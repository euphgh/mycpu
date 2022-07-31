// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/04 10:52
// Last Modified : 2022/07/31 19:09
// File Name     : TLB.v
// Description   : 页翻译缓存
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/07/04   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "MyDefines.v"
module TLB (
    input	wire	clk,
    input	wire	rst,
    // IF的端口
    input   wire                    inst_tlbReq_i,  // 只有在该信号拉高的时候才会在下一周期更新TLB输出
    input	wire	[`VPN2]         inst_vpn2_i,
    input	wire                    inst_oddPage_i,
    input	wire	[`ASID]         inst_asid_i,
    output	wire	                inst_hit_o,
    output	wire	[`TLB_WIDTH]    inst_index_o,
    output	wire	[`CACHE_TAG]    inst_pfn_o,
    output	wire	[`CBITS]        inst_c_o,
    output	wire	                inst_d_o,
    output	wire	                inst_v_o,
   
    // MEM的端口以及TLBP的复用
    input   wire                    data_tlbReq_i,  // 只有在该信号拉高的时候才会在下一周期更新TLB输出
    input	wire	[`VPN2]         data_vpn2_i,
    input	wire	                data_oddPage_i,
    input	wire	[`ASID]         data_asid_i,
    output	wire	[`TLB_WIDTH]    data_index_o,
    output	wire	[`CACHE_TAG]    data_pfn_o,
    output	wire	                data_hit_o,
    output	wire	[`CBITS]        data_c_o,
    output	wire	                data_d_o,
    output	wire	                data_v_o,

    // TLBW
    input	wire	                w_enbale_i,
    input	wire	[`TLB_WIDTH]    w_index_i,
    input	wire	[`VPN2]         w_vpn2_i,
    input	wire	[`ASID]         w_asid_i,
    input	wire	[`MASK]         w_mask_i,
    input	wire	                w_g_i,
    input	wire	[`CACHE_TAG]    w_pfn0_i,
    input	wire	[`FLAG0]        w_flags0_i,
    input	wire	[`CACHE_TAG]    w_pfn1_i,
    input	wire	[`FLAG1]        w_flags1_i,

    // TLBR
    input	wire	                r_enbale_i,
    input	wire	[`TLB_WIDTH]    r_index_i,
    output	wire    [`VPN2]         r_vpn2_o,
    output	wire	[`ASID]         r_asid_o,
    output	wire	[`MASK]         r_mask_o,
    output	wire	                r_g_o,
    output	wire	[`CACHE_TAG]    r_pfn0_o,
    output	wire	[`FLAG0]        r_flags0_o,
    output	wire	[`CACHE_TAG]    r_pfn1_o,
    output	wire	[`FLAG1]        r_flags1_o
);
    //* Structure:
    //* bit:     |89    71|70    63|62        51| 50 |49    30|29   25|24    5|4     0|
    //* field:   |  vpn2  |  asid  |  pagemask  |  G |  pfn0  | c,d,v |  pfn1 | c,d,v |
    assign inst_hit_o = 'd0;
    assign inst_index_o = 'd0;
    assign inst_pfn_o = 'd0;
    assign inst_c_o = 'd0;
    assign inst_d_o = 'd0;
    assign inst_v_o = 'd0;
    assign data_index_o = 'd0;
    assign data_pfn_o = 'd0;
    assign data_hit_o = 'd0;
    assign data_c_o = 'd0;
    assign data_d_o = 'd0;
    assign data_v_o = 'd0;
    assign r_vpn2_o = 'd0;
    assign r_asid_o = 'd0;
    assign r_mask_o = 'd0;
    assign r_g_o = 'd0;
    assign r_pfn0_o = 'd0;
    assign r_flags0_o = 'd0;
    assign r_pfn1_o = 'd0;
    assign r_flags1_o = 'd0;
    endmodule
