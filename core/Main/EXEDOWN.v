// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/02 09:01
// Last Modified : 2022/07/31 16:34
// File Name     : EXEDOWN.v
// Description   : 下段执行段，需要进行算数，位移，异常，乘除，TLB，cache指令
//                  的操作等
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/07/02   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "MyDefines.v"
module EXEDOWN(
    input	wire	                        clk,
    input	wire	                        rst,
    /////////////////////////////////////////////////
    //////////////  线信号输入    ///////////////////{{{
    /////////////////////////////////////////////////
    // 前后流水线互锁 
    input	wire	                        ID_down_valid_w_i,
    input	wire	                        PREMEM_allowin_w_i,
    // 上下流水线互锁
    input	wire	                        EXE_up_okToChange_w_i,        // allowin共用一个，代表上下两端都可进
    // 异常互锁
    input	wire	                        PREMEM_hasRisk_w_i,
    // 非阻塞乘除
    input	wire	                        CP0_nonBlockMark_w_i,
    input	wire	                        SBA_nonBlockDS_w_i,
    input	wire	                        SBA_branchRisk_w_i,
    // 流水线刷新
    input	wire	                        SBA_flush_w_i,
    input	wire	                        CP0_excOccur_w_i,
    input	wire	[`EXCEP_SEG]            CP0_exceptSeg_w_i,
    input	wire	[`SINGLE_WORD]          WB_forwardData_w_i,
/*}}}*/
    /////////////////////////////////////////////////
    //////////////    线信号的输出    ///////////////{{{
    /////////////////////////////////////////////////
    // ID指令阶段控制
    output	wire	                        EXE_down_forwardMode_w_o,    
    output	wire	[`GPR_NUM]              EXE_down_writeNum_w_o,    
    // 流水线控制
    output	wire	                        EXE_down_valid_w_o,     // 该周期数据是否有效，后段决定是否采样
    output  wire                            EXE_down_allowin_w_o,   // 下周起该段是否可以更新
    //危险暂停信号
    output	wire	                        EXE_down_hasDangerous_w_o,  // mul,clo,clz,madd,msub,cache,tlb等危险指令
	output   wire    [0:0]			        EXE_down_hasExceprion_w_o,
	output   wire    [`EXCCODE]			    EXE_down_ExcCode_w_o,
    output	wire	                        EXE_down_isDelaySlot_w_o,
    output	wire	[`SINGLE_WORD]          EXE_down_exceptPC_w_o,
    output	wire	[`SINGLE_WORD]          EXE_down_exceptBadVAddr_w_o,
    output	wire	                        EXE_down_nonBlockMark_w_o,
    output	wire	                        EXE_down_eret_w_o,
    output	wire	                        EXE_down_isRefill_w_o,       // 不同异常地址
    output	wire	                        EXE_down_isInterrupt_w_o,    // 不同异常地址
    //最后一段不需要传递给其他段
    //output	wire	                        EXE_down_hasRisk_w_o,     //
/*}}}*/
   ////////////////////////////////////////////////
    //////////////    寄存器输入      //////////////{{{
    ////////////////////////////////////////////////
    // 基本状态信息{{{
    input	wire	[`GPR_NUM]              ID_down_writeNum_i,         // 回写寄存器数值,0为不回写
    input	wire	[2*`SINGLE_WORD]        ID_down_readData_i,         // 寄存器值rsrt
    input	wire	                        ID_down_isDelaySlot_i,      // 表示该指令是否是延迟槽指令
    input	wire	                        ID_down_isDangerous_i,      // 表示该指令在执行期间不得执行其他指令
    input	wire	[`SINGLE_WORD]          ID_down_VAddr_i,            // 用于debug和异常处理}}}
    //算数,位移{{{
    input	wire	[`SINGLE_WORD]          ID_down_oprand0_i,          // 经过多路选择器,选择WB前递数据或立即数或SA的第一个操作数
    input	wire	                        ID_down_oprand0IsReg_i,     
    input	wire	                        ID_down_oprand1IsReg_i,     
    input	wire	[`FORWARD_MODE]         ID_down_forwardSel0_i,      // 用于选择前递信号
    input	wire	                        ID_down_data0Ready_i,       // 表示该operand是否可用
    input	wire	[`SINGLE_WORD]          ID_down_oprand1_i,       // 经过多路选择器,选择WB前递数据或立即数或SA的第一个操作数
    input	wire	[`FORWARD_MODE]         ID_down_forwardSel1_i,      // 用于选择前递信号
    input	wire	                        ID_down_data1Ready_i,       // 表示该operand是否可用
    input	wire	[`ALUOP]                ID_down_aluOprator_i,       //}}}
    // 乘除指令类信息{{{
    input	wire	[`MDUOP]                ID_down_mduOperator_i,      // 包括乘除,累加累减,立即数乘法
    input	wire	[`HILO]                 ID_down_readHiLo_i,         // 只有指令需要将HiLo写入GPR,该信号才会拉高,mfhilo 
    input	wire	[`HILO]                 ID_down_writeHiLo_i,        // 需要根据数值写HiLo的指令,有madd,/sub,mult,div,mtc0,其中mtc0是类似与add做运算,之后将运算结果写入}}}
    // 异常处理类信息{{{
    input	wire    [`EXCCODE]              ID_down_ExcCode_i,          // 异常信号	
    input	wire	[`EXCEPRION_SEL]        ID_down_exceptionSel_i,     // 选择ALU的overflow和trap
    input	wire	                        ID_down_hasException_i,     // 存在异常
    input	wire	                        ID_down_eret_i,
    input	wire	                        ID_down_isRefill_i,
    input	wire                            ID_down_exceptionRisk_i,    // 存在异常的风险
    input	wire	                        ID_up_branchRisk_i,
    input	wire	[`CP0_POSITION]         ID_down_positionCp0_i,      // {rd,sel}
    input	wire	                        ID_down_readCp0_i,          // 只有指令需要将cp0写入GPR,该信号才会拉高,mfc0
    input	wire	                        ID_down_writeCp0_i,         // 只有指令需要将GPR写入cp0,该信号才会拉高,mtc0
    input	wire	[`TRAP_KIND]            ID_down_trapKind_i,         // 自陷指令的种类}}}
    // 访存类信息{{{
    input	wire	                        ID_down_memReq_i,           // 表示访存请求
    input	wire	                        ID_down_memWR_i,            // 表示访存类型
    input	wire	                        ID_down_memAtom_i,          // 表示该访存操作是原子访存操作,需要读写LLbit
    input	wire    [`LOAD_MODE]            ID_down_loadMode_i,         // load模式	
    input	wire    [`STORE_MODE]           ID_down_storeMode_i,        // store模式	}}}
    // TLB和Cache{{{
    input	wire	                        ID_down_isTLBInst_i,        // 表示是TLB指令
    input	wire	[`TLB_INST]             ID_down_TLBInstOperator_i,  // 执行的种类
    // Cache指令
    input	wire	                        ID_down_isCacheInst_i,      // 表示是Cache指令
    input	wire	[`CACHE_OP]             ID_down_CacheOperator_i,    // Cache指令op}}}
    // 运算数据前递{{{
    input	wire	[`SINGLE_WORD]          EXE_up_aluRes_i,
    input	wire	[`SINGLE_WORD]          EXE_down_aluRes_i,
    input	wire	[`SINGLE_WORD]          SBA_aluRes_i,
    input	wire	[`SINGLE_WORD]          REEXE_regData_i,
    input	wire	[`SINGLE_WORD]          PREMEM_preliminaryRes_i,
    input	wire	[`SINGLE_WORD]          MEM_finalRes_i,
    // }}}
/*}}}*/
    /////////////////////////////////////////////////
    //////////////      寄存器输出     //////////////{{{
    /////////////////////////////////////////////////
    // 基本状态信息 {{{
    output	wire	[`GPR_NUM]              EXE_down_writeNum_o,        // 回写寄存器数值,0为不回写
    output	wire	                        EXE_down_isDelaySlot_o,     // 表示该指令是否是延迟槽指令,用于异常处理
    output	wire	                        EXE_down_isDangerous_o,     // 表示该指令是否是延迟槽指令,用于异常处理
    output	wire	[`SINGLE_WORD]          EXE_down_VAddr_o,           // 用于debug和异常处理}}}
    //算数,位移 乘除处理输出{{{
    output	wire    [`SINGLE_WORD]          EXE_down_aluRes_o,
    output	wire	[`SINGLE_WORD]          EXE_down_mduRes_o,          // mfhilo的运算处理结果
    output	wire	[4:0]                   EXE_down_clRes_o,           // clo的计算结果
    output	wire	[`SINGLE_WORD]          EXE_down_mulRes_o,          // 专门用于Mul的接口
    output	wire	[`MATH_SEL]             EXE_down_mathResSel_o,      // 数学运算结果的选择
    output	wire	                        EXE_down_nonBlockDS_o,        // 该条指令执行在MDU运算期间, 包括MDU指令
    output	wire	                        EXE_down_nonBlockMark_o,    // 该条指令执行在MDU运算期间, 不包括MDU指令}}}
    // 异常处理类信息{{{
    output	wire    [`EXCCODE]              EXE_down_ExcCode_o,         // 异常信号
    output	wire	                        EXE_down_hasException_o,    // 存在异常
    output	wire                            EXE_down_exceptionRisk_o,   // 存在异常的风险
    output	wire	[`SINGLE_WORD]          EXE_down_exceptBadVAddr_o,
    output	wire	                        EXE_down_eret_o,
    output	wire	                        EXE_down_isRefill_o,
    output	wire	[`CP0_POSITION]         EXE_down_positionCp0_o,     // {rd,sel}
    output	wire	                        EXE_down_readCp0_o,         // mfc0,才会拉高
    output	wire	                        EXE_down_writeCp0_o,        // mtc0,才会拉高
    /*}}}*/
    //访存信号{{{
    output	wire	                        EXE_down_memReq_o,          // 表示访存需要              
    output	wire	                        EXE_down_memWR_o,           // 表示访存类型
    output	wire	[3:0]                   EXE_down_memEnable_o,       // 表示字节读写使能,0000表示全不写
    output	wire	                        EXE_down_memAtom_o,         // 表示该访存操作是原子访存操作,需要读写LLbit
    output	wire	[`SINGLE_WORD]          EXE_down_storeData_o,
    output	wire    [`LOAD_SEL]             EXE_down_loadSel_o,         // load指令模式		}}}
    // TLB指令,最危险指令，需要等待后面的流水线排空才能发射{{{
    output	wire	                        EXE_down_isTLBInst_o,       // 表示是TLB指令
    output	wire	[`TLB_INST]             EXE_down_TLBInstOperator_o, // 执行的种类
    // Cache指令,在该段中，cache地址由aluRes给出
    output	wire	                        EXE_down_isCacheInst_o,     // 表示是Cache指令
    output	wire	[`CACHE_OP]             EXE_down_CacheOperator_o    // Cache指令op
    /*}}}*/
    /*}}}*/
);
    // 自动定义 {{{
    /*autodef*/
    //Start of automatic define 
    //Start of automatic reg
    //Define flip-flop registers here
    //Define combination registers here
    //End of automatic reg
    //Start of automatic wire
    //Define assign wires here
    //Define instance wires here
    wire [`ALUOP]               aluop                           ;// unresolved
    wire                        overflow                        ;
    wire [`SINGLE_WORD]         aluso                           ;
    wire                        MduReq                          ; // WIRE_NEW// unresolved
    wire [2*`SINGLE_WORD]       MDU_oprand                      ;// unresolved
    wire [2*`SINGLE_WORD]       MDU_HiLoData                    ;// unresolved
    wire [`MDU_REQ]             MDU_operator                    ;// unresolved
    wire [2*`SINGLE_WORD]       MDU_writeData_p                 ;
    wire                        mulrReq                         ;// unresolved
    wire                        mulr_data_ok                    ;
    //End of automatic wire
    //End of automatic define
    wire [`SINGLE_WORD]         scr         [1:0]               ;
    wire                        cancel                          ;// 表示是否应当被取消
    /*}}}*/
    //Intersegment_register{{{

    wire            needClear;
    wire            needUpdata;

	reg	[`GPR_NUM]			ID_down_writeNum_r_i;
	reg	[2*`SINGLE_WORD]			ID_down_readData_r_i;
	reg	[0:0]			ID_down_isDelaySlot_r_i;
	reg	[0:0]			ID_down_isDangerous_r_i;
	reg	[`SINGLE_WORD]			ID_down_VAddr_r_i;
	reg	[`SINGLE_WORD]			ID_down_oprand0_r_i;
	reg	[0:0]			ID_down_oprand0IsReg_r_i;
	reg	[0:0]			ID_down_oprand1IsReg_r_i;
	reg	[`FORWARD_MODE]			ID_down_forwardSel0_r_i;
	reg	[0:0]			ID_down_data0Ready_r_i;
	reg	[`SINGLE_WORD]			ID_down_oprand1_r_i;
	reg	[`FORWARD_MODE]			ID_down_forwardSel1_r_i;
	reg	[0:0]			ID_down_data1Ready_r_i;
	reg	[`ALUOP]			ID_down_aluOprator_r_i;
	reg	[`MDUOP]			ID_down_mduOperator_r_i;
	reg	[`HILO]			ID_down_readHiLo_r_i;
	reg	[`HILO]			ID_down_writeHiLo_r_i;
	reg	[`EXCCODE]			ID_down_ExcCode_r_i;
	reg	[`EXCEPRION_SEL]			ID_down_exceptionSel_r_i;
	reg	[0:0]			ID_down_hasException_r_i;
	reg	[0:0]			ID_down_eret_r_i;
	reg	[0:0]			ID_down_isRefill_r_i;
	reg	[0:0]			ID_down_exceptionRisk_r_i;
	reg	[0:0]			ID_up_branchRisk_r_i;
	reg	[`CP0_POSITION]			ID_down_positionCp0_r_i;
	reg	[0:0]			ID_down_readCp0_r_i;
	reg	[0:0]			ID_down_writeCp0_r_i;
	reg	[`TRAP_KIND]			ID_down_trapKind_r_i;
	reg	[0:0]			ID_down_memReq_r_i;
	reg	[0:0]			ID_down_memWR_r_i;
	reg	[0:0]			ID_down_memAtom_r_i;
	reg	[`LOAD_MODE]			ID_down_loadMode_r_i;
	reg	[`STORE_MODE]			ID_down_storeMode_r_i;
	reg	[0:0]			ID_down_isTLBInst_r_i;
	reg	[`TLB_INST]			ID_down_TLBInstOperator_r_i;
	reg	[0:0]			ID_down_isCacheInst_r_i;
	reg	[`CACHE_OP]			ID_down_CacheOperator_r_i;
	reg	[`SINGLE_WORD]			EXE_up_aluRes_r_i;
	reg	[`SINGLE_WORD]			EXE_down_aluRes_r_i;
	reg	[`SINGLE_WORD]			SBA_aluRes_r_i;
	reg	[`SINGLE_WORD]			REEXE_regData_r_i;
	reg	[`SINGLE_WORD]			PREMEM_preliminaryRes_r_i;
	reg	[`SINGLE_WORD]			MEM_finalRes_r_i;
    always @(posedge clk) begin
        if (!rst || needClear) begin
			ID_down_writeNum_r_i	<=	'b0;
			ID_down_readData_r_i	<=	'b0;
			ID_down_isDelaySlot_r_i	<=	'b0;
			ID_down_isDangerous_r_i	<=	'b0;
			ID_down_VAddr_r_i	<=	'b0;
			ID_down_oprand0_r_i	<=	'b0;
			ID_down_oprand0IsReg_r_i	<=	'b0;
			ID_down_oprand1IsReg_r_i	<=	'b0;
			ID_down_forwardSel0_r_i	<=	'b0;
			ID_down_data0Ready_r_i	<=	'b0;
			ID_down_oprand1_r_i	<=	'b0;
			ID_down_forwardSel1_r_i	<=	'b0;
			ID_down_data1Ready_r_i	<=	'b0;
			ID_down_aluOprator_r_i	<=	'b0;
			ID_down_mduOperator_r_i	<=	'b0;
			ID_down_readHiLo_r_i	<=	'b0;
			ID_down_writeHiLo_r_i	<=	'b0;
			ID_down_ExcCode_r_i	<=	'b0;
			ID_down_exceptionSel_r_i	<=	'b0;
			ID_down_hasException_r_i	<=	'b0;
			ID_down_eret_r_i	<=	'b0;
			ID_down_isRefill_r_i	<=	'b0;
			ID_down_exceptionRisk_r_i	<=	'b0;
			ID_up_branchRisk_r_i	<=	'b0;
			ID_down_positionCp0_r_i	<=	'b0;
			ID_down_readCp0_r_i	<=	'b0;
			ID_down_writeCp0_r_i	<=	'b0;
			ID_down_trapKind_r_i	<=	'b0;
			ID_down_memReq_r_i	<=	'b0;
			ID_down_memWR_r_i	<=	'b0;
			ID_down_memAtom_r_i	<=	'b0;
			ID_down_loadMode_r_i	<=	'b0;
			ID_down_storeMode_r_i	<=	'b0;
			ID_down_isTLBInst_r_i	<=	'b0;
			ID_down_TLBInstOperator_r_i	<=	'b0;
			ID_down_isCacheInst_r_i	<=	'b0;
			ID_down_CacheOperator_r_i	<=	'b0;
			EXE_up_aluRes_r_i	<=	'b0;
			EXE_down_aluRes_r_i	<=	'b0;
			SBA_aluRes_r_i	<=	'b0;
			REEXE_regData_r_i	<=	'b0;
			PREMEM_preliminaryRes_r_i	<=	'b0;
			MEM_finalRes_r_i	<=	'b0;
        end
        else if (needUpdata) begin
			ID_down_writeNum_r_i	<=	ID_down_writeNum_i;
			ID_down_readData_r_i	<=	ID_down_readData_i;
			ID_down_isDelaySlot_r_i	<=	ID_down_isDelaySlot_i;
			ID_down_isDangerous_r_i	<=	ID_down_isDangerous_i;
			ID_down_VAddr_r_i	<=	ID_down_VAddr_i;
			ID_down_oprand0_r_i	<=	ID_down_oprand0_i;
			ID_down_oprand0IsReg_r_i	<=	ID_down_oprand0IsReg_i;
			ID_down_oprand1IsReg_r_i	<=	ID_down_oprand1IsReg_i;
			ID_down_forwardSel0_r_i	<=	ID_down_forwardSel0_i;
			ID_down_data0Ready_r_i	<=	ID_down_data0Ready_i;
			ID_down_oprand1_r_i	<=	ID_down_oprand1_i;
			ID_down_forwardSel1_r_i	<=	ID_down_forwardSel1_i;
			ID_down_data1Ready_r_i	<=	ID_down_data1Ready_i;
			ID_down_aluOprator_r_i	<=	ID_down_aluOprator_i;
			ID_down_mduOperator_r_i	<=	ID_down_mduOperator_i;
			ID_down_readHiLo_r_i	<=	ID_down_readHiLo_i;
			ID_down_writeHiLo_r_i	<=	ID_down_writeHiLo_i;
			ID_down_ExcCode_r_i	<=	ID_down_ExcCode_i;
			ID_down_exceptionSel_r_i	<=	ID_down_exceptionSel_i;
			ID_down_hasException_r_i	<=	ID_down_hasException_i;
			ID_down_eret_r_i	<=	ID_down_eret_i;
			ID_down_isRefill_r_i	<=	ID_down_isRefill_i;
			ID_down_exceptionRisk_r_i	<=	ID_down_exceptionRisk_i;
			ID_up_branchRisk_r_i	<=	ID_up_branchRisk_i;
			ID_down_positionCp0_r_i	<=	ID_down_positionCp0_i;
			ID_down_readCp0_r_i	<=	ID_down_readCp0_i;
			ID_down_writeCp0_r_i	<=	ID_down_writeCp0_i;
			ID_down_trapKind_r_i	<=	ID_down_trapKind_i;
			ID_down_memReq_r_i	<=	ID_down_memReq_i;
			ID_down_memWR_r_i	<=	ID_down_memWR_i;
			ID_down_memAtom_r_i	<=	ID_down_memAtom_i;
			ID_down_loadMode_r_i	<=	ID_down_loadMode_i;
			ID_down_storeMode_r_i	<=	ID_down_storeMode_i;
			ID_down_isTLBInst_r_i	<=	ID_down_isTLBInst_i;
			ID_down_TLBInstOperator_r_i	<=	ID_down_TLBInstOperator_i;
			ID_down_isCacheInst_r_i	<=	ID_down_isCacheInst_i;
			ID_down_CacheOperator_r_i	<=	ID_down_CacheOperator_i;
			EXE_up_aluRes_r_i	<=	EXE_up_aluRes_i;
			EXE_down_aluRes_r_i	<=	EXE_down_aluRes_i;
			SBA_aluRes_r_i	<=	SBA_aluRes_i;
			REEXE_regData_r_i	<=	REEXE_regData_i;
			PREMEM_preliminaryRes_r_i	<=	PREMEM_preliminaryRes_i;
			MEM_finalRes_r_i	<=	MEM_finalRes_i;
        end
    end
    /*}}}*/
