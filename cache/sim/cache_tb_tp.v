`timescale 1ns / 1ps
`include "../src/Cacheconst.vh"
`define ICACHE_ADDR_TRACE_FILE "D:/Code/trycache/golden_trace_icache_1.txt"
`define ICACHE_DATA_TRACE_FILE "D:/Code/trycache/golden_trace_icache_2.txt"
`define DCACHE_ADDR_TRACE_FILE "D:/Code/trycache/golden_trace_dcache_1.txt"
`define DCACHE_DATA_TRACE_FILE "D:/Code/trycache/golden_trace_dcache_2.txt"
`define END_ADDR 32'h0000_0000

`define TEST_ICACHE
`define TEST_DCACHE

module cache_tb(  );

    // 时钟与重置信号
    reg aclk;
    reg aresetn;
    initial begin
        aclk    = 1'b0;
        aresetn = 1'b0;
        #2000;
        aresetn = 1'b1;
    end
    always #5 aclk = ~aclk;

    //ICACHE交互信号
    reg          inst_req         ;
    reg          inst_wr          ;
    reg  [1  :0] inst_size        ;
    wire [7  :0] inst_index       ;
    reg  [19 :0] inst_tag         ;
    reg          inst_hasException;
    reg          inst_unCache     ;
    reg  [31 :0] inst_wdata       ;
    wire [127:0] inst_rdata       ;
    wire         inst_index_ok    ;
    wire         inst_data_ok     ;
    
    //DCACHE交互信号
    reg         data_req         ;
    reg         data_wr          ;
    reg  [1 :0] data_size        ;
    reg  [11:0] data_index       ;
    reg  [19:0] data_tag         ;
    reg         data_hasException;
    reg         data_unCache     ;
    reg  [3 :0] data_wstrb       ;
    reg  [31:0] data_wdata       ;
    wire [31:0] data_rdata       ;
    wire        data_index_ok    ;
    wire        data_data_ok     ;

    //访存行为模拟
    reg test_err;
    reg test_end;
    reg [31:0] inst_cnt;
    reg [31:0] data_cnt;
    //
    integer inst_addr_trace_ref;
    integer inst_data_trace_ref;
    integer data_addr_trace_ref;
    integer data_data_trace_ref;
    initial begin
        inst_cnt = 0;
        data_cnt = 0;
`ifdef TEST_ICACHE
        inst_req  = 1;
        inst_wr   = 0;
        inst_size = 2'b11;
        inst_hasException = 0;
        //TODO
        inst_unCache = 0;
        inst_wdata = 0;
`endif
`ifdef TEST_DCACHE
        data_req = 0;
