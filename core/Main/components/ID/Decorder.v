// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/13 09:29
// Last Modified : 2022/07/30 15:35
// File Name     : Decorder.v
// Description   : ID段的解码器，用于生成所有的控制信号
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/07/13   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "../../../MyDefines.v"
module Decorder(
    input	wire	[2*`SINGLE_WORD]  AB_Inst_p,
    /////////////////////////////////////////////////
    ///////////////         输出     ////////////////{{{
    /////////////////////////////////////////////////
    // 两路都有{{{
    output	wire    [`OPRAND_SEL]           up_oprand0_sel,
    output	wire    [`OPRAND_SEL]           up_oprand1_sel,
    output	wire    [`OPRAND_SEL]           down_oprand0_sel,
    output	wire    [`OPRAND_SEL]           down_oprand1_sel,
    output	wire	[2*`EXCCODE]            decorderExcCode_p,
    output	wire	[1:0]                   decorderException_p,
    output	wire    [1:0]                   ID_exceptionRisk_p,         // 存在异常的风险
    output  wire    [2*`EXTEND_ACTION]      extendAction_p,
    output	wire	[`ALUOP]                ID_up_aluOprator_o,         
    output	wire	[`ALUOP]                ID_down_aluOprator_o,
    output	wire	[`EXCEPRION_SEL]        ID_down_exceptionSel_o,
    output	wire	[`TRAP_KIND]            ID_down_trapKind_o,         // 自陷指令的种类
/*}}}*/
    // 上流水线{{{
    output	wire	[`BRANCH_KIND]          ID_up_branchKind_o,         // only up
    output	wire	                        ID_up_branchRisk_o,   
    output	wire	[`REPAIR_ACTION]        ID_up_repairAction_o,/*}}}*/
    // 下流水线{{{
    output	wire	                        ID_down_isDangerous_o,      // 表示该指令在执行期间不得执行其他指令
    output	wire	[`MDUOP]                ID_down_mduOperator_o,      // 包括乘除,clo,clz和累加累减
    output	wire	[`HILO]                 ID_down_readHiLo_o,         // 只有指令需要将HiLo写入GPR,该信号才会拉高,包括clo/z,mul,mfhilo
    output	wire	[`HILO]                 ID_down_writeHiLo_o,        // 需要根据数值写HiLo的指令,有madd,/sub,mult,div,mtc0,其中mtc0是类似与add做运算,之后将运算结果写入
    output	wire	                        ID_down_readCp0_o,          // 只有指令需要将cp0写入GPR,该信号才会拉高,mfc0
    output	wire	                        ID_down_writeCp0_o,         // 只有指令需要将GPR写入cp0,该信号才会拉高,mtc0,直接将rt寄存器的数值接入
    output	wire	                        ID_down_eret_o,             // 是eret指令 TODO
    output	wire	                        ID_down_memReq_o,
    output	wire	                        ID_down_memWR_o,            // 表示访存，0表示访问，1表示存储
    output	wire	                        ID_down_memAtom_o,          // 表示该访存操作是原子访存操作,需要读写LLbit
    output	wire    [`LOAD_MODE]            ID_down_loadMode_o,         // load模式	
    output	wire    [`STORE_MODE]           ID_down_storeMode_o,        // store模式	
    output	wire	                        ID_down_isTLBInst_o,        // 表示是TLB指令
    output	wire	[`TLB_INST]             ID_down_TLBInstOperator_o,  // 执行的种类
    output	wire	                        ID_down_isCacheInst_o,      // 表示是Cache指令
    output	wire	[`CACHE_OP]             ID_down_CacheOperator_o     // Cache指令op}}}
    /*}}}*/
);
    // 变量重命名和打包{{{
    wire [`SINGLE_WORD] inst [1:0];
    assign inst[0] = AB_Inst_p[31: 0];
    assign inst[1] = AB_Inst_p[63:32];
    wire    [`OPRAND_SEL]       oprand0_sel_up      [1:0];
    wire    [`OPRAND_SEL]       oprand1_sel_up      [1:0];
    wire    [0:0]               decorderException_up[1:0];
    wire    [`EXCCODE]          decorderExcCode_up  [1:0];
    wire    [0:0]               exceptionRisk_up    [1:0];
    wire    [`EXTEND_ACTION]    extendAction_up     [1:0];
    wire    [`ALUOP]            aluOprator_up       [1:0];
    wire    [`EXCEPRION_SEL]    exceptionSel_up     [1:0];
    wire    [`TRAP_KIND]        trapKind_up         [1:0];
    assign  up_oprand0_sel      = oprand0_sel_up[0];
    assign  down_oprand0_sel    = oprand0_sel_up[1];
    assign  up_oprand1_sel      = oprand1_sel_up[0];
    assign  down_oprand1_sel    = oprand1_sel_up[1];
    `PACK_ARRAY(1,2,decorderException_up,decorderException_p)
    `PACK_ARRAY(`EXCCODE_LEN,2,decorderExcCode_up,decorderExcCode_p)
    `PACK_ARRAY(1,2,exceptionRisk_up,ID_exceptionRisk_p)
    `PACK_ARRAY(`EXTEND_ACTION_LEN,2,extendAction_up,extendAction_p)
    assign  ID_up_aluOprator_o      = aluOprator_up[0];
    assign  ID_down_aluOprator_o    = aluOprator_up[1];
    assign  ID_down_exceptionSel_o  = exceptionSel_up[1];
    assign  ID_down_trapKind_o      = trapKind_up[1];
    assign  ID_down_CacheOperator_o = 'd0;
    // }}}
    // 自动解码{{{
    generate
        for (genvar i = 0; i < 2; i = i+1)	begin
	/*autoDecoder0_Start*/ /*{{{*/
