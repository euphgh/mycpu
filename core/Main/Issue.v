// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/06/30 20:47
// Last Modified : 2022/08/08 09:38
// File Name     : Issur.v
// Description   : 收集I-Cache的指令，发射指令
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/06/30   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "../MyDefines.v"
module Issue (
    input   wire	                                clk,
    input   wire	                                rst,

    /////////////////////////////////////////////////
    ///////////////     寄存器输入   ////////////////{{{
    /////////////////////////////////////////////////
    input   wire    [`FOUR_WORDS]                   IF_inst_p_i,
    input   wire    [4*`SINGLE_WORD]                IF_predDest_p_i,
    input   wire    [3:0]                           IF_predTake_p_i,
    input   wire    [4*`ALL_CHECKPOINT]             IF_predInfo_p_i,
    input   wire	[`SINGLE_WORD]                  IF_instBasePC_i,
    input   wire	                                IF_valid_i,
    input   wire	[3:0]                           IF_instEnable_i,
    input   wire    [2:0]                           IF_instNum_i,
    input	wire                                    IF_hasException_i,
    input	wire    [`EXCCODE]                      IF_ExcCode_i,
    input	wire	                                IF_isRefill_i,
    /*}}}*/

    //////////////////////////////////////////////////
    //////////////     线信号输入      ///////////////{{{
    //////////////////////////////////////////////////
    //刷新流水线
    input	wire	                            SBA_flush_w_i,      
    input	wire	                            CP0_excOccur_w_i,   
    // 流水线控制
    input	wire	                            ID_allowin_w_i,        // 逐级互锁信号
    /*}}}*/

    //////////////////////////////////////////////////
    //////////////     线信号输出      ///////////////{{{
    //////////////////////////////////////////////////
    // InstQueue反馈信号
    output  wire                                IS_stopFetch_o,
/*}}}*/

    /////////////////////////////////////////////////
    ///////////////     寄存器输出   ////////////////{{{
    /////////////////////////////////////////////////
    output	wire [`ISSUE_MODE]                 IS_issueMode_o,
    output	wire [2*`SINGLE_WORD]              IS_Inst_p_o,
    output	wire [2*`SINGLE_WORD]              IS_VAddr_p_o,
    output	wire [2*`SINGLE_WORD]              IS_predDest_p_o,
    output	wire [1:0]                         IS_hasException_p_o,
    output	wire [1:0]                         IS_predTake_p_o,
    output	wire [2*`EXCCODE]                  IS_ExcCode_p_o,
    output	wire [2*`ALL_CHECKPOINT]           IS_checkPoint_p_o,
    output	wire [4*`GPR_NUM]                  IS_regReadNum_p_o,
    output	wire [3:0]                         IS_needRead_p_o,
    output	wire [2*`GPR_NUM]                  IS_regWriteNum_p_o,
    output	wire [1:0]                         IS_isRefill_p_o
    /*}}}*/
);
    /*autodef*/   
    /*{{{*/
    //Start of automatic define
    //Start of automatic reg
    //Define flip-flop registers here
    //Define combination registers here
    //End of automatic reg
    //Start of automatic wire
    //Define assign wires here
    //Define instance wires here
    wire [`IQ_VALID]                   IQ_supplyValid           ;
    wire [2*`SINGLE_WORD]              IQ_VAddr_p               ;
    wire [2*`SINGLE_WORD]              IQ_inst_p                ;
    wire [1:0]                         IQ_hasException_p        ;
    wire [2*`EXCCODE]                  IQ_ExcCode_p             ;
    wire [2*`SINGLE_WORD]              IQ_predDest_p            ;
    wire [1:0]                         IQ_predTake_p            ;
    wire [2*`ALL_CHECKPOINT]           IQ_checkPoint_p          ;
    wire                               IQ_full                  ;
    wire                               IQ_empty                 ;
    wire [$clog2(`IQ_CAPABILITY):0]    IQ_number_w              ;
    wire [1:0]                         IQ_isRefill_p            ;
    //End of automatic wire
    //End of automatic define
    wire [1:0] IS_upDateMode_i;
