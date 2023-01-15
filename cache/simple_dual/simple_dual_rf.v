// simple-Dual-Port BRAM with Byte-wide
//      Write-First mode
// File: HDL_Coding_Techniques/rams/bytewrite_tdp_ram_wf.v
//
// ByteWide Write Enable, - WRITE_FIRST mode template - Vivado recomended
module simple_dual_rf #(
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
    output reg [(NUM_COL*COL_WIDTH)-1:0] doutA,

    input wire [NUM_COL-1:0] wen,
    input wire [ADDR_WIDTH-1:0] addrB,
    input wire [(NUM_COL*COL_WIDTH)-1:0] dinB
);
       // Core Memory  
       (* ram_style = "block" *) reg [(NUM_COL*COL_WIDTH)-1:0]            ram_block [(2**ADDR_WIDTH)-1:0];

       // Port-A Read-Only
       generate
           genvar                       i;
           for(i=0;i<NUM_COL;i=i+1) begin
               always @ (posedge clk) begin
                   if(en) begin
                       doutA[i*COL_WIDTH +: COL_WIDTH] <= ram_block[addrA][i*COL_WIDTH +: COL_WIDTH] ;
                   end
               end
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
