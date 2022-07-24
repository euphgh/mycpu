// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/08 17:21
// Last Modified : 2022/07/23 21:53
// File Name     : TakeDestDecorder.v
// Description   : 根据四条指令码，解码该指令精细分支预测的选择子
//         
//
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/07/08   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "MyDefines.v"
module TakeDestDecorder(
    input	wire	[`FOUR_WORDS]       inst_rdata,
    input	wire	                    SCT_valid_i,
    output	wire	[4*`B_SELECT]       takeDestSel_p
);
    wire [`SINGLE_WORD] inst [3:0];
    `UNPACK_ARRAY(`SINGLE_WORD_LEN,4,inst,inst_rdata)
    wire [`B_SELECT]   takeDestSel      [3:0];
    wire [`B_SELECT]   takeDestSel_m    [3:0];
    /**
    *   后段预测    Direct    ,Dest
    *   1. B        PHT direct,BTB  Dest    5'b00101
    *   2. BAL      PHT direct,RSA  Dest    5'b10001
    *   3. J        1         ,BTB  Dest    5'b00110
    *   4. JAL      1         ,BTB  Dest    5'b00110
    *   5. JALR     1         ,IJTC Dest    5'b01010
    *   6. JR(1-30) 1         ,IJTC Dest    5'b01010
    *   7. JR($31)  1         ,RSA  Dest    5'b10010
    */

    `PACK_ARRAY(`B_SEL_LEN,4,takeDestSel,takeDestSel_p)
    wire [0:0]          isJRInst    [3:0];
    wire [0:0]          isRsFull    [3:0];
    generate
    genvar i;
    for (i = 0; i < 4; i=i+1)	begin
        assign isRsFull[i] = &inst[i][25:21];
        assign isJRInst[i] = takeDestSel_m[i][3] & takeDestSel_m[i][4]; 
        assign takeDestSel[i][0] = takeDestSel_m[i][0] && SCT_valid_i;
        assign takeDestSel[i][1] = takeDestSel_m[i][1] && SCT_valid_i;
        assign takeDestSel[i][2] = takeDestSel_m[i][2] && SCT_valid_i;
        assign takeDestSel[i][3] = (isJRInst[i] ? !isRsFull[i] : takeDestSel_m[i][3]) && SCT_valid_i;
        assign takeDestSel[i][4] = (isJRInst[i] ?  isRsFull[i] : takeDestSel_m[i][4]) && SCT_valid_i;
        /*autoDecoder_Start*/ /*{{{*/
        
	assign	takeDestSel_m[i][0]	=	(((inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31])) &
 ((inst[i][16]&!inst[i][17]&!inst[i][18]&!inst[i][19]&!inst[i][20]) | (!inst[i][16]&!inst[i][17]&!inst[i][18]&!inst[i][19]&!inst[i][20]) | (inst[i][16]&!inst[i][17]&!inst[i][18]&!inst[i][19]&inst[i][20]) | (!inst[i][16]&!inst[i][17]&!inst[i][18]&!inst[i][19]&inst[i][20]))) |
 (!((inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31])) &
 ((!inst[i][26]&!inst[i][27]&inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31]) | (inst[i][26]&!inst[i][27]&inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31]) | (inst[i][26]&inst[i][27]&inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31]) | (!inst[i][26]&inst[i][27]&inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31])));
	assign	takeDestSel_m[i][1]	=	(((!inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31])) &
 ((!inst[i][0]&!inst[i][1]&!inst[i][2]&inst[i][3]&!inst[i][4]&!inst[i][5]) | (inst[i][0]&!inst[i][1]&!inst[i][2]&inst[i][3]&!inst[i][4]&!inst[i][5]))) |
 (!((!inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31])) &
 ((!inst[i][26]&inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31]) | (inst[i][26]&inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31])));
	assign	takeDestSel_m[i][2]	=	(((inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31])) &
 ((inst[i][16]&!inst[i][17]&!inst[i][18]&!inst[i][19]&!inst[i][20]) | (!inst[i][16]&!inst[i][17]&!inst[i][18]&!inst[i][19]&!inst[i][20]))) |
 (!((inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31])) &
 ((!inst[i][26]&!inst[i][27]&inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31]) | (inst[i][26]&!inst[i][27]&inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31]) | (inst[i][26]&inst[i][27]&inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31]) | (!inst[i][26]&inst[i][27]&inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31]) | (!inst[i][26]&inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31]) | (inst[i][26]&inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31])));
	assign	takeDestSel_m[i][3]	=	(((!inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31])) &
 ((!inst[i][0]&!inst[i][1]&!inst[i][2]&inst[i][3]&!inst[i][4]&!inst[i][5]) | (inst[i][0]&!inst[i][1]&!inst[i][2]&inst[i][3]&!inst[i][4]&!inst[i][5]))) |
 (!((!inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31])) &
 (1'b0));
	assign	takeDestSel_m[i][4]	=	(((!inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31])) &
 ((!inst[i][0]&!inst[i][1]&!inst[i][2]&inst[i][3]&!inst[i][4]&!inst[i][5]))) |
 (!((!inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31])) &
 ((((inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31])) &
 ((inst[i][16]&!inst[i][17]&!inst[i][18]&!inst[i][19]&inst[i][20]) | (!inst[i][16]&!inst[i][17]&!inst[i][18]&!inst[i][19]&inst[i][20]))) |
 (!((inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31])) &
 (1'b0))));
        /*autoDecoder_End*/ /*}}}*/
    end
    endgenerate
endmodule

