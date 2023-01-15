`include "../main/Cacheconst.vh"
module axi_2to1_arbiter (
    //input AXI id 0{{{
    input [3 :0]    arid_0   ,
    input [31:0]    araddr_0 ,
    input [3 :0]    arlen_0  ,
    input [2 :0]    arsize_0 ,
    input [1 :0]    arburst_0,
    input [1 :0]    arlock_0 ,
    input [3 :0]    arcache_0,
    input [2 :0]    arprot_0 , 
    input           arvalid_0,
    output          arready_0,

    output [3 :0]   rid_0    ,
    output [31:0]   rdata_0  ,
    output [1 :0]   rresp_0  ,
    output          rlast_0  ,
    output          rvalid_0 ,
    input           rready_0 ,

    input [3 :0]    awid_0   ,
    input [31:0]    awaddr_0 ,
    input [3 :0]    awlen_0  ,
    input [2 :0]    awsize_0 ,
    input [1 :0]    awburst_0,
    input [1 :0]    awlock_0 ,
    input [3 :0]    awcache_0,
    input [2 :0]    awprot_0 ,
    input           awvalid_0,
    output          awready_0,

    input [3 :0]    wid_0    ,
    input [31:0]    wdata_0  ,
    input [3 :0]    wstrb_0  ,
    input           wlast_0  ,
    input           wvalid_0 ,
    output          wready_0 ,

    output  [3 :0]  bid_0    ,
    output          bvalid_0 ,
    output  [1 :0]  bresp_0  ,
    input           bready_0 ,  /*}}}*/
    //input AXI id 1{{{
    input [3 :0]    arid_1   ,
    input [31:0]    araddr_1 ,
    input [3 :0]    arlen_1  ,
    input [2 :0]    arsize_1 ,
    input [1 :0]    arburst_1,
    input [1 :0]    arlock_1 ,
    input [3 :0]    arcache_1,
    input [2 :0]    arprot_1 , 
    input           arvalid_1,
    output          arready_1,

    output [3 :0]   rid_1    ,
    output [31:0]   rdata_1  ,
    output [1 :0]   rresp_1  ,
    output          rlast_1  ,
    output          rvalid_1 ,
    input           rready_1 ,

    input [3 :0]    awid_1   ,
    input [31:0]    awaddr_1 ,
    input [3 :0]    awlen_1  ,
    input [2 :0]    awsize_1 ,
    input [1 :0]    awburst_1,
    input [1 :0]    awlock_1 ,
    input [3 :0]    awcache_1,
    input [2 :0]    awprot_1 ,
    input           awvalid_1,
    output          awready_1,

    input [3 :0]    wid_1    ,
    input [31:0]    wdata_1  ,
    input [3 :0]    wstrb_1  ,
    input           wlast_1  ,
    input           wvalid_1 ,
    output          wready_1 ,

    output  [3 :0]  bid_1    ,
    output          bvalid_1 ,
    output  [1 :0]  bresp_1  ,
    input           bready_1 ,  /*}}}*/
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
    assign {/*{{{*/
        araddr, 
        arlen,  
        arsize, 
        arburst,
        arlock, 
        arcache,
        arprot         
            } = arvalid_0 ? {
                araddr_0, 
                arlen_0,  
                arsize_0, 
                arburst_0,
                arlock_0, 
                arcache_0,
                arprot_0         
                } : {
                    araddr_1, 
                    arlen_1,  
                    arsize_1, 
                    arburst_1,
                    arlock_1, 
                    arcache_1,
                    arprot_1
                    };/*}}}*/
    assign arvalid = arvalid_0 || arvalid_1;
    assign arready_0 = arvalid_0 && arready;
    assign arready_1 = !arvalid_0 && arvalid_1 && arready;
    assign arid = arvalid_0 ? arid_0 : {arid_1 | 4'b0010};

    assign {/*{{{*/
        rid_0,
        rdata_0,  
        rresp_0,  
        rlast_0
        } = {
            (rid & 4'b1101),
            rdata,  
            rresp,  
            rlast 
        };/*}}}*/
    assign {/*{{{*/
        rid_1,
        rdata_1,  
        rresp_1,  
        rlast_1
        } = {
            (rid & 4'b1101),
            rdata,  
            rresp,  
            rlast 
        };/*}}}*/
    wire is_chl1 = rid==(`DCACHE_RID | 4'b0010);
    assign rvalid_0 = (!is_chl1) && rvalid ;
    assign rvalid_1 = (is_chl1) && rvalid ;
    assign rready = is_chl1 ? rready_1 : rready_0;

    assign awid    = awid_1;    
    assign awaddr  = awaddr_1;  
    assign awlen   = awlen_1;   
    assign awsize  = awsize_1;  
    assign awburst = awburst_1; 
    assign awlock  = awlock_1;  
    assign awcache = awcache_1; 
    assign awprot  = awprot_1;  
    assign awvalid = awvalid_1; 
    assign awready_1 = awready; 
    assign wid     = wid_1;     
    assign wdata   = wdata_1;   
    assign wstrb   = wstrb_1;   
    assign wlast   = wlast_1;   
    assign wvalid  = wvalid_1;  
    assign wready_1  = wready;  
    assign bid_1     = bid;     
    assign bvalid_1  = bvalid;  
    assign bresp_1   = bresp;   
    assign bready   = bready_1;  

endmodule
