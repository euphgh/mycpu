// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/18 10:45
// Last Modified : 2022/08/03 18:24
// File Name     : PrimaryExceptionProcessor.v
// Description   :  接受异常请求和修改TLB的请求,对CP0寄存器进行读写
//                  此外还需在异常触发的时候发送刷新流水线的信号
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/07/18   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "../MyDefines.v"
module PrimaryExceptionProcessor (
    input	wire	                        clk,
    input	wire	                        rst,
    // 特权指令的异常请求
    input	wire	                        MEM_writeCp0_w_i,         // mtc0,才会拉高
    input	wire	[`CP0_POSITION]         MEM_positionCp0_w_i,      // {rd,sel}
    input	wire	[`SINGLE_WORD]          MEM_writeData_w_i,        // 需要写入CP0的内容
    // tlb指令的异常请求{{{
    input	wire	                        DMMU_TLBPwrite_i,       // 查询指令，写Index
    input	wire	                        DMMU_TLBRwrite_i,       // 读指令,写大部分TLB寄存器
    input	wire    [`SINGLE_WORD]          DMMU_Index_i,
    input	wire    [`SINGLE_WORD]          DMMU_EntryHi_i,
    input	wire    [`SINGLE_WORD]          DMMU_EntryLo0_i,
    input	wire    [`SINGLE_WORD]          DMMU_EntryLo1_i,
    input	wire    [`SINGLE_WORD]          DMMU_PageMask_i,
/*}}}*/
    // MEM段异常处理内容{{{
    // 判断该段是否可以处理异常不可以用该段的hasRisk,因为有异常必为1
    input	wire	                        WB_hasRisk_w_i,
    input	wire	                        MEM_hasException_w_i,     // 存在异常
    input	wire    [`EXCCODE]              MEM_ExcCode_w_i,          // 异常信号
    input	wire	                        MEM_isDelaySlot_w_i,
    input	wire	[`SINGLE_WORD]          MEM_exceptPC_w_i,
    input	wire	[`SINGLE_WORD]          MEM_exceptBadVAddr_w_i,
    input	wire	                        MEM_nonBlockMark_w_i,
    input	wire	                        MEM_eret_w_i,
    input	wire	                        MEM_isRefill_w_i,       // 不同异常地址
    input	wire	                        MEM_isInterrupt_w_i,    // 不同异常地址
/*}}}*/
    // PREMEM段异常处理内容{{{
    // 判断该段是否可以处理异常不可以用该段的hasRisk,因为有异常必为1
    input	wire	                        MEM_hasRisk_w_i,
    input	wire	                        PREMEM_hasException_w_i,     // 存在异常
    input	wire    [`EXCCODE]              PREMEM_ExcCode_w_i,          // 异常信号
    input	wire	                        PREMEM_isDelaySlot_w_i,
    input	wire	[`SINGLE_WORD]          PREMEM_exceptPC_w_i,
    input	wire	[`SINGLE_WORD]          PREMEM_exceptBadVAddr_w_i,
    input	wire	                        PREMEM_nonBlockMark_w_i,
    input	wire	                        PREMEM_eret_w_i,
    input	wire	                        PREMEM_isRefill_w_i,       // 不同异常地址
    input	wire	                        PREMEM_isInterrupt_w_i,    // 不同异常地址
/*}}}*/
    // EXE down段异常处理内容{{{
    input	wire	                        PREMEM_hasRisk_w_i,         
	input   wire    [0:0]			        EXE_down_hasExceprion_w_i,
	input   wire    [`EXCCODE]			    EXE_down_ExcCode_w_i,
    input	wire	                        EXE_down_isDelaySlot_w_i,
    input	wire	[`SINGLE_WORD]          EXE_down_exceptPC_w_i,
    input	wire	[`SINGLE_WORD]          EXE_down_exceptBadVAddr_w_i,
    input	wire	                        EXE_down_nonBlockMark_w_i,
    input	wire	                        EXE_down_eret_w_i,
    input	wire	                        EXE_down_isRefill_w_i,       // 不同异常地址
    input	wire	                        EXE_down_isInterrupt_w_i,    // 不同异常地址
/*}}}*/
    // 外界读取寄存器{{{
    output	wire	[`SINGLE_WORD]          CP0_Status_w_o,
    output	wire	[`SINGLE_WORD]          CP0_Cause_w_o,
    output	wire	[`SINGLE_WORD]          CP0_Config_w_o,
/*}}}*/
    // 异常处理的输出{{{
    output	wire	[`SINGLE_WORD]          CP0_readData_w_o,       // 读出来的寄存器数值
    output	wire	                        CP0_excOccur_w_o,       // 判断是否发生了异常冲刷
    output	wire	[`SINGLE_WORD]          CP0_excDestPC_w_o,
    output	wire	                        CP0_nonBlockMark_w_o,   //此次异常发生在乘除之后
    output	wire	[`SINGLE_WORD]          CP0_EntryHi_w_o, 
    output	wire	[`SINGLE_WORD]          CP0_EntryLo0_w_o, 
    output	wire	[`SINGLE_WORD]          CP0_EntryLo1_w_o, 
    output	wire	[`SINGLE_WORD]          CP0_PageMask_w_o, 
    output	wire	[`SINGLE_WORD]          CP0_Index_w_o, 
    output	wire	[`SINGLE_WORD]          CP0_Random_w_o, 
    output	wire	[`EXCEP_SEG]            CP0_exceptSeg_w_o,
/*}}}*/
    input   wire    [5:0]                   ext_int                 // 外部中断接入口 
);
    // 寄存器数据{{{
    wire    [`SINGLE_WORD]	        Index;
    wire    [`SINGLE_WORD]	        EntryLo0;
    wire    [`SINGLE_WORD]	        EntryLo1;
    wire    [`SINGLE_WORD]	        BadVAdder;
    wire    [`SINGLE_WORD]	        Count;
    wire    [`SINGLE_WORD]	        EntryHi;
    wire    [`SINGLE_WORD]	        Compare;
    wire    [`SINGLE_WORD]	        Status;
    wire    [`SINGLE_WORD]	        Cause;
    wire    [`SINGLE_WORD]	        EPC;
    wire    [`SINGLE_WORD]	        Config;
    wire    [`SINGLE_WORD]	        Config1;
    // }}}
    // 外部输入的再连线和定义{{{
    // TLB指令的写入信息
    wire	                TLBPwrite = DMMU_TLBPwrite_i;       // 查询指令，写Index
    wire	                TLBRwrite = DMMU_TLBRwrite_i;       // 读指令,写大部分TLB寄存器
    wire    [`SINGLE_WORD]  tlbwIndex   = DMMU_Index_i;
    wire    [`SINGLE_WORD]  tlbwEntryHi = DMMU_EntryHi_i;
    wire    [`SINGLE_WORD]  tlbwEntryLo0= DMMU_EntryLo0_i;
    wire    [`SINGLE_WORD]  tlbwEntryLo1= DMMU_EntryLo1_i;
    wire    [`SINGLE_WORD]  tlbwPageMask= DMMU_PageMask_i;
    // mtc0指令写入信息
    wire                    mtc0_wen    = MEM_writeCp0_w_i;
    wire [`CP0_POSITION]    mtc0_addr   = MEM_positionCp0_w_i;
    wire [`CP0_POSITION]    mfc0_addr   = MEM_positionCp0_w_i;
    wire [`SINGLE_WORD]     mtc0_wdata  = MEM_writeData_w_i;
    // 一般异常信息
    `define ALL_INFO `ALL_INFO_LEN-1:0
    `define ALL_INFO_LEN 73
    wire [`ALL_INFO] EXE_packedInfo = {
         EXE_down_hasExceprion_w_i,
         EXE_down_ExcCode_w_i,
         EXE_down_isDelaySlot_w_i,
         EXE_down_exceptPC_w_i,
         EXE_down_exceptBadVAddr_w_i,
         EXE_down_nonBlockMark_w_i,
         EXE_down_eret_w_i
        };
    wire [`ALL_INFO] MEM_packedInfo = {
         MEM_hasException_w_i,
         MEM_ExcCode_w_i,
         MEM_isDelaySlot_w_i,
         MEM_exceptPC_w_i,
         MEM_exceptBadVAddr_w_i,
         MEM_nonBlockMark_w_i,
         MEM_eret_w_i
        };
    wire [`ALL_INFO] PREMEM_packedInfo = {
         PREMEM_hasException_w_i,
         PREMEM_ExcCode_w_i,
         PREMEM_isDelaySlot_w_i,
         PREMEM_exceptPC_w_i,
         PREMEM_exceptBadVAddr_w_i,
         PREMEM_nonBlockMark_w_i,
         PREMEM_eret_w_i
        };
    wire [`ALL_INFO] selectedInfo = !PREMEM_hasRisk_w_i   ? EXE_packedInfo :
                                    !MEM_hasRisk_w_i      ? PREMEM_packedInfo :
                                    !WB_hasRisk_w_i       ? MEM_packedInfo : 'd0;
    wire                    hasException;
    wire    [`EXCCODE]      ExcCode;
    wire                    isDelaySlot;
    wire    [`SINGLE_WORD]  exceptPC;       // 异常指令的PC TODO
    wire                    nonBlockMark;
    wire                    eret;           // 退出指令
    wire    [`SINGLE_WORD]  exceptBadVAddr; // 错误的虚地址,访存不对齐和tlb错误 TODO
    assign {
         hasException,
         ExcCode,
         isDelaySlot,
         exceptPC,
         exceptBadVAddr,
         nonBlockMark,
         eret
        } = selectedInfo;
    wire    isExceptionInNormal = (hasException && !Status[`EXL]) ? `TRUE : `FALSE;
    assign CP0_exceptSeg_w_o =  !PREMEM_hasRisk_w_i     ?   `EXCEP_EXE_CODE :
                                !MEM_hasRisk_w_i        ?   `EXCEP_PREMEM_CODE :
                                !WB_hasRisk_w_i         ?   `EXCEP_MEM_CODE  : 'd0;

    /*}}}*/
    ////////////////    Status  ////////////////{{{
    //  EXL{{{
    reg  Status_exl;
    always @(posedge clk) begin
        if (!rst) begin
            Status_exl    <=  `FALSE;
        end
        if (mtc0_wen && mtc0_addr==`ADDR_STATUS) begin
            Status_exl        <=  mtc0_wdata[`EXL];
        end
        else if (isExceptionInNormal) begin
            Status_exl    <=  `TRUE;
        end
        else if (eret) begin
            Status_exl    <=  `FALSE;
        end
    end
    //}}}
    //  im7~im0{{{
    reg     [`IM7:`IM0]     Status_im;
    always @(posedge clk) begin
        if (!rst) begin
            Status_im   <=  'd0;
        end
        else if (mtc0_wen && mtc0_addr==`ADDR_STATUS) begin
            Status_im   <=  mtc0_wdata[`IM7:`IM0];
        end
    end
    //}}}
    //  IE{{{
    reg     Status_ie;
    always @(posedge clk) begin
        if (!rst) begin
            Status_ie   <=  `FALSE;
        end
        else if (mtc0_wen && mtc0_addr==`ADDR_STATUS) begin
            Status_ie   <=  mtc0_wdata[`IE];
        end
    end
    //}}}
    assign Status = {9'b0,1'b1,6'b0,Status_im,6'b0,Status_exl,Status_ie};
    //}}}
    ////////////////    Cause  ////////////////{{{
    //BD{{{
    reg Cause_bd;
    always @(posedge clk) begin
        if (!rst) begin
            Cause_bd    <=  `FALSE;
        end
        else if (isExceptionInNormal) begin
            Cause_bd    <=  isDelaySlot;
        end
    end
    //}}}
    //TI{{{
    reg Cause_ti;
    always @(posedge clk) begin
        if (!rst) begin
            Cause_ti    <=  `FALSE;
        end
        else if (mtc0_wen && mtc0_addr==`ADDR_COMPARE) begin
            Cause_ti    <=  `FALSE;
        end
        else if (Count==Compare) begin
            Cause_ti    <=  `TRUE;
        end
    end
    //}}}
    // IP7~IP2{{{
    reg     [`IP7:`IP0] Cause_ip;
    always @(posedge clk) begin
        if (!rst) begin
            Cause_ip[`IP7:`IP2] <=  'd0;
        end
        else begin
            Cause_ip[`IP7]      <=  ext_int[5] || Cause_ti;
            Cause_ip[`IP6:`IP2] <=  ext_int[4:0];
        end
    end
    // }}}
    // IP1~IP0{{{
    always @(posedge clk) begin
        if (!rst) begin
            Cause_ip[`IP1:`IP0] <=  'd0;
        end
        else if (mtc0_wen && mtc0_addr==`ADDR_CAUSE) begin
            Cause_ip[`IP1:`IP0] <=  mtc0_wdata[`IP1:`IP0];
        end
    end
    // }}}
    // ExcCode{{{
    reg     [`EXCCODE]  Cause_exccode;
    always @(posedge clk) begin
        if (!rst) begin
            Cause_exccode   <=  `EXCCODE_LEN'd0;
        end
        else if (isExceptionInNormal) begin
            Cause_exccode   <=  ExcCode;
        end
    end
    // }}}
    assign Cause = {Cause_bd,Cause_ti,14'b0,Cause_ip,1'b0,Cause_exccode,2'b0};
    //}}}
    ////////////////    EPC     ////////////////{{{
    reg     [`SINGLE_WORD]      epc;
    always @(posedge clk) begin
        if (isExceptionInNormal) begin
            epc <=  isDelaySlot ? exceptPC - 32'h4 : exceptPC;
        end
        else if (mtc0_wen && mtc0_addr==`ADDR_EPC) begin
            epc <=  mtc0_wdata;
        end
    end
    assign EPC = epc;
    //}}}
    ////////////////    BadVAdder   ////////////////{{{
    reg     [`SINGLE_WORD]      badVaddr;
    wire    badVaddrCode = (ExcCode==`ADEL)||(ExcCode==`ADES)||
                            (ExcCode==`TLBL)||(ExcCode==`TLBS)||(ExcCode==`MOD);
    always @(posedge clk) begin
        if (isExceptionInNormal && badVaddrCode) begin
            badVaddr    <=  exceptBadVAddr;
        end
    end
    assign BadVAdder = badVaddr;
    //}}}
    ////////////////    Count   ////////////////{{{
    reg     [`SINGLE_WORD]      count;
    reg                         tick;
    always @(posedge clk) begin
        if (!rst) begin
            tick    <=  1'b0;
        end
        else begin
            tick    <=  !tick;
        end

        if (!rst) begin
            count   <=  'd0;
        end
        else if (mtc0_wen && mtc0_addr==`ADDR_COUNT) begin
            count   <=  mtc0_wdata;
        end
        else if (tick) begin
            count   <= count + 1'b1;
        end
    end
    assign Count = count;
    //}}}
    ////////////////    Compare   ////////////////{{{
    reg [`SINGLE_WORD]  compare;
    always @(posedge clk) begin
        if (!rst) begin
            compare <=  `ZEROWORD;
        end
        else if (mtc0_wen && mtc0_addr==`ADDR_COMPARE) begin
            compare <=  mtc0_wdata;
        end
    end
    assign Compare = compare;
    //}}}
    ////////////////    Index   ////////////////{{{
    // P{{{
    reg     Index_p;
    always @(posedge clk) begin
        if (!rst) begin
            Index_p     <=  1'b0;
        end
        else if (TLBPwrite) begin
            Index_p     <=  tlbwIndex[`P];
        end
    end
    // }}}
    // Index{{{
    reg     [`INDEX]    Index_index;
    always @(posedge clk) begin
        if (!rst) begin
            Index_index <=  'b0;
        end
        else if (TLBPwrite) begin
            Index_index <=  tlbwIndex[`INDEX];
        end
    end
    // }}}
    assign Index = {Index_p,{32-1-`TLB_ENTRY_NUM{1'b0}},Index_index};
    //}}}
    ////////////////    EntryLo0   ////////////////{{{
    reg     [`SINGLE_WORD]  entryLo0;
    always @(posedge clk) begin
        if (!rst) begin
            entryLo0    <=  `ZEROWORD;
        end
        else if (mtc0_wen && mtc0_addr==`ADDR_ENRTYLO0) begin
            entryLo0    <=  mtc0_wdata;
        end
        else if (TLBRwrite) begin
            entryLo0    <=  tlbwEntryLo0;
        end
    end
    assign EntryLo0 = entryLo0;
    // }}}
    ////////////////    EntryLo1   ////////////////{{{
    reg     [`SINGLE_WORD]  entryLo1;
    always @(posedge clk) begin
        if (!rst) begin
            entryLo1    <=  `ZEROWORD;
        end
        else if (mtc0_wen && mtc0_addr==`ADDR_ENRTYLO1) begin
            entryLo1    <=  mtc0_wdata;
        end
        else if (TLBRwrite) begin
            entryLo1    <=  tlbwEntryLo1;
        end
    end
    assign EntryLo1 = entryLo1;
    //}}}
    ////////////////    EntryHi   ////////////////{{{
    reg     [`SINGLE_WORD]  entryHi;
    always @(posedge clk) begin
        if (!rst) begin
            entryHi     <=  `ZEROWORD; 
        end
        else if (mtc0_wen && mtc0_addr==`ADDR_ENRTYHI) begin
            entryHi     <=  mtc0_wdata;
        end
        else if (TLBRwrite) begin
            entryHi     <=  tlbwEntryHi;
        end
    end
    assign EntryHi  =  entryHi;
    //}}}
    ////////////////    Config   ////////////////{{{
    reg     [`K0]   Config_k0;
    always @(posedge clk) begin
        if (!rst) begin
        `ifdef OPEN_CACHE
            Config_k0   <=  `CACHED;
        `else 
            Config_k0   <=  `UNCACHED;
        `endif
        end
        else if (mtc0_wen && mtc0_addr==`ADDR_CONFIG) begin
            Config_k0   <=  mtc0_wdata[`K0];
        end
    end
    assign Config = {1'b1,15'b0,1'b0,2'b0,3'b0,3'b1,4'b0,Config_k0};
    //}}}
    ////////////////    Config1   ////////////////{{{
    assign Config1 = {1'b1,`MMU_SIZE,`IS,`IL,`IA,`DS,`DL,`DA,7'b0};
    //}}}
    // CP0的输出{{{
    assign  CP0_nonBlockMark_w_o = nonBlockMark;
    assign  CP0_readData_w_o =  ({32{mfc0_addr==`ADDR_STATUS}}      & Status)       | 
                            ({32{mfc0_addr==`ADDR_CAUSE}}       & Cause )       |
                            ({32{mfc0_addr==`ADDR_EPC}}         & EPC   )       |
                            ({32{mfc0_addr==`ADDR_BADVADDR}}    & BadVAdder)    |
                            ({32{mfc0_addr==`ADDR_COUNT}}       & Count)        |
                            ({32{mfc0_addr==`ADDR_COMPARE}}     & Compare)      |
                            ({32{mfc0_addr==`ADDR_INDEX}}       & Index)        |
                            ({32{mfc0_addr==`ADDR_ENRTYLO0}}    & EntryLo0)     |
                            ({32{mfc0_addr==`ADDR_ENRTYLO1}}    & EntryLo1)     |
                            ({32{mfc0_addr==`ADDR_ENRTYHI}}     & EntryHi)      |
                            ({32{mfc0_addr==`ADDR_CONFIG}}      & Config)       |
                            ({32{mfc0_addr==`ADDR_CONFIG1}}     & Config1)      ;
    wire    writeK0 = mtc0_wen && (mtc0_addr==`ADDR_CONFIG);
    assign CP0_excOccur_w_o  =  isExceptionInNormal || eret || writeK0;
    assign CP0_excDestPC_w_o =  isExceptionInNormal ? 32'hbfc00380 :
                                eret ? EPC : 
                                writeK0 ? (exceptPC + 32'd4) : 32'b0;
    assign CP0_Status_w_o = Status;
    assign CP0_Cause_w_o = Cause;
    assign CP0_Config_w_o = Config;
    assign CP0_EntryHi_w_o = EntryHi; 
    assign CP0_EntryLo0_w_o = EntryLo0; 
    assign CP0_EntryLo1_w_o = EntryLo1; 
    //assign CP0_PageMask_w_i = PageMask; TODO
    assign CP0_Index_w_o = Index; 
    // assign CP0_Random_w_i = Random; TODO 

    // }}}
endmodule
