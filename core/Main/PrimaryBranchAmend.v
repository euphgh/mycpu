// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/03 14:47
// Last Modified : 2022/07/30 10:23
// File Name     : PrimaryBranchAmend.v
// Description   :
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/07/03   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "../MyDefines.v"
module PrimaryBranchAmend(
    input	wire	clk,
    input	wire	rst,
    //////////////////////////////////////////////////
    //////////////     线信号输入      ///////////////{{{
    //////////////////////////////////////////////////
    // 流水线控制
    input	wire	                        REEXE_valid_w_i,
    input	wire	                        WB_allowin_w_i,
/*}}}*/
    //////////////////////////////////////////////////
    //////////////     线信号输出      ///////////////{{{
    //////////////////////////////////////////////////
    // 前递模式控制
    output	wire	[`GPR_NUM]              PBA_writeNum_w_o,    
    // 流水线控制
    output	wire	                        PBA_okToChange_w_o,            // 逐级互锁信号
    //output	wire	                        PBA_valid_w_o,              
    // 数据前递
    output	wire	[`SINGLE_WORD]          PBA_forwardData_w_o,        // 将上一周期的运算结果前递
    // ID回写信号
    output	wire	                        PBA_writeEnable_w_o,       // 回写使能
/*}}}*/
    ///////////////////////////////////////////////////
    //////////////     寄存器输出       ///////////////{{{
    ///////////////////////////////////////////////////
    output	reg	    [`SINGLE_WORD]  debug_wb_pc0,
    output	reg	    [3:0]           debug_wb_rf_wen0,
    output	reg	    [`GPR_NUM]      debug_wb_rf_wnum0,
    output	reg	    [`SINGLE_WORD]  debug_wb_rf_wdata0,
    /*}}}*/
    ///////////////////////////////////////////////////
    //////////////     寄存器输入       ///////////////{{{
    ///////////////////////////////////////////////////
    input	wire	[`GPR_NUM]              REEXE_writeNum_i,             // 回写寄存器数值,0为不回写
    input	wire	[`SINGLE_WORD]          REEXE_VAddr_i,                // 用于debug和异常处理
    input	wire    [`SINGLE_WORD]          REEXE_regData_i        
    /*}}}*/
);
    //自动定义
    /*autodef*/
    //Intersegment_register{{{

    wire            needClear;
    wire            needUpdata;

	reg	[`GPR_NUM]			REEXE_writeNum_r_i;
	reg	[`SINGLE_WORD]			REEXE_VAddr_r_i;
	reg	[`SINGLE_WORD]			REEXE_regData_r_i;
    always @(posedge clk) begin
        if (!rst || needClear) begin
			REEXE_writeNum_r_i	<=	'b0;
			REEXE_VAddr_r_i	<=	'b0;
			REEXE_regData_r_i	<=	'b0;
        end
        else if (needUpdata) begin
			REEXE_writeNum_r_i	<=	REEXE_writeNum_i;
			REEXE_VAddr_r_i	<=	REEXE_VAddr_i;
			REEXE_regData_r_i	<=	REEXE_regData_i;
        end
    end
    /*}}}*/
    // 线信号处理{{{
    assign PBA_writeNum_w_o = REEXE_writeNum_r_i;
    assign PBA_forwardData_w_o  = REEXE_regData_r_i;
    // 流水线互锁
    reg hasData;
    wire ready = 1'b1;
    assign PBA_okToChange_w_o = !hasData || ready;
    wire needFlush = 1'b0;
    wire PBA_valid_w_o = hasData && ready;
    assign needUpdata = WB_allowin_w_i && REEXE_valid_w_i;
    assign needClear  = (!REEXE_valid_w_i&&WB_allowin_w_i) || needFlush;
    always @(posedge clk) begin
        if(!rst || needClear) begin
            hasData <=  1'b0;
        end
        else if (WB_allowin_w_i)
            hasData <=  REEXE_valid_w_i;
    end
    /*}}}*/
    // 传递数值{{{
    assign PBA_writeEnable_w_o    = |REEXE_writeNum_r_i && PBA_valid_w_o;
    // }}}
    // debugSignal{{{
    always @(posedge clk) begin
        if (!rst) begin
            debug_wb_pc0        <=  `ZEROWORD;
            debug_wb_rf_wen0    <=  4'b0;
            debug_wb_rf_wnum0   <=  5'b0;
            debug_wb_rf_wdata0  <=  `ZEROWORD;
        end
        else begin
            debug_wb_pc0        <=  REEXE_VAddr_r_i;
            debug_wb_rf_wen0    <=  {4{PBA_writeEnable_w_o}};
            debug_wb_rf_wnum0   <=  PBA_writeNum_w_o;
            debug_wb_rf_wdata0  <=  PBA_forwardData_w_o;
        end
    end
    // }}}
endmodule

