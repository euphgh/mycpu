// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/06 08:52
// Last Modified : 2022/07/21 19:48
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
`include "MyDefines.v"
module ReturnAddressStack (
    input	wire	clk,
    input	wire	rst,
    // 总线接口{{{
    input	wire	    inst_index_ok,
    input	wire	    inst_req,
/*}}}*/
    // 查询接口{{{
    input	wire	[`SINGLE_WORD]      PCR_VAddr_i,
    input	wire	[`SINGLE_WORD]      BTB_fifthVAddr_i, // 该地址是四值字对齐,当第四条预测失败，返回该地址
    output	wire	[4*`SINGLE_WORD]    RAS_predDest_p_o,
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
    input	wire	[`REPAIR_ACTION]    BSC_repairAction_w_i,   // RAS行为
    input	wire	[`ALL_CHECKPOINT]   BSC_allCheckPoint_w_i,  // 三个分支预测单元共用一个
    input	wire	[`SINGLE_WORD]      BSC_erroVAdr_w_i        // PC
/*}}}*/
);
    // 信号定义和打包{{{
    reg [`RAS_CHECKPOINT] checkPoint [3:0];
    `PACK_ARRAY(`RAS_CHECKPOINT_LEN,4,checkPoint,RAS_checkPoint_p_o)
    reg [`SINGLE_WORD] destination [3:0];
    `PACK_ARRAY(`SINGLE_WORD_LEN,4,destination,RAS_predDest_p_o)
    /*}}}*/
    // 具体查询逻辑{{{
    // 如果查询到的地方是valid = false,返回PC+8
    // 如果找到的数据是无效的，使用PC+8
    always @(posedge clk) begin
        if (!rst) begin
            destination[0] <= `ZEROWORD;
            destination[1] <= `ZEROWORD;
            destination[2] <= `ZEROWORD;
            destination[3] <= `ZEROWORD;
            checkPoint[0]  <= 'd0;
            checkPoint[1]  <= 'd0;
            checkPoint[2]  <= 'd0;
            checkPoint[3]  <= 'd0;
        end
        else if (inst_index_ok && inst_req) begin
            destination[0] <= {PCR_VAddr_i[31:4],2'b01,PCR_VAddr_i[1:0]};
            destination[1] <= {PCR_VAddr_i[31:4],2'b10,PCR_VAddr_i[1:0]};
            destination[2] <= {PCR_VAddr_i[31:4],2'b11,PCR_VAddr_i[1:0]};
            destination[3] <= {BTB_fifthVAddr_i[31:4],2'b01,BTB_fifthVAddr_i[1:0]};
            checkPoint[0]  <= 'd0;
            checkPoint[1]  <= 'd0;
            checkPoint[2]  <= 'd0;
            checkPoint[3]  <= 'd0;
        end
    end
/*}}}*/
endmodule

