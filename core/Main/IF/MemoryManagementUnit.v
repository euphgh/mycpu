// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/06/30 21:04
// Last Modified : 2022/07/30 21:01
// File Name     : MemoryManagementUnit.v
// Description   :  1.  根据虚地址映射物理地址的高位
//                  2.  检查TLB异常和非对齐异常 
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/06/30   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "MyDefines.v"
module MemoryManagementUnit (
    input	wire	clk,
    input	wire	rst,
    // 映射虚地址
    input	wire	[`SINGLE_WORD]  PCR_VAddr_i,
    // 该映射是否有非对齐异常,延后一个周期
    input	wire	                FCT_hasException_i,
    // CP0交互{{{
    input   wire    [`SINGLE_WORD]  CP0_Config_w_i,
/*}}}*/
    // TLB接口{{{
    output  wire                    inst_tlbReq_o,
    output	wire	[`VPN2]         inst_vpn2_o,
    output	wire	                inst_oddPage_o,
    output	wire	[`ASID]         inst_asid_o,
    input	wire	                inst_hit_i,
    input	wire	[`TLB_WIDTH]    inst_index_i,
    input	wire	[`CACHE_TAG]    inst_pfn_i,
    input	wire	[`CBITS]        inst_c_i,
    input	wire	                inst_d_i,
    input	wire	                inst_v_i,/*}}}*/
    // 异常信号输出{{{
    output	wire 	[`EXCCODE]      MMU_ExcCode_o,      //包括TLB异常以及非对齐异常
    output	wire 	                MMU_hasException_o,
    output	wire	                MMU_isRefill_o,
/*}}}*/
    // 总线接口{{{
    input	wire	                inst_req,
    input	wire	                inst_index_ok,
    output	wire 	[`CACHE_TAG]    inst_tag,
    output	wire 	                inst_hasException,
    output	wire 	                inst_unCache
    /*}}}*/
);
    // 自动定义{{{
    /*autodef*/    
    //Start of automatic define
    //Start of automatic reg
    //Define flip-flop registers here
    reg     [`CACHE_TAG]        unmapTag                        ;
    //Define combination registers here
    //End of automatic reg
    //Start of automatic wire
    //Define assign wires here
    reg                         isKseg0                         ;
    reg                         isKseg1                         ;
    reg                         isOther                         ;
    reg                         kseg0UnCache                    ;
    wire                        kseg1UnCache                    ;
    wire                        otherUnCache                    ;
    wire    [`CACHE_TAG]        PCinput                         ;
    //Define instance wires here
    //End of automatic wire
    //End of automatic define
    // }}}
    // 线信号处理{{{
`ifdef OPEN_CACHE
    assign kseg1UnCache = `FALSE;
`else
    assign kseg1UnCache = `TRUE;
`endif
    assign PCinput = PCR_VAddr_i[`CACHE_TAG];
    assign inst_tlbReq_o = inst_req && inst_index_ok && isOther;
/*}}}*/
    // 直接映射的寄存器版本{{{
    always @(posedge clk) begin
        if(!rst) begin
            unmapTag        <=  `CACHE_TAG_ZERO;
            isKseg0         <=  `FALSE;
            isKseg1         <=  `FALSE;
            isOther         <=  `FALSE;// 0?或者11?
            kseg0UnCache    <=  'd0;
        end
        else if (inst_req && inst_index_ok) begin
            unmapTag    <=  {3'b0,PCinput[28:12]};
            isKseg0         <=  PCR_VAddr_i[31:29]==3'b100;
            isKseg1         <=  PCR_VAddr_i[31:29]==3'b101;
            isOther         <=  (!PCR_VAddr_i[31]) || (&PCR_VAddr_i[31:30]);// 0?或者11?
            kseg0UnCache    <=  CP0_Config_w_i[`K0]!=`CACHED;
        end
    end/*}}}*/
    // TLB输入{{{
    assign inst_vpn2_o = PCinput[31:13];
    assign inst_oddPage_o = PCinput[12];
/*}}}*/
    // 总线输出{{{
    assign otherUnCache = inst_c_i != `CACHED;
    assign inst_hasException        =  (MMU_hasException_o && isOther) || FCT_hasException_i;
    assign inst_tag = isOther ? inst_pfn_i : unmapTag;
    assign inst_unCache =   (isOther && otherUnCache) |
                            (isKseg0 && kseg0UnCache) |
                            (isKseg1 && kseg1UnCache) ;/*}}}*/
    // 异常处理{{{
    assign MMU_hasException_o   =   isOther && !(inst_v_i && inst_hit_i);
    assign MMU_ExcCode_o        =   `TLBL;
    assign MMU_isRefill_o       =   isOther && !inst_hit_i;
/*}}}*/
endmodule

