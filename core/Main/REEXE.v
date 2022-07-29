// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/03 14:35
// Last Modified : 2022/07/29 21:25
// File Name     : REEXE.v
// Description   : 延迟执行段，先阶段只用于数据前递
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/07/03   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "MyDefines.v"
module REEXE(
    input	wire	clk,
    input	wire	rst,
    //////////////////////////////////////////////////
    //////////////     线信号输入      ///////////////{{{
    //////////////////////////////////////////////////
    // 流水线控制
    input	wire	                        PBA_allowin_w_i,
    input	wire	                        SBA_valid_w_i,
    input	wire	                        MEM_allowin_w_i,
/*}}}*/
    //////////////////////////////////////////////////
    //////////////     线信号输出      ///////////////{{{
    //////////////////////////////////////////////////
    // 流水线控制
    output	wire	                        REEXE_allowin_w_o,            // 逐级互锁信号
    output	wire	                        REEXE_valid_w_o,              // 给下一级流水线决定是否采样
    // 前递模式控制
    output	wire	                        REEXE_forwardMode_w_o,    
    output	wire	[`GPR_NUM]              REEXE_writeNum_w_o,    
/*}}}*/
    ///////////////////////////////////////////////////
    //////////////     寄存器输入       ///////////////{{{
    ///////////////////////////////////////////////////
    input	wire	[`GPR_NUM]              SBA_writeNum_i,             // 回写寄存器数值,0为不回写
    input	wire	[`SINGLE_WORD]          SBA_VAddr_i,             // 用于debug和异常处理
    // 算数,位移
    input	wire    [`SINGLE_WORD]          SBA_aluRes_i,	        
/*}}}*/
    ///////////////////////////////////////////////////
    //////////////     寄存器输出       ///////////////{{{
    ///////////////////////////////////////////////////
    output	wire	[`GPR_NUM]              REEXE_writeNum_o,           // 回写寄存器数值,0为不回写
    output	wire	[`SINGLE_WORD]          REEXE_VAddr_o,              // 用于debug和异常处理
    // 算数,位移
    output	wire    [`SINGLE_WORD]          REEXE_regData_o
/*}}}*/
);
    //自动定义
    /*autodef*/
    //Intersegment_register{{{

    wire            needClear;
    wire            needUpdata;

	reg	[`GPR_NUM]			SBA_writeNum_r_i;
	reg	[`SINGLE_WORD]			SBA_VAddr_r_i;
	reg	[`SINGLE_WORD]			SBA_aluRes_r_i;
    always @(posedge clk) begin
        if (!rst || needClear) begin
			SBA_writeNum_r_i	<=	'b0;
			SBA_VAddr_r_i	<=	'b0;
			SBA_aluRes_r_i	<=	'b0;
        end
        else if (needUpdata) begin
			SBA_writeNum_r_i	<=	SBA_writeNum_i;
			SBA_VAddr_r_i	<=	SBA_VAddr_i;
			SBA_aluRes_r_i	<=	SBA_aluRes_i;
        end
    end
    ///*}}}*/
    // 线信号处理{{{
    assign REEXE_writeNum_w_o     = SBA_writeNum_r_i;
    // 流水线互锁
    reg hasData;
    wire ready = 1'b1;
    assign REEXE_forwardMode_w_o  = hasData && ready;
    assign REEXE_valid_w_o    = hasData && ready && MEM_allowin_w_i;
    assign REEXE_allowin_w_o  = !hasData || (ready && PBA_allowin_w_i);
    wire   ok_to_change = REEXE_allowin_w_o && MEM_allowin_w_i;
    assign needUpdata = ok_to_change && SBA_valid_w_i;
    // TODO 是否需要在清空流水线的时候allowin
    assign needClear  = (!SBA_valid_w_i&&ok_to_change);
    always @(posedge clk) begin
        if(!rst || needClear) begin
            hasData <=  1'b0;
        end
        else if (ok_to_change)
            hasData <=  SBA_valid_w_i;
    end
    // }}}
    // 简单寄存器输出{{{
    assign REEXE_writeNum_o     = SBA_writeNum_r_i;
    assign REEXE_VAddr_o        = SBA_VAddr_r_i;
    assign REEXE_regData_o      = SBA_aluRes_r_i;
    /*}}}*/
endmodule

