//// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/02 11:09
// Last Modified : 2022/08/03 10:16
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
`include "../MyDefines.v"
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
    input	wire	[`EXCEP_SEG]            CP0_exceptSeg_w_i,
    // 流水线控制
    input	wire	                        EXE_up_valid_w_i,
    input	wire	                        PREMEM_allowin_w_i,         // 上下段互锁
    // 数据前递{{{
    input	wire	[`GPR_NUM]              REEXE_writeNum_w_i,   
    input	wire	[`GPR_NUM]              MEM_writeNum_w_i,
    input	wire	                        MEM_forwardMode_w_i,
    input	wire	                        REEXE_forwardMode_w_i,
    // }}}
    input	wire	[2*`SINGLE_WORD]        ID_up_delayReadData_w_p_i,
/*}}}*/
    //////////////////////////////////////////////////
    //////////////     线信号输出      ///////////////{{{
    //////////////////////////////////////////////////
    // 流水线控制
    output	wire	                        SBA_okToChange_w_o,            // 逐级互锁信号
    output	wire	                        SBA_valid_w_o,
    // 数据前递模式控制
    output	wire	                        SBA_forwardMode_w_o,    
    output	wire	[`GPR_NUM]              SBA_writeNum_w_o,    
    output	wire	                        SBA_nonBlockDS_w_o,       // 在分支跳转的时候处理非阻塞
    output	wire	                        SBA_branchRisk_w_o,
    // 错误刷新
    output  wire                            SBA_flush_w_o,              //  表示分支错误，需要刷新流水线
    output  wire    [`SINGLE_WORD]          SBA_erroVAddr_w_o,          //  分支错误PC
    output  wire    [`SINGLE_WORD]          SBA_corrDest_w_o,           //  正确的分支目的
    output  wire                            SBA_corrTake_w_o,           //  正确的分支方向
    output	wire	[`ALL_CHECKPOINT]       SBA_checkPoint_w_o,         //  检查点信息
    output	wire	[`REPAIR_ACTION]        SBA_repairAction_w_o,       //  检查点信息
    output	wire	[2*`GPR_NUM]            SBA_delayReadNum_w_p_o, 
/*}}}*/
    /////////////////////////////////////////////////
    //////////////      寄存器输入     //////////////{{{
    /////////////////////////////////////////////////
    input	wire	[`GPR_NUM]              EXE_up_writeNum_i,          // 回写寄存器数值,0为不回写
    input	wire	[`SINGLE_WORD]          EXE_up_VAddr_i,             // 用于debug和异常处理
    // 延迟执行{{{
    input	wire	                        EXE_up_notExc_i,            // 该指令是延迟执行指令
    input	wire	[2*`SINGLE_WORD]        EXE_up_preSrc_p_i,          // 指令自带的操作数
    input	wire	                        EXE_up_oprand0IsReg_i,       
    input	wire	                        EXE_up_oprand1IsReg_i,       
    input	wire	[`ALUOP]                EXE_up_aluOprator_i,
    input	wire	[2*`GPR_NUM]            EXE_up_readNum_p_i,         // 读寄存器index 
    input	wire	[1:0]                   EXE_up_needRead_p_i,        // 延迟执行需要读寄存器}}}
    // 算数,位移
    input	wire    [`SINGLE_WORD]          EXE_up_aluRes_i,	        
    // 非阻塞乘除
    // 分支确认的信息
    input	wire	[`SINGLE_WORD]          EXE_up_corrDest_i,          // 预测的分支地址
    input	wire	                        EXE_up_corrTake_i,          // 预测的分支跳转
    input	wire	[`REPAIR_ACTION]        EXE_up_repairAction_i,      // 修复动作，包含是否需要修复的信号
    input	wire	[`ALL_CHECKPOINT]       EXE_up_checkPoint_i,
    input	wire	                        EXE_up_branchRisk_i,
    input	wire	                        EXE_down_nonBlockDS_i,
/*}}}*/
    ///////////////////////////////////////////////////
    //////////////     寄存器输出       ///////////////{{{
    ///////////////////////////////////////////////////
    output	wire	[`GPR_NUM]              SBA_writeNum_o,             // 回写寄存器数值,0为不回写
    output	wire	[`SINGLE_WORD]          SBA_VAddr_o,                // 用于debug和异常处理
    // 延迟执行{{{
    output	wire	                        SBA_notExc_o,            // 表示该指令是延迟执行指令
    output	wire	[`DELAY_MODE]           SBA_forwardSel0_o, 
    output	wire	[`DELAY_MODE]           SBA_forwardSel1_o, 
    output	wire	                        SBA_oprand0IsReg_o,       
    output	wire	                        SBA_oprand1IsReg_o,       
    output	wire	[2*`SINGLE_WORD]        SBA_preSrc_p_o,          // 指令自带的操作数
    output	wire	[2*`SINGLE_WORD]        SBA_readData_p_o,        
    output	wire	[`ALUOP]                SBA_aluOperator_o,
    // }}}
    // 算数,位移
    output	wire    [`SINGLE_WORD]          SBA_aluRes_o
