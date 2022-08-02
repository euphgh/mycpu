// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/04 21:19
// Last Modified : 2022/08/02 11:54
// File Name     : BranchSelectCheck.v
// Description   : BSC的后半部分，从三种预测结果中，根据解码结果选择一种分支，
//                  同时修改BTB，该部分还接受后段分支确认的信号，分别写入BSC的
//                  前段和BTB
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
module BranchSelectCheck (
    // 总线接口{{{
    input   wire    [`FOUR_WORDS]           inst_rdata,
    /*}}}*/
    // 寄存器输入{{{
    //  BTB信息{{{
    input   wire 	[4*`SINGLE_WORD]        SCT_predDest_p_i,
    input   wire 	[3:0]                   SCT_predTake_p_i,
    input   wire    [`INST_NUM]             SCT_BTBInstEnable_i,    // 表示BTB读出的4条目标指令那些是需要
    input	wire	[`SINGLE_WORD]          SCT_BTBfifthVAddr_i,
    input	wire	                        SCT_needDelaySlot_i,
    input	wire    [`SINGLE_WORD]          SCT_BTBValidDest_i,
    input	wire	                        SCT_BTBValidTake_i,
/*}}}*/
    // PC和异常{{{
    input	wire    [`INST_NUM]             SCT_originEnable_i,     // PCR寄存器的使能
    input	wire    [`SINGLE_WORD]          SCT_VAddr_i,
    input	wire	                        SCT_hasException_i,
    input	wire    [`EXCCODE]              SCT_ExcCode_i,
    input	wire	                        SCT_isRefill_i,
/*}}}*/
    input	wire	                        SCT_valid_i,        // SecondCacheTrace送入信号
    // BPU预测结果{{{
    // PHT的预测结果
    input	wire	[3:0]                   SCT_PHT_predTake_p_i,
    input	wire    [4*`PHT_CHECKPOINT]     SCT_PHT_checkPoint_p_i,
    // RAS的预测结果
    input	wire	[4*`SINGLE_WORD]        SCT_RAS_predDest_p_i,
    input	wire    [4*`RAS_CHECKPOINT]     SCT_RAS_checkPoint_p_i,
    // IJTC的预测结果
    input	wire	[4*`IJTC_CHECKPOINT]    SCT_IJTC_checkPoint_p_i,
    input	wire	[4*`SINGLE_WORD]        SCT_IJTC_predDest_p_i,
/*}}}*/
/*}}}*/
    // 线信号输出{{{
    // BTB和BPU修复时所需要的信息{{{
    output	wire	[`REPAIR_ACTION]    BSC_repairAction_w_o,     // 
    output	wire	[`ALL_CHECKPOINT]   BSC_allCheckPoint_w_o,    // 三个分支预测单元共用一个
    output	wire	[`SINGLE_WORD]      BSC_erroVAdr_w_o,
    output	wire	                    BSC_correctTake_w_o,      // 跳转方向
    output	wire	[`SINGLE_WORD]      BSC_correctDest_w_o,      // 跳转目的
/*}}}*/
    // PC寄存器控制信号{{{
    output	wire	                    BSC_needCancel_w_o,       // 前段BTB预测失败
    output	wire	                    BSC_isDiffRes_w_o,        // BTB和BPU预测结果不同
    output	wire	[`SINGLE_WORD]      BSC_fifthVAddr_w_o,       // VAddr开始的第5条指令
    output	wire	[`SINGLE_WORD]      BSC_validDest_w_o,        // BPU预测的有效PC
    output	wire	                    BSC_needDelaySlot_w_o,    // BPU预测是否需要延迟槽
    output	wire	                    BSC_DelaySlotIsGetted_w_o,// SCT是否传入了needDelaySlot
/*}}}*/
    // 送入指令FIFO{{{
    // 分支确认信息
    output  wire    [4*`SINGLE_WORD]    IF_predDest_p_o,
    output  wire    [3:0]               IF_predTake_p_o,
    output  wire    [4*`ALL_CHECKPOINT] IF_predInfo_p_o,
    output	wire	[`SINGLE_WORD]      IF_instBasePC_o,

    output	wire	                    IF_valid_o,
    output	wire	[3:0]               IF_instEnable_o,
    output  wire    [`FOUR_WORDS]       IF_inst_p_o,
    output	wire    [2:0]               IF_instNum_o,
    // 送入指令FIFO的异常信息
    output	wire                        IF_hasException_o,
    output	wire	                    IF_isRefill_o,
    output	wire    [`EXCCODE]          IF_ExcCode_o
    /*}}}*/
/*}}}*/
);
    /*autodef*//*{{{*/
    //Start of automatic define
    //Start of automatic reg
    //Define flip-flop registers here
    //Define combination registers here
    //End of automatic reg
    //Start of automatic wire
    //Define assign wires here
    //Define instance wires here
    //End of automatic wire
    //End of automatic define
    wire                        isEnableSame                    ;
    wire [0:0]                  BPU_predTake_up [3:0]           ;
    wire [`SINGLE_WORD]         BPU_predDest_up [3:0]           ;
    wire [`ALL_CHECKPOINT]      BPU_checkPoint_up [3:0]         ;
    wire                        isPredictSame                   ;
    wire [`ALL_CHECKPOINT]      BPU_checkPoint                  ;
    wire [31:4]                 baseAddr                        ;
    wire [1:0]                  offset                          ;
    wire [1:0]                  position                        ;
    wire [`SINGLE_WORD]         BPU_erroVAddr                   ;
    //Define instance wires here
    wire [`INST_NUM]            actualEnable                    ;
    wire [`INST_NUM]            firstValidBit                   ;
    wire [4*`B_SELECT]          takeDestSel_p                   ;
    wire [`REPAIR_ACTION]     now_RepairAction                  ;
    wire [`SINGLE_WORD]         validDest_o                     ;
    wire                        validTake_o                     ;
    wire    [4*`SINGLE_WORD]   inst_p    ;
    //}}}  
    // 生成BPU预测结果{{{
    // 例化模块与信号打包{{{
    TakeDestDecorder u_TakeDestDecorder(
    /*autoinst*/
        .inst_rdata             (inst_p                         ), //input
        .SCT_valid_i            (SCT_valid_i                    ),
        .takeDestSel_p          (takeDestSel_p[4*`B_SELECT]     )  //output
    );
    wire [`B_SELECT] takeDestSel [3:0];
    `UNPACK_ARRAY(`B_SEL_LEN,4,takeDestSel,takeDestSel_p)
    wire [0:0] PHT_predTake [3:0];
    `UNPACK_ARRAY(1,4,PHT_predTake,SCT_PHT_predTake_p_i)
    wire [`SINGLE_WORD] BTB_predDest_up [3:0];
    wire [3:0]          BTB_predTake_up  = SCT_predTake_p_i;
    `UNPACK_ARRAY(`SINGLE_WORD_LEN,4,BTB_predDest_up,SCT_predDest_p_i)
    wire [`SINGLE_WORD] RAS_predDest [3:0];
    `UNPACK_ARRAY(`SINGLE_WORD_LEN,4,RAS_predDest,SCT_RAS_predDest_p_i)
    wire [`SINGLE_WORD] IJTC_predDest [3:0];
    `UNPACK_ARRAY(`SINGLE_WORD_LEN,4,IJTC_predDest,SCT_IJTC_predDest_p_i)
    // 检查点重新排列
    wire    [`ALL_CHECKPOINT]   allCheckPoint_up    [3:0]; // 重新排列后所有的检查点
    wire    [`PHT_CHECKPOINT]   PHT_checkPoint_up   [3:0];
    wire    [`RAS_CHECKPOINT]   RAS_checkPoint_up   [3:0];
    wire    [`IJTC_CHECKPOINT]  IJTC_checkPoint_up  [3:0];
    `UNPACK_ARRAY(`RAS_CHECKPOINT_LEN,4,RAS_checkPoint_up,SCT_RAS_checkPoint_p_i)
    `UNPACK_ARRAY(`PHT_CHECKPOINT_LEN,4,PHT_checkPoint_up,SCT_PHT_checkPoint_p_i)
    `UNPACK_ARRAY(`IJTC_CHECKPOINT_LEN,4,IJTC_checkPoint_up,SCT_IJTC_checkPoint_p_i)
    // }}}
    generate
    genvar k;
    for (k = 0; k < 4; k=k+1)	begin
        assign allCheckPoint_up[k] = {
            PHT_checkPoint_up[k],
            RAS_checkPoint_up[k],
            IJTC_checkPoint_up[k]};
    end
    endgenerate
    assign isEnableSame = actualEnable==SCT_BTBInstEnable_i;
    generate
    genvar i;
    for (i=0; i<4; i=i+1)	begin
        `ifdef BTB_ONLY
        assign BPU_predTake_up[i] = (takeDestSel[i][`PHT_TAKE] && BTB_predTake_up[i]) ||
                                    (takeDestSel[i][`MUST_TAKE]);
        assign BPU_predDest_up[i] = takeDestSel[i][`BTB_DEST] ? BTB_predDest_up[i]  : 
                                    takeDestSel[i][`RAS_DEST] ? BTB_predDest_up[i]  :
                                    takeDestSel[i][`IJTC_DEST]? BTB_predDest_up[i]  :   SCT_BTBfifthVAddr_i;
        `else
        assign BPU_predTake_up[i] = (takeDestSel[i][`PHT_TAKE] && PHT_predTake[i]) ||
                                    (takeDestSel[i][`MUST_TAKE]);
        assign BPU_predDest_up[i] = takeDestSel[i][`BTB_DEST] ? BTB_predDest_up[i]  : 
                                    takeDestSel[i][`RAS_DEST] ? RAS_predDest[i]     :
                                    takeDestSel[i][`IJTC_DEST]? IJTC_predDest[i]    :   SCT_BTBfifthVAddr_i;
        `endif
        assign BPU_checkPoint_up[i] = ({`ALL_CHECKPOINT_LEN{firstValidBit[i]}} & allCheckPoint_up[i]);
        end
    endgenerate
    // {{{
    wire [4*`SINGLE_WORD]   BPU_predDest_p;
    wire [3:0]              BPU_predTake_p;
    wire    needDelaySlot;
    `PACK_ARRAY(`SINGLE_WORD_LEN,4,BPU_predDest_up,BPU_predDest_p)
    `PACK_ARRAY(1,4,BPU_predTake_up,BPU_predTake_p)
    BranchFourToOne BranchFourToOne_u(
        /*autoinst*/
        .fifthPC_i              (SCT_BTBfifthVAddr_i              ), //input // INST_NEW
        .originEnable_i         (SCT_originEnable_i               ), //input // INST_NEW
        .predTake_p_i           (BPU_predTake_p                   ), //input // INST_NEW
        .predDest_p_i           (BPU_predDest_p                   ), //input // INST_NEW
        .validDest_o            (validDest_o                      ), //output // INST_NEW
        .validTake_o            (validTake_o                      ), //output // INST_NEW
        .actualEnable_o         (actualEnable                     ), //output // INST_NEW
        .needDelaySlot          (needDelaySlot                    ), //output // INST_NEW
        .firstValidBit          (firstValidBit                    )  //output
    );/*}}}*/
    assign isPredictSame =  (!(validTake_o || SCT_BTBValidTake_i))||
                            ((validTake_o && SCT_BTBValidTake_i)&& (validDest_o==SCT_BTBValidDest_i));
    assign BPU_checkPoint               = BPU_checkPoint_up[0] | BPU_checkPoint_up[1] | BPU_checkPoint_up[2] | BPU_checkPoint_up[3];
    assign BSC_needDelaySlot_w_o        = needDelaySlot                     &&                          SCT_valid_i;
    assign BSC_DelaySlotIsGetted_w_o    = SCT_needDelaySlot_i               &&                          SCT_valid_i;
    assign BSC_isDiffRes_w_o            = !(isEnableSame&&isPredictSame)    && !SCT_needDelaySlot_i &&  SCT_valid_i;
    assign BSC_needCancel_w_o           = BSC_isDiffRes_w_o &&                                          SCT_valid_i;
    assign BSC_validDest_w_o            = validDest_o;
    assign BSC_fifthVAddr_w_o           = SCT_BTBfifthVAddr_i;
    /*}}}*/
    //FIFO传入逻辑{{{
    assign IF_valid_o = SCT_valid_i && (|actualEnable);
    assign IF_hasException_o = SCT_hasException_i;
    assign IF_ExcCode_o = SCT_ExcCode_i;
    assign IF_isRefill_o = SCT_isRefill_i;
    // 将指令按照使能的顺序压缩，第一个有效指令放在第一位，第二个放在第二位
    // 选择信号生成
    wire    [4*`INST_NUM]   instSelect_p;
    wire    [`INST_NUM]     instSelect_up   [`INST_NUM];
    `UNPACK_ARRAY(`INST_NUM_LEN,`INST_NUM_LEN,instSelect_up,instSelect_p)
    Compressor u_Compressor(
        /*autoinst*/
        .actualEnable           (actualEnable[`INST_NUM]        ), //input
        .outputEnable           (IF_instEnable_o               ), //output
        .outputNumber           (IF_instNum_o                  ), //output
        .instSelect_p           (instSelect_p[4*`INST_NUM]      )  //output
    );
    // 指令
    wire    [`SINGLE_WORD]     inst_up   [3:0];
    assign  inst_p = inst_rdata & {4*`SINGLE_WORD_LEN{!SCT_hasException_i}};
    `UNPACK_ARRAY(`SINGLE_WORD_LEN,4,inst_up,inst_p)
    // 选择前的压缩
    wire    [`SINGLE_WORD_LEN + `ALL_CHECKPOINT_LEN + `SINGLE_WORD_LEN + 1 - 1 : 0 ]
            allInfo_up [3:0];
    generate
    genvar l;
    for (l = 0; l < 4; l=l+1)	begin
        assign allInfo_up[l] = {
            inst_up[l],
            allCheckPoint_up[l],
            BPU_predDest_up[l],
            BPU_predTake_up[l]
            };
    end
    endgenerate
    // 选择
    wire    [`SINGLE_WORD_LEN + `ALL_CHECKPOINT_LEN + `SINGLE_WORD_LEN + 1 - 1 : 0 ]
            compressedAll_up [3:0];
    wire    [1:0]   compressedPCSeq;
    generate
    genvar j;
    for (j=0;  j<4; j=j+1)	begin
        assign compressedAll_up[j] =instSelect_up[j][0] ? allInfo_up[0] :
                                    instSelect_up[j][1] ? allInfo_up[1] :
                                    instSelect_up[j][2] ? allInfo_up[2] :
                                    instSelect_up[j][3] ? allInfo_up[3] : 'b0;
    end
    endgenerate
    // 选择之后的解包
    wire    [`SINGLE_WORD]      compressedInst_up           [3:0];
    wire    [`ALL_CHECKPOINT]   compressedcheckPoint_up     [3:0];
    wire    [`SINGLE_WORD]      compressedDest_up           [3:0];
    wire    [0:0]               compressedTake_up           [3:0];
    generate
    genvar t;
    for (t = 0; t < 4; t=t+1)	begin
        assign {
            compressedInst_up[t],
            compressedcheckPoint_up[t],
            compressedDest_up[t],
            compressedTake_up[t]
                            } = compressedAll_up[t] ;
    end
    endgenerate
    `PACK_ARRAY(`SINGLE_WORD_LEN,4,compressedInst_up,IF_inst_p_o)
    `PACK_ARRAY(`ALL_CHECKPOINT_LEN,4,compressedcheckPoint_up,IF_predInfo_p_o)
    `PACK_ARRAY(`SINGLE_WORD_LEN,4,compressedDest_up,IF_predDest_p_o)
    `PACK_ARRAY(1,4,compressedTake_up,IF_predTake_p_o)
    assign compressedPCSeq =    instSelect_up[0][0] ? 2'b00 :
                                instSelect_up[0][1] ? 2'b01 :
                                instSelect_up[0][2] ? 2'b10 : 2'b11; 
    assign IF_instBasePC_o = {SCT_VAddr_i[31:4],compressedPCSeq,SCT_VAddr_i[1:0]};
/*}}}*/
    // 分支恢复逻辑{{{
    assign BSC_allCheckPoint_w_o = BPU_checkPoint;
    assign BSC_erroVAdr_w_o      = BPU_erroVAddr;
    assign BSC_correctDest_w_o   = validDest_o;
    assign BSC_repairAction_w_o  = now_RepairAction;
    assign baseAddr = SCT_VAddr_i[31:4];
    assign offset = SCT_VAddr_i[1:0];
    assign BSC_correctTake_w_o   = validTake_o;
    assign position =    ({2{firstValidBit[0]}} & 2'b00)|
                         ({2{firstValidBit[1]}} & 2'b01)|
                         ({2{firstValidBit[2]}} & 2'b10)|
                         ({2{firstValidBit[3]}} & 2'b11);
    assign BPU_erroVAddr = {baseAddr,position,offset};
    wire [`SINGLE_WORD] firstBranchInst;
    assign firstBranchInst =    ({32{firstValidBit[0]}} & inst_up[0])|
                                ({32{firstValidBit[1]}} & inst_up[1])|
                                ({32{firstValidBit[2]}} & inst_up[2])|
                                ({32{firstValidBit[3]}} & inst_up[3]);
    RepairDecorder RepairDecorder_u(
        /*autoinst*/
        .inst                   (firstBranchInst                      ), //input
        .isDiffRes              (BSC_isDiffRes_w_o                    ), //input
        .now_RepairAction       (now_RepairAction[`REPAIR_ACTION ]    )  //output // INST_NEW
    );
/*}}}*/
endmodule
