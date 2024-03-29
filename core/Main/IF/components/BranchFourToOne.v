// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/09 09:38
// Last Modified : 2022/08/03 10:11
// File Name     : BranchFourToOne.v
// Description   : 根据分支预测器预测的take，选择出正确的Dest和相应的数据
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/07/09   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "MyDefines.v"
module BranchFourToOne(
    input	wire	[`SINGLE_WORD]      fifthPC_i,
    input	wire	[`INST_NUM]         originEnable_i,
    input	wire	[`INST_NUM]         predTake_p_i,
    input	wire	[4*`SINGLE_WORD]    predDest_p_i,

    output	wire	[`SINGLE_WORD]      validDest_o,
    output	wire	                    validTake_o,
    output	wire	[`INST_NUM]         actualEnable_o,
    output	wire	                    needDelaySlot,
    output	wire	[`INST_NUM]         firstValidBit
);
    wire    [0:0]   predTake        [3:0];
    `UNPACK_ARRAY(1,4,predTake,predTake_p_i)
    wire    [`SINGLE_WORD]   predDest        [3:0];
    `UNPACK_ARRAY(`SINGLE_WORD_LEN,4,predDest,predDest_p_i)
    wire    [3:0]   isFirstBranch   ;
    assign isFirstBranch[0] =     predTake[0] && originEnable_i[0];
    assign isFirstBranch[1] =   !(predTake[0] && originEnable_i[0]) &&   
                                  predTake[1] && originEnable_i[1];
    assign isFirstBranch[2] =   !(predTake[0] && originEnable_i[0]) && 
                                !(predTake[1] && originEnable_i[1]) &&
                                  predTake[2] && originEnable_i[2];
    assign isFirstBranch[3] =   !(predTake[0] && originEnable_i[0]) &&
                                !(predTake[1] && originEnable_i[1]) &&
                                !(predTake[2] && originEnable_i[2]) &&
                                  predTake[3] && originEnable_i[3];
    wire   [`INST_NUM]      branchEnable;
    assign branchEnable =   isFirstBranch[0] ? 4'b0011 :
                            isFirstBranch[1] ? 4'b0111 : 4'b1111 ;
    assign actualEnable_o  = branchEnable & originEnable_i;
    assign firstValidBit = {isFirstBranch[3],isFirstBranch[2],isFirstBranch[1],isFirstBranch[0]};
    // 四条指令中存在有效分支时，有效分支的目的地址
    // 四条指令中不存在有效分支时，使用最后一条有效PC的NNPC
    wire    [`SINGLE_WORD]   validBDest_up    [3:0];    
    wire    [`SINGLE_WORD]   validNDest_up = originEnable_i[3] ? fifthPC_i :        // 第5PC,即下一个四字对齐
                                                                (fifthPC_i-'d12);   // 第2PC,即00延迟槽指令后一条
    generate
    genvar i;
    for (i=0; i<4; i=i+1)	begin
            assign validBDest_up[i] = {32{isFirstBranch[i]}} & predDest[i];
        end
    endgenerate
    wire NoBranch = !(|isFirstBranch);
    assign validDest_o = validBDest_up[0]|validBDest_up[1]|validBDest_up[2]|validBDest_up[3]|
                        ({32{NoBranch}} & validNDest_up);
    assign validTake_o = |(predTake_p_i & firstValidBit);
    assign needDelaySlot = firstValidBit[3];
endmodule

