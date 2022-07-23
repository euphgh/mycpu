module ic_ft_tb(  );
    // ic_ft Inputs
    reg   clk;
    reg   rst;
    reg   inst_req;
    reg   inst_wr;
    reg   [1 :0]  inst_size;
    reg   [31:0]  inst_addr;
    wire   [7 :0]  inst_index;
    wire   [19:0]  inst_tag;
    reg   inst_hasException;
    reg   inst_unCache;
    reg   [31 :0]  inst_wdata;
    wire   arready;
    wire   [3 :0]  rid;
    wire  [31:0]  rdata;
    wire   [1 :0]  rresp;
    wire   rlast;
    wire   rvalid;
    wire   awready;
    wire   wready;
    wire   [3 :0]  bid;
    wire   bvalid;
    wire   [1 :0]  bresp;

    // ic_ft Outputs
    wire  [127:0]  inst_rdata;
    wire  inst_index_ok;
    wire  inst_data_ok;
    wire  [3 :0]  arid;
    wire  [31:0]  araddr;
    wire  [7 :0]  arlen;
    wire  [31:0]  arsize;
    wire  [1 :0]  arburst;
    wire  [1 :0]  arlock;
    wire  [3 :0]  arcache;
    wire  [2 :0]  arprot;
    wire  arvalid;
    wire  rready;
    wire  [3 :0]  awid;
    wire  [31:0]  awaddr;
    wire  [7 :0]  awlen;
    wire  [2 :0]  awsize;
    wire  [1 :0]  awburst;
    wire  [1 :0]  awlock;
    wire  [3 :0]  awcache;
    wire  [2 :0]  awprot;
    wire  awvalid;
    wire  [3 :0]  wid;
    wire  [31:0]  wdata;
    wire  [3 :0]  wstrb;
    wire  wlast;
    wire  wvalid;
    wire  bready;

    // 时钟与重置信号
    initial begin
        clk    = 1'b0;
        rst = 1'b0;
        #2000;
        rst = 1'b1;
        #1000
        inst_req = 1'b1;
        inst_addr = 32'b0;
        //inst_tag = 20'b0001_1111_1100_0000;
    end
    always #5 clk = ~clk;
    assign inst_index = inst_addr[11:4];
    assign inst_tag   = inst_addr[31:12];
    always @(posedge clk ) begin
        #1
        if(inst_data_ok) begin
            inst_addr <= inst_addr + 16;
        end
    end

    ic_ft  u_ic_ft (
        .clk                     ( clk                 ),
        .rst                     ( rst                 ),
        .inst_req                ( inst_req            ),
        .inst_wr                 ( inst_wr             ),
        .inst_size               ( inst_size           ),
        .inst_index              ( inst_index          ),
        .inst_tag                ( inst_tag            ),
        .inst_hasException       ( inst_hasException   ),
        .inst_unCache            ( inst_unCache        ),
        .inst_wdata              ( inst_wdata          ),
        .arready                 ( arready             ),
        .rid                     ( rid                 ),
        .rdata                   ( rdata               ),
        .rresp                   ( rresp               ),
        .rlast                   ( rlast               ),
        .rvalid                  ( rvalid              ),
        .awready                 ( awready             ),
        .wready                  ( wready              ),
        .bid                     ( bid                 ),
        .bvalid                  ( bvalid              ),
        .bresp                   ( bresp               ),

        .inst_rdata              ( inst_rdata          ),
        .inst_index_ok           ( inst_index_ok       ),
        .inst_data_ok            ( inst_data_ok        ),
        .arid                    ( arid                ),
        .araddr                  ( araddr              ),
        .arlen                   ( arlen               ),
        .arsize                  ( arsize              ),
        .arburst                 ( arburst             ),
        .arlock                  ( arlock              ),
        .arcache                 ( arcache             ),
        .arprot                  ( arprot              ),
        .arvalid                 ( arvalid             ),
        .rready                  ( rready              ),
        .awid                    ( awid                ),
        .awaddr                  ( awaddr              ),
        .awlen                   ( awlen               ),
        .awsize                  ( awsize              ),
        .awburst                 ( awburst             ),
        .awlock                  ( awlock              ),
        .awcache                 ( awcache             ),
        .awprot                  ( awprot              ),
        .awvalid                 ( awvalid             ),
        .wid                     ( wid                 ),
        .wdata                   ( wdata               ),
        .wstrb                   ( wstrb               ),
        .wlast                   ( wlast               ),
        .wvalid                  ( wvalid              ),
        .bready                  ( bready              )
    );

    axi_ram u_axi_ram         (
        .s_aresetn                (rst    ),
        .s_aclk                   (clk    ),
        .s_axi_awid               (awid   ),
        .s_axi_awaddr             (awaddr ),
        .s_axi_awlen              (awlen  ),
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
        .s_axi_arlen              (arlen  ),
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