wire temp_0_0 = (!inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][31]);
wire temp_0_1 = (!inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31]);
wire temp_0_2 = (!inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31]);
wire temp_0_3 = (!inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][30]&!inst[i][31]);
wire temp_0_4 = ( inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31]);

	assign	oprand0_sel_up[i][0]	=	((temp_0_2) & ((!inst[i][2]&!inst[i][3]& inst[i][5]) | ( inst[i][2]&!inst[i][3]& inst[i][5]) |
(!inst[i][2]& inst[i][3]& inst[i][5]) | (!inst[i][2]& inst[i][3]&!inst[i][5]) |
( inst[i][2]&!inst[i][3]&!inst[i][5]))) |
 (!(temp_0_2) & (((temp_0_1) & (( inst[i][19]))) |
 (!(temp_0_1) & (((temp_0_0) & ((!inst[i][25]))) |
 (!(temp_0_0) & (( inst[i][29]&!inst[i][31]) | (!inst[i][29]& inst[i][31]) |
( inst[i][29]& inst[i][31])))))));
	assign	oprand0_sel_up[i][1]	=	((temp_0_2) & ((!inst[i][2]&!inst[i][3]&!inst[i][5]))) |
 (!(temp_0_2) & (((temp_0_0) & (1'b0)) |
 (!(temp_0_0) & (1'b0))));
	assign	oprand0_sel_up[i][2]	=	((temp_0_4) & ((!inst[i][19]))) |
 (!(temp_0_4) & (((temp_0_3) & (1'b0)) |
 (!(temp_0_3) & ((!inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][31]) | ( inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][31]) |
( inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][31])))));
	assign	oprand1_sel_up[i][0]	=	((temp_0_3) & ((!inst[i][25]))) |
 (!(temp_0_3) & ((!inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31]) | (!inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]& inst[i][30]&!inst[i][31])));
	assign	oprand1_sel_up[i][1]	=	((temp_0_4) & (( inst[i][19]))) |
 (!(temp_0_4) & (((temp_0_3) & (1'b0)) |
 (!(temp_0_3) & (( inst[i][29]&!inst[i][30]&!inst[i][31]) | (!inst[i][29]&!inst[i][30]& inst[i][31]) |
( inst[i][29]&!inst[i][30]& inst[i][31]) | (!inst[i][29]& inst[i][30]& inst[i][31]) |
( inst[i][29]& inst[i][30]& inst[i][31])))));
	assign	oprand1_sel_up[i][2]	=	((temp_0_4) & ((!inst[i][19]))) |
 (!(temp_0_4) & (((temp_0_3) & (1'b0)) |
 (!(temp_0_3) & ((!inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][31]) | ( inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][31]) |
( inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][31])))));
	assign	decorderException_up[i]	=	((temp_0_2) & (( inst[i][2]& inst[i][3]))) |
 (!(temp_0_2) & (( inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][30]&!inst[i][31]) | (!inst[i][26]& inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][30]&!inst[i][31]) |
( inst[i][26]& inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][30]&!inst[i][31]) | ( inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][30]& inst[i][31]) |
(!inst[i][26]& inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][30]& inst[i][31]) | ( inst[i][26]&!inst[i][27]& inst[i][28]&!inst[i][29]& inst[i][30]& inst[i][31]) |
(!inst[i][26]& inst[i][27]& inst[i][28]&!inst[i][29]& inst[i][30]& inst[i][31]) | ( inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][30]& inst[i][31]) |
(!inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][30]& inst[i][31]) | ( inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]& inst[i][30]& inst[i][31]) |
(!inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]& inst[i][30]& inst[i][31]) | (!inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][30]&!inst[i][31]) |
( inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][30]&!inst[i][31]) | (!inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][30]&!inst[i][31]) |
( inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][30]&!inst[i][31]) | ( inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]& inst[i][30]&!inst[i][31]) |
(!inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]& inst[i][30]&!inst[i][31]) | ( inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]& inst[i][30]&!inst[i][31]) |
( inst[i][26]& inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) | (!inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) |
( inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) | (!inst[i][26]&!inst[i][27]& inst[i][28]&!inst[i][29]& inst[i][30]& inst[i][31]) |
( inst[i][26]& inst[i][27]& inst[i][28]&!inst[i][29]& inst[i][30]& inst[i][31]) | (!inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]& inst[i][30]& inst[i][31]) |
( inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]& inst[i][30]& inst[i][31]) | ( inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][30]& inst[i][31]) |
(!inst[i][26]&!inst[i][27]& inst[i][28]&!inst[i][29]& inst[i][30]&!inst[i][31]) | ( inst[i][26]&!inst[i][27]& inst[i][28]&!inst[i][29]& inst[i][30]&!inst[i][31]) |
(!inst[i][26]& inst[i][27]& inst[i][28]&!inst[i][29]& inst[i][30]&!inst[i][31])));
	assign	decorderExcCode_up[i][0]	=	((temp_0_2) & (( inst[i][0]& inst[i][2]& inst[i][3]&!inst[i][4]&!inst[i][5]) | (!inst[i][0]&!inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]) |
( inst[i][0]&!inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]) | (!inst[i][0]& inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]))) |
 (!(temp_0_2) & (((temp_0_1) & (( inst[i][19]))) |
 (!(temp_0_1) & ((!inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) | ( inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) |
( inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) | (!inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) |
(!inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) | (!inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][30]& inst[i][31])))));
	assign	decorderExcCode_up[i][1]	=	( inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][30]&!inst[i][31]) | (!inst[i][26]& inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][30]&!inst[i][31]) |