`endif
        inst_addr_trace_ref = $fopen(`ICACHE_ADDR_TRACE_FILE,"r");
        inst_data_trace_ref = $fopen(`ICACHE_ADDR_TRACE_FILE,"r");
        data_addr_trace_ref = $fopen(`DCACHE_ADDR_TRACE_FILE,"r");
        data_data_trace_ref = $fopen(`DCACHE_ADDR_TRACE_FILE,"r");
    end

    //  读取访存信息
    reg [31:0] no_use_num;
    reg [31:0] inst_cpu_addr;
    reg [31:0] no_use_inst_rdata;
    reg [31:0] use_num;
    reg [31:0] ref_inst_cpu_addr;
    reg [31:0] ref_inst_rdata;
    // index
    assign inst_index = inst_cpu_addr[11:4];
    // tag
    always @(posedge aclk ) begin
        inst_tag <= inst_cpu_addr[31:12];
    end
`ifdef TEST_ICACHE
    always @(posedge aclk ) begin
        #1
        if (inst_index_ok) begin
            if (!($feof(inst_addr_trace_ref)) && aresetn) begin
                $fscanf(inst_addr_trace_ref, "          %d %h %h", no_use_num, inst_cpu_addr, no_use_inst_rdata);
            end
        end
    end
    //TODO FOUR_WORD we test one of four
    reg [31:0]  ref_inst_data;
    always @(posedge aclk) begin
        #1;
        if (inst_data_ok) begin
            if (!($feof(inst_data_trace_ref)) && aresetn) begin
                $fscanf(inst_data_trace_ref, "          %d %h %h", use_num, ref_inst_cpu_addr, ref_inst_data);
            end
        end
    end
    //TRACE比对
    wire [31:0] test_inst_rdata [3:0];
    assign {test_inst_rdata[3],test_inst_rdata[2],test_inst_rdata[1],test_inst_rdata[0]} = inst_rdata;
    always @(posedge aclk) begin
        #2;
        if (!aresetn) begin
            test_err <= 1'b0;
        end
        else if (!test_end && inst_data_ok) begin
            inst_cnt <= inst_cnt + 1'b1;
            if (test_inst_rdata[ref_inst_cpu_addr[3:2]]!==ref_inst_data) begin
                //TODO
                $display("--------------------------------------------------------------");
                $display("[%t] Error!!!",$time);
                $display("    Cache Address = 0x%8h", inst_cpu_addr);
                $display("    Reference Cache Data = 0x%8h, Error Cache Data = 0x%8h",ref_inst_data, test_inst_rdata[ref_inst_cpu_addr[3:2]]);
                $display("--------------------------------------------------------------");
                test_err <= 1'b1;
                #40;
                $finish;
            end
        end
    end
`endif 

`ifdef TEST_DCACHE
    always @(posedge aclk ) begin
        if (data_index_ok) begin
            if (!($feof(data_addr_trace_ref)) && aresetn) begin
            //TODO $fscanf(inst_addr_trace_ref, "%h %h", cpu_req, cpu_addr);
            end
        end
    end
    reg [31:0]  ref_data_data;
    always @(posedge aclk) begin
        #1;
        if (data_data_ok) begin
            if (!($feof(data_data_trace_ref)) && aresetn) begin
            //TODO $fscanf(cache_data_trace_ref, "%h", ref_cache_data);
            end
        end
    end
    //TRACE比对
    always @(posedge aclk) begin
        #2;
        if (!aresetn) begin
            test_err <= 1'b0;
        end
        else if (!test_end && data_data_ok) begin
            data_cnt <= data_cnt + 1'b1;
            if (data_rdata!==ref_data_data) begin
                // //TODO
                // $display("--------------------------------------------------------------");
                // $display("[%t] Error!!!",$time);
                // $display("    Cache Address = 0x%8h", cpu_addr);
                // $display("    Reference Cache Data = 0x%8h, Error Cache Data = 0x%8h",ref_cache_data, cache_rdata);
                // $display("--------------------------------------------------------------");
                // test_err <= 1'b1;
                // #40;
                // $finish;
            end
        end
    end
`endif

    //测试管理信号
    parameter TEST_TIME     = 410526;
    parameter REF_MISS_TIME = 1275;
    parameter INST_CNT = 123342;
    parameter DATA_CNT = 40114;
    reg [31:0] inst_miss_time;
    reg [31:0] data_miss_time;

    initial begin
        $timeformat(-9,0," ns",10);
        inst_miss_time = 0;
        data_miss_time = 0;
        while(aresetn) #5;
        $display("==============================================================");
        $display("Test begin!");
        #10000;
    end
    always @(posedge aclk) begin
        if (u_icache_tp.cache_stat == `MISS) begin
            inst_miss_time <= inst_miss_time + 1;
        end
    end
    always @(posedge aclk) begin
        if (u_dcache_tp.cache_stat == `MISS) begin
            data_miss_time <= data_miss_time + 1;
        end
    end
    always @(posedge aclk) begin
        if (!aresetn) begin
            test_end <= 1'b0;
        end
        //TODO
        else if (!test_end) begin
`ifdef TEST_ICACHE
            if (inst_cnt == INST_CNT) begin
                test_end <= 1'b1;
                $display("==============================================================");
                $display("Test end!");
                #40;
                $fclose(inst_addr_trace_ref);
                $fclose(inst_data_trace_ref);
                $fclose(data_addr_trace_ref);
                $fclose(data_data_trace_ref);
                if (test_err) begin
                    $display("Fail!!! Cache function errors! Check your code!");
                end
                else if (inst_miss_time > REF_MISS_TIME) begin
                    $display("--------------------------------------------------------------");
                    $display("[%t] Error!!!",$time);
                    $display("    Reference  Cache Miss Rate = %d / %d", REF_MISS_TIME, TEST_TIME);
                    $display("    Your Error Cache Miss Rate = %d / %d", inst_miss_time, TEST_TIME);
                    $display("--------------------------------------------------------------");
                    $display("Fail!!! LRU algorithm errors! Check your code!");
                end
                else begin
                    $display("----PASS!!!");
                end
                $finish;
            end
`endif 
`ifdef TEST_DCACHE
            if (data_cnt == DATA_CNT) begin
                test_end <= 1'b1;
                $display("==============================================================");
                $display("Test end!");
                #40;
                $fclose(inst_addr_trace_ref);
                $fclose(inst_data_trace_ref);
                $fclose(data_addr_trace_ref);
                $fclose(data_data_trace_ref);
                if (test_err) begin
                    $display("Fail!!! Cache function errors! Check your code!");
                end
                else if (data_miss_time > REF_MISS_TIME) begin
                    $display("--------------------------------------------------------------");
                    $display("[%t] Error!!!",$time);
                    $display("    Reference  Cache Miss Rate = %d / %d", REF_MISS_TIME , TEST_TIME);
                    $display("    Your Error Cache Miss Rate = %d / %d", data_miss_time, TEST_TIME);
                    $display("--------------------------------------------------------------");
                    $display("Fail!!! LRU algorithm errors! Check your code!");
                end
                else begin
                    $display("----PASS!!!");
                end
                $finish;
            end
`endif 
        end
    end





    //------------Inst Cache-----------
    wire  [3 :0] inst_cache_arid   ;
    wire  [31:0] inst_cache_araddr ;
    wire  [3 :0] inst_cache_arlen  ;
    wire  [2 :0] inst_cache_arsize ;
    wire  [1 :0] inst_cache_arburst;
    wire  [1 :0] inst_cache_arlock ;
    wire  [3 :0] inst_cache_arcache;
    wire  [2 :0] inst_cache_arprot ;
    wire         inst_cache_arvalid;
    wire         inst_cache_arready;

    wire  [3 :0] inst_cache_rid    ;
    wire  [31:0] inst_cache_rdata  ;
    wire  [1 :0] inst_cache_rresp  ;
    wire         inst_cache_rlast  ;
    wire         inst_cache_rvalid ;
    wire         inst_cache_rready ;

    wire  [3 :0] inst_cache_awid   ;
    wire  [31:0] inst_cache_awaddr ;
    wire  [3 :0] inst_cache_awlen  ;
    wire  [2 :0] inst_cache_awsize ;
    wire  [1 :0] inst_cache_awburst;
    wire  [1 :0] inst_cache_awlock ;
    wire  [3 :0] inst_cache_awcache;
    wire  [2 :0] inst_cache_awprot ;
    wire         inst_cache_awvalid;
    wire         inst_cache_awready;

    wire  [3 :0] inst_cache_wid    ;
    wire  [31:0] inst_cache_wdata  ;
    wire  [3 :0] inst_cache_wstrb  ;
    wire         inst_cache_wlast  ;
    wire         inst_cache_wvalid ;
    wire         inst_cache_wready ;

    wire  [3 :0] inst_cache_bid    ;
    wire  [1 :0] inst_cache_bresp  ;
    wire         inst_cache_bvalid ;
    wire         inst_cache_bready ;

    // Inst Uncache <-> Inst Cache
    wire          inst_uca_req     ;
    wire  [31 :0] inst_uca_addr    ;
    wire  [127:0] inst_uca_rdata   ;
    wire          inst_uca_addr_ok ;
    wire          inst_uca_data_ok ;

    //-----------Inst Uncache
    wire  [3 :0] inst_uncache_arid   ;
    wire  [31:0] inst_uncache_araddr ;
    wire  [3 :0] inst_uncache_arlen  ;
    wire  [2 :0] inst_uncache_arsize ;
    wire  [1 :0] inst_uncache_arburst;
    wire  [1 :0] inst_uncache_arlock ;
    wire  [3 :0] inst_uncache_arcache;
    wire  [2 :0] inst_uncache_arprot ;
    wire         inst_uncache_arvalid;
    wire         inst_uncache_arready;

    wire  [3 :0] inst_uncache_rid    ;
    wire  [31:0] inst_uncache_rdata  ;
    wire  [1 :0] inst_uncache_rresp  ;
    wire         inst_uncache_rlast  ;
    wire         inst_uncache_rvalid ;
    wire         inst_uncache_rready ;

    wire         inst_uncache_awready;
    wire         inst_uncache_wready ;
    wire         inst_uncahce_bvalid ;
    wire  [3 :0] inst_uncache_bid    ;
    wire  [1 :0] inst_uncahce_bresp  ;

    //------------Data Cache
    wire  [3 :0] data_cache_arid   ;
    wire  [31:0] data_cache_araddr ;
    wire  [3 :0] data_cache_arlen  ;
    wire  [2 :0] data_cache_arsize ;
    wire  [1 :0] data_cache_arburst;
    wire  [1 :0] data_cache_arlock ;
    wire  [3 :0] data_cache_arcache;
    wire  [2 :0] data_cache_arprot ;
    wire         data_cache_arvalid;
    wire         data_cache_arready;

    wire  [3 :0] data_cache_rid    ;
    wire  [31:0] data_cache_rdata  ;
    wire  [1 :0] data_cache_rresp  ;
    wire         data_cache_rlast  ;
    wire         data_cache_rvalid ;
    wire         data_cache_rready ;

    wire  [3 :0] data_cache_awid   ;
    wire  [31:0] data_cache_awaddr ;
    wire  [3 :0] data_cache_awlen  ;
    wire  [2 :0] data_cache_awsize ;
    wire  [1 :0] data_cache_awburst;
    wire  [1 :0] data_cache_awlock ;
    wire  [3 :0] data_cache_awcache;
    wire  [2 :0] data_cache_awprot ;
    wire         data_cache_awvalid;
    wire         data_cache_awready;

    wire  [3 :0] data_cache_wid    ;
    wire  [31:0] data_cache_wdata  ;
    wire  [3 :0] data_cache_wstrb  ;
    wire         data_cache_wlast  ;
    wire         data_cache_wvalid ;
    wire         data_cache_wready ;

    wire  [3 :0] data_cache_bid    ;
    wire  [1 :0] data_cache_bresp  ;
    wire         data_cache_bvalid ;
    wire         data_cache_bready ;

    // Data Uncache <-> Data Cache
    wire        data_uca_req    ;
    wire        data_uca_wr     ;
    wire [31:0] data_uca_addr   ;
    wire [31:0] data_uca_wdata  ;
    wire [3 :0] data_uca_wstrb  ;
    wire [31:0] data_uca_rdata  ;
    wire        data_uca_addr_ok;
    wire        data_uca_data_ok;

    //-----------Data Uncache
    wire  [3 :0] data_uncache_arid   ;
    wire  [31:0] data_uncache_araddr ;
    wire  [3 :0] data_uncache_arlen  ;
    wire  [2 :0] data_uncache_arsize ;
    wire  [1 :0] data_uncache_arburst;
    wire  [1 :0] data_uncache_arlock ;
    wire  [3 :0] data_uncache_arcache;
    wire  [2 :0] data_uncache_arprot ;
    wire         data_uncache_arvalid;
    wire         data_uncache_arready;

    wire  [3 :0] data_uncache_rid    ;
    wire  [31:0] data_uncache_rdata  ;
    wire  [1 :0] data_uncache_rresp  ;
    wire         data_uncache_rlast  ;
    wire         data_uncache_rvalid ;
    wire         data_uncache_rready ;

    wire  [3 :0] data_uncache_awid   ;
    wire  [31:0] data_uncache_awaddr ;
    wire  [3 :0] data_uncache_awlen  ;
    wire  [2 :0] data_uncache_awsize ;
    wire  [1 :0] data_uncache_awburst;
    wire  [1 :0] data_uncache_awlock ;
    wire  [3 :0] data_uncache_awcache;
    wire  [2 :0] data_uncache_awprot ;
    wire         data_uncache_awvalid;
    wire         data_uncache_awready;

    wire  [3 :0] data_uncache_wid    ;
    wire  [31:0] data_uncache_wdata  ;
    wire  [3 :0] data_uncache_wstrb  ;
    wire         data_uncache_wlast  ;
    wire         data_uncache_wvalid ;
    wire         data_uncache_wready ;

    wire  [3 :0] data_uncache_bid    ;
    wire  [1 :0] data_uncache_bresp  ;
    wire         data_uncache_bvalid ;
    wire         data_uncache_bready ;

    // AIX CROSSBAR <-> AXI_RAM
    wire [3 :0] arid;
    wire [31:0] araddr;
    wire [3 :0] arlen;
    wire [2 :0] arsize;
    wire [1 :0] arburst;
    wire [1 :0] arlock;
    wire [3 :0] arcache;
    wire [2 :0] arprot;
    wire        arvalid;
    wire        arready;
    wire [3 :0] rid;
    wire [31:0] rdata;
    wire [1 :0] rresp;
    wire        rlast;
    wire        rvalid;
    wire        rready;
    wire [3 :0] awid;
    wire [31:0] awaddr;
    wire [3 :0] awlen;
    wire [2 :0] awsize;
    wire [1 :0] awburst;
    wire [1 :0] awlock;
    wire [3 :0] awcache;
    wire [2 :0] awprot;
    wire        awvalid;
    wire        awready;
    wire [3 :0] wid;
    wire [31:0] wdata;
    wire [3 :0] wstrb;
    wire        wlast;
    wire        wvalid;
    wire        wready;
    wire [3 :0] bid;
    wire [1 :0] bresp;
    wire        bvalid;
    wire        bready;

    wire [3 :0] s_axi_arid = arid;
    wire [31:0] s_axi_araddr= araddr;
    wire [7 :0] s_axi_arlen = {4'b0000,arlen};
    wire [2 :0] s_axi_arsize= arsize;
    wire [1 :0] s_axi_arburst= arburst;
    wire [1 :0] s_axi_arlock= arlock;
    wire [3 :0] s_axi_arcache= arcache;
    wire [2 :0] s_axi_arprot= arprot;
    wire        s_axi_arvalid= arvalid;
    wire        s_axi_arready= arready;
    wire [3 :0] s_axi_rid= rid;
    wire [31:0] s_axi_rdata= rdata;
    wire [1 :0] s_axi_rresp= rresp;
    wire        s_axi_rlast= rlast;
    wire        s_axi_rvalid= rvalid;
    wire        s_axi_rready= rready;
    wire [3 :0] s_axi_awid= awid;
    wire [31:0] s_axi_awaddr= awaddr;
    wire [7 :0] s_axi_awlen = {4'b0000,awlen};
    wire [2 :0] s_axi_awsize= awsize;
    wire [1 :0] s_axi_awburst= awburst;
    wire [1 :0] s_axi_awlock= awlock;
    wire [3 :0] s_axi_awcache= awcache;
    wire [2 :0] s_axi_awprot= awprot;
    wire        s_axi_awvalid= awvalid;
    wire        s_axi_awready= awready;
    wire [3 :0] s_axi_wid= wid;
    wire [31:0] s_axi_wdata= wdata;
    wire [3 :0] s_axi_wstrb= wstrb;
    wire        s_axi_wlast= wlast;
    wire        s_axi_wvalid= wvalid;
    wire        s_axi_wready= wready;
    wire [3 :0] s_axi_bid= bid;
    wire [1 :0] s_axi_bresp= bresp;
    wire        s_axi_bvalid= bvalid;
    wire        s_axi_bready= bready;
// AXI CROSSBAR
    axi_crossbar_0 u_axi_crossbar_0(
        .aclk             (aclk   ),
        .aresetn          (aresetn),

        .s_axi_arid       ({data_cache_arid,       inst_cache_arid,       data_uncache_arid,       inst_uncache_arid    }),
        .s_axi_araddr     ({data_cache_araddr,     inst_cache_araddr,     data_uncache_araddr,     inst_uncache_araddr  }),
        .s_axi_arlen      ({data_cache_arlen,      inst_cache_arlen,      data_uncache_arlen,      inst_uncache_arlen   }),
        .s_axi_arsize     ({data_cache_arsize,     inst_cache_arsize,     data_uncache_arsize,     inst_uncache_arsize  }),
        .s_axi_arburst    ({data_cache_arburst,    inst_cache_arburst,    data_uncache_arburst,    inst_uncache_arburst }),
        .s_axi_arlock     ({data_cache_arlock,     inst_cache_arlock,     data_uncache_arlock,     inst_uncache_arlock  }),
        .s_axi_arcache    ({data_cache_arcache,    inst_cache_arcache,    data_uncache_arcache,    inst_uncache_arcache }),
        .s_axi_arprot     ({data_cache_arprot,     inst_cache_arprot,     data_uncache_arprot,     inst_uncache_arprot  }),
        .s_axi_arqos      (16'b0                                                                                         ),
        .s_axi_arvalid    ({data_cache_arvalid,    inst_cache_arvalid,    data_uncache_arvalid,    inst_uncache_arvalid }),
        .s_axi_arready    ({data_cache_arready,    inst_cache_arready,    data_uncache_arready,    inst_uncache_arready }),

        .s_axi_rid        ({data_cache_rid,        inst_cache_rid,        data_uncache_rid,        inst_uncache_rid     }),
        .s_axi_rdata      ({data_cache_rdata,      inst_cache_rdata,      data_uncache_rdata,      inst_uncache_rdata   }),
        .s_axi_rresp      ({data_cache_rresp,      inst_cache_rresp,      data_uncache_rresp,      inst_uncache_rresp   }),
        .s_axi_rlast      ({data_cache_rlast,      inst_cache_rlast,      data_uncache_rlast,      inst_uncache_rlast   }),
        .s_axi_rvalid     ({data_cache_rvalid,     inst_cache_rvalid,     data_uncache_rvalid,     inst_uncache_rvalid  }),
        .s_axi_rready     ({data_cache_rready,     inst_cache_rready,     data_uncache_rready,     inst_uncache_rready  }),

        .s_axi_awid       ({data_cache_awid,       4'b0,                  data_uncache_awid,       4'b0                 }),
        .s_axi_awaddr     ({data_cache_awaddr,     32'b0,                 data_uncache_awaddr,     32'b0                }),
        .s_axi_awlen      ({data_cache_awlen,      4'b0,                  data_uncache_awlen,      4'b0                 }),
        .s_axi_awsize     ({data_cache_awsize,     3'b0,                  data_uncache_awsize,     3'b0                 }),
        .s_axi_awburst    ({data_cache_awburst,    2'b0,                  data_uncache_awburst,    2'b0                 }),
        .s_axi_awlock     ({data_cache_awlock,     2'b0,                  data_uncache_awlock,     2'b0                 }),
        .s_axi_awcache    ({data_cache_awcache,    4'b0,                  data_uncache_awcache,    4'b0                 }),
        .s_axi_awprot     ({data_cache_awprot,     3'b0,                  data_uncache_awprot,     3'b0                 }),
        .s_axi_awqos      ({4'b0,                  4'b0,                  4'b0,                    4'b0                 }),
        .s_axi_awvalid    ({data_cache_awvalid,    1'b0,                  data_uncache_awvalid,    1'b0                 }),
        .s_axi_awready    ({data_cache_awready,    inst_cache_awready,    data_uncache_awready,    inst_uncache_awready }),

        .s_axi_wid        ({data_cache_wid,        4'b0,                  data_uncache_wid,        4'b0                 }),
        .s_axi_wdata      ({data_cache_wdata,      32'b0,                 data_uncache_wdata,      32'b0                }),
        .s_axi_wstrb      ({data_cache_wstrb,      4'b0,                  data_uncache_wstrb,      4'b0                 }),
        .s_axi_wlast      ({data_cache_wlast,      1'b0,                  data_uncache_wlast,      1'b0                 }),
        .s_axi_wvalid     ({data_cache_wvalid,     1'b0,                  data_uncache_wvalid,     1'b0                 }),
        .s_axi_wready     ({data_cache_wready,     inst_cache_wready,     data_uncache_wready,     inst_uncache_wready  }),

        .s_axi_bid        ({data_cache_bid,        inst_cache_bid,        data_uncache_bid,        inst_uncache_bid     }),
        .s_axi_bresp      ({data_cache_bresp,      inst_cache_bresp,      data_uncache_bresp,      inst_uncahce_bresp   }),
        .s_axi_bvalid     ({data_cache_bvalid,     inst_cache_bvalid,     data_uncache_bvalid,     inst_uncahce_bvalid  }),
        .s_axi_bready     ({data_cache_bready,     1'b0,                  data_uncache_bready,     1'b0                 }),

        .m_axi_arid           (arid   ),
        .m_axi_araddr         (araddr ),
        .m_axi_arlen          (arlen  ),
        .m_axi_arsize         (arsize ),
        .m_axi_arburst        (arburst),
        .m_axi_arlock         (arlock ),
        .m_axi_arcache        (arcache),
        .m_axi_arprot         (arprot ),
        .m_axi_arqos          (       ),
        .m_axi_arvalid        (arvalid),
        .m_axi_arready        (arready),
        .m_axi_rid            (rid    ),
        .m_axi_rdata          (rdata  ),
        .m_axi_rresp          (rresp  ),
        .m_axi_rlast          (rlast  ),
        .m_axi_rvalid         (rvalid ),
        .m_axi_rready         (rready ),
        .m_axi_awid           (awid   ),
        .m_axi_awaddr         (awaddr ),
        .m_axi_awlen          (awlen  ),
        .m_axi_awsize         (awsize ),
        .m_axi_awburst        (awburst),
        .m_axi_awlock         (awlock ),
        .m_axi_awcache        (awcache),
        .m_axi_awprot         (awprot ),
        .m_axi_awqos          (       ),
        .m_axi_awvalid        (awvalid),
        .m_axi_awready        (awready),
        .m_axi_wid            (wid    ),
        .m_axi_wdata          (wdata  ),
        .m_axi_wstrb          (wstrb  ),
        .m_axi_wlast          (wlast  ),
        .m_axi_wvalid         (wvalid ),
        .m_axi_wready         (wready ),
        .m_axi_bid            (bid    ),
        .m_axi_bresp          (bresp  ),
        .m_axi_bvalid         (bvalid ),
        .m_axi_bready         (bready )
    );
    axi_ram u_axi_ram         (
        .s_aresetn                (aresetn),
        .s_aclk                   (aclk   ),
        .s_axi_awid               (s_axi_awid   ),
        .s_axi_awaddr             (s_axi_awaddr ),
        .s_axi_awlen              (s_axi_awlen  ),
        .s_axi_awsize             (s_axi_awsize ),
        .s_axi_awburst            (s_axi_awburst),
        .s_axi_awvalid            (s_axi_awvalid),
        .s_axi_awready            (s_axi_awready),
        .s_axi_wdata              (s_axi_wdata  ),
        .s_axi_wstrb              (s_axi_wstrb  ),
        .s_axi_wlast              (s_axi_wlast  ),
        .s_axi_wvalid             (s_axi_wvalid ),
        .s_axi_wready             (s_axi_wready ),
        .s_axi_bid                (s_axi_bid    ),
        .s_axi_bresp              (s_axi_bresp  ),
        .s_axi_bvalid             (s_axi_bvalid ),
        .s_axi_bready             (s_axi_bready	),
        .s_axi_arid               (s_axi_arid   ),
        .s_axi_araddr             (s_axi_araddr ),
        .s_axi_arlen              (s_axi_arlen  ),
        .s_axi_arsize             (s_axi_arsize ),
        .s_axi_arburst            (s_axi_arburst),
        .s_axi_arvalid            (s_axi_arvalid),
        .s_axi_arready            (s_axi_arready),
        .s_axi_rid                (s_axi_rid    ),
        .s_axi_rresp              (s_axi_rresp  ),
        .s_axi_rdata              (s_axi_rdata  ),
        .s_axi_rlast              (s_axi_rlast  ),
        .s_axi_rvalid             (s_axi_rvalid ),
        .s_axi_rready             (s_axi_rready )
    );
    // ICACHE and INST_UNCACHE
    icache_tp  u_icache_tp (
        .clk                  (aclk                ),
        .rst                  (aresetn             ),
        .inst_req             (inst_req            ),
        .inst_wr              (inst_wr             ),
        .inst_size            (inst_size           ),
        .inst_index           (inst_index          ),
        .inst_tag             (inst_tag            ),
        .inst_hasException    (inst_hasException   ),
        .inst_unCache         (inst_unCache        ),
        .inst_wdata           (inst_wdata          ),
        .inst_rdata           (inst_rdata          ),
        .inst_index_ok        (inst_index_ok       ),
        .inst_data_ok         (inst_data_ok        ),
        .arid                 (inst_cache_arid     ),
        .araddr               (inst_cache_araddr   ),
        .arlen                (inst_cache_arlen    ),
        .arsize               (inst_cache_arsize   ),
        .arburst              (inst_cache_arburst  ),
        .arlock               (inst_cache_arlock   ),
        .arcache              (inst_cache_arcache  ),
        .arprot               (inst_cache_arprot   ), 
        .arvalid              (inst_cache_arvalid  ),
        .arready              (inst_cache_arready  ),
        .rid                  (inst_cache_rid      ),
        .rdata                (inst_cache_rdata    ),
        .rresp                (inst_cache_rresp    ),
        .rlast                (inst_cache_rlast    ),
        .rvalid               (inst_cache_rvalid   ),
        .rready               (inst_cache_rready   ),
        .awid                 (inst_cache_awid     ),
        .awaddr               (inst_cache_awaddr   ),
        .awlen                (inst_cache_awlen    ),
        .awsize               (inst_cache_awsize   ),
        .awburst              (inst_cache_awburst  ),
        .awlock               (inst_cache_awlock   ),
        .awcache              (inst_cache_awcache  ),
        .awprot               (inst_cache_awprot   ),
        .awvalid              (inst_cache_awvalid  ),
        .awready              (inst_cache_awready  ),
        .wid                  (inst_cache_wid      ),
        .wdata                (inst_cache_wdata    ),
        .wstrb                (inst_cache_wstrb    ),
        .wlast                (inst_cache_wlast    ),
        .wvalid               (inst_cache_wvalid   ),
        .wready               (inst_cache_wready   ),
        .bid                  (inst_cache_bid      ),
        .bvalid               (inst_cache_bvalid   ),
        .bresp                (inst_cache_bresp    ),
        .bready               (inst_cache_bready   ),
        .inst_uncache_req     (inst_uca_req        ),
        .inst_uncache_addr    (inst_uca_addr       ),
        .inst_uncache_rdata   (inst_uca_rdata      ),
        .inst_uncache_addr_ok (inst_uca_addr_ok    ),
        .inst_uncache_data_ok (inst_uca_data_ok    )
    );
    inst_uncache u_inst_uncache (
        .clk          (aclk                ),
        .rst          (aresetn             ),
        .inst_req     (inst_uca_req        ),
        .inst_addr    (inst_uca_addr       ),
        .inst_rdata   (inst_uca_rdata      ),
        .inst_addr_ok (inst_uca_addr_ok    ),
        .inst_data_ok (inst_uca_data_ok    ),
        .arid         (inst_uncache_arid   ),
        .araddr       (inst_uncache_araddr ),
        .arlen        (inst_uncache_arlen  ),
        .arsize       (inst_uncache_arsize ),
        .arburst      (inst_uncache_arburst),
        .arlock       (inst_uncache_arlock ),
        .arcache      (inst_uncache_arcache),
        .arprot       (inst_uncache_arprot ), 
        .arvalid      (inst_uncache_arvalid),
        .arready      (inst_uncache_arready),
        .rid          (inst_uncache_rid    ),
        .rdata        (inst_uncache_rdata  ),
        .rresp        (inst_uncache_rresp  ),
        .rlast        (inst_uncache_rlast  ),
        .rvalid       (inst_uncache_rvalid ),
        .rready       (inst_uncache_rready )
    );

    // DCACHE and DATA_UNCAHCE
    dcache_tp u_dcache_tp (
        .clk                  (aclk                ),
        .rst                  (aresetn             ),
        .data_req             (data_req            ),
        .data_wr              (data_wr             ),
        .data_size            (data_size           ),
        .data_index           (data_index          ),
        .data_tag             (data_tag            ),
        .data_hasException    (data_hasException   ),
        .data_unCache         (data_unCache        ),
        .data_wstrb           (data_wstrb          ),
        .data_wdata           (data_wdata          ),
        .data_rdata           (data_rdata          ),
        .data_index_ok        (data_index_ok       ),
        .data_data_ok         (data_data_ok        ),
        .arid                 (data_cache_arid     ),
        .araddr               (data_cache_araddr   ),
        .arlen                (data_cache_arlen    ),
        .arsize               (data_cache_arsize   ),
        .arburst              (data_cache_arburst  ),
        .arlock               (data_cache_arlock   ),
        .arcache              (data_cache_arcache  ),
        .arprot               (data_cache_arprot   ), 
        .arvalid              (data_cache_arvalid  ),
        .arready              (data_cache_arready  ),
        .rid                  (data_cache_rid      ),
        .rdata                (data_cache_rdata    ),
        .rresp                (data_cache_rresp    ),
        .rlast                (data_cache_rlast    ),
        .rvalid               (data_cache_rvalid   ),
        .rready               (data_cache_rready   ),
        .awid                 (data_cache_awid     ),
        .awaddr               (data_cache_awaddr   ),
        .awlen                (data_cache_awlen    ),
        .awsize               (data_cache_awsize   ),
        .awburst              (data_cache_awburst  ),
        .awlock               (data_cache_awlock   ),
        .awcache              (data_cache_awcache  ),
        .awprot               (data_cache_awprot   ),
        .awvalid              (data_cache_awvalid  ),
        .awready              (data_cache_awready  ),
        .wid                  (data_cache_wid      ),
        .wdata                (data_cache_wdata    ),
        .wstrb                (data_cache_wstrb    ),
        .wlast                (data_cache_wlast    ),
        .wvalid               (data_cache_wvalid   ),
        .wready               (data_cache_wready   ),
        .bid                  (data_cache_bid      ),
        .bvalid               (data_cache_bvalid   ),
        .bresp                (data_cache_bresp    ),
        .bready               (data_cache_bready   ),
        .data_uncache_req     (data_uca_req    ),
        .data_uncache_wr      (data_uca_wr     ),
        .data_uncache_addr    (data_uca_addr   ),
        .data_uncache_wdata   (data_uca_wdata  ),
        .data_uncache_wstrb   (data_uca_wstrb  ),
        .data_uncache_rdata   (data_uca_rdata  ),
        .data_uncache_addr_ok (data_uca_addr_ok),
        .data_uncache_data_ok (data_uca_data_ok)
    );
    data_uncache u_data_uncache(
        .clk                  (aclk                ),
        .rst                  (aresetn             ),
        .data_req             (data_uca_req        ),
        .data_wr              (data_uca_wr         ),
        .data_addr            (data_uca_addr       ),
        .data_wdata           (data_uca_wdata      ),
        .data_wstrb           (data_uca_wstrb      ),
        .data_rdata           (data_uca_rdata      ),
        .data_addr_ok         (data_uca_addr_ok    ),
        .data_data_ok         (data_uca_data_ok    ),
        .arid                 (data_uncache_arid   ),
        .araddr               (data_uncache_araddr ),
        .arlen                (data_uncache_arlen  ),
        .arsize               (data_uncache_arsize ),
        .arburst              (data_uncache_arburst),
        .arlock               (data_uncache_arlock ),
        .arcache              (data_uncache_arcache),
        .arprot               (data_uncache_arprot ), 
        .arvalid              (data_uncache_arvalid),
        .arready              (data_uncache_arready),
        .rid                  (data_uncache_rid    ),
        .rdata                (data_uncache_rdata  ),
        .rresp                (data_uncache_rresp  ),
        .rlast                (data_uncache_rlast  ),
        .rvalid               (data_uncache_rvalid ),
        .rready               (data_uncache_rready ),
        .awid                 (data_uncache_awid   ),
        .awaddr               (data_uncache_awaddr ),
        .awlen                (data_uncache_awlen  ),
        .awsize               (data_uncache_awsize ),
        .awburst              (data_uncache_awburst),
        .awlock               (data_uncache_awlock ),
        .awcache              (data_uncache_awcache),
        .awprot               (data_uncache_awprot ),
        .awvalid              (data_uncache_awvalid),
        .awready              (data_uncache_awready),
        .wid                  (data_uncache_wid    ),
        .wdata                (data_uncache_wdata  ),
        .wstrb                (data_uncache_wstrb  ),
        .wlast                (data_uncache_wlast  ),
        .wvalid               (data_uncache_wvalid ),
        .wready               (data_uncache_wready ),
        .bid                  (data_uncache_bid    ),
        .bvalid               (data_uncache_bvalid ),
        .bresp                (data_uncache_bresp  ),
        .bready               (data_uncache_bready )
    );
endmodule