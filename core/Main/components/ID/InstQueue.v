// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/06/30 09:24
// Last Modified : 2022/08/02 18:55
// File Name     : InstQueue.v
// Description   : 用于收集指令，根据指令使能进行装入，根据指令需求进行输出
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/06/30   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
// 输出的指令包直接写在发射解码器上，通过解码器逻辑，单发还是双发，选择性的清
// 除掉目标指令。只有当指令信息流入下一个段间寄存器，才能将该指令从IQ中彻底清
// 楚
`timescale 1ns/1ps
`include "MyDefines.v"
module InstQueue (
    input   wire            clk,
    input   wire            rst,
    // 刷新流水线的信号{{{
    input	wire	                        SBA_flush_w_i,            
    input	wire                            CP0_excOccur_w_i,	
/*}}}*/
    //////////////////////////////////////////////////
    //////////////     寄存器输入      ///////////////{{{
    //////////////////////////////////////////////////
    // 取指令控制
    input	wire	[1:0]                   ID_upDateMode_i,    // 输入数值2'b00,2'b01,2'b11，将队头的x个数据出队
    // 分支确认信号
    input   wire    [4*`SINGLE_WORD]        IF_predDest_p_i,
    input   wire    [3:0]                   IF_predTake_p_i,
    input   wire    [4*`ALL_CHECKPOINT]     IF_predInfo_p_i,
    // 四条指令的基地址
    input   wire	[`SINGLE_WORD]          IF_instBasePC_i,
    // 送入指令FIFO的指令    
    input   wire	                        IF_valid_i,
    input   wire    [3:0]                   IF_instEnable_i,
    input   wire    [`FOUR_WORDS]           IF_inst_p_i,
    input   wire    [2:0]                   IF_instNum_i,
    // 送入指令FIFO的异常信息
    input	wire                            IF_hasException_i,
    input	wire    [`EXCCODE]              IF_ExcCode_i,
    input	wire                            IF_isRefill_i,
    /*}}}*/
    //////////////////////////////////////////////////
    //////////////     寄存器输出      ///////////////{{{
    //////////////////////////////////////////////////
    // 取出指令
    output	reg     [`IQ_VALID]                 IQ_supplyValid  ,   // 可选宏定义三种
    output	wire    [2*`SINGLE_WORD]            IQ_inst_p  ,
    output	wire    [2*`SINGLE_WORD]            IQ_VAddr_p  ,
    output	wire    [1:0]                       IQ_hasException_p  ,
    output  wire    [2*`EXCCODE]                IQ_ExcCode_p  ,
    output  wire    [1:0]                       IQ_isRefill_p  ,
    output  wire    [2*`SINGLE_WORD]            IQ_predDest_p  ,
    output  wire    [1:0]                       IQ_predTake_p  ,
    output  wire    [2*`ALL_CHECKPOINT]         IQ_checkPoint_p  ,

    output  wire                                IQ_full  ,
    output  wire                                IQ_empty  ,
    output	wire	                            ID_stopFetch_o,
    output  wire    [`IQ_POINT]                 IQ_number_w  
    /*}}}*/
);
    // 计数器比实际多一位,为了充分利用队列容量
    reg [`IQ_POINT]  head;
    reg [`IQ_POINT]  tail;
    wire    needClear = SBA_flush_w_i || CP0_excOccur_w_i;
    reg [`IQ_LENTH] queue [`IQ_CAPABILITY-1:0];
    // 自动定义{{{
    /*autodef*/
    //Start of automatic define
    //Start of automatic reg
    //Define flip-flop registers here
    //Define combination registers here
    //End of automatic reg
    //Start of automatic wire
    //Define assign wires here
    wire                        enough                          ;// unresolved
    //Define instance wires here
    //End of automatic wire
    //End of automatic define
