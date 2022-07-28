`timescale 1ns / 1ps
`include "../Cacheconst.vh"
module dc_un_tb(  );

    // 时钟与重置信�?
    reg aclk;
    reg aresetn;
    // Data Uncache
    reg         data_uca_req    ;
    reg  [1 :0] data_uca_size   ;
    reg         data_uca_wr     ;
    reg  [31:0] data_uca_addr   ;
    reg  [31:0] data_uca_wdata  ;
    reg  [3 :0] data_uca_wstrb  ;
    wire [31:0] data_uca_rdata  ;
    wire        data_uca_addr_ok;
    wire        data_uca_data_ok;
    initial begin
        aclk    = 1'b0;
        aresetn = 1'b0;
        #2000;
        aresetn = 1'b1;
        data_uca_req = 1;
        data_uca_size = 0;
        data_uca_wr = 0;
        data_uca_addr = 32'h1fc132a2;
        data_uca_wdata = 0;
        data_uca_wstrb = 4'b0011;
    end
    always #5 aclk = ~aclk;

    always @(posedge aclk ) begin
        #1
        if (data_uca_data_ok) begin
            case (data_uca_size)
                2'b00: data_uca_size <= 2'b01;
                2'b01: data_uca_size <= 2'b10;
                2'b10: data_uca_size <= 2'b00;    
            endcase
        end
    end

    

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
    data_uncache u_data_uncache(
        .clk                  (aclk                ),
        .rst                  (aresetn             ),
        .data_req             (data_uca_req        ),
        .data_size            (data_uca_size       ),
        .data_wr              (data_uca_wr         ),
        .data_addr            (data_uca_addr       ),
        .data_wdata           (data_uca_wdata      ),
        .data_wstrb           (data_uca_wstrb      ),
        .data_rdata           (data_uca_rdata      ),
        .data_addr_ok         (data_uca_addr_ok    ),
        .data_data_ok         (data_uca_data_ok    ),
        .arid                 (arid   ),
        .araddr               (araddr ),
        .arlen                (arlen  ),
        .arsize               (arsize ),
        .arburst              (arburst),
        .arlock               (arlock ),
        .arcache              (arcache),
        .arprot               (arprot ), 
        .arvalid              (arvalid),
        .arready              (arready),
        .rid                  (rid    ),
        .rdata                (rdata  ),
        .rresp                (rresp  ),
        .rlast                (rlast  ),
        .rvalid               (rvalid ),
        .rready               (rready ),
        .awid                 (awid   ),
        .awaddr               (awaddr ),
        .awlen                (awlen  ),
        .awsize               (awsize ),
        .awburst              (awburst),
        .awlock               (awlock ),
        .awcache              (awcache),
        .awprot               (awprot ),
        .awvalid              (awvalid),
        .awready              (awready),
        .wid                  (wid    ),
        .wdata                (wdata  ),
        .wstrb                (wstrb  ),
        .wlast                (wlast  ),
        .wvalid               (wvalid ),
        .wready               (wready ),
        .bid                  (bid    ),
        .bvalid               (bvalid ),
        .bresp                (bresp  ),
        .bready               (bready )
    );

    axi_ram_1 u_axi_ram_2         (
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