// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/08/02 15:38
// Last Modified : 2022/08/03 21:34
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
    input	wire	[`SINGLE_WORD]          PCR_VAddr_i,     // 该地址是四值字对齐,需要预测该PC开始的四条指令
    input	wire	[`SINGLE_WORD]          BTB_fifthVAddr_i, // 该地址是四值字对齐,当第四条预测失败，返回该地址
    output	wire	[4*`GHT_CHECKPOINT]     GHT_checkPoint_p_o,
    output	wire	[4*`SINGLE_WORD]        GHT_predDest_p_o,
    output	wire	[3:0]                   GHT_predTake_p_o,
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
    localparam ITEM_NUM = 256;
    localparam HIS_REG  = 4;
    localparam DATA_WID = 32;
    `define MEM_ADDR      $clog2(ITEM_NUM)-1:0
    `define GHT_PC_INDEX  ($clog2(ITEM_NUM)/2)+4-1:4
    // 信号定义和打包{{{
    wire [`GHT_CHECKPOINT] checkPoint [3:0];
    `PACK_ARRAY(`GHT_CHECKPOINT_LEN,4,checkPoint,GHT_checkPoint_p_o)
    reg [`SINGLE_WORD] seq_dest[3:0];
    wire [`SINGLE_WORD] destination[3:0];
    `PACK_ARRAY(`SINGLE_WORD_LEN,4,destination,GHT_predDest_p_o)
/*}}}*/
    // 具体查询逻辑{{{
    // 如果查询到的地方是valid = false,返回PC+8
    // 如果找到的数据是无效的，使用PC+8
/*}}}*/
    // 变量定义{{{
    wire [`SINGLE_WORD]     vAddr   [3:0];
    wire [1:0]              number  [3:0];
    assign vAddr[0] = {PCR_VAddr_i[31:4],2'b00,PCR_VAddr_i[1:0]};
    assign vAddr[1] = {PCR_VAddr_i[31:4],2'b01,PCR_VAddr_i[1:0]};
    assign vAddr[2] = {PCR_VAddr_i[31:4],2'b10,PCR_VAddr_i[1:0]};
    assign vAddr[3] = {PCR_VAddr_i[31:4],2'b11,PCR_VAddr_i[1:0]};
    assign number[0] = 2'b00;
    assign number[1] = 2'b01;
    assign number[2] = 2'b10;
    assign number[3] = 2'b11;
    // }}}
    // GHT{{{
    reg [HIS_REG-1:0]  ghr;
    wire    add_ghr     =   FU_repairAction_w_i[`NEED_REPAIR] && 
                            ((FU_repairAction_w_i[`IJTC_ACTION]==`IJTC_DIRECT)||(FU_repairAction_w_i[`PHT_ACTION]==`PHT_DIRECT));
    wire    reset_ghr   =   FU_repairAction_w_i[`NEED_REPAIR] &&
                            ((FU_repairAction_w_i[`IJTC_ACTION]==`IJTC_REPAIRE) || (FU_repairAction_w_i[`PHT_ACTION]==`PHT_REPAIRE));
    always @(posedge clk) begin
        if (!rst) begin
            ghr <=  'd0;
        end
        else if (add_ghr) begin
            ghr <=  {ghr[HIS_REG-2:0],FU_correctTake_w_i};
        end
        else if (reset_ghr) begin
            ghr <=  FU_allCheckPoint_w_i[`GHT_CHECK_REG];
        end
    end
    generate
        for (genvar i = 0; i < 4; i = i+1)	begin
            wire    [`MEM_ADDR]     rAddr;
            wire    [`MEM_ADDR]     wAddr;
            wire                    wen;
            wire    [`SINGLE_WORD]  wdata;
            wire    [`SINGLE_WORD]  rdata;/*}}}*/
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
            // 读操作逻辑 {{{
            assign  rAddr   =   {ghr,vAddr[i][`GHT_PC_INDEX]};
            wire [1:0] counter = rdata[`GHT_COUNTER];
            assign GHT_predTake_p_o[i]  = counter[1];
            assign destination[i]       = {rdata[`GHT_DEST_PC],2'b0};
            assign checkPoint[i]        = {rdata[`GHT_DEST_PC],ghr,rdata[`GHT_COUNTER]};
            // }}}
            // 写操作逻辑{{{
            assign  wen     =   (vAddr[i][3:2]==number[i])  && reset_ghr;
            wire   maxStatu =   (FU_allCheckPoint_w_i[`GHT_CHECK_COUNT]==2'b11) && FU_correctTake_w_i;
            wire   [1:0] nextStatu  =   maxStatu ? 2'b11 : (FU_allCheckPoint_w_i[`GHT_CHECK_COUNT]+FU_correctTake_w_i);
            assign wdata    =   FU_repairAction_w_i[`PHT_ACTION]==`PHT_REPAIRE ? 
                                    {FU_allCheckPoint_w_i[`GHT_CHECK_DEST],nextStatu} : 
                                    {FU_correctDest_w_i[31:2],FU_allCheckPoint_w_i[`GHT_CHECK_COUNT]};
            assign wAddr    =   {ghr,FU_erroVAddr_w_i[`GHT_PC_INDEX]};
            // }}}
        end
    endgenerate
    
endmodule

