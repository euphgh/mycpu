// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/16 11:55
// Last Modified : 2022/08/04 14:49
// File Name     : MultiDivideUnit.v
// Description   : 乘除模块
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/07/16   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "MyDefines.v"
module MultiDivideUnit(
    input	wire	clk,
    input	wire	rst,
    input	wire	                    mulrReq,         // 直连乘法的请求
    output	wire	                    mulr_data_ok,    // 直连乘法完成
    input	wire                        MduReq,
    input	wire	                    cancel,
    input	wire    [2*`SINGLE_WORD]    MDU_oprand, 
    input	wire    [2*`SINGLE_WORD]    MDU_HiLoData, 
    input	wire	[`MDU_REQ]          MDU_operator,
    output	wire                        MDU_Oprand_ok,  //操作数ok
    output	wire                        MDU_data_ok,    //计算结果ok
    output	wire	[`HILO]             MDU_writeEnable,
    output	reg	                        HiLo_busy,
    output	wire	[2*`SINGLE_WORD]    MDU_writeData_p
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
    wire                        mulReq                          ;
    wire                        isSignedMul                     ;// unresolved
    wire                        isAccumlate                     ;// unresolved
    wire                        add_sub_op                      ;// unresolved
    wire                        mulOprand_ok                    ;
    wire                        mulData_ok                      ;
    wire [2*`SINGLE_WORD]       mulRes                          ;
    wire                        divReq                          ;// unresolved
    wire                        isSignedDiv                     ;// unresolved
    wire [`SINGLE_WORD]         divident_i                      ;// unresolved
    wire [`SINGLE_WORD]         divisor_i                       ;// unresolved
    wire                        div_oprand_ok                       ;// unresolved
    wire [`SINGLE_WORD]         quotient_o                      ;
    wire [`SINGLE_WORD]         reminder_o                      ;
    wire                        div_data_ok                     ; // WIRE_NEW
    //WIRE_DEL: Wire isAccessible has been deleted.
    //WIRE_DEL: Wire timer_o has been deleted.
    //End of automatic wire
    //End of automatic define
    wire [`SINGLE_WORD]         oprand_up   [3:0]               ;
    `UNPACK_ARRAY(`SINGLE_WORD_LEN,2,oprand_up,MDU_oprand)
/*}}}*/
    MyMultiplier MyMultiplier_u(/*{{{*/
        /*autoinst*/
        .clk                    (clk                            ), //input
        .rst                    (rst                            ), //input
        .mulReq                 (mulReq                         ), //input
        .isSignedMul            (isSignedMul                    ), //input
        .add_sub_op             (add_sub_op                     ), //input
        .isAccumlate            (isAccumlate                    ), //input
        .cancel                 (cancel                         ), //input
        .mulOprand              (MDU_oprand                     ), //input
        .HiLoData               (MDU_HiLoData                   ), //input
        .mulOprand_ok           (mulOprand_ok                   ), //output
        .mulData_ok             (mulData_ok                     ), //output
        .mulRes                 (mulRes[2*`SINGLE_WORD]         )  //output
    );
    assign mulReq       = (mulrReq || MDU_operator[`MUL_REQ] || MDU_operator[`ACCUM_REQ]) && MduReq && !HiLo_busy;
    assign mulr_data_ok = mulData_ok;
    assign isSignedMul  = MDU_operator[`MUL_SIGN];
    assign add_sub_op   = MDU_operator[`ACCUM_OP];
    assign isAccumlate  = MDU_operator[`ACCUM_REQ];
    /*}}}*/
    Divider Divider_u(/*{{{*/
        /*autoinst*/
        .clk                    (clk                            ), //input
        .rst                    (rst                            ), //input
        .cancel                 (cancel                         ), //input // INST_NEW
        .divReq                 (divReq                         ), //input
        .isSignedDiv            (isSignedDiv                    ), //input
        .divident_i             (divident_i[`SINGLE_WORD]       ), //input
        .divisor_i              (divisor_i[`SINGLE_WORD]        ), //input
        .div_oprand_ok          (div_oprand_ok                  ), //output
        .quotient_o             (quotient_o[`SINGLE_WORD]       ), //output
        .reminder_o             (reminder_o[`SINGLE_WORD]       ), //output
        .div_data_ok            (div_data_ok                    )  //output
    );
    assign divReq       = MDU_operator[`DIV_REQ] && MduReq && !HiLo_busy;
    assign isSignedDiv  = MDU_operator[`DIV_SIGN];
    assign divident_i   = oprand_up[0];
    assign divisor_i    = oprand_up[1];
    /*}}}*/ 
    // HiLo模块和MDU模块的交互{{{
    always @(posedge clk) begin
        if(!rst || cancel || MDU_data_ok) begin
            HiLo_busy   <=  `FALSE;
        end
        else if (MDU_Oprand_ok && MduReq) begin
            HiLo_busy   <=  `TRUE;
        end 
    end
/*}}}*/
    assign MDU_Oprand_ok =  (MDU_operator[`DIV_REQ] ?   div_oprand_ok :
                            (mulReq) ? mulOprand_ok :  
                             MDU_operator[`MT_REQ]  ?   1'b1 : 1'b0) && (MduReq && !HiLo_busy);

    assign MDU_data_ok =  !cancel && (div_data_ok||mulData_ok||(MDU_Oprand_ok && MDU_operator[`MT_REQ]));

    assign MDU_writeEnable = (div_data_ok||mulData_ok) ? 2'b11 : {MDU_operator[`MT_DEST],!MDU_operator[`MT_DEST]};
    assign MDU_writeData_p[31:0] =   div_data_ok ? quotient_o :
                                mulData_ok  ? mulRes[31:0] : MDU_oprand[31:0];
    assign MDU_writeData_p[63:32] =   div_data_ok ? reminder_o :
                                mulData_ok  ? mulRes[63:32]: MDU_oprand[31:0];
endmodule

