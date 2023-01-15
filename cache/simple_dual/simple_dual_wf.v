// simple-Dual-Port BRAM with Byte-wide
//      Write-First mode
// File: HDL_Coding_Techniques/rams/bytewrite_tdp_ram_wf.v
//
// ByteWide Write Enable, - WRITE_FIRST mode template - Vivado recomended
module simple_dual_wf #(
    //----------------------------------------------------------------------
    parameter   NUM_COL         =   4,
    parameter   COL_WIDTH       =   8,
    parameter   ADDR_WIDTH      =  10
    // Addr  Width in bits : 2**ADDR_WIDTH = RAM Depth
    //----------------------------------------------------------------------
) (
    input wire clk,
    input wire en, 
    input wire [ADDR_WIDTH-1:0] addrA,
    output wire [(NUM_COL*COL_WIDTH)-1:0] doutA,

    input wire [NUM_COL-1:0] wen,
    input wire [ADDR_WIDTH-1:0] addrB,
    input wire [NUM_COL*COL_WIDTH-1:0] dinB
);
       // Core Memory  
       (* ram_style = "block" *) reg [(NUM_COL*COL_WIDTH)-1:0]            ram_block [(2**ADDR_WIDTH)-1:0];
       // Port-A Read-Only
       generate
           genvar                       i;
           
           for(i=0;i<NUM_COL;i=i+1) begin
           reg [COL_WIDTH-1:0] tmp;
               always @ (posedge clk) begin
                   if(en) begin
                       tmp <= ram_block[addrA][i*COL_WIDTH +: COL_WIDTH] ;
                   end
               end
               reg [COL_WIDTH-1:0] wdata_r;
               reg col_r;
               always @(posedge clk) begin
                   if (en) begin
                       wdata_r <= dinB[i*COL_WIDTH +: COL_WIDTH];
                       col_r <= (addrA==addrB) && wen[i];
                   end
               end
               assign doutA[i*COL_WIDTH +: COL_WIDTH] = col_r ? wdata_r : tmp;
           end
       endgenerate

       // Port-B Write-Only:
       generate
           for(i=0;i<NUM_COL;i=i+1) begin
               always @ (posedge clk) begin
                   if(en) begin
                       if(wen[i]) begin
                           ram_block[addrB][i*COL_WIDTH +: COL_WIDTH] <= dinB[i*COL_WIDTH +: COL_WIDTH];
                       end
                   end     
               end
           end
       endgenerate

       endmodule // bytewrite_tdp_ram_wf
