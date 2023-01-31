// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/15 20:49
// Last Modified : 2022/07/31 20:43
// File Name     : MyMultiplier.v
// Description   :
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/07/15   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "../../../MyDefines.v"
module MyMultiplier(
    input	wire	                    clk,
    input	wire	                    rst,
    input	wire	                    mulReq,         // 表示有mult,madd类的计算
    input	wire	                    cancel,
    input	wire	                    isSignedMul,
    input	wire	                    isAccumlate,    // 是否是累加计算
    input	wire	                    add_sub_op,     // 表示累加1'b1,累减1'b0
    input	wire	[2*`SINGLE_WORD]    mulOprand,
    input	wire	[2*`SINGLE_WORD]    HiLoData,
    output	wire	                    mulOprand_ok,   // 握手信号
    output	wire                        mulData_ok,     // 表示完成运算
    output	wire	[2*`SINGLE_WORD]    mulRes
);
    /*autodef*/
/*{{{*/
    //Start of automatic define
    //Start of automatic reg
    //Define flip-flop registers here
    //Define combination registers here
    //End of automatic reg
    //Start of automatic wire
    //Define assign wires here
    //Define instance wires here
    wire [`SINGLE_WORD]             add_a       ;
    wire [`SINGLE_WORD]             add_b       ;
    wire [3:0]                      adder_op    ;
    wire [`SINGLE_WORD]             add_res     ;
    wire                            overflow    ;
    //End of automatic wire
    //End of automatic define
    /*}}}*/
    // 一般乘法计算{{{
    wire                    crFlag              ;
    wire                    cin_i               ;
    wire [1+`SINGLE_WORD]   oprand          [1:0];
    wire [`SINGLE_WORD]     mulOprand_up    [3:0];
    wire [65:0]             res                 ;
    reg  [3:0]              timer               ;   // 计算时间
    reg                     start               ;   // 表示确认接受
    `UNPACK_ARRAY(`SINGLE_WORD_LEN,2,mulOprand_up,mulOprand)
    generate
        for (genvar i = 0; i < 2; i=i+1) begin
            assign oprand[i] = {isSignedMul && mulOprand_up[i][31],mulOprand_up[i]};
        end
    endgenerate

    ip_multiplier Multiplier_u(
        /*autoinst*/
        .clk                    (clk), //input */
        .rst                    (rst),
        .A                      (oprand[0]), //input */
        .B                      (oprand[1]), //input */
        .P                      (res)  //output */
    ); 

    wire [2*`SINGLE_WORD]   multOnly_data = res[63:0];
/*}}}*/
    adder #(.BUS(`SINGLE_WORD_LEN)) adder_u (/*{{{*/
        /*autoinst*/
        .add_a                  (add_a[`SINGLE_WORD]            ), //input
        .add_b                  (add_b[`SINGLE_WORD]            ), //input
        .adder_op               (adder_op[3:0]                  ), //input
        .add_res                (add_res[`SINGLE_WORD]          ), //output
        .crFlag                 (crFlag                         ),
        .cin_i                  (cin_i                          ),
        .overflow               (overflow                       )  //output
    );
/*}}}*/
    // 状态保存
    reg [3:0] upBound ;
    reg isAccumlate_r;
    reg add_sub_op_r;
    always @(posedge clk) begin
        if (!rst || cancel) begin
            start   <=  `FALSE;
            timer   <=  'b0;
            upBound <=  'd2;
            isAccumlate_r   <=  `FALSE;
            add_sub_op_r    <=  `FALSE;
        end
        else if (mulReq && mulOprand_ok) begin
            start   <=  `TRUE;
            timer   <=  'b1;
            upBound <= isAccumlate ? 'd4 : 'd2;
            isAccumlate_r   <=  isAccumlate;
            add_sub_op_r    <=  add_sub_op;

        end 
        else if (start==`TRUE) begin
            timer   <=  timer < upBound ? timer + 'b1 : 'b0; 
            start   <=  timer < upBound ? `TRUE : `FALSE;
        end 
    end
    // 段间逻辑和段间寄存器 {{{
    reg [`SINGLE_WORD]  multiRes;
    reg [`SINGLE_WORD]  adderRes;
    reg                 savedCin;
    assign add_a = (timer==2) ? HiLoData[31:0]  : HiLoData[63:32];
    assign add_b = (timer==2)   ? (add_sub_op_r ? res[31:0] : ~res[31:0])
                                : (add_sub_op_r ? multiRes  : ~multiRes ) ;
    assign cin_i = (timer==2) ? !add_sub_op_r   : savedCin;
    assign adder_op = 4'd8;
    always @(posedge clk) begin
        if (!rst || cancel) begin
            multiRes    <=  `ZEROWORD;
            adderRes    <=  `ZEROWORD;
            savedCin    <=  1'b0;
        end
        else if (timer==2) begin
            multiRes    <=  res[63:32];
            adderRes    <=  add_res;
            savedCin    <=  crFlag;
        end 
    end
    wire    [2*`SINGLE_WORD]   accuRes = {add_res,adderRes};
/*}}}*/
    assign mulOprand_ok = mulReq && (!start || mulData_ok);
    assign mulData_ok   = (timer==upBound) && start;
    assign mulRes       = isAccumlate_r ? accuRes : multOnly_data;
endmodule

