// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/02 11:09
// Last Modified : 2022/07/23 10:53
// File Name     : SecondBranchAmend.v
// Description   : 位于PREMEM的阶段，用于处理EXE_UP计算出来的正确分支
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/07/02   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "MyDefines.v"
module SecondBranchAmend (
    input	wire	clk,
    input	wire	rst,
    //////////////////////////////////////////////////
    //////////////     线信号输入      ///////////////{{{
    //////////////////////////////////////////////////
    // 异常互锁
    input	wire	                        MEM_hasRisk_w_i,
    // 刷新流水线的信号
    input	wire	                        CP0_excOccur_w_i,            
    // 流水线控制
    input	wire	                        REEXE_allowin_w_i,
    input	wire	                        EXE_up_valid_w_i,
    input	wire	                        PREMEM_allowin_w_i,         // 上下段互锁
/*}}}*/
    //////////////////////////////////////////////////
    //////////////     线信号输出      ///////////////{{{
    //////////////////////////////////////////////////
    // 刷新流水线不刷新非阻塞
    output	wire	                        SBA_nonBlockMark_w_o, 
    // 异常互锁
    output  wire	                        SBA_hasRisk_w_o,            // 在进行EXE_UP的运算之后发现是有异常，如溢出，陷阱
    // 流水线控制
    output	wire	                        SBA_allowin_w_o,            // 逐级互锁信号
    output	wire	                        SBA_valid_w_o,              // 该信号可以用于给下一级流水线决定是否采样          
    // 数据前递
    output	wire	[`SINGLE_WORD]          SBA_forwardData_w_o,        // 将上一周期的运算结果前递
    // 数据前递模式控制
    output	wire	[`FORWARD_MODE]         SBA_forwardMode_w_o,    
    output	wire	[`GPR_NUM]              SBA_writeNum_w_o,    
    // 错误刷新
    output  wire                            SBA_flush_w_o,              //  表示分支错误，需要刷新流水线
    output  wire    [`SINGLE_WORD]          SBA_erroVAddr_w_o,          //  分支错误PC
    output  wire    [`SINGLE_WORD]          SBA_corrDest_w_o,           //  正确的分支目的
    output  wire                            SBA_corrTake_w_o,           //  正确的分支方向
    output	wire	[`ALL_CHECKPOINT]       SBA_checkPoint_w_o,         //  检查点信息
    output	wire	[`REPAIR_ACTION]        SBA_repairAction_w_o,       //  检查点信息
/*}}}*/
    /////////////////////////////////////////////////
    //////////////      寄存器输入     //////////////{{{
    /////////////////////////////////////////////////
    input	wire	[`GPR_NUM]              EXE_up_writeNum_i,          // 回写寄存器数值,0为不回写
    input	wire	[`SINGLE_WORD]          EXE_up_VAddr_i,             // 用于debug和异常处理
    // 算数,位移
    input	wire    [`SINGLE_WORD]          EXE_up_aluRes_i,	        
    // 非阻塞乘除
    input	wire	                        EXE_up_nonBlockMark_i,
    // 分支确认的信息
    input	wire	[`SINGLE_WORD]          EXE_up_corrDest_i,          // 预测的分支地址
    input	wire	                        EXE_up_corrTake_i,          // 预测的分支跳转
    input	wire	[`REPAIR_ACTION]        EXE_up_repairAction_i,      // 修复动作，包含是否需要修复的信号
    input	wire	[`ALL_CHECKPOINT]       EXE_up_checkPoint_i,
    input	wire                            EXE_up_branchRisk_i,        // 存在分支确认失败的风险
    //异常处理信息
    input	wire                            EXE_up_exceptionRisk_i,     // 存在i异常发生的风险
    input	wire    [`EXCCODE]              EXE_up_ExcCode_i,           // 异常信号	
    input	wire	                        EXE_up_hasException_i,      // 存在异常
/*}}}*/
    ///////////////////////////////////////////////////
    //////////////     寄存器输出       ///////////////{{{
    ///////////////////////////////////////////////////
    output	wire	[`GPR_NUM]              SBA_writeNum_o,             // 回写寄存器数值,0为不回写
    output	wire	[`SINGLE_WORD]          SBA_VAddr_o,                // 用于debug和异常处理
    // 非阻塞乘除
    output	wire	                        SBA_nonBlockMark_o,
    // 算数,位移
    output	wire    [`SINGLE_WORD]          SBA_aluRes_o,
    //异常处理信息
    output	wire                            SBA_exceptionRisk_o,        // 存在分支确认失败的风险
    output	wire    [`EXCCODE]              SBA_ExcCode_o,              // 异常信号
    output	wire	                        SBA_hasExceprion_o          // 存在异常
/*}}}*/
);
    //自动定义
    /*autodef*/
    //Intersegment_register{{{

    wire            needClear;
    wire            needUpdata;

	reg	[`GPR_NUM]			EXE_up_writeNum_r_i;
	reg	[`SINGLE_WORD]			EXE_up_VAddr_r_i;
	reg	[`SINGLE_WORD]			EXE_up_aluRes_r_i;
	reg	[0:0]			EXE_up_nonBlockMark_r_i;
	reg	[`SINGLE_WORD]			EXE_up_corrDest_r_i;
	reg	[0:0]			EXE_up_corrTake_r_i;
	reg	[`REPAIR_ACTION]			EXE_up_repairAction_r_i;
	reg	[`ALL_CHECKPOINT]			EXE_up_checkPoint_r_i;
	reg	[0:0]			EXE_up_branchRisk_r_i;
	reg	[0:0]			EXE_up_exceptionRisk_r_i;
	reg	[`EXCCODE]			EXE_up_ExcCode_r_i;
	reg	[0:0]			EXE_up_hasException_r_i;
    always @(posedge clk) begin
        if (!rst && needClear) begin
			EXE_up_writeNum_r_i	<=	'b0;
			EXE_up_VAddr_r_i	<=	'b0;
			EXE_up_aluRes_r_i	<=	'b0;
			EXE_up_nonBlockMark_r_i	<=	'b0;
			EXE_up_corrDest_r_i	<=	'b0;
			EXE_up_corrTake_r_i	<=	'b0;
			EXE_up_repairAction_r_i	<=	'b0;
			EXE_up_checkPoint_r_i	<=	'b0;
			EXE_up_branchRisk_r_i	<=	'b0;
			EXE_up_exceptionRisk_r_i	<=	'b0;
			EXE_up_ExcCode_r_i	<=	'b0;
			EXE_up_hasException_r_i	<=	'b0;
        end
        else if (needUpdata) begin
			EXE_up_writeNum_r_i	<=	EXE_up_writeNum_i;
			EXE_up_VAddr_r_i	<=	EXE_up_VAddr_i;
			EXE_up_aluRes_r_i	<=	EXE_up_aluRes_i;
			EXE_up_nonBlockMark_r_i	<=	EXE_up_nonBlockMark_i;
			EXE_up_corrDest_r_i	<=	EXE_up_corrDest_i;
			EXE_up_corrTake_r_i	<=	EXE_up_corrTake_i;
			EXE_up_repairAction_r_i	<=	EXE_up_repairAction_i;
			EXE_up_checkPoint_r_i	<=	EXE_up_checkPoint_i;
			EXE_up_branchRisk_r_i	<=	EXE_up_branchRisk_i;
			EXE_up_exceptionRisk_r_i	<=	EXE_up_exceptionRisk_i;
			EXE_up_ExcCode_r_i	<=	EXE_up_ExcCode_i;
			EXE_up_hasException_r_i	<=	EXE_up_hasException_i;
        end
    end
    ///*}}}*/
    // 线信号处理{{{
    assign SBA_hasRisk_w_o      = EXE_up_exceptionRisk_r_i || EXE_up_branchRisk_r_i || MEM_hasRisk_w_i;
    assign SBA_writeNum_w_o     = EXE_up_writeNum_r_i;
    assign SBA_forwardMode_w_o  = `FORWARD_MODE_REEXE;
    assign SBA_forwardData_w_o  = EXE_up_aluRes_r_i;
    assign SBA_erroVAddr_w_o = EXE_up_VAddr_r_i;
    assign SBA_corrDest_w_o = EXE_up_corrDest_r_i;
    assign SBA_corrTake_w_o = EXE_up_corrTake_r_i;
    assign SBA_repairAction_w_o = EXE_up_repairAction_r_i;
    assign SBA_flush_w_o = !SBA_hasRisk_w_o && EXE_up_repairAction_r_i[`NEED_REPAIR];
    assign SBA_checkPoint_w_o = EXE_up_checkPoint_r_i;
    assign SBA_nonBlockMark_w_o = EXE_up_nonBlockMark_r_i;
    // 流水线互锁
    reg hasData;
    wire ready = !(MEM_hasRisk_w_i&&EXE_up_repairAction_r_i[`NEED_REPAIR]);
    assign SBA_valid_w_o    = hasData && ready;
    assign SBA_allowin_w_o  = !hasData || (ready && REEXE_allowin_w_i);
    wire   ok_to_change = SBA_allowin_w_o && PREMEM_allowin_w_i;
    assign needUpdata = ok_to_change && EXE_up_valid_w_i;
    // TODO 是否需要在清空流水线的时候allowin
    wire needFlush = SBA_flush_w_o || CP0_excOccur_w_i;
    assign needClear  = (!EXE_up_valid_w_i&&ok_to_change) || needFlush;
    always @(posedge clk) begin
        if(!rst || needClear) begin
            hasData <=  1'b0;
        end
        else if (ok_to_change)
            hasData <=  EXE_up_valid_w_i;
    end
    // }}}
    // 寄存器输出{{{
    assign SBA_writeNum_o = EXE_up_writeNum_r_i;
    assign SBA_aluRes_o = EXE_up_aluRes_r_i;
    assign SBA_VAddr_o  = EXE_up_VAddr_r_i;
    assign SBA_exceptionRisk_o = EXE_up_hasException_r_i;
    assign SBA_ExcCode_o  = EXE_up_ExcCode_r_i;
    assign SBA_hasExceprion_o = EXE_up_hasException_r_i;
    assign SBA_nonBlockMark_o = EXE_up_nonBlockMark_r_i;
    // }}}
endmodule

