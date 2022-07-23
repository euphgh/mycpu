`timescale 1ns / 1ps

module data_tagv_tp(
    input           clk,
    input           en,
    input           tagwen,
    input           valwen,
    input  [6 :0]   index,
    input  [19:0]   wtag,
    input           wvalid,
    output [20:0]   back     
);
    reg [19 :0] tag_ram [127:0];
    reg [127:0] v_ram ;
    reg [20 :0] tagv_res;

    always @(posedge clk ) begin
        if (tagwen) begin
            tag_ram[index] <= wtag;
        end
    end

    always @(posedge clk ) begin
        if (valwen) begin
            v_ram[index] <= wvalid;
        end
    end
    
    always @(posedge clk) begin
        tagv_res <= {tag_ram[index],v_ram[index]};
    end
    assign back = tagv_res;
endmodule
