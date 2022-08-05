// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/09 10:18
// Last Modified : 2022/08/02 14:58
// File Name     : DelaySlotProcessor.v
// Description   : 根据BSC和BTB的分支预测结果选择合适的PC送入PC寄存器
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/07/09   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "../../MyDefines.v"
module DelaySlotProcessor (
    input	wire	[`SINGLE_WORD]      BTB_fifthVAddr_i,        // VAddr开始的第5条指令
    input	wire	[`SINGLE_WORD]      BTB_validDest_i,
    input	wire	                    BTB_needDelaySlot_i,
    input	wire	                    BTB_DelaySlotIsGetted_i,

    input	wire	[`SINGLE_WORD]      BSC_fifthVAddr_w_i,        // VAddr开始的第5条指令
    input	wire	[`SINGLE_WORD]      BSC_validDest_w_i,
    input	wire	                    BSC_needDelaySlot_w_i,
    input	wire	                    BSC_DelaySlotIsGetted_w_i,
    input	wire	                    BSC_isDiffRes_w_i,

    output	wire	[`SINGLE_WORD]      DSP_predictPC_o,
    output	wire	                    DSP_needDelaySlot_o
);
    assign DSP_predictPC_o = BSC_isDiffRes_w_i ?
        ((!BSC_DelaySlotIsGetted_w_i    && BSC_needDelaySlot_w_i) ? BSC_fifthVAddr_w_i  : BSC_validDest_w_i ) :
        ((!BTB_DelaySlotIsGetted_i      && BTB_needDelaySlot_i  ) ? BTB_fifthVAddr_i    : BTB_validDest_i   ) ;
    assign DSP_needDelaySlot_o = BSC_isDiffRes_w_i ?  BSC_needDelaySlot_w_i : BTB_needDelaySlot_i;
endmodule
          
