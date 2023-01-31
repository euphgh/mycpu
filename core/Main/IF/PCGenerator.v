// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/06/30 08:27
// Last Modified : 2022/07/23 20:49
// File Name     : PCGenerator.v
// Description   : 将PC寄存器发送的PC计算出4个用于BTB的PC，同时考虑延迟槽
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/06/30   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "../../MyDefines.v"
module PCGenerator(
    input   wire                    PCR_needDelaySlot_i, // 表示第一条指令是延迟槽指令
    input   wire    [`SINGLE_WORD]  PCR_VAddr_i,     // 必然四字对齐
    input	wire	[`SINGLE_WORD]  PCR_lastVAddr_i,
    output	wire	                PCG_needDelaySlot_o,
    output  wire    [`FOUR_WORDS]   PCG_VAddr_p_o    // 给BTB的四条PC
);
   /*autodef*/
    //Start of automatic define
    //Start of automatic reg
    //Define flip-flop registers here
    //Define combination registers here
    //End of automatic reg
    //Start of automatic wire
    //Define assign wires here
    wire [`SINGLE_WORD]                       firstPC                         ;
    wire [`SINGLE_WORD]                       secondPC                        ;
    wire [`SINGLE_WORD]                       thirdPC                         ;
    wire [`SINGLE_WORD]                       fourthPC                        ;
    //Define instance wires here
    //End of automatic wire
    //End of automatic define

    assign firstPC  = PCR_needDelaySlot_i ? {PCR_lastVAddr_i[31:4],2'b00,PCR_lastVAddr_i[1:0]}
    : {PCR_VAddr_i[31:4],2'b00,PCR_VAddr_i[1:0]};
    assign secondPC = PCR_needDelaySlot_i ? {PCR_lastVAddr_i[31:4],2'b01,PCR_lastVAddr_i[1:0]}
    : {PCR_VAddr_i[31:4],2'b01,PCR_VAddr_i[1:0]};
    assign thirdPC  = PCR_needDelaySlot_i ? {PCR_lastVAddr_i[31:4],2'b10,PCR_lastVAddr_i[1:0]}
    : {PCR_VAddr_i[31:4],2'b10,PCR_VAddr_i[1:0]};
    assign fourthPC = PCR_needDelaySlot_i ? {PCR_lastVAddr_i[31:4],2'b11,PCR_lastVAddr_i[1:0]}
    : {PCR_VAddr_i[31:4],2'b11,PCR_VAddr_i[1:0]};
    assign PCG_VAddr_p_o = {fourthPC,thirdPC,secondPC,firstPC};
    assign  PCG_needDelaySlot_o = PCR_needDelaySlot_i;
endmodule

