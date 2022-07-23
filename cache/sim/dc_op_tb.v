`timescale 1ns / 1ps
`include "../src/Cacheconst.vh"
`define DCACHE_ADDR_TRACE_FILE "D:/Code/trycache/golden_trace_dcache_1.txt"
`define DCACHE_DATA_TRACE_FILE "D:/Code/trycache/golden_trace_dcache_2.txt"
`define DCACHE_OP_TEST "D:/Code/cache_tp/rtl/sim/trace/dc_op.txt"
module dc_op_tb(  );

    // 时钟与重置信�?
    reg aclk;
    reg aresetn;
    initial begin
        aclk    = 1'b0;
        aresetn = 1'b0;
        #2000;
        aresetn = 1'b1;
    end
    always #5 aclk = ~aclk;

    //DCACHE交互信号
    reg         data_req         ;
    reg         data_wr          ;
    reg  [1 :0] data_size        ;
    wire [11:0] data_index       ;
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
    reg [31:0] data_cnt;

    integer data_addr_trace_ref;
    integer data_data_trace_ref;
    initial begin
        data_cnt = 0;
        data_req  = 1;
        data_wr   = 0;
        data_size = 2'b11;
        data_hasException = 0;
        //TODO
        data_unCache =0;
        data_wdata = 0;
        data_wstrb = 0;
        data_addr_trace_ref = $fopen(`DCACHE_ADDR_TRACE_FILE,"r");
        data_data_trace_ref = $fopen(`DCACHE_DATA_TRACE_FILE,"r");
    end

    //  读取访存信息
    reg [31:0] no_use_num;
    reg [31:0] data_addr;
    reg [31:0] no_use_data_rdata;
    reg [31:0] no_use_data_wdata;
    reg [31:0] use_num;
    reg [31:0] ref_data_addr;
    reg  ref_data_wr;
    reg [3:0] no_use_data_wstrb;
    reg [31:0] ref_data_rdata;
    // index
    assign data_index = data_addr[11:0];
    // tag
    always @(posedge aclk ) begin
        //data_unCache <= $random %2;
        data_tag <= data_addr[31:12];
    end


    always @(posedge aclk ) begin
        #1
        if (data_index_ok) begin
            if (!($feof(data_addr_trace_ref)) && aresetn) begin
                //TODO
                $fscanf(data_addr_trace_ref, "          %d %h %h %h %h %h", no_use_num ,data_addr,data_wr,data_wstrb,data_wdata,no_use_data_rdata);
            end
        end
    end
    always @(posedge aclk) begin
        #1;
        if (data_data_ok) begin
            if (!($feof(data_data_trace_ref)) && aresetn) begin
                $fscanf(data_data_trace_ref, "          %d %h %h %h %h %h", use_num ,ref_data_addr,ref_data_wr,no_use_data_wstrb,no_use_data_wdata,ref_data_rdata);
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
            if (ref_data_wr) begin
                
            end
            else if (data_rdata!==ref_data_rdata) begin
                //TODO
                $display("--------------------------------------------------------------");
                $display("[%t at %d] Error!!!",$time,data_cnt);
                $display("    Cache Address = 0x%8h", ref_data_addr);
                $display("    Reference Cache Data = 0x%8h, Error Cache Data = 0x%8h",ref_data_rdata, data_rdata);
                $display("--------------------------------------------------------------");
                test_err <= 1'b1;
                #40;
                $finish;
            end
        end
    end

    //测试管理信号
    parameter TEST_TIME     = 410526;
    parameter REF_MISS_TIME = 1275;
    parameter DATA_CNT = 4001;
    reg [31:0] data_miss_time;

    initial begin
        $timeformat(-9,0," ns",10);
        data_miss_time = 0;
        while(aresetn) #5;
        $display("==============================================================");
        $display("Test begin!");
        #10000;
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
            if (data_cnt == DATA_CNT) begin
                test_end <= 1'b1;
                $display("==============================================================");
                $display("Test end!");
                #40;
                $fclose(data_addr_trace_ref);
                $fclose(data_data_trace_ref);
                if (test_err) begin
                    $display("Fail!!! Cache function errors! Check your code!");
                end
                else if (data_miss_time > REF_MISS_TIME) begin
                    $display("--------------------------------------------------------------");
                    $display("[%t] Error!!!",$time);
                    $display("    Reference  Cache Miss Rate = %d / %d", REF_MISS_TIME, TEST_TIME);
                    $display("    Your Error Cache Miss Rate = %d / %d", data_miss_time, TEST_TIME);
                    $display("--------------------------------------------------------------");
                    $display("Fail!!! LRU algorithm errors! Check your code!");
                end
                else begin
                    $display("----PASS!!!");
                end
                $finish;
            end
        end
    end

    //TEST CACHEOP
    integer cnt_op;
    reg   dcache_req;
    reg   [4 :0]  dcache_op;  
    reg   [31:0]  dcache_addr;
    reg   [19:0]  dcache_tag;
    reg   dcache_dirty; 
    reg   dcache_valid;         
    wire  dcache_ok;
    integer dcache_op_trace;
    initial begin
        cnt_op = 0;
        dcache_op_trace = $fopen(`DCACHE_OP_TEST,"r");
        dcache_req = 1;
        $fscanf(dcache_op_trace, "%h %h %h %h %h", dcache_op, dcache_addr,dcache_tag,dcache_valid,dcache_dirty);
    end
    always @(posedge aclk ) begin
        if (dcache_ok) begin
            cnt_op <= cnt_op + 1;
            $fscanf(dcache_op_trace, "%h %h %h %h %h", dcache_op, dcache_addr,dcache_tag,dcache_valid,dcache_dirty);
        end
    end
    always @(posedge aclk ) begin
        if (cnt_op == 8) begin
            dcache_req <= 0;
        end
    end



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

    wire  [3 :0] arid   ;
    wire  [31:0] araddr ;
    wire  [3 :0] arlen  ;
    wire  [2 :0] arsize ;
    wire  [1 :0] arburst;
    wire  [1 :0] arlock ;
    wire  [3 :0] arcache;
    wire  [2 :0] arprot ;
    wire         arvalid;
    wire         arready;

    wire  [3 :0] rid    ;
    wire  [31:0] rdata  ;
    wire  [1 :0] rresp  ;
    wire         rlast  ;
    wire         rvalid ;
    wire         rready ;

    wire  [3 :0] awid   ;
    wire  [31:0] awaddr ;
    wire  [3 :0] awlen  ;
    wire  [2 :0] awsize ;
    wire  [1 :0] awburst;
    wire  [1 :0] awlock ;
    wire  [3 :0] awcache;
    wire  [2 :0] awprot ;
    wire         awvalid;
    wire         awready;

    wire  [3 :0] wid    ;
    wire  [31:0] wdata  ;
    wire  [3 :0] wstrb  ;
    wire         wlast  ;
    wire         wvalid ;
    wire         wready ;

    wire  [3 :0] bid    ;
    wire  [1 :0] bresp  ;
    wire         bvalid ;
    wire         bready ;

    dcache_tp u_dcache_tp (
        .clk                  (aclk                ),
        .rst                  (aresetn             ),

        .dcache_req           (dcache_req          ),
        .dcache_op            (dcache_op           ),
        .dcache_addr          (dcache_addr         ),
        .dcache_tag           (dcache_tag          ),
        .dcache_valid         (dcache_valid        ),
        .dcache_dirty         (dcache_dirty        ),
        .dcache_ok            (dcache_ok           ),

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


    axi_crossbar_1 u_axi_crossbar_1(
        .aclk             (aclk   ),
        .aresetn          (aresetn),

        .s_axi_arid       ({data_cache_arid,    data_uncache_arid   }),
        .s_axi_araddr     ({data_cache_araddr,  data_uncache_araddr }),
        .s_axi_arlen      ({data_cache_arlen,   data_uncache_arlen  }),
        .s_axi_arsize     ({data_cache_arsize,  data_uncache_arsize }),
        .s_axi_arburst    ({data_cache_arburst, data_uncache_arburst}),
        .s_axi_arlock     ({data_cache_arlock,  data_uncache_arlock }),
        .s_axi_arcache    ({data_cache_arcache, data_uncache_arcache}),
        .s_axi_arprot     ({data_cache_arprot,  data_uncache_arprot }),
        .s_axi_arqos      (8'b0                                      ),
        .s_axi_arvalid    ({data_cache_arvalid, data_uncache_arvalid}),
        .s_axi_arready    ({data_cache_arready, data_uncache_arready}),

        .s_axi_rid        ({data_cache_rid,     data_uncache_rid    }),
        .s_axi_rdata      ({data_cache_rdata,   data_uncache_rdata  }),
        .s_axi_rresp      ({data_cache_rresp,   data_uncache_rresp  }),
        .s_axi_rlast      ({data_cache_rlast,   data_uncache_rlast  }),
        .s_axi_rvalid     ({data_cache_rvalid,  data_uncache_rvalid }),
        .s_axi_rready     ({data_cache_rready,  data_uncache_rready }),

        .s_axi_awid       ({data_cache_awid,    data_uncache_awid   }),
        .s_axi_awaddr     ({data_cache_awaddr,  data_uncache_awaddr }),
        .s_axi_awlen      ({data_cache_awlen,   data_uncache_awlen  }),
        .s_axi_awsize     ({data_cache_awsize,  data_uncache_awsize }),
        .s_axi_awburst    ({data_cache_awburst, data_uncache_awburst}),
        .s_axi_awlock     ({data_cache_awlock,  data_uncache_awlock }),
        .s_axi_awcache    ({data_cache_awcache, data_uncache_awcache}),
        .s_axi_awprot     ({data_cache_awprot,  data_uncache_awprot }),
        .s_axi_awqos      (8'b0                                      ),
        .s_axi_awvalid    ({data_cache_awvalid, data_uncache_awvalid}),
        .s_axi_awready    ({data_cache_awready, data_uncache_awready}),

        .s_axi_wid        ({data_cache_wid,     data_uncache_wid    }),
        .s_axi_wdata      ({data_cache_wdata,   data_uncache_wdata  }),
        .s_axi_wstrb      ({data_cache_wstrb,   data_uncache_wstrb  }),
        .s_axi_wlast      ({data_cache_wlast,   data_uncache_wlast  }),
        .s_axi_wvalid     ({data_cache_wvalid,  data_uncache_wvalid }),
        .s_axi_wready     ({data_cache_wready,  data_uncache_wready }),

        .s_axi_bid        ({data_cache_bid,     data_uncache_bid    }),
        .s_axi_bresp      ({data_cache_bresp,   data_uncache_bresp  }),
        .s_axi_bvalid     ({data_cache_bvalid,  data_uncache_bvalid }),
        .s_axi_bready     ({data_cache_bready,  data_uncache_bready }),

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

    axi_ram u_axi_ram_2         (
        .s_aresetn                (aresetn),
        .s_aclk                   (aclk   ),
        .s_axi_awid               (awid   ),
        .s_axi_awaddr             (awaddr ),
        .s_axi_awlen              ({4'b0000,awlen}  ),
        .s_axi_awsize             (awsize ),
        .s_axi_awburst            (awburst),
        .s_axi_awvalid            (awvalid),
        .s_axi_awready            (awready),
        .s_axi_wdata              (wdata  ),
        .s_axi_wstrb              (wstrb  ),
        .s_axi_wlast              (wlast  ),
        .s_axi_wvalid             (wvalid ),
        .s_axi_wready             (wready ),
        .s_axi_bid                (bid    ),
        .s_axi_bresp              (bresp  ),
        .s_axi_bvalid             (bvalid ),
        .s_axi_bready             (bready ),
        .s_axi_arid               (arid   ),
        .s_axi_araddr             (araddr ),
        .s_axi_arlen              ({4'b0000,arlen}  ),
        .s_axi_arsize             (arsize ),
        .s_axi_arburst            (arburst),
        .s_axi_arvalid            (arvalid),
        .s_axi_arready            (arready),
        .s_axi_rid                (rid    ),
        .s_axi_rresp              (rresp  ),
        .s_axi_rdata              (rdata  ),
        .s_axi_rlast              (rlast  ),
        .s_axi_rvalid             (rvalid ),
        .s_axi_rready             (rready )
    );
endmodule