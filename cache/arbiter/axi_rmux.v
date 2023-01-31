module axi_rmux (
    //input0 read AXI{{{
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
    input           rready_0 ,/*}}}*/
    //input1 read AXI{{{
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
    input           rready_1 ,/*}}}*/
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
    output        rready/*}}}*/
);
    assign  {/*{{{*/
            arid,
            araddr,
            arlen,
            arsize,
            arburst,
            arlock ,
            arcache,
            arprot
        } = arvalid_0 ? {
                arid_0,
                araddr_0,
                arlen_0,
                arsize_0,
                arburst_0,
                arlock_0 ,
                arcache_0,
                arprot_0
            } : {
                arid_1 | 4'b0010,
                araddr_1,
                arlen_1,
                arsize_1,
                arburst_1,
                arlock_1 ,
                arcache_1,
                arprot_1
            };/*}}}*/
    assign arvalid =  arvalid_1 || arvalid_0;
    assign arready_0 = arready;
    assign arready_1 = arready;

    assign  {/*{{{*/
        rid_1   ,
        rdata_1 ,
        rresp_1 ,
        rlast_1
        } = {
            rid & 4'b1101,
            rdata ,
            rresp ,
            rlast
            };/*}}}*/
    assign  {/*{{{*/
        rid_0   ,
        rdata_0 ,
        rresp_0 ,
        rlast_0
        } = {
            rid & 4'b1101,
            rdata ,
            rresp ,
            rlast
            };/*}}}*/
    assign rvalid_0 = !rid[1] && rvalid;
    assign rvalid_1 =  rid[1] && rvalid;
    assign rready =  rid[1] ?  rready_1 : rready_0;
endmodule
