// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/03 14:35
// Last Modified : 2022/07/30 10:36
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
`include "../MyDefines.v"
module REEXE(
    input	wire	clk,
    input	wire	rst,
    //////////////////////////////////////////////////
    //////////////     线信号输入      ///////////////{{{
    //////////////////////////////////////////////////
    // 流水线控制
    input	wire	                        SBA_valid_w_i,
    input	wire	                        MEM_allowin_w_i,
    // 数据前递
    input	wire	[`SINGLE_WORD]          WB_forwardData_w_i, // 不包含非wload指令
/*}}}*/
    //////////////////////////////////////////////////
    //////////////     线信号输出      ///////////////{{{
    //////////////////////////////////////////////////
    // 流水线控制
    output	wire	                        REEXE_okToChange_w_o,            // 逐级互锁信号
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
    // 延迟执行{{{
    input	wire	                        SBA_notExc_i,            // 表示该指令是延迟执行指令
    input	wire	[`DELAY_MODE]           SBA_forwardSel0_i, 
    input	wire	[`DELAY_MODE]           SBA_forwardSel1_i, 
    input	wire	                        SBA_oprand0IsReg_i,       
    input	wire	                        SBA_oprand1IsReg_i,       
    input	wire	[2*`SINGLE_WORD]        SBA_preSrc_p_i,          // 指令自带的操作数
    input	wire	[2*`SINGLE_WORD]        SBA_readData_p_i,        
    input	wire	[`ALUOP]                SBA_aluOperator_i,
    // 前递数据{{{
    input	wire	[`SINGLE_WORD]          REEXE_regData_i,
    // }}}
    // }}}
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
    wire [`ALUOP]               aluop                           ;
    wire                        overflow                        ;
    wire [`SINGLE_WORD]         scr [1:0]                       ;
    wire [`SINGLE_WORD]         aluso                           ;
    /*autodef*/
    //Intersegment_register{{{

    wire            needClear;
    wire            needUpdata;

	reg	[`GPR_NUM]			SBA_writeNum_r_i;
	reg	[`SINGLE_WORD]			SBA_VAddr_r_i;
	reg	[`SINGLE_WORD]			SBA_aluRes_r_i;
	reg	[0:0]			SBA_notExc_r_i;
	reg	[`DELAY_MODE]			SBA_forwardSel0_r_i;
	reg	[`DELAY_MODE]			SBA_forwardSel1_r_i;
	reg	[0:0]			SBA_oprand0IsReg_r_i;
	reg	[0:0]			SBA_oprand1IsReg_r_i;
	reg	[2*`SINGLE_WORD]			SBA_preSrc_p_r_i;
	reg	[2*`SINGLE_WORD]			SBA_readData_p_r_i;
	reg	[`ALUOP]			SBA_aluOperator_r_i;
	reg	[`SINGLE_WORD]			REEXE_regData_r_i;
    always @(posedge clk) begin
        if (!rst || needClear) begin
			SBA_writeNum_r_i	<=	'b0;
			SBA_VAddr_r_i	<=	'b0;
			SBA_aluRes_r_i	<=	'b0;
			SBA_notExc_r_i	<=	'b0;
			SBA_forwardSel0_r_i	<=	'b0;
			SBA_forwardSel1_r_i	<=	'b0;
			SBA_oprand0IsReg_r_i	<=	'b0;
			SBA_oprand1IsReg_r_i	<=	'b0;
			SBA_preSrc_p_r_i	<=	'b0;
			SBA_readData_p_r_i	<=	'b0;
			SBA_aluOperator_r_i	<=	'b0;
			REEXE_regData_r_i	<=	'b0;
        end
        else if (needUpdata) begin
			SBA_writeNum_r_i	<=	SBA_writeNum_i;
			SBA_VAddr_r_i	<=	SBA_VAddr_i;
			SBA_aluRes_r_i	<=	SBA_aluRes_i;
			SBA_notExc_r_i	<=	SBA_notExc_i;
			SBA_forwardSel0_r_i	<=	SBA_forwardSel0_i;
			SBA_forwardSel1_r_i	<=	SBA_forwardSel1_i;
			SBA_oprand0IsReg_r_i	<=	SBA_oprand0IsReg_i;
			SBA_oprand1IsReg_r_i	<=	SBA_oprand1IsReg_i;
			SBA_preSrc_p_r_i	<=	SBA_preSrc_p_i;
			SBA_readData_p_r_i	<=	SBA_readData_p_i;
			SBA_aluOperator_r_i	<=	SBA_aluOperator_i;
			REEXE_regData_r_i	<=	REEXE_regData_i;
        end
    end
    ///*}}}*/
    // 线信号处理{{{
    // 流水线互锁
    reg hasData;
    wire ready = 1'b1;
    assign REEXE_okToChange_w_o = !hasData || ready;
    wire needFlush = 1'b0;
    assign REEXE_valid_w_o    = hasData && 
                                ready &&
                                MEM_allowin_w_i;
    assign needUpdata = MEM_allowin_w_i && SBA_valid_w_i;
    assign needClear  = (!SBA_valid_w_i&&MEM_allowin_w_i) || needFlush;
    always @(posedge clk) begin
        if(!rst || needClear) begin
            hasData <=  1'b0;
        end
        else if (MEM_allowin_w_i)
            hasData <=  SBA_valid_w_i;
    end
    assign REEXE_forwardMode_w_o  = hasData && ready;
    assign REEXE_writeNum_w_o     = SBA_writeNum_r_i;
    // }}}
    // 简单寄存器输出{{{
    assign REEXE_writeNum_o     = SBA_writeNum_r_i;
    assign REEXE_VAddr_o        = SBA_VAddr_r_i;
    /*}}}*/
    // 延迟执行{{{
    ALU ALU_u(/*{{{*/
      /*autoinst*/
        .scr0                   (scr[0]                         ), //input
        .scr1                   (scr[1]                         ), //input
        .aluop                  (aluop[`ALUOP]                  ), //input
        .overflow               (overflow                       ), //output
        .aluso                  (aluso[`SINGLE_WORD]            )  //output
    );
    assign aluop = SBA_aluOperator_r_i;
    /*}}}*/
    // 前递选择 {{{
    wire	    [`SINGLE_WORD]          readData          [1:0];            
    wire	    [`SINGLE_WORD]          SBA_oprand_up     [1:0];            
    wire	    [`DELAY_MODE]           SBA_forwardSel_up [1:0];        // 用于选择前递信号
    `UNPACK_ARRAY(`SINGLE_WORD_LEN,2,readData,SBA_readData_p_r_i)
    `UNPACK_ARRAY(`SINGLE_WORD_LEN,2,SBA_oprand_up,SBA_preSrc_p_r_i)
    assign SBA_forwardSel_up[0] = SBA_forwardSel0_r_i;
    assign SBA_forwardSel_up[1] = SBA_forwardSel1_r_i;
    wire        [`SINGLE_WORD]      updataRegFile_up[1:0];
    wire        [0:0]               srcIsReg        [1:0];
    assign srcIsReg[0] = SBA_oprand0IsReg_r_i;
    assign srcIsReg[1] = SBA_oprand1IsReg_r_i;
    generate   
        for (genvar i = 0; i < 2; i=i+1)	begin     
            // WB段数据再保存{{{
            reg [`SINGLE_WORD]  wb_savedData;
            reg                 useSavedWb;
            always @(posedge clk) begin
                if (!rst || needClear || needUpdata) begin
                    useSavedWb      <=  `FALSE;
                end
                else if (SBA_forwardSel_up[i][`DELAY_MEM_BIT]) begin
                    useSavedWb      <=  `TRUE;
                end
                if (!rst || needClear || needUpdata) begin
                    wb_savedData    <=  `ZEROWORD;
                end
                else if (SBA_forwardSel_up[i][`DELAY_MEM_BIT] && !useSavedWb) begin
                    wb_savedData    <=  WB_forwardData_w_i;
                end
            end
            wire [`SINGLE_WORD] wb_data = useSavedWb ? wb_savedData : WB_forwardData_w_i;
            // }}}
            assign updataRegFile_up[i] =    
                                            ({32{SBA_forwardSel_up[i][`DELAY_ID_BIT]}}         & readData[i]           )|
                                            ({32{SBA_forwardSel_up[i][`DELAY_REEXE_BIT]}}      & REEXE_regData_r_i     )|
                                            ({32{SBA_forwardSel_up[i][`DELAY_MEM_BIT]}}        & wb_data               );
            assign scr[i] = srcIsReg[i] ? updataRegFile_up[i] : SBA_oprand_up[i];
        end
    endgenerate
/*}}}*/
    assign REEXE_regData_o      = SBA_notExc_r_i ? aluso : SBA_aluRes_r_i;
    // }}}
endmodule

