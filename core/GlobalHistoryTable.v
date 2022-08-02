// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/08/02 15:38
// Last Modified : 2022/08/02 16:31
// File Name     : GlobalHistoryTable.v
// Description   : 全局历史预测跳转, 包括GHT和IJTC
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/08/02   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "MyDefines.v"
module GlobalHistoryTable (
    input	wire	    clk,
    input	wire	    rst,
    // 总线接口{{{
    input	wire	    inst_index_ok,
    input	wire	    inst_req,
/*}}}*/
    // 查询接口{{{
    input	wire	[`SINGLE_WORD]      PCR_VAddr_i,     // 该地址是四值字对齐,需要预测该PC开始的四条指令
    input	wire	[`SINGLE_WORD]      BTB_fifthVAddr_i, // 该地址是四值字对齐,当第四条预测失败，返回该地址
    output	wire	[4*`IJTC_CHECKPOINT]  IJTC_checkPoint_p_o,
    output	wire	[4*`SINGLE_WORD]      IJTC_predDest_p_o,
/*}}}*/
    // 修改接口{{{
    // IJTC repair 在后段任何分支预测错误时，需要以下输入
    // 1. 检查点，当时的GHR
    // 2. 现在该指令的跳转目的
    // 3. 该指令的PC
    // IJTC direct 在任何前段分支预测之后，需要以下输入
    // 1. 预测的该指令是否跳转
    // 2. 该指令的PC
    input	wire	[`REPAIR_ACTION]    FU_repairAction_w_i,   // IJTC行为
    input	wire	[`ALL_CHECKPOINT]   FU_allCheckPoint_w_i,  // 三个分支预测单元共用一个
    input	wire	[`SINGLE_WORD]      FU_erroVAddr_w_i,
    input	wire	                    FU_correctTake_w_i,      // 跳转方向
    input	wire	[`SINGLE_WORD]      FU_correctDest_w_i       // 跳转目的
/*}}}*/
);
    localparam ITEM_NUM = 1024;
    localparam DATA_WID = 32;
    // 自动定义{{{
    /*autodef*/
    //Start of automatic define
    //Start of automatic reg
    //Define flip-flop registers here
    //Define combination registers here
    //End of automatic reg
    //Start of automatic wire
    //Define assign wires here
    //Define instance wires here
    wire                        wen;
    wire [ITEM_NUM-1:0]         rAddr;
    wire [DATA_WID-1:0]         wAddr;
    wire [`SINGLE_WORD]         wdata;
    wire [`SINGLE_WORD]         rdata;
    //End of automatic wire
    //End of automatic define
    // }}}
    // 信号定义和打包{{{
    reg [`IJTC_CHECKPOINT] checkPoint [3:0];
    `PACK_ARRAY(`IJTC_CHECKPOINT_LEN,4,checkPoint,IJTC_checkPoint_p_o)
    reg [`SINGLE_WORD] seq_dest[3:0];
    reg [`SINGLE_WORD] destination[3:0];
    `PACK_ARRAY(`SINGLE_WORD_LEN,4,destination,IJTC_predDest_p_o)
/*}}}*/
    // 具体查询逻辑{{{
    // 如果查询到的地方是valid = false,返回PC+8
    // 如果找到的数据是无效的，使用PC+8
    always @(posedge clk) begin
        if (!rst) begin
            seq_dest[0] <= `ZEROWORD;
            seq_dest[1] <= `ZEROWORD;
            seq_dest[2] <= `ZEROWORD;
            seq_dest[3] <= `ZEROWORD;
            checkPoint[0]  <= 'd0;
            checkPoint[1]  <= 'd0;
            checkPoint[2]  <= 'd0;
            checkPoint[3]  <= 'd0;
        end
        else if (inst_index_ok && inst_req) begin
            seq_dest[0] <= {PCR_VAddr_i[31:4],2'b10,PCR_VAddr_i[1:0]};
            seq_dest[1] <= {PCR_VAddr_i[31:4],2'b11,PCR_VAddr_i[1:0]};
            seq_dest[2] <= {BTB_fifthVAddr_i[31:4],2'b11,BTB_fifthVAddr_i[1:0]};
            seq_dest[3] <= {BTB_fifthVAddr_i[31:4],2'b01,BTB_fifthVAddr_i[1:0]};
            checkPoint[0]  <= 'd0;
            checkPoint[1]  <= 'd0;
            checkPoint[2]  <= 'd0;
            checkPoint[3]  <= 'd0;
        end
    end
/*}}}*/
    MyRAM  #(/*{{{*/
        .MY_NUMBER(ITEM_NUM),
        .MY_DATA_WIDTH(DATA_WID)
    )
    mem (
        /*autoinst*/
        .clk                    (clk                             ), //input
        .wen                    (wen                             ), //input
        .rAddr                  (rAddr                           ), //input
        .wAddr                  (wAddr                           ), //input
        .wdata                  (wdata                           ), //input
        .rdata                  (rdata                           )  //output
    );/*}}}*/
    reg [`SINGLE_WORD]  ghr;
endmodule

