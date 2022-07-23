`timescale 1ns / 1ps
`include "./Cacheconst.vh"
module ic_ft(
    input           clk,
    input           rst,

    //类Sram接口，如果是指令Cache，只进行读操作，而且每次读四个字节，不需要size信号
    input            inst_req         ,
    input            inst_wr          ,
    input  [1 :0]    inst_size        ,
    input  [7 :0]    inst_index       ,
    input  [19:0]    inst_tag         ,
    input            inst_hasException,
    input            inst_unCache     ,
    input  [31 :0]   inst_wdata       ,
    output [127:0]   inst_rdata       ,
    output           inst_index_ok    ,
    output           inst_data_ok     ,

    //  AXI接口信号定义:
    output [3 :0] arid   ,
    output [31:0] araddr ,
    output [7 :0] arlen  ,
    output [31:0] arsize ,
    output [1 :0] arburst,
    output [1 :0] arlock ,
    output [3 :0] arcache,
    output [2 :0] arprot , 
    output        arvalid,
    input         arready,

    input  [3 :0] rid    ,
    input  [31:0] rdata  ,
    input  [1 :0] rresp  ,
    input         rlast  ,
    input         rvalid ,
    output        rready ,

    output [3 :0] awid   ,
    output [31:0] awaddr ,
    output [7 :0] awlen  ,
    output [2 :0] awsize ,
    output [1 :0] awburst,
    output [1 :0] awlock ,
    output [3 :0] awcache,
    output [2 :0] awprot ,
    output        awvalid,
    input         awready,

    output [3 :0] wid    ,
    output [31:0] wdata  ,
    output [3 :0] wstrb  ,
    output        wlast  ,
    output        wvalid ,
    input         wready ,

    input  [3 :0] bid    ,
    input         bvalid ,
    input  [1 :0] bresp  ,
    output        bready 

);
    
    reg       last_req;
    // req
    always @(posedge clk ) begin
        if (!rst) begin
            last_req <= 1'b0;
        end
        else if (inst_index_ok) begin
            last_req <= inst_req;
        end else if (inst_data_ok) begin
            last_req <= 1'b0;
        end
    end


    reg [7:0] index;
    reg       index_valid;
    reg [20:0] tag;
    reg       tag_valid;
    always @(posedge clk ) begin
        if(!rst) begin
            index <= 8'b0;
            index_valid <= 1'b0;
        end
        else if (inst_index_ok) begin
            index <= inst_index;
            index_valid <= 1'b1;
        end
        else begin
            index_valid <= 1'b0;
        end
    end

    always @(posedge clk ) begin
        if(!rst) begin
            tag <= 20'b0;
            tag_valid <= 1'b0;
        end
        else if (index_valid) begin
            tag <= inst_tag;
            tag_valid <= 1'b1;
        end
        else if (arready) begin
            tag_valid <= 1'b0;
        end
    end

    //data
    reg [31:0] buf_rdata [3:0] ;
    reg        buf_valid       ;
    reg [2 :0] fill_counter    ;
    always @(posedge clk ) begin
        if (!rst) begin
            buf_rdata[0] <= 32'b0;
            buf_rdata[1] <= 32'b0;
            buf_rdata[2] <= 32'b0;
            buf_rdata[3] <= 32'b0;
            buf_valid    <= 1'b0 ;
            fill_counter <= 2'b0 ;
        end
        else if ((rid == 4'd4) && rvalid) begin
            buf_rdata[fill_counter] <= rdata           ;
            fill_counter            <= fill_counter + 1;
            if (rlast) begin
                buf_valid <= 1'b1;
            end
        end
        else if (arready) begin
            buf_valid    <= 1'b0 ;
            fill_counter <= 2'b0 ; 
        end
    end
    //axi interface
    assign arid    = 4'd4;
    assign araddr  = {tag,index,4'b0000};
    assign arlen   = 4'd3;
    assign arsize  = 3'd2;
    assign arburst = 3'd01;
    assign arlock  = 2'd0;
    assign arcache = 4'd0;
    assign arprot  = 3'd0;
    assign arvalid = tag_valid; //接收到地址后下个周期表明arvalid，开始传输，并在传输开始后拉低

    assign rready  = 1'b1;


    assign inst_index_ok = inst_req && ((last_req) ? inst_data_ok : 1'b1);
    assign inst_data_ok  = buf_valid;
    assign inst_rdata = {buf_rdata[3],buf_rdata[2],buf_rdata[1],buf_rdata[0]}; 
    
endmodule