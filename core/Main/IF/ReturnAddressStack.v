// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/06 08:52
// Last Modified : 2022/08/03 21:29
// File Name     : ReturnAddressStack.v
// Description   : 预测j.*r指令和jr $31指令的跳转返回关系
//                  1. 在preComfirm阶段修改preSatck,如果是call，就用PC(call+8)
//                  压栈，ret则在preStack弹栈，如果栈空，依然栈空
//                  2. 其他所有指令如果出现预测错误，需要将当前栈顶修改成该错误
//                  预测指令检查点信息的栈顶，同时将当前栈顶的元素改成检查点的
//                  元素修改preStack栈顶所指的元素的数值为realStack
//                  所指的元素的数值，并修改栈顶相同即可。
//                  3. 综上所示，有如下操作，
//                      (1):Pop
//                      (2):Push
//                      (5):Repair
//
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/07/06   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "../../MyDefines.v"
module ReturnAddressStack (
    input	wire	clk,
    input	wire	rst,
    // 查询接口{{{
    input	wire	[`SINGLE_WORD]      PCR_VAddr_i,
    output	wire	[4*`SINGLE_WORD]    RAS_predDest_p_o,
    output	wire	[3:0]               RAS_predTake_p_o,
    output	wire    [4*`RAS_CHECKPOINT] RAS_checkPoint_p_o,
/*}}}*/
    // 修改接口{{{
    // RAS repair 在后段分任何支检查错误时，需要以下输入
    // 1. 当时栈顶指针位置
    // 2. 当时该栈顶指针的数值
    // RAS Push 在前段分支预测为call之后，需要以下输入
    // 1、 该分支指令的PC+8
    // RAS Pop  在前段分支预测为ret 之后，需要以下输入
    // 无
    input	wire	[`REPAIR_ACTION]    FU_repairAction_w_i,   // RAS行为
    input	wire	[`ALL_CHECKPOINT]   FU_allCheckPoint_w_i,  // 三个分支预测单元共用一个
    input	wire	[`SINGLE_WORD]      FU_erroVAddr_w_i        // PC
/*}}}*/
);
    // 信号定义和打包{{{
    wire  [`RAS_CHECKPOINT] checkPoint [3:0];
    `PACK_ARRAY(`RAS_CHECKPOINT_LEN,4,checkPoint,RAS_checkPoint_p_o)
    wire [`SINGLE_WORD] destination [3:0];
    `PACK_ARRAY(`SINGLE_WORD_LEN,4,destination,RAS_predDest_p_o)
    /*}}}*/
    // 具体查询逻辑{{{
    // 如果查询到的地方是valid = false,返回PC+8
    // 如果找到的数据是无效的，使用PC+8
/*}}}*/
    localparam ITEM_NUM = 512;
    localparam DATA_WID = 32;
    localparam HIS_REG  = 4;
    wire    [$clog2(ITEM_NUM)-1:0]      rAddr;
    wire    [$clog2(ITEM_NUM)-1:0]      wAddr;
    wire                                wen;
    wire    [DATA_WID-1:0]              wdata;
    wire    [DATA_WID-1:0]              rdata;
    MyRAM  #(/*{{{*/
        .MY_NUMBER(ITEM_NUM),
        .MY_DATA_WIDTH(DATA_WID)
    )
    stack (
        /*autoinst*/
        .clk                    (clk                             ), //input
        .wen                    (wen                             ), //input
        .rAddr                  (rAddr                           ), //input
        .wAddr                  (wAddr                           ), //input
        .wdata                  (wdata                           ), //input
        .rdata                  (rdata                           )  //output
    );/*}}}*/
    wire    push    = FU_repairAction_w_i[`NEED_REPAIR] && FU_repairAction_w_i[`RAS_ACTION]==`RAS_PUSH;
    wire    pop     = FU_repairAction_w_i[`NEED_REPAIR] && FU_repairAction_w_i[`RAS_ACTION]==`RAS_POP;
    wire    repair  = FU_repairAction_w_i[`NEED_REPAIR] && FU_repairAction_w_i[`RAS_ACTION]==`RAS_REPAIRE;
    reg    [$clog2(ITEM_NUM)-1:0]      top;
    always @(posedge clk) begin
        if (!rst) begin
            top     <=  'd0;
        end
        else if (push) begin
            top     <=  top + 'd1;
        end
        else if (pop) begin
            top     <=  top - 'd1;
        end
        else if (repair) begin
            top     <=  FU_allCheckPoint_w_i[`RAS_CHECK_TOP];
        end
    end
    assign wen = push || repair;
    assign wAddr = push ? (top+'d1) : FU_allCheckPoint_w_i[`RAS_CHECK_TOP];
    assign wdata = push ? (FU_erroVAddr_w_i+'d8) : {FU_allCheckPoint_w_i[`RAS_CHECK_PC],2'b0};
    assign rAddr =  wen ? wAddr : 
                    pop ? (top - 'd1) : top;
    generate
        for (genvar i = 0; i < 4; i = i+1)	begin
            assign destination[i]       = rdata;
            assign checkPoint[i]        = {rdata[31:2],top};
            assign RAS_predTake_p_o[i]  = top!='d0;
        end
    endgenerate
endmodule

