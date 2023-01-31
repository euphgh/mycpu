module inst_mux (
    //icache input AXI{{{
    input [3 :0]    arid_ic   ,
    input [31:0]    araddr_ic ,
    input [3 :0]    arlen_ic  ,
    input [2 :0]    arsize_ic ,
    input [1 :0]    arburst_ic,
    input [1 :0]    arlock_ic ,
    input [3 :0]    arcache_ic,
    input [2 :0]    arprot_ic , 
    input           arvalid_ic,
    output          arready_ic,

    output [3 :0]   rid_ic    ,
    output [31:0]   rdata_ic  ,
    output [1 :0]   rresp_ic  ,
    output          rlast_ic  ,
    output          rvalid_ic ,
    input           rready_ic ,

    input [3 :0]    awid_ic   ,
    input [31:0]    awaddr_ic ,
    input [3 :0]    awlen_ic  ,
    input [2 :0]    awsize_ic ,
    input [1 :0]    awburst_ic,
    input [1 :0]    awlock_ic ,
    input [3 :0]    awcache_ic,
    input [2 :0]    awprot_ic ,
    input           awvalid_ic,
    output          awready_ic,

    input [3 :0]    wid_ic    ,
    input [31:0]    wdata_ic  ,
    input [3 :0]    wstrb_ic  ,
    input           wlast_ic  ,
    input           wvalid_ic ,
    output          wready_ic ,

    output  [3 :0]  bid_ic    ,
    output          bvalid_ic ,
    output  [1 :0]  bresp_ic  ,
    input           bready_ic,  /*}}}*/
    //iuncache input AXI{{{
    input [3 :0]    arid_iu   ,
    input [31:0]    araddr_iu ,
    input [3 :0]    arlen_iu  ,
    input [2 :0]    arsize_iu ,
    input [1 :0]    arburst_iu,
    input [1 :0]    arlock_iu ,
    input [3 :0]    arcache_iu,
    input [2 :0]    arprot_iu , 
    input           arvalid_iu,
    output          arready_iu,

    output [3 :0]   rid_iu    ,
    output [31:0]   rdata_iu  ,
    output [1 :0]   rresp_iu  ,
    output          rlast_iu  ,
    output          rvalid_iu ,
    input           rready_iu ,

    input [3 :0]    awid_iu   ,
    input [31:0]    awaddr_iu ,
    input [3 :0]    awlen_iu  ,
    input [2 :0]    awsize_iu ,
    input [1 :0]    awburst_iu,
    input [1 :0]    awlock_iu ,
    input [3 :0]    awcache_iu,
    input [2 :0]    awprot_iu ,
    input           awvalid_iu,
    output          awready_iu,

    input [3 :0]    wid_iu    ,
    input [31:0]    wdata_iu  ,
    input [3 :0]    wstrb_iu  ,
    input           wlast_iu  ,
    input           wvalid_iu ,
    output          wready_iu ,

    output  [3 :0]  bid_iu    ,
    output          bvalid_iu ,
    output  [1 :0]  bresp_iu  ,
    input           bready_iu,  /*}}}*/
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
    axi_rmux axi_ic_iu(/*{{{*/
        .arid_0(arid_ic),   
        .araddr_0(araddr_ic), 
        .arlen_0(arlen_ic),  
        .arsize_0(arsize_ic), 
        .arburst_0(arburst_ic),
        .arlock_0(arlock_ic), 
        .arcache_0(arcache_ic),
        .arprot_0(arprot_ic), 
        .arvalid_0(arvalid_ic),
        .arready_0(arready_ic),
        .rid_0(rid_ic),    
        .rdata_0(rdata_ic),  
        .rresp_0(rresp_ic),  
        .rlast_0(rlast_ic),  
        .rvalid_0(rvalid_ic), 
        .rready_0(rready_ic), 

        .arid_1   (arid_iu   ),
        .araddr_1 (araddr_iu ),
        .arlen_1  (arlen_iu  ),
        .arsize_1 (arsize_iu ),
        .arburst_1(arburst_iu),
        .arlock_1 (arlock_iu ),
        .arcache_1(arcache_iu),
        .arprot_1 (arprot_iu ),
        .arvalid_1(arvalid_iu),
        .arready_1(arready_iu),
        .rid_1    (rid_iu    ),
        .rdata_1  (rdata_iu  ),
        .rresp_1  (rresp_iu  ),
        .rlast_1  (rlast_iu  ),
        .rvalid_1 (rvalid_iu ),
        .rready_1 (rready_iu ),

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
        } =  {
        awid_ic,   
        awaddr_ic, 
        awlen_ic,  
        awsize_ic, 
        awburst_ic,
        awlock_ic, 
        awcache_ic,
        awprot_ic
        } | {
        awid_iu,   
        awaddr_iu, 
        awlen_iu,  
        awsize_iu, 
        awburst_iu,
        awlock_iu, 
        awcache_iu,
        awprot_iu 
        };/*}}}*/
    assign {/*{{{*/
        wid  ,   
        wdata, 
        wstrb,  
        wlast
        } = {
        wid_ic  ,   
        wdata_ic, 
        wstrb_ic,  
        wlast_ic
        } | {
        wid_iu  ,   
        wdata_iu, 
        wstrb_iu,  
        wlast_iu
        };/*}}}*/
    assign awvalid = awvalid_ic || awvalid_iu;
    assign wvalid = wvalid_ic || wvalid_iu;
    assign awready_ic = awready;
    assign awready_iu = awready;
    assign wready_ic = wready;
    assign wready_iu = wready;
    assign  {/*{{{*/
        bid_iu   ,
        bresp_iu
        } = {
            bid   ,
            bresp
            };/*}}}*/
    assign  {/*{{{*/
        bid_ic   ,
        bresp_ic
        } = {
            bid   ,
            bresp
            };/*}}}*/
    assign bvalid_ic = bvalid;
    assign bvalid_iu = bvalid;
    assign bready =  bready_ic | bready_iu;
endmodule