( inst[i][26]& inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][30]&!inst[i][31]) | ( inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][30]& inst[i][31]) |
(!inst[i][26]& inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][30]& inst[i][31]) | ( inst[i][26]&!inst[i][27]& inst[i][28]&!inst[i][29]& inst[i][30]& inst[i][31]) |
(!inst[i][26]& inst[i][27]& inst[i][28]&!inst[i][29]& inst[i][30]& inst[i][31]) | ( inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][30]& inst[i][31]) |
(!inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][30]& inst[i][31]) | ( inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]& inst[i][30]& inst[i][31]) |
(!inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]& inst[i][30]& inst[i][31]) | (!inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][30]&!inst[i][31]) |
( inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][30]&!inst[i][31]) | (!inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][30]&!inst[i][31]) |
( inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][30]&!inst[i][31]) | ( inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]& inst[i][30]&!inst[i][31]) |
(!inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]& inst[i][30]&!inst[i][31]) | ( inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]& inst[i][30]&!inst[i][31]) |
( inst[i][26]& inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) | (!inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) |
( inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) | (!inst[i][26]&!inst[i][27]& inst[i][28]&!inst[i][29]& inst[i][30]& inst[i][31]) |
( inst[i][26]& inst[i][27]& inst[i][28]&!inst[i][29]& inst[i][30]& inst[i][31]) | (!inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]& inst[i][30]& inst[i][31]) |
( inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]& inst[i][30]& inst[i][31]) | ( inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][30]& inst[i][31]) |
(!inst[i][26]&!inst[i][27]& inst[i][28]&!inst[i][29]& inst[i][30]&!inst[i][31]) | ( inst[i][26]&!inst[i][27]& inst[i][28]&!inst[i][29]& inst[i][30]&!inst[i][31]) |
(!inst[i][26]& inst[i][27]& inst[i][28]&!inst[i][29]& inst[i][30]&!inst[i][31]);
	assign	decorderExcCode_up[i][2]	=	((temp_0_2) & ((!inst[i][0]&!inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) | (!inst[i][0]&!inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]) |
( inst[i][0]&!inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]) | (!inst[i][0]& inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]))) |
 (!(temp_0_2) & (((temp_0_1) & (( inst[i][19]))) |
 (!(temp_0_1) & ((!inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) | (!inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) |
(!inst[i][26]&!inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) | ( inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) |
( inst[i][26]&!inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) | ( inst[i][26]& inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) |
(!inst[i][26]& inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) | (!inst[i][26]& inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) |
(!inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) | ( inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) |
( inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) | (!inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) |
(!inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) | (!inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][30]& inst[i][31]) |
(!inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][30]& inst[i][31])))));
	assign	decorderExcCode_up[i][3]	=	((temp_0_2) & ((!inst[i][0]&!inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) | (!inst[i][0]& inst[i][2]& inst[i][3]&!inst[i][4]&!inst[i][5]) |
( inst[i][0]& inst[i][2]& inst[i][3]&!inst[i][4]&!inst[i][5]) | (!inst[i][0]&!inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]) |
( inst[i][0]&!inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]) | (!inst[i][0]& inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]))) |
 (!(temp_0_2) & (((temp_0_1) & (( inst[i][19]))) |
 (!(temp_0_1) & ((!inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) | ( inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][30]&!inst[i][31]) |
(!inst[i][26]& inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][30]&!inst[i][31]) | ( inst[i][26]& inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][30]&!inst[i][31]) |
( inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][30]& inst[i][31]) | (!inst[i][26]& inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][30]& inst[i][31]) |
( inst[i][26]&!inst[i][27]& inst[i][28]&!inst[i][29]& inst[i][30]& inst[i][31]) | (!inst[i][26]& inst[i][27]& inst[i][28]&!inst[i][29]& inst[i][30]& inst[i][31]) |
( inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][30]& inst[i][31]) | (!inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][30]& inst[i][31]) |
( inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]& inst[i][30]& inst[i][31]) | (!inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]& inst[i][30]& inst[i][31]) |
(!inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][30]&!inst[i][31]) | ( inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][30]&!inst[i][31]) |
(!inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][30]&!inst[i][31]) | ( inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][30]&!inst[i][31]) |
( inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]& inst[i][30]&!inst[i][31]) | (!inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]& inst[i][30]&!inst[i][31]) |
( inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]& inst[i][30]&!inst[i][31]) | ( inst[i][26]& inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) |
(!inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) | ( inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) |
(!inst[i][26]&!inst[i][27]& inst[i][28]&!inst[i][29]& inst[i][30]& inst[i][31]) | ( inst[i][26]& inst[i][27]& inst[i][28]&!inst[i][29]& inst[i][30]& inst[i][31]) |
(!inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]& inst[i][30]& inst[i][31]) | ( inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]& inst[i][30]& inst[i][31]) |
( inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][30]& inst[i][31]) | (!inst[i][26]&!inst[i][27]& inst[i][28]&!inst[i][29]& inst[i][30]&!inst[i][31]) |
( inst[i][26]&!inst[i][27]& inst[i][28]&!inst[i][29]& inst[i][30]&!inst[i][31]) | (!inst[i][26]& inst[i][27]& inst[i][28]&!inst[i][29]& inst[i][30]&!inst[i][31])))));
	assign	decorderExcCode_up[i][4]	=	1'b0;
	assign	exceptionRisk_up[i]	=	((temp_0_2) & ((!inst[i][0]&!inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) | (!inst[i][0]& inst[i][2]& inst[i][3]&!inst[i][4]&!inst[i][5]) |
( inst[i][0]& inst[i][2]& inst[i][3]&!inst[i][4]&!inst[i][5]) | (!inst[i][0]&!inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]) |
( inst[i][0]&!inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]) | (!inst[i][0]& inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]))) |
 (!(temp_0_2) & (((temp_0_1) & (( inst[i][19]))) |
 (!(temp_0_1) & ((!inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) | (!inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) |
(!inst[i][26]&!inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) | ( inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) |
( inst[i][26]&!inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) | ( inst[i][26]& inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) |
(!inst[i][26]& inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) | (!inst[i][26]& inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) |
(!inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) | ( inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) |
( inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) | (!inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) |
(!inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) | (!inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][30]& inst[i][31]) |
(!inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][30]& inst[i][31]) | (!inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][30]&!inst[i][31]) |
( inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) | ( inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][30]&!inst[i][31]) |
(!inst[i][26]& inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][30]&!inst[i][31]) | ( inst[i][26]& inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][30]&!inst[i][31]) |
( inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][30]& inst[i][31]) | (!inst[i][26]& inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][30]& inst[i][31]) |
( inst[i][26]&!inst[i][27]& inst[i][28]&!inst[i][29]& inst[i][30]& inst[i][31]) | (!inst[i][26]& inst[i][27]& inst[i][28]&!inst[i][29]& inst[i][30]& inst[i][31]) |
( inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][30]& inst[i][31]) | (!inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][30]& inst[i][31]) |
( inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]& inst[i][30]& inst[i][31]) | (!inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]& inst[i][30]& inst[i][31]) |
(!inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][30]&!inst[i][31]) | ( inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][30]&!inst[i][31]) |
(!inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][30]&!inst[i][31]) | ( inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][30]&!inst[i][31]) |
( inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]& inst[i][30]&!inst[i][31]) | (!inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]& inst[i][30]&!inst[i][31]) |
( inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]& inst[i][30]&!inst[i][31]) | ( inst[i][26]& inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) |
(!inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) | ( inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) |
(!inst[i][26]&!inst[i][27]& inst[i][28]&!inst[i][29]& inst[i][30]& inst[i][31]) | ( inst[i][26]& inst[i][27]& inst[i][28]&!inst[i][29]& inst[i][30]& inst[i][31]) |
(!inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]& inst[i][30]& inst[i][31]) | ( inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]& inst[i][30]& inst[i][31]) |
( inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][30]& inst[i][31]) | (!inst[i][26]&!inst[i][27]& inst[i][28]&!inst[i][29]& inst[i][30]&!inst[i][31]) |
( inst[i][26]&!inst[i][27]& inst[i][28]&!inst[i][29]& inst[i][30]&!inst[i][31]) | (!inst[i][26]& inst[i][27]& inst[i][28]&!inst[i][29]& inst[i][30]&!inst[i][31])))));
	assign	extendAction_up[i][0]	=	( inst[i][28]& inst[i][29]&!inst[i][31]);
	assign	extendAction_up[i][1]	=	(!inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][31]) | ( inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][31]) |
