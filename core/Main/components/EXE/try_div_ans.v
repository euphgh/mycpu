/*====================Ports Declaration====================*/
module try_div_ans (
    input wire [63:0] minuend,
    input wire [31:0] divisor,
    input wire [5:0] timer,
    input wire [31:0] quotient_iter,
    output wire [31:0] quotient_temp,
    output wire [63:0] minuend_back,
    output wire pre_complete
    );
/*====================Variable Declaration====================*/
wire [32:0] diff;
wire [63:0] minuend_new;
/*====================Function Code====================*/
assign diff = minuend[63:31] - {1'b0,divisor};
assign minuend_new = {diff,minuend[30:0]};
assign quotient_temp = (quotient_iter<<1) + (!diff[32]);
assign minuend_back = (diff[32] ? minuend : minuend_new)<<1;
assign pre_complete = (timer==6'd32);
endmodule