//  线信号处理{{{
    // 流水线互锁
    reg hasData;
    wire ready;
    assign EXE_down_allowin_w_o = EXE_up_okToChange_w_i && (ready||!hasData) && PREMEM_allowin_w_i;
    // 上下不同部分
    wire needFlush = CP0_excOccur_w_i || SBA_flush_w_i;
    assign EXE_down_valid_w_o = hasData && 
                                ready && 
                                EXE_down_allowin_w_o &&
                                !CP0_excOccur_w_i;
    assign needUpdata = EXE_down_allowin_w_o && ID_down_valid_w_i;
    assign needClear  = (!ID_down_valid_w_i&&EXE_down_allowin_w_o) || needFlush;
    always @(posedge clk) begin
        if(!rst || needClear) begin
            hasData <=  1'b0;
        end
        else if (EXE_down_allowin_w_o)
            hasData <=  ID_down_valid_w_i;
    end
    wire EXE_down_hasRisk_w_o  =    ID_down_exceptionRisk_r_i || 
                                    ID_up_branchRisk_r_i || 
                                    PREMEM_hasRisk_w_i;

    assign EXE_down_writeNum_w_o = ID_down_writeNum_r_i;
    wire    isAluInst = !ID_down_memReq_r_i &&
                        !ID_down_mduOperator_r_i[`MDU_CLO] &&
                        !ID_down_mduOperator_r_i[`MDU_CLZ] &&
                        !(|ID_down_readCp0_r_i) && 
                        !(|ID_down_readHiLo_r_i);
    assign EXE_down_hasDangerous_w_o = ID_down_isDangerous_r_i;
    assign EXE_down_forwardMode_w_o  = hasData && ready && !ID_down_memReq_r_i && isAluInst;
