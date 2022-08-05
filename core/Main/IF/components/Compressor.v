// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/08 08:47
// Last Modified : 2022/07/08 09:07
// File Name     : Compressor.v
// Description   : 根据实际的指令使能信号,生成实际有效数目、压缩后的使能、每个
//                  位的指令选择信号
//
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/07/08   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "../../../MyDefines.v"
module Compressor (
    input	wire	[`INST_NUM]     actualEnable,
    output	wire	[`INST_NUM]     outputEnable,
    output	wire	[2:0]           outputNumber,
    output	wire	[4*`INST_NUM]   instSelect_p
);
    wire    [`INST_NUM] instSelect  [`INST_NUM];
    assign  instSelect[0] = actualEnable[0] ? 4'b0001 :
                            actualEnable[1] ? 4'b0010 :
                            actualEnable[2] ? 4'b0100 :
                            actualEnable[3] ? 4'b1000 : 4'b0;
    assign  instSelect[1] = (actualEnable[0] && actualEnable[1]) ? 4'b0010  :
                            (actualEnable[1] && actualEnable[2]) ? 4'b0100  :
                            (actualEnable[2] && actualEnable[3]) ? 4'b1000  :   4'b0;
    assign  instSelect[2] = (actualEnable[0] && actualEnable[1] && actualEnable[2]) ? 4'b0100 :
                            (actualEnable[1] && actualEnable[2] && actualEnable[3]) ? 4'b1000 : 4'b0000;
    assign  instSelect[3] = {(&actualEnable),3'b0};
    `PACK_ARRAY(4,4,instSelect,instSelect_p)
    assign  outputNumber  = ({3{(actualEnable==4'b0001)||
                                (actualEnable==4'b0010)||
                                (actualEnable==4'b0100)||
                                (actualEnable==4'b1000)}} & 3'd1) |
                            ({3{(actualEnable==4'b0011)||
                                (actualEnable==4'b0101)||
                                (actualEnable==4'b1001)||
                                (actualEnable==4'b0110)||
                                (actualEnable==4'b1010)||
                                (actualEnable==4'b1100)}} & 3'd2) |
                            ({3{(actualEnable==4'b0111)||
                                (actualEnable==4'b1011)||
                                (actualEnable==4'b1101)||
                                (actualEnable==4'b1110)}} & 3'd3) |
                            ({3{(&actualEnable)}} & 3'd4 ) |
                            ({3{(!(|actualEnable))}} & 3'd0);
    assign outputEnable  =  ({4{(actualEnable==4'b0001)||
                                (actualEnable==4'b0010)||
                                (actualEnable==4'b0100)||
                                (actualEnable==4'b1000)}} & 4'b0001) |
                            ({4{(actualEnable==4'b0011)||
                                (actualEnable==4'b0101)||
                                (actualEnable==4'b1001)||
                                (actualEnable==4'b0110)||
                                (actualEnable==4'b1010)||
                                (actualEnable==4'b1100)}} & 4'b0011) |
                            ({4{(actualEnable==4'b0111)||
                                (actualEnable==4'b1011)||
                                (actualEnable==4'b1101)||
                                (actualEnable==4'b1110)}} & 4'b0111) |
                            ({4{(&actualEnable)}} & 4'b1111 );
endmodule                       
