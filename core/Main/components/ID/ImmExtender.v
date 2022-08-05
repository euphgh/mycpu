// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/13 10:36
// Last Modified : 2022/07/22 14:46
// File Name     : ImmExtender.v
// Description   : 立即数扩展器，可以实现0扩展和1扩展
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/07/13   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "../../../MyDefines.v"
module ImmExtender(
    input	wire	[25:0]              inst_index, // inst低26位
    input	wire	[`EXTEND_ACTION]    extendAction,
    output	wire	[`SINGLE_WORD]      extendedRes
);
    assign extendedRes =    extendAction[`ZERO_EXTEND_IMMED] ? {16'b0,inst_index[15:0]} :
                            extendAction[`SIGN_EXTEND_IMMED] ? {{16{inst_index[15]}},inst_index[15:0]} : {6'b0,inst_index};

endmodule

