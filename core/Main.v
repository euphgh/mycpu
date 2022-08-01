// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/03 15:29
// Last Modified : 2022/07/27 11:10
// File Name     : Main.v
// Description   :封装成修改过后的类sram接口的CPU
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/07/03   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "MyDefines.v"
module Main(
    input	wire	clk,
    input	wire	rst,
    input	wire	[5:0]   ext_int,  
    /////////////////////////////////////////////////
    ///////////////     Cache接口   /////////////////{{{
    /////////////////////////////////////////////////
    //inst sram-like 
    output  wire                             inst_req,
    output  wire                             inst_wr,
    output  wire    [1:0]                    inst_size,          // constant value = 2'b11 表示一次传输4条指令,共16字节;
    output  wire    [`CACHE_INDEX]           inst_index,         // 4字对齐,即最后4bit一定为0
    output  wire    [`CACHE_TAG]             inst_tag,      
    output  wire                             inst_hasException,
    output  wire                             inst_unCache,
    // 信号说明:
    // inst_tag信号是经过TLB转化的物理地址的高位,用于cache进行比对,会在index_ok握手成功的周期立即发送
    // inst_unCache表示此次访存操作是否经过cache,和tag信号按照相同的时序发送
    // 如果不经过Cache,则为1,否则为0。
    // inst_hasException表示本次访存请求的TLB翻译是否出现了例外
    // 如果发生了例外,则为1,否则为0
    // 若该周期hasException为1,则对Cache提出以下要求：
    // 1. 不能使得自身的状态发生任何改变。包括所有Cache块的内容,标志位
    // 都不能发生改变
    // 2. 对本次访存请求的data_ok需要在下一个上升沿到来之后拉高,代表本
    // 次访存事务的结束
    // 3. rdata需要返回0
    // 如下图:
    // 在2处,index_ok握手成功,但是在2号周期中,tagValid为0。
    // 按照规约,要求Cache如图所示,在第三周期将data_ok拉高来结束本次访存事务
    // 
//  .   .   1       2       3       4       5       6       7       8       9      10
//          +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +
// clk      |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |
//          +   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+
//            +------------+                                                         
// sig        |            |                                                         
// req      --+            +---------------------------------------------------------
//                +--------+                                                         
// sig            |        |                                                         
// index_ok ------+        +---------------------------------------------------------
//                                                                                   
// sig                                                                               
// tagValid -------------------------------------------------------------------------
//                            +-------+        
// sig                        |       |                                                                                                      
// data_ok  ------------------+       +----------------------------------------------
    input   wire    [`FOUR_WORDS]            inst_rdata,
    output	wire	[`SINGLE_WORD]           inst_wdata,
    input   wire                             inst_index_ok,      // 类似addr_ok,表示cache成功接受到CPU发送的index
    input   wire                             inst_data_ok,
    //data sram-like 
    output wire                              data_req,
    output wire                              data_wr,
    output wire     [1:0]                    data_size,          // 同A12文档,没有变化
    output wire     [11:0]                   data_index,         // 同A12文档,存在4字不对齐的情况
    output wire     [`CACHE_TAG]             data_tag,           // 同上
    output wire                              data_unCache,       // 同上
    output wire                              data_hasException,  // 同上
    output wire     [3:0]                    data_wstrb,         // 同CPU设计实战表8-3
    output wire     [31:0]                   data_wdata,
    input  wire     [31:0]                   data_rdata,
    input  wire                              data_index_ok,      // 同上
    input  wire                              data_data_ok,
/*}}}*/
    /////////////////////////////////////////////////
    ///////////////     Debug信号   /////////////////{{{
    /////////////////////////////////////////////////
    // 写回级（多周期最后一级）的 PC,因而需要 mycpu 里将 PC 一路带到写回级
    output	wire	[`SINGLE_WORD]  debug_wb_pc0,
    output	wire	[`SINGLE_WORD]  debug_wb_pc1,
    // 写回级写寄存器堆(regfiles)的写使能,为字节写使能,如果 mycpu 写 regfiles
    // 为单字节写使能,则将写使能扩展成 4 位即可。
    output	wire	[3:0]           debug_wb_rf_wen0,
    output	wire	[3:0]           debug_wb_rf_wen1,
    // 写回级写 regfiles 的目的寄存器号
    output	wire	[`GPR_NUM]      debug_wb_rf_wnum0,
    output	wire	[`GPR_NUM]      debug_wb_rf_wnum1,
    // 写回级写 regfiles 的写数据 
    output	wire	[`SINGLE_WORD]  debug_wb_rf_wdata0,
    output	wire	[`SINGLE_WORD]  debug_wb_rf_wdata1
/*}}}*/
);
 
    /////////////////////////////////////////////////////////////////////
    ////////////////        autoConnect Code Start       ////////////////{{{
    /////////////////////////////////////////////////////////////////////

	wire	[0:0]	ID_stopFetch_o;	wire	[0:0]	ID_stopFetch_i;
	assign	ID_stopFetch_i	=	ID_stopFetch_o;
	wire	[0:0]	ID_down_valid_w_o;	wire	[0:0]	ID_down_valid_w_i;
	assign	ID_down_valid_w_i	=	ID_down_valid_w_o;
	wire	[0:0]	ID_up_valid_w_o;	wire	[0:0]	ID_up_valid_w_i;
	assign	ID_up_valid_w_i	=	ID_up_valid_w_o;
	wire	[1:0]	ID_upDateMode_o;	wire	[1:0]	ID_upDateMode_i;
	assign	ID_upDateMode_i	=	ID_upDateMode_o;
	wire	[4:0]	ID_up_writeNum_o;	wire	[4:0]	ID_up_writeNum_i;
	assign	ID_up_writeNum_i	=	ID_up_writeNum_o;
	wire	[63:0]	ID_up_readData_o;	wire	[63:0]	ID_up_readData_i;
	assign	ID_up_readData_i	=	ID_up_readData_o;
	wire	[31:0]	ID_up_VAddr_o;	wire	[31:0]	ID_up_VAddr_i;
	assign	ID_up_VAddr_i	=	ID_up_VAddr_o;
	wire	[31:0]	ID_up_oprand0_o;	wire	[31:0]	ID_up_oprand0_i;
	assign	ID_up_oprand0_i	=	ID_up_oprand0_o;
	wire	[0:0]	ID_up_oprand0IsReg_o;	wire	[0:0]	ID_up_oprand0IsReg_i;
	assign	ID_up_oprand0IsReg_i	=	ID_up_oprand0IsReg_o;
	wire	[0:0]	ID_up_oprand1IsReg_o;	wire	[0:0]	ID_up_oprand1IsReg_i;
	assign	ID_up_oprand1IsReg_i	=	ID_up_oprand1IsReg_o;
	wire	[6:0]	ID_up_forwardSel0_o;	wire	[6:0]	ID_up_forwardSel0_i;
	assign	ID_up_forwardSel0_i	=	ID_up_forwardSel0_o;
	wire	[0:0]	ID_up_data0Ready_o;	wire	[0:0]	ID_up_data0Ready_i;
	assign	ID_up_data0Ready_i	=	ID_up_data0Ready_o;
	wire	[31:0]	ID_up_oprand1_o;	wire	[31:0]	ID_up_oprand1_i;
	assign	ID_up_oprand1_i	=	ID_up_oprand1_o;
	wire	[6:0]	ID_up_forwardSel1_o;	wire	[6:0]	ID_up_forwardSel1_i;
	assign	ID_up_forwardSel1_i	=	ID_up_forwardSel1_o;
	wire	[0:0]	ID_up_data1Ready_o;	wire	[0:0]	ID_up_data1Ready_i;
	assign	ID_up_data1Ready_i	=	ID_up_data1Ready_o;
	wire	[13:0]	ID_up_aluOprator_o;	wire	[13:0]	ID_up_aluOprator_i;
	assign	ID_up_aluOprator_i	=	ID_up_aluOprator_o;
	wire	[0:0]	ID_up_branchRisk_o;	wire	[0:0]	ID_up_branchRisk_i;
	assign	ID_up_branchRisk_i	=	ID_up_branchRisk_o;
	wire	[7:0]	ID_up_repairAction_o;	wire	[7:0]	ID_up_repairAction_i;
	assign	ID_up_repairAction_i	=	ID_up_repairAction_o;
	wire	[31:0]	ID_up_predDest_o;	wire	[31:0]	ID_up_predDest_i;
	assign	ID_up_predDest_i	=	ID_up_predDest_o;
	wire	[0:0]	ID_up_predTake_o;	wire	[0:0]	ID_up_predTake_i;
	assign	ID_up_predTake_i	=	ID_up_predTake_o;
	wire	[60:0]	ID_up_checkPoint_o;	wire	[60:0]	ID_up_checkPoint_i;
	assign	ID_up_checkPoint_i	=	ID_up_checkPoint_o;
	wire	[5:0]	ID_up_branchKind_o;	wire	[5:0]	ID_up_branchKind_i;
	assign	ID_up_branchKind_i	=	ID_up_branchKind_o;
	wire	[4:0]	ID_down_writeNum_o;	wire	[4:0]	ID_down_writeNum_i;
	assign	ID_down_writeNum_i	=	ID_down_writeNum_o;
	wire	[63:0]	ID_down_readData_o;	wire	[63:0]	ID_down_readData_i;
	assign	ID_down_readData_i	=	ID_down_readData_o;
	wire	[0:0]	ID_down_isDelaySlot_o;	wire	[0:0]	ID_down_isDelaySlot_i;
	assign	ID_down_isDelaySlot_i	=	ID_down_isDelaySlot_o;
	wire	[0:0]	ID_down_isDangerous_o;	wire	[0:0]	ID_down_isDangerous_i;
	assign	ID_down_isDangerous_i	=	ID_down_isDangerous_o;
	wire	[31:0]	ID_down_VAddr_o;	wire	[31:0]	ID_down_VAddr_i;
	assign	ID_down_VAddr_i	=	ID_down_VAddr_o;
	wire	[31:0]	ID_down_oprand0_o;	wire	[31:0]	ID_down_oprand0_i;
	assign	ID_down_oprand0_i	=	ID_down_oprand0_o;
	wire	[0:0]	ID_down_oprand0IsReg_o;	wire	[0:0]	ID_down_oprand0IsReg_i;
	assign	ID_down_oprand0IsReg_i	=	ID_down_oprand0IsReg_o;
	wire	[0:0]	ID_down_oprand1IsReg_o;	wire	[0:0]	ID_down_oprand1IsReg_i;
	assign	ID_down_oprand1IsReg_i	=	ID_down_oprand1IsReg_o;
	wire	[6:0]	ID_down_forwardSel0_o;	wire	[6:0]	ID_down_forwardSel0_i;
	assign	ID_down_forwardSel0_i	=	ID_down_forwardSel0_o;
	wire	[0:0]	ID_down_data0Ready_o;	wire	[0:0]	ID_down_data0Ready_i;
	assign	ID_down_data0Ready_i	=	ID_down_data0Ready_o;
	wire	[31:0]	ID_down_oprand1_o;	wire	[31:0]	ID_down_oprand1_i;
	assign	ID_down_oprand1_i	=	ID_down_oprand1_o;
	wire	[6:0]	ID_down_forwardSel1_o;	wire	[6:0]	ID_down_forwardSel1_i;
	assign	ID_down_forwardSel1_i	=	ID_down_forwardSel1_o;
	wire	[0:0]	ID_down_data1Ready_o;	wire	[0:0]	ID_down_data1Ready_i;
	assign	ID_down_data1Ready_i	=	ID_down_data1Ready_o;
	wire	[13:0]	ID_down_aluOprator_o;	wire	[13:0]	ID_down_aluOprator_i;
	assign	ID_down_aluOprator_i	=	ID_down_aluOprator_o;
	wire	[8:0]	ID_down_mduOperator_o;	wire	[8:0]	ID_down_mduOperator_i;
	assign	ID_down_mduOperator_i	=	ID_down_mduOperator_o;
	wire	[1:0]	ID_down_readHiLo_o;	wire	[1:0]	ID_down_readHiLo_i;
	assign	ID_down_readHiLo_i	=	ID_down_readHiLo_o;
	wire	[1:0]	ID_down_writeHiLo_o;	wire	[1:0]	ID_down_writeHiLo_i;
	assign	ID_down_writeHiLo_i	=	ID_down_writeHiLo_o;
	wire	[4:0]	ID_down_ExcCode_o;	wire	[4:0]	ID_down_ExcCode_i;
	assign	ID_down_ExcCode_i	=	ID_down_ExcCode_o;
	wire	[1:0]	ID_down_exceptionSel_o;	wire	[1:0]	ID_down_exceptionSel_i;
	assign	ID_down_exceptionSel_i	=	ID_down_exceptionSel_o;
	wire	[0:0]	ID_down_hasException_o;	wire	[0:0]	ID_down_hasException_i;
	assign	ID_down_hasException_i	=	ID_down_hasException_o;
	wire	[0:0]	ID_down_exceptionRisk_o;	wire	[0:0]	ID_down_exceptionRisk_i;
	assign	ID_down_exceptionRisk_i	=	ID_down_exceptionRisk_o;
	wire	[7:0]	ID_down_positionCp0_o;	wire	[7:0]	ID_down_positionCp0_i;
	assign	ID_down_positionCp0_i	=	ID_down_positionCp0_o;
	wire	[0:0]	ID_down_readCp0_o;	wire	[0:0]	ID_down_readCp0_i;
	assign	ID_down_readCp0_i	=	ID_down_readCp0_o;
	wire	[0:0]	ID_down_eret_o;	wire	[0:0]	ID_down_eret_i;
	assign	ID_down_eret_i	=	ID_down_eret_o;
	wire	[0:0]	ID_down_isRefill_o;	wire	[0:0]	ID_down_isRefill_i;
	assign	ID_down_isRefill_i	=	ID_down_isRefill_o;
	wire	[0:0]	ID_down_writeCp0_o;	wire	[0:0]	ID_down_writeCp0_i;
	assign	ID_down_writeCp0_i	=	ID_down_writeCp0_o;
	wire	[3:0]	ID_down_trapKind_o;	wire	[3:0]	ID_down_trapKind_i;
	assign	ID_down_trapKind_i	=	ID_down_trapKind_o;
	wire	[0:0]	ID_down_memReq_o;	wire	[0:0]	ID_down_memReq_i;
	assign	ID_down_memReq_i	=	ID_down_memReq_o;
	wire	[0:0]	ID_down_memWR_o;	wire	[0:0]	ID_down_memWR_i;
	assign	ID_down_memWR_i	=	ID_down_memWR_o;
	wire	[0:0]	ID_down_memAtom_o;	wire	[0:0]	ID_down_memAtom_i;
	assign	ID_down_memAtom_i	=	ID_down_memAtom_o;
	wire	[6:0]	ID_down_loadMode_o;	wire	[6:0]	ID_down_loadMode_i;
	assign	ID_down_loadMode_i	=	ID_down_loadMode_o;
	wire	[4:0]	ID_down_storeMode_o;	wire	[4:0]	ID_down_storeMode_i;
	assign	ID_down_storeMode_i	=	ID_down_storeMode_o;
	wire	[0:0]	ID_down_isTLBInst_o;	wire	[0:0]	ID_down_isTLBInst_i;
	assign	ID_down_isTLBInst_i	=	ID_down_isTLBInst_o;
	wire	[3:0]	ID_down_TLBInstOperator_o;	wire	[3:0]	ID_down_TLBInstOperator_i;
	assign	ID_down_TLBInstOperator_i	=	ID_down_TLBInstOperator_o;
	wire	[0:0]	ID_down_isCacheInst_o;	wire	[0:0]	ID_down_isCacheInst_i;
	assign	ID_down_isCacheInst_i	=	ID_down_isCacheInst_o;
	wire	[4:0]	ID_down_CacheOperator_o;	wire	[4:0]	ID_down_CacheOperator_i;
	assign	ID_down_CacheOperator_i	=	ID_down_CacheOperator_o;
	wire	[4:0]	DMMU_ExcCode_o;	wire	[4:0]	DMMU_ExcCode_i;
	assign	DMMU_ExcCode_i	=	DMMU_ExcCode_o;
	wire	[0:0]	DMMU_tlbRefill_o;	wire	[0:0]	DMMU_tlbRefill_i;
	assign	DMMU_tlbRefill_i	=	DMMU_tlbRefill_o;
	wire	[0:0]	data_tlbReq_o;	wire	[0:0]	data_tlbReq_i;
	assign	data_tlbReq_i	=	data_tlbReq_o;
	wire	[18:0]	data_vpn2_o;	wire	[18:0]	data_vpn2_i;
	assign	data_vpn2_i	=	data_vpn2_o;
	wire	[0:0]	data_oddPage_o;	wire	[0:0]	data_oddPage_i;
	assign	data_oddPage_i	=	data_oddPage_o;
	wire	[7:0]	data_asid_o;	wire	[7:0]	data_asid_i;
	assign	data_asid_i	=	data_asid_o;
	wire	[0:0]	w_enbale_o;	wire	[0:0]	w_enbale_i;
	assign	w_enbale_i	=	w_enbale_o;
	wire	[4:0]	w_index_o;	wire	[4:0]	w_index_i;
	assign	w_index_i	=	w_index_o;
	wire	[18:0]	w_vpn2_o;	wire	[18:0]	w_vpn2_i;
	assign	w_vpn2_i	=	w_vpn2_o;
	wire	[7:0]	w_asid_o;	wire	[7:0]	w_asid_i;
	assign	w_asid_i	=	w_asid_o;
	wire	[11:0]	w_mask_o;	wire	[11:0]	w_mask_i;
	assign	w_mask_i	=	w_mask_o;
	wire	[0:0]	w_g_o;	wire	[0:0]	w_g_i;
	assign	w_g_i	=	w_g_o;
	wire	[19:0]	w_pfn0_o;	wire	[19:0]	w_pfn0_i;
	assign	w_pfn0_i	=	w_pfn0_o;
	wire	[4:0]	w_flags0_o;	wire	[4:0]	w_flags0_i;
	assign	w_flags0_i	=	w_flags0_o;
	wire	[19:0]	w_pfn1_o;	wire	[19:0]	w_pfn1_i;
	assign	w_pfn1_i	=	w_pfn1_o;
	wire	[4:0]	w_flags1_o;	wire	[4:0]	w_flags1_i;
	assign	w_flags1_i	=	w_flags1_o;
	wire	[0:0]	r_enbale_o;	wire	[0:0]	r_enbale_i;
	assign	r_enbale_i	=	r_enbale_o;
	wire	[4:0]	r_index_o;	wire	[4:0]	r_index_i;
	assign	r_index_i	=	r_index_o;
	wire	[0:0]	DMMU_TLBPwrite_o;	wire	[0:0]	DMMU_TLBPwrite_i;
	assign	DMMU_TLBPwrite_i	=	DMMU_TLBPwrite_o;
	wire	[0:0]	DMMU_TLBRwrite_o;	wire	[0:0]	DMMU_TLBRwrite_i;
	assign	DMMU_TLBRwrite_i	=	DMMU_TLBRwrite_o;
	wire	[31:0]	DMMU_EntryHi_o;	wire	[31:0]	DMMU_EntryHi_i;
	assign	DMMU_EntryHi_i	=	DMMU_EntryHi_o;
	wire	[31:0]	DMMU_EntryLo0_o;	wire	[31:0]	DMMU_EntryLo0_i;
	assign	DMMU_EntryLo0_i	=	DMMU_EntryLo0_o;
	wire	[31:0]	DMMU_EntryLo1_o;	wire	[31:0]	DMMU_EntryLo1_i;
	assign	DMMU_EntryLo1_i	=	DMMU_EntryLo1_o;
	wire	[31:0]	DMMU_PageMask_o;	wire	[31:0]	DMMU_PageMask_i;
	assign	DMMU_PageMask_i	=	DMMU_PageMask_o;
	wire	[31:0]	DMMU_Index_o;	wire	[31:0]	DMMU_Index_i;
	assign	DMMU_Index_i	=	DMMU_Index_o;
	wire	[4:0]	WB_writeNum_w_o;	wire	[4:0]	WB_writeNum_w_i;
	assign	WB_writeNum_w_i	=	WB_writeNum_w_o;
	wire	[0:0]	WB_hasDangerous_w_o;	wire	[0:0]	WB_hasDangerous_w_i;
	assign	WB_hasDangerous_w_i	=	WB_hasDangerous_w_o;
	wire	[0:0]	WB_hasRisk_w_o;	wire	[0:0]	WB_hasRisk_w_i;
	assign	WB_hasRisk_w_i	=	WB_hasRisk_w_o;
	wire	[0:0]	WB_allowin_w_o;	wire	[0:0]	WB_allowin_w_i;
	assign	WB_allowin_w_i	=	WB_allowin_w_o;
	wire	[31:0]	WB_forwardData_w_o;	wire	[31:0]	WB_forwardData_w_i;
	assign	WB_forwardData_w_i	=	WB_forwardData_w_o;
	wire	[31:0]	WB_finalRes_w_o;	wire	[31:0]	WB_finalRes_w_i;
	assign	WB_finalRes_w_i	=	WB_finalRes_w_o;
	wire	[0:0]	WB_writeEnable_w_o;	wire	[0:0]	WB_writeEnable_w_i;
	assign	WB_writeEnable_w_i	=	WB_writeEnable_w_o;
	wire	[31:0]	CP0_Status_w_o;	wire	[31:0]	CP0_Status_w_i;
	assign	CP0_Status_w_i	=	CP0_Status_w_o;
	wire	[31:0]	CP0_Cause_w_o;	wire	[31:0]	CP0_Cause_w_i;
	assign	CP0_Cause_w_i	=	CP0_Cause_w_o;
	wire	[31:0]	CP0_Config_w_o;	wire	[31:0]	CP0_Config_w_i;
	assign	CP0_Config_w_i	=	CP0_Config_w_o;
	wire	[31:0]	CP0_readData_w_o;	wire	[31:0]	CP0_readData_w_i;
	assign	CP0_readData_w_i	=	CP0_readData_w_o;
	wire	[0:0]	CP0_excOccur_w_o;	wire	[0:0]	CP0_excOccur_w_i;
	assign	CP0_excOccur_w_i	=	CP0_excOccur_w_o;
	wire	[31:0]	CP0_excDestPC_w_o;	wire	[31:0]	CP0_excDestPC_w_i;
	assign	CP0_excDestPC_w_i	=	CP0_excDestPC_w_o;
	wire	[0:0]	CP0_nonBlockMark_w_o;	wire	[0:0]	CP0_nonBlockMark_w_i;
	assign	CP0_nonBlockMark_w_i	=	CP0_nonBlockMark_w_o;
	wire	[31:0]	CP0_EntryHi_w_o;	wire	[31:0]	CP0_EntryHi_w_i;
	assign	CP0_EntryHi_w_i	=	CP0_EntryHi_w_o;
	wire	[31:0]	CP0_EntryLo0_w_o;	wire	[31:0]	CP0_EntryLo0_w_i;
	assign	CP0_EntryLo0_w_i	=	CP0_EntryLo0_w_o;
	wire	[31:0]	CP0_EntryLo1_w_o;	wire	[31:0]	CP0_EntryLo1_w_i;
	assign	CP0_EntryLo1_w_i	=	CP0_EntryLo1_w_o;
	wire	[31:0]	CP0_PageMask_w_o;	wire	[31:0]	CP0_PageMask_w_i;
	assign	CP0_PageMask_w_i	=	CP0_PageMask_w_o;
	wire	[31:0]	CP0_Index_w_o;	wire	[31:0]	CP0_Index_w_i;
	assign	CP0_Index_w_i	=	CP0_Index_w_o;
	wire	[31:0]	CP0_Random_w_o;	wire	[31:0]	CP0_Random_w_i;
	assign	CP0_Random_w_i	=	CP0_Random_w_o;
	wire	[3:0]	CP0_exceptSeg_w_o;	wire	[3:0]	CP0_exceptSeg_w_i;
	assign	CP0_exceptSeg_w_i	=	CP0_exceptSeg_w_o;
	wire	[0:0]	REEXE_okToChange_w_o;	wire	[0:0]	REEXE_okToChange_w_i;
	assign	REEXE_okToChange_w_i	=	REEXE_okToChange_w_o;
	wire	[0:0]	REEXE_valid_w_o;	wire	[0:0]	REEXE_valid_w_i;
	assign	REEXE_valid_w_i	=	REEXE_valid_w_o;
	wire	[0:0]	REEXE_forwardMode_w_o;	wire	[0:0]	REEXE_forwardMode_w_i;
	assign	REEXE_forwardMode_w_i	=	REEXE_forwardMode_w_o;
	wire	[4:0]	REEXE_writeNum_w_o;	wire	[4:0]	REEXE_writeNum_w_i;
	assign	REEXE_writeNum_w_i	=	REEXE_writeNum_w_o;
	wire	[4:0]	REEXE_writeNum_o;	wire	[4:0]	REEXE_writeNum_i;
	assign	REEXE_writeNum_i	=	REEXE_writeNum_o;
	wire	[31:0]	REEXE_VAddr_o;	wire	[31:0]	REEXE_VAddr_i;
	assign	REEXE_VAddr_i	=	REEXE_VAddr_o;
	wire	[31:0]	REEXE_regData_o;	wire	[31:0]	REEXE_regData_i;
	assign	REEXE_regData_i	=	REEXE_regData_o;
	wire	[0:0]	inst_hit_o;	wire	[0:0]	inst_hit_i;
	assign	inst_hit_i	=	inst_hit_o;
	wire	[4:0]	inst_index_o;	wire	[4:0]	inst_index_i;
	assign	inst_index_i	=	inst_index_o;
	wire	[19:0]	inst_pfn_o;	wire	[19:0]	inst_pfn_i;
	assign	inst_pfn_i	=	inst_pfn_o;
	wire	[2:0]	inst_c_o;	wire	[2:0]	inst_c_i;
	assign	inst_c_i	=	inst_c_o;
	wire	[0:0]	inst_d_o;	wire	[0:0]	inst_d_i;
	assign	inst_d_i	=	inst_d_o;
	wire	[0:0]	inst_v_o;	wire	[0:0]	inst_v_i;
	assign	inst_v_i	=	inst_v_o;
	wire	[4:0]	data_index_o;	wire	[4:0]	data_index_i;
	assign	data_index_i	=	data_index_o;
	wire	[19:0]	data_pfn_o;	wire	[19:0]	data_pfn_i;
	assign	data_pfn_i	=	data_pfn_o;
	wire	[0:0]	data_hit_o;	wire	[0:0]	data_hit_i;
	assign	data_hit_i	=	data_hit_o;
	wire	[2:0]	data_c_o;	wire	[2:0]	data_c_i;
	assign	data_c_i	=	data_c_o;
	wire	[0:0]	data_d_o;	wire	[0:0]	data_d_i;
	assign	data_d_i	=	data_d_o;
	wire	[0:0]	data_v_o;	wire	[0:0]	data_v_i;
	assign	data_v_i	=	data_v_o;
	wire	[18:0]	r_vpn2_o;	wire	[18:0]	r_vpn2_i;
	assign	r_vpn2_i	=	r_vpn2_o;
	wire	[7:0]	r_asid_o;	wire	[7:0]	r_asid_i;
	assign	r_asid_i	=	r_asid_o;
	wire	[11:0]	r_mask_o;	wire	[11:0]	r_mask_i;
	assign	r_mask_i	=	r_mask_o;
	wire	[0:0]	r_g_o;	wire	[0:0]	r_g_i;
	assign	r_g_i	=	r_g_o;
	wire	[19:0]	r_pfn0_o;	wire	[19:0]	r_pfn0_i;
	assign	r_pfn0_i	=	r_pfn0_o;
	wire	[4:0]	r_flags0_o;	wire	[4:0]	r_flags0_i;
	assign	r_flags0_i	=	r_flags0_o;
	wire	[19:0]	r_pfn1_o;	wire	[19:0]	r_pfn1_i;
	assign	r_pfn1_i	=	r_pfn1_o;
	wire	[4:0]	r_flags1_o;	wire	[4:0]	r_flags1_i;
	assign	r_flags1_i	=	r_flags1_o;
	wire	[0:0]	MEM_forwardMode_w_o;	wire	[0:0]	MEM_forwardMode_w_i;
	assign	MEM_forwardMode_w_i	=	MEM_forwardMode_w_o;
	wire	[4:0]	MEM_writeNum_w_o;	wire	[4:0]	MEM_writeNum_w_i;
	assign	MEM_writeNum_w_i	=	MEM_writeNum_w_o;
	wire	[0:0]	MEM_hasDangerous_w_o;	wire	[0:0]	MEM_hasDangerous_w_i;
	assign	MEM_hasDangerous_w_i	=	MEM_hasDangerous_w_o;
	wire	[0:0]	MEM_hasRisk_w_o;	wire	[0:0]	MEM_hasRisk_w_i;
	assign	MEM_hasRisk_w_i	=	MEM_hasRisk_w_o;
	wire	[0:0]	MEM_allowin_w_o;	wire	[0:0]	MEM_allowin_w_i;
	assign	MEM_allowin_w_i	=	MEM_allowin_w_o;
	wire	[0:0]	MEM_valid_w_o;	wire	[0:0]	MEM_valid_w_i;
	assign	MEM_valid_w_i	=	MEM_valid_w_o;
	wire	[4:0]	MEM_ExcCode_w_o;	wire	[4:0]	MEM_ExcCode_w_i;
	assign	MEM_ExcCode_w_i	=	MEM_ExcCode_w_o;
	wire	[0:0]	MEM_hasException_w_o;	wire	[0:0]	MEM_hasException_w_i;
	assign	MEM_hasException_w_i	=	MEM_hasException_w_o;
	wire	[0:0]	MEM_isDelaySlot_w_o;	wire	[0:0]	MEM_isDelaySlot_w_i;
	assign	MEM_isDelaySlot_w_i	=	MEM_isDelaySlot_w_o;
	wire	[31:0]	MEM_exceptPC_w_o;	wire	[31:0]	MEM_exceptPC_w_i;
	assign	MEM_exceptPC_w_i	=	MEM_exceptPC_w_o;
	wire	[31:0]	MEM_exceptBadVAddr_w_o;	wire	[31:0]	MEM_exceptBadVAddr_w_i;
	assign	MEM_exceptBadVAddr_w_i	=	MEM_exceptBadVAddr_w_o;
	wire	[0:0]	MEM_eret_w_o;	wire	[0:0]	MEM_eret_w_i;
	assign	MEM_eret_w_i	=	MEM_eret_w_o;
	wire	[7:0]	MEM_positionCp0_w_o;	wire	[7:0]	MEM_positionCp0_w_i;
	assign	MEM_positionCp0_w_i	=	MEM_positionCp0_w_o;
	wire	[31:0]	MEM_writeData_w_o;	wire	[31:0]	MEM_writeData_w_i;
	assign	MEM_writeData_w_i	=	MEM_writeData_w_o;
	wire	[0:0]	MEM_nonBlockMark_w_o;	wire	[0:0]	MEM_nonBlockMark_w_i;
	assign	MEM_nonBlockMark_w_i	=	MEM_nonBlockMark_w_o;
	wire	[0:0]	MEM_isRefill_w_o;	wire	[0:0]	MEM_isRefill_w_i;
	assign	MEM_isRefill_w_i	=	MEM_isRefill_w_o;
	wire	[0:0]	MEM_isInterrupt_w_o;	wire	[0:0]	MEM_isInterrupt_w_i;
	assign	MEM_isInterrupt_w_i	=	MEM_isInterrupt_w_o;
	wire	[0:0]	MEM_writeCp0_w_o;	wire	[0:0]	MEM_writeCp0_w_i;
	assign	MEM_writeCp0_w_i	=	MEM_writeCp0_w_o;
	wire	[0:0]	MEM_exceptionRisk_o;	wire	[0:0]	MEM_exceptionRisk_i;
	assign	MEM_exceptionRisk_i	=	MEM_exceptionRisk_o;
	wire	[4:0]	MEM_writeNum_o;	wire	[4:0]	MEM_writeNum_i;
	assign	MEM_writeNum_i	=	MEM_writeNum_o;
	wire	[31:0]	MEM_VAddr_o;	wire	[31:0]	MEM_VAddr_i;
	assign	MEM_VAddr_i	=	MEM_VAddr_o;
	wire	[31:0]	MEM_rtData_o;	wire	[31:0]	MEM_rtData_i;
	assign	MEM_rtData_i	=	MEM_rtData_o;
	wire	[0:0]	MEM_memReq_o;	wire	[0:0]	MEM_memReq_i;
	assign	MEM_memReq_i	=	MEM_memReq_o;
	wire	[0:0]	MEM_isDangerous_o;	wire	[0:0]	MEM_isDangerous_i;
	assign	MEM_isDangerous_i	=	MEM_isDangerous_o;
	wire	[31:0]	MEM_finalRes_o;	wire	[31:0]	MEM_finalRes_i;
	assign	MEM_finalRes_i	=	MEM_finalRes_o;
	wire	[1:0]	MEM_alignCheck_o;	wire	[1:0]	MEM_alignCheck_i;
	assign	MEM_alignCheck_i	=	MEM_alignCheck_o;
	wire	[10:0]	MEM_loadSel_o;	wire	[10:0]	MEM_loadSel_i;
	assign	MEM_loadSel_i	=	MEM_loadSel_o;
	wire	[4:0]	PBA_writeNum_w_o;	wire	[4:0]	PBA_writeNum_w_i;
	assign	PBA_writeNum_w_i	=	PBA_writeNum_w_o;
	wire	[0:0]	PBA_okToChange_w_o;	wire	[0:0]	PBA_okToChange_w_i;
	assign	PBA_okToChange_w_i	=	PBA_okToChange_w_o;
	wire	[31:0]	PBA_forwardData_w_o;	wire	[31:0]	PBA_forwardData_w_i;
	assign	PBA_forwardData_w_i	=	PBA_forwardData_w_o;
	wire	[0:0]	PBA_writeEnable_w_o;	wire	[0:0]	PBA_writeEnable_w_i;
	assign	PBA_writeEnable_w_i	=	PBA_writeEnable_w_o;
	wire	[0:0]	SBA_okToChange_w_o;	wire	[0:0]	SBA_okToChange_w_i;
	assign	SBA_okToChange_w_i	=	SBA_okToChange_w_o;
	wire	[0:0]	SBA_valid_w_o;	wire	[0:0]	SBA_valid_w_i;
	assign	SBA_valid_w_i	=	SBA_valid_w_o;
	wire	[0:0]	SBA_forwardMode_w_o;	wire	[0:0]	SBA_forwardMode_w_i;
	assign	SBA_forwardMode_w_i	=	SBA_forwardMode_w_o;
	wire	[4:0]	SBA_writeNum_w_o;	wire	[4:0]	SBA_writeNum_w_i;
	assign	SBA_writeNum_w_i	=	SBA_writeNum_w_o;
	wire	[0:0]	SBA_nonBlockDS_w_o;	wire	[0:0]	SBA_nonBlockDS_w_i;
	assign	SBA_nonBlockDS_w_i	=	SBA_nonBlockDS_w_o;
	wire	[0:0]	SBA_branchRisk_w_o;	wire	[0:0]	SBA_branchRisk_w_i;
	assign	SBA_branchRisk_w_i	=	SBA_branchRisk_w_o;
	wire	[0:0]	SBA_flush_w_o;	wire	[0:0]	SBA_flush_w_i;
	assign	SBA_flush_w_i	=	SBA_flush_w_o;
	wire	[31:0]	SBA_erroVAddr_w_o;	wire	[31:0]	SBA_erroVAddr_w_i;
	assign	SBA_erroVAddr_w_i	=	SBA_erroVAddr_w_o;
	wire	[31:0]	SBA_corrDest_w_o;	wire	[31:0]	SBA_corrDest_w_i;
	assign	SBA_corrDest_w_i	=	SBA_corrDest_w_o;
	wire	[0:0]	SBA_corrTake_w_o;	wire	[0:0]	SBA_corrTake_w_i;
	assign	SBA_corrTake_w_i	=	SBA_corrTake_w_o;
	wire	[60:0]	SBA_checkPoint_w_o;	wire	[60:0]	SBA_checkPoint_w_i;
	assign	SBA_checkPoint_w_i	=	SBA_checkPoint_w_o;
	wire	[7:0]	SBA_repairAction_w_o;	wire	[7:0]	SBA_repairAction_w_i;
	assign	SBA_repairAction_w_i	=	SBA_repairAction_w_o;
	wire	[4:0]	SBA_writeNum_o;	wire	[4:0]	SBA_writeNum_i;
	assign	SBA_writeNum_i	=	SBA_writeNum_o;
	wire	[31:0]	SBA_VAddr_o;	wire	[31:0]	SBA_VAddr_i;
	assign	SBA_VAddr_i	=	SBA_VAddr_o;
	wire	[31:0]	SBA_aluRes_o;	wire	[31:0]	SBA_aluRes_i;
	assign	SBA_aluRes_i	=	SBA_aluRes_o;
	wire	[127:0]	IF_predDest_p_o;	wire	[127:0]	IF_predDest_p_i;
	assign	IF_predDest_p_i	=	IF_predDest_p_o;
	wire	[3:0]	IF_predTake_p_o;	wire	[3:0]	IF_predTake_p_i;
	assign	IF_predTake_p_i	=	IF_predTake_p_o;
	wire	[243:0]	IF_predInfo_p_o;	wire	[243:0]	IF_predInfo_p_i;
	assign	IF_predInfo_p_i	=	IF_predInfo_p_o;
	wire	[31:0]	IF_instBasePC_o;	wire	[31:0]	IF_instBasePC_i;
	assign	IF_instBasePC_i	=	IF_instBasePC_o;
	wire	[0:0]	IF_valid_o;	wire	[0:0]	IF_valid_i;
	assign	IF_valid_i	=	IF_valid_o;
	wire	[3:0]	IF_instEnable_o;	wire	[3:0]	IF_instEnable_i;
	assign	IF_instEnable_i	=	IF_instEnable_o;
	wire	[127:0]	IF_inst_p_o;	wire	[127:0]	IF_inst_p_i;
	assign	IF_inst_p_i	=	IF_inst_p_o;
	wire	[2:0]	IF_instNum_o;	wire	[2:0]	IF_instNum_i;
	assign	IF_instNum_i	=	IF_instNum_o;
	wire	[0:0]	IF_hasException_o;	wire	[0:0]	IF_hasException_i;
	assign	IF_hasException_i	=	IF_hasException_o;
	wire	[4:0]	IF_ExcCode_o;	wire	[4:0]	IF_ExcCode_i;
	assign	IF_ExcCode_i	=	IF_ExcCode_o;
	wire	[0:0]	IF_isRefill_o;	wire	[0:0]	IF_isRefill_i;
	assign	IF_isRefill_i	=	IF_isRefill_o;
	wire	[0:0]	inst_tlbReq_o;	wire	[0:0]	inst_tlbReq_i;
	assign	inst_tlbReq_i	=	inst_tlbReq_o;
	wire	[18:0]	inst_vpn2_o;	wire	[18:0]	inst_vpn2_i;
	assign	inst_vpn2_i	=	inst_vpn2_o;
	wire	[0:0]	inst_oddPage_o;	wire	[0:0]	inst_oddPage_i;
	assign	inst_oddPage_i	=	inst_oddPage_o;
	wire	[7:0]	inst_asid_o;	wire	[7:0]	inst_asid_i;
	assign	inst_asid_i	=	inst_asid_o;
	wire	[0:0]	EXE_up_forwardMode_w_o;	wire	[0:0]	EXE_up_forwardMode_w_i;
	assign	EXE_up_forwardMode_w_i	=	EXE_up_forwardMode_w_o;
	wire	[4:0]	EXE_up_writeNum_w_o;	wire	[4:0]	EXE_up_writeNum_w_i;
	assign	EXE_up_writeNum_w_i	=	EXE_up_writeNum_w_o;
	wire	[0:0]	EXE_up_okToChange_w_o;	wire	[0:0]	EXE_up_okToChange_w_i;
	assign	EXE_up_okToChange_w_i	=	EXE_up_okToChange_w_o;
	wire	[0:0]	EXE_up_valid_w_o;	wire	[0:0]	EXE_up_valid_w_i;
	assign	EXE_up_valid_w_i	=	EXE_up_valid_w_o;
	wire	[4:0]	EXE_up_writeNum_o;	wire	[4:0]	EXE_up_writeNum_i;
	assign	EXE_up_writeNum_i	=	EXE_up_writeNum_o;
	wire	[31:0]	EXE_up_VAddr_o;	wire	[31:0]	EXE_up_VAddr_i;
	assign	EXE_up_VAddr_i	=	EXE_up_VAddr_o;
	wire	[31:0]	EXE_up_aluRes_o;	wire	[31:0]	EXE_up_aluRes_i;
	assign	EXE_up_aluRes_i	=	EXE_up_aluRes_o;
	wire	[31:0]	EXE_up_corrDest_o;	wire	[31:0]	EXE_up_corrDest_i;
	assign	EXE_up_corrDest_i	=	EXE_up_corrDest_o;
	wire	[0:0]	EXE_up_corrTake_o;	wire	[0:0]	EXE_up_corrTake_i;
	assign	EXE_up_corrTake_i	=	EXE_up_corrTake_o;
	wire	[7:0]	EXE_up_repairAction_o;	wire	[7:0]	EXE_up_repairAction_i;
	assign	EXE_up_repairAction_i	=	EXE_up_repairAction_o;
	wire	[60:0]	EXE_up_checkPoint_o;	wire	[60:0]	EXE_up_checkPoint_i;
	assign	EXE_up_checkPoint_i	=	EXE_up_checkPoint_o;
	wire	[0:0]	EXE_up_branchRisk_o;	wire	[0:0]	EXE_up_branchRisk_i;
	assign	EXE_up_branchRisk_i	=	EXE_up_branchRisk_o;
	wire	[0:0]	EXE_down_forwardMode_w_o;	wire	[0:0]	EXE_down_forwardMode_w_i;
	assign	EXE_down_forwardMode_w_i	=	EXE_down_forwardMode_w_o;
	wire	[4:0]	EXE_down_writeNum_w_o;	wire	[4:0]	EXE_down_writeNum_w_i;
	assign	EXE_down_writeNum_w_i	=	EXE_down_writeNum_w_o;
	wire	[0:0]	EXE_down_valid_w_o;	wire	[0:0]	EXE_down_valid_w_i;
	assign	EXE_down_valid_w_i	=	EXE_down_valid_w_o;
	wire	[0:0]	EXE_down_allowin_w_o;	wire	[0:0]	EXE_down_allowin_w_i;
	assign	EXE_down_allowin_w_i	=	EXE_down_allowin_w_o;
	wire	[0:0]	EXE_down_hasDangerous_w_o;	wire	[0:0]	EXE_down_hasDangerous_w_i;
	assign	EXE_down_hasDangerous_w_i	=	EXE_down_hasDangerous_w_o;
	wire	[0:0]	EXE_down_hasExceprion_w_o;	wire	[0:0]	EXE_down_hasExceprion_w_i;
	assign	EXE_down_hasExceprion_w_i	=	EXE_down_hasExceprion_w_o;
	wire	[4:0]	EXE_down_ExcCode_w_o;	wire	[4:0]	EXE_down_ExcCode_w_i;
	assign	EXE_down_ExcCode_w_i	=	EXE_down_ExcCode_w_o;
	wire	[0:0]	EXE_down_isDelaySlot_w_o;	wire	[0:0]	EXE_down_isDelaySlot_w_i;
	assign	EXE_down_isDelaySlot_w_i	=	EXE_down_isDelaySlot_w_o;
	wire	[31:0]	EXE_down_exceptPC_w_o;	wire	[31:0]	EXE_down_exceptPC_w_i;
	assign	EXE_down_exceptPC_w_i	=	EXE_down_exceptPC_w_o;
	wire	[31:0]	EXE_down_exceptBadVAddr_w_o;	wire	[31:0]	EXE_down_exceptBadVAddr_w_i;
	assign	EXE_down_exceptBadVAddr_w_i	=	EXE_down_exceptBadVAddr_w_o;
	wire	[0:0]	EXE_down_nonBlockMark_w_o;	wire	[0:0]	EXE_down_nonBlockMark_w_i;
	assign	EXE_down_nonBlockMark_w_i	=	EXE_down_nonBlockMark_w_o;
	wire	[0:0]	EXE_down_eret_w_o;	wire	[0:0]	EXE_down_eret_w_i;
	assign	EXE_down_eret_w_i	=	EXE_down_eret_w_o;
	wire	[0:0]	EXE_down_isRefill_w_o;	wire	[0:0]	EXE_down_isRefill_w_i;
	assign	EXE_down_isRefill_w_i	=	EXE_down_isRefill_w_o;
	wire	[0:0]	EXE_down_isInterrupt_w_o;	wire	[0:0]	EXE_down_isInterrupt_w_i;
	assign	EXE_down_isInterrupt_w_i	=	EXE_down_isInterrupt_w_o;
	wire	[4:0]	EXE_down_writeNum_o;	wire	[4:0]	EXE_down_writeNum_i;
	assign	EXE_down_writeNum_i	=	EXE_down_writeNum_o;
	wire	[0:0]	EXE_down_isDelaySlot_o;	wire	[0:0]	EXE_down_isDelaySlot_i;
	assign	EXE_down_isDelaySlot_i	=	EXE_down_isDelaySlot_o;
	wire	[0:0]	EXE_down_isDangerous_o;	wire	[0:0]	EXE_down_isDangerous_i;
	assign	EXE_down_isDangerous_i	=	EXE_down_isDangerous_o;
	wire	[31:0]	EXE_down_VAddr_o;	wire	[31:0]	EXE_down_VAddr_i;
	assign	EXE_down_VAddr_i	=	EXE_down_VAddr_o;
	wire	[31:0]	EXE_down_aluRes_o;	wire	[31:0]	EXE_down_aluRes_i;
	assign	EXE_down_aluRes_i	=	EXE_down_aluRes_o;
	wire	[31:0]	EXE_down_mduRes_o;	wire	[31:0]	EXE_down_mduRes_i;
	assign	EXE_down_mduRes_i	=	EXE_down_mduRes_o;
	wire	[4:0]	EXE_down_clRes_o;	wire	[4:0]	EXE_down_clRes_i;
	assign	EXE_down_clRes_i	=	EXE_down_clRes_o;
	wire	[31:0]	EXE_down_mulRes_o;	wire	[31:0]	EXE_down_mulRes_i;
	assign	EXE_down_mulRes_i	=	EXE_down_mulRes_o;
	wire	[3:0]	EXE_down_mathResSel_o;	wire	[3:0]	EXE_down_mathResSel_i;
	assign	EXE_down_mathResSel_i	=	EXE_down_mathResSel_o;
	wire	[0:0]	EXE_down_nonBlockDS_o;	wire	[0:0]	EXE_down_nonBlockDS_i;
	assign	EXE_down_nonBlockDS_i	=	EXE_down_nonBlockDS_o;
	wire	[0:0]	EXE_down_nonBlockMark_o;	wire	[0:0]	EXE_down_nonBlockMark_i;
	assign	EXE_down_nonBlockMark_i	=	EXE_down_nonBlockMark_o;
	wire	[4:0]	EXE_down_ExcCode_o;	wire	[4:0]	EXE_down_ExcCode_i;
	assign	EXE_down_ExcCode_i	=	EXE_down_ExcCode_o;
	wire	[0:0]	EXE_down_hasException_o;	wire	[0:0]	EXE_down_hasException_i;
	assign	EXE_down_hasException_i	=	EXE_down_hasException_o;
	wire	[0:0]	EXE_down_exceptionRisk_o;	wire	[0:0]	EXE_down_exceptionRisk_i;
	assign	EXE_down_exceptionRisk_i	=	EXE_down_exceptionRisk_o;
	wire	[31:0]	EXE_down_exceptBadVAddr_o;	wire	[31:0]	EXE_down_exceptBadVAddr_i;
	assign	EXE_down_exceptBadVAddr_i	=	EXE_down_exceptBadVAddr_o;
	wire	[0:0]	EXE_down_eret_o;	wire	[0:0]	EXE_down_eret_i;
	assign	EXE_down_eret_i	=	EXE_down_eret_o;
	wire	[0:0]	EXE_down_isRefill_o;	wire	[0:0]	EXE_down_isRefill_i;
	assign	EXE_down_isRefill_i	=	EXE_down_isRefill_o;
	wire	[7:0]	EXE_down_positionCp0_o;	wire	[7:0]	EXE_down_positionCp0_i;
	assign	EXE_down_positionCp0_i	=	EXE_down_positionCp0_o;
	wire	[0:0]	EXE_down_readCp0_o;	wire	[0:0]	EXE_down_readCp0_i;
	assign	EXE_down_readCp0_i	=	EXE_down_readCp0_o;
	wire	[0:0]	EXE_down_writeCp0_o;	wire	[0:0]	EXE_down_writeCp0_i;
	assign	EXE_down_writeCp0_i	=	EXE_down_writeCp0_o;
	wire	[0:0]	EXE_down_memReq_o;	wire	[0:0]	EXE_down_memReq_i;
	assign	EXE_down_memReq_i	=	EXE_down_memReq_o;
	wire	[0:0]	EXE_down_memWR_o;	wire	[0:0]	EXE_down_memWR_i;
	assign	EXE_down_memWR_i	=	EXE_down_memWR_o;
	wire	[3:0]	EXE_down_memEnable_o;	wire	[3:0]	EXE_down_memEnable_i;
	assign	EXE_down_memEnable_i	=	EXE_down_memEnable_o;
	wire	[0:0]	EXE_down_memAtom_o;	wire	[0:0]	EXE_down_memAtom_i;
	assign	EXE_down_memAtom_i	=	EXE_down_memAtom_o;
	wire	[31:0]	EXE_down_storeData_o;	wire	[31:0]	EXE_down_storeData_i;
	assign	EXE_down_storeData_i	=	EXE_down_storeData_o;
	wire	[10:0]	EXE_down_loadSel_o;	wire	[10:0]	EXE_down_loadSel_i;
	assign	EXE_down_loadSel_i	=	EXE_down_loadSel_o;
	wire	[0:0]	EXE_down_isTLBInst_o;	wire	[0:0]	EXE_down_isTLBInst_i;
	assign	EXE_down_isTLBInst_i	=	EXE_down_isTLBInst_o;
	wire	[3:0]	EXE_down_TLBInstOperator_o;	wire	[3:0]	EXE_down_TLBInstOperator_i;
	assign	EXE_down_TLBInstOperator_i	=	EXE_down_TLBInstOperator_o;
	wire	[0:0]	EXE_down_isCacheInst_o;	wire	[0:0]	EXE_down_isCacheInst_i;
	assign	EXE_down_isCacheInst_i	=	EXE_down_isCacheInst_o;
	wire	[4:0]	EXE_down_CacheOperator_o;	wire	[4:0]	EXE_down_CacheOperator_i;
	assign	EXE_down_CacheOperator_i	=	EXE_down_CacheOperator_o;
	wire	[0:0]	PREMEM_forwardMode_w_o;	wire	[0:0]	PREMEM_forwardMode_w_i;
	assign	PREMEM_forwardMode_w_i	=	PREMEM_forwardMode_w_o;
	wire	[4:0]	PREMEM_writeNum_w_o;	wire	[4:0]	PREMEM_writeNum_w_i;
	assign	PREMEM_writeNum_w_i	=	PREMEM_writeNum_w_o;
	wire	[0:0]	PREMEM_hasDangerous_w_o;	wire	[0:0]	PREMEM_hasDangerous_w_i;
	assign	PREMEM_hasDangerous_w_i	=	PREMEM_hasDangerous_w_o;
	wire	[0:0]	PREMEM_hasRisk_w_o;	wire	[0:0]	PREMEM_hasRisk_w_i;
	assign	PREMEM_hasRisk_w_i	=	PREMEM_hasRisk_w_o;
	wire	[0:0]	PREMEM_allowin_w_o;	wire	[0:0]	PREMEM_allowin_w_i;
	assign	PREMEM_allowin_w_i	=	PREMEM_allowin_w_o;
	wire	[0:0]	PREMEM_valid_w_o;	wire	[0:0]	PREMEM_valid_w_i;
	assign	PREMEM_valid_w_i	=	PREMEM_valid_w_o;
	wire	[0:0]	PREMEM_search_w_o;	wire	[0:0]	PREMEM_search_w_i;
	assign	PREMEM_search_w_i	=	PREMEM_search_w_o;
	wire	[0:0]	PREMEM_read_w_o;	wire	[0:0]	PREMEM_read_w_i;
	assign	PREMEM_read_w_i	=	PREMEM_read_w_o;
	wire	[0:0]	PREMEM_map_w_o;	wire	[0:0]	PREMEM_map_w_i;
	assign	PREMEM_map_w_i	=	PREMEM_map_w_o;
	wire	[0:0]	PREMEM_writeI_w_o;	wire	[0:0]	PREMEM_writeI_w_i;
	assign	PREMEM_writeI_w_i	=	PREMEM_writeI_w_o;
	wire	[0:0]	PREMEM_writeR_w_o;	wire	[0:0]	PREMEM_writeR_w_i;
	assign	PREMEM_writeR_w_i	=	PREMEM_writeR_w_o;
	wire	[31:0]	PREMEM_VAddr_w_o;	wire	[31:0]	PREMEM_VAddr_w_i;
	assign	PREMEM_VAddr_w_i	=	PREMEM_VAddr_w_o;
	wire	[0:0]	PREMEM_hasException_w_o;	wire	[0:0]	PREMEM_hasException_w_i;
	assign	PREMEM_hasException_w_i	=	PREMEM_hasException_w_o;
	wire	[4:0]	PREMEM_ExcCode_w_o;	wire	[4:0]	PREMEM_ExcCode_w_i;
	assign	PREMEM_ExcCode_w_i	=	PREMEM_ExcCode_w_o;
	wire	[31:0]	PREMEM_exceptBadVAddr_w_o;	wire	[31:0]	PREMEM_exceptBadVAddr_w_i;
	assign	PREMEM_exceptBadVAddr_w_i	=	PREMEM_exceptBadVAddr_w_o;
	wire	[0:0]	PREMEM_isDelaySlot_w_o;	wire	[0:0]	PREMEM_isDelaySlot_w_i;
	assign	PREMEM_isDelaySlot_w_i	=	PREMEM_isDelaySlot_w_o;
	wire	[31:0]	PREMEM_exceptPC_w_o;	wire	[31:0]	PREMEM_exceptPC_w_i;
	assign	PREMEM_exceptPC_w_i	=	PREMEM_exceptPC_w_o;
	wire	[0:0]	PREMEM_nonBlockMark_w_o;	wire	[0:0]	PREMEM_nonBlockMark_w_i;
	assign	PREMEM_nonBlockMark_w_i	=	PREMEM_nonBlockMark_w_o;
	wire	[0:0]	PREMEM_eret_w_o;	wire	[0:0]	PREMEM_eret_w_i;
	assign	PREMEM_eret_w_i	=	PREMEM_eret_w_o;
	wire	[0:0]	PREMEM_isRefill_w_o;	wire	[0:0]	PREMEM_isRefill_w_i;
	assign	PREMEM_isRefill_w_i	=	PREMEM_isRefill_w_o;
	wire	[0:0]	PREMEM_isInterrupt_w_o;	wire	[0:0]	PREMEM_isInterrupt_w_i;
	assign	PREMEM_isInterrupt_w_i	=	PREMEM_isInterrupt_w_o;
	wire	[4:0]	PREMEM_writeNum_o;	wire	[4:0]	PREMEM_writeNum_i;
	assign	PREMEM_writeNum_i	=	PREMEM_writeNum_o;
	wire	[31:0]	PREMEM_VAddr_o;	wire	[31:0]	PREMEM_VAddr_i;
	assign	PREMEM_VAddr_i	=	PREMEM_VAddr_o;
	wire	[0:0]	PREMEM_isDelaySlot_o;	wire	[0:0]	PREMEM_isDelaySlot_i;
	assign	PREMEM_isDelaySlot_i	=	PREMEM_isDelaySlot_o;
	wire	[0:0]	PREMEM_isDangerous_o;	wire	[0:0]	PREMEM_isDangerous_i;
	assign	PREMEM_isDangerous_i	=	PREMEM_isDangerous_o;
	wire	[1:0]	PREMEM_alignCheck_o;	wire	[1:0]	PREMEM_alignCheck_i;
	assign	PREMEM_alignCheck_i	=	PREMEM_alignCheck_o;
	wire	[10:0]	PREMEM_loadSel_o;	wire	[10:0]	PREMEM_loadSel_i;
	assign	PREMEM_loadSel_i	=	PREMEM_loadSel_o;
	wire	[0:0]	PREMEM_memReq_o;	wire	[0:0]	PREMEM_memReq_i;
	assign	PREMEM_memReq_i	=	PREMEM_memReq_o;
	wire	[31:0]	PREMEM_rtData_o;	wire	[31:0]	PREMEM_rtData_i;
	assign	PREMEM_rtData_i	=	PREMEM_rtData_o;
	wire	[31:0]	PREMEM_preliminaryRes_o;	wire	[31:0]	PREMEM_preliminaryRes_i;
	assign	PREMEM_preliminaryRes_i	=	PREMEM_preliminaryRes_o;
	wire	[0:0]	PREMEM_nonBlockMark_o;	wire	[0:0]	PREMEM_nonBlockMark_i;
	assign	PREMEM_nonBlockMark_i	=	PREMEM_nonBlockMark_o;
	wire	[4:0]	PREMEM_ExcCode_o;	wire	[4:0]	PREMEM_ExcCode_i;
	assign	PREMEM_ExcCode_i	=	PREMEM_ExcCode_o;
	wire	[0:0]	PREMEM_hasException_o;	wire	[0:0]	PREMEM_hasException_i;
	assign	PREMEM_hasException_i	=	PREMEM_hasException_o;
	wire	[0:0]	PREMEM_exceptionRisk_o;	wire	[0:0]	PREMEM_exceptionRisk_i;
	assign	PREMEM_exceptionRisk_i	=	PREMEM_exceptionRisk_o;
	wire	[31:0]	PREMEM_exceptBadVAddr_o;	wire	[31:0]	PREMEM_exceptBadVAddr_i;
	assign	PREMEM_exceptBadVAddr_i	=	PREMEM_exceptBadVAddr_o;
	wire	[0:0]	PREMEM_eret_o;	wire	[0:0]	PREMEM_eret_i;
	assign	PREMEM_eret_i	=	PREMEM_eret_o;
	wire	[0:0]	PREMEM_isRefill_o;	wire	[0:0]	PREMEM_isRefill_i;
	assign	PREMEM_isRefill_i	=	PREMEM_isRefill_o;
	wire	[7:0]	PREMEM_positionCp0_o;	wire	[7:0]	PREMEM_positionCp0_i;
	assign	PREMEM_positionCp0_i	=	PREMEM_positionCp0_o;
	wire	[0:0]	PREMEM_readCp0_o;	wire	[0:0]	PREMEM_readCp0_i;
	assign	PREMEM_readCp0_i	=	PREMEM_readCp0_o;
	wire	[0:0]	PREMEM_writeCp0_o;	wire	[0:0]	PREMEM_writeCp0_i;
	assign	PREMEM_writeCp0_i	=	PREMEM_writeCp0_o;
	wire	[0:0]	PREMEM_isCacheInst_o;	wire	[0:0]	PREMEM_isCacheInst_i;
	assign	PREMEM_isCacheInst_i	=	PREMEM_isCacheInst_o;
	wire	[4:0]	PREMEM_CacheOperator_o;	wire	[4:0]	PREMEM_CacheOperator_i;
	assign	PREMEM_CacheOperator_i	=	PREMEM_CacheOperator_o;
	wire	[31:0]	PREMEM_CacheAddress_o;	wire	[31:0]	PREMEM_CacheAddress_i;
	assign	PREMEM_CacheAddress_i	=	PREMEM_CacheAddress_o;

ID  u_ID (
    .clk                        ( clk                         ),
    .rst                        ( rst                         ),
    .IF_inst_p_i                ( IF_inst_p_i                 ),
    .ID_upDateMode_i            ( ID_upDateMode_i             ),
    .IF_predDest_p_i            ( IF_predDest_p_i             ),
    .IF_predTake_p_i            ( IF_predTake_p_i             ),
    .IF_predInfo_p_i            ( IF_predInfo_p_i             ),
    .IF_instBasePC_i            ( IF_instBasePC_i             ),
    .IF_valid_i                 ( IF_valid_i                  ),
    .IF_instEnable_i            ( IF_instEnable_i             ),
    .IF_instNum_i               ( IF_instNum_i                ),
    .IF_hasException_i          ( IF_hasException_i           ),
    .IF_ExcCode_i               ( IF_ExcCode_i                ),
    .IF_isRefill_i              ( IF_isRefill_i               ),
    .SBA_flush_w_i              ( SBA_flush_w_i               ),
    .CP0_excOccur_w_i           ( CP0_excOccur_w_i            ),
    .EXE_down_allowin_w_i       ( EXE_down_allowin_w_i        ),
    .PBA_writeEnable_w_i        ( PBA_writeEnable_w_i         ),
    .PBA_writeNum_w_i           ( PBA_writeNum_w_i            ),
    .PBA_forwardData_w_i        ( PBA_forwardData_w_i         ),
    .WB_writeEnable_w_i         ( WB_writeEnable_w_i          ),
    .WB_writeNum_w_i            ( WB_writeNum_w_i             ),
    .WB_finalRes_w_i            ( WB_finalRes_w_i             ),
    .EXE_up_writeNum_w_i        ( EXE_up_writeNum_w_i         ),
    .EXE_down_writeNum_w_i      ( EXE_down_writeNum_w_i       ),
    .SBA_writeNum_w_i           ( SBA_writeNum_w_i            ),
    .MEM_writeNum_w_i           ( MEM_writeNum_w_i            ),
    .REEXE_writeNum_w_i         ( REEXE_writeNum_w_i          ),
    .PREMEM_writeNum_w_i        ( PREMEM_writeNum_w_i         ),
    .EXE_up_forwardMode_w_i     ( EXE_up_forwardMode_w_i      ),
    .MEM_forwardMode_w_i        ( MEM_forwardMode_w_i         ),
    .EXE_down_forwardMode_w_i   ( EXE_down_forwardMode_w_i    ),
    .SBA_forwardMode_w_i        ( SBA_forwardMode_w_i         ),
    .PREMEM_forwardMode_w_i     ( PREMEM_forwardMode_w_i      ),
    .REEXE_forwardMode_w_i      ( REEXE_forwardMode_w_i       ),
    .EXE_down_hasDangerous_w_i  ( EXE_down_hasDangerous_w_i   ),
    .MEM_hasDangerous_w_i       ( MEM_hasDangerous_w_i        ),
    .PREMEM_hasDangerous_w_i    ( PREMEM_hasDangerous_w_i     ),
    .WB_hasDangerous_w_i        ( WB_hasDangerous_w_i         ),

    .ID_stopFetch_o             ( ID_stopFetch_o              ),
    .ID_down_valid_w_o          ( ID_down_valid_w_o           ),
    .ID_up_valid_w_o            ( ID_up_valid_w_o             ),
    .ID_upDateMode_o            ( ID_upDateMode_o             ),
    .ID_up_writeNum_o           ( ID_up_writeNum_o            ),
    .ID_up_readData_o           ( ID_up_readData_o            ),
    .ID_up_VAddr_o              ( ID_up_VAddr_o               ),
    .ID_up_oprand0_o            ( ID_up_oprand0_o             ),
    .ID_up_oprand0IsReg_o       ( ID_up_oprand0IsReg_o        ),
    .ID_up_oprand1IsReg_o       ( ID_up_oprand1IsReg_o        ),
    .ID_up_forwardSel0_o        ( ID_up_forwardSel0_o         ),
    .ID_up_data0Ready_o         ( ID_up_data0Ready_o          ),
    .ID_up_oprand1_o            ( ID_up_oprand1_o             ),
    .ID_up_forwardSel1_o        ( ID_up_forwardSel1_o         ),
    .ID_up_data1Ready_o         ( ID_up_data1Ready_o          ),
    .ID_up_aluOprator_o         ( ID_up_aluOprator_o          ),
    .ID_up_branchRisk_o         ( ID_up_branchRisk_o          ),
    .ID_up_repairAction_o       ( ID_up_repairAction_o        ),
    .ID_up_predDest_o           ( ID_up_predDest_o            ),
    .ID_up_predTake_o           ( ID_up_predTake_o            ),
    .ID_up_checkPoint_o         ( ID_up_checkPoint_o          ),
    .ID_up_branchKind_o         ( ID_up_branchKind_o          ),
    .ID_down_writeNum_o         ( ID_down_writeNum_o          ),
    .ID_down_readData_o         ( ID_down_readData_o          ),
    .ID_down_isDelaySlot_o      ( ID_down_isDelaySlot_o       ),
    .ID_down_isDangerous_o      ( ID_down_isDangerous_o       ),
    .ID_down_VAddr_o            ( ID_down_VAddr_o             ),
    .ID_down_oprand0_o          ( ID_down_oprand0_o           ),
    .ID_down_oprand0IsReg_o     ( ID_down_oprand0IsReg_o      ),
    .ID_down_oprand1IsReg_o     ( ID_down_oprand1IsReg_o      ),
    .ID_down_forwardSel0_o      ( ID_down_forwardSel0_o       ),
    .ID_down_data0Ready_o       ( ID_down_data0Ready_o        ),
    .ID_down_oprand1_o          ( ID_down_oprand1_o           ),
    .ID_down_forwardSel1_o      ( ID_down_forwardSel1_o       ),
    .ID_down_data1Ready_o       ( ID_down_data1Ready_o        ),
    .ID_down_aluOprator_o       ( ID_down_aluOprator_o        ),
    .ID_down_mduOperator_o      ( ID_down_mduOperator_o       ),
    .ID_down_readHiLo_o         ( ID_down_readHiLo_o          ),
    .ID_down_writeHiLo_o        ( ID_down_writeHiLo_o         ),
    .ID_down_ExcCode_o          ( ID_down_ExcCode_o           ),
    .ID_down_exceptionSel_o     ( ID_down_exceptionSel_o      ),
    .ID_down_hasException_o     ( ID_down_hasException_o      ),
    .ID_down_exceptionRisk_o    ( ID_down_exceptionRisk_o     ),
    .ID_down_positionCp0_o      ( ID_down_positionCp0_o       ),
    .ID_down_readCp0_o          ( ID_down_readCp0_o           ),
    .ID_down_eret_o             ( ID_down_eret_o              ),
    .ID_down_isRefill_o         ( ID_down_isRefill_o          ),
    .ID_down_writeCp0_o         ( ID_down_writeCp0_o          ),
    .ID_down_trapKind_o         ( ID_down_trapKind_o          ),
    .ID_down_memReq_o           ( ID_down_memReq_o            ),
    .ID_down_memWR_o            ( ID_down_memWR_o             ),
    .ID_down_memAtom_o          ( ID_down_memAtom_o           ),
    .ID_down_loadMode_o         ( ID_down_loadMode_o          ),
    .ID_down_storeMode_o        ( ID_down_storeMode_o         ),
    .ID_down_isTLBInst_o        ( ID_down_isTLBInst_o         ),
    .ID_down_TLBInstOperator_o  ( ID_down_TLBInstOperator_o   ),
    .ID_down_isCacheInst_o      ( ID_down_isCacheInst_o       ),
    .ID_down_CacheOperator_o    ( ID_down_CacheOperator_o     )
);

DataMemoryManagementUnit  u_DataMemoryManagementUnit (
    .clk                     ( clk                 ),
    .rst                     ( rst                 ),
    .PREMEM_search_w_i       ( PREMEM_search_w_i   ),
    .PREMEM_read_w_i         ( PREMEM_read_w_i     ),
    .PREMEM_writeI_w_i       ( PREMEM_writeI_w_i   ),
    .PREMEM_writeR_w_i       ( PREMEM_writeR_w_i   ),
    .PREMEM_map_w_i          ( PREMEM_map_w_i      ),
    .PREMEM_VAddr_w_i        ( PREMEM_VAddr_w_i    ),
    .data_req                ( data_req            ),
    .data_wr                 ( data_wr             ),
    .data_index_ok           ( data_index_ok       ),
    .data_hit_i              ( data_hit_i          ),
    .data_index_i            ( data_index_i        ),
    .data_pfn_i              ( data_pfn_i          ),
    .data_c_i                ( data_c_i            ),
    .data_d_i                ( data_d_i            ),
    .data_v_i                ( data_v_i            ),
    .r_vpn2_i                ( r_vpn2_i            ),
    .r_asid_i                ( r_asid_i            ),
    .r_mask_i                ( r_mask_i            ),
    .r_g_i                   ( r_g_i               ),
    .r_pfn0_i                ( r_pfn0_i            ),
    .r_flags0_i              ( r_flags0_i          ),
    .r_pfn1_i                ( r_pfn1_i            ),
    .r_flags1_i              ( r_flags1_i          ),
    .CP0_Config_w_i          ( CP0_Config_w_i      ),
    .CP0_EntryHi_w_i         ( CP0_EntryHi_w_i     ),
    .CP0_EntryLo0_w_i        ( CP0_EntryLo0_w_i    ),
    .CP0_EntryLo1_w_i        ( CP0_EntryLo1_w_i    ),
    .CP0_PageMask_w_i        ( CP0_PageMask_w_i    ),
    .CP0_Index_w_i           ( CP0_Index_w_i       ),
    .CP0_Random_w_i          ( CP0_Random_w_i      ),

    .DMMU_ExcCode_o          ( DMMU_ExcCode_o      ),
    .DMMU_tlbRefill_o        ( DMMU_tlbRefill_o    ),
    .data_tag                ( data_tag            ),
    .data_unCache            ( data_unCache        ),
    .data_hasException       ( data_hasException   ),
    .data_tlbReq_o           ( data_tlbReq_o       ),
    .data_vpn2_o             ( data_vpn2_o         ),
    .data_oddPage_o          ( data_oddPage_o      ),
    .data_asid_o             ( data_asid_o         ),
    .w_enbale_o              ( w_enbale_o          ),
    .w_index_o               ( w_index_o           ),
    .w_vpn2_o                ( w_vpn2_o            ),
    .w_asid_o                ( w_asid_o            ),
    .w_mask_o                ( w_mask_o            ),
    .w_g_o                   ( w_g_o               ),
    .w_pfn0_o                ( w_pfn0_o            ),
    .w_flags0_o              ( w_flags0_o          ),
    .w_pfn1_o                ( w_pfn1_o            ),
    .w_flags1_o              ( w_flags1_o          ),
    .r_enbale_o              ( r_enbale_o          ),
    .r_index_o               ( r_index_o           ),
    .DMMU_TLBPwrite_o        ( DMMU_TLBPwrite_o    ),
    .DMMU_TLBRwrite_o        ( DMMU_TLBRwrite_o    ),
    .DMMU_EntryHi_o          ( DMMU_EntryHi_o      ),
    .DMMU_EntryLo0_o         ( DMMU_EntryLo0_o     ),
    .DMMU_EntryLo1_o         ( DMMU_EntryLo1_o     ),
    .DMMU_PageMask_o         ( DMMU_PageMask_o     ),
    .DMMU_Index_o            ( DMMU_Index_o        )
);

WriteBack  u_WriteBack (
    .clk                     ( clk                   ),
    .rst                     ( rst                   ),
    .MEM_valid_w_i           ( MEM_valid_w_i         ),
    .PBA_okToChange_w_i      ( PBA_okToChange_w_i    ),
    .data_rdata              ( data_rdata            ),
    .MEM_writeNum_i          ( MEM_writeNum_i        ),
    .MEM_exceptionRisk_i     ( MEM_exceptionRisk_i   ),
    .MEM_memReq_i            ( MEM_memReq_i          ),
    .MEM_VAddr_i             ( MEM_VAddr_i           ),
    .MEM_isDangerous_i       ( MEM_isDangerous_i     ),
    .MEM_finalRes_i          ( MEM_finalRes_i        ),
    .MEM_rtData_i            ( MEM_rtData_i          ),
    .MEM_alignCheck_i        ( MEM_alignCheck_i      ),
    .MEM_loadSel_i           ( MEM_loadSel_i         ),

    .WB_writeNum_w_o         ( WB_writeNum_w_o       ),
    .WB_hasDangerous_w_o     ( WB_hasDangerous_w_o   ),
    .WB_hasRisk_w_o          ( WB_hasRisk_w_o        ),
    .WB_allowin_w_o          ( WB_allowin_w_o        ),
    .WB_forwardData_w_o      ( WB_forwardData_w_o    ),
    .WB_finalRes_w_o         ( WB_finalRes_w_o       ),
    .WB_writeEnable_w_o      ( WB_writeEnable_w_o    ),
    .debug_wb_pc1            ( debug_wb_pc1          ),
    .debug_wb_rf_wen1        ( debug_wb_rf_wen1      ),
    .debug_wb_rf_wnum1       ( debug_wb_rf_wnum1     ),
    .debug_wb_rf_wdata1      ( debug_wb_rf_wdata1    )
);

PrimaryExceptionProcessor  u_PrimaryExceptionProcessor (
    .clk                          ( clk                           ),
    .rst                          ( rst                           ),
    .MEM_writeCp0_w_i             ( MEM_writeCp0_w_i              ),
    .MEM_positionCp0_w_i          ( MEM_positionCp0_w_i           ),
    .MEM_writeData_w_i            ( MEM_writeData_w_i             ),
    .DMMU_TLBPwrite_i             ( DMMU_TLBPwrite_i              ),
    .DMMU_TLBRwrite_i             ( DMMU_TLBRwrite_i              ),
    .DMMU_Index_i                 ( DMMU_Index_i                  ),
    .DMMU_EntryHi_i               ( DMMU_EntryHi_i                ),
    .DMMU_EntryLo0_i              ( DMMU_EntryLo0_i               ),
    .DMMU_EntryLo1_i              ( DMMU_EntryLo1_i               ),
    .DMMU_PageMask_i              ( DMMU_PageMask_i               ),
    .WB_hasRisk_w_i               ( WB_hasRisk_w_i                ),
    .MEM_hasException_w_i         ( MEM_hasException_w_i          ),
    .MEM_ExcCode_w_i              ( MEM_ExcCode_w_i               ),
    .MEM_isDelaySlot_w_i          ( MEM_isDelaySlot_w_i           ),
    .MEM_exceptPC_w_i             ( MEM_exceptPC_w_i              ),
    .MEM_exceptBadVAddr_w_i       ( MEM_exceptBadVAddr_w_i        ),
    .MEM_nonBlockMark_w_i         ( MEM_nonBlockMark_w_i          ),
    .MEM_eret_w_i                 ( MEM_eret_w_i                  ),
    .MEM_isRefill_w_i             ( MEM_isRefill_w_i              ),
    .MEM_isInterrupt_w_i          ( MEM_isInterrupt_w_i           ),
    .MEM_hasRisk_w_i              ( MEM_hasRisk_w_i               ),
    .PREMEM_hasException_w_i      ( PREMEM_hasException_w_i       ),
    .PREMEM_ExcCode_w_i           ( PREMEM_ExcCode_w_i            ),
    .PREMEM_isDelaySlot_w_i       ( PREMEM_isDelaySlot_w_i        ),
    .PREMEM_exceptPC_w_i          ( PREMEM_exceptPC_w_i           ),
    .PREMEM_exceptBadVAddr_w_i    ( PREMEM_exceptBadVAddr_w_i     ),
    .PREMEM_nonBlockMark_w_i      ( PREMEM_nonBlockMark_w_i       ),
    .PREMEM_eret_w_i              ( PREMEM_eret_w_i               ),
    .PREMEM_isRefill_w_i          ( PREMEM_isRefill_w_i           ),
    .PREMEM_isInterrupt_w_i       ( PREMEM_isInterrupt_w_i        ),
    .PREMEM_hasRisk_w_i           ( PREMEM_hasRisk_w_i            ),
    .EXE_down_hasExceprion_w_i    ( EXE_down_hasExceprion_w_i     ),
    .EXE_down_ExcCode_w_i         ( EXE_down_ExcCode_w_i          ),
    .EXE_down_isDelaySlot_w_i     ( EXE_down_isDelaySlot_w_i      ),
    .EXE_down_exceptPC_w_i        ( EXE_down_exceptPC_w_i         ),
    .EXE_down_exceptBadVAddr_w_i  ( EXE_down_exceptBadVAddr_w_i   ),
    .EXE_down_nonBlockMark_w_i    ( EXE_down_nonBlockMark_w_i     ),
    .EXE_down_eret_w_i            ( EXE_down_eret_w_i             ),
    .EXE_down_isRefill_w_i        ( EXE_down_isRefill_w_i         ),
    .EXE_down_isInterrupt_w_i     ( EXE_down_isInterrupt_w_i      ),
    .ext_int                      ( ext_int                       ),

    .CP0_Status_w_o               ( CP0_Status_w_o                ),
    .CP0_Cause_w_o                ( CP0_Cause_w_o                 ),
    .CP0_Config_w_o               ( CP0_Config_w_o                ),
    .CP0_readData_w_o             ( CP0_readData_w_o              ),
    .CP0_excOccur_w_o             ( CP0_excOccur_w_o              ),
    .CP0_excDestPC_w_o            ( CP0_excDestPC_w_o             ),
    .CP0_nonBlockMark_w_o         ( CP0_nonBlockMark_w_o          ),
    .CP0_EntryHi_w_o              ( CP0_EntryHi_w_o               ),
    .CP0_EntryLo0_w_o             ( CP0_EntryLo0_w_o              ),
    .CP0_EntryLo1_w_o             ( CP0_EntryLo1_w_o              ),
    .CP0_PageMask_w_o             ( CP0_PageMask_w_o              ),
    .CP0_Index_w_o                ( CP0_Index_w_o                 ),
    .CP0_Random_w_o               ( CP0_Random_w_o                ),
    .CP0_exceptSeg_w_o            ( CP0_exceptSeg_w_o             )
);

REEXE  u_REEXE (
    .clk                     ( clk                     ),
    .rst                     ( rst                     ),
    .SBA_valid_w_i           ( SBA_valid_w_i           ),
    .MEM_allowin_w_i         ( MEM_allowin_w_i         ),
    .SBA_writeNum_i          ( SBA_writeNum_i          ),
    .SBA_VAddr_i             ( SBA_VAddr_i             ),
    .SBA_aluRes_i            ( SBA_aluRes_i            ),

    .REEXE_okToChange_w_o    ( REEXE_okToChange_w_o    ),
    .REEXE_valid_w_o         ( REEXE_valid_w_o         ),
    .REEXE_forwardMode_w_o   ( REEXE_forwardMode_w_o   ),
    .REEXE_writeNum_w_o      ( REEXE_writeNum_w_o      ),
    .REEXE_writeNum_o        ( REEXE_writeNum_o        ),
    .REEXE_VAddr_o           ( REEXE_VAddr_o           ),
    .REEXE_regData_o         ( REEXE_regData_o         )
);

TLB  u_TLB (
    .clk                     ( clk              ),
    .rst                     ( rst              ),
    .inst_tlbReq_i           ( inst_tlbReq_i    ),
    .inst_vpn2_i             ( inst_vpn2_i      ),
    .inst_oddPage_i          ( inst_oddPage_i   ),
    .inst_asid_i             ( inst_asid_i      ),
    .data_tlbReq_i           ( data_tlbReq_i    ),
    .data_vpn2_i             ( data_vpn2_i      ),
    .data_oddPage_i          ( data_oddPage_i   ),
    .data_asid_i             ( data_asid_i      ),
    .w_enbale_i              ( w_enbale_i       ),
    .w_index_i               ( w_index_i        ),
    .w_vpn2_i                ( w_vpn2_i         ),
    .w_asid_i                ( w_asid_i         ),
    .w_mask_i                ( w_mask_i         ),
    .w_g_i                   ( w_g_i            ),
    .w_pfn0_i                ( w_pfn0_i         ),
    .w_flags0_i              ( w_flags0_i       ),
    .w_pfn1_i                ( w_pfn1_i         ),
    .w_flags1_i              ( w_flags1_i       ),
    .r_enbale_i              ( r_enbale_i       ),
    .r_index_i               ( r_index_i        ),

    .inst_hit_o              ( inst_hit_o       ),
    .inst_index_o            ( inst_index_o     ),
    .inst_pfn_o              ( inst_pfn_o       ),
    .inst_c_o                ( inst_c_o         ),
    .inst_d_o                ( inst_d_o         ),
    .inst_v_o                ( inst_v_o         ),
    .data_index_o            ( data_index_o     ),
    .data_pfn_o              ( data_pfn_o       ),
    .data_hit_o              ( data_hit_o       ),
    .data_c_o                ( data_c_o         ),
    .data_d_o                ( data_d_o         ),
    .data_v_o                ( data_v_o         ),
    .r_vpn2_o                ( r_vpn2_o         ),
    .r_asid_o                ( r_asid_o         ),
    .r_mask_o                ( r_mask_o         ),
    .r_g_o                   ( r_g_o            ),
    .r_pfn0_o                ( r_pfn0_o         ),
    .r_flags0_o              ( r_flags0_o       ),
    .r_pfn1_o                ( r_pfn1_o         ),
    .r_flags1_o              ( r_flags1_o       )
);

MEM  u_MEM (
    .clk                      ( clk                       ),
    .rst                      ( rst                       ),
    .WB_allowin_w_i           ( WB_allowin_w_i            ),
    .PREMEM_valid_w_i         ( PREMEM_valid_w_i          ),
    .REEXE_okToChange_w_i     ( REEXE_okToChange_w_i      ),
    .WB_hasRisk_w_i           ( WB_hasRisk_w_i            ),
    .CP0_excOccur_w_i         ( CP0_excOccur_w_i          ),
    .CP0_exceptSeg_w_i        ( CP0_exceptSeg_w_i         ),
    .CP0_readData_w_i         ( CP0_readData_w_i          ),
    .data_hasException        ( data_hasException         ),
    .DMMU_tlbRefill_i         ( DMMU_tlbRefill_i          ),
    .DMMU_ExcCode_i           ( DMMU_ExcCode_i            ),
    .CP0_Cause_w_i            ( CP0_Cause_w_i             ),
    .CP0_Status_w_i           ( CP0_Status_w_i            ),
    .data_data_ok             ( data_data_ok              ),
    .PREMEM_writeNum_i        ( PREMEM_writeNum_i         ),
    .PREMEM_VAddr_i           ( PREMEM_VAddr_i            ),
    .PREMEM_isDelaySlot_i     ( PREMEM_isDelaySlot_i      ),
    .PREMEM_isDangerous_i     ( PREMEM_isDangerous_i      ),
    .PREMEM_alignCheck_i      ( PREMEM_alignCheck_i       ),
    .PREMEM_loadSel_i         ( PREMEM_loadSel_i          ),
    .PREMEM_memReq_i          ( PREMEM_memReq_i           ),
    .PREMEM_preliminaryRes_i  ( PREMEM_preliminaryRes_i   ),
    .PREMEM_nonBlockMark_i    ( PREMEM_nonBlockMark_i     ),
    .PREMEM_rtData_i          ( PREMEM_rtData_i           ),
    .PREMEM_ExcCode_i         ( PREMEM_ExcCode_i          ),
    .PREMEM_hasException_i    ( PREMEM_hasException_i     ),
    .PREMEM_exceptBadVAddr_i  ( PREMEM_exceptBadVAddr_i   ),
    .PREMEM_eret_i            ( PREMEM_eret_i             ),
    .PREMEM_isRefill_i        ( PREMEM_isRefill_i         ),
    .PREMEM_exceptionRisk_i   ( PREMEM_exceptionRisk_i    ),
    .PREMEM_positionCp0_i     ( PREMEM_positionCp0_i      ),
    .PREMEM_readCp0_i         ( PREMEM_readCp0_i          ),
    .PREMEM_writeCp0_i        ( PREMEM_writeCp0_i         ),
    .PREMEM_isCacheInst_i     ( PREMEM_isCacheInst_i      ),
    .PREMEM_CacheOperator_i   ( PREMEM_CacheOperator_i    ),
    .PREMEM_CacheAddress_i    ( PREMEM_CacheAddress_i     ),

    .MEM_forwardMode_w_o      ( MEM_forwardMode_w_o       ),
    .MEM_writeNum_w_o         ( MEM_writeNum_w_o          ),
    .MEM_hasDangerous_w_o     ( MEM_hasDangerous_w_o      ),
    .MEM_hasRisk_w_o          ( MEM_hasRisk_w_o           ),
    .MEM_allowin_w_o          ( MEM_allowin_w_o           ),
    .MEM_valid_w_o            ( MEM_valid_w_o             ),
    .MEM_ExcCode_w_o          ( MEM_ExcCode_w_o           ),
    .MEM_hasException_w_o     ( MEM_hasException_w_o      ),
    .MEM_isDelaySlot_w_o      ( MEM_isDelaySlot_w_o       ),
    .MEM_exceptPC_w_o         ( MEM_exceptPC_w_o          ),
    .MEM_exceptBadVAddr_w_o   ( MEM_exceptBadVAddr_w_o    ),
    .MEM_eret_w_o             ( MEM_eret_w_o              ),
    .MEM_positionCp0_w_o      ( MEM_positionCp0_w_o       ),
    .MEM_writeData_w_o        ( MEM_writeData_w_o         ),
    .MEM_nonBlockMark_w_o     ( MEM_nonBlockMark_w_o      ),
    .MEM_isRefill_w_o         ( MEM_isRefill_w_o          ),
    .MEM_isInterrupt_w_o      ( MEM_isInterrupt_w_o       ),
    .MEM_writeCp0_w_o         ( MEM_writeCp0_w_o          ),
    .MEM_exceptionRisk_o      ( MEM_exceptionRisk_o       ),
    .MEM_writeNum_o           ( MEM_writeNum_o            ),
    .MEM_VAddr_o              ( MEM_VAddr_o               ),
    .MEM_rtData_o             ( MEM_rtData_o              ),
    .MEM_memReq_o             ( MEM_memReq_o              ),
    .MEM_isDangerous_o        ( MEM_isDangerous_o         ),
    .MEM_finalRes_o           ( MEM_finalRes_o            ),
    .MEM_alignCheck_o         ( MEM_alignCheck_o          ),
    .MEM_loadSel_o            ( MEM_loadSel_o             )
);

PrimaryBranchAmend  u_PrimaryBranchAmend (
    .clk                     ( clk                   ),
    .rst                     ( rst                   ),
    .REEXE_valid_w_i         ( REEXE_valid_w_i       ),
    .WB_allowin_w_i          ( WB_allowin_w_i        ),
    .REEXE_writeNum_i        ( REEXE_writeNum_i      ),
    .REEXE_VAddr_i           ( REEXE_VAddr_i         ),
    .REEXE_regData_i         ( REEXE_regData_i       ),

    .PBA_writeNum_w_o        ( PBA_writeNum_w_o      ),
    .PBA_okToChange_w_o      ( PBA_okToChange_w_o    ),
    .PBA_forwardData_w_o     ( PBA_forwardData_w_o   ),
    .PBA_writeEnable_w_o     ( PBA_writeEnable_w_o   ),
    .debug_wb_pc0            ( debug_wb_pc0          ),
    .debug_wb_rf_wen0        ( debug_wb_rf_wen0      ),
    .debug_wb_rf_wnum0       ( debug_wb_rf_wnum0     ),
    .debug_wb_rf_wdata0      ( debug_wb_rf_wdata0    )
);

SecondBranchAmend  u_SecondBranchAmend (
    .clk                     ( clk                     ),
    .rst                     ( rst                     ),
    .MEM_hasRisk_w_i         ( MEM_hasRisk_w_i         ),
    .CP0_excOccur_w_i        ( CP0_excOccur_w_i        ),
    .CP0_exceptSeg_w_i       ( CP0_exceptSeg_w_i       ),
    .EXE_up_valid_w_i        ( EXE_up_valid_w_i        ),
    .PREMEM_allowin_w_i      ( PREMEM_allowin_w_i      ),
    .EXE_up_writeNum_i       ( EXE_up_writeNum_i       ),
    .EXE_up_VAddr_i          ( EXE_up_VAddr_i          ),
    .EXE_up_aluRes_i         ( EXE_up_aluRes_i         ),
    .EXE_up_corrDest_i       ( EXE_up_corrDest_i       ),
    .EXE_up_corrTake_i       ( EXE_up_corrTake_i       ),
    .EXE_up_repairAction_i   ( EXE_up_repairAction_i   ),
    .EXE_up_checkPoint_i     ( EXE_up_checkPoint_i     ),
    .EXE_up_branchRisk_i     ( EXE_up_branchRisk_i     ),
    .EXE_down_nonBlockDS_i   ( EXE_down_nonBlockDS_i   ),

    .SBA_okToChange_w_o      ( SBA_okToChange_w_o      ),
    .SBA_valid_w_o           ( SBA_valid_w_o           ),
    .SBA_forwardMode_w_o     ( SBA_forwardMode_w_o     ),
    .SBA_writeNum_w_o        ( SBA_writeNum_w_o        ),
    .SBA_nonBlockDS_w_o      ( SBA_nonBlockDS_w_o      ),
    .SBA_branchRisk_w_o      ( SBA_branchRisk_w_o      ),
    .SBA_flush_w_o           ( SBA_flush_w_o           ),
    .SBA_erroVAddr_w_o       ( SBA_erroVAddr_w_o       ),
    .SBA_corrDest_w_o        ( SBA_corrDest_w_o        ),
    .SBA_corrTake_w_o        ( SBA_corrTake_w_o        ),
    .SBA_checkPoint_w_o      ( SBA_checkPoint_w_o      ),
    .SBA_repairAction_w_o    ( SBA_repairAction_w_o    ),
    .SBA_writeNum_o          ( SBA_writeNum_o          ),
    .SBA_VAddr_o             ( SBA_VAddr_o             ),
    .SBA_aluRes_o            ( SBA_aluRes_o            )
);

IF  u_IF (
    .inst_rdata              ( inst_rdata             ),
    .inst_index_ok           ( inst_index_ok          ),
    .inst_data_ok            ( inst_data_ok           ),
    .ID_stopFetch_i          ( ID_stopFetch_i         ),
    .SBA_flush_w_i           ( SBA_flush_w_i          ),
    .SBA_erroVAddr_w_i       ( SBA_erroVAddr_w_i      ),
    .SBA_corrDest_w_i        ( SBA_corrDest_w_i       ),
    .SBA_corrTake_w_i        ( SBA_corrTake_w_i       ),
    .SBA_checkPoint_w_i      ( SBA_checkPoint_w_i     ),
    .SBA_repairAction_w_i    ( SBA_repairAction_w_i   ),
    .CP0_excOccur_w_i        ( CP0_excOccur_w_i       ),
    .CP0_excDestPC_w_i       ( CP0_excDestPC_w_i      ),
    .CP0_Config_w_i          ( CP0_Config_w_i         ),
    .inst_hit_i              ( inst_hit_i             ),
    .inst_index_i            ( inst_index_i           ),
    .inst_pfn_i              ( inst_pfn_i             ),
    .inst_c_i                ( inst_c_i               ),
    .inst_d_i                ( inst_d_i               ),
    .inst_v_i                ( inst_v_i               ),
    .clk                     ( clk                    ),
    .rst                     ( rst                    ),

    .inst_req                ( inst_req               ),
    .inst_wr                 ( inst_wr                ),
    .inst_size               ( inst_size              ),
    .inst_index              ( inst_index             ),
    .inst_tag                ( inst_tag               ),
    .inst_hasException       ( inst_hasException      ),
    .inst_unCache            ( inst_unCache           ),
    .inst_wdata              ( inst_wdata             ),
    .IF_predDest_p_o         ( IF_predDest_p_o        ),
    .IF_predTake_p_o         ( IF_predTake_p_o        ),
    .IF_predInfo_p_o         ( IF_predInfo_p_o        ),
    .IF_instBasePC_o         ( IF_instBasePC_o        ),
    .IF_valid_o              ( IF_valid_o             ),
    .IF_instEnable_o         ( IF_instEnable_o        ),
    .IF_inst_p_o             ( IF_inst_p_o            ),
    .IF_instNum_o            ( IF_instNum_o           ),
    .IF_hasException_o       ( IF_hasException_o      ),
    .IF_ExcCode_o            ( IF_ExcCode_o           ),
    .IF_isRefill_o           ( IF_isRefill_o          ),
    .inst_tlbReq_o           ( inst_tlbReq_o          ),
    .inst_vpn2_o             ( inst_vpn2_o            ),
    .inst_oddPage_o          ( inst_oddPage_o         ),
    .inst_asid_o             ( inst_asid_o            )
);

EXEUP  u_EXEUP (
    .clk                      ( clk                       ),
    .rst                      ( rst                       ),
    .ID_up_valid_w_i          ( ID_up_valid_w_i           ),
    .EXE_down_allowin_w_i     ( EXE_down_allowin_w_i      ),
    .SBA_flush_w_i            ( SBA_flush_w_i             ),
    .CP0_excOccur_w_i         ( CP0_excOccur_w_i          ),
    .CP0_exceptSeg_w_i        ( CP0_exceptSeg_w_i         ),
    .WB_forwardData_w_i       ( WB_forwardData_w_i        ),
    .ID_up_VAddr_i            ( ID_up_VAddr_i             ),
    .ID_up_writeNum_i         ( ID_up_writeNum_i          ),
    .ID_up_readData_i         ( ID_up_readData_i          ),
    .ID_up_oprand0_i          ( ID_up_oprand0_i           ),
    .ID_up_oprand0IsReg_i     ( ID_up_oprand0IsReg_i      ),
    .ID_up_oprand1IsReg_i     ( ID_up_oprand1IsReg_i      ),
    .ID_up_forwardSel0_i      ( ID_up_forwardSel0_i       ),
    .ID_up_data0Ready_i       ( ID_up_data0Ready_i        ),
    .ID_up_oprand1_i          ( ID_up_oprand1_i           ),
    .ID_up_forwardSel1_i      ( ID_up_forwardSel1_i       ),
    .ID_up_data1Ready_i       ( ID_up_data1Ready_i        ),
    .ID_up_aluOprator_i       ( ID_up_aluOprator_i        ),
    .ID_up_branchRisk_i       ( ID_up_branchRisk_i        ),
    .ID_up_branchKind_i       ( ID_up_branchKind_i        ),
    .ID_up_repairAction_i     ( ID_up_repairAction_i      ),
    .ID_up_checkPoint_i       ( ID_up_checkPoint_i        ),
    .ID_up_predDest_i         ( ID_up_predDest_i          ),
    .ID_up_predTake_i         ( ID_up_predTake_i          ),
    .EXE_up_aluRes_i          ( EXE_up_aluRes_i           ),
    .EXE_down_aluRes_i        ( EXE_down_aluRes_i         ),
    .SBA_aluRes_i             ( SBA_aluRes_i              ),
    .REEXE_regData_i          ( REEXE_regData_i           ),
    .PREMEM_preliminaryRes_i  ( PREMEM_preliminaryRes_i   ),
    .MEM_finalRes_i           ( MEM_finalRes_i            ),

    .EXE_up_forwardMode_w_o   ( EXE_up_forwardMode_w_o    ),
    .EXE_up_writeNum_w_o      ( EXE_up_writeNum_w_o       ),
    .EXE_up_okToChange_w_o    ( EXE_up_okToChange_w_o     ),
    .EXE_up_valid_w_o         ( EXE_up_valid_w_o          ),
    .EXE_up_writeNum_o        ( EXE_up_writeNum_o         ),
    .EXE_up_VAddr_o           ( EXE_up_VAddr_o            ),
    .EXE_up_aluRes_o          ( EXE_up_aluRes_o           ),
    .EXE_up_corrDest_o        ( EXE_up_corrDest_o         ),
    .EXE_up_corrTake_o        ( EXE_up_corrTake_o         ),
    .EXE_up_repairAction_o    ( EXE_up_repairAction_o     ),
    .EXE_up_checkPoint_o      ( EXE_up_checkPoint_o       ),
    .EXE_up_branchRisk_o      ( EXE_up_branchRisk_o       )
);

EXEDOWN  u_EXEDOWN (
    .clk                          ( clk                           ),
    .rst                          ( rst                           ),
    .ID_down_valid_w_i            ( ID_down_valid_w_i             ),
    .PREMEM_allowin_w_i           ( PREMEM_allowin_w_i            ),
    .EXE_up_okToChange_w_i        ( EXE_up_okToChange_w_i         ),
    .PREMEM_hasRisk_w_i           ( PREMEM_hasRisk_w_i            ),
    .CP0_nonBlockMark_w_i         ( CP0_nonBlockMark_w_i          ),
    .SBA_nonBlockDS_w_i           ( SBA_nonBlockDS_w_i            ),
    .SBA_branchRisk_w_i           ( SBA_branchRisk_w_i            ),
    .SBA_flush_w_i                ( SBA_flush_w_i                 ),
    .CP0_excOccur_w_i             ( CP0_excOccur_w_i              ),
    .CP0_exceptSeg_w_i            ( CP0_exceptSeg_w_i             ),
    .WB_forwardData_w_i           ( WB_forwardData_w_i            ),
    .ID_down_writeNum_i           ( ID_down_writeNum_i            ),
    .ID_down_readData_i           ( ID_down_readData_i            ),
    .ID_down_isDelaySlot_i        ( ID_down_isDelaySlot_i         ),
    .ID_down_isDangerous_i        ( ID_down_isDangerous_i         ),
    .ID_down_VAddr_i              ( ID_down_VAddr_i               ),
    .ID_down_oprand0_i            ( ID_down_oprand0_i             ),
    .ID_down_oprand0IsReg_i       ( ID_down_oprand0IsReg_i        ),
    .ID_down_oprand1IsReg_i       ( ID_down_oprand1IsReg_i        ),
    .ID_down_forwardSel0_i        ( ID_down_forwardSel0_i         ),
    .ID_down_data0Ready_i         ( ID_down_data0Ready_i          ),
    .ID_down_oprand1_i            ( ID_down_oprand1_i             ),
    .ID_down_forwardSel1_i        ( ID_down_forwardSel1_i         ),
    .ID_down_data1Ready_i         ( ID_down_data1Ready_i          ),
    .ID_down_aluOprator_i         ( ID_down_aluOprator_i          ),
    .ID_down_mduOperator_i        ( ID_down_mduOperator_i         ),
    .ID_down_readHiLo_i           ( ID_down_readHiLo_i            ),
    .ID_down_writeHiLo_i          ( ID_down_writeHiLo_i           ),
    .ID_down_ExcCode_i            ( ID_down_ExcCode_i             ),
    .ID_down_exceptionSel_i       ( ID_down_exceptionSel_i        ),
    .ID_down_hasException_i       ( ID_down_hasException_i        ),
    .ID_down_eret_i               ( ID_down_eret_i                ),
    .ID_down_isRefill_i           ( ID_down_isRefill_i            ),
    .ID_down_exceptionRisk_i      ( ID_down_exceptionRisk_i       ),
    .ID_up_branchRisk_i           ( ID_up_branchRisk_i            ),
    .ID_down_positionCp0_i        ( ID_down_positionCp0_i         ),
    .ID_down_readCp0_i            ( ID_down_readCp0_i             ),
    .ID_down_writeCp0_i           ( ID_down_writeCp0_i            ),
    .ID_down_trapKind_i           ( ID_down_trapKind_i            ),
    .ID_down_memReq_i             ( ID_down_memReq_i              ),
    .ID_down_memWR_i              ( ID_down_memWR_i               ),
    .ID_down_memAtom_i            ( ID_down_memAtom_i             ),
    .ID_down_loadMode_i           ( ID_down_loadMode_i            ),
    .ID_down_storeMode_i          ( ID_down_storeMode_i           ),
    .ID_down_isTLBInst_i          ( ID_down_isTLBInst_i           ),
    .ID_down_TLBInstOperator_i    ( ID_down_TLBInstOperator_i     ),
    .ID_down_isCacheInst_i        ( ID_down_isCacheInst_i         ),
    .ID_down_CacheOperator_i      ( ID_down_CacheOperator_i       ),
    .EXE_up_aluRes_i              ( EXE_up_aluRes_i               ),
    .EXE_down_aluRes_i            ( EXE_down_aluRes_i             ),
    .SBA_aluRes_i                 ( SBA_aluRes_i                  ),
    .REEXE_regData_i              ( REEXE_regData_i               ),
    .PREMEM_preliminaryRes_i      ( PREMEM_preliminaryRes_i       ),
    .MEM_finalRes_i               ( MEM_finalRes_i                ),

    .EXE_down_forwardMode_w_o     ( EXE_down_forwardMode_w_o      ),
    .EXE_down_writeNum_w_o        ( EXE_down_writeNum_w_o         ),
    .EXE_down_valid_w_o           ( EXE_down_valid_w_o            ),
    .EXE_down_allowin_w_o         ( EXE_down_allowin_w_o          ),
    .EXE_down_hasDangerous_w_o    ( EXE_down_hasDangerous_w_o     ),
    .EXE_down_hasExceprion_w_o    ( EXE_down_hasExceprion_w_o     ),
    .EXE_down_ExcCode_w_o         ( EXE_down_ExcCode_w_o          ),
    .EXE_down_isDelaySlot_w_o     ( EXE_down_isDelaySlot_w_o      ),
    .EXE_down_exceptPC_w_o        ( EXE_down_exceptPC_w_o         ),
    .EXE_down_exceptBadVAddr_w_o  ( EXE_down_exceptBadVAddr_w_o   ),
    .EXE_down_nonBlockMark_w_o    ( EXE_down_nonBlockMark_w_o     ),
    .EXE_down_eret_w_o            ( EXE_down_eret_w_o             ),
    .EXE_down_isRefill_w_o        ( EXE_down_isRefill_w_o         ),
    .EXE_down_isInterrupt_w_o     ( EXE_down_isInterrupt_w_o      ),
    .EXE_down_writeNum_o          ( EXE_down_writeNum_o           ),
    .EXE_down_isDelaySlot_o       ( EXE_down_isDelaySlot_o        ),
    .EXE_down_isDangerous_o       ( EXE_down_isDangerous_o        ),
    .EXE_down_VAddr_o             ( EXE_down_VAddr_o              ),
    .EXE_down_aluRes_o            ( EXE_down_aluRes_o             ),
    .EXE_down_mduRes_o            ( EXE_down_mduRes_o             ),
    .EXE_down_clRes_o             ( EXE_down_clRes_o              ),
    .EXE_down_mulRes_o            ( EXE_down_mulRes_o             ),
    .EXE_down_mathResSel_o        ( EXE_down_mathResSel_o         ),
    .EXE_down_nonBlockDS_o        ( EXE_down_nonBlockDS_o         ),
    .EXE_down_nonBlockMark_o      ( EXE_down_nonBlockMark_o       ),
    .EXE_down_ExcCode_o           ( EXE_down_ExcCode_o            ),
    .EXE_down_hasException_o      ( EXE_down_hasException_o       ),
    .EXE_down_exceptionRisk_o     ( EXE_down_exceptionRisk_o      ),
    .EXE_down_exceptBadVAddr_o    ( EXE_down_exceptBadVAddr_o     ),
    .EXE_down_eret_o              ( EXE_down_eret_o               ),
    .EXE_down_isRefill_o          ( EXE_down_isRefill_o           ),
    .EXE_down_positionCp0_o       ( EXE_down_positionCp0_o        ),
    .EXE_down_readCp0_o           ( EXE_down_readCp0_o            ),
    .EXE_down_writeCp0_o          ( EXE_down_writeCp0_o           ),
    .EXE_down_memReq_o            ( EXE_down_memReq_o             ),
    .EXE_down_memWR_o             ( EXE_down_memWR_o              ),
    .EXE_down_memEnable_o         ( EXE_down_memEnable_o          ),
    .EXE_down_memAtom_o           ( EXE_down_memAtom_o            ),
    .EXE_down_storeData_o         ( EXE_down_storeData_o          ),
    .EXE_down_loadSel_o           ( EXE_down_loadSel_o            ),
    .EXE_down_isTLBInst_o         ( EXE_down_isTLBInst_o          ),
    .EXE_down_TLBInstOperator_o   ( EXE_down_TLBInstOperator_o    ),
    .EXE_down_isCacheInst_o       ( EXE_down_isCacheInst_o        ),
    .EXE_down_CacheOperator_o     ( EXE_down_CacheOperator_o      )
);

PREMEM  u_PREMEM (
    .clk                         ( clk                          ),
    .rst                         ( rst                          ),
    .MEM_allowin_w_i             ( MEM_allowin_w_i              ),
    .EXE_down_valid_w_i          ( EXE_down_valid_w_i           ),
    .SBA_okToChange_w_i          ( SBA_okToChange_w_i           ),
    .MEM_hasRisk_w_i             ( MEM_hasRisk_w_i              ),
    .CP0_excOccur_w_i            ( CP0_excOccur_w_i             ),
    .CP0_exceptSeg_w_i           ( CP0_exceptSeg_w_i            ),
    .SBA_flush_w_i               ( SBA_flush_w_i                ),
    .data_index_ok               ( data_index_ok                ),
    .EXE_down_writeNum_i         ( EXE_down_writeNum_i          ),
    .EXE_down_isDelaySlot_i      ( EXE_down_isDelaySlot_i       ),
    .EXE_down_isDangerous_i      ( EXE_down_isDangerous_i       ),
    .EXE_down_VAddr_i            ( EXE_down_VAddr_i             ),
    .EXE_down_aluRes_i           ( EXE_down_aluRes_i            ),
    .EXE_down_mduRes_i           ( EXE_down_mduRes_i            ),
    .EXE_down_clRes_i            ( EXE_down_clRes_i             ),
    .EXE_down_mulRes_i           ( EXE_down_mulRes_i            ),
    .EXE_down_mathResSel_i       ( EXE_down_mathResSel_i        ),
    .EXE_down_nonBlockMark_i     ( EXE_down_nonBlockMark_i      ),
    .EXE_up_branchRisk_i         ( EXE_up_branchRisk_i          ),
    .EXE_down_ExcCode_i          ( EXE_down_ExcCode_i           ),
    .EXE_down_hasException_i     ( EXE_down_hasException_i      ),
    .EXE_down_exceptionRisk_i    ( EXE_down_exceptionRisk_i     ),
    .EXE_down_exceptBadVAddr_i   ( EXE_down_exceptBadVAddr_i    ),
    .EXE_down_eret_i             ( EXE_down_eret_i              ),
    .EXE_down_isRefill_i         ( EXE_down_isRefill_i          ),
    .EXE_down_positionCp0_i      ( EXE_down_positionCp0_i       ),
    .EXE_down_readCp0_i          ( EXE_down_readCp0_i           ),
    .EXE_down_writeCp0_i         ( EXE_down_writeCp0_i          ),
    .EXE_down_memReq_i           ( EXE_down_memReq_i            ),
    .EXE_down_memWR_i            ( EXE_down_memWR_i             ),
    .EXE_down_memEnable_i        ( EXE_down_memEnable_i         ),
    .EXE_down_memAtom_i          ( EXE_down_memAtom_i           ),
    .EXE_down_storeData_i        ( EXE_down_storeData_i         ),
    .EXE_down_loadSel_i          ( EXE_down_loadSel_i           ),
    .EXE_down_isTLBInst_i        ( EXE_down_isTLBInst_i         ),
    .EXE_down_TLBInstOperator_i  ( EXE_down_TLBInstOperator_i   ),
    .EXE_down_isCacheInst_i      ( EXE_down_isCacheInst_i       ),
    .EXE_down_CacheOperator_i    ( EXE_down_CacheOperator_i     ),

    .PREMEM_forwardMode_w_o      ( PREMEM_forwardMode_w_o       ),
    .PREMEM_writeNum_w_o         ( PREMEM_writeNum_w_o          ),
    .PREMEM_hasDangerous_w_o     ( PREMEM_hasDangerous_w_o      ),
    .PREMEM_hasRisk_w_o          ( PREMEM_hasRisk_w_o           ),
    .PREMEM_allowin_w_o          ( PREMEM_allowin_w_o           ),
    .PREMEM_valid_w_o            ( PREMEM_valid_w_o             ),
    .data_index                  ( data_index                   ),
    .data_req                    ( data_req                     ),
    .data_wr                     ( data_wr                      ),
    .data_size                   ( data_size                    ),
    .data_wstrb                  ( data_wstrb                   ),
    .data_wdata                  ( data_wdata                   ),
    .PREMEM_search_w_o           ( PREMEM_search_w_o            ),
    .PREMEM_read_w_o             ( PREMEM_read_w_o              ),
    .PREMEM_map_w_o              ( PREMEM_map_w_o               ),
    .PREMEM_writeI_w_o           ( PREMEM_writeI_w_o            ),
    .PREMEM_writeR_w_o           ( PREMEM_writeR_w_o            ),
    .PREMEM_VAddr_w_o            ( PREMEM_VAddr_w_o             ),
    .PREMEM_hasException_w_o     ( PREMEM_hasException_w_o      ),
    .PREMEM_ExcCode_w_o          ( PREMEM_ExcCode_w_o           ),
    .PREMEM_exceptBadVAddr_w_o   ( PREMEM_exceptBadVAddr_w_o    ),
    .PREMEM_isDelaySlot_w_o      ( PREMEM_isDelaySlot_w_o       ),
    .PREMEM_exceptPC_w_o         ( PREMEM_exceptPC_w_o          ),
    .PREMEM_nonBlockMark_w_o     ( PREMEM_nonBlockMark_w_o      ),
    .PREMEM_eret_w_o             ( PREMEM_eret_w_o              ),
    .PREMEM_isRefill_w_o         ( PREMEM_isRefill_w_o          ),
    .PREMEM_isInterrupt_w_o      ( PREMEM_isInterrupt_w_o       ),
    .PREMEM_writeNum_o           ( PREMEM_writeNum_o            ),
    .PREMEM_VAddr_o              ( PREMEM_VAddr_o               ),
    .PREMEM_isDelaySlot_o        ( PREMEM_isDelaySlot_o         ),
    .PREMEM_isDangerous_o        ( PREMEM_isDangerous_o         ),
    .PREMEM_alignCheck_o         ( PREMEM_alignCheck_o          ),
    .PREMEM_loadSel_o            ( PREMEM_loadSel_o             ),
    .PREMEM_memReq_o             ( PREMEM_memReq_o              ),
    .PREMEM_rtData_o             ( PREMEM_rtData_o              ),
    .PREMEM_preliminaryRes_o     ( PREMEM_preliminaryRes_o      ),
    .PREMEM_nonBlockMark_o       ( PREMEM_nonBlockMark_o        ),
    .PREMEM_ExcCode_o            ( PREMEM_ExcCode_o             ),
    .PREMEM_hasException_o       ( PREMEM_hasException_o        ),
    .PREMEM_exceptionRisk_o      ( PREMEM_exceptionRisk_o       ),
    .PREMEM_exceptBadVAddr_o     ( PREMEM_exceptBadVAddr_o      ),
    .PREMEM_eret_o               ( PREMEM_eret_o                ),
    .PREMEM_isRefill_o           ( PREMEM_isRefill_o            ),
    .PREMEM_positionCp0_o        ( PREMEM_positionCp0_o         ),
    .PREMEM_readCp0_o            ( PREMEM_readCp0_o             ),
    .PREMEM_writeCp0_o           ( PREMEM_writeCp0_o            ),
    .PREMEM_isCacheInst_o        ( PREMEM_isCacheInst_o         ),
    .PREMEM_CacheOperator_o      ( PREMEM_CacheOperator_o       ),
    .PREMEM_CacheAddress_o       ( PREMEM_CacheAddress_o        )
);

 
    /////////////////////////////////////////////////////////////////////
    ////////////////        autoConnect Code end         ////////////////}}}
    /////////////////////////////////////////////////////////////////////

endmodule