/*}}}*/
);
    //自动定义
    /*autodef*/
    reg had_branch_flush;
    wire    load_conflict;
    //Intersegment_register{{{

    wire            needClear;
    wire            needUpdata;

	reg	[`GPR_NUM]			EXE_up_writeNum_r_i;
	reg	[`SINGLE_WORD]			EXE_up_VAddr_r_i;
	reg	[0:0]			EXE_up_notExc_r_i;
	reg	[2*`SINGLE_WORD]			EXE_up_preSrc_p_r_i;
	reg	[0:0]			EXE_up_oprand0IsReg_r_i;
	reg	[0:0]			EXE_up_oprand1IsReg_r_i;
	reg	[`ALUOP]			EXE_up_aluOprator_r_i;
	reg	[2*`GPR_NUM]			EXE_up_readNum_p_r_i;
	reg	[1:0]			EXE_up_needRead_p_r_i;
	reg	[`SINGLE_WORD]			EXE_up_aluRes_r_i;
	reg	[`SINGLE_WORD]			EXE_up_corrDest_r_i;
	reg	[0:0]			EXE_up_corrTake_r_i;
	reg	[`REPAIR_ACTION]			EXE_up_repairAction_r_i;
	reg	[`ALL_CHECKPOINT]			EXE_up_checkPoint_r_i;
	reg	[0:0]			EXE_up_branchRisk_r_i;
	reg	[0:0]			EXE_down_nonBlockDS_r_i;
    always @(posedge clk) begin
        if (!rst || needClear) begin
			EXE_up_writeNum_r_i	<=	'b0;
			EXE_up_VAddr_r_i	<=	'b0;
			EXE_up_notExc_r_i	<=	'b0;
			EXE_up_preSrc_p_r_i	<=	'b0;
			EXE_up_oprand0IsReg_r_i	<=	'b0;
			EXE_up_oprand1IsReg_r_i	<=	'b0;
			EXE_up_aluOprator_r_i	<=	'b0;
			EXE_up_readNum_p_r_i	<=	'b0;
			EXE_up_needRead_p_r_i	<=	'b0;
			EXE_up_aluRes_r_i	<=	'b0;
			EXE_up_corrDest_r_i	<=	'b0;
			EXE_up_corrTake_r_i	<=	'b0;
			EXE_up_repairAction_r_i	<=	'b0;
			EXE_up_checkPoint_r_i	<=	'b0;
			EXE_up_branchRisk_r_i	<=	'b0;
			EXE_down_nonBlockDS_r_i	<=	'b0;
        end
        else if (needUpdata) begin
			EXE_up_writeNum_r_i	<=	EXE_up_writeNum_i;
			EXE_up_VAddr_r_i	<=	EXE_up_VAddr_i;
			EXE_up_notExc_r_i	<=	EXE_up_notExc_i;
			EXE_up_preSrc_p_r_i	<=	EXE_up_preSrc_p_i;
			EXE_up_oprand0IsReg_r_i	<=	EXE_up_oprand0IsReg_i;
			EXE_up_oprand1IsReg_r_i	<=	EXE_up_oprand1IsReg_i;
			EXE_up_aluOprator_r_i	<=	EXE_up_aluOprator_i;
			EXE_up_readNum_p_r_i	<=	EXE_up_readNum_p_i;
			EXE_up_needRead_p_r_i	<=	EXE_up_needRead_p_i;
			EXE_up_aluRes_r_i	<=	EXE_up_aluRes_i;
			EXE_up_corrDest_r_i	<=	EXE_up_corrDest_i;
			EXE_up_corrTake_r_i	<=	EXE_up_corrTake_i;
			EXE_up_repairAction_r_i	<=	EXE_up_repairAction_i;
			EXE_up_checkPoint_r_i	<=	EXE_up_checkPoint_i;
			EXE_up_branchRisk_r_i	<=	EXE_up_branchRisk_i;
			EXE_down_nonBlockDS_r_i	<=	EXE_down_nonBlockDS_i;
        end
    end
    ///*}}}*/
    // 线信号处理{{{
    // 流水线互锁
    reg hasData;
    wire ready = !(MEM_hasRisk_w_i&&EXE_up_repairAction_r_i[`NEED_REPAIR]) && !load_conflict;
    assign SBA_okToChange_w_o = !hasData || ready;
    wire needFlush = CP0_exceptSeg_w_i[`EXCEP_MEM] && CP0_excOccur_w_i;
    wire pre_valid = EXE_up_valid_w_i && !SBA_flush_w_o;
    assign SBA_valid_w_o    =   hasData && 
                                ready && 
                                PREMEM_allowin_w_i &&
                                !needFlush;
    assign needUpdata = PREMEM_allowin_w_i && pre_valid;
    assign needClear  = (!pre_valid&&PREMEM_allowin_w_i) || needFlush;
    always @(posedge clk) begin
        if(!rst || needClear) begin
            hasData     <=  1'b0;
        end
        else if (PREMEM_allowin_w_i)
            hasData     <=  EXE_up_valid_w_i ;
    end
    assign SBA_forwardMode_w_o  = ready && hasData && !EXE_up_notExc_r_i;
    assign SBA_nonBlockDS_w_o   = EXE_down_nonBlockDS_r_i;
    assign SBA_branchRisk_w_o   = EXE_up_branchRisk_r_i;
    assign SBA_writeNum_w_o     = EXE_up_writeNum_r_i;
    assign SBA_erroVAddr_w_o    = EXE_up_VAddr_r_i;
    assign SBA_corrDest_w_o     = EXE_up_corrDest_r_i;
    assign SBA_corrTake_w_o     = EXE_up_corrTake_r_i;
    assign SBA_repairAction_w_o = EXE_up_repairAction_r_i;
    assign SBA_flush_w_o        = (!MEM_hasRisk_w_i && EXE_up_repairAction_r_i[`NEED_REPAIR]) && !had_branch_flush;
    assign SBA_checkPoint_w_o   = EXE_up_checkPoint_r_i;
    // }}}
    // flush信号处理{{{
    always @(posedge clk) begin
        if (!rst || needUpdata || needClear) begin
            had_branch_flush    <=  `FALSE;
        end
        else if (SBA_flush_w_o) begin
            had_branch_flush    <=  `TRUE;
        end
    end
    // }}}
    // 寄存器输出{{{
    assign SBA_writeNum_o = EXE_up_writeNum_r_i;
    assign SBA_aluRes_o = EXE_up_aluRes_r_i;
    assign SBA_VAddr_o  = EXE_up_VAddr_r_i;
    // }}}
    // 延迟执行{{{
    assign SBA_delayReadNum_w_p_o = EXE_up_readNum_p_r_i;
    wire [`DELAY_MODE]      forwardReady    [1:0];     
    wire [`DELAY_MODE]      forwardWhich    [1:0];     
    wire [`DELAY_MODE]      forwardSel      [1:0];     
    wire [`GPR_NUM]         readNum         [1:0];
    wire                    load_conflict_up[1:0];
    wire [1:0]              needRead        = EXE_up_needRead_p_r_i;
    `UNPACK_ARRAY(`GPR_NUM_LEN,2,readNum,EXE_up_readNum_p_r_i)
    assign SBA_forwardSel0_o = forwardSel[0];
    assign SBA_forwardSel1_o = forwardSel[1];
    assign SBA_preSrc_p_o       = EXE_up_preSrc_p_r_i;
    assign SBA_readData_p_o     = ID_up_delayReadData_w_p_i;
    assign SBA_aluOperator_o    = EXE_up_aluOprator_r_i;
    assign SBA_oprand0IsReg_o   = EXE_up_oprand0IsReg_r_i;
    assign SBA_oprand1IsReg_o   = EXE_up_oprand1IsReg_r_i;
    assign SBA_notExc_o         = EXE_up_notExc_r_i;
    // 数据是否可以在下一个周期使用,如果需要被前递,前递段的数据是否计算完成
    generate
        for (genvar i = 0; i < 2; i=i+1)	begin
            wire   notZero = |readNum[i];
            assign forwardWhich[i] = 
                                        (MEM_writeNum_w_i==readNum[i]    && notZero) ? `DELAY_MODE_MEM : 
                                        (REEXE_writeNum_w_i==readNum[i]  && notZero) ? `DELAY_MODE_REEXE : `DELAY_MODE_ID;
            assign forwardReady[i] = { 
                                        MEM_forwardMode_w_i,
                                        REEXE_forwardMode_w_i,
                                        1'b1
                                          };
            assign forwardSel[i]   = forwardWhich[i] & forwardReady[i];
            assign load_conflict_up[i] = needRead[i] && (MEM_writeNum_w_i==readNum[i] && notZero) && !MEM_forwardMode_w_i;
        end
    endgenerate
    assign load_conflict = load_conflict_up[0] || load_conflict_up[1];
/*}}}*/
endmodule