/*}}}*/
    InstQueue InstQueue_u (/*{{{*/
        .clk                    (clk                                        ), //input
        .rst                    (rst                                        ), //input
        // 取指令控制
        .IS_upDateMode_i        (IS_upDateMode_i[1:0]                       ), //input
        // 分支确认信号
        .IF_predDest_p_i        (IF_predDest_p_i[4*`SINGLE_WORD]            ), //input
        .IF_predTake_p_i        (IF_predTake_p_i[3:0]                       ), //input
        .IF_predInfo_p_i        (IF_predInfo_p_i[4*`ALL_CHECKPOINT]         ), //input
        // 四条指令的基地址
        .IF_instBasePC_i        (IF_instBasePC_i[`SINGLE_WORD]              ), //input
        // 送入指令FIFO的指令    
        .IF_valid_i             (IF_valid_i                                 ), //input
        .IF_instEnable_i        (IF_instEnable_i[3:0]                       ), //input
        .IF_inst_p_i            (IF_inst_p_i[`FOUR_WORDS]                   ), //input
        .IF_instNum_i           (IF_instNum_i[2:0]                          ), //input
        // 送入指令FIFO的异常信息
        .IF_hasException_i      (IF_hasException_i                          ), //input
        .IF_ExcCode_i           (IF_ExcCode_i[`EXCCODE]                     ), //input
        // 取出指令
        .IQ_supplyValid         (IQ_supplyValid  [`IQ_VALID]                ), //output
        .IQ_VAddr_p             (IQ_VAddr_p  [2*`SINGLE_WORD]               ), //output
        .IQ_inst_p              (IQ_inst_p  [2*`SINGLE_WORD]                ), //output
        .IQ_hasException_p      (IQ_hasException_p  [1:0]                   ), //output
        .IQ_ExcCode_p           (IQ_ExcCode_p  [2*`EXCCODE]                 ), //output
        .IQ_predDest_p          (IQ_predDest_p  [2*`SINGLE_WORD]            ), //output
        .IQ_predTake_p          (IQ_predTake_p  [1:0]                       ), //output
        .IQ_checkPoint_p        (IQ_checkPoint_p  [2*`ALL_CHECKPOINT]       ), //output
        .IQ_full                (IQ_full                                    ), //output
        .IQ_empty               (IQ_empty                                   ), //output
        .IQ_number_w            (IQ_number_w  [$clog2(`IQ_CAPABILITY):0]    ), //output
        .IF_isRefill_i          (IF_isRefill_i                              ), //input
        .IQ_isRefill_p          (IQ_isRefill_p[1:0]                         ), //output
        .IS_stopFetch_o         (IS_stopFetch_o                             ),
        /*autoinst*/
        .SBA_flush_w_i          (SBA_flush_w_i                              ), //input
        .CP0_excOccur_w_i       (CP0_excOccur_w_i                           )  //input
    );
    /*}}}*/
    Arbitrator Arbitrator_u (/*{{{*/
        /*autoinst*/
        .IQ_supplyValid          (IQ_supplyValid  [`IQ_VALID]              ), //input
        .IQ_inst_p               (IQ_inst_p  [2*`SINGLE_WORD]              ), //input
        .IQ_VAddr_p              (IQ_VAddr_p  [2*`SINGLE_WORD]             ), //input // INST_NEW
        .IQ_hasException_p       (IQ_hasException_p  [1:0]                 ), //input // INST_NEW
        .IQ_ExcCode_p            (IQ_ExcCode_p  [2*`EXCCODE]               ), //input // INST_NEW
        .IQ_predDest_p           (IQ_predDest_p  [2*`SINGLE_WORD]          ), //input // INST_NEW
        .IQ_predTake_p           (IQ_predTake_p  [1:0]                     ), //input // INST_NEW
        .IQ_checkPoint_p         (IQ_checkPoint_p  [2*`ALL_CHECKPOINT]     ), //input // INST_NEW
        .IQ_isRefill_p           (IQ_isRefill_p[1:0]                       ), //input
        .AB_issueMode_w          (IS_issueMode_o                           ), //output
        .AB_Inst_p               (IS_Inst_p_o                              ), //output
        .AB_VAddr_p              (IS_VAddr_p_o                             ), //output // INST_NEW
        .AB_predDest_p           (IS_predDest_p_o                          ), //output // INST_NEW
        .AB_hasException_p       (IS_hasException_p_o                      ), //output // INST_NEW
        .AB_predTake_p           (IS_predTake_p_o                          ), //output // INST_NEW
        .AB_ExcCode_p            (IS_ExcCode_p_o                           ), //output // INST_NEW
        .AB_checkPoint_p         (IS_checkPoint_p_o                        ), //output // INST_NEW
        .AB_regReadNum_p_w       (IS_regReadNum_p_o                        ), //output
        .AB_needRead_p_w         (IS_needRead_p_o                          ), //output
        .AB_regWriteNum_p_w      (IS_regWriteNum_p_o                       ), //output
        .AB_isRefill_p           (IS_isRefill_p_o                          )  //output
    );
    /*}}}*/
    assign IS_upDateMode_i = ID_allowin_w_i ? IS_issueMode_o : `NO_ISSUE;
endmodule

