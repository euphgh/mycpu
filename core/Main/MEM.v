// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/02 17:29
// Last Modified : 2022/08/08 11:05
// File Name     : MEM.v
// Description   : 访存，取出tlb映射送入cache，执行cache指令和tlb指令
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/07/02   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "../MyDefines.v"
module MEM(
    input	wire	clk,
    input	wire	rst,

    //////////////////////////////////////////////////
    //////////////     线信号输入      ///////////////{{{
    //////////////////////////////////////////////////
    // 前后流水线互锁 
    input	wire	                        WB_allowin_w_i,
    input	wire	                        PREMEM_valid_w_i,
    // 上下流水线互锁
    input	wire	                        REEXE_okToChange_w_i,
    // 异常互锁
    input	wire                            WB_hasRisk_w_i, 
    // 流水线刷新
    input	wire	                        CP0_excOccur_w_i,
    input	wire	[`EXCEP_SEG]            CP0_exceptSeg_w_i,
    input	wire	[`SINGLE_WORD]          CP0_readData_w_i,   // 读出来的寄存器数值
    // 在执行TLB指令后，需要将以下数据写入CP0寄存器
    input	wire	                        data_hasException,
    input	wire	                        DMMU_tlbRefill_i,   // 是否有重填异常
    input	wire	[`EXCCODE]              DMMU_ExcCode_i,     //包括TLB异常以及非对齐异常
    input	wire	[`SINGLE_WORD]          CP0_Cause_w_i,
    input	wire	[`SINGLE_WORD]          CP0_Status_w_i,
    // 总线信号
    input	wire	                        data_data_ok,
/*}}}*/
    //////////////////////////////////////////////////
    //////////////     线信号输出      ///////////////{{{
    //////////////////////////////////////////////////
    // ID阶段前递控制
    output	wire	                        MEM_forwardMode_w_o,    
    output	wire	[`GPR_NUM]              MEM_writeNum_w_o,    
    //危险暂停信号
    output	wire	                        MEM_hasDangerous_w_o,   // mul,clo,clz,madd,msub,cache,tlb等危险指令
    // 异常互锁
    output	wire	                        MEM_hasRisk_w_o,         
    // 流水线互锁信号 {{{
    output	wire	                        MEM_allowin_w_o,        // 逐级互锁信号
    output	wire	                        MEM_valid_w_o,          // 给下一级流水线决定是否采样
    // }}}
    // cache指令接口{{{
    /* output                                  dcache_req  , */
    /* output           [4 :0]                 dcache_op   , */
    /* output           [31:0]                 dcache_addr , */
    /* output           [19:0]                 dcache_tag  , */
    /* output                                  dcache_valid, */
    /* output                                  dcache_dirty, */
    /* output                                  dcache_ok   , */
    /* output                                  icache_req  , */
    /* output          [4 :0]                  icache_op   , */
    /* output          [31:0]                  icache_addr , */
    /* output          [19:0]                  icache_tag  , */
    /* output                                  icache_valid, */
    /* input                                   icache_ok   , */
    // }}}
    // 用于CP0进行异常处理的信号{{{
    output	wire    [`EXCCODE]              MEM_ExcCode_w_o,          // 异常信号
    output	wire	                        MEM_hasException_w_o,     // 存在异常
    output	wire	                        MEM_isDelaySlot_w_o,
    output	wire	[`SINGLE_WORD]          MEM_exceptPC_w_o,
    output	wire	[`SINGLE_WORD]          MEM_exceptBadVAddr_w_o,
    output	wire	                        MEM_eret_w_o,
    output	wire	[`CP0_POSITION]         MEM_positionCp0_w_o,    // {rd,sel}
    output	wire	[`SINGLE_WORD]          MEM_writeData_w_o,      // 需要写入CP0的内容
    output	wire	                        MEM_nonBlockMark_w_o,
    output	wire	                        MEM_isRefill_w_o,       // 不同异常地址
    output	wire	                        MEM_isInterrupt_w_o,    // 不同异常地址
    output	wire	                        MEM_writeCp0_w_o,       // mtc0,才会拉高 }}}
    // }}}
    /////////////////////////////////////////////////
    //////////////      寄存器输入   ////////////////{{{
    /////////////////////////////////////////////////

    input	wire    [`GPR_NUM]              PREMEM_writeNum_i,
    input	wire	[`SINGLE_WORD]          PREMEM_VAddr_i,
    input	wire	                        PREMEM_isDelaySlot_i,       // 该指令是否是延迟槽指令,用于异常处理
    input	wire	                        PREMEM_isDangerous_i,       // 该条指令是危险指令,传递给下一级
    input	wire	[1:0]                   PREMEM_alignCheck_i,
    // 访存类信息
    input	wire    [`LOAD_SEL]             PREMEM_loadSel_i,           // load指令模式		
    input	wire                            PREMEM_memReq_i,           // load指令模式		
    // 算数,位移    
    input	wire    [`SINGLE_WORD]          PREMEM_preliminaryRes_i,    // 对应于SBA段的aluRes，PREMEM段的结果对于乘除指令和mf指令是已经完成了的        
    input	wire	                        PREMEM_nonBlockMark_i,      // 该条指令执行在MDU运算期间
    input	wire	[`SINGLE_WORD]          PREMEM_rtData_i,
    // 异常处理类信息
    input	wire    [`EXCCODE]              PREMEM_ExcCode_i,           // 异常信号
    input	wire	                        PREMEM_hasException_i,      // 存在异常
    input	wire	[`SINGLE_WORD]          PREMEM_exceptBadVAddr_i,    // 虚地址异常
    input	wire	                        PREMEM_eret_i,
    input	wire	                        PREMEM_isRefill_i,
    input	wire                            PREMEM_exceptionRisk_i,     // 存在异常的风险
    input	wire	[`CP0_POSITION]         PREMEM_positionCp0_i,       // {rd,sel}
    input	wire	                        PREMEM_readCp0_i,           // mfc0,才会拉高
    input	wire	                        PREMEM_writeCp0_i,          // mtc0,才会拉高
    // Cache指令,在该段中,cache地址由aluRes给出
    input	wire	                        PREMEM_isCacheInst_i,       // 表示是Cache指令
    input	wire	[`CACHE_OP]             PREMEM_CacheOperator_i,     // Cache指令op
    input	wire	[`SINGLE_WORD]          PREMEM_CacheAddress_i,      // Cache指令地址
/*}}}*/
    //////////////////////////////////////////////////
    //////////////      寄存器输出      //////////////{{{
    //////////////////////////////////////////////////
    output	wire	                        MEM_exceptionRisk_o,
    output	wire	[`GPR_NUM]              MEM_writeNum_o,         // 回写寄存器数值,0为不回写
    output	wire	[`SINGLE_WORD]          MEM_VAddr_o,
    output	wire	[`SINGLE_WORD]          MEM_rtData_o,
    output	wire	                        MEM_memReq_o,
    output	wire	                        MEM_isDangerous_o,      // 表示该条指令是不是危险指令,传递给下一级
    output	wire    [`SINGLE_WORD]          MEM_finalRes_o,         // 最终写入寄存器的数值 包括alu，乘除，cp0
    output	wire	[1:0]                   MEM_alignCheck_o,
    output	wire    [`LOAD_SEL]             MEM_loadSel_o           // load指令模式		
/*}}}*/
);
    // 自动定义{{{
    /*autodef*/
    // }}}
    //Intersegment_register{{{

    wire            needClear;
    wire            needUpdata;

	reg	[`GPR_NUM]			PREMEM_writeNum_r_i;
	reg	[`SINGLE_WORD]			PREMEM_VAddr_r_i;
	reg	[0:0]			PREMEM_isDelaySlot_r_i;
	reg	[0:0]			PREMEM_isDangerous_r_i;
	reg	[1:0]			PREMEM_alignCheck_r_i;
	reg	[`LOAD_SEL]			PREMEM_loadSel_r_i;
	reg	[0:0]			PREMEM_memReq_r_i;
	reg	[`SINGLE_WORD]			PREMEM_preliminaryRes_r_i;
	reg	[0:0]			PREMEM_nonBlockMark_r_i;
	reg	[`SINGLE_WORD]			PREMEM_rtData_r_i;
	reg	[`EXCCODE]			PREMEM_ExcCode_r_i;
	reg	[0:0]			PREMEM_hasException_r_i;
	reg	[`SINGLE_WORD]			PREMEM_exceptBadVAddr_r_i;
	reg	[0:0]			PREMEM_eret_r_i;
	reg	[0:0]			PREMEM_isRefill_r_i;
	reg	[0:0]			PREMEM_exceptionRisk_r_i;
	reg	[`CP0_POSITION]			PREMEM_positionCp0_r_i;
	reg	[0:0]			PREMEM_readCp0_r_i;
	reg	[0:0]			PREMEM_writeCp0_r_i;
	reg	[0:0]			PREMEM_isCacheInst_r_i;
	reg	[`CACHE_OP]			PREMEM_CacheOperator_r_i;
	reg	[`SINGLE_WORD]			PREMEM_CacheAddress_r_i;
    always @(posedge clk) begin
        if (!rst || needClear) begin
			PREMEM_writeNum_r_i	<=	'b0;
			PREMEM_VAddr_r_i	<=	'b0;
			PREMEM_isDelaySlot_r_i	<=	'b0;
			PREMEM_isDangerous_r_i	<=	'b0;
			PREMEM_alignCheck_r_i	<=	'b0;
			PREMEM_loadSel_r_i	<=	'b0;
			PREMEM_memReq_r_i	<=	'b0;
			PREMEM_preliminaryRes_r_i	<=	'b0;
			PREMEM_nonBlockMark_r_i	<=	'b0;
			PREMEM_rtData_r_i	<=	'b0;
			PREMEM_ExcCode_r_i	<=	'b0;
			PREMEM_hasException_r_i	<=	'b0;
			PREMEM_exceptBadVAddr_r_i	<=	'b0;
			PREMEM_eret_r_i	<=	'b0;
			PREMEM_isRefill_r_i	<=	'b0;
			PREMEM_exceptionRisk_r_i	<=	'b0;
			PREMEM_positionCp0_r_i	<=	'b0;
			PREMEM_readCp0_r_i	<=	'b0;
			PREMEM_writeCp0_r_i	<=	'b0;
			PREMEM_isCacheInst_r_i	<=	'b0;
			PREMEM_CacheOperator_r_i	<=	'b0;
			PREMEM_CacheAddress_r_i	<=	'b0;
        end
        else if (needUpdata) begin
			PREMEM_writeNum_r_i	<=	PREMEM_writeNum_i;
			PREMEM_VAddr_r_i	<=	PREMEM_VAddr_i;
			PREMEM_isDelaySlot_r_i	<=	PREMEM_isDelaySlot_i;
			PREMEM_isDangerous_r_i	<=	PREMEM_isDangerous_i;
			PREMEM_alignCheck_r_i	<=	PREMEM_alignCheck_i;
			PREMEM_loadSel_r_i	<=	PREMEM_loadSel_i;
			PREMEM_memReq_r_i	<=	PREMEM_memReq_i;
			PREMEM_preliminaryRes_r_i	<=	PREMEM_preliminaryRes_i;
			PREMEM_nonBlockMark_r_i	<=	PREMEM_nonBlockMark_i;
			PREMEM_rtData_r_i	<=	PREMEM_rtData_i;
			PREMEM_ExcCode_r_i	<=	PREMEM_ExcCode_i;
			PREMEM_hasException_r_i	<=	PREMEM_hasException_i;
			PREMEM_exceptBadVAddr_r_i	<=	PREMEM_exceptBadVAddr_i;
			PREMEM_eret_r_i	<=	PREMEM_eret_i;
			PREMEM_isRefill_r_i	<=	PREMEM_isRefill_i;
			PREMEM_exceptionRisk_r_i	<=	PREMEM_exceptionRisk_i;
			PREMEM_positionCp0_r_i	<=	PREMEM_positionCp0_i;
			PREMEM_readCp0_r_i	<=	PREMEM_readCp0_i;
			PREMEM_writeCp0_r_i	<=	PREMEM_writeCp0_i;
			PREMEM_isCacheInst_r_i	<=	PREMEM_isCacheInst_i;
			PREMEM_CacheOperator_r_i	<=	PREMEM_CacheOperator_i;
			PREMEM_CacheAddress_r_i	<=	PREMEM_CacheAddress_i;
        end
    end
    /*}}}*/
    // 线信号处理{{{
    // 流水线互锁
    reg hasData;
    wire ready = !PREMEM_memReq_r_i || data_data_ok;
    // 上下控制
    assign MEM_allowin_w_o = REEXE_okToChange_w_i && (ready||!hasData) && WB_allowin_w_i;
    // 上下不同部分
    wire needFlush = CP0_exceptSeg_w_i[`EXCEP_MEM] && CP0_excOccur_w_i ;
    assign MEM_valid_w_o =  hasData && 
                            ready && 
                            MEM_allowin_w_o &&
                            !needFlush;
    assign needUpdata = MEM_allowin_w_o && PREMEM_valid_w_i;
    assign needClear  = (!PREMEM_valid_w_i&&MEM_allowin_w_o) || needFlush;
    always @(posedge clk) begin
        if(!rst || needClear) begin
            hasData <=  1'b0;
        end
        else if (MEM_allowin_w_o)
            hasData <=  PREMEM_valid_w_i;
    end
    assign MEM_writeNum_w_o = PREMEM_writeNum_r_i;
    assign MEM_hasDangerous_w_o = PREMEM_isDangerous_r_i;
    assign MEM_rtData_o = PREMEM_rtData_r_i;
    assign MEM_VAddr_o = PREMEM_VAddr_r_i;
    wire    cannotForward = PREMEM_memReq_r_i && (!PREMEM_loadSel_r_i[`LOAD_LW_BIT]);
    assign MEM_forwardMode_w_o = hasData && ready && !cannotForward;
    /*}}}*/
    // 简单线信号传递{{{
    assign MEM_writeNum_o = PREMEM_writeNum_r_i;
    assign MEM_loadSel_o  = PREMEM_loadSel_r_i;
    assign MEM_isDangerous_o = PREMEM_isDangerous_r_i;
    assign MEM_finalRes_o = PREMEM_readCp0_r_i ? CP0_readData_w_i : PREMEM_preliminaryRes_r_i;
    assign MEM_alignCheck_o = PREMEM_alignCheck_r_i;
    assign MEM_exceptionRisk_o = 1'b0;
    assign MEM_memReq_o = PREMEM_memReq_r_i;
    // }}}
    // 异常处理{{{
    // 中断生成
    wire has_int =  ((CP0_Cause_w_i[`IP7:`IP0] & CP0_Status_w_i[`IM7:`IM0])!=8'h00) && 
                    (CP0_Status_w_i[`EXL]==1'b0) && hasData;
    assign MEM_hasRisk_w_o  = PREMEM_exceptionRisk_r_i || WB_hasRisk_w_i || has_int;
    assign MEM_isInterrupt_w_o = has_int;
    assign MEM_ExcCode_w_o =    has_int ? `INT : 
                                PREMEM_hasException_r_i ? PREMEM_ExcCode_r_i : DMMU_ExcCode_i;
    assign MEM_hasException_w_o = data_hasException || PREMEM_hasException_r_i || has_int;
    assign MEM_exceptBadVAddr_w_o = PREMEM_hasException_r_i ? PREMEM_exceptBadVAddr_r_i : PREMEM_exceptBadVAddr_r_i;
    assign MEM_isDelaySlot_w_o = PREMEM_isDelaySlot_r_i;
    assign MEM_exceptPC_w_o = PREMEM_VAddr_r_i;
    assign MEM_positionCp0_w_o = PREMEM_positionCp0_r_i;
    assign MEM_writeCp0_w_o = PREMEM_writeCp0_r_i;
    assign MEM_eret_w_o = PREMEM_eret_r_i;
    assign MEM_writeData_w_o = PREMEM_preliminaryRes_r_i;
    assign MEM_isRefill_w_o = DMMU_tlbRefill_i || PREMEM_isRefill_r_i;
    assign MEM_nonBlockMark_w_o = PREMEM_nonBlockMark_r_i;
    // }}}
    // Cache指令op{{{
    /* wire   isDcache     = PREMEM_CacheOperator_r_i[1:0]==2'b01; */
    /* wire   isIcache     = PREMEM_CacheOperator_r_i[1:0]==2'b00; */
    /* assign dcache_req   = PREMEM_isCacheInst_i && isDcache && !MEM_hasException_w_o; */
    /* assign icache_req   = PREMEM_isCacheInst_i && isIcache && !MEM_hasException_w_o; */
    /* assign dcache_op    = PREMEM_CacheOperator_r_i; */
    /* assign icache_op    = PREMEM_CacheOperator_r_i; */
    /* assign dcache_tag   = 'd0; */
    /* assign dcache_valid = 'd0; */
    /* assign dcache_dirty = 'd0; */
    /* assign dcache_addr  = PREMEM_preliminaryRes_r_i; */
    /* assign icache_tag   = 'd0; */
    /* assign icache_valid = 'd0; */
    /* assign icache_addr  = PREMEM_preliminaryRes_r_i; */
    /* // }}} */
endmodule

