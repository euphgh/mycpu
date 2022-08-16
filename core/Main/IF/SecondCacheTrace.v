// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/04 15:41
// Last Modified : 2022/08/04 19:27
// File Name     : SecondCacheTrace.v
// Description   : 跟踪Cache的数据流动
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/07/04   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "../../MyDefines.v"
module SecondCacheTrace (
    input	wire	clk,
    input	wire	rst,
    // 线信号输入{{{
    // RAS的预测结果{{{
    input	wire	[4*`SINGLE_WORD]        RAS_predDest_p_i,
    input	wire    [4*`RAS_CHECKPOINT]     RAS_checkPoint_p_i,
    input	wire	[3:0]                   RAS_predTake_p_i,
/*}}}*/
    // PHT预测接口{{{
    input	wire	[4*`PHT_CHECKPOINT]     PHT_checkPoint_p_i,
    input	wire	[3:0]                   PHT_predTake_p_i,
    input	wire	[3:0]                   PHT_valid_p_i,
    // }}}
    // 总线接口{{{
    input	wire	                    inst_data_ok,
    /*}}}*/
    // 取消信号{{{
    input	wire	                    BSC_needCancel_w_i, // 两种分支预测结果不同
    input	wire	                    CP0_excOccur_w_i,   // 异常发生
    input	wire	                    SBA_flush_w_i,      // 分支预测恢复
/*}}}*/
    // MMU异常信息{{{
    input	wire    [`EXCCODE]          MMU_ExcCode_i,
    input	wire	                    MMU_hasException_i,
    input	wire	                    MMU_isRefill_i,       // 表示是重填异常
/*}}}*/
    // 流水控制{{{
    output	wire	                SCT_allowin_w_o,
    output	wire	                SCT_valid_o,
/*}}}*/
/*}}}*/
    // 寄存器输入{{{
    input	wire                        FCT_valid_i,
    input	wire    [`SINGLE_WORD]      FCT_VAddr_i,
    input	wire	                    FCT_hasException_i,
    input	wire	[`EXCCODE]          FCT_ExcCode_i,
    input	wire		                FCT_isCanceled_i,
    input	wire  	[4*`SINGLE_WORD]    FCT_predDest_p_i,
    input	wire  	[3:0]               FCT_predTake_p_i,
    // 控制信号
    //  BTB中间变量
    input   wire    [`INST_NUM]         FCT_BTBInstEnable_i,    // 表示BTB读出的4条目标指令那些是需要
    input	wire	[`SINGLE_WORD]      FCT_BTBfifthVAddr_i,
    input	wire	                    FCT_needDelaySlot_i,
    // 基本信息
    input	wire    [`INST_NUM]         FCT_originEnable_i,     // PCR寄存器的使能
    input	wire	[`SINGLE_WORD]      FCT_BTBValidDest_i,
    input	wire	                    FCT_BTBValidTake_i,
/*}}}*/
    // 寄存器输出{{{
    //  BTB信息{{{
    output	reg 	[4*`SINGLE_WORD]        SCT_predDest_p_o,
    output	reg 	[3:0]                   SCT_predTake_p_o,
    output  reg     [`INST_NUM]             SCT_BTBInstEnable_o,    // 表示BTB读出的4条目标指令那些是需要
    output	reg	    [`SINGLE_WORD]          SCT_BTBfifthVAddr_o,
    output	reg	                            SCT_needDelaySlot_o,
    output	reg	    [`SINGLE_WORD]          SCT_BTBValidDest_o,
    output	reg	                            SCT_BTBValidTake_o,
/*}}}*/
    // 基本信息{{{
    output	reg		[`INST_NUM]             SCT_originEnable_o,     // PCR寄存器的使能
    output	reg     [`SINGLE_WORD]          SCT_VAddr_o,
    output	reg	                            SCT_hasException_o,
    output	reg	    [`EXCCODE]              SCT_ExcCode_o,
    output	reg                             SCT_isRefill_o,
/*}}}*/
    // BPU预测结果
    // RAS的预测结果{{{
    output	reg     [4*`SINGLE_WORD]        SCT_RAS_predDest_p_o,
    output	reg     [3:0]                   SCT_RAS_predTake_p_o,
    output	reg     [4*`RAS_CHECKPOINT]     SCT_RAS_checkPoint_p_o,
/*}}}*/
    // PHT预测接口{{{
    output	reg	    [4*`PHT_CHECKPOINT]     SCT_PHT_checkPoint_p_o,
    output	reg	    [3:0]                   SCT_PHT_predTake_p_o,
    output	reg     [3:0]                   SCT_PHT_valid_p_o
    // }}}
/*}}}*/
);
    reg		                        SCT_isCanceled_o;   //对该周期内出现的异常信号和分支失败信号采样
    reg hasData;
    assign SCT_valid_o = inst_data_ok && !SCT_isCanceled_o;
    assign SCT_allowin_w_o = !hasData || inst_data_ok;
    wire needCancel = (BSC_needCancel_w_i || CP0_excOccur_w_i || SBA_flush_w_i);
    always @(posedge clk) begin
        if(!rst || (inst_data_ok && !FCT_valid_i)) begin
            hasData             <=  `FALSE;
            SCT_originEnable_o  <=  4'b0; 
            SCT_BTBInstEnable_o <=  4'b0; 
            SCT_VAddr_o         <=  `ZEROWORD;
            SCT_hasException_o  <=  `FALSE;
            SCT_ExcCode_o       <=  `NOEXCCODE;
            SCT_isCanceled_o    <=  `FALSE;
            SCT_predDest_p_o    <=  'd0;
            SCT_predTake_p_o    <=  'd0;
            SCT_BTBValidDest_o  <=  `ZEROWORD;
            SCT_BTBValidTake_o  <=  `FALSE;
            SCT_BTBfifthVAddr_o <=  `ZEROWORD;
            SCT_needDelaySlot_o <=  `FALSE;
            SCT_RAS_predDest_p_o    <=  'd0;
            SCT_RAS_checkPoint_p_o  <=  'd0;
            SCT_PHT_checkPoint_p_o  <=  'd0; 
            SCT_PHT_predTake_p_o    <=  'd0;
            SCT_RAS_predTake_p_o    <=  'd0;
            SCT_PHT_valid_p_o       <=  'd0;
        end
        else if (SCT_allowin_w_o && FCT_valid_i) begin
            hasData             <=  `TRUE;
            SCT_originEnable_o  <=  FCT_originEnable_i; 
            SCT_BTBInstEnable_o <=  FCT_BTBInstEnable_i; 
            SCT_VAddr_o         <=  FCT_VAddr_i;
            SCT_hasException_o  <=  !FCT_hasException_i ? MMU_hasException_i : 1'b1;
            SCT_ExcCode_o       <=  FCT_hasException_i ? FCT_ExcCode_i : MMU_ExcCode_i;
            SCT_isCanceled_o    <=  FCT_isCanceled_i || needCancel;
            SCT_predDest_p_o    <=  FCT_predDest_p_i;
            SCT_predTake_p_o    <=  FCT_predTake_p_i;
            SCT_BTBValidDest_o  <=  FCT_BTBValidDest_i;
            SCT_BTBValidTake_o  <=  FCT_BTBValidTake_i;
            SCT_BTBfifthVAddr_o <=  FCT_BTBfifthVAddr_i;
            SCT_needDelaySlot_o <=  FCT_needDelaySlot_i;
            SCT_isRefill_o      <=  MMU_isRefill_i;
            SCT_RAS_predDest_p_o    <=  RAS_predDest_p_i    ;
            SCT_RAS_checkPoint_p_o  <=  RAS_checkPoint_p_i  ;
            SCT_PHT_checkPoint_p_o  <=  PHT_checkPoint_p_i  ; 
            SCT_PHT_predTake_p_o    <=  PHT_predTake_p_i    ;
            SCT_RAS_predTake_p_o    <=  RAS_predTake_p_i;
            SCT_PHT_valid_p_o       <=  PHT_valid_p_i;
        end
        else if (hasData && needCancel) begin
            SCT_isCanceled_o    <=  `TRUE;
        end
    end
endmodule
