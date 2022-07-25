// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/04 15:23
// Last Modified : 2022/07/25 14:51
// File Name     : FirstCacheTrace.v
// Description   : 用于模拟Cache三段流水的过程，掌握Cache取数据的过程
//         
//
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/07/04   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "MyDefines.v"
module FirstCacheTrace (
    input	wire	clk,
    input	wire	rst,

    // 总线接口{{{
    input	wire	                    inst_req,
    input	wire	                    inst_index_ok,
/*}}}*/
    // PC寄存器接口{{{
    input   wire    [`INST_NUM]         PCR_instEnable_i,    // 表示此次读出的4条目标指令那些是需要的
    input   wire    [`SINGLE_WORD]      PCR_VAddr_i,         // to TLB
    input 	wire    [`EXCCODE]          PCR_ExcCode_i,
    input	wire 	                    PCR_hasException_i,  // 表明存在异常
/*}}}*/
    // 取消信号{{{
    input	wire	                    BSC_needCancel_w_i,
    input	wire	                    CP0_excOccur_w_i,
/*}}}*/
    // BTB接口{{{
    input	wire	[4*`SINGLE_WORD]    BTB_predDest_p_i,
    input	wire	[`SINGLE_WORD]      BTB_fifthVAddr_i,
    input   wire    [`INST_NUM]         BTB_instEnable_i,   // 表示BTB读出的4条目标指令那些是需要
    // BTB最终预测结果
    input	wire	[`SINGLE_WORD]      BTB_validDest_i,
    input	wire	                    BTB_validTake_i,
    /*}}}*/
    input	wire	                    PCG_needDelaySlot_i,
    // 流水线互锁{{{
    input	wire	                    SCT_allowin_w_i,
    output	wire                        FCT_valid_o,
/*}}}*/
    //  寄存器输出{{{
    // BTB信息
    output	reg 	[4*`SINGLE_WORD]    FCT_predDest_p_o,
    output  reg     [`INST_NUM]         FCT_BTBInstEnable_o,    // 表示BTB读出的4条目标指令那些是需要
    output	reg	    [`SINGLE_WORD]      FCT_BTBfifthVAddr_o,
    output	reg	                        FCT_needDelaySlot_o,
    // BTB最终预测结果
    output	reg	    [`SINGLE_WORD]      FCT_BTBValidDest_o,
    output	reg	                        FCT_BTBValidTake_o,
    // 基本信息
    output	reg		[`INST_NUM]         FCT_originEnable_o,     // PCR寄存器的使能
    output	reg     [`SINGLE_WORD]      FCT_VAddr_o,
    output	reg	                        FCT_hasException_o,
    output	reg	    [`EXCCODE]          FCT_ExcCode_o,
    output	reg	                        FCT_isCanceled_o
/*}}}*/
);
    reg hasData;
    assign FCT_valid_o = hasData;
    wire needCancel = (BSC_needCancel_w_i || CP0_excOccur_w_i);
    // 断言: 在indexok的时候，Cache的第二段寄存器中一定没有数据
    wire myAsset = !(inst_req && inst_index_ok && !SCT_allowin_w_i);
    wire ready_go = hasData && SCT_allowin_w_i;
    always @(posedge clk) begin
        if(!rst || (ready_go && !inst_index_ok)) begin
            hasData         <=  `FALSE;
            FCT_VAddr_o     <=  `ZEROWORD;
            FCT_hasException_o   <=  `FALSE;
            FCT_ExcCode_o   <=  `NOEXCCODE;
            FCT_predDest_p_o<=  0 ;
            FCT_BTBValidTake_o  <=  `FALSE; 
            FCT_BTBValidDest_o  <=  `ZEROWORD;
            FCT_BTBInstEnable_o <=  4'b0;
            FCT_originEnable_o  <=  4'b0;
            FCT_BTBfifthVAddr_o <=  `ZEROWORD; 
            FCT_needDelaySlot_o <=  `FALSE; 
            FCT_isCanceled_o    <=  `FALSE;
        end
        else if (inst_index_ok && inst_req) begin
            hasData         <=  `TRUE;
            FCT_VAddr_o     <=  PCR_VAddr_i;
            FCT_hasException_o  <=  PCR_hasException_i;
            FCT_ExcCode_o   <=  PCR_ExcCode_i;
            FCT_isCanceled_o<=  (BSC_needCancel_w_i||CP0_excOccur_w_i);
            FCT_predDest_p_o<=  BTB_predDest_p_i ;

            FCT_BTBValidTake_o  <=  BTB_validTake_i; 
            FCT_BTBValidDest_o  <=  BTB_validDest_i;
            FCT_BTBInstEnable_o <=  BTB_instEnable_i;
            FCT_originEnable_o  <=  PCR_instEnable_i;

            FCT_BTBfifthVAddr_o <=  BTB_fifthVAddr_i; 
            FCT_needDelaySlot_o <=  PCG_needDelaySlot_i; 
        end
        else if (hasData && needCancel) begin
            FCT_isCanceled_o    <= `TRUE;
        end
    end
endmodule

