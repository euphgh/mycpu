module axi_rmux (
    input wire clk, rst_n,
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
    reg is_cache_r;
    reg has_req_r;
    assign  {/*{{{*/
            arid,
            araddr,
            arlen,
            arsize,
            arburst,
            arlock ,
            arcache,
            arprot
        } = arvalid_1 ? {
                arid_1,
                araddr_1,
                arlen_1,
                arsize_1,
                arburst_1,
                arlock_1 ,
                arcache_1,
                arprot_1
            } : {
                arid_0,
                araddr_0,
                arlen_0,
                arsize_0,
                arburst_0,
                arlock_0 ,
                arcache_0,
                arprot_0
            };/*}}}*/
    assign arvalid =  arvalid_1 || arvalid_0;
    assign arready_0 = arready;
    assign arready_1 = arready;
    always @(posedge clk) begin/*{{{*/
        if (!rst_n) begin
            has_req_r <= 'd0;
            is_cache_r <= 'd0;
        end
        else if (arvalid && arready) begin
            has_req_r <= 1'b1;
            is_cache_r <= arvalid_0;
        end
        else if (rvalid && rready && rlast) begin
            has_req_r <= 1'b0;
        end
    end/*}}}*/

    assign  {/*{{{*/
        rid_1   ,
        rdata_1 ,
        rresp_1 ,
        rlast_1
        } = {
            rid   ,
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
            rid   ,
            rdata ,
            rresp ,
            rlast
            };/*}}}*/
    assign rvalid_0 = has_req_r && is_cache_r && rvalid;
    assign rvalid_1 = has_req_r && !is_cache_r && rvalid;
    assign rready = is_cache_r ?  rready_0 : rready_1;
endmodule
