module data_mux    (
    //icache input AXI{{{
    input [3 :0]    arid_dc   ,
    input [31:0]    araddr_dc ,
    input [3 :0]    arlen_dc  ,
    input [2 :0]    arsize_dc ,
    input [1 :0]    arburst_dc,
    input [1 :0]    arlock_dc ,
    input [3 :0]    arcache_dc,
    input [2 :0]    arprot_dc , 
    input           arvalid_dc,
    output          arready_dc,

    output [3 :0]   rid_dc    ,
    output [31:0]   rdata_dc  ,
    output [1 :0]   rresp_dc  ,
    output          rlast_dc  ,
    output          rvalid_dc ,
    input           rready_dc ,

    input [3 :0]    awid_dc   ,
    input [31:0]    awaddr_dc ,
    input [3 :0]    awlen_dc  ,
    input [2 :0]    awsize_dc ,
    input [1 :0]    awburst_dc,
    input [1 :0]    awlock_dc ,
    input [3 :0]    awcache_dc,
    input [2 :0]    awprot_dc ,
    input           awvalid_dc,
    output          awready_dc,

    input [3 :0]    wid_dc    ,
    input [31:0]    wdata_dc  ,
    input [3 :0]    wstrb_dc  ,
    input           wlast_dc  ,
    input           wvalid_dc ,
    output          wready_dc ,

    output  [3 :0]  bid_dc    ,
    output          bvalid_dc ,
    output  [1 :0]  bresp_dc  ,
    input           bready_dc,  /*}}}*/
    //iuncache input AXI{{{
    input [3 :0]    arid_du   ,
    input [31:0]    araddr_du ,
    input [3 :0]    arlen_du  ,
    input [2 :0]    arsize_du ,
    input [1 :0]    arburst_du,
    input [1 :0]    arlock_du ,
    input [3 :0]    arcache_du,
    input [2 :0]    arprot_du , 
    input           arvalid_du,
    output          arready_du,

    output [3 :0]   rid_du    ,
    output [31:0]   rdata_du  ,
    output [1 :0]   rresp_du  ,
    output          rlast_du  ,
    output          rvalid_du ,
    input           rready_du ,

    input [3 :0]    awid_du   ,
    input [31:0]    awaddr_du ,
    input [3 :0]    awlen_du  ,
    input [2 :0]    awsize_du ,
    input [1 :0]    awburst_du,
    input [1 :0]    awlock_du ,
    input [3 :0]    awcache_du,
    input [2 :0]    awprot_du ,
    input           awvalid_du,
    output          awready_du,

    input [3 :0]    wid_du    ,
    input [31:0]    wdata_du  ,
    input [3 :0]    wstrb_du  ,
    input           wlast_du  ,
    input           wvalid_du ,
    output          wready_du ,

    output  [3 :0]  bid_du    ,
    output          bvalid_du ,
    output  [1 :0]  bresp_du  ,
    input           bready_du,  /*}}}*/
    //master out AXI{{{
    output [3 :0] arid   ,
    output [31:0] araddr ,
    output [3 :0] arlen  ,
    output [2 :0] arsize ,
    output [1 :0] arburst,
    output [1 :0] arlock ,
    output [3 :0] arcache,
    output [2 :0] arprot , 
    output        arvalid,
    input         arready,

    input  [3 :0] rid    ,
    input  [31:0] rdata  ,
    input  [1 :0] rresp  ,
    input         rlast  ,
    input         rvalid ,
    output        rready ,

    output [3 :0] awid   ,
    output [31:0] awaddr ,
    output [3 :0] awlen  ,
    output [2 :0] awsize ,
    output [1 :0] awburst,
    output [1 :0] awlock ,
    output [3 :0] awcache,
    output [2 :0] awprot ,
    output        awvalid,
    input         awready,

    output [3 :0] wid    ,
    output [31:0] wdata  ,
    output [3 :0] wstrb  ,
    output        wlast  ,
    output        wvalid ,
    input         wready ,

    input  [3 :0] bid    ,
    input         bvalid ,
    input  [1 :0] bresp  ,
    output        bready  /*}}}*/
);
    axi_rmux axi_dc_du(/*{{{*/
        .arid_0(arid_dc),   
        .araddr_0(araddr_dc), 
        .arlen_0(arlen_dc),  
        .arsize_0(arsize_dc), 
        .arburst_0(arburst_dc),
        .arlock_0(arlock_dc), 
        .arcache_0(arcache_dc),
        .arprot_0(arprot_dc), 
        .arvalid_0(arvalid_dc),
        .arready_0(arready_dc),
        .rid_0(rid_dc),    
        .rdata_0(rdata_dc),  
        .rresp_0(rresp_dc),  
        .rlast_0(rlast_dc),  
        .rvalid_0(rvalid_dc), 
        .rready_0(rready_dc), 

        .arid_1   (arid_du   ),
        .araddr_1 (araddr_du ),
        .arlen_1  (arlen_du  ),
        .arsize_1 (arsize_du ),
        .arburst_1(arburst_du),
        .arlock_1 (arlock_du ),
        .arcache_1(arcache_du),
        .arprot_1 (arprot_du ),
        .arvalid_1(arvalid_du),
        .arready_1(arready_du),
        .rid_1    (rid_du    ),
        .rdata_1  (rdata_du  ),
        .rresp_1  (rresp_du  ),
        .rlast_1  (rlast_du  ),
        .rvalid_1 (rvalid_du ),
        .rready_1 (rready_du ),

        .arid   (arid   ),
        .araddr (araddr ),
        .arlen  (arlen  ),
        .arsize (arsize ),
        .arburst(arburst),
        .arlock (arlock ),
        .arcache(arcache),
        .arprot (arprot ),
        .arvalid(arvalid),
        .arready(arready),
        .rid    (rid    ),
        .rdata  (rdata  ),
        .rresp  (rresp  ),
        .rlast  (rlast  ),
        .rvalid (rvalid ),
        .rready (rready )
    );/*}}}*/

    assign {/*{{{*/
        awid,   
        awaddr, 
        awlen,  
        awsize, 
        awburst,
        awlock, 
        awcache,
        awprot
        } = awvalid_dc ? {
        awid_dc,   
        awaddr_dc, 
        awlen_dc,  
        awsize_dc, 
        awburst_dc,
        awlock_dc, 
        awcache_dc,
        awprot_dc
        } : {
        awid_du | 4'b0010,   
        awaddr_du, 
        awlen_du,  
        awsize_du, 
        awburst_du,
        awlock_du, 
        awcache_du,
        awprot_du 
        };/*}}}*/
    assign {/*{{{*/
        wid  ,   
        wdata, 
        wstrb,  
        wlast
        } = (wvalid_du && !wvalid_dc) ? {
        wid_du | 4'b0010, 
        wdata_du, 
        wstrb_du,  
        wlast_du
        } : {
        wid_dc,
        wdata_dc, 
        wstrb_dc,  
        wlast_dc
        };/*}}}*/
    assign awvalid = awvalid_dc || awvalid_du;
    assign awready_dc = awready;
    assign awready_du = awready;

    assign wvalid = wvalid_dc || wvalid_du;
    assign wready_dc = wvalid_dc && wready;
    assign wready_du = (!wvalid_dc && wvalid_du) && wready;

    assign  {/*{{{*/
        bid_du   ,
        bresp_du
        } = {
            bid & 4'b1101,
            bresp
            };/*}}}*/
    assign  {/*{{{*/
        bid_dc   ,
        bresp_dc
        } = {
            bid & 4'b1101,
            bresp
            };/*}}}*/
    assign bvalid_dc = !bid[1] && bvalid;
    assign bvalid_du =  bid[1] && bvalid;
    assign bready =  bid[1] ? bready_du : bready_dc;
endmodule
