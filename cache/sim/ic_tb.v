`timescale 1ns / 1ps
`include "../Cacheconst.vh"
`define ICACHE_ADDR_TRACE_FILE "D:/nscscc2022_group_v0.01/nscscc-group/func_test_v0.01/soc_axi_func/mycpu/cache/sim/trace/golden_trace_icache_1.txt"
`define ICACHE_DATA_TRACE_FILE "D:/nscscc2022_group_v0.01/nscscc-group/func_test_v0.01/soc_axi_func/mycpu/cache/sim/trace/golden_trace_icache_2.txt"

module ic_tb(  );

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
    
    //访存行为模拟
    reg test_err;
    reg test_end;
    reg [31:0] inst_cnt;

    integer inst_addr_trace_ref;
    integer inst_data_trace_ref;
    initial begin
        inst_cnt = 0;
        inst_req  = 1;
        inst_wr   = 0;
        inst_size = 2'b11;
        inst_hasException = 0;
        //TODO
        inst_unCache = 0;
        inst_wdata = 0;
        inst_addr_trace_ref = $fopen(`ICACHE_ADDR_TRACE_FILE,"r");
        inst_data_trace_ref = $fopen(`ICACHE_DATA_TRACE_FILE,"r");
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
        //inst_unCache <= $random %2;
        inst_tag <= inst_cpu_addr[31:12];
    end


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
                $display("    Cache Address = 0x%8h", ref_inst_cpu_addr);
                $display("    Reference Cache Data = 0x%8h, Error Cache Data = 0x%8h",ref_inst_data, test_inst_rdata[ref_inst_cpu_addr[3:2]]);
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
    parameter INST_CNT = 36236;
    reg [31:0] inst_miss_time;

    initial begin
        $timeformat(-9,0," ns",10);
        inst_miss_time = 0;
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
        if (!aresetn) begin
            test_end <= 1'b0;
        end
        //TODO
        else if (!test_end) begin
            if (inst_cnt == INST_CNT) begin
                test_end <= 1'b1;
                $display("==============================================================");
                $display("Test end!");
                #40;
                $fclose(inst_addr_trace_ref);
                $fclose(inst_data_trace_ref);
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
    wire  [3 :0] inst_uncache_awid   = 0;
    wire  [31:0] inst_uncache_awaddr = 0;
    wire  [3 :0] inst_uncache_awlen  = 0;
    wire  [2 :0] inst_uncache_awsize = 0;
    wire  [1 :0] inst_uncache_awburst= 0;
    wire  [1 :0] inst_uncache_awlock = 0;
    wire  [3 :0] inst_uncache_awcache= 0;
    wire  [2 :0] inst_uncache_awprot = 0;
    wire         inst_uncache_awvalid= 0;
    wire         inst_uncache_awready= 0;
    wire  [3 :0] inst_uncache_wid    = 0;
    wire  [31:0] inst_uncache_wdata  = 0;
    wire  [3 :0] inst_uncache_wstrb  = 0;
    wire         inst_uncache_wlast  = 0;
    wire         inst_uncache_wvalid = 0;
    wire         inst_uncache_wready = 0;
    wire  [3 :0] inst_uncache_bid    = 0;
    wire  [1 :0] inst_uncache_bresp  = 0;
    wire         inst_uncache_bvalid = 0;
    wire         inst_uncache_bready = 0;

    axi_ram_1 u_axi_ram         (
        .s_aresetn                (aresetn),
        .s_aclk                   (aclk   ),
        .s_axi_awid               (inst_uncache_awid   ),
        .s_axi_awaddr             (inst_uncache_awaddr ),
        .s_axi_awlen              ({4'b0000,inst_uncache_awlen}  ),
        .s_axi_awsize             (inst_uncache_awsize ),
        .s_axi_awburst            (inst_uncache_awburst),
        .s_axi_awvalid            (inst_uncache_awvalid),
        .s_axi_awready            (inst_uncache_awready),
        .s_axi_wdata              (inst_uncache_wdata  ),
        .s_axi_wstrb              (inst_uncache_wstrb  ),
        .s_axi_wlast              (inst_uncache_wlast  ),
        .s_axi_wvalid             (inst_uncache_wvalid ),
        .s_axi_wready             (inst_uncache_wready ),
        .s_axi_bid                (inst_uncache_bid    ),
        .s_axi_bresp              (inst_uncache_bresp  ),
        .s_axi_bvalid             (inst_uncache_bvalid ),
        .s_axi_bready             (inst_uncache_bready ),
        .s_axi_arid               (inst_uncache_arid   ),
        .s_axi_araddr             (inst_uncache_araddr ),
        .s_axi_arlen              ({4'b0000,inst_uncache_arlen}  ),
        .s_axi_arsize             (inst_uncache_arsize ),
        .s_axi_arburst            (inst_uncache_arburst),
        .s_axi_arvalid            (inst_uncache_arvalid),
        .s_axi_arready            (inst_uncache_arready),
        .s_axi_rid                (inst_uncache_rid    ),
        .s_axi_rresp              (inst_uncache_rresp  ),
        .s_axi_rdata              (inst_uncache_rdata  ),
        .s_axi_rlast              (inst_uncache_rlast  ),
        .s_axi_rvalid             (inst_uncache_rvalid ),
        .s_axi_rready             (inst_uncache_rready )
    );
    axi_ram_1 u_axi_ram_1         (
        .s_aresetn                (aresetn),
        .s_aclk                   (aclk   ),
        .s_axi_awid               (inst_cache_awid   ),
        .s_axi_awaddr             (inst_cache_awaddr ),
        .s_axi_awlen              ({4'b0000,inst_cache_awlen}  ),
        .s_axi_awsize             (inst_cache_awsize ),
        .s_axi_awburst            (inst_cache_awburst),
        .s_axi_awvalid            (inst_cache_awvalid),
        .s_axi_awready            (inst_cache_awready),
        .s_axi_wdata              (inst_cache_wdata  ),
        .s_axi_wstrb              (inst_cache_wstrb  ),
        .s_axi_wlast              (inst_cache_wlast  ),
        .s_axi_wvalid             (inst_cache_wvalid ),
        .s_axi_wready             (inst_cache_wready ),
        .s_axi_bid                (inst_cache_bid    ),
        .s_axi_bresp              (inst_cache_bresp  ),
        .s_axi_bvalid             (inst_cache_bvalid ),
        .s_axi_bready             (inst_cache_bready ),
        .s_axi_arid               (inst_cache_arid   ),
        .s_axi_araddr             (inst_cache_araddr ),
        .s_axi_arlen              ({4'b0000,inst_cache_arlen}  ),
        .s_axi_arsize             (inst_cache_arsize ),
        .s_axi_arburst            (inst_cache_arburst),
        .s_axi_arvalid            (inst_cache_arvalid),
        .s_axi_arready            (inst_cache_arready),
        .s_axi_rid                (inst_cache_rid    ),
        .s_axi_rresp              (inst_cache_rresp  ),
        .s_axi_rdata              (inst_cache_rdata  ),
        .s_axi_rlast              (inst_cache_rlast  ),
        .s_axi_rvalid             (inst_cache_rvalid ),
        .s_axi_rready             (inst_cache_rready )
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

endmodule