/*}}}*/
    assign IQ_number_w   = tail-head;
    //如果不考虑用于保存以及请求的指令的空隙，tail+1 == head表示队列,
    assign IQ_empty         =   tail == head;
    assign IQ_full          =   (tail[`IQ_NUMBER] == head[`IQ_NUMBER]) && 
                                (tail[`IQ_POINT_SIGN]!=head[`IQ_POINT_SIGN]);
    assign ID_stopFetch_o   =   (IQ_number_w>=`IQ_POINT_BIT 5) && !needClear;
    wire    [`SINGLE_WORD]          IF_inst_up          [3:0];
    wire    [`SINGLE_WORD]          IF_predDest_up      [3:0];
    wire    [0:0]                   IF_predTake_up      [3:0];
    wire    [`ALL_CHECKPOINT]       IF_predInfo_up      [3:0];
    wire	[`SINGLE_WORD]          IF_instBasePC_up    [3:0];
    `UNPACK_ARRAY(`SINGLE_WORD_LEN,4,IF_inst_up,IF_inst_p_i)
    `UNPACK_ARRAY(`SINGLE_WORD_LEN,4,IF_predDest_up,IF_predDest_p_i)
    `UNPACK_ARRAY(1,4,IF_predTake_up,IF_predTake_p_i)
    `UNPACK_ARRAY(`ALL_CHECKPOINT_LEN,4,IF_predInfo_up,IF_predInfo_p_i)
    assign IF_instBasePC_up[0] = IF_instBasePC_i;
    assign IF_instBasePC_up[1] = {IF_instBasePC_i[31:4],IF_instBasePC_i[3:2]+2'b01,IF_instBasePC_i[1:0]};
    assign IF_instBasePC_up[2] = {IF_instBasePC_i[31:4],IF_instBasePC_i[3:2]+2'b10,IF_instBasePC_i[1:0]};
    assign IF_instBasePC_up[3] = {IF_instBasePC_i[31:4],IF_instBasePC_i[3:2]+2'b11,IF_instBasePC_i[1:0]};
    //写入逻辑{{{
    always @(posedge clk) begin
        if(!rst || needClear) begin
            tail        <= 'd0;
        end
        else if (IF_valid_i) begin
            tail        <= tail + {{$clog2(`IQ_CAPABILITY)-3{1'b0}},IF_instNum_i};
        end
    end
    wire    [`IQ_LENTH] packedInfo  [3:0];
    generate
        for (genvar i = 0; i < 4; i = i+1)	begin
            assign packedInfo[i] = {
                    IF_isRefill_i,
                    IF_ExcCode_i,
                    IF_predInfo_up[i],
                    IF_hasException_i,
                    IF_predTake_up[i],
                    IF_predDest_up[i],
                    IF_inst_up[i],
                    IF_instBasePC_up[i]
                    };
        end
    endgenerate
    wire ok_toWrite = rst && IF_valid_i;
    always @(posedge clk) begin/*{{{*/
        if (!ok_toWrite) begin end
        else if (IF_instEnable_i[3]) begin
            queue[tail[`IQ_NUMBER]+`IQ_NUMBER_BIT 3] <= packedInfo[3];
            queue[tail[`IQ_NUMBER]+`IQ_NUMBER_BIT 2] <= packedInfo[2];
            queue[tail[`IQ_NUMBER]+`IQ_NUMBER_BIT 1] <= packedInfo[1];
            queue[tail[`IQ_NUMBER]+`IQ_NUMBER_BIT 0] <= packedInfo[0];
        end
        else if (IF_instEnable_i[2]) begin
            queue[tail[`IQ_NUMBER]+`IQ_NUMBER_BIT 2] <= packedInfo[2];
            queue[tail[`IQ_NUMBER]+`IQ_NUMBER_BIT 1] <= packedInfo[1];
            queue[tail[`IQ_NUMBER]+`IQ_NUMBER_BIT 0] <= packedInfo[0];
        end
        else if (IF_instEnable_i[1]) begin
            queue[tail[`IQ_NUMBER]+`IQ_NUMBER_BIT 1] <= packedInfo[1];
            queue[tail[`IQ_NUMBER]+`IQ_NUMBER_BIT 0] <= packedInfo[0];
        end
        else if (IF_instEnable_i[0]) begin
            queue[tail[`IQ_NUMBER]+`IQ_NUMBER_BIT 0] <= packedInfo[0];
        end
    end/*}}}*/
/*}}}*/
    //读出逻辑{{{
    wire    [2:0] IF_supplyNum = {3{IF_valid_i}} & (  IF_instEnable_i[3] ? 3'd4 :
                                                IF_instEnable_i[2] ? 3'd3 :
                                                IF_instEnable_i[1] ? 3'd2 :
                                                IF_instEnable_i[0] ? 3'd1 : 3'd0);
    wire    [`IQ_POINT] nextNumber = IQ_number_w + IF_supplyNum - ID_upDateMode_i[0] - ID_upDateMode_i[1];
    assign enough = nextNumber >= 'd2;
    always @(posedge clk) begin
        if (!rst || needClear) begin
            head    <=  'd0;
            IQ_supplyValid   <= 2'b0;
        end
        else begin
            head    <=  head +
                {{$clog2(`IQ_CAPABILITY){1'b0}},ID_upDateMode_i  [0]} +
                {{$clog2(`IQ_CAPABILITY){1'b0}},ID_upDateMode_i  [1]} ;
            IQ_supplyValid   <= enough ? `DUAL_ISSUE : nextNumber[1:0];
        end
    end
    // 少一周期的组合逻辑写法{{{
    wire    [`SINGLE_WORD]              IQ_VAddr_up             [1:0];  /*{{{*/
    wire    [`SINGLE_WORD]              IQ_inst_up              [1:0];  
    wire	[0:0]                       IQ_hasException_up      [1:0];  
    wire    [`EXCCODE]                  IQ_ExcCode_up           [1:0];  
    wire    [`SINGLE_WORD]              IQ_predDest_up          [1:0];  
    wire    [0:0]                       IQ_predTake_up          [1:0];  
    wire    [`ALL_CHECKPOINT]           IQ_checkPoint_up        [1:0];  
    wire    [0:0]                       IQ_isRefill_up          [1:0];
    wire    [`IQ_NUMBER_WID]            number [1:0];
    assign  number[0] = `IQ_NUMBER_BIT 0;
    assign  number[1] = `IQ_NUMBER_BIT 1;/*}}}*/
    generate
        for (genvar i = 0; i < 2; i = i+1)	begin
            assign  {
                IQ_isRefill_up[i],
                IQ_ExcCode_up[i],
                IQ_checkPoint_up[i],
                IQ_hasException_up[i],
                IQ_predTake_up[i],
                IQ_predDest_up[i],
                IQ_inst_up[i],
                IQ_VAddr_up[i]
                }   =  queue[head[`IQ_NUMBER]+number[i]];
        end
    endgenerate
    // }}}
    // 多一周期的寄存器写法{{{
    /*reg     [`SINGLE_WORD]              IQ_VAddr_up             [1:0];  */
    /*reg     [`SINGLE_WORD]              IQ_inst_up              [1:0];  */
    /*reg	    [0:0]                       IQ_hasException_up      [1:0];  */
    /*reg     [`EXCCODE]                  IQ_ExcCode_up           [1:0];  */
    /*reg     [`SINGLE_WORD]              IQ_predDest_up          [1:0];  */
    /*reg     [0:0]                       IQ_predTake_up          [1:0];  */
    /*reg     [`ALL_CHECKPOINT]           IQ_checkPoint_up        [1:0];  */
    /*reg     [0:0]                       IQ_isRefill_up          [1:0];*/
    /*generate*/
    /*genvar j;*/
    /*for (j = 0; j < 2; j=j+1)	begin*/
        /*always @(posedge clk) begin*/
            /*if (!rst) begin*/
                /*IQ_VAddr_up[j]              <=  `ZEROWORD;*/
                /*IQ_inst_up[j]               <=  `ZEROWORD;*/
                /*IQ_hasException_up[j]       <=  `FALSE;*/
                /*IQ_ExcCode_up[j]            <=  `NOEXCCODE;*/
                /*IQ_predDest_up[j]           <=  `ZEROWORD;*/
                /*IQ_predTake_up[j]           <=  `FALSE;*/
                /*IQ_checkPoint_up[j]         <=  0;*/
                /*IQ_isRefill_up[j]           <=  `FALSE;*/
            /*end*/
            /*else if (IQ_supplyValid  [j]) begin*/
                /*{*/
                    /*IQ_VAddr_up[j],*/
                    /*IQ_inst_up[j],*/
                    /*IQ_predDest_up[j],*/
                    /*IQ_predTake_up[j],*/
                    /*IQ_checkPoint_up[j],*/
                    /*IQ_hasException_up[j],*/
                    /*IQ_ExcCode_up[j],*/
                    /*IQ_isRefill_up[j]*/
                    /*}   <=  queue[head+j];*/
            /*end*/
        /*end*/
    /*end*/
    /*endgenerate*/
    // }}}
    `PACK_ARRAY(`SINGLE_WORD_LEN,2,IQ_VAddr_up,IQ_VAddr_p  )
    `PACK_ARRAY(`SINGLE_WORD_LEN,2,IQ_inst_up,IQ_inst_p  )
    `PACK_ARRAY(1,2,IQ_hasException_up,IQ_hasException_p  )
    `PACK_ARRAY(`SINGLE_WORD_LEN,2,IQ_predDest_up,IQ_predDest_p  )
    `PACK_ARRAY(1,2,IQ_predTake_up,IQ_predTake_p  )
    `PACK_ARRAY(`ALL_CHECKPOINT_LEN,2,IQ_checkPoint_up,IQ_checkPoint_p  )
    `PACK_ARRAY(`EXCCODE_LEN,2,IQ_ExcCode_up,IQ_ExcCode_p  )
    `PACK_ARRAY(1,2,IQ_isRefill_up,IQ_isRefill_p)
/*}}}*/
endmodule

