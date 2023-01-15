`timescale 1ns / 1ps
module data_data_tp#(
    parameter LINE  = 128,
    parameter BLOCK = 8
)(
    input                     clk   ,
    input                     en    ,
    input  [4*BLOCK-1     :0] wen   ,
    input  [$clog2(LINE)-1:0] rindex,
    input  [$clog2(LINE)-1:0] windex,
    input  [32*BLOCK-1    :0] wdata ,
    output [32*BLOCK-1    :0] rdata
);

    /* reg  [32*BLOCK-1    :0] wdata_reg; */
    /* reg  [4*BLOCK-1     :0] wen_reg; */
    /* reg                     col_reg; */
    /* wire [32*BLOCK-1    :0] doutb; */
    /* wire col = (rindex == windex) && |wen; */
    /**/
    /* always @(posedge clk) begin */
    /*     col_reg    <= col; */
    /*     wdata_reg  <= wdata; */
    /*     wen_reg    <= wen; */
    /* end */
    /**/
    /* wire [32*BLOCK-1    :0] collison_output; */
    /**/
    /* genvar i; */
    /* generate */
    /*     for (i = 0; i < (32*BLOCK); i = i + 1) begin */
    /*         assign collison_output[i] = wen_reg[i >> 3] ? wdata_reg[i] : doutb[i]; */
    /*     end */
    /* endgenerate */
    /**/
    /* assign rdata = col_reg ? collison_output : doutb; */
    /**/
simple_dual_wf #(
    .NUM_COL         (   4*BLOCK),
    .COL_WIDTH       (   8),
    .ADDR_WIDTH      (  $clog2(LINE))
    ) inst_data (
    .clk(clk),
    .en(en), 
    .addrA(rindex),
    .doutA(rdata),
    .wen(wen),
    .addrB(windex),
    .dinB(wdata)
    );
endmodule
