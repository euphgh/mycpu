// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/07 15:57
// Last Modified : 2022/07/31 00:45
// File Name     : IF.v
// Description   : 取值段，包括PC寄存器，分支预测以及TLB
//
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/07/07   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "MyDefines.v"
module IF (
    // cache总线交互{{{
    output  wire                            inst_req,
    output  wire                            inst_wr,
    output  wire    [1:0]                   inst_size,          // constant value = 2'b11 表示一次传输4条指令,共16字节;
    output  wire    [`CACHE_INDEX]          inst_index,         // 4字对齐,即最后4bit一定为0
    output  wire    [`CACHE_TAG]            inst_tag,      
    output  wire                            inst_hasException,
    output  wire                            inst_unCache,
    output  wire    [31:0]                  inst_wdata,         // 从不使用
    input   wire    [`FOUR_WORDS]           inst_rdata,
    input   wire                            inst_index_ok,      // 类似addr_ok,表示cache成功接受到CPU发送的index
    input   wire                            inst_data_ok,
/*}}}*/
    // InstQueue交互{{{
    input	wire	                    ID_stopFetch_i,
    output  wire    [4*`SINGLE_WORD]    IF_predDest_p_o,
    output  wire    [3:0]               IF_predTake_p_o,
    output  wire    [4*`ALL_CHECKPOINT] IF_predInfo_p_o,
    output  wire	[`SINGLE_WORD]      IF_instBasePC_o,
    output  wire	                    IF_valid_o,
    output  wire	[3:0]               IF_instEnable_o,
    output  wire    [`FOUR_WORDS]       IF_inst_p_o,
    output  wire    [2:0]               IF_instNum_o,
    output	wire                        IF_hasException_o,
    output	wire    [`EXCCODE]          IF_ExcCode_o,
    output	wire	                    IF_isRefill_o,
/*}}}*/
    // SBA(分支确认)交互{{{
    input   wire                        SBA_flush_w_i,          //表示分支错误，需要刷新流水线
    input   wire    [`SINGLE_WORD]      SBA_erroVAddr_w_i,      //分支错误PC
    input   wire    [`SINGLE_WORD]      SBA_corrDest_w_i,       //正确的分支目的
    input   wire                        SBA_corrTake_w_i,       //正确的分支方向
    input	wire	[`ALL_CHECKPOINT]   SBA_checkPoint_w_i,     // 检查点信息，用于恢复PHT和IJTC
    input	wire	[`REPAIR_ACTION]    SBA_repairAction_w_i,   // 修复行为
/*}}}*/
    // PEP(异常处理)交互{{{
    input   wire                        CP0_excOccur_w_i,         // WB检测到异常
    input   wire    [`SINGLE_WORD]      CP0_excDestPC_w_i,        // 延迟确认的PC，重新从此处跳转
    input   wire    [`SINGLE_WORD]      CP0_Config_w_i,
/*}}}*/
    // TLB交互{{{
    output  wire                    inst_tlbReq_o,
    output	wire	[`VPN2]         inst_vpn2_o,
    output	wire	                inst_oddPage_o,
    output	wire	[`ASID]         inst_asid_o,
    input	wire	                    inst_hit_i,
    input	wire	    [`TLB_WIDTH]    inst_index_i,
    input	wire	    [`CACHE_TAG]    inst_pfn_i,
    input	wire	[`CBITS]        inst_c_i,
    input	wire	                inst_d_i,
    input	wire	                inst_v_i,
/*}}}*/
    input wire clk,
    input wire rst
);
 
    /////////////////////////////////////////////////////////////////////
    ////////////////        autoConnect Code Start       ////////////////{{{
    /////////////////////////////////////////////////////////////////////

	wire	[7:0]	BSC_repairAction_w_o;	wire	[7:0]	BSC_repairAction_w_i;
	assign	BSC_repairAction_w_i	=	BSC_repairAction_w_o;
	wire	[61:0]	BSC_allCheckPoint_w_o;	wire	[61:0]	BSC_allCheckPoint_w_i;
	assign	BSC_allCheckPoint_w_i	=	BSC_allCheckPoint_w_o;
	wire	[31:0]	BSC_erroVAdr_w_o;	wire	[31:0]	BSC_erroVAdr_w_i;
	assign	BSC_erroVAdr_w_i	=	BSC_erroVAdr_w_o;
	wire	[0:0]	BSC_correctTake_w_o;	wire	[0:0]	BSC_correctTake_w_i;
	assign	BSC_correctTake_w_i	=	BSC_correctTake_w_o;
	wire	[31:0]	BSC_correctDest_w_o;	wire	[31:0]	BSC_correctDest_w_i;
	assign	BSC_correctDest_w_i	=	BSC_correctDest_w_o;
	wire	[0:0]	BSC_needCancel_w_o;	wire	[0:0]	BSC_needCancel_w_i;
	assign	BSC_needCancel_w_i	=	BSC_needCancel_w_o;
	wire	[0:0]	BSC_isDiffRes_w_o;	wire	[0:0]	BSC_isDiffRes_w_i;
	assign	BSC_isDiffRes_w_i	=	BSC_isDiffRes_w_o;
	wire	[31:0]	BSC_fifthVAddr_w_o;	wire	[31:0]	BSC_fifthVAddr_w_i;
	assign	BSC_fifthVAddr_w_i	=	BSC_fifthVAddr_w_o;
	wire	[31:0]	BSC_validDest_w_o;	wire	[31:0]	BSC_validDest_w_i;
	assign	BSC_validDest_w_i	=	BSC_validDest_w_o;
	wire	[0:0]	BSC_needDelaySlot_w_o;	wire	[0:0]	BSC_needDelaySlot_w_i;
	assign	BSC_needDelaySlot_w_i	=	BSC_needDelaySlot_w_o;
	wire	[0:0]	BSC_DelaySlotIsGetted_w_o;	wire	[0:0]	BSC_DelaySlotIsGetted_w_i;
	assign	BSC_DelaySlotIsGetted_w_i	=	BSC_DelaySlotIsGetted_w_o;
	wire	[3:0]	PHT_predTake_p_o;	wire	[3:0]	PHT_predTake_p_i;
	assign	PHT_predTake_p_i	=	PHT_predTake_p_o;
	wire	[39:0]	PHT_checkPoint_p_o;	wire	[39:0]	PHT_checkPoint_p_i;
	assign	PHT_checkPoint_p_i	=	PHT_checkPoint_p_o;
	wire	[0:0]	PCG_needDelaySlot_o;	wire	[0:0]	PCG_needDelaySlot_i;
	assign	PCG_needDelaySlot_i	=	PCG_needDelaySlot_o;
	wire	[127:0]	PCG_VAddr_p_o;	wire	[127:0]	PCG_VAddr_p_i;
	assign	PCG_VAddr_p_i	=	PCG_VAddr_p_o;
	wire	[4:0]	MMU_ExcCode_o;	wire	[4:0]	MMU_ExcCode_i;
	assign	MMU_ExcCode_i	=	MMU_ExcCode_o;
	wire	[0:0]	MMU_hasException_o;	wire	[0:0]	MMU_hasException_i;
	assign	MMU_hasException_i	=	MMU_hasException_o;
	wire	[0:0]	MMU_isRefill_o;	wire	[0:0]	MMU_isRefill_i;
	assign	MMU_isRefill_i	=	MMU_isRefill_o;
	wire	[31:0]	BTB_fifthVAddr_o;	wire	[31:0]	BTB_fifthVAddr_i;
	assign	BTB_fifthVAddr_i	=	BTB_fifthVAddr_o;
	wire	[127:0]	BTB_predDest_p_o;	wire	[127:0]	BTB_predDest_p_i;
	assign	BTB_predDest_p_i	=	BTB_predDest_p_o;
	wire	[3:0]	BTB_instEnable_o;	wire	[3:0]	BTB_instEnable_i;
	assign	BTB_instEnable_i	=	BTB_instEnable_o;
	wire	[31:0]	BTB_validDest_o;	wire	[31:0]	BTB_validDest_i;
	assign	BTB_validDest_i	=	BTB_validDest_o;
	wire	[0:0]	BTB_validTake_o;	wire	[0:0]	BTB_validTake_i;
	assign	BTB_validTake_i	=	BTB_validTake_o;
	wire	[0:0]	BTB_needDelaySlot_o;	wire	[0:0]	BTB_needDelaySlot_i;
	assign	BTB_needDelaySlot_i	=	BTB_needDelaySlot_o;
	wire	[0:0]	BTB_DelaySlotIsGetted_o;	wire	[0:0]	BTB_DelaySlotIsGetted_i;
	assign	BTB_DelaySlotIsGetted_i	=	BTB_DelaySlotIsGetted_o;
	wire	[4:0]	PCR_ExcCode_o;	wire	[4:0]	PCR_ExcCode_i;
	assign	PCR_ExcCode_i	=	PCR_ExcCode_o;
	wire	[0:0]	PCR_hasException_o;	wire	[0:0]	PCR_hasException_i;
	assign	PCR_hasException_i	=	PCR_hasException_o;
	wire	[0:0]	PCR_needDelaySlot_o;	wire	[0:0]	PCR_needDelaySlot_i;
	assign	PCR_needDelaySlot_i	=	PCR_needDelaySlot_o;
	wire	[31:0]	PCR_VAddr_o;	wire	[31:0]	PCR_VAddr_i;
	assign	PCR_VAddr_i	=	PCR_VAddr_o;
	wire	[31:0]	PCR_lastVAddr_o;	wire	[31:0]	PCR_lastVAddr_i;
	assign	PCR_lastVAddr_i	=	PCR_lastVAddr_o;
	wire	[3:0]	PCR_instEnable_o;	wire	[3:0]	PCR_instEnable_i;
	assign	PCR_instEnable_i	=	PCR_instEnable_o;
	wire	[31:0]	DSP_predictPC_o;	wire	[31:0]	DSP_predictPC_i;
	assign	DSP_predictPC_i	=	DSP_predictPC_o;
	wire	[0:0]	DSP_needDelaySlot_o;	wire	[0:0]	DSP_needDelaySlot_i;
	assign	DSP_needDelaySlot_i	=	DSP_needDelaySlot_o;
	wire	[127:0]	RAS_predDest_p_o;	wire	[127:0]	RAS_predDest_p_i;
	assign	RAS_predDest_p_i	=	RAS_predDest_p_o;
	wire	[175:0]	RAS_checkPoint_p_o;	wire	[175:0]	RAS_checkPoint_p_i;
	assign	RAS_checkPoint_p_i	=	RAS_checkPoint_p_o;
	wire	[0:0]	SCT_allowin_w_o;	wire	[0:0]	SCT_allowin_w_i;
	assign	SCT_allowin_w_i	=	SCT_allowin_w_o;
	wire	[0:0]	SCT_valid_o;	wire	[0:0]	SCT_valid_i;
	assign	SCT_valid_i	=	SCT_valid_o;
	wire	[127:0]	SCT_predDest_p_o;	wire	[127:0]	SCT_predDest_p_i;
	assign	SCT_predDest_p_i	=	SCT_predDest_p_o;
	wire	[3:0]	SCT_BTBInstEnable_o;	wire	[3:0]	SCT_BTBInstEnable_i;
	assign	SCT_BTBInstEnable_i	=	SCT_BTBInstEnable_o;
	wire	[31:0]	SCT_BTBfifthVAddr_o;	wire	[31:0]	SCT_BTBfifthVAddr_i;
	assign	SCT_BTBfifthVAddr_i	=	SCT_BTBfifthVAddr_o;
	wire	[0:0]	SCT_needDelaySlot_o;	wire	[0:0]	SCT_needDelaySlot_i;
	assign	SCT_needDelaySlot_i	=	SCT_needDelaySlot_o;
	wire	[31:0]	SCT_BTBValidDest_o;	wire	[31:0]	SCT_BTBValidDest_i;
	assign	SCT_BTBValidDest_i	=	SCT_BTBValidDest_o;
	wire	[0:0]	SCT_BTBValidTake_o;	wire	[0:0]	SCT_BTBValidTake_i;
	assign	SCT_BTBValidTake_i	=	SCT_BTBValidTake_o;
	wire	[3:0]	SCT_originEnable_o;	wire	[3:0]	SCT_originEnable_i;
	assign	SCT_originEnable_i	=	SCT_originEnable_o;
	wire	[31:0]	SCT_VAddr_o;	wire	[31:0]	SCT_VAddr_i;
	assign	SCT_VAddr_i	=	SCT_VAddr_o;
	wire	[0:0]	SCT_hasException_o;	wire	[0:0]	SCT_hasException_i;
	assign	SCT_hasException_i	=	SCT_hasException_o;
	wire	[4:0]	SCT_ExcCode_o;	wire	[4:0]	SCT_ExcCode_i;
	assign	SCT_ExcCode_i	=	SCT_ExcCode_o;
	wire	[0:0]	SCT_isRefill_o;	wire	[0:0]	SCT_isRefill_i;
	assign	SCT_isRefill_i	=	SCT_isRefill_o;
	wire	[31:0]	SCT_IJTC_checkPoint_p_o;	wire	[31:0]	SCT_IJTC_checkPoint_p_i;
	assign	SCT_IJTC_checkPoint_p_i	=	SCT_IJTC_checkPoint_p_o;
	wire	[127:0]	SCT_IJTC_predDest_p_o;	wire	[127:0]	SCT_IJTC_predDest_p_i;
	assign	SCT_IJTC_predDest_p_i	=	SCT_IJTC_predDest_p_o;
	wire	[127:0]	SCT_RAS_predDest_p_o;	wire	[127:0]	SCT_RAS_predDest_p_i;
	assign	SCT_RAS_predDest_p_i	=	SCT_RAS_predDest_p_o;
	wire	[175:0]	SCT_RAS_checkPoint_p_o;	wire	[175:0]	SCT_RAS_checkPoint_p_i;
	assign	SCT_RAS_checkPoint_p_i	=	SCT_RAS_checkPoint_p_o;
	wire	[3:0]	SCT_PHT_predTake_p_o;	wire	[3:0]	SCT_PHT_predTake_p_i;
	assign	SCT_PHT_predTake_p_i	=	SCT_PHT_predTake_p_o;
	wire	[39:0]	SCT_PHT_checkPoint_p_o;	wire	[39:0]	SCT_PHT_checkPoint_p_i;
	assign	SCT_PHT_checkPoint_p_i	=	SCT_PHT_checkPoint_p_o;
	wire	[31:0]	IJTC_checkPoint_p_o;	wire	[31:0]	IJTC_checkPoint_p_i;
	assign	IJTC_checkPoint_p_i	=	IJTC_checkPoint_p_o;
	wire	[127:0]	IJTC_predDest_p_o;	wire	[127:0]	IJTC_predDest_p_i;
	assign	IJTC_predDest_p_i	=	IJTC_predDest_p_o;
	wire	[0:0]	FCT_valid_o;	wire	[0:0]	FCT_valid_i;
	assign	FCT_valid_i	=	FCT_valid_o;
	wire	[127:0]	FCT_predDest_p_o;	wire	[127:0]	FCT_predDest_p_i;
	assign	FCT_predDest_p_i	=	FCT_predDest_p_o;
	wire	[3:0]	FCT_BTBInstEnable_o;	wire	[3:0]	FCT_BTBInstEnable_i;
	assign	FCT_BTBInstEnable_i	=	FCT_BTBInstEnable_o;
	wire	[31:0]	FCT_BTBfifthVAddr_o;	wire	[31:0]	FCT_BTBfifthVAddr_i;
	assign	FCT_BTBfifthVAddr_i	=	FCT_BTBfifthVAddr_o;
	wire	[0:0]	FCT_needDelaySlot_o;	wire	[0:0]	FCT_needDelaySlot_i;
	assign	FCT_needDelaySlot_i	=	FCT_needDelaySlot_o;
	wire	[31:0]	FCT_BTBValidDest_o;	wire	[31:0]	FCT_BTBValidDest_i;
	assign	FCT_BTBValidDest_i	=	FCT_BTBValidDest_o;
	wire	[0:0]	FCT_BTBValidTake_o;	wire	[0:0]	FCT_BTBValidTake_i;
	assign	FCT_BTBValidTake_i	=	FCT_BTBValidTake_o;
	wire	[3:0]	FCT_originEnable_o;	wire	[3:0]	FCT_originEnable_i;
	assign	FCT_originEnable_i	=	FCT_originEnable_o;
	wire	[31:0]	FCT_VAddr_o;	wire	[31:0]	FCT_VAddr_i;
	assign	FCT_VAddr_i	=	FCT_VAddr_o;
	wire	[0:0]	FCT_hasException_o;	wire	[0:0]	FCT_hasException_i;
	assign	FCT_hasException_i	=	FCT_hasException_o;
	wire	[4:0]	FCT_ExcCode_o;	wire	[4:0]	FCT_ExcCode_i;
	assign	FCT_ExcCode_i	=	FCT_ExcCode_o;
	wire	[0:0]	FCT_isCanceled_o;	wire	[0:0]	FCT_isCanceled_i;
	assign	FCT_isCanceled_i	=	FCT_isCanceled_o;

BranchSelectCheck  u_BranchSelectCheck (
    .SBA_flush_w_i                      ( SBA_flush_w_i                       ),
    .SBA_erroVAddr_w_i                  ( SBA_erroVAddr_w_i                   ),
    .SBA_corrDest_w_i                   ( SBA_corrDest_w_i                    ),
    .SBA_corrTake_w_i                   ( SBA_corrTake_w_i                    ),
    .SBA_checkPoint_w_i                 ( SBA_checkPoint_w_i                  ),
    .SBA_repairAction_w_i               ( SBA_repairAction_w_i                ),
    .inst_rdata                         ( inst_rdata                          ),
    .SCT_predDest_p_i                   ( SCT_predDest_p_i                    ),
    .SCT_BTBInstEnable_i                ( SCT_BTBInstEnable_i                 ),
    .SCT_BTBfifthVAddr_i                ( SCT_BTBfifthVAddr_i                 ),
    .SCT_needDelaySlot_i                ( SCT_needDelaySlot_i                 ),
    .SCT_BTBValidDest_i                 ( SCT_BTBValidDest_i                  ),
    .SCT_BTBValidTake_i                 ( SCT_BTBValidTake_i                  ),
    .SCT_originEnable_i                 ( SCT_originEnable_i                  ),
    .SCT_VAddr_i                        ( SCT_VAddr_i                         ),
    .SCT_hasException_i                 ( SCT_hasException_i                  ),
    .SCT_ExcCode_i                      ( SCT_ExcCode_i                       ),
    .SCT_isRefill_i                     ( SCT_isRefill_i                      ),
    .SCT_valid_i                        ( SCT_valid_i                         ),
    .SCT_PHT_predTake_p_i               ( SCT_PHT_predTake_p_i                ),
    .SCT_PHT_checkPoint_p_i             ( SCT_PHT_checkPoint_p_i              ),
    .SCT_RAS_predDest_p_i               ( SCT_RAS_predDest_p_i                ),
    .SCT_RAS_checkPoint_p_i             ( SCT_RAS_checkPoint_p_i              ),
    .SCT_IJTC_checkPoint_p_i            ( SCT_IJTC_checkPoint_p_i             ),
    .SCT_IJTC_predDest_p_i              ( SCT_IJTC_predDest_p_i               ),

    .BSC_repairAction_w_o               ( BSC_repairAction_w_o                ),
    .BSC_allCheckPoint_w_o              ( BSC_allCheckPoint_w_o               ),
    .BSC_erroVAdr_w_o                   ( BSC_erroVAdr_w_o                    ),
    .BSC_correctTake_w_o                ( BSC_correctTake_w_o                 ),
    .BSC_correctDest_w_o                ( BSC_correctDest_w_o                 ),
    .BSC_needCancel_w_o                 ( BSC_needCancel_w_o                  ),
    .BSC_isDiffRes_w_o                  ( BSC_isDiffRes_w_o                   ),
    .BSC_fifthVAddr_w_o                 ( BSC_fifthVAddr_w_o                  ),
    .BSC_validDest_w_o                  ( BSC_validDest_w_o                   ),
    .BSC_needDelaySlot_w_o              ( BSC_needDelaySlot_w_o               ),
    .BSC_DelaySlotIsGetted_w_o          ( BSC_DelaySlotIsGetted_w_o           ),
    .IF_predDest_p_o                    ( IF_predDest_p_o                     ),
    .IF_predTake_p_o                    ( IF_predTake_p_o                     ),
    .IF_predInfo_p_o                    ( IF_predInfo_p_o                     ),
    .IF_instBasePC_o                    ( IF_instBasePC_o                     ),
    .IF_valid_o                         ( IF_valid_o                          ),
    .IF_instEnable_o                    ( IF_instEnable_o                     ),
    .IF_inst_p_o                        ( IF_inst_p_o                         ),
    .IF_instNum_o                       ( IF_instNum_o                        ),
    .IF_hasException_o                  ( IF_hasException_o                   ),
    .IF_isRefill_o                      ( IF_isRefill_o                       ),
    .IF_ExcCode_o                       ( IF_ExcCode_o                        )
);

PatternHistoryTable  u_PatternHistoryTable (
    .clk                     ( clk                     ),
    .rst                     ( rst                     ),
    .inst_index_ok           ( inst_index_ok           ),
    .inst_req                ( inst_req                ),
    .PCR_VAddr_i             ( PCR_VAddr_i             ),
    .BSC_repairAction_w_i    ( BSC_repairAction_w_i    ),
    .BSC_allCheckPoint_w_i   ( BSC_allCheckPoint_w_i   ),
    .BSC_erroVAdr_w_i        ( BSC_erroVAdr_w_i        ),
    .BSC_correctTake_w_i     ( BSC_correctTake_w_i     ),

    .PHT_predTake_p_o        ( PHT_predTake_p_o        ),
    .PHT_checkPoint_p_o      ( PHT_checkPoint_p_o      )
);

PCGenerator  u_PCGenerator (
    .PCR_needDelaySlot_i     ( PCR_needDelaySlot_i   ),
    .PCR_VAddr_i             ( PCR_VAddr_i           ),
    .PCR_lastVAddr_i         ( PCR_lastVAddr_i       ),

    .PCG_needDelaySlot_o     ( PCG_needDelaySlot_o   ),
    .PCG_VAddr_p_o           ( PCG_VAddr_p_o         )
);

MemoryManagementUnit  u_MemoryManagementUnit (
    .clk                     ( clk                  ),
    .rst                     ( rst                  ),
    .PCR_VAddr_i             ( PCR_VAddr_i          ),
    .FCT_hasException_i      ( FCT_hasException_i   ),
    .CP0_Config_w_i          ( CP0_Config_w_i       ),
    .inst_hit_i              ( inst_hit_i           ),
    .inst_index_i            ( inst_index_i         ),
    .inst_pfn_i              ( inst_pfn_i           ),
    .inst_c_i                ( inst_c_i             ),
    .inst_d_i                ( inst_d_i             ),
    .inst_v_i                ( inst_v_i             ),
    .inst_req                ( inst_req             ),
    .inst_index_ok           ( inst_index_ok        ),

    .inst_tlbReq_o           ( inst_tlbReq_o        ),
    .inst_vpn2_o             ( inst_vpn2_o          ),
    .inst_oddPage_o          ( inst_oddPage_o       ),
    .inst_asid_o             ( inst_asid_o          ),
    .MMU_ExcCode_o           ( MMU_ExcCode_o        ),
    .MMU_hasException_o      ( MMU_hasException_o   ),
    .MMU_isRefill_o          ( MMU_isRefill_o       ),
    .inst_tag                ( inst_tag             ),
    .inst_hasException       ( inst_hasException    ),
    .inst_unCache            ( inst_unCache         )
);

BranchTargetBuffer  u_BranchTargetBuffer (
    .clk                      ( clk                       ),
    .rst                      ( rst                       ),
    .PCR_instEnable_i         ( PCR_instEnable_i          ),
    .PCG_VAddr_p_i            ( PCG_VAddr_p_i             ),
    .PCG_needDelaySlot_i      ( PCG_needDelaySlot_i       ),
    .BSC_repairAction_w_i     ( BSC_repairAction_w_i      ),
    .BSC_allCheckPoint_w_i    ( BSC_allCheckPoint_w_i     ),
    .BSC_erroVAdr_w_i         ( BSC_erroVAdr_w_i          ),
    .BSC_correctTake_w_i      ( BSC_correctTake_w_i       ),
    .BSC_correctDest_w_i      ( BSC_correctDest_w_i       ),

    .BTB_fifthVAddr_o         ( BTB_fifthVAddr_o          ),
    .BTB_predDest_p_o         ( BTB_predDest_p_o          ),
    .BTB_instEnable_o         ( BTB_instEnable_o          ),
    .BTB_validDest_o          ( BTB_validDest_o           ),
    .BTB_validTake_o          ( BTB_validTake_o           ),
    .BTB_needDelaySlot_o      ( BTB_needDelaySlot_o       ),
    .BTB_DelaySlotIsGetted_o  ( BTB_DelaySlotIsGetted_o   )
);

PCRegister  u_PCRegister (
    .clk                     ( clk                   ),
    .rst                     ( rst                   ),
    .inst_index_ok           ( inst_index_ok         ),
    .ID_stopFetch_i          ( ID_stopFetch_i        ),
    .DSP_predictPC_i         ( DSP_predictPC_i       ),
    .DSP_needDelaySlot_i     ( DSP_needDelaySlot_i   ),
    .SBA_flush_w_i           ( SBA_flush_w_i         ),
    .BSC_isDiffRes_w_i       ( BSC_isDiffRes_w_i     ),
    .BSC_correctDest_w_i     ( BSC_correctDest_w_i   ),
    .CP0_excOccur_w_i        ( CP0_excOccur_w_i      ),
    .CP0_excDestPC_w_i       ( CP0_excDestPC_w_i     ),

    .inst_req                ( inst_req              ),
    .inst_wr                 ( inst_wr               ),
    .inst_size               ( inst_size             ),
    .inst_index              ( inst_index            ),
    .inst_wdata              ( inst_wdata            ),
    .PCR_ExcCode_o           ( PCR_ExcCode_o         ),
    .PCR_hasException_o      ( PCR_hasException_o    ),
    .PCR_needDelaySlot_o     ( PCR_needDelaySlot_o   ),
    .PCR_VAddr_o             ( PCR_VAddr_o           ),
    .PCR_lastVAddr_o         ( PCR_lastVAddr_o       ),
    .PCR_instEnable_o        ( PCR_instEnable_o      )
);

DelaySlotProcessor  u_DelaySlotProcessor (
    .BTB_fifthVAddr_i           ( BTB_fifthVAddr_i            ),
    .BTB_validDest_i            ( BTB_validDest_i             ),
    .BTB_needDelaySlot_i        ( BTB_needDelaySlot_i         ),
    .BTB_DelaySlotIsGetted_i    ( BTB_DelaySlotIsGetted_i     ),
    .BSC_fifthVAddr_w_i         ( BSC_fifthVAddr_w_i          ),
    .BSC_validDest_w_i          ( BSC_validDest_w_i           ),
    .BSC_needDelaySlot_w_i      ( BSC_needDelaySlot_w_i       ),
    .BSC_DelaySlotIsGetted_w_i  ( BSC_DelaySlotIsGetted_w_i   ),
    .BSC_isDiffRes_w_i          ( BSC_isDiffRes_w_i           ),

    .DSP_predictPC_o            ( DSP_predictPC_o             ),
    .DSP_needDelaySlot_o        ( DSP_needDelaySlot_o         )
);

ReturnAddressStack  u_ReturnAddressStack (
    .clk                     ( clk                     ),
    .rst                     ( rst                     ),
    .inst_index_ok           ( inst_index_ok           ),
    .inst_req                ( inst_req                ),
    .PCR_VAddr_i             ( PCR_VAddr_i             ),
    .BTB_fifthVAddr_i        ( BTB_fifthVAddr_i        ),
    .BSC_repairAction_w_i    ( BSC_repairAction_w_i    ),
    .BSC_allCheckPoint_w_i   ( BSC_allCheckPoint_w_i   ),
    .BSC_erroVAdr_w_i        ( BSC_erroVAdr_w_i        ),

    .RAS_predDest_p_o        ( RAS_predDest_p_o        ),
    .RAS_checkPoint_p_o      ( RAS_checkPoint_p_o      )
);

SecondCacheTrace  u_SecondCacheTrace (
    .clk                      ( clk                       ),
    .rst                      ( rst                       ),
    .IJTC_checkPoint_p_i      ( IJTC_checkPoint_p_i       ),
    .IJTC_predDest_p_i        ( IJTC_predDest_p_i         ),
    .RAS_predDest_p_i         ( RAS_predDest_p_i          ),
    .RAS_checkPoint_p_i       ( RAS_checkPoint_p_i        ),
    .PHT_predTake_p_i         ( PHT_predTake_p_i          ),
    .PHT_checkPoint_p_i       ( PHT_checkPoint_p_i        ),
    .inst_data_ok             ( inst_data_ok              ),
    .BSC_needCancel_w_i       ( BSC_needCancel_w_i        ),
    .CP0_excOccur_w_i         ( CP0_excOccur_w_i          ),
    .MMU_ExcCode_i            ( MMU_ExcCode_i             ),
    .MMU_hasException_i       ( MMU_hasException_i        ),
    .MMU_isRefill_i           ( MMU_isRefill_i            ),
    .FCT_valid_i              ( FCT_valid_i               ),
    .FCT_VAddr_i              ( FCT_VAddr_i               ),
    .FCT_hasException_i       ( FCT_hasException_i        ),
    .FCT_ExcCode_i            ( FCT_ExcCode_i             ),
    .FCT_isCanceled_i         ( FCT_isCanceled_i          ),
    .FCT_predDest_p_i         ( FCT_predDest_p_i          ),
    .FCT_BTBInstEnable_i      ( FCT_BTBInstEnable_i       ),
    .FCT_BTBfifthVAddr_i      ( FCT_BTBfifthVAddr_i       ),
    .FCT_needDelaySlot_i      ( FCT_needDelaySlot_i       ),
    .FCT_originEnable_i       ( FCT_originEnable_i        ),
    .FCT_BTBValidDest_i       ( FCT_BTBValidDest_i        ),
    .FCT_BTBValidTake_i       ( FCT_BTBValidTake_i        ),

    .SCT_allowin_w_o          ( SCT_allowin_w_o           ),
    .SCT_valid_o              ( SCT_valid_o               ),
    .SCT_predDest_p_o         ( SCT_predDest_p_o          ),
    .SCT_BTBInstEnable_o      ( SCT_BTBInstEnable_o       ),
    .SCT_BTBfifthVAddr_o      ( SCT_BTBfifthVAddr_o       ),
    .SCT_needDelaySlot_o      ( SCT_needDelaySlot_o       ),
    .SCT_BTBValidDest_o       ( SCT_BTBValidDest_o        ),
    .SCT_BTBValidTake_o       ( SCT_BTBValidTake_o        ),
    .SCT_originEnable_o       ( SCT_originEnable_o        ),
    .SCT_VAddr_o              ( SCT_VAddr_o               ),
    .SCT_hasException_o       ( SCT_hasException_o        ),
    .SCT_ExcCode_o            ( SCT_ExcCode_o             ),
    .SCT_isRefill_o           ( SCT_isRefill_o            ),
    .SCT_IJTC_checkPoint_p_o  ( SCT_IJTC_checkPoint_p_o   ),
    .SCT_IJTC_predDest_p_o    ( SCT_IJTC_predDest_p_o     ),
    .SCT_RAS_predDest_p_o     ( SCT_RAS_predDest_p_o      ),
    .SCT_RAS_checkPoint_p_o   ( SCT_RAS_checkPoint_p_o    ),
    .SCT_PHT_predTake_p_o     ( SCT_PHT_predTake_p_o      ),
    .SCT_PHT_checkPoint_p_o   ( SCT_PHT_checkPoint_p_o    )
);

IndirectJumpTargetCache  u_IndirectJumpTargetCache (
    .clk                     ( clk                     ),
    .rst                     ( rst                     ),
    .inst_index_ok           ( inst_index_ok           ),
    .inst_req                ( inst_req                ),
    .PCR_VAddr_i             ( PCR_VAddr_i             ),
    .BTB_fifthVAddr_i        ( BTB_fifthVAddr_i        ),
    .BSC_repairAction_w_i    ( BSC_repairAction_w_i    ),
    .BSC_allCheckPoint_w_i   ( BSC_allCheckPoint_w_i   ),
    .BSC_erroVAdr_w_i        ( BSC_erroVAdr_w_i        ),
    .BSC_correctTake_w_i     ( BSC_correctTake_w_i     ),
    .BSC_correctDest_w_i     ( BSC_correctDest_w_i     ),

    .IJTC_checkPoint_p_o     ( IJTC_checkPoint_p_o     ),
    .IJTC_predDest_p_o       ( IJTC_predDest_p_o       )
);

FirstCacheTrace  u_FirstCacheTrace (
    .clk                     ( clk                   ),
    .rst                     ( rst                   ),
    .inst_req                ( inst_req              ),
    .inst_index_ok           ( inst_index_ok         ),
    .PCR_instEnable_i        ( PCR_instEnable_i      ),
    .PCR_VAddr_i             ( PCR_VAddr_i           ),
    .PCR_ExcCode_i           ( PCR_ExcCode_i         ),
    .PCR_hasException_i      ( PCR_hasException_i    ),
    .BSC_needCancel_w_i      ( BSC_needCancel_w_i    ),
    .CP0_excOccur_w_i        ( CP0_excOccur_w_i      ),
    .BTB_predDest_p_i        ( BTB_predDest_p_i      ),
    .BTB_fifthVAddr_i        ( BTB_fifthVAddr_i      ),
    .BTB_instEnable_i        ( BTB_instEnable_i      ),
    .BTB_validDest_i         ( BTB_validDest_i       ),
    .BTB_validTake_i         ( BTB_validTake_i       ),
    .PCG_needDelaySlot_i     ( PCG_needDelaySlot_i   ),
    .SCT_allowin_w_i         ( SCT_allowin_w_i       ),

    .FCT_valid_o             ( FCT_valid_o           ),
    .FCT_predDest_p_o        ( FCT_predDest_p_o      ),
    .FCT_BTBInstEnable_o     ( FCT_BTBInstEnable_o   ),
    .FCT_BTBfifthVAddr_o     ( FCT_BTBfifthVAddr_o   ),
    .FCT_needDelaySlot_o     ( FCT_needDelaySlot_o   ),
    .FCT_BTBValidDest_o      ( FCT_BTBValidDest_o    ),
    .FCT_BTBValidTake_o      ( FCT_BTBValidTake_o    ),
    .FCT_originEnable_o      ( FCT_originEnable_o    ),
    .FCT_VAddr_o             ( FCT_VAddr_o           ),
    .FCT_hasException_o      ( FCT_hasException_o    ),
    .FCT_ExcCode_o           ( FCT_ExcCode_o         ),
    .FCT_isCanceled_o        ( FCT_isCanceled_o      )
);

 
    /////////////////////////////////////////////////////////////////////
    ////////////////        autoConnect Code end         ////////////////}}}
    /////////////////////////////////////////////////////////////////////

endmodule
