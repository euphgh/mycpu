// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/06/28 11:37
// Last Modified : 2022/07/25 14:12
// File Name     : PCRegister.v
// Description   :  1.  根据BTB预测、前后异常处理，生成下一条目标PC和目标PC使能
//                  2.  检查目标PC的指令对齐性，若不对齐，生成例外标识，停止生
//                      成下一条目标PC
//                  3.  和I-Cache交互，完成类sram总线的延时等待功能
//                  4.  将Vaddr的基地址送入MMU，使其在addr_ok的下一排送出
//                      PAddr的基地址和cache属性
// input         :  BTB预测、精细分支预测、前后分支确认、前后异常处理、I-Cache的
//                  addr_ok
// output        :  目标PC、目标使能、valid信号
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/06/28   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "MyDefines.v"

module PCRegister (
    input   wire        clk,
    input   wire        rst,
    //  总线接口{{{
    output  wire                    inst_req,
    output  wire                    inst_wr,                // constant value = 1'b0;
    output  wire    [1:0]           inst_size,              // constant value = 2'b11 表示一次传输4条指令，共16字节;'
    output  reg     [`CACHE_INDEX]  inst_index,             // 4字对齐，`CACHE_INDEX'hx0
    output  wire    [`SINGLE_WORD]  inst_wdata,             // constant value = 32'b0
    input   wire                    inst_index_ok,
/*}}}*/
    // 指令buffer反馈{{{
    input	wire	                ID_stopFetch_i,
/*}}}*/
    // BTB预测下一条PC来源{{{
    input	wire	[`SINGLE_WORD]  DSP_predictPC_i,
    input	wire	                DSP_needDelaySlot_i,
/*}}}*/
    // 分支预测恢复{{{
    input   wire                    SBA_flush_w_i,          // 检测到分支预测错误
    input   wire    [`SINGLE_WORD]  BSC_correctDest_w_i,    // 异常PC的跳转目的
/*}}}*/
    // 异常刷新{{{
    input   wire                    CP0_excOccur_w_i,         // WB检测到异常
    input   wire    [`SINGLE_WORD]  CP0_excDestPC_w_i,        // 延迟确认的PC，重新从此处跳转
/*}}}*/
    // 寄存器输出{{{
    // 异常处理{{{
    output	reg 	[`EXCCODE]      PCR_ExcCode_o,
    output	reg 	                PCR_hasException_o,  // 表明存在异常
/*}}}*/
    // 延迟槽处理{{{
    output	reg 	                PCR_needDelaySlot_o,
/*}}}*/
    // 取指信息{{{
    output  reg     [`SINGLE_WORD]  PCR_VAddr_o,     // to TLB
    output	wire	[`SINGLE_WORD]  PCR_lastVAddr_o,
    output  reg     [`INST_NUM]     PCR_instEnable_o // 表示此次读出的4条目标指令那些是需要的
    // }}}
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
    wire                        useBTBPC                        ;
    wire [`SINGLE_WORD]         nextNotAlignedPC                ;
    wire [1:0]                  wordBoundary                    ;
    wire [`SINGLE_WORD]         nextAlignedPC                   ;
    wire [3:0]                  temp_enable                     ;
    wire [3:2]                  position                        ;
    wire [3:0]                  temp_instEnable                 ;
    reg  [`SINGLE_WORD]         lastBase                        ;/*}}}*/
    // 没有异常的时候和没有分支预测错误的时候使用BTB预测结果
    assign useBTBPC = !(CP0_excOccur_w_i|SBA_flush_w_i);
    // 从三个PC来源中选出一个目标PC
    assign nextNotAlignedPC = (CP0_excDestPC_w_i & {32{CP0_excOccur_w_i}}) |
        (BSC_correctDest_w_i & {32{SBA_flush_w_i}}) |
        (DSP_predictPC_i & {32{useBTBPC}});
    // 将不是4字对齐的目标PC转换成4字对齐的PC
    assign wordBoundary = nextNotAlignedPC[1:0];
    assign nextAlignedPC = {nextNotAlignedPC[31:4],2'b00,wordBoundary};
    // 根据最低为生成指令使能
    assign temp_enable = {{3{!(useBTBPC&&DSP_needDelaySlot_i)}},1'b1};// 在没有异常和失败的条件下且是延迟槽
    assign position = nextNotAlignedPC[3:2];
    assign temp_instEnable =         ({4{position==2'b00}} & temp_enable) |
                                     ({4{position==2'b01}} & 4'b1110) |
                                     ({4{position==2'b10}} & 4'b1100) |
                                     ({4{position==2'b11}} & 4'b1000) ;

    // 总线交互
    always @(posedge clk) begin
        if (!rst) begin
            inst_index  <= `CACHE_INDEX_ZERO;
            PCR_instEnable_o <= 4'b1111;
            PCR_VAddr_o      <=  `STARTPOINT;
            lastBase                <=  `STARTPOINT - 32'h4;
            PCR_hasException_o   <= `FALSE;
            PCR_ExcCode_o        <= 0;
            PCR_needDelaySlot_o <= `FALSE;
        end
        // 只有在index_ok 和请求都有效的情况下才会刷新另一个请求
        else if (inst_req&&inst_index_ok || (!useBTBPC)) begin
            // 如果IQ满了，则始终将req拉低
            inst_index  <= nextAlignedPC[`CACHE_INDEX];
            lastBase         <= PCR_VAddr_o;
            PCR_instEnable_o <= temp_instEnable & {4{!(|wordBoundary)}}; //字边界检查，如果有异常则全部不要
            PCR_VAddr_o      <= nextAlignedPC;
            PCR_hasException_o  <= (|wordBoundary);
            PCR_ExcCode_o       <= `ADEL;
            PCR_needDelaySlot_o <= DSP_needDelaySlot_i;
        end
    end
    assign inst_wdata   = `ZEROWORD;
    assign inst_wr      = `SRAM_READ;
    assign inst_size    = 2'b11;
    assign inst_req = rst && !ID_stopFetch_i;
    assign PCR_lastVAddr_o = lastBase;
endmodule

