// +FHDR----------------------------------------------------------------------------
//// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/02 16:52
// Last Modified : 2022/07/30 11:23
// File Name     : DataMemoryManagementUnit.v
// Description   :
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/07/02   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "MyDefines.v"
module DataMemoryManagementUnit(
    input	wire	clk,
    input	wire	rst,
    // 流水线接口{{{
    // 表示需要tlb执行以下操作
    input	wire	                        PREMEM_search_w_i,
    input	wire	                        PREMEM_read_w_i,
    input	wire	                        PREMEM_writeI_w_i,
    input	wire	                        PREMEM_writeR_w_i,
    // 一般地址映射
    input	wire	                        PREMEM_map_w_i,
    // 映射的地址
    input	wire	[`SINGLE_WORD]          PREMEM_VAddr_w_i,
    // 异常处理
    output	wire	[`EXCCODE]              DMMU_ExcCode_o,     // 是否产生异常根据总线信号data_hasException
    output	wire	                        DMMU_tlbRefill_o,   // 是否有重填异常
/*}}}*/
    // Cache接口 {{{
    input	wire	                        data_req,
    // 确定读写
    input	wire                            data_wr,
    input	wire	                        data_index_ok,
    output	wire	[`CACHE_TAG]            data_tag,
    output	wire	                        data_unCache,
    // 执行地址映射之后产生的异常
    output	wire	                        data_hasException,
    
/*}}}*/
    // TLB接口{{{
    // map接口
    output  wire                    data_tlbReq_o,
    output	wire	[`VPN2]         data_vpn2_o,
    output	wire	                data_oddPage_o,
    output	wire	[`ASID]         data_asid_o,
    input	wire	                data_hit_i,
    input	wire	[`TLB_WIDTH]    data_index_i,
    input	wire	[`CACHE_TAG]    data_pfn_i,
    input	wire	[`CBITS]        data_c_i,
    input	wire	                data_d_i,
    input	wire	                data_v_i,
    // TLBW
    output	wire	                w_enbale_o,
    output	wire	[`TLB_WIDTH]    w_index_o,
    output	wire	[`VPN2]         w_vpn2_o,
    output	wire	[`ASID]         w_asid_o,
    output	wire	[`MASK]         w_mask_o,
    output	wire	                w_g_o,
    output	wire	[`CACHE_TAG]    w_pfn0_o,
    output	wire	[`FLAG0]        w_flags0_o,
    output	wire	[`CACHE_TAG]    w_pfn1_o,
    output	wire	[`FLAG1]        w_flags1_o,
    // TLBR
    output	wire	                r_enbale_o,
    output	wire	[`TLB_WIDTH]    r_index_o,
    input	wire    [`VPN2]         r_vpn2_i,
    input	wire	[`ASID]         r_asid_i,
    input	wire	[`MASK]         r_mask_i,
    input	wire	                r_g_i,
    input	wire	[`CACHE_TAG]    r_pfn0_i,
    input	wire	[`FLAG0]        r_flags0_i,
    input	wire	[`CACHE_TAG]    r_pfn1_i,
    input	wire	[`FLAG1]        r_flags1_i,
/*}}}*/
    // CP0接口{{{
    // 写CP0{{{
    // 写请求
    output	reg	                            DMMU_TLBPwrite_o,       // 查询指令，写Index
    output	reg	                            DMMU_TLBRwrite_o,       // 读指令,写大部分TLB寄存器
    // TLBR读出来的信息
    output	wire    [`SINGLE_WORD]          DMMU_EntryHi_o,
    output	wire    [`SINGLE_WORD]          DMMU_EntryLo0_o,
    output	wire    [`SINGLE_WORD]          DMMU_EntryLo1_o,
    output	wire    [`SINGLE_WORD]          DMMU_PageMask_o,
    // TLBP查出来的Index
    output	wire    [`SINGLE_WORD]          DMMU_Index_o,
    // }}}
    // 读CP0{{{
    // 确定map和cache
    input	wire    [`SINGLE_WORD]          CP0_Config_w_i,
    // 查找所需要的信息
    input	wire    [`SINGLE_WORD]          CP0_EntryHi_w_i,
    // 写操作写入的信息
    input	wire    [`SINGLE_WORD]          CP0_EntryLo0_w_i,
    input	wire    [`SINGLE_WORD]          CP0_EntryLo1_w_i,
    input	wire    [`SINGLE_WORD]          CP0_PageMask_w_i,
    // 写和读操作操作的Index
    input	wire    [`SINGLE_WORD]          CP0_Index_w_i,
    input	wire    [`SINGLE_WORD]          CP0_Random_w_i
    // }}}
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
    // map操作逻辑{{{
    assign kseg1UnCache = `TRUE;
    assign otherUnCache = data_c_i!=`CACHED;
    assign PCinput = PREMEM_VAddr_w_i[`CACHE_TAG] & {20{data_index_ok&&data_req}};
    assign data_tlbReq_o = data_req && data_index_ok || PREMEM_search_w_i;
    reg     mapReq;
    reg     mapWR;
    always @(posedge clk) begin
        if(!rst) begin
            mapReq      <=  `FALSE;
            mapWR       <=  1'b0;
            unmapTag    <=  `CACHE_TAG_ZERO;
            isKseg0         <=  `FALSE;
            isKseg1         <=  `FALSE;
            isOther         <=  `FALSE;// 0?或者11?
            kseg0UnCache    <=  'd0;
        end
        else if (data_tlbReq_o) begin
            mapReq      <=  PREMEM_map_w_i;
            isKseg0         <=  PREMEM_VAddr_w_i[31:29]==3'b100;
            isKseg1         <=  PREMEM_VAddr_w_i[31:29]==3'b101;
            isOther         <=  (!PREMEM_VAddr_w_i[31]) || (&PREMEM_VAddr_w_i[31:30]);// 0?或者11?
            mapWR       <=  data_wr;
            unmapTag    <=  {3'b0,PCinput[28:12]};
            kseg0UnCache    <=  CP0_Config_w_i[`K0]!=`CACHED;
        end
    end
    assign data_vpn2_o = PCinput[31:13];
    assign data_oddPage_o = PCinput[12];
    assign data_tag = isOther ? data_pfn_i : unmapTag;

    assign data_unCache =   (isOther && otherUnCache) |
                            (isKseg0 && kseg0UnCache) |
                            (isKseg1 && kseg1UnCache) ;

    wire    modifyException     =   data_hit_i && data_v_i && !data_d_i && !mapWR;
    wire    storeException      =   !mapWR && (!data_hit_i || !data_v_i);
    wire    loadException       =   mapWR  && (!data_hit_i || !data_v_i);
    assign  data_hasException   =   (modifyException || storeException || loadException) && mapReq && isOther;
    assign  DMMU_ExcCode_o      =   {5{mapReq}} & (modifyException ?   `MOD :
                                    storeException  ?   `TLBS: `TLBL);
    assign  DMMU_tlbRefill_o    =   mapReq && !data_hit_i ;
    /*}}}*/
    // 写操作逻辑{{{
    assign w_enbale_o   =   PREMEM_writeR_w_i || PREMEM_writeI_w_i;
    assign w_index_o    =   PREMEM_writeI_w_i ? CP0_Index_w_i[`INDEX] : CP0_Random_w_i[`INDEX];
    assign w_vpn2_o     =   CP0_EntryHi_w_i[`HI_VPN];
    assign w_asid_o     =   CP0_EntryHi_w_i[`HI_ASID];
    assign w_g_o        =   CP0_EntryLo0_w_i[`LO_G] && CP0_EntryLo1_w_i[`LO_G];
    assign w_pfn0_o     =   CP0_EntryLo0_w_i[`LO_FPN];
    assign w_flags0_o   =   {CP0_EntryLo0_w_i[`LO_C],CP0_EntryLo0_w_i[`LO_D],CP0_EntryLo0_w_i[`LO_V]};
    assign w_pfn1_o     =   CP0_EntryLo1_w_i[`LO_FPN];
    assign w_flags1_o   =   {CP0_EntryLo1_w_i[`LO_C],CP0_EntryLo1_w_i[`LO_D],CP0_EntryLo1_w_i[`LO_V]};
/*}}}*/
    // 读操作逻辑{{{
    assign r_enbale_o  =    PREMEM_read_w_i;
    always @(posedge clk) begin
        if (!rst) begin
            DMMU_TLBPwrite_o <= `FALSE;
            DMMU_TLBRwrite_o <= `FALSE;
        end
        else  begin
            DMMU_TLBPwrite_o <= PREMEM_search_w_i;
            DMMU_TLBRwrite_o <= PREMEM_read_w_i;
        end
    end
    assign r_index_o   =    CP0_Index_w_i[`INDEX];
    assign DMMU_EntryHi_o   =   {r_vpn2_i,5'b0,r_asid_i};
    assign DMMU_EntryLo0_o  =   {6'b0,r_pfn0_i,r_flags0_i,r_g_i};
    assign DMMU_EntryLo1_o  =   {6'b0,r_pfn1_i,r_flags1_i,r_g_i};
/*}}}*/
    // 查操作逻辑{{{
    assign DMMU_Index_o[`P]       =   !data_hit_i;
    assign DMMU_Index_o[`INDEX]   =   data_index_i;
/*}}}*/
endmodule

