// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/02 11:53
// Last Modified : 2022/07/23 10:54
// File Name     : PREMEM.v
// Description   :  预MEM段，用于处简单的数据选择,且进行TLB和cache访存第一步
//         
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/07/02   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "MyDefines.v"
module PREMEM (
    input	wire	clk,
    input	wire	rst,
    //////////////////////////////////////////////////
    //////////////     线输入信号      ///////////////{{{
    //////////////////////////////////////////////////
    // 流水线互锁信号 
    input	wire	                        MEM_allowin_w_i,
    input	wire	                        EXE_down_valid_w_i,
    input	wire	                        SBA_allowin_w_i,
    // 异常互锁
    input	wire                            SBA_hasRisk_w_i, 
    // 流水线刷新
    input	wire	                        CP0_excOccur_w_i,
    input	wire	                        SBA_flush_w_i,
    // 总线
    input	wire	                        data_index_ok,
/*}}}*/
    //////////////////////////////////////////////////
    //////////////     线输出信号      ///////////////{{{
    //////////////////////////////////////////////////
    // ID阶段前递控制
    output	wire	[`FORWARD_MODE]         PREMEM_forwardMode_w_o,    
    output	wire	[`GPR_NUM]              PREMEM_writeNum_w_o,    
    //危险暂停信号
    output	wire	                        PREMEM_hasDangerous_w_o,    // mul,clo,clz,madd,msub,cache,tlb等危险指令
    // 异常互锁
    output	wire	                        PREMEM_hasRisk_w_o,         
    // 流水线互锁信号 
    output	wire	                        PREMEM_allowin_w_o,         // 逐级互锁信号
    output	wire	                        PREMEM_valid_w_o,           // 该信号可以用于给下一级流水线决定是否采样            
    // 数据前递信号
    output	wire	[`SINGLE_WORD]          PREMEM_forwardData_w_o,     // EXE计算结果前递
    // 总线
    output	wire	[11:0]                  data_index,
    output	wire	                        data_req,
    output	wire                            data_wr,
    output	wire	[1:0]                   data_size,
    output	wire	[3:0]                   data_wstrb,
    output	wire	[`SINGLE_WORD]          data_wdata,
    // TLB
    output	wire	                        PREMEM_search_w_o,
    output	wire	                        PREMEM_read_w_o,
    output	wire	                        PREMEM_map_w_o,
    output	wire	                        PREMEM_writeI_w_o,
    output	wire	                        PREMEM_writeR_w_o,
    output	wire	[`SINGLE_WORD]          PREMEM_VAddr_w_o,
/*}}}*/
    /////////////////////////////////////////////////
    //////////////      寄存器输入   ////////////////{{{
    /////////////////////////////////////////////////
    input	wire	[`GPR_NUM]              EXE_down_writeNum_i,        // 回写寄存器数值,0为不回写
    input	wire	                        EXE_down_isDelaySlot_i,     // 该指令是否是延迟槽指令,用于异常处理
    input	wire	                        EXE_down_isDangerous_i,     // 该指令是否是延迟槽指令,用于异常处理
    input	wire	[`SINGLE_WORD]          EXE_down_VAddr_i,           // 用于debug和异常处理
    //算数,位移,乘除处理输入{{{
    input	wire    [`SINGLE_WORD]          EXE_down_aluRes_i,	        
    input	wire	[`SINGLE_WORD]          EXE_down_mduRes_i,          // mfhilo的运算处理结果
    input	wire	[4:0]                   EXE_down_clRes_i,           // clo的计算结果
    input	wire	[`SINGLE_WORD]          EXE_down_mulRes_i,          // 专门用于Mul的接口
    input	wire	[`MATH_SEL]             EXE_down_mathResSel_i,      // 数学运算结果的选择
    input	wire	                        EXE_down_nonBlockMark_i,    // 该条指令执行在MDU运算期间}}}
    // 异常处理类信息
    input	wire    [`EXCCODE]              EXE_down_ExcCode_i,         // 异常信号	
    input	wire	                        EXE_down_hasException_i,    // 存在异常
    input	wire                            EXE_down_exceptionRisk_i,   // 存在异常的风险
    input	wire	[`SINGLE_WORD]          EXE_down_exceptBadVAddr_i,    // 虚地址异常
    input	wire	                        EXE_down_eret_i,
    input	wire	[`CP0_POSITION]         EXE_down_positionCp0_i,     // {rd,sel}
    input	wire	                        EXE_down_readCp0_i,         // mfc0,才会拉高
    input	wire	                        EXE_down_writeCp0_i,        // mtc0,才会拉高
    //访存信号{{{
    input	wire	                        EXE_down_memReq_i,          // 表示访存需要              
    input	wire	                        EXE_down_memWR_i,            // 表示访存类型
    input	wire	[3:0]                   EXE_down_memEnable_i,       // 表示字节读写使能,0000表示全不写
    input	wire	                        EXE_down_memAtom_i,         // 表示该访存操作是原子访存操作,需要读写LLbit
    input	wire	[`SINGLE_WORD]          EXE_down_storeData_i,
    input	wire    [`LOAD_SEL]             EXE_down_loadSel_i,         // load指令模式		}}}
    // TLB指令,最危险指令，需要等待后面的流水线排空才能发射{{{
    input	wire	                        EXE_down_isTLBInst_i,       // 表示是TLB指令
    input	wire	[`TLB_INST]             EXE_down_TLBInstOperator_i, // 执行的种类
    // Cache指令,在该段中，cache地址由aluRes给出
    input	wire	                        EXE_down_isCacheInst_i,     // 表示是Cache指令
    input	wire	[`CACHE_OP]             EXE_down_CacheOperator_i,   // Cache指令op
    /*}}}*/
/*}}}*/
    //////////////////////////////////////////////////
    //////////////      寄存器输出      //////////////{{{
    //////////////////////////////////////////////////
    output	wire    [`GPR_NUM]              PREMEM_writeNum_o,
    output	wire	[`SINGLE_WORD]          PREMEM_VAddr_o,
    output	wire	                        PREMEM_isDelaySlot_o,       // 表示该指令是否是延迟槽指令,用于异常处理
    output	wire	                        PREMEM_isDangerous_o,       // 表示该条指令是不是危险指令,传递给下一级
    output	wire	[1:0]                   PREMEM_alignCheck_o,        // 访存地址后两位
    // 访存类信息
    output	wire    [`LOAD_SEL]             PREMEM_loadSel_o,           // load指令模式		
    output	wire	                        PREMEM_memReq_o,           
    output	wire    [`SINGLE_WORD]          PREMEM_rtData_o,
    // 算数,位移    
    output	wire    [`SINGLE_WORD]          PREMEM_preliminaryRes_o,    // 对应于SBA段的aluRes，PREMEM段的结果对于乘除指令和mf指令是已经完成了的        
    output	wire	                        PREMEM_nonBlockMark_o,      // 该条指令执行在MDU运算期间
    // 异常处理类信息
    output	wire    [`EXCCODE]              PREMEM_ExcCode_o,           // 异常信号
    output	wire	                        PREMEM_hasException_o,      // 存在异常
    output	wire                            PREMEM_exceptionRisk_o,     // 存在异常的风险
    output	wire	[`SINGLE_WORD]          PREMEM_exceptBadVAddr_o,    // 虚地址异常
    output	wire	                        PREMEM_eret_o,
    output	wire	[`CP0_POSITION]         PREMEM_positionCp0_o,       // {rd,sel}
    output	wire	                        PREMEM_readCp0_o,           // mfc0,才会拉高
    output	wire	                        PREMEM_writeCp0_o,          // mtc0,才会拉高
    // Cache指令,在该段中,cache地址由aluRes给出
    output	wire	                        PREMEM_isCacheInst_o,       // 表示是Cache指令
    output	wire	[`CACHE_OP]             PREMEM_CacheOperator_o,     // Cache指令op
    output	wire	[`SINGLE_WORD]          PREMEM_CacheAddress_o       // Cache指令地址
/*}}}*/
);
    // 自动定义{{{
    /*autodef*/
    // }}}
    //Intersegment_register{{{

    wire            needClear;
    wire            needUpdata;

	reg	[`GPR_NUM]			EXE_down_writeNum_r_i;
	reg	[0:0]			EXE_down_isDelaySlot_r_i;
	reg	[0:0]			EXE_down_isDangerous_r_i;
	reg	[`SINGLE_WORD]			EXE_down_VAddr_r_i;
	reg	[`SINGLE_WORD]			EXE_down_aluRes_r_i;
	reg	[`SINGLE_WORD]			EXE_down_mduRes_r_i;
	reg	[4:0]			EXE_down_clRes_r_i;
	reg	[`SINGLE_WORD]			EXE_down_mulRes_r_i;
	reg	[`MATH_SEL]			EXE_down_mathResSel_r_i;
	reg	[0:0]			EXE_down_nonBlockMark_r_i;
	reg	[`EXCCODE]			EXE_down_ExcCode_r_i;
	reg	[0:0]			EXE_down_hasException_r_i;
	reg	[0:0]			EXE_down_exceptionRisk_r_i;
	reg	[`SINGLE_WORD]			EXE_down_exceptBadVAddr_r_i;
	reg	[0:0]			EXE_down_eret_r_i;
	reg	[`CP0_POSITION]			EXE_down_positionCp0_r_i;
	reg	[0:0]			EXE_down_readCp0_r_i;
	reg	[0:0]			EXE_down_writeCp0_r_i;
	reg	[0:0]			EXE_down_memReq_r_i;
	reg	[0:0]			EXE_down_memWR_r_i;
	reg	[3:0]			EXE_down_memEnable_r_i;
	reg	[0:0]			EXE_down_memAtom_r_i;
	reg	[`SINGLE_WORD]			EXE_down_storeData_r_i;
	reg	[`LOAD_SEL]			EXE_down_loadSel_r_i;
	reg	[0:0]			EXE_down_isTLBInst_r_i;
	reg	[`TLB_INST]			EXE_down_TLBInstOperator_r_i;
	reg	[0:0]			EXE_down_isCacheInst_r_i;
	reg	[`CACHE_OP]			EXE_down_CacheOperator_r_i;
    always @(posedge clk) begin
        if (!rst && needClear) begin
			EXE_down_writeNum_r_i	<=	'b0;
			EXE_down_isDelaySlot_r_i	<=	'b0;
			EXE_down_isDangerous_r_i	<=	'b0;
			EXE_down_VAddr_r_i	<=	'b0;
			EXE_down_aluRes_r_i	<=	'b0;
			EXE_down_mduRes_r_i	<=	'b0;
			EXE_down_clRes_r_i	<=	'b0;
			EXE_down_mulRes_r_i	<=	'b0;
			EXE_down_mathResSel_r_i	<=	'b0;
			EXE_down_nonBlockMark_r_i	<=	'b0;
			EXE_down_ExcCode_r_i	<=	'b0;
			EXE_down_hasException_r_i	<=	'b0;
			EXE_down_exceptionRisk_r_i	<=	'b0;
			EXE_down_exceptBadVAddr_r_i	<=	'b0;
			EXE_down_eret_r_i	<=	'b0;
			EXE_down_positionCp0_r_i	<=	'b0;
			EXE_down_readCp0_r_i	<=	'b0;
			EXE_down_writeCp0_r_i	<=	'b0;
			EXE_down_memReq_r_i	<=	'b0;
			EXE_down_memWR_r_i	<=	'b0;
			EXE_down_memEnable_r_i	<=	'b0;
			EXE_down_memAtom_r_i	<=	'b0;
			EXE_down_storeData_r_i	<=	'b0;
			EXE_down_loadSel_r_i	<=	'b0;
			EXE_down_isTLBInst_r_i	<=	'b0;
			EXE_down_TLBInstOperator_r_i	<=	'b0;
			EXE_down_isCacheInst_r_i	<=	'b0;
			EXE_down_CacheOperator_r_i	<=	'b0;
        end
        else if (needUpdata) begin
			EXE_down_writeNum_r_i	<=	EXE_down_writeNum_i;
			EXE_down_isDelaySlot_r_i	<=	EXE_down_isDelaySlot_i;
			EXE_down_isDangerous_r_i	<=	EXE_down_isDangerous_i;
			EXE_down_VAddr_r_i	<=	EXE_down_VAddr_i;
			EXE_down_aluRes_r_i	<=	EXE_down_aluRes_i;
			EXE_down_mduRes_r_i	<=	EXE_down_mduRes_i;
			EXE_down_clRes_r_i	<=	EXE_down_clRes_i;
			EXE_down_mulRes_r_i	<=	EXE_down_mulRes_i;
			EXE_down_mathResSel_r_i	<=	EXE_down_mathResSel_i;
			EXE_down_nonBlockMark_r_i	<=	EXE_down_nonBlockMark_i;
			EXE_down_ExcCode_r_i	<=	EXE_down_ExcCode_i;
			EXE_down_hasException_r_i	<=	EXE_down_hasException_i;
			EXE_down_exceptionRisk_r_i	<=	EXE_down_exceptionRisk_i;
			EXE_down_exceptBadVAddr_r_i	<=	EXE_down_exceptBadVAddr_i;
			EXE_down_eret_r_i	<=	EXE_down_eret_i;
			EXE_down_positionCp0_r_i	<=	EXE_down_positionCp0_i;
			EXE_down_readCp0_r_i	<=	EXE_down_readCp0_i;
			EXE_down_writeCp0_r_i	<=	EXE_down_writeCp0_i;
			EXE_down_memReq_r_i	<=	EXE_down_memReq_i;
			EXE_down_memWR_r_i	<=	EXE_down_memWR_i;
			EXE_down_memEnable_r_i	<=	EXE_down_memEnable_i;
			EXE_down_memAtom_r_i	<=	EXE_down_memAtom_i;
			EXE_down_storeData_r_i	<=	EXE_down_storeData_i;
			EXE_down_loadSel_r_i	<=	EXE_down_loadSel_i;
			EXE_down_isTLBInst_r_i	<=	EXE_down_isTLBInst_i;
			EXE_down_TLBInstOperator_r_i	<=	EXE_down_TLBInstOperator_i;
			EXE_down_isCacheInst_r_i	<=	EXE_down_isCacheInst_i;
			EXE_down_CacheOperator_r_i	<=	EXE_down_CacheOperator_i;
        end
    end
    /*}}}*/
    // 原子访存处理{{{
    wire isLLinst = EXE_down_memReq_r_i && !EXE_down_memWR_r_i && EXE_down_memAtom_r_i; 
    wire isSCinst = EXE_down_memReq_r_i && EXE_down_memWR_r_i && EXE_down_memAtom_r_i; 
    reg LLbit ;
    always @(posedge clk) begin
        if (!rst || EXE_down_eret_r_i) begin
            LLbit   <=  1'b0;
        end
        else if (isLLinst) begin
            LLbit   <=  1'b1;
        end
    end
    // }}}
    // 线信号处理{{{
    assign PREMEM_VAddr_w_o  = EXE_down_VAddr_r_i;
    assign PREMEM_search_w_o = PREMEM_allowin_w_o && !PREMEM_hasRisk_w_o && EXE_down_isTLBInst_r_i && EXE_down_TLBInstOperator_r_i[`TLB_INST_TBLP];
    assign PREMEM_writeI_w_o = PREMEM_allowin_w_o && !PREMEM_hasRisk_w_o && EXE_down_isTLBInst_r_i && EXE_down_TLBInstOperator_r_i[`TLB_INST_TBLWI];
    assign PREMEM_writeR_w_o = PREMEM_allowin_w_o && !PREMEM_hasRisk_w_o && EXE_down_isTLBInst_r_i && EXE_down_TLBInstOperator_r_i[`TLB_INST_TBLWR];
    assign PREMEM_read_w_o   = PREMEM_allowin_w_o && !PREMEM_hasRisk_w_o && EXE_down_isTLBInst_r_i && EXE_down_TLBInstOperator_r_i[`TLB_INST_TBLRI];
    assign PREMEM_map_w_o    = PREMEM_allowin_w_o && !PREMEM_hasRisk_w_o && EXE_down_memReq_r_i;
    wire    cache_noAccept  = !data_index_ok && EXE_down_memReq_r_i;
    wire    store_conflict  = EXE_down_memReq_r_i && PREMEM_hasRisk_w_o;
    wire    tlb_conflict    = EXE_down_isTLBInst_r_i && PREMEM_hasRisk_w_o;
    assign PREMEM_forwardData_w_o = ({32{EXE_down_mathResSel_r_i[`MATH_ALU]}} & EXE_down_aluRes_r_i) |
                                    ({32{EXE_down_mathResSel_r_i[`MATH_MULR]}}& EXE_down_mulRes_r_i) |
                                    ({32{EXE_down_mathResSel_r_i[`MATH_CL]}}  & {27'b0,EXE_down_clRes_r_i})|
                                    ({32{isSCinst                         }}  & {31'b0,LLbit}) | 
                                    ({32{EXE_down_mathResSel_r_i[`MATH_MDU]}} & EXE_down_mduRes_r_i);
    assign PREMEM_hasRisk_w_o  = EXE_down_exceptionRisk_r_i || SBA_hasRisk_w_i;
    assign PREMEM_writeNum_w_o = EXE_down_writeNum_r_i;
    wire    [`FORWARD_MODE] memforward = EXE_down_memReq_r_i ? `FORWARD_MODE_WB : 'b0;
    assign PREMEM_forwardMode_w_o = `FORWARD_MODE_MEM | memforward ;
    assign PREMEM_hasDangerous_w_o = EXE_down_isDangerous_r_i;
    // 流水线互锁
    reg hasData;
    wire ready = !(store_conflict || tlb_conflict || cache_noAccept);
    wire needFlash = CP0_excOccur_w_i || SBA_flush_w_i;
    // 只要有一段有数据就说明有数据
    assign PREMEM_valid_w_o = hasData && ready;
    assign PREMEM_allowin_w_o = !hasData || (ready && MEM_allowin_w_i);
    wire   ok_to_change = PREMEM_allowin_w_o && SBA_allowin_w_i ;
    assign needUpdata = ok_to_change && EXE_down_valid_w_i;
    assign needClear  = (!EXE_down_valid_w_i&&ok_to_change) || needFlash;
    always @(posedge clk) begin
        if(!rst || needClear) begin
            hasData <=  1'b0;
        end
        else if (ok_to_change)
            hasData <=  EXE_down_valid_w_i;
    end
    /*}}}*/
    // 总线信号{{{
    assign data_req = EXE_down_memReq_r_i && !PREMEM_hasRisk_w_o && MEM_allowin_w_i;
    assign data_wr  = EXE_down_memWR_r_i;
    assign data_index   = EXE_down_aluRes_r_i[11:0];
    assign data_wstrb   = EXE_down_memEnable_r_i;
    wire [2:0] size =   {2'b00,data_wstrb[0]} + {2'b00,data_wstrb[1]} + 
                        {2'b00,data_wstrb[2]} + {2'b00,data_wstrb[3]} ;
    assign data_size=   (size=='d1) ? 2'b00 : 
                        (size=='d2) ? 2'b01 : 2'b11;
    assign data_wdata   =   EXE_down_storeData_r_i;
    // }}}
    // 简单的信号传递{{{
    assign PREMEM_writeNum_o        = EXE_down_writeNum_r_i;
    assign PREMEM_VAddr_o           = EXE_down_VAddr_r_i;
    assign PREMEM_isDelaySlot_o     = EXE_down_isDelaySlot_r_i;
    assign PREMEM_isDangerous_o     = EXE_down_isDangerous_r_i;
    assign PREMEM_alignCheck_o      = EXE_down_aluRes_r_i[1:0];
    assign PREMEM_loadSel_o         = EXE_down_loadSel_r_i;
    assign PREMEM_memReq_o          = EXE_down_memReq_r_i;
    assign PREMEM_preliminaryRes_o  = PREMEM_forwardData_w_o;
    assign PREMEM_nonBlockMark_o    = EXE_down_nonBlockMark_r_i;
    assign PREMEM_rtData_o          = data_wdata;
/*}}}*/
    // 异常处理{{{
    assign PREMEM_hasException_o    = EXE_down_hasException_r_i;
    assign PREMEM_exceptionRisk_o   = PREMEM_hasException_o;
    assign PREMEM_ExcCode_o         = EXE_down_ExcCode_r_i;
    assign PREMEM_readCp0_o         = EXE_down_readCp0_r_i;
    assign PREMEM_writeCp0_o        = EXE_down_writeCp0_r_i;
    assign PREMEM_positionCp0_o     = EXE_down_positionCp0_r_i;
    assign PREMEM_eret_o            = EXE_down_eret_r_i;
    assign PREMEM_exceptBadVAddr_o  = EXE_down_exceptBadVAddr_r_i;
    assign PREMEM_alignCheck_o      = data_index[1:0];
    // }}}
    // Cache指令{{{
    assign PREMEM_CacheAddress_o = EXE_down_aluRes_r_i;
    assign PREMEM_isCacheInst_o     = EXE_down_isCacheInst_r_i;
    assign PREMEM_CacheOperator_o   = EXE_down_CacheOperator_r_i;
    // }}}
endmodule

