`timescale 1ns / 1ps
module inst_tagv_tp#(
    parameter LINE  = 128
)(
    input                       clk   ,
    input                       en    ,
    input                       tagwen,
    input                       valwen,
    input  [$clog2(LINE)-1:0]   index ,
    input  [19            :0]   wtag  ,
    input                       wvalid,
    output [20            :0]   back
);
    reg [19    :0] tag_ram [LINE-1:0];
    reg [LINE-1:0] v_ram ;
    reg [20    :0] tagv_res;

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
