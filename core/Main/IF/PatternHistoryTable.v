// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/08/04 15:30
// Last Modified : 2022/08/08 11:16
// File Name     : PatternHistoryTable.v
// Description   : 两位饱和计数器表
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/08/04   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "../../MyDefines.v"
module PatternHistoryTable (
    input	wire	clk,
    input	wire	rst,
    // 查询接口{{{
    input	wire	[`SINGLE_WORD]          PCR_VAddr_i,
    output	wire	[4*`PHT_CHECKPOINT]     PHT_checkPoint_p_o,
    output	wire	[3:0]                   PHT_predTake_p_o,
    // }}}
    // 修改接口{{{
    input	wire	[`REPAIR_ACTION]        FU_repairAction_w_i,   // IJTC行为
    input	wire	[`ALL_CHECKPOINT]       FU_allCheckPoint_w_i,  // 三个分支预测单元共用一个
    input	wire	[`SINGLE_WORD]          FU_erroVAddr_w_i,
    input	wire	                        FU_correctTake_w_i
    /*}}}*/
);
    localparam ITEM_NUM =   256;
    localparam DATA_WID =   2;
    `define PHT_ADDR        $clog2(ITEM_NUM)-1:0
    `define PHT_OFFSET      7:4
    `define PHT_PC_INDEX_L  $clog2(ITEM_NUM)+4-1:4
    `define PHT_PC_INDEX_H  2*$clog2(ITEM_NUM)+4-1:4+$clog2(ITEM_NUM)
    wire [`SINGLE_WORD]     vAddr   [3:0];
    wire [1:0]              number  [3:0];
    wire [DATA_WID-1:0]     checkPoint[3:0];
    `PACK_ARRAY(DATA_WID,4,checkPoint,PHT_checkPoint_p_o)
    assign vAddr[0] = {PCR_VAddr_i[31:4],2'b00,PCR_VAddr_i[1:0]};
    assign vAddr[1] = {PCR_VAddr_i[31:4],2'b01,PCR_VAddr_i[1:0]};
    assign vAddr[2] = {PCR_VAddr_i[31:4],2'b10,PCR_VAddr_i[1:0]};
    assign vAddr[3] = {PCR_VAddr_i[31:4],2'b11,PCR_VAddr_i[1:0]};
    assign number[0] = 2'b00;
    assign number[1] = 2'b01;
    assign number[2] = 2'b10;
    assign number[3] = 2'b11;
    generate
        for (genvar i = 0; i < 4; i = i+1)	begin
            reg     [ITEM_NUM-1:0]  pht_valid;
            reg     [DATA_WID-1:0]  counters    [ITEM_NUM-1:0];
            reg     [DATA_WID-1:0]  rdata;
            wire    [`PHT_ADDR]     wAddr = FU_erroVAddr_w_i[`PHT_PC_INDEX_L] ^ FU_erroVAddr_w_i[`PHT_PC_INDEX_H];
            wire    [`PHT_ADDR]     rAddr = vAddr[i][`PHT_PC_INDEX_L] ^ vAddr[i][`PHT_PC_INDEX_H];
            wire    isMax   =   (FU_allCheckPoint_w_i[`PHT_CHECK_COUNT]==2'b11) && FU_correctTake_w_i;
            wire    isMin   =   (FU_allCheckPoint_w_i[`PHT_CHECK_COUNT]==2'b00) && !FU_correctTake_w_i;
            wire    [DATA_WID-1:0]  nowstatu    =   FU_allCheckPoint_w_i[`PHT_CHECK_COUNT];
            wire    [DATA_WID-1:0]  nextStatu   =   (isMin||isMax) ? nowstatu :
                                                    (FU_correctTake_w_i ? (nowstatu+1'b1) : (nowstatu-1'b1) );
            wire    wen =   (FU_repairAction_w_i[`PHT_ACTION]==`PHT_REPAIRE || FU_repairAction_w_i[`PHT_ACTION]==`PHT_DIRECT) && 
                            FU_repairAction_w_i[`NEED_REPAIR] &&
                            number[i]==FU_erroVAddr_w_i[3:2];
            integer k;
            always @(posedge clk) begin
                if (!rst) begin
                    pht_valid   <=  'd0;
                    // counters 重置为10
                    for (k = 0; k < ITEM_NUM; k=k+1) begin
                        counters[k]    =  2'b10; 
                    end
                end
                else if (wen) begin
                    pht_valid[wAddr]<=  `TRUE;
                    counters[wAddr] <=  nextStatu;
                end
            end
            always @(posedge clk) begin
                rdata   <=  counters[rAddr];
            end
            assign PHT_predTake_p_o[i]  = pht_valid[rAddr] && rdata[1];
            assign checkPoint[i]= rdata;
        end
    endgenerate
endmodule