/*}}}*/
    ALU ALU_u(/*{{{*/
      /*autoinst*/
        .scr0                   (scr[0]                         ), //input
        .scr1                   (scr[1]                         ), //input
        .aluop                  (aluop[`ALUOP]                  ), //input
        .overflow               (overflow                       ), //output
        .aluso                  (aluso[`SINGLE_WORD]            )  //output
    );
    assign aluop = ID_down_aluOprator_r_i;
    /*}}}*/
    // 前递选择 {{{
    wire	    [`SINGLE_WORD]          ID_down_oprand_up     [1:0];            
    wire	    [`FORWARD_MODE]         ID_down_forwardSel_up [1:0];        // 用于选择前递信号
    wire	                            ID_down_dataReady_up  [1:0];        // 表示该operand是否可用
    assign ID_down_oprand_up[0] = ID_down_oprand0_r_i;
    assign ID_down_oprand_up[1] = ID_down_oprand1_r_i;
    assign ID_down_forwardSel_up[0] = ID_down_forwardSel0_r_i;
    assign ID_down_forwardSel_up[1] = ID_down_forwardSel1_r_i;
    wire        [`SINGLE_WORD]      readData_up     [1:0];
    `UNPACK_ARRAY(`SINGLE_WORD_LEN,2,readData_up,ID_down_readData_r_i)
    wire        [`SINGLE_WORD]      updataRegFile_up[1:0];
    wire        [0:0]               srcIsReg        [1:0];
    assign srcIsReg[0] = ID_down_oprand0IsReg_r_i;
    assign srcIsReg[1] = ID_down_oprand1IsReg_r_i;
    generate   
        for (genvar i = 0; i < 2; i=i+1)	begin     
            // WB段数据再保存{{{
            reg [`SINGLE_WORD]  wb_savedData;
            reg                 useSavedWb;
            always @(posedge clk) begin
                if (!rst || needClear || needUpdata) begin
                    useSavedWb      <=  `FALSE;
                end
                else if (ID_down_forwardSel_up[i][`FORWARD_MEM_BIT]) begin
                    useSavedWb      <=  `TRUE;
                end
                if (!rst || needClear || needUpdata) begin
                    wb_savedData    <=  `ZEROWORD;
                end
                else if (ID_down_forwardSel_up[i][`FORWARD_MEM_BIT] && !useSavedWb) begin
                    wb_savedData    <=  WB_forwardData_w_i;
                end
            end
            wire [`SINGLE_WORD] wb_data = useSavedWb ? wb_savedData : WB_forwardData_w_i;
            // }}}
            assign updataRegFile_up[i] = ({32{ID_down_forwardSel_up[i][`FORWARD_ID_BIT]}}&readData_up[i])|
            ({32{ID_down_forwardSel_up[i][`FORWARD_SBA_BIT]}}& SBA_aluRes_r_i)|
            ({32{ID_down_forwardSel_up[i][`FORWARD_PREMEM_BIT]}}& PREMEM_preliminaryRes_r_i)|
            ({32{ID_down_forwardSel_up[i][`FORWARD_REEXE_BIT]}}& REEXE_regData_r_i)|
            ({32{ID_down_forwardSel_up[i][`FORWARD_MEM_BIT]}}& wb_data)|
            ({32{ID_down_forwardSel_up[i][`FORWARD_EXE_UP_BIT]}}& EXE_up_aluRes_r_i)|
            ({32{ID_down_forwardSel_up[i][`FORWARD_EXE_DOWN_BIT] }}& EXE_down_aluRes_r_i);
            assign scr[i] = !srcIsReg[i] ? ID_down_oprand_up[i] : updataRegFile_up[i];
        end
    endgenerate