(!inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][31]) | ( inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][31]) |
(!inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][31]) | (!inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][31]) |
(!inst[i][27]& inst[i][28]&!inst[i][29]& inst[i][31]) | ( inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][31]) |
( inst[i][27]& inst[i][28]&!inst[i][29]& inst[i][31]) | (!inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][31]) |
( inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][31]) | ( inst[i][27]& inst[i][28]& inst[i][29]& inst[i][31]);
	assign	extendAction_up[i][2]	=	( inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][31]);
	assign	aluOprator_up[i][0]	=	((temp_0_3) & (1'b0)) |
 (!(temp_0_3) & (( inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][31])));
	assign	aluOprator_up[i][1]	=	((temp_0_2) & (( inst[i][0]&!inst[i][3]&!inst[i][4]&!inst[i][5]))) |
 (!(temp_0_2) & (((temp_0_0) & (1'b0)) |
 (!(temp_0_0) & (1'b0))));
	assign	aluOprator_up[i][2]	=	((temp_0_2) & ((!inst[i][0]& inst[i][1]&!inst[i][3]&!inst[i][4]&!inst[i][5]))) |
 (!(temp_0_2) & (((temp_0_0) & (1'b0)) |
 (!(temp_0_0) & (1'b0))));
	assign	aluOprator_up[i][3]	=	((temp_0_2) & ((!inst[i][1]&!inst[i][3]&!inst[i][4]&!inst[i][5]))) |
 (!(temp_0_2) & (((temp_0_0) & (1'b0)) |
 (!(temp_0_0) & (1'b0))));
	assign	aluOprator_up[i][4]	=	((temp_0_2) & (( inst[i][0]& inst[i][3]& inst[i][5]))) |
 (!(temp_0_2) & (((temp_0_1) & (( inst[i][16]& inst[i][19]))) |
 (!(temp_0_1) & (((temp_0_0) & (1'b0)) |
 (!(temp_0_0) & (( inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][31])))))));
	assign	aluOprator_up[i][5]	=	((temp_0_2) & ((!inst[i][0]&!inst[i][2]& inst[i][3]&!inst[i][4]& inst[i][5]) | (!inst[i][0]&!inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]) |
( inst[i][0]&!inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]))) |
 (!(temp_0_2) & (((temp_0_1) & ((!inst[i][16]&!inst[i][18]& inst[i][19]))) |
 (!(temp_0_1) & (((temp_0_0) & (1'b0)) |
 (!(temp_0_0) & ((!inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][31])))))));
	assign	aluOprator_up[i][6]	=	((temp_0_2) & ((!inst[i][0]& inst[i][1]& inst[i][2]&!inst[i][4]& inst[i][5]))) |
 (!(temp_0_2) & (((temp_0_0) & (1'b0)) |
 (!(temp_0_0) & ((!inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][31])))));
	assign	aluOprator_up[i][7]	=	((temp_0_2) & (( inst[i][0]& inst[i][1]& inst[i][2]& inst[i][5]))) |
 (!(temp_0_2) & (((temp_0_0) & (1'b0)) |
 (!(temp_0_0) & (1'b0))));
	assign	aluOprator_up[i][8]	=	((temp_0_2) & (( inst[i][0]&!inst[i][1]& inst[i][2]))) |
 (!(temp_0_2) & (((temp_0_0) & (1'b0)) |
 (!(temp_0_0) & (( inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29])))));
	assign	aluOprator_up[i][9]	=	((temp_0_2) & ((!inst[i][0]&!inst[i][1]& inst[i][2]&!inst[i][4]& inst[i][5]))) |
 (!(temp_0_2) & (((temp_0_0) & (1'b0)) |
 (!(temp_0_0) & ((!inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29])))));
	assign	aluOprator_up[i][10]	=	((temp_0_2) & (( inst[i][1]&!inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) | (!inst[i][1]& inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]) |
( inst[i][1]& inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]))) |
 (!(temp_0_2) & (((temp_0_1) & (( inst[i][18]))) |
 (!(temp_0_1) & (((temp_0_0) & (1'b0)) |
 (!(temp_0_0) & (1'b0))))));
	assign	aluOprator_up[i][11]	=	((temp_0_2) & ((!inst[i][1]&!inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) | (!inst[i][1]&!inst[i][2]& inst[i][3]&!inst[i][4]&!inst[i][5]))) |
 (!(temp_0_2) & (((temp_0_1) & ((!inst[i][19]))) |
 (!(temp_0_1) & (((temp_0_0) & ((!inst[i][25]))) |
 (!(temp_0_0) & ((!inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][31]) | (!inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][31]) |
( inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][31]) | ( inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][31]) |
(!inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][31]) | (!inst[i][27]& inst[i][28]&!inst[i][29]& inst[i][31]) |
( inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][31]) | ( inst[i][27]& inst[i][28]&!inst[i][29]& inst[i][31]) |
(!inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][31]) | ( inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][31]) |
( inst[i][27]& inst[i][28]& inst[i][29]& inst[i][31])))))));
	assign	aluOprator_up[i][12]	=	((temp_0_2) & ((!inst[i][0]& inst[i][1]& inst[i][3]&!inst[i][4]&!inst[i][5]))) |
 (!(temp_0_2) & (((temp_0_0) & (1'b0)) |
 (!(temp_0_0) & (1'b0))));
	assign	aluOprator_up[i][13]	=	((temp_0_2) & (( inst[i][0]& inst[i][1]& inst[i][3]&!inst[i][4]&!inst[i][5]))) |
 (!(temp_0_2) & (((temp_0_0) & (1'b0)) |
 (!(temp_0_0) & (1'b0))));
	assign	trapKind_up[i][0]	=	((temp_0_2) & ((!inst[i][1]&!inst[i][2]))) |
 (!(temp_0_2) & (((temp_0_1) & (1'b0)) |
 (!(temp_0_1) & (1'b0))));
	assign	trapKind_up[i][1]	=	((temp_0_2) & (( inst[i][1]&!inst[i][2]))) |
 (!(temp_0_2) & (((temp_0_1) & ((!inst[i][18]))) |
 (!(temp_0_1) & (1'b0))));
	assign	trapKind_up[i][2]	=	((temp_0_2) & (( inst[i][1]& inst[i][2]))) |
 (!(temp_0_2) & (((temp_0_1) & (( inst[i][17]& inst[i][18]))) |
 (!(temp_0_1) & (1'b0))));
	assign	trapKind_up[i][3]	=	((temp_0_2) & ((!inst[i][1]& inst[i][2]))) |
 (!(temp_0_2) & (((temp_0_1) & ((!inst[i][17]& inst[i][18]))) |
 (!(temp_0_1) & (1'b0))));
	assign	exceptionSel_up[i][0]	=	((temp_0_2) & (( inst[i][4]& inst[i][5]))) |
 (!(temp_0_2) & (((temp_0_1) & (( inst[i][19]))) |
 (!(temp_0_1) & (1'b0))));
	assign	exceptionSel_up[i][1]	=	((temp_0_2) & ((!inst[i][0]&!inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]))) |
 (!(temp_0_2) & ((!inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][30]&!inst[i][31])));
/*autoDecoder0_End*/ /*}}}*/
		    end
    endgenerate
	/*autoDecoder1_Start*/ /*{{{*/
wire temp_1_0 = (!inst[0][26]&!inst[0][27]&!inst[0][28]&!inst[0][29]&!inst[0][30]&!inst[0][31]);
wire temp_1_1 = (!inst[0][27]&!inst[0][28]&!inst[0][29]&!inst[0][30]&!inst[0][31]);

	assign	ID_up_branchKind_o[0]	=	((temp_1_0) & (1'b0)) |
 (!(temp_1_0) & (( inst[0][26]& inst[0][27]& inst[0][28])));
	assign	ID_up_branchKind_o[1]	=	((temp_1_0) & (1'b0)) |
 (!(temp_1_0) & ((!inst[0][26]& inst[0][27]& inst[0][28])));
	assign	ID_up_branchKind_o[2]	=	((temp_1_0) & (1'b0)) |
 (!(temp_1_0) & (((temp_1_1) & ((!inst[0][16]))) |
 (!(temp_1_1) & (1'b0))));
	assign	ID_up_branchKind_o[3]	=	((temp_1_0) & (1'b0)) |
 (!(temp_1_0) & (((temp_1_1) & (( inst[0][16]))) |
 (!(temp_1_1) & (1'b0))));
	assign	ID_up_branchKind_o[4]	=	((temp_1_0) & (1'b0)) |
 (!(temp_1_0) & (( inst[0][26]&!inst[0][27]& inst[0][28])));
	assign	ID_up_branchKind_o[5]	=	((temp_1_0) & (1'b0)) |
 (!(temp_1_0) & ((!inst[0][26]&!inst[0][27])));
	assign	ID_up_branchRisk_o	=	((temp_1_0) & ((!inst[0][1]&!inst[0][2]& inst[0][3]&!inst[0][4]))) |
 (!(temp_1_0) & (((temp_1_1) & ((!inst[0][19]))) |
 (!(temp_1_1) & ((!inst[0][29]&!inst[0][30]&!inst[0][31])))));
	assign	ID_up_repairAction_o[0]	=	((temp_1_0) & ((!inst[0][5]))) |
 (!(temp_1_0) & ((!inst[0][31])));
	assign	ID_up_repairAction_o[1]	=	((temp_1_0) & (1'b0)) |
 (!(temp_1_0) & (1'b0));
	assign	ID_up_repairAction_o[2]	=	((temp_1_0) & ((!inst[0][5]))) |
 (!(temp_1_0) & (( inst[0][26]& inst[0][27]&!inst[0][28])));
	assign	ID_up_repairAction_o[3]	=	((temp_1_0) & ((!inst[0][0]))) |
 (!(temp_1_0) & (((temp_1_1) & ((!inst[0][20]))) |
 (!(temp_1_1) & ((!inst[0][26]& inst[0][28]) | ( inst[0][26]& inst[0][28]) |
(!inst[0][26]&!inst[0][28])))));
	assign	ID_up_repairAction_o[4]	=	((temp_1_0) & ((!inst[0][0]))) |
 (!(temp_1_0) & (((temp_1_1) & ((!inst[0][20]))) |
 (!(temp_1_1) & ((!inst[0][26]& inst[0][28]) | ( inst[0][26]& inst[0][28]) |
(!inst[0][26]&!inst[0][28])))));
	assign	ID_up_repairAction_o[5]	=	((temp_1_0) & (1'b0)) |
 (!(temp_1_0) & (1'b0));
	assign	ID_up_repairAction_o[6]	=	((temp_1_0) & (1'b0)) |
 (!(temp_1_0) & ((!inst[0][27]& inst[0][28]) | ( inst[0][27]& inst[0][28]) |
(!inst[0][27]&!inst[0][28])));
	assign	ID_up_repairAction_o[7]	=	((temp_1_0) & ((!inst[0][1]&!inst[0][2]& inst[0][3]&!inst[0][4]))) |
 (!(temp_1_0) & (((temp_1_1) & ((!inst[0][19]))) |
 (!(temp_1_1) & ((!inst[0][29]&!inst[0][30]&!inst[0][31])))));
/*autoDecoder1_End*/ /*}}}*/
	/*autoDecoder2_Start*/ /*{{{*/
wire temp_2_0 = ( inst[1][25]);
wire temp_2_1 = (!inst[1][26]&!inst[1][27]&!inst[1][29]& inst[1][30]&!inst[1][31]);
wire temp_2_2 = (!inst[1][26]&!inst[1][27]& inst[1][28]& inst[1][30]&!inst[1][31]);
wire temp_2_3 = (!inst[1][26]&!inst[1][27]&!inst[1][28]&!inst[1][29]&!inst[1][30]&!inst[1][31]);

	assign	ID_down_isDangerous_o	=	((temp_2_1) & (((temp_2_0) & ((!inst[1][4]))) |
 (!(temp_2_0) & (1'b0)))) |
 (!(temp_2_1) & (( inst[1][26]& inst[1][27]& inst[1][28]& inst[1][29]&!inst[1][30]& inst[1][31])));
	assign	ID_down_mduOperator_o[0]	=	((temp_2_3) & ((!inst[1][0]&!inst[1][1]& inst[1][3]& inst[1][4]))) |
 (!(temp_2_3) & (((temp_2_2) & ((!inst[1][0]&!inst[1][1]&!inst[1][5]))) |
 (!(temp_2_2) & (1'b0))));
	assign	ID_down_mduOperator_o[1]	=	((temp_2_3) & (( inst[1][0]&!inst[1][1]& inst[1][3]& inst[1][4]))) |
 (!(temp_2_3) & (((temp_2_2) & (( inst[1][0]&!inst[1][5]))) |
 (!(temp_2_2) & (1'b0))));
	assign	ID_down_mduOperator_o[2]	=	((temp_2_3) & ((!inst[1][0]& inst[1][1]& inst[1][3]& inst[1][4]))) |
 (!(temp_2_3) & (1'b0));
	assign	ID_down_mduOperator_o[3]	=	((temp_2_3) & (( inst[1][0]& inst[1][1]& inst[1][3]& inst[1][4]))) |
 (!(temp_2_3) & (1'b0));
	assign	ID_down_mduOperator_o[4]	=	((temp_2_2) & ((!inst[1][1]&!inst[1][2]&!inst[1][5]))) |
 (!(temp_2_2) & (1'b0));
	assign	ID_down_mduOperator_o[5]	=	((temp_2_2) & (( inst[1][2]))) |
 (!(temp_2_2) & (1'b0));
	assign	ID_down_mduOperator_o[6]	=	((temp_2_2) & (( inst[1][1]))) |
 (!(temp_2_2) & (1'b0));
	assign	ID_down_mduOperator_o[7]	=	((temp_2_2) & (( inst[1][0]& inst[1][5]))) |
 (!(temp_2_2) & (1'b0));
	assign	ID_down_mduOperator_o[8]	=	((temp_2_2) & ((!inst[1][0]& inst[1][5]))) |
 (!(temp_2_2) & (1'b0));
	assign	ID_down_readHiLo_o[0]	=	((temp_2_3) & ((!inst[1][0]&!inst[1][1]&!inst[1][3]& inst[1][4]&!inst[1][5]))) |
 (!(temp_2_3) & (((temp_2_2) & ((!inst[1][1]&!inst[1][5]))) |
 (!(temp_2_2) & (1'b0))));
	assign	ID_down_readHiLo_o[1]	=	((temp_2_3) & ((!inst[1][0]& inst[1][1]&!inst[1][3]& inst[1][4]&!inst[1][5]))) |
 (!(temp_2_3) & (((temp_2_2) & ((!inst[1][1]&!inst[1][5]))) |
 (!(temp_2_2) & (1'b0))));
	assign	ID_down_writeHiLo_o[0]	=	((temp_2_3) & (( inst[1][0]&!inst[1][1]&!inst[1][3]&!inst[1][5]))) |
 (!(temp_2_3) & (((temp_2_2) & ((!inst[1][1]&!inst[1][5]))) |
 (!(temp_2_2) & (1'b0))));
	assign	ID_down_writeHiLo_o[1]	=	((temp_2_3) & (( inst[1][0]& inst[1][1]&!inst[1][3]& inst[1][4]&!inst[1][5]))) |
 (!(temp_2_3) & (((temp_2_2) & ((!inst[1][1]&!inst[1][5]))) |
 (!(temp_2_2) & (1'b0))));
	assign	ID_down_readCp0_o	=	((temp_2_1) & ((!inst[1][23]&!inst[1][25]))) |
 (!(temp_2_1) & (1'b0));
	assign	ID_down_writeCp0_o	=	((temp_2_1) & (( inst[1][23]))) |
 (!(temp_2_1) & (1'b0));
	assign	ID_down_memReq_o	=	(!inst[1][26]&!inst[1][27]&!inst[1][28]&!inst[1][29]&!inst[1][30]& inst[1][31]) | (!inst[1][26]&!inst[1][27]& inst[1][28]&!inst[1][29]&!inst[1][30]& inst[1][31]) |
( inst[1][26]&!inst[1][27]&!inst[1][28]&!inst[1][29]&!inst[1][30]& inst[1][31]) | ( inst[1][26]&!inst[1][27]& inst[1][28]&!inst[1][29]&!inst[1][30]& inst[1][31]) |
( inst[1][26]& inst[1][27]&!inst[1][28]&!inst[1][29]&!inst[1][30]& inst[1][31]) | (!inst[1][26]& inst[1][27]&!inst[1][28]&!inst[1][29]&!inst[1][30]& inst[1][31]) |
(!inst[1][26]& inst[1][27]& inst[1][28]&!inst[1][29]&!inst[1][30]& inst[1][31]) | (!inst[1][26]&!inst[1][27]&!inst[1][28]& inst[1][29]&!inst[1][30]& inst[1][31]) |
( inst[1][26]&!inst[1][27]&!inst[1][28]& inst[1][29]&!inst[1][30]& inst[1][31]) | ( inst[1][26]& inst[1][27]&!inst[1][28]& inst[1][29]&!inst[1][30]& inst[1][31]) |
(!inst[1][26]& inst[1][27]&!inst[1][28]& inst[1][29]&!inst[1][30]& inst[1][31]) | (!inst[1][26]& inst[1][27]& inst[1][28]& inst[1][29]&!inst[1][30]& inst[1][31]) |
(!inst[1][26]&!inst[1][27]&!inst[1][28]&!inst[1][29]& inst[1][30]& inst[1][31]) | (!inst[1][26]&!inst[1][27]&!inst[1][28]& inst[1][29]& inst[1][30]& inst[1][31]);
	assign	ID_down_memWR_o	=	( inst[1][29]);
	assign	ID_down_memAtom_o	=	( inst[1][30]);
	assign	ID_down_loadMode_o[0]	=	(!inst[1][26]&!inst[1][27]&!inst[1][28]&!inst[1][29]&!inst[1][30]);
	assign	ID_down_loadMode_o[1]	=	(!inst[1][26]&!inst[1][27]& inst[1][28]);
	assign	ID_down_loadMode_o[2]	=	( inst[1][26]&!inst[1][27]&!inst[1][28]&!inst[1][29]);
	assign	ID_down_loadMode_o[3]	=	( inst[1][26]& inst[1][28]);
	assign	ID_down_loadMode_o[4]	=	( inst[1][26]& inst[1][27]&!inst[1][29]&!inst[1][30]) | (!inst[1][26]&!inst[1][27]&!inst[1][29]& inst[1][30]);
	assign	ID_down_loadMode_o[5]	=	(!inst[1][26]& inst[1][27]&!inst[1][28]&!inst[1][29]);
	assign	ID_down_loadMode_o[6]	=	( inst[1][27]& inst[1][28]&!inst[1][29]);
	assign	ID_down_storeMode_o[0]	=	(!inst[1][26]&!inst[1][27]& inst[1][29]&!inst[1][30]);
	assign	ID_down_storeMode_o[1]	=	( inst[1][26]&!inst[1][27]& inst[1][29]);
	assign	ID_down_storeMode_o[2]	=	(!inst[1][26]& inst[1][27]&!inst[1][29]&!inst[1][30]) | ( inst[1][26]& inst[1][27]& inst[1][29]&!inst[1][30]) |
(!inst[1][26]&!inst[1][27]& inst[1][29]& inst[1][30]);
	assign	ID_down_storeMode_o[3]	=	(!inst[1][26]& inst[1][27]&!inst[1][28]& inst[1][29]);
	assign	ID_down_storeMode_o[4]	=	( inst[1][28]& inst[1][29]);
	assign	ID_down_eret_o	=	((temp_2_1) & (((temp_2_0) & (( inst[1][4]))) |
 (!(temp_2_0) & (1'b0)))) |
 (!(temp_2_1) & (1'b0));
	assign	ID_down_isTLBInst_o	=	((temp_2_1) & (((temp_2_0) & ((!inst[1][4]))) |
 (!(temp_2_0) & (1'b0)))) |
 (!(temp_2_1) & (1'b0));
	assign	ID_down_TLBInstOperator_o[0]	=	((temp_2_1) & (((temp_2_0) & (( inst[1][3]))) |
 (!(temp_2_0) & (1'b0)))) |
 (!(temp_2_1) & (1'b0));
	assign	ID_down_TLBInstOperator_o[1]	=	((temp_2_1) & (((temp_2_0) & (( inst[1][0]))) |
 (!(temp_2_0) & (1'b0)))) |
 (!(temp_2_1) & (1'b0));
	assign	ID_down_TLBInstOperator_o[2]	=	((temp_2_1) & (((temp_2_0) & (( inst[1][1]&!inst[1][2]))) |
 (!(temp_2_0) & (1'b0)))) |
 (!(temp_2_1) & (1'b0));
	assign	ID_down_TLBInstOperator_o[3]	=	((temp_2_1) & (((temp_2_0) & (( inst[1][2]))) |
 (!(temp_2_0) & (1'b0)))) |
 (!(temp_2_1) & (1'b0));
	assign	ID_down_isCacheInst_o	=	( inst[1][26]& inst[1][27]& inst[1][28]& inst[1][29]&!inst[1][30]& inst[1][31]);
/*autoDecoder2_End*/ /*}}}*/
    // }}}
endmodule

