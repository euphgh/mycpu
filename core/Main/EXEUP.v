// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/01 16:24
// Last Modified : 2022/08/03 14:17
// File Name     : EXEUP.v
// Description   : EXE上段,需要执行算数,移动,分支,自陷指令
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/07/01   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "MyDefines.v"
module EXEUP(
    input	wire	clk,
    input	wire	rst,
    /////////////////////////////////////////////////
    //////////////    线信号输入      ///////////////{{{
    /////////////////////////////////////////////////
    // 流水线控制
    input	wire	                        ID_up_valid_w_i,
    input	wire	                        EXE_down_allowin_w_i,
    // 刷新流水线的信号
    input	wire	                        SBA_flush_w_i,            
    input	wire	                        CP0_excOccur_w_i,            
    input	wire	[`EXCEP_SEG]            CP0_exceptSeg_w_i,
    // 异常互锁
    input	wire	[`SINGLE_WORD]          WB_forwardData_w_i,
/*}}}*/
    ////////////////////////////////////////////////
    //////////////    寄存器的输入    //////////////{{{
    ////////////////////////////////////////////////
    input	wire	[`SINGLE_WORD]          ID_up_VAddr_i,
    input	wire	[`GPR_NUM]              ID_up_writeNum_i,             // 回写寄存器数值,0为不回写
    // 寄存器文件
    input	wire	[2*`SINGLE_WORD]        ID_up_readData_i,           // 寄存器值rsrt
    // 算数,位移
    input	wire	[`SINGLE_WORD]          ID_up_oprand0_i,            
    input	wire	                        ID_up_oprand0IsReg_i,       
    input	wire	                        ID_up_oprand1IsReg_i,       
    input	wire	[`FORWARD_MODE]         ID_up_forwardSel0_i,        // 用于选择前递信号
    input	wire	                        ID_up_data0Ready_i,         // 表示该operand是否可用
    input	wire	[`SINGLE_WORD]          ID_up_oprand1_i,            
    input	wire	[`FORWARD_MODE]         ID_up_forwardSel1_i,        // 用于选择前递信号
    input	wire	                        ID_up_data1Ready_i,         // 表示该operand是否可用
    input	wire	[`ALUOP]                ID_up_aluOprator_i,
    // 分支确认的信息    
    input	wire                            ID_up_branchRisk_i,         // 存在分支确认失败的风险
    input	wire    [`BRANCH_KIND]          ID_up_branchKind_i,         // 分支指令的种类
    input	wire	[`REPAIR_ACTION]        ID_up_repairAction_i,       // 检查点信息,包括是否是分支指令
    input	wire	[`ALL_CHECKPOINT]       ID_up_checkPoint_i,         // 检查点信息
    input	wire	[`SINGLE_WORD]          ID_up_predDest_i,           // 预测的分支地址
    input	wire	                        ID_up_predTake_i,           // 预测的分支跳转
    // 运算数据前递
    input	wire	[`SINGLE_WORD]          EXE_up_aluRes_i,
    input	wire	[`SINGLE_WORD]          EXE_down_aluRes_i,
    input	wire	[`SINGLE_WORD]          SBA_aluRes_i,
    input	wire	[`SINGLE_WORD]          REEXE_regData_i,
    input	wire	[`SINGLE_WORD]          PREMEM_preliminaryRes_i,
    input	wire	[`SINGLE_WORD]          MEM_finalRes_i,
/*}}}*/
    /////////////////////////////////////////////////
    //////////////      线信号输出     //////////////{{{
    /////////////////////////////////////////////////
    // ID指令阶段控制
    output	wire	                        EXE_up_forwardMode_w_o,    
    output	wire	[`GPR_NUM]              EXE_up_writeNum_w_o,    
    // 流水线控制
    output	wire	                        EXE_up_okToChange_w_o, // 只有上才有allowin，代表上下两端都可进
    output	wire	                        EXE_up_valid_w_o,       // 用于给下一级流水线决定是否采样
/*}}}*/
    /////////////////////////////////////////////////
    //////////////      寄存器输出     //////////////{{{
    /////////////////////////////////////////////////
    output	wire	[`GPR_NUM]              EXE_up_writeNum_o,          // 回写寄存器数值,0为不回写
    output	wire	[`SINGLE_WORD]          EXE_up_VAddr_o,             // 用于debug和异常处理
    // 算数,位移
    output	wire    [`SINGLE_WORD]          EXE_up_aluRes_o,	        
    // 非阻塞乘除
    // 分支确认的信息
    output	wire	[`SINGLE_WORD]          EXE_up_corrDest_o,          // 预测的分支地址
    output	wire	                        EXE_up_corrTake_o,          // 预测的分支跳转
    output	wire	[`REPAIR_ACTION]        EXE_up_repairAction_o,      // 修复动作，包含是否需要修复的信号
    output	wire	[`ALL_CHECKPOINT]       EXE_up_checkPoint_o,
    output	wire	                        EXE_up_isBranch_o,
    output	wire                            EXE_up_branchRisk_o         // 存在分支确认失败的风险
/*}}}*/
);
    /*autodef*/
    //Start of automatic define{{{
    //Start of automatic reg
    //Define flip-flop registers here
    //Define combination registers here
    //End of automatic reg
    //Start of automatic wire
    //Define assign wires here
    //Define instance wires here
    wire [`ALUOP]               aluop                           ;
    wire                        overflow                        ;
    wire [`SINGLE_WORD]         aluso                           ;
    //End of automatic wire
    //End of automatic define
    wire [`SINGLE_WORD]         scr [1:0]                       ;
/*}}}*/
    //Intersegment_register{{{

    wire            needClear;
    wire            needUpdata;

	reg	[`SINGLE_WORD]			ID_up_VAddr_r_i;
	reg	[`GPR_NUM]			ID_up_writeNum_r_i;
	reg	[2*`SINGLE_WORD]			ID_up_readData_r_i;
	reg	[`SINGLE_WORD]			ID_up_oprand0_r_i;
	reg	[0:0]			ID_up_oprand0IsReg_r_i;
	reg	[0:0]			ID_up_oprand1IsReg_r_i;
	reg	[`FORWARD_MODE]			ID_up_forwardSel0_r_i;
	reg	[0:0]			ID_up_data0Ready_r_i;
	reg	[`SINGLE_WORD]			ID_up_oprand1_r_i;
	reg	[`FORWARD_MODE]			ID_up_forwardSel1_r_i;
	reg	[0:0]			ID_up_data1Ready_r_i;
	reg	[`ALUOP]			ID_up_aluOprator_r_i;
	reg	[0:0]			ID_up_branchRisk_r_i;
	reg	[`BRANCH_KIND]			ID_up_branchKind_r_i;
	reg	[`REPAIR_ACTION]			ID_up_repairAction_r_i;
	reg	[`ALL_CHECKPOINT]			ID_up_checkPoint_r_i;
	reg	[`SINGLE_WORD]			ID_up_predDest_r_i;
	reg	[0:0]			ID_up_predTake_r_i;
	reg	[`SINGLE_WORD]			EXE_up_aluRes_r_i;
	reg	[`SINGLE_WORD]			EXE_down_aluRes_r_i;
	reg	[`SINGLE_WORD]			SBA_aluRes_r_i;
	reg	[`SINGLE_WORD]			REEXE_regData_r_i;
	reg	[`SINGLE_WORD]			PREMEM_preliminaryRes_r_i;
	reg	[`SINGLE_WORD]			MEM_finalRes_r_i;
    always @(posedge clk) begin
        if (!rst || needClear) begin
			ID_up_VAddr_r_i	<=	'b0;
			ID_up_writeNum_r_i	<=	'b0;
			ID_up_readData_r_i	<=	'b0;
			ID_up_oprand0_r_i	<=	'b0;
			ID_up_oprand0IsReg_r_i	<=	'b0;
			ID_up_oprand1IsReg_r_i	<=	'b0;
			ID_up_forwardSel0_r_i	<=	'b0;
			ID_up_data0Ready_r_i	<=	'b0;
			ID_up_oprand1_r_i	<=	'b0;
			ID_up_forwardSel1_r_i	<=	'b0;
			ID_up_data1Ready_r_i	<=	'b0;
			ID_up_aluOprator_r_i	<=	'b0;
			ID_up_branchRisk_r_i	<=	'b0;
			ID_up_branchKind_r_i	<=	'b0;
			ID_up_repairAction_r_i	<=	'b0;
			ID_up_checkPoint_r_i	<=	'b0;
			ID_up_predDest_r_i	<=	'b0;
			ID_up_predTake_r_i	<=	'b0;
			EXE_up_aluRes_r_i	<=	'b0;
			EXE_down_aluRes_r_i	<=	'b0;
			SBA_aluRes_r_i	<=	'b0;
			REEXE_regData_r_i	<=	'b0;
			PREMEM_preliminaryRes_r_i	<=	'b0;
			MEM_finalRes_r_i	<=	'b0;
        end
        else if (needUpdata) begin
			ID_up_VAddr_r_i	<=	ID_up_VAddr_i;
			ID_up_writeNum_r_i	<=	ID_up_writeNum_i;
			ID_up_readData_r_i	<=	ID_up_readData_i;
			ID_up_oprand0_r_i	<=	ID_up_oprand0_i;
			ID_up_oprand0IsReg_r_i	<=	ID_up_oprand0IsReg_i;
			ID_up_oprand1IsReg_r_i	<=	ID_up_oprand1IsReg_i;
			ID_up_forwardSel0_r_i	<=	ID_up_forwardSel0_i;
			ID_up_data0Ready_r_i	<=	ID_up_data0Ready_i;
			ID_up_oprand1_r_i	<=	ID_up_oprand1_i;
			ID_up_forwardSel1_r_i	<=	ID_up_forwardSel1_i;
			ID_up_data1Ready_r_i	<=	ID_up_data1Ready_i;
			ID_up_aluOprator_r_i	<=	ID_up_aluOprator_i;
			ID_up_branchRisk_r_i	<=	ID_up_branchRisk_i;
			ID_up_branchKind_r_i	<=	ID_up_branchKind_i;
			ID_up_repairAction_r_i	<=	ID_up_repairAction_i;
			ID_up_checkPoint_r_i	<=	ID_up_checkPoint_i;
			ID_up_predDest_r_i	<=	ID_up_predDest_i;
			ID_up_predTake_r_i	<=	ID_up_predTake_i;
			EXE_up_aluRes_r_i	<=	EXE_up_aluRes_i;
			EXE_down_aluRes_r_i	<=	EXE_down_aluRes_i;
			SBA_aluRes_r_i	<=	SBA_aluRes_i;
			REEXE_regData_r_i	<=	REEXE_regData_i;
			PREMEM_preliminaryRes_r_i	<=	PREMEM_preliminaryRes_i;
			MEM_finalRes_r_i	<=	MEM_finalRes_i;
        end
    end
    /*}}}*/
//  线信号处理{{{
    // 流水线互锁
    reg hasData;
    wire ready = 1'b1;
    assign EXE_up_okToChange_w_o = !hasData || ready;
    wire exceptionClean = CP0_exceptSeg_w_i[`EXCEP_PREMEM] && CP0_excOccur_w_i;
    wire needFlush = SBA_flush_w_i || exceptionClean;
    assign EXE_up_valid_w_o =   hasData && 
                                ready && 
                                EXE_down_allowin_w_i && 
                                !exceptionClean;
    assign needUpdata = EXE_down_allowin_w_i && ID_up_valid_w_i;
    assign needClear  = (!ID_up_valid_w_i&&EXE_down_allowin_w_i) || needFlush;
    always @(posedge clk) begin
        if(!rst || needClear) begin
            hasData <=  1'b0;
        end
        else if (EXE_down_allowin_w_i)
            hasData <=  ID_up_valid_w_i;
    end
    assign EXE_up_forwardMode_w_o = hasData && ready;
    assign EXE_up_writeNum_w_o = ID_up_writeNum_r_i;
/*}}}*/
    ALU ALU_u(/*{{{*/
      /*autoinst*/
        .scr0                   (scr[0]                         ), //input
        .scr1                   (scr[1]                         ), //input
        .aluop                  (aluop[`ALUOP]                  ), //input
        .overflow               (overflow                       ), //output
        .aluso                  (aluso[`SINGLE_WORD]            )  //output
    );
    assign aluop = ID_up_aluOprator_r_i;
    /*}}}*/
    // 前递选择 {{{
    wire	    [`SINGLE_WORD]          ID_up_oprand_up     [1:0];            
    wire	    [`FORWARD_MODE]         ID_up_forwardSel_up [1:0];        // 用于选择前递信号
    assign ID_up_oprand_up[0] = ID_up_oprand0_r_i;
    assign ID_up_oprand_up[1] = ID_up_oprand1_r_i;
    assign ID_up_forwardSel_up[0] = ID_up_forwardSel0_r_i;
    assign ID_up_forwardSel_up[1] = ID_up_forwardSel1_r_i;
    wire        [`SINGLE_WORD]      readData_up     [1:0];
    `UNPACK_ARRAY(`SINGLE_WORD_LEN,2,readData_up,ID_up_readData_r_i)
    wire        [`SINGLE_WORD]      updataRegFile_up[1:0];
    wire        [0:0]               srcIsReg        [1:0];
    assign srcIsReg[0] = ID_up_oprand0IsReg_r_i;
    assign srcIsReg[1] = ID_up_oprand1IsReg_r_i;
    generate   
        for (genvar i = 0; i < 2; i=i+1)	begin     
            // WB段数据再保存{{{
            reg [`SINGLE_WORD]  wb_savedData;
            reg                 useSavedWb;
            always @(posedge clk) begin
                if (!rst || needClear || needUpdata) begin
                    useSavedWb      <=  `FALSE;
                end
                else if (ID_up_forwardSel_up[i][`FORWARD_MEM_BIT]) begin
                    useSavedWb      <=  `TRUE;
                end
                if (!rst || needClear || needUpdata) begin
                    wb_savedData    <=  `ZEROWORD;
                end
                else if (ID_up_forwardSel_up[i][`FORWARD_MEM_BIT] && !useSavedWb) begin
                    wb_savedData    <=  WB_forwardData_w_i;
                end
            end
            wire [`SINGLE_WORD] wb_data = useSavedWb ? wb_savedData : WB_forwardData_w_i;
            // }}}
            assign updataRegFile_up[i] = ({32{ID_up_forwardSel_up[i][`FORWARD_ID_BIT]}} & readData_up[i])|
                            ({32{ID_up_forwardSel_up[i][`FORWARD_SBA_BIT]}}         & SBA_aluRes_r_i            )|
                            ({32{ID_up_forwardSel_up[i][`FORWARD_PREMEM_BIT]}}      & PREMEM_preliminaryRes_r_i )|
                            ({32{ID_up_forwardSel_up[i][`FORWARD_REEXE_BIT]}}       & REEXE_regData_r_i         )|
                            ({32{ID_up_forwardSel_up[i][`FORWARD_MEM_BIT]}}         & wb_data        )|
                            ({32{ID_up_forwardSel_up[i][`FORWARD_EXE_UP_BIT]}}      & EXE_up_aluRes_r_i         )|
                            ({32{ID_up_forwardSel_up[i][`FORWARD_EXE_DOWN_BIT] }}   & EXE_down_aluRes_r_i       );
            assign scr[i] = srcIsReg[i] ? updataRegFile_up[i] : ID_up_oprand_up[i];
        end
    endgenerate
/*}}}*/
    // 简单信号赋值{{{
    assign EXE_up_writeNum_o = ID_up_writeNum_r_i;
    assign EXE_up_VAddr_o = ID_up_VAddr_r_i;
/*}}}*/
    // 分支预测计算{{{
    wire beq_take = updataRegFile_up[0]==updataRegFile_up[1];
    wire bne_take = !beq_take;
    wire blt_take = updataRegFile_up[0][31];
    wire bge_take = !blt_take;
    wire bgt_take = (!updataRegFile_up[0][31]) && |(updataRegFile_up[0][30:0]);
    wire ble_take = !bgt_take;
    assign EXE_up_corrTake_o =  ID_up_branchKind_r_i[`BRANCH_EQUAL] ? beq_take : 
                                ID_up_branchKind_r_i[`BRANCH_NEQ]   ? bne_take :
                                ID_up_branchKind_r_i[`BRANCH_LT]    ? blt_take :
                                ID_up_branchKind_r_i[`BRANCH_LE]    ? ble_take :
                                ID_up_branchKind_r_i[`BRANCH_GT]    ? bgt_take :
                                ID_up_branchKind_r_i[`BRANCH_GE]    ? bge_take : ID_up_branchRisk_r_i;
    wire isLink = ID_up_repairAction_r_i[`NEED_REPAIR] && |(ID_up_writeNum_r_i);
    assign EXE_up_aluRes_o = isLink ? (ID_up_VAddr_r_i + 5'd8) : aluso;
    assign EXE_up_corrDest_o = EXE_up_corrTake_o ? aluso : {ID_up_VAddr_r_i[31:3]+1'b1,ID_up_VAddr_r_i[2:0]};
    assign EXE_up_repairAction_o = {EXE_up_branchRisk_o,ID_up_repairAction_r_i[`REPAIR_ACTION_LEN-2:0]};
    assign EXE_up_checkPoint_o   = ID_up_checkPoint_r_i;
    wire    predictHit  =   ((!EXE_up_corrTake_o) && (!ID_up_predTake_r_i)) ||
                            ((EXE_up_corrDest_o==ID_up_predDest_r_i) && EXE_up_corrTake_o && ID_up_predTake_r_i);
    assign EXE_up_branchRisk_o   =  (!predictHit) && ID_up_branchRisk_r_i ;
    assign EXE_up_isBranch_o     = ID_up_branchRisk_r_i;

    reg [31:0] truep,falsep;
    reg [31:0] truehit;

    always @(posedge clk) begin
        if (!rst) begin
            truep   <=  'd0;
            falsep  <=  'd0;
            truehit <=  'd0;
        end
        else if (   !ID_up_branchRisk_r_i || 
                    !EXE_down_allowin_w_i ||  
                    SBA_flush_w_i ||
                    CP0_excOccur_w_i
                                            ) begin
        end
        else if (!predictHit) begin
            falsep <= falsep +1;
            `ifdef DEBUG
            $display("predict error: pc %h, pred %b goto %h, but %b goto %h",EXE_up_VAddr_o,ID_up_predTake_r_i,ID_up_predDest_r_i,EXE_up_corrTake_o,EXE_up_corrDest_o);
            `endif
            `ifdef BREAK
            $finish(0);
            `endif
        end
        else if (EXE_up_corrTake_o && ID_up_predTake_r_i) begin
            truehit <=  truehit + 1;
            truep <= truep +1;
            `ifdef DEBUG
            $display("predict right: pc %h, %b goto %h",EXE_up_VAddr_o,ID_up_predTake_r_i,ID_up_predDest_r_i);
            `endif
        end
        else if (EXE_up_corrTake_o==1'b0 && ID_up_predTake_r_i==1'b0 && ID_up_branchRisk_r_i) begin
            truep <= truep +1;
            `ifdef DEBUG
            $display("predict right: pc %h, %b goto %h",EXE_up_VAddr_o,ID_up_predTake_r_i,ID_up_predDest_r_i);
            `endif
        end
    end
/*}}}*/
endmodule

