// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/03 14:17
// Last Modified : 2022/07/23 09:16
// File Name     : WriteBack.v
// Description   : 回写段，用于数据选择，数据前递和数据写入RegFile
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
module WriteBack (
    input	wire	clk,
    input	wire	rst,

    //////////////////////////////////////////////////
    //////////////     线信号输入      ///////////////{{{
    //////////////////////////////////////////////////
    // 流水线控制
    input	wire	                        PBA_allowin_w_i,
    input	wire	                        MEM_valid_w_i,
    // 异常互锁
    input	wire                            PBA_hasRisk_w_i, 
    // 总线数据输入
    input	wire	[`SINGLE_WORD]          data_rdata,
/*}}}*/
    //////////////////////////////////////////////////
    //////////////     线信号输出      ///////////////{{{
    //////////////////////////////////////////////////
    // ID阶段前递控制
    output	wire	[`GPR_NUM]              WB_writeNum_w_o,    
    //危险暂停信号
    output	wire	                        WB_hasDangerous_w_o,    // mul,clo,clz,madd,msub,cache,tlb等危险指令
    // 异常互锁
    output	wire	                        WB_hasRisk_w_o,         
    // 流水线互锁信号 
    output	wire	                        WB_allowin_w_o,         // 逐级互锁信号
    //output	wire	                        WB_valid_w_o,              
    // 数据前递信号
    output	wire	[`SINGLE_WORD]          WB_forwardData_w_o,     // EXE计算结果前递
    // ID回写信号
    output	wire	                        WB_writeEnable_w_o,       // 回写使能
/*}}}*/
    ///////////////////////////////////////////////////
    //////////////     寄存器输出       ///////////////{{{
    ///////////////////////////////////////////////////
    output	reg	    [`SINGLE_WORD]  debug_wb_pc1,
    output	reg	    [3:0]           debug_wb_rf_wen1,
    output	reg	    [`GPR_NUM]      debug_wb_rf_wnum1,
    output	reg	    [`SINGLE_WORD]  debug_wb_rf_wdata1,
/*}}}*/
    //////////////////////////////////////////////////
    //////////////      寄存器输入      //////////////{{{
    //////////////////////////////////////////////////
    input	wire	[`GPR_NUM]              MEM_writeNum_i,         // 回写寄存器数值,0为不回写
    input	wire	                        MEM_exceptionRisk_i,
    input	wire	[`SINGLE_WORD]          MEM_VAddr_i,
    input	wire	                        MEM_isDangerous_i,      // 表示该条指令是不是危险指令,传递给下一级
    input	wire    [`SINGLE_WORD]          MEM_finalRes_i,         // 最终写入寄存器的数值 包括alu，乘除，cp0
    // 访存信号
    input	wire	[`SINGLE_WORD]          MEM_rtData_i,
    input	wire	[1:0]                   MEM_alignCheck_i,
    input	wire    [`LOAD_SEL]             MEM_loadSel_i           // load指令模式		
/*}}}*/
);

    // 自动定义{{{
    /*autodef*/
    // }}}
    //Intersegment_register{{{

    wire            needClear;
    wire            needUpdata;

	reg	[`GPR_NUM]			MEM_writeNum_r_i;
	reg	[0:0]			MEM_exceptionRisk_r_i;
	reg	[`SINGLE_WORD]			MEM_VAddr_r_i;
	reg	[0:0]			MEM_isDangerous_r_i;
	reg	[`SINGLE_WORD]			MEM_finalRes_r_i;
	reg	[`SINGLE_WORD]			MEM_rtData_r_i;
	reg	[1:0]			MEM_alignCheck_r_i;
	reg	[`LOAD_SEL]			MEM_loadSel_r_i;
    always @(posedge clk) begin
        if (!rst && needClear) begin
			MEM_writeNum_r_i	<=	'b0;
			MEM_exceptionRisk_r_i	<=	'b0;
			MEM_VAddr_r_i	<=	'b0;
			MEM_isDangerous_r_i	<=	'b0;
			MEM_finalRes_r_i	<=	'b0;
			MEM_rtData_r_i	<=	'b0;
			MEM_alignCheck_r_i	<=	'b0;
			MEM_loadSel_r_i	<=	'b0;
        end
        else if (needUpdata) begin
			MEM_writeNum_r_i	<=	MEM_writeNum_i;
			MEM_exceptionRisk_r_i	<=	MEM_exceptionRisk_i;
			MEM_VAddr_r_i	<=	MEM_VAddr_i;
			MEM_isDangerous_r_i	<=	MEM_isDangerous_i;
			MEM_finalRes_r_i	<=	MEM_finalRes_i;
			MEM_rtData_r_i	<=	MEM_rtData_i;
			MEM_alignCheck_r_i	<=	MEM_alignCheck_i;
			MEM_loadSel_r_i	<=	MEM_loadSel_i;
        end
    end
    /*}}}*/
    // 线信号处理{{{
    assign WB_hasRisk_w_o  = MEM_exceptionRisk_r_i || PBA_hasRisk_w_i;
    assign WB_writeNum_w_o = MEM_writeNum_r_i;
    assign WB_hasDangerous_w_o = MEM_isDangerous_r_i;
    // 流水线互锁
    reg hasData;
    wire ready = 1'b1;
    wire needFlash = 1'b0;
    // 只要有一段有数据就说明有数据
    wire WB_valid_w_o = hasData && ready;
    assign WB_allowin_w_o = !hasData || ready;
    wire   ok_to_change = WB_allowin_w_o && PBA_allowin_w_i ;
    assign needUpdata = ok_to_change && MEM_valid_w_i;
    assign needClear  = (!MEM_valid_w_i&&ok_to_change) || needFlash;
    always @(posedge clk) begin
        if(!rst || needClear) begin
            hasData <=  1'b0;
        end
        else if (ok_to_change)
            hasData <=  MEM_valid_w_i;
    end
    /*}}}*/
    // load类指令{{{
    wire lb_sign = (MEM_alignCheck_r_i==2'b00 ? data_rdata[7] :
                   MEM_alignCheck_r_i==2'b01 ? data_rdata[15] :
                   MEM_alignCheck_r_i==2'b10 ? data_rdata[23] : data_rdata[31]) 
                   && MEM_loadSel_r_i[`LOAD_LB_BIT];
    wire [`SINGLE_WORD] lb_data =   {{24{lb_sign}},{MEM_alignCheck_r_i==2'b00 ? {data_rdata[7:0]} :
                                                    MEM_alignCheck_r_i==2'b01 ? {data_rdata[15:8]} :
                                                    MEM_alignCheck_r_i==2'b10 ? {data_rdata[23:16]} :
                                                                                {data_rdata[31:24]}} } ;
    wire lb_sel = MEM_loadSel_r_i[`LOAD_LB_BIT] || MEM_loadSel_r_i[`LOAD_LBU_BIT];
    wire lh_sign = (MEM_alignCheck_r_i==2'b00 ? data_rdata[15] : data_rdata[31]) && MEM_loadSel_r_i[`LOAD_LH_BIT];
    wire [`SINGLE_WORD] lh_data =   {{16{lh_sign}},{MEM_alignCheck_r_i==2'b00 ? {data_rdata[15:0]}  :
                                                                                {data_rdata[31:16]}} } ;
    wire lh_sel = MEM_loadSel_r_i[`LOAD_LH_BIT] || MEM_loadSel_r_i[`LOAD_LHU_BIT];
    wire    [`SINGLE_WORD]  lw_data  = data_rdata;
    wire lw_sel = MEM_loadSel_r_i[`LOAD_LW_BIT];
    wire    [`SINGLE_WORD]  lwl_data =  MEM_loadSel_r_i[`LOAD_L0_BIT] ? {data_rdata  [ 7: 0],MEM_rtData_r_i[23:0 ]} :
                                        MEM_loadSel_r_i[`LOAD_L1_BIT] ? {data_rdata  [15: 0],MEM_rtData_r_i[15:0 ]} :
                                                                        {data_rdata  [23: 0],MEM_rtData_r_i[ 7:0 ]} ;
    wire    lwl_sel = MEM_loadSel_r_i[`LOAD_L0_BIT] || MEM_loadSel_r_i[`LOAD_L1_BIT] || MEM_loadSel_r_i[`LOAD_L2_BIT];
    wire    [`SINGLE_WORD]  lwr_data =  MEM_loadSel_r_i[`LOAD_R3_BIT] ? {MEM_rtData_r_i[31: 8],data_rdata  [31:24]} :
                                        MEM_loadSel_r_i[`LOAD_R2_BIT] ? {MEM_rtData_r_i[31:16],data_rdata  [31:16]} :
                                                                        {MEM_rtData_r_i[31:24],data_rdata  [31:8 ]} ;
    wire    lwr_sel = MEM_loadSel_r_i[`LOAD_R1_BIT] || MEM_loadSel_r_i[`LOAD_R2_BIT] || MEM_loadSel_r_i[`LOAD_R3_BIT];
    wire    not_load = |MEM_loadSel_r_i;
    assign WB_forwardData_w_o = ({32{lb_sel}} & lb_data) |
                            ({32{lh_sel}} & lh_data) |
                            ({32{lw_sel}} & lw_data) |
                            ({32{lwl_sel}}& lwl_data)|
                            ({32{lwr_sel}}& lwr_data)|
                            ({32{not_load}}& MEM_finalRes_r_i);
    /*}}}*/
    // 传递数值{{{
    assign WB_writeEnable_w_o = |MEM_writeNum_r_i && WB_valid_w_o;
    // }}}
    // debugSignal{{{
    always @(posedge clk) begin
        if (!rst) begin
            debug_wb_pc1        <=  `ZEROWORD;
            debug_wb_rf_wen1    <=  4'b0;
            debug_wb_rf_wnum1   <=  5'b0;
            debug_wb_rf_wdata1  <=  `ZEROWORD;
        end
        else begin
            debug_wb_pc1        <=  MEM_VAddr_r_i;
            debug_wb_rf_wen1    <=  {4{WB_writeEnable_w_o}};
            debug_wb_rf_wnum1   <=  WB_writeNum_w_o;
            debug_wb_rf_wdata1  <=  WB_forwardData_w_o;
        end
    end
    // }}}
endmodule
 
