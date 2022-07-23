`timescale 1ns / 1ps

module cache_tagv_tp(
    input           clk,
    input           en,
    input           wen,
    input [6 :0]    index,
    input [19:0]    wdata,
    input           valid,
    output [20:0]   back     
);
    reg [20:0] tagv_ram [127:0];
    reg [20:0] tagv_res;

    always @(posedge clk ) begin
        if (wen) begin
            tagv_ram[index] <= {wdata,valid};
        end
    end
    
    always @(posedge clk) begin
        tagv_res <= tagv_ram[index];
    end
    assign back = tagv_res;
endmodule
