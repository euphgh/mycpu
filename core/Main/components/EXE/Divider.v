// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/15 20:21
// Last Modified : 2022/07/28 10:11
// File Name     : Divider.v
// Description   : 除法器，33周期，包括有符号数和无符号数
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
module Divider (
    input   wire                        clk,
    input	wire                        rst,
    input   wire                        divReq,        //tvalid
    input	wire	                    cancel,
    input   wire                        isSignedDiv, //{0:无符号,1:有符号}
    input   wire        [`SINGLE_WORD]  divident_i,
    input	wire	    [`SINGLE_WORD]  divisor_i,
    output  wire                        div_oprand_ok,
    output  wire        [`SINGLE_WORD]  quotient_o,
    output	wire	    [`SINGLE_WORD]  reminder_o,
    output  wire                        div_data_ok
);

    wire                        x_sign;
    wire                        y_sign;
    wire    [`SINGLE_WORD]      x_abs,y_abs;
    reg     [5:0]               timer; 
    reg     [`SINGLE_WORD]      divisor;
    reg     [`SINGLE_WORD]      quotient_iter;
    reg     [2*`SINGLE_WORD]    minuend;
    wire                        reminder_sign;
    wire                        quotient_sign;
    reg                         reminder_sign_r;
    reg                         quotient_sign_r;
    wire    [`SINGLE_WORD]      quotient_temp;
    wire    [2*`SINGLE_WORD]    minuend_back;
    wire                        pre_complete;
    reg                         have_data;
    
    assign div_oprand_ok = divReq&&(pre_complete||(!have_data));
    assign x_sign = divident_i[31]&&isSignedDiv;
    assign y_sign = divisor_i[31]&&isSignedDiv;
    assign x_abs = ({32{x_sign}}^divident_i) + {31'b0,x_sign};
    assign y_abs = ({32{y_sign}}^divisor_i)  + {31'b0,y_sign}; 
    assign quotient_sign = (divident_i[31]^divisor_i[31]) && isSignedDiv;
    assign reminder_sign = divident_i[31] && isSignedDiv;
    
    always @(posedge clk ) begin
        if (!(rst)||cancel) begin
            divisor <= 32'hffff_ffff;
            minuend <= 64'b0;
            timer   <= 6'b0;
            quotient_iter   <= 32'b0;
            reminder_sign_r <= 1'b0;
            quotient_sign_r <=1'b0;
            have_data <= 1'b0;
        end
        else if (div_oprand_ok) begin
            timer <= 6'b1;
            minuend <= {32'b0,x_abs};
            divisor <= y_abs;
            quotient_iter <= 32'b0; 
            reminder_sign_r <= reminder_sign;
            quotient_sign_r <= quotient_sign;
            have_data <= 1'b1;
        end
        else if (have_data) begin
            timer           <= timer < 'd32 ? timer + 1'b1 : 'b0;
            minuend         <= timer < 'd32 ? minuend_back : 'd0;
            quotient_iter   <= timer < 'd32 ? quotient_temp: 'd0;
            have_data       <= timer < 'd32 ? 1'b1 : 1'b0;
        end
    end
    
    try_div_ans  u_try_div_ans (
        .minuend                 ( minuend         ),
        .divisor                 ( divisor         ),
        .timer                   ( timer           ),
        .quotient_iter           ( quotient_iter   ),
    
        .quotient_temp           ( quotient_temp   ),
        .minuend_back            ( minuend_back    ),
        .pre_complete            ( pre_complete    )
    );
    assign quotient_o = quotient_sign_r ? (~quotient_temp+1'b1) : quotient_temp;
    assign reminder_o = reminder_sign_r ? (~minuend_back[63:32]+1'b1) : minuend_back[63:32];
    assign div_data_ok = pre_complete;
endmodule

