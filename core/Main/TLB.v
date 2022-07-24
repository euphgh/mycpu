// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/04 10:52
// Last Modified : 2022/07/23 10:59
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
    output	reg	                    inst_hit_o,
    output	reg	    [`TLB_WIDTH]    inst_index_o,
    output	reg	    [`CACHE_TAG]    inst_pfn_o,
    output	wire	[`CBITS]        inst_c_o,
    output	wire	                inst_d_o,
    output	wire	                inst_v_o,
   
    // MEM的端口以及TLBP的复用
    input   wire                    data_tlbReq_i,  // 只有在该信号拉高的时候才会在下一周期更新TLB输出
    input	wire	[`VPN2]         data_vpn2_i,
    input	wire	                data_oddPage_i,
    input	wire	[`ASID]         data_asid_i,
    output	reg	    [`TLB_WIDTH]    data_index_o,
    output	reg	    [`CACHE_TAG]    data_pfn_o,
    output	reg	                    data_hit_o,
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
    output	reg     [`VPN2]         r_vpn2_o,
    output	reg	    [`ASID]         r_asid_o,
    output	reg	    [`MASK]         r_mask_o,
    output	reg	                    r_g_o,
    output	reg	    [`CACHE_TAG]    r_pfn0_o,
    output	reg	    [`FLAG0]        r_flags0_o,
    output	reg	    [`CACHE_TAG]    r_pfn1_o,
    output	reg	    [`FLAG1]        r_flags1_o
);
    //* Structure:
    //* bit:     |89    71|70    63|62        51| 50 |49    30|29   25|24    5|4     0|
    //* field:   |  vpn2  |  asid  |  pagemask  |  G |  pfn0  | c,d,v |  pfn1 | c,d,v |
    endmodule
