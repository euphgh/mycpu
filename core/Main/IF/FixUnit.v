// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/31 16:39
// Last Modified : 2022/07/31 16:49
// File Name     : FixUnit.v
// Description   : 收集后段分支恢复和前段分支恢复信息，修复分支预测模块
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/07/31   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "../../MyDefines.v"
module FixUnit(
    // 前段修复信息
    input   wire                        SBA_flush_w_i,          //表示分支错误，需要刷新流水线
    input   wire    [`SINGLE_WORD]      SBA_erroVAddr_w_i,      //分支错误PC
    input   wire    [`SINGLE_WORD]      SBA_corrDest_w_i,       //正确的分支目的
    input   wire                        SBA_corrTake_w_i,       //正确的分支方向
    input	wire	[`ALL_CHECKPOINT]   SBA_checkPoint_w_i,     // 检查点信息，用于恢复PHT和IJTC
    input	wire	[`REPAIR_ACTION]    SBA_repairAction_w_i,   // 修复行为
    // 后段修复信息
    input	wire	                    BSC_isDiffRes_w_i,        // BTB和BPU预测结果不同
    input	wire	[`REPAIR_ACTION]    BSC_repairAction_w_i,     // 
    input	wire	[`ALL_CHECKPOINT]   BSC_allCheckPoint_w_i,    // 三个分支预测单元共用一个
    input	wire	[`SINGLE_WORD]      BSC_erroVAdr_w_i,
    input	wire	                    BSC_correctTake_w_i,      // 跳转方向
    input	wire	[`SINGLE_WORD]      BSC_correctDest_w_i,      // 跳转目的

    output	wire	[`REPAIR_ACTION]    FU_repairAction_w_o,     // 
    output	wire	[`SINGLE_WORD]      FU_erroVAddr_w_o,
    output	wire	                    FU_correctTake_w_o,      // 跳转方向
    output	wire	[`SINGLE_WORD]      FU_correctDest_w_o       // 跳转目的
);
    assign FU_repairAction_w_o  = SBA_flush_w_i ? SBA_repairAction_w_i  : BSC_repairAction_w_i  ;
    assign FU_erroVAddr_w_o     = SBA_flush_w_i ? SBA_erroVAddr_w_i     : BSC_erroVAdr_w_i      ;
    assign FU_correctTake_w_o   = SBA_flush_w_i ? SBA_corrTake_w_i      : BSC_correctTake_w_i   ;  
    assign FU_correctDest_w_o   = SBA_flush_w_i ? SBA_corrDest_w_i      : BSC_correctDest_w_i   ;  
endmodule

