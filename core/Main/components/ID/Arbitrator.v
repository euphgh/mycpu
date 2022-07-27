// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/06/30 19:58
// Last Modified : 2022/07/27 12:10
// File Name     : Arbitrator.v
// Description   : 根据初步解码的指令类型和寄存器读写，进行发射分配和生成InstQueue的指令需求
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/06/30   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "MyDefines.v"
module Arbitrator(
    input	wire    [`IQ_VALID]                 IQ_supplyValid,   // 可选宏定义三种
    input	wire    [2*`SINGLE_WORD]            IQ_inst_p,
    input	wire    [2*`SINGLE_WORD]            IQ_VAddr_p,
    input	wire    [1:0]                       IQ_hasException_p,
    input   wire    [2*`EXCCODE]                IQ_ExcCode_p,
    input	wire	[1:0]                       IQ_isRefill_p,
    input   wire    [2*`SINGLE_WORD]            IQ_predDest_p,
    input   wire    [1:0]                       IQ_predTake_p,
    input   wire    [2*`ALL_CHECKPOINT]         IQ_checkPoint_p,

    output	wire	[2*`SINGLE_WORD]            AB_Inst_p,        // 经过选择分发指令,[0]在上流水线，[1]在下
    output	wire    [2*`SINGLE_WORD]            AB_VAddr_p,
    output  wire    [2*`SINGLE_WORD]            AB_predDest_p,
    output	wire    [1:0]                       AB_hasException_p,
    output  wire    [1:0]                       AB_predTake_p,
    output  wire    [2*`EXCCODE]                AB_ExcCode_p,
    output  wire    [1:0]                       AB_isRefill_p,
    output  wire    [2*`ALL_CHECKPOINT]         AB_checkPoint_p,

    output	wire	[`ISSUE_MODE]               AB_issueMode_w,   // 表示发射类型，同时也可以作为指令使能
    output	wire	[4*`GPR_NUM]                AB_regReadNum_p_w,
    output	wire	[3:0]                       AB_needRead_p_w,                       
    output	wire	[2*`GPR_NUM]                AB_regWriteNum_p_w
);
    // 发射规则{{{
    wire    [1:0]           instMode    [1:0];
    wire    [`GPR_NUM]      ReadRs      [1:0];  // 指令的部分截取
    wire    [`GPR_NUM]      ReadRt      [1:0];  // 指令的部分截取
    wire    [`GPR_NUM]      writeRd     [1:0];  // 表示写入的寄存器，可能是rt也可能是rd
    wire                    isNeedRs    [1:0];  // 指令是否存在读寄存器的需求
    wire                    isNeedRt    [1:0];  // 指令是否存在读寄存器的需求
    wire                    isNeedRd    [1:0];  // 指令是否存在写寄存器的需求

    // 指令种类的冲突，当0号指令可以在0号槽双发且1号指令可以在1号槽双发，才能双发
    wire    kindConflict0   = !(|(instMode[0] & `AT_SLOT_ZERO));
    wire    kindConflict1   = !(|(instMode[1] & `AT_SLOT_ONE));
    wire    dual_kindConflict   = kindConflict0 || kindConflict1;
    wire    single_kindConflict = !(|(instMode[0] & `AT_SLOT_ONE));
    // 指令数据的冲突，是否存在写后读
    wire    dataConflict = isNeedRd[0] && ((isNeedRs[1] && (ReadRs[1]==writeRd[0]))||(isNeedRt[1] && (ReadRt[1]==writeRd[0])));
    assign AB_issueMode_w =     IQ_supplyValid  [1] ? ((dataConflict || dual_kindConflict) ? `SINGLE_ISSUE : `DUAL_ISSUE) :
                                IQ_supplyValid  [0] ? (single_kindConflict ? `NO_ISSUE : `SINGLE_ISSUE) : `NO_ISSUE;
 
    wire    [2*`GPR_NUM]    IQ_regReadNum_up    [1:0];
    wire    [`GPR_NUM]      IQ_regWriteNum_up   [1:0];
    wire    [1:0]           IQ_needRead_up      [1:0];
    wire    [2*`GPR_NUM]    AB_regReadNum_up    [1:0];
    wire    [`GPR_NUM]      AB_regWriteNum_up   [1:0];
    wire    [1:0]           AB_needRead_up      [1:0];
    assign  IQ_regReadNum_up[0] = {({5{isNeedRt[0]}} & ReadRt[0]),({5{isNeedRs[0]}} & ReadRs[0])};
    assign  IQ_regReadNum_up[1] = {({5{isNeedRt[1]}} & ReadRt[1]),({5{isNeedRs[1]}} & ReadRs[1])};
    assign  IQ_regWriteNum_up[0]= {5{isNeedRd[0]}} & writeRd[0];
    assign  IQ_regWriteNum_up[1]= {5{isNeedRd[1]}} & writeRd[1];
    assign  IQ_needRead_up[0]   = {isNeedRt[0],isNeedRs[0]};
    assign  IQ_needRead_up[1]   = {isNeedRt[1],isNeedRs[1]};
    // }}}
    // 解包和压缩包{{{
    wire    [   3*`SINGLE_WORD_LEN+
                3*1+
                `EXCCODE_LEN+
                `ALL_CHECKPOINT_LEN + 
                3*`GPR_NUM_LEN + 
                2 + 
                -1:0]    allInfo_i[1:0] , allInfo_o [1:0];
    wire    [`SINGLE_WORD]              AB_VAddr_up           [1:0];  
    wire    [`SINGLE_WORD]              AB_inst_up            [1:0];  
    wire    [0:0]                       AB_hasException_up    [1:0];  
    wire    [0:0]                       AB_isRefill_up        [1:0];  
    wire    [`EXCCODE]                  AB_ExcCode_up         [1:0];  
    wire    [`SINGLE_WORD]              AB_predDest_up        [1:0];  
    wire    [0:0]                       AB_predTake_up        [1:0];  
    wire    [`ALL_CHECKPOINT]           AB_checkPoint_up      [1:0];  
    `PACK_ARRAY(`SINGLE_WORD_LEN,2,AB_VAddr_up,AB_VAddr_p)
    `PACK_ARRAY(`SINGLE_WORD_LEN,2,AB_inst_up,AB_Inst_p)
    `PACK_ARRAY(1,2,AB_hasException_up,AB_hasException_p)
    `PACK_ARRAY(`SINGLE_WORD_LEN,2,AB_predDest_up,AB_predDest_p)
    `PACK_ARRAY(1,2,AB_predTake_up,AB_predTake_p)
    `PACK_ARRAY(`ALL_CHECKPOINT_LEN,2,AB_checkPoint_up,AB_checkPoint_p)
    `PACK_ARRAY(`EXCCODE_LEN,2,AB_ExcCode_up,AB_ExcCode_p)
    `PACK_ARRAY(1,2,AB_isRefill_up,AB_isRefill_p)
    `PACK_ARRAY(2*`GPR_NUM_LEN,2,AB_regReadNum_up,AB_regReadNum_p_w)
    `PACK_ARRAY(`GPR_NUM_LEN,2,AB_regWriteNum_up,AB_regWriteNum_p_w)
    `PACK_ARRAY(2,2,AB_needRead_up,AB_needRead_p_w)
    wire    [`SINGLE_WORD]              IQ_VAddr_up           [1:0];  
    wire    [`SINGLE_WORD]              IQ_inst_up            [1:0];  
    wire    [0:0]                       IQ_hasException_up    [1:0];  
    wire    [`EXCCODE]                  IQ_ExcCode_up         [1:0];  
    wire    [0:0]                       IQ_isRefill_up        [1:0];  
    wire    [`SINGLE_WORD]              IQ_predDest_up        [1:0];  
    wire    [0:0]                       IQ_predTake_up        [1:0];  
    wire    [`ALL_CHECKPOINT]           IQ_checkPoint_up      [1:0];  
    `UNPACK_ARRAY(`SINGLE_WORD_LEN,2,IQ_VAddr_up,IQ_VAddr_p  )
    `UNPACK_ARRAY(`SINGLE_WORD_LEN,2,IQ_inst_up,IQ_inst_p  )
    `UNPACK_ARRAY(1,2,IQ_hasException_up,IQ_hasException_p  )
    `UNPACK_ARRAY(`SINGLE_WORD_LEN,2,IQ_predDest_up,IQ_predDest_p  )
    `UNPACK_ARRAY(1,2,IQ_predTake_up,IQ_predTake_p  )
    `UNPACK_ARRAY(`ALL_CHECKPOINT_LEN,2,IQ_checkPoint_up,IQ_checkPoint_p  )
    `UNPACK_ARRAY(`EXCCODE_LEN,2,IQ_ExcCode_up,IQ_ExcCode_p  )
    `UNPACK_ARRAY(1,2,IQ_isRefill_up,IQ_isRefill_p  )
    generate
    for (genvar i = 0; i < 2; i=i+1)	begin
        assign allInfo_i[i] = {
                IQ_VAddr_up[i],
                IQ_inst_up[i],
                IQ_predDest_up[i],
                IQ_predTake_up[i],
                IQ_checkPoint_up[i],
                IQ_hasException_up[i],
                IQ_ExcCode_up[i],
                IQ_isRefill_up[i],
                IQ_regReadNum_up[i],
                IQ_regWriteNum_up[i],
                IQ_needRead_up[i]
                };
        assign {
                AB_VAddr_up[i],
                AB_inst_up[i],
                AB_predDest_up[i],
                AB_predTake_up[i],
                AB_checkPoint_up[i],
                AB_hasException_up[i],
                AB_ExcCode_up[i],
                AB_isRefill_up[i],
                AB_regReadNum_up[i],
                AB_regWriteNum_up[i],
                AB_needRead_up[i]
                } = allInfo_o[i];
    end
    endgenerate
/*}}}*/
    // 指令发射流水线选择{{{
    assign allInfo_o[0] = allInfo_i[0];
    assign allInfo_o[1] = (AB_issueMode_w==`SINGLE_ISSUE) ? allInfo_i[0] : allInfo_i[1];
/*}}}*/
    // 定义解码{{{
    wire    [`SINGLE_WORD]  inst    [1:0];
    generate
        for (genvar i = 0; i < 2; i = i+1)	begin
            wire writeToRt;         // 输出到的目的寄存器是rt
            wire link;              // 输出到的目的寄存器是31，优先级较高
            assign inst[i]      =   IQ_inst_up[i];
            assign ReadRs[i]    =   inst[i][25:21];
            assign ReadRt[i]    =   inst[i][20:16];
            assign writeRd[i]   =   (writeToRt  ? inst[i][20:16] : inst[i][15:11]) | {5{link}}; 
	/*autoDecoder_Start*/ /*{{{*/
wire temp0 = (!inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31]);
wire temp1 = (!inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][30]&!inst[i][31]);
wire temp2 = ( inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31]);
wire temp3 = (!inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]& inst[i][30]&!inst[i][31]);

	assign	isNeedRs[i]	=	((temp0) & ((!inst[i][0]&!inst[i][1]&!inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) | ( inst[i][0]&!inst[i][1]&!inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) |
(!inst[i][0]& inst[i][1]&!inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) | ( inst[i][0]& inst[i][1]&!inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) |
(!inst[i][0]&!inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) | ( inst[i][0]&!inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) |
(!inst[i][0]& inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) | ( inst[i][0]& inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) |
(!inst[i][0]& inst[i][1]&!inst[i][2]& inst[i][3]&!inst[i][4]& inst[i][5]) | ( inst[i][0]& inst[i][1]&!inst[i][2]& inst[i][3]&!inst[i][4]& inst[i][5]) |
( inst[i][0]& inst[i][1]&!inst[i][2]& inst[i][3]&!inst[i][4]&!inst[i][5]) | (!inst[i][0]& inst[i][1]&!inst[i][2]& inst[i][3]&!inst[i][4]&!inst[i][5]) |
(!inst[i][0]&!inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]&!inst[i][5]) | (!inst[i][0]& inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]&!inst[i][5]) |
( inst[i][0]& inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]&!inst[i][5]) | (!inst[i][0]&!inst[i][1]&!inst[i][2]& inst[i][3]& inst[i][4]&!inst[i][5]) |
( inst[i][0]&!inst[i][1]&!inst[i][2]& inst[i][3]& inst[i][4]&!inst[i][5]) | (!inst[i][0]& inst[i][1]&!inst[i][2]& inst[i][3]& inst[i][4]&!inst[i][5]) |
( inst[i][0]& inst[i][1]&!inst[i][2]& inst[i][3]& inst[i][4]&!inst[i][5]) | ( inst[i][0]&!inst[i][1]&!inst[i][2]&!inst[i][3]& inst[i][4]&!inst[i][5]) |
( inst[i][0]& inst[i][1]&!inst[i][2]&!inst[i][3]& inst[i][4]&!inst[i][5]) | (!inst[i][0]&!inst[i][1]&!inst[i][2]& inst[i][3]&!inst[i][4]&!inst[i][5]) |
( inst[i][0]&!inst[i][1]&!inst[i][2]& inst[i][3]&!inst[i][4]&!inst[i][5]) | (!inst[i][0]&!inst[i][1]&!inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]) |
( inst[i][0]&!inst[i][1]&!inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]) | (!inst[i][0]& inst[i][1]&!inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]) |
( inst[i][0]& inst[i][1]&!inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]) | (!inst[i][0]&!inst[i][1]& inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]) |
(!inst[i][0]& inst[i][1]& inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]))) |
 (!(temp0) & ((!inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) | ( inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) |
(!inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) | ( inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) |
(!inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) | ( inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) |
(!inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) | ( inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) |
(!inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]& inst[i][30]&!inst[i][31]) | (!inst[i][26]&!inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31]) |
( inst[i][26]&!inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31]) | ( inst[i][26]& inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31]) |
(!inst[i][26]& inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31]) | ( inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31]) |
(!inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) | (!inst[i][26]&!inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) |
( inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) | ( inst[i][26]&!inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) |
( inst[i][26]& inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) | (!inst[i][26]& inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) |
(!inst[i][26]& inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) | (!inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) |
( inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) | ( inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) |
(!inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) | (!inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) |
(!inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][30]& inst[i][31]) | (!inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][30]& inst[i][31]) |
( inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31])));
	assign	isNeedRt[i]	=	((temp0) & ((!inst[i][0]&!inst[i][1]&!inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) | ( inst[i][0]&!inst[i][1]&!inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) |
(!inst[i][0]& inst[i][1]&!inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) | ( inst[i][0]& inst[i][1]&!inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) |
(!inst[i][0]&!inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) | ( inst[i][0]&!inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) |
(!inst[i][0]& inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) | ( inst[i][0]& inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) |
(!inst[i][0]& inst[i][1]&!inst[i][2]& inst[i][3]&!inst[i][4]& inst[i][5]) | ( inst[i][0]& inst[i][1]&!inst[i][2]& inst[i][3]&!inst[i][4]& inst[i][5]) |
( inst[i][0]& inst[i][1]&!inst[i][2]& inst[i][3]&!inst[i][4]&!inst[i][5]) | (!inst[i][0]& inst[i][1]&!inst[i][2]& inst[i][3]&!inst[i][4]&!inst[i][5]) |
(!inst[i][0]&!inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]&!inst[i][5]) | (!inst[i][0]& inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]&!inst[i][5]) |
( inst[i][0]& inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]&!inst[i][5]) | (!inst[i][0]&!inst[i][1]&!inst[i][2]&!inst[i][3]&!inst[i][4]&!inst[i][5]) |
(!inst[i][0]& inst[i][1]&!inst[i][2]&!inst[i][3]&!inst[i][4]&!inst[i][5]) | ( inst[i][0]& inst[i][1]&!inst[i][2]&!inst[i][3]&!inst[i][4]&!inst[i][5]) |
(!inst[i][0]&!inst[i][1]&!inst[i][2]& inst[i][3]& inst[i][4]&!inst[i][5]) | ( inst[i][0]&!inst[i][1]&!inst[i][2]& inst[i][3]& inst[i][4]&!inst[i][5]) |
(!inst[i][0]& inst[i][1]&!inst[i][2]& inst[i][3]& inst[i][4]&!inst[i][5]) | ( inst[i][0]& inst[i][1]&!inst[i][2]& inst[i][3]& inst[i][4]&!inst[i][5]) |
(!inst[i][0]&!inst[i][1]&!inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]) | ( inst[i][0]&!inst[i][1]&!inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]) |
(!inst[i][0]& inst[i][1]&!inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]) | ( inst[i][0]& inst[i][1]&!inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]) |
(!inst[i][0]&!inst[i][1]& inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]) | (!inst[i][0]& inst[i][1]& inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]))) |
 (!(temp0) & (((temp1) & (( inst[i][23]&!inst[i][25]))) |
 (!(temp1) & ((!inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]& inst[i][30]&!inst[i][31]) | (!inst[i][26]&!inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31]) |
( inst[i][26]&!inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31]) | (!inst[i][26]& inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) |
(!inst[i][26]& inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) | (!inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) |
( inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) | ( inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) |
(!inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) | (!inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) |
(!inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][30]& inst[i][31])))));
	assign	isNeedRd[i]	=	((temp0) & ((!inst[i][0]&!inst[i][1]&!inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) | ( inst[i][0]&!inst[i][1]&!inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) |
(!inst[i][0]& inst[i][1]&!inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) | ( inst[i][0]& inst[i][1]&!inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) |
(!inst[i][0]&!inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) | ( inst[i][0]&!inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) |
(!inst[i][0]& inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) | ( inst[i][0]& inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) |
(!inst[i][0]& inst[i][1]&!inst[i][2]& inst[i][3]&!inst[i][4]& inst[i][5]) | ( inst[i][0]& inst[i][1]&!inst[i][2]& inst[i][3]&!inst[i][4]& inst[i][5]) |
( inst[i][0]& inst[i][1]&!inst[i][2]& inst[i][3]&!inst[i][4]&!inst[i][5]) | (!inst[i][0]& inst[i][1]&!inst[i][2]& inst[i][3]&!inst[i][4]&!inst[i][5]) |
(!inst[i][0]&!inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]&!inst[i][5]) | (!inst[i][0]& inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]&!inst[i][5]) |
( inst[i][0]& inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]&!inst[i][5]) | (!inst[i][0]&!inst[i][1]&!inst[i][2]&!inst[i][3]&!inst[i][4]&!inst[i][5]) |
(!inst[i][0]& inst[i][1]&!inst[i][2]&!inst[i][3]&!inst[i][4]&!inst[i][5]) | ( inst[i][0]& inst[i][1]&!inst[i][2]&!inst[i][3]&!inst[i][4]&!inst[i][5]) |
(!inst[i][0]&!inst[i][1]&!inst[i][2]&!inst[i][3]& inst[i][4]&!inst[i][5]) | (!inst[i][0]& inst[i][1]&!inst[i][2]&!inst[i][3]& inst[i][4]&!inst[i][5]) |
( inst[i][0]&!inst[i][1]&!inst[i][2]& inst[i][3]&!inst[i][4]&!inst[i][5]))) |
 (!(temp0) & (((temp3) & (( inst[i][0]&!inst[i][1]&!inst[i][2]& inst[i][5]) | (!inst[i][0]&!inst[i][1]&!inst[i][2]& inst[i][5]) |
(!inst[i][0]& inst[i][1]&!inst[i][2]&!inst[i][5]))) |
 (!(temp3) & (((temp2) & (( inst[i][16]&!inst[i][17]&!inst[i][18]&!inst[i][19]& inst[i][20]) | (!inst[i][16]&!inst[i][17]&!inst[i][18]&!inst[i][19]& inst[i][20]))) |
 (!(temp2) & (((temp1) & ((!inst[i][23]&!inst[i][25]) | ( inst[i][23]&!inst[i][25]))) |
 (!(temp1) & ((!inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) | ( inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) |
(!inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) | ( inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) |
(!inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) | ( inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) |
(!inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) | ( inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) |
( inst[i][26]& inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31]) | (!inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) |
(!inst[i][26]&!inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) | ( inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) |
( inst[i][26]&!inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) | ( inst[i][26]& inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) |
(!inst[i][26]& inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) | (!inst[i][26]& inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) |
(!inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][30]& inst[i][31])))))))));
	assign	instMode[i][0]	=	((temp0) & ((!inst[i][0]&!inst[i][1]&!inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) | ( inst[i][0]&!inst[i][1]&!inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) |
(!inst[i][0]& inst[i][1]&!inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) | ( inst[i][0]& inst[i][1]&!inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) |
(!inst[i][0]&!inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) | ( inst[i][0]&!inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) |
(!inst[i][0]& inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) | ( inst[i][0]& inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) |
(!inst[i][0]& inst[i][1]&!inst[i][2]& inst[i][3]&!inst[i][4]& inst[i][5]) | ( inst[i][0]& inst[i][1]&!inst[i][2]& inst[i][3]&!inst[i][4]& inst[i][5]) |
( inst[i][0]& inst[i][1]&!inst[i][2]& inst[i][3]&!inst[i][4]&!inst[i][5]) | (!inst[i][0]& inst[i][1]&!inst[i][2]& inst[i][3]&!inst[i][4]&!inst[i][5]) |
(!inst[i][0]&!inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]&!inst[i][5]) | (!inst[i][0]& inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]&!inst[i][5]) |
( inst[i][0]& inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]&!inst[i][5]) | (!inst[i][0]&!inst[i][1]&!inst[i][2]&!inst[i][3]&!inst[i][4]&!inst[i][5]) |
(!inst[i][0]& inst[i][1]&!inst[i][2]&!inst[i][3]&!inst[i][4]&!inst[i][5]) | ( inst[i][0]& inst[i][1]&!inst[i][2]&!inst[i][3]&!inst[i][4]&!inst[i][5]) |
(!inst[i][0]&!inst[i][1]&!inst[i][2]& inst[i][3]&!inst[i][4]&!inst[i][5]) | ( inst[i][0]&!inst[i][1]&!inst[i][2]& inst[i][3]&!inst[i][4]&!inst[i][5]) |
(!inst[i][0]&!inst[i][1]& inst[i][2]& inst[i][3]&!inst[i][4]&!inst[i][5]) | ( inst[i][0]&!inst[i][1]& inst[i][2]& inst[i][3]&!inst[i][4]&!inst[i][5]) |
(!inst[i][0]&!inst[i][1]&!inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]) | ( inst[i][0]&!inst[i][1]&!inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]) |
(!inst[i][0]& inst[i][1]&!inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]) | ( inst[i][0]& inst[i][1]&!inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]) |
(!inst[i][0]&!inst[i][1]& inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]) | (!inst[i][0]& inst[i][1]& inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]))) |
 (!(temp0) & ((!inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) | ( inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) |
(!inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) | ( inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) |
(!inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) | ( inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) |
(!inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) | ( inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) |
(!inst[i][26]&!inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31]) | ( inst[i][26]&!inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31]) |
( inst[i][26]& inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31]) | (!inst[i][26]& inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31]) |
(!inst[i][26]& inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31]) | ( inst[i][26]& inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31]) |
( inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31])));
	assign	instMode[i][1]	=	((temp0) & ((!inst[i][0]&!inst[i][1]&!inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) | ( inst[i][0]&!inst[i][1]&!inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) |
(!inst[i][0]& inst[i][1]&!inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) | ( inst[i][0]& inst[i][1]&!inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) |
(!inst[i][0]&!inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) | ( inst[i][0]&!inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) |
(!inst[i][0]& inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) | ( inst[i][0]& inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]& inst[i][5]) |
(!inst[i][0]& inst[i][1]&!inst[i][2]& inst[i][3]&!inst[i][4]& inst[i][5]) | ( inst[i][0]& inst[i][1]&!inst[i][2]& inst[i][3]&!inst[i][4]& inst[i][5]) |
( inst[i][0]& inst[i][1]&!inst[i][2]& inst[i][3]&!inst[i][4]&!inst[i][5]) | (!inst[i][0]& inst[i][1]&!inst[i][2]& inst[i][3]&!inst[i][4]&!inst[i][5]) |
(!inst[i][0]&!inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]&!inst[i][5]) | (!inst[i][0]& inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]&!inst[i][5]) |
( inst[i][0]& inst[i][1]& inst[i][2]&!inst[i][3]&!inst[i][4]&!inst[i][5]) | (!inst[i][0]&!inst[i][1]&!inst[i][2]&!inst[i][3]&!inst[i][4]&!inst[i][5]) |
(!inst[i][0]& inst[i][1]&!inst[i][2]&!inst[i][3]&!inst[i][4]&!inst[i][5]) | ( inst[i][0]& inst[i][1]&!inst[i][2]&!inst[i][3]&!inst[i][4]&!inst[i][5]) |
(!inst[i][0]&!inst[i][1]&!inst[i][2]& inst[i][3]& inst[i][4]&!inst[i][5]) | ( inst[i][0]&!inst[i][1]&!inst[i][2]& inst[i][3]& inst[i][4]&!inst[i][5]) |
(!inst[i][0]& inst[i][1]&!inst[i][2]& inst[i][3]& inst[i][4]&!inst[i][5]) | ( inst[i][0]& inst[i][1]&!inst[i][2]& inst[i][3]& inst[i][4]&!inst[i][5]) |
(!inst[i][0]&!inst[i][1]&!inst[i][2]&!inst[i][3]& inst[i][4]&!inst[i][5]) | ( inst[i][0]&!inst[i][1]&!inst[i][2]&!inst[i][3]& inst[i][4]&!inst[i][5]) |
(!inst[i][0]& inst[i][1]&!inst[i][2]&!inst[i][3]& inst[i][4]&!inst[i][5]) | ( inst[i][0]& inst[i][1]&!inst[i][2]&!inst[i][3]& inst[i][4]&!inst[i][5]) |
(!inst[i][0]&!inst[i][1]& inst[i][2]& inst[i][3]&!inst[i][4]&!inst[i][5]) | ( inst[i][0]&!inst[i][1]& inst[i][2]& inst[i][3]&!inst[i][4]&!inst[i][5]) |
(!inst[i][0]&!inst[i][1]&!inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]) | ( inst[i][0]&!inst[i][1]&!inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]) |
(!inst[i][0]& inst[i][1]&!inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]) | ( inst[i][0]& inst[i][1]&!inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]) |
(!inst[i][0]&!inst[i][1]& inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]) | (!inst[i][0]& inst[i][1]& inst[i][2]&!inst[i][3]& inst[i][4]& inst[i][5]))) |
 (!(temp0) & (((temp2) & ((!inst[i][16]& inst[i][17]& inst[i][18]& inst[i][19]&!inst[i][20]) | (!inst[i][16]&!inst[i][17]&!inst[i][18]& inst[i][19]&!inst[i][20]) |
( inst[i][16]&!inst[i][17]&!inst[i][18]& inst[i][19]&!inst[i][20]) | (!inst[i][16]&!inst[i][17]& inst[i][18]& inst[i][19]&!inst[i][20]) |
( inst[i][16]& inst[i][17]&!inst[i][18]& inst[i][19]&!inst[i][20]) | (!inst[i][16]& inst[i][17]&!inst[i][18]& inst[i][19]&!inst[i][20]))) |
 (!(temp2) & ((!inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) | ( inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) |
(!inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) | ( inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) |
(!inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) | ( inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) |
(!inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) | ( inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) |
(!inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]& inst[i][30]&!inst[i][31]) | (!inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) |
(!inst[i][26]&!inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) | ( inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) |
( inst[i][26]&!inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) | ( inst[i][26]& inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) |
(!inst[i][26]& inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) | (!inst[i][26]& inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) |
(!inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) | ( inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) |
( inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) | (!inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) |
(!inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31]) | (!inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][30]& inst[i][31]) |
(!inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]& inst[i][30]& inst[i][31]) | (!inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][30]&!inst[i][31]) |
( inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]& inst[i][31])))));
	assign	writeToRt	=	(!inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) | ( inst[i][26]&!inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) |
(!inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) | ( inst[i][26]& inst[i][27]&!inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) |
(!inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) | ( inst[i][26]&!inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) |
(!inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) | ( inst[i][26]& inst[i][27]& inst[i][28]& inst[i][29]&!inst[i][30]&!inst[i][31]) |
(!inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) | (!inst[i][26]&!inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) |
( inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) | ( inst[i][26]&!inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) |
( inst[i][26]& inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) | (!inst[i][26]& inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) |
(!inst[i][26]& inst[i][27]& inst[i][28]&!inst[i][29]&!inst[i][30]& inst[i][31]) | (!inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][30]& inst[i][31]) |
(!inst[i][26]&!inst[i][27]&!inst[i][28]&!inst[i][29]& inst[i][30]&!inst[i][31]);
	assign	link	=	((temp2) & (( inst[i][16]) | (!inst[i][16]))) |
 (!(temp2) & (( inst[i][26]& inst[i][27]&!inst[i][28]&!inst[i][29]&!inst[i][30]&!inst[i][31])));
/*autoDecoder_End*/ /*}}}*/
		                end
    endgenerate
/*}}}*/
endmodule