/*}}}*/
    // 访存处理{{{
    wire [1:0]  alignCheck = updataRegFile_up[0][1:0] + ID_down_oprand1_r_i[1:0];
    wire [3:0]  ByteEnable =    alignCheck==2'b00 ? 4'b0001 :
                                alignCheck==2'b01 ? 4'b0010 :
                                alignCheck==2'b10 ? 4'b0100 : 4'b1000 ;
    wire [3:0]  HalfEnable =    alignCheck==2'b00 ? 4'b0011 :
                                alignCheck==2'b10 ? 4'b1100 : 4'b0000 ;
    wire [3:0]  WordLeftEnable =    alignCheck==2'b00 ? 4'b0001 :
                                    alignCheck==2'b01 ? 4'b0011 :
                                    alignCheck==2'b10 ? 4'b0111 : 4'b1111 ;
    wire [3:0]  WordRightEnable =   alignCheck==2'b00 ? 4'b1111 :
                                    alignCheck==2'b01 ? 4'b1110 :
                                    alignCheck==2'b10 ? 4'b1100 : 4'b1000 ;
    wire isByte   = ID_down_loadMode_r_i[`LOAD_MODE_LB]  || 
                    ID_down_loadMode_r_i[`LOAD_MODE_LBU] || 
                    ID_down_storeMode_r_i[`STORE_MODE_SB];
    wire isHalf   = ID_down_loadMode_r_i[`LOAD_MODE_LH]  || 
                    ID_down_loadMode_r_i[`LOAD_MODE_LHU] || 
                    ID_down_storeMode_r_i[`STORE_MODE_SH];
    wire isLeft   = ID_down_loadMode_r_i[`LOAD_MODE_LWL] ||
                    ID_down_storeMode_r_i[`STORE_MODE_SWL];
    wire isRight  = ID_down_loadMode_r_i[`LOAD_MODE_LWR] ||
                    ID_down_storeMode_r_i[`STORE_MODE_SWR];
    assign EXE_down_memEnable_o   = isByte  ? ByteEnable :
                                    isHalf  ? HalfEnable :
                                    isLeft  ? WordRightEnable :
                                    isRight ? WordLeftEnable  : 4'b1111;
    wire [`LOAD_SEL] lwl_sel =  alignCheck==2'b00 ? `LOAD_SEL_L0 :
                                alignCheck==2'b01 ? `LOAD_SEL_L1 : 
                                alignCheck==2'b10 ? `LOAD_SEL_R2 : `LOAD_SEL_LW;
    wire [`LOAD_SEL] lwr_sel =  alignCheck==2'b00 ? `LOAD_SEL_LW :
                                alignCheck==2'b01 ? `LOAD_SEL_R1 : 
                                alignCheck==2'b10 ? `LOAD_SEL_R2 : `LOAD_SEL_R3;
    assign EXE_down_loadSel_o = ID_down_loadMode_r_i[`LOAD_MODE_LB ] ? `LOAD_SEL_LB :
                                ID_down_loadMode_r_i[`LOAD_MODE_LBU] ? `LOAD_SEL_LBU:
                                ID_down_loadMode_r_i[`LOAD_MODE_LH ] ? `LOAD_SEL_LH :
                                ID_down_loadMode_r_i[`LOAD_MODE_LHU] ? `LOAD_SEL_LHU:
                                ID_down_loadMode_r_i[`LOAD_MODE_LW ] ? `LOAD_SEL_LW :
                                ID_down_loadMode_r_i[`LOAD_MODE_LWL] ? lwl_sel : lwr_sel;
    wire [`SINGLE_WORD] sb_data = {4{updataRegFile_up[1][7:0]}};
    wire [`SINGLE_WORD] sh_data = {2{updataRegFile_up[1][15:0]}};
    wire [`SINGLE_WORD] combination [2:0];
    assign combination[0] = {updataRegFile_up[1][23:0],updataRegFile_up[1][31:24]};
    assign combination[1] = {updataRegFile_up[1][15:0],updataRegFile_up[1][31:16]};
    assign combination[2] = {updataRegFile_up[1][7:0],updataRegFile_up[1][31:8]};
    wire [`SINGLE_WORD] swl_data =  ({32{alignCheck==2'b00}} & combination[0]) |
                                    ({32{alignCheck==2'b01}} & combination[1]) |
                                    ({32{alignCheck==2'b10}} & combination[2]) |
                                    ({32{alignCheck==2'b10}} & updataRegFile_up[1]) ;
    wire [`SINGLE_WORD] swr_data =  ({32{alignCheck==2'b00}} & updataRegFile_up[1]) |
                                    ({32{alignCheck==2'b01}} & combination[2]) |
                                    ({32{alignCheck==2'b10}} & combination[1]) |
                                    ({32{alignCheck==2'b10}} & combination[0]) ;
    assign EXE_down_storeData_o =   ({32{ID_down_storeMode_r_i[`STORE_MODE_SB]}} & sb_data) |
                                    ({32{ID_down_storeMode_r_i[`STORE_MODE_SH]}} & sh_data) |
                                    ({32{ID_down_storeMode_r_i[`STORE_MODE_SW]}} & updataRegFile_up[1]) |
                                    ({32{ID_down_storeMode_r_i[`STORE_MODE_SWL]}} & swl_data) |
                                    ({32{ID_down_storeMode_r_i[`STORE_MODE_SWR]}} & swr_data) ;
    /*}}}*/
    // ALU 异常处理{{{
    wire storeException = ((ID_down_storeMode_r_i[`STORE_MODE_SH] && alignCheck[0]!=1'b0) ||
                          (ID_down_storeMode_r_i[`STORE_MODE_SW] && (alignCheck[1:0]!=2'b00))) && ID_down_memReq_r_i;
    wire loadException  = (((ID_down_loadMode_r_i[`LOAD_MODE_LH]||ID_down_loadMode_r_i[`LOAD_MODE_LHU]) && alignCheck[0]!=1'b0) || 
                          ((ID_down_loadMode_r_i[`LOAD_MODE_LW]) && alignCheck[1:0]!=2'b00)) && ID_down_memReq_r_i;
    wire tlbRisk = (aluso[31:29]!=3'b101) && (aluso[31:29]!=3'b100) && ID_down_memReq_r_i;
    wire equals = !(|aluso);
    wire hasTrap =  ID_down_trapKind_r_i[`TRAP_EQUAL]      ? equals    :
                    ID_down_trapKind_r_i[`TRAP_LT_LTU]     ? aluso[0]  :
                    ID_down_trapKind_r_i[`TRAP_GE_GEU]     ? !aluso[0] : !equals;
    assign EXE_down_hasException_o =  ( ID_down_exceptionSel_r_i[`EXCEPRION_OV] ? overflow : 
                                        ID_down_exceptionSel_r_i[`EXCEPRION_TR] ? hasTrap  :  
                                        ID_down_memWR_r_i ? storeException :
                                        !ID_down_memWR_r_i ? loadException : 1'b0) || ID_down_hasException_r_i;
    assign EXE_down_aluRes_o = aluso;
    assign EXE_down_writeNum_o = ID_down_writeNum_r_i;
    assign EXE_down_ExcCode_o = ID_down_ExcCode_r_i;
    // 该信号用于下一段前递，表示这周期的运算结果是否有风险，可以慢
    assign EXE_down_exceptionRisk_o = EXE_down_hasException_o || tlbRisk || ID_down_writeCp0_r_i || ID_down_eret_r_i;
    assign EXE_down_VAddr_o = ID_down_VAddr_r_i;
    assign EXE_down_eret_o = ID_down_eret_r_i;
    assign EXE_down_exceptBadVAddr_o = ID_down_hasException_r_i ? ID_down_VAddr_r_i : aluso;
/*}}}*/
    // 简单的寄存器信号赋值 {{{
    assign EXE_down_isDelaySlot_o = ID_down_isDelaySlot_r_i;
    assign EXE_down_isDangerous_o = ID_down_isDangerous_r_i;
    assign EXE_down_positionCp0_o = ID_down_positionCp0_r_i;
    assign EXE_down_readCp0_o = ID_down_readCp0_r_i;
    assign EXE_down_writeCp0_o = ID_down_writeCp0_r_i;
    assign EXE_down_memReq_o = ID_down_memReq_r_i;
    assign EXE_down_memWR_o = ID_down_memWR_r_i;
    assign EXE_down_memAtom_o = ID_down_memAtom_r_i;
    assign EXE_down_isTLBInst_o = ID_down_isTLBInst_r_i;
    assign EXE_down_TLBInstOperator_o = ID_down_TLBInstOperator_r_i;
    assign EXE_down_isCacheInst_o = ID_down_isCacheInst_r_i;
    assign EXE_down_CacheOperator_o = ID_down_CacheOperator_r_i;
    assign EXE_down_isRefill_o  = ID_down_isRefill_r_i;
/*}}}*/
    // 乘除法指令的操作{{{
    // 信号声明和赋值{{{
    wire                 HiLo_busy;
    reg [`SINGLE_WORD]  regHiLo [1:0];
    // MDU模块的信号
    wire [1:0] MDU_writeEnable;
    wire                MDU_Oprand_ok;  //操作数ok
    wire                MDU_data_ok;    //计算结果ok
    wire [`SINGLE_WORD] MDU_writeData   [1:0];
    MultiDivideUnit MultiDivideUnit_u(/*{{{*/
        .clk                    (clk                                 ), //input
        .rst                    (rst                                 ), //input
        .MduReq                 (MduReq                              ), //input
        .cancel                 (cancel                              ), //input
        .MDU_oprand             (MDU_oprand[2*`SINGLE_WORD]          ), //input
        .MDU_HiLoData           (MDU_HiLoData[2*`SINGLE_WORD]        ), //input
        .MDU_operator           (MDU_operator[`MDU_REQ]              ), //input
        .MDU_Oprand_ok          (MDU_Oprand_ok                       ), //output
        .MDU_writeEnable        (MDU_writeEnable[`HILO]              ), //output
        .MDU_writeData_p        (MDU_writeData_p[2*`SINGLE_WORD]     ), //output
        .HiLo_busy              (HiLo_busy                           ),
        /*autoinst*/
        .mulrReq                (mulrReq                        ), //input // INST_NEW
        .mulr_data_ok           (mulr_data_ok                   ), //output // INST_NEW
        .MDU_data_ok            (MDU_data_ok                    )  //output
    );
/*}}}*/
    assign cancel = (CP0_excOccur_w_i && !CP0_nonBlockMark_w_i) || (SBA_flush_w_i && !SBA_nonBlockDS_w_i);
    assign MDU_operator[`MUL_REQ]   = ID_down_mduOperator_r_i[`MDU_MULT]||ID_down_mduOperator_r_i[`MDU_MULU];
    assign MDU_operator[`MUL_SIGN]  = ID_down_mduOperator_r_i[`MDU_MULT];
    assign MDU_operator[`DIV_REQ]   = ID_down_mduOperator_r_i[`MDU_DIV] ||ID_down_mduOperator_r_i[`MDU_DIVU];
    assign MDU_operator[`DIV_SIGN]  = ID_down_mduOperator_r_i[`MDU_DIV];
    assign MDU_operator[`ACCUM_REQ] = ID_down_mduOperator_r_i[`MDU_ADD] ||ID_down_mduOperator_r_i[`MDU_SUB];
    assign MDU_operator[`ACCUM_OP]  = ID_down_mduOperator_r_i[`MDU_ADD];
    assign MDU_operator[`MT_REQ]    = |ID_down_writeHiLo_r_i;
    assign MDU_operator[`MT_DEST]   =  ID_down_writeHiLo_r_i[`HI_WRITE];
    assign MDU_oprand = {updataRegFile_up[1],updataRegFile_up[0]};
    assign MDU_HiLoData = {regHiLo[1],regHiLo[0]} ;
    wire isMduWrite = |ID_down_mduOperator_r_i[6:0] || (|ID_down_writeHiLo_r_i);
    assign mulrReq = ID_down_mduOperator_r_i[`MDU_MULR];
    `UNPACK_ARRAY(`SINGLE_WORD_LEN,2,MDU_writeData,MDU_writeData_p)/*}}}*/
    // MDU和指令流水线之间的交互{{{
    reg                 isAccepted;     // 该指令是否被MDU接受
    // 乘除指令自身不会有异常风险
    assign MduReq = isMduWrite  &&
                    !isAccepted &&
                    !cancel     &&
                    !PREMEM_hasRisk_w_i &&
                    !SBA_branchRisk_w_i;
    always @(posedge clk) begin
        if (!rst || needClear || needUpdata) begin
            isAccepted  <=  `FALSE;
        end
        else if (hasData) begin
            isAccepted  <=  (MDU_Oprand_ok&&MduReq) || isAccepted;
        end
    end
    // 需要MDU运算但是MDU没有接受
    wire mduConflict = isMduWrite && !(isAccepted||MDU_Oprand_ok);
    // 不能在MDU中同时存在两个工作
    wire HiLoConflict = ((|ID_down_readHiLo_r_i)||(|isMduWrite))&&HiLo_busy;   
    // 需要写HiLo寄存器但是前面有风险,包括乘除
    wire writeHiLoConflict = isMduWrite && PREMEM_hasRisk_w_i;
/*}}}*/
    // HiLo寄存器{{{
    generate
        for (genvar i = 0; i < 2; i = i+1)	begin
            always @(posedge clk) begin
                if (!rst) begin
                `ifdef CONTINUE
                    $readmemh(`HILO_FILE, regHiLo);
                `else
                    regHiLo[i]  <=  `ZEROWORD;
                `endif
                end
                else if (MDU_data_ok && MDU_writeEnable[i]) begin
                    regHiLo[i]  <=  MDU_writeData[i];
                end 
            end
        end
    endgenerate/*}}}*/
    assign EXE_down_mduRes_o = ID_down_readHiLo_r_i[`HI_READ] ? regHiLo[1] : regHiLo[0];
    assign EXE_down_nonBlockMark_o  = HiLo_busy;
    assign EXE_down_nonBlockDS_o    = HiLo_busy || ID_down_isDelaySlot_r_i;
/*}}}*/
    // CLO,CLZ,MUL指令{{{
    wire clReq      = ID_down_mduOperator_r_i[`MDU_CLZ] || ID_down_mduOperator_r_i[`MDU_CLO];
    wire countOne   = ID_down_mduOperator_r_i[`MDU_CLO];
    reg     [4:0]   clRes;
    reg     [4:0]   position;
    reg             cl_data_ok;
    wire            cl_conflict = clReq && !cl_data_ok;
    always @(posedge clk) begin
        if (!rst) begin
            clRes   <=  'd0;
            position    <=  'd31;
            cl_data_ok  <=  'd0;
        end
        else if (clReq) begin
            clRes   <=  clRes + (
                (updataRegFile_up[0][position]==countOne) ? 
                ((updataRegFile_up[0][position+1]==countOne) ? 'd2 : 'd1) : 'd0
            );
            position    <=  position - 'd2;
            cl_data_ok  <=  position=='d1;
        end 
    end
    assign EXE_down_clRes_o = clRes;
    wire mulr_conflict = mulrReq && !mulr_data_ok;
    assign EXE_down_mulRes_o = MDU_writeData_p[31:0];
    assign ready = !(HiLoConflict|| writeHiLoConflict || mulr_conflict || cl_conflict);
    assign EXE_down_mathResSel_o =  clReq   ? 4'b0001 :
                                    mulrReq ? 4'b0010 :
                                    (|ID_down_readHiLo_r_i)  ? 4'b0100 : 4'b1000;
    /*}}}*/
    // 异常处理{{{
    assign EXE_down_hasExceprion_w_o    = EXE_down_hasException_o && !ID_down_isDelaySlot_r_i;  // 为了使得分支跳转在异常处理之前
    assign EXE_down_ExcCode_w_o         = EXE_down_ExcCode_o;                                      
    assign EXE_down_isDelaySlot_w_o     = EXE_down_isDelaySlot_o;                                     
    assign EXE_down_exceptPC_w_o        = EXE_down_VAddr_o;                                     
    assign EXE_down_exceptBadVAddr_w_o  = EXE_down_exceptBadVAddr_o;                                     
    assign EXE_down_nonBlockMark_w_o    = EXE_down_nonBlockMark_o;                                     
    assign EXE_down_eret_w_o            = EXE_down_eret_o;                                     
    assign EXE_down_isRefill_w_o        = EXE_down_isRefill_o;                                     
    assign EXE_down_isInterrupt_w_o     = 1'b0;                                     
    // }}}
endmodule
