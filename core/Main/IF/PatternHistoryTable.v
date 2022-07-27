// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/06 08:40
// Last Modified : 2022/07/26 16:49
// File Name     : PatternHistoryTable.v
// Description   : 用于预测条件跳转指令的方向
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
module  PatternHistoryTable (
    input	wire	clk,
    input	wire	rst,
    // 总线接口{{{
    input	wire	                    inst_index_ok,
    input	wire	                    inst_req,
/*}}}*/
    // 查询接口{{{
    input	wire	[`SINGLE_WORD]      PCR_VAddr_i,
    output	wire	[3:0]               PHT_predTake_p_o,
    output	wire    [4*`PHT_CHECKPOINT] PHT_checkPoint_p_o,
/*}}}*/
    // 修改接口{{{
    // PHT repair 后段任何分支检查错误时，需要以下输入
    // 1. 检查点，当时的BHR和两位饱和计数器的数值
    // 2. 现在该指令是否跳转
    // 3. 该指令的PC
    // PHT direct 在前段分支预测之后，需要以下输入
    // 1. 预测出该指令是否跳转
    // 2. 该指令的PC
    input	wire	[`REPAIR_ACTION]    BSC_repairAction_w_i,   // PHT行为
    input	wire	[`ALL_CHECKPOINT]   BSC_allCheckPoint_w_i,  // 三个分支预测单元共用一个
    input	wire	[`SINGLE_WORD]      BSC_erroVAdr_w_i,
    input	wire	                    BSC_correctTake_w_i
/*}}}*/
);
    // 信号定义和打包{{{
    reg [`PHT_CHECKPOINT] checkPoint [3:0];
    `PACK_ARRAY(`PHT_CHECKPOINT_LEN,4,checkPoint,PHT_checkPoint_p_o)
    reg [0:0] predictedTake[3:0];
    `PACK_ARRAY(1,4,predictedTake,PHT_predTake_p_o)
/*}}}*/
    // 具体预测逻辑{{{
    generate
        for (genvar i = 0; i < 4; i = i+1)	begin
            always @(posedge clk) begin
                if (!rst) begin
                    predictedTake[i]<=  1'b0;
                    checkPoint[i]   <=  'd0;    
                end
                else if (inst_index_ok && inst_req) begin
                    predictedTake[i]<=  1'b0;
                    checkPoint[i]   <=  'd0;    
                end
            end
        end
    endgenerate
/*}}}*/
endmodule

