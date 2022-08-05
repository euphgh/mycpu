// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        :  Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/12 19:37
// Last Modified : 2022/08/01 10:15
// File Name     : RegFile.v
// Description   : 多端口的寄存器堆,支持4读2写,且前递数据优先读出
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/07/12   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "../../../MyDefines.v"
module RegFile(
    input	wire	clk,
    input	wire	rst,
    // 读端口 
    input	wire	[4*`GPR_NUM]        AB_regReadNum_p_w,         
    output	wire	[4*`SINGLE_WORD]    readData_p_o,        
    // 写端口
    input	wire	                    PBA_writeEnable_w_i,     
    input	wire	[`GPR_NUM]          PBA_writeNum_w_i,        
    input	wire	[`SINGLE_WORD]      PBA_forwardData_w_i,// 先执行的指令回写数据

    input	wire	                    WB_writeEnable_w_i,     
    input	wire	[`GPR_NUM]          WB_writeNum_w_i,        
    input	wire	[`SINGLE_WORD]      WB_forwardData_w_i  // 后执行的指令回写数据
);
    /*autodef*/
    //Start of automatic define
    //Start of automatic reg
    //Define flip-flop registers here
    //Define combination registers here
    //End of automatic reg
    //Start of automatic wire
    //Define assign wires here
    wire                        WAW_coflict                     ;
    //Define instance wires here
    //End of automatic wire
    //End of automatic define

    reg     [`SINGLE_WORD]  regfile         [31:1];
    wire	[`GPR_NUM]  	readNum         [3:0];
    wire	[`SINGLE_WORD]  readData        [3:0];
    wire    [1:0]           hasForward      [3:0];
    wire    [`SINGLE_WORD]  writeData       [1:0];
    wire	[1:0]           writeEnable     ;
    wire	[`GPR_NUM]      writeNum        [1:0]; 


    // 打包和解包
    `UNPACK_ARRAY(`GPR_NUM_LEN,4,readNum,AB_regReadNum_p_w)
    assign writeEnable[0]   = PBA_writeEnable_w_i;
    assign writeEnable[1]   = WB_writeEnable_w_i;
    assign writeData[0]     = PBA_forwardData_w_i;
    assign writeData[1]     = WB_forwardData_w_i;
    assign writeNum[0]      = PBA_writeNum_w_i;
    assign writeNum[1]      = WB_writeNum_w_i;
    assign WAW_coflict  = (writeEnable[0] && writeEnable[1]) && (writeNum[0]==writeNum[1]);
    `PACK_ARRAY(`SINGLE_WORD_LEN,4,readData,readData_p_o)
    // 前递信号生成逻辑{{{
    generate
        for (genvar j = 0; j < 4; j=j+1)	begin
            for (genvar k = 0; k < 2; k=k+1)	begin
                assign hasForward[j][k] = writeEnable[k] && (writeNum[k]==readNum[j]);
            end
        end
    endgenerate
/*}}}*/
    // 读逻辑{{{
    generate
    genvar i;
    for (i = 0; i < 4; i=i+1)	begin
        assign readData[i]  =   !(|readNum[i]) ? `ZEROWORD :
                            (hasForward[i][0]) ? writeData[0] : 
                            (hasForward[i][1]) ? writeData[1] : regfile[readNum[i]];
    end
    endgenerate
    /*}}}*/
    // 写逻辑{{{
    wire double_write = &writeEnable && !WAW_coflict;
    wire single_write_first  = writeEnable[0] && !writeEnable[1];
    wire single_write_second = (writeEnable[1] && !writeEnable[0]) || (&writeEnable && WAW_coflict);
    integer t;
    always @(posedge clk) begin
        if (!rst) begin
        `ifdef CONTINUE
            $readmemh(`REG_FILE, regfile, 1, 31);
        `endif
        `ifndef CONTINUE
            for (t=1; t<32; t=t+1) begin
                regfile[t]  <=  `ZEROWORD; 
            end
        `endif
        end
        else if (double_write) begin
            regfile[writeNum[1]]    <=  writeData[1]; 
            regfile[writeNum[0]]    <=  writeData[0];
        end
        else if (single_write_first) begin
            regfile[writeNum[0]]    <=  writeData[0];
        end
        else if (single_write_second) begin
            regfile[writeNum[1]]    <=  writeData[1]; 
        end
    end
/*}}}*/
endmodule

