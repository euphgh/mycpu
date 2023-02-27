module ip_multiplier (
    input wire clk,rst,
    input wire [32:0] A,
    input wire [32:0] B,
    output wire [65:0] P
);
    
`ifndef VERILATOR
Multiplier Multiplier_u(
    /*autoinst*/
    .CLK                    (clk), //input */
    .A                      (A), //input */
    .B                      (B), //input */
    .P                      (P)  //output */
); 
`else
    reg [65:0] seg1,seg0;
    always @(posedge clk) begin
        if (!rst) begin
            seg0 <= 0;
            seg1 <= 0;
        end
        else begin
            seg0 <= {{33{A[32]}}, A} * {{33{B[32]}}, B};	// MyMultipler.scala:9:{20,34}
            seg1 <= seg0;
        end
    end
    assign P = seg1;
`endif

endmodule
