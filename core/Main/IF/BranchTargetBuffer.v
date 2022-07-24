// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/06/29 10:48
// Last Modified : 2022/07/23 21:19
// File Name     : BranchTargetBuffer.v
// Description   :  1.  根据VPC预测该PC接下来的4条指令的地址，并在同一周期内一
//                      次返回4条指令的预测结果
//                  2.  接受BPU发送过来的修改申请，负责精细分子的修改和正确分
//                      支的修改在下一周期完成修改
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/06/29   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "MyDefines.v"
module BranchTargetBuffer (
    input   wire                    clk,
    input   wire                    rst,
    input   wire    [3:0]           PCR_instEnable_i,           // BTB根据PC所需要的指令进行预测和选择，不要的不选择
    input   wire    [`FOUR_WORDS]   PCG_VAddr_p_i,              // 给BTB的四条PC
    input	wire	                PCG_needDelaySlot_i,

    // BPU input
    input	wire	[`REPAIR_ACTION]    BSC_repairAction_w_i,   // IJTC行为
    input	wire	[`ALL_CHECKPOINT]   BSC_allCheckPoint_w_i,  // 三个分支预测单元共用一个
    input	wire	[`SINGLE_WORD]      BSC_erroVAdr_w_i,
    input	wire	                    BSC_correctTake_w_i,      // 跳转方向
    input	wire	[`SINGLE_WORD]      BSC_correctDest_w_i,      // 跳转目的

    // 给BPU的信号
    output	wire	[`SINGLE_WORD]      BTB_fifthVAddr_o,        // VAddr开始的第5条指令
    output	wire	[4*`SINGLE_WORD]    BTB_predDest_p_o,
    output  wire    [`INST_NUM]         BTB_instEnable_o,       // 表示BTB读出的4条目标指令那些是需要

    // 给DelaySlopt的信号
    output	wire	[`SINGLE_WORD]      BTB_validDest_o,
    output	wire	                    BTB_validTake_o,
    output	wire	                    BTB_needDelaySlot_o,
    output	wire	                    BTB_DelaySlotIsGetted_o
);
/*
* BTB获取PC的指令使能，如果指令不被使能，则生成下一条PC的时候无需考虑该指令是
* 否分支，否则需要考虑
* 考虑原则按照原计划分支和延迟槽的计划来
* 也测结果为不跳转的时候，即Valid = Flase目的为PC+8
*/
    /*autodef*/
    //Start of automatic define
    //Start of automatic reg
    //Define flip-flop registers here
    //Define combination registers here
    //End of automatic reg
    //Start of automatic wire
    //Define assign wires here
    //Define instance wires here
    wire [`INST_NUM]            firstValidBit                   ;
    wire                        needDelaySlot                   ; // WIRE_NEW
    //End of automatic wire
    //End of automatic define
    wire [31:0]                 VAddr_i                         ;
    wire [31:0]                 nextVAddr_i                     ;
    wire [`SINGLE_WORD] destination[3:0];
    `PACK_ARRAY(`SINGLE_WORD_LEN,4,destination,BTB_predDest_p_o)
    assign VAddr_i = PCG_VAddr_p_i[31:0];
    assign nextVAddr_i = {VAddr_i[31:4]+28'b1,2'b00,VAddr_i[1:0]};
    assign destination[0] = {VAddr_i[31:4],2'b10,VAddr_i[1:0]};
    assign destination[1] = {VAddr_i[31:4],2'b11,VAddr_i[1:0]};
    assign destination[2] = {nextVAddr_i[31:4],2'b00,VAddr_i[1:0]};
    assign destination[3] = {nextVAddr_i[31:4],2'b01,nextVAddr_i[1:0]};
    wire   [3:0] BTB_predTake_p_o = 4'b0;

    assign BTB_fifthVAddr_o = nextVAddr_i;
    assign BTB_DelaySlotIsGetted_o  = !PCG_needDelaySlot_i;
    assign BTB_needDelaySlot_o      = needDelaySlot;
    BranchFourToOne BranchFourToOne_u(
        .fifthPC_i              (BTB_fifthVAddr_o                 ), //input
        .originEnable_i         (PCR_instEnable_i                 ), //input
        .predTake_p_i           (BTB_predTake_p_o                 ), //input
        .predDest_p_i           (BTB_predDest_p_o                 ), //input
        .validDest_o            (BTB_validDest_o                  ), //output
        .validTake_o            (BTB_validTake_o                  ), //output
        .actualEnable_o         (BTB_instEnable_o                 ), //output
        .firstValidBit          (firstValidBit[`INST_NUM]         ),  //output
        /*autoinst*/
        .needDelaySlot          (needDelaySlot                  )  //output
    );
endmodule

