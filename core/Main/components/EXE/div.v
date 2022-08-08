module div (
    input   wire        clk,
    input	wire        rst,
    input   wire        div,//tvalid
    input   wire        div_signed, //{0:无符号,1:有符号}
    input   wire        [31:0] x,y,
    output  wire        div_tready,
    output  wire        [31:0] s,r,
    output  wire        complete,
    output  wire        [5:0] timer_out
);
/*====================Variable Declaration====================*/
wire x_sign,y_sign;
wire first;
wire [31:0] x_abs,y_abs;
reg [5:0] timer; 
reg [31:0] divisor,quotient_iter;
reg [63:0] minuend;
wire reminder_sign,quotient_sign;
reg reminder_sign_r,quotient_sign_r;
wire  [31:0]  quotient_temp;
wire  [63:0]  minuend_back;
wire pre_complete;
reg  have_data;
reg [31:0] quotient_temp_r;
reg [31:0] minuend_back_r;
reg pre_complete_r;
/*====================Function Code====================*/
assign div_tready = div&&(pre_complete_r||(!have_data));
assign x_sign = x[31]&&div_signed;
assign y_sign = y[31]&&div_signed;
assign x_abs = ({32{x_sign}}^x) + x_sign;
assign y_abs = ({32{y_sign}}^y) + y_sign; 
assign first = !(|timer);
assign quotient_sign = (x[31]^y[31]) && div_signed;
assign reminder_sign = x[31] && div_signed;

always @(posedge clk ) begin
    if (!(rst)||pre_complete_r) begin
        divisor <= 32'hffff_ffff;
        minuend <= 64'b0;
        timer = 6'b0;
        quotient_iter <= 32'b0;
        reminder_sign_r <= 1'b0;
        quotient_sign_r <=1'b0;
        have_data <= 1'b0;
    end
    else if (div_tready) begin
        timer <= 1'b1;
        minuend <= {32'b0,x_abs};
        divisor <= y_abs;
        quotient_iter <= 32'b0; 
        reminder_sign_r <= reminder_sign;
        quotient_sign_r <= quotient_sign;
        have_data <= 1'b1;
    end
    else if (have_data) begin
        timer <= timer + 1'b1;
        minuend <= minuend_back;
        quotient_iter <= quotient_temp;
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
always @(posedge clk ) begin
    if (!(rst)||pre_complete_r) begin
        quotient_temp_r <= 32'b0;
        minuend_back_r <= 32'b0;
        pre_complete_r <= 1'b0;
    end
    else begin
        quotient_temp_r <= quotient_temp;
        minuend_back_r <= minuend_back[63:32];
        pre_complete_r <= pre_complete;
    end
end
assign s = quotient_sign_r ? (~quotient_temp_r+1'b1) : quotient_temp_r;
assign r = reminder_sign_r ? (~minuend_back_r+1'b1) : minuend_back_r;
assign complete = pre_complete_r || (!have_data);
assign timer_out = timer;
endmodule

