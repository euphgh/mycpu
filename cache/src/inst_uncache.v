`timescale 1ns / 1ps
`include "../Cacheconst.vh"
module inst_uncache(
    input         clk          ,
    input         rst          , 

    input          inst_req     ,
    input  [31 :0] inst_addr    ,
    output [127:0] inst_rdata   ,
    output         inst_addr_ok ,
    output         inst_data_ok ,
    
    output [3 :0] arid         ,
    output [31:0] araddr       ,
    output [3 :0] arlen        ,
    output [2 :0] arsize       ,
    output [1 :0] arburst      ,
    output [1 :0] arlock       ,
    output [3 :0] arcache      ,
    output [2 :0] arprot       ,
    output        arvalid      ,
    input         arready      ,
             
    input  [3 :0] rid          ,
    input  [31:0] rdata        ,
    input  [1 :0] rresp        ,
    input         rlast        ,
    input         rvalid       ,
    output        rready
);

    //此部分只做读操作
    reg        last_req        ;
    reg [31:0] last_addr       ;
    reg        last_arvalid    ;
    reg [31:0] buf_rdata [3:0] ;
    reg        buf_valid       ;
    reg [2 :0] fill_counter    ;

    assign inst_addr_ok = inst_req && (last_req ? inst_data_ok : 1'b1);
    assign inst_data_ok = last_req && buf_valid;
    assign inst_rdata   = {buf_rdata[3],buf_rdata[2],buf_rdata[1],buf_rdata[0]}; 
    
    // req
    always @(posedge clk ) begin
        if (!rst) begin
            last_req <= 1'b0;
        end
        else if (inst_addr_ok || inst_data_ok) begin
            last_req <= inst_req;
        end
    end

    // addr
    always @(posedge clk ) begin
        if (!rst) begin
            last_addr <= 32'b0;
        end
        else if (inst_addr_ok) begin
            last_addr <= inst_addr;
        end
    end

    //arvalid
    always @(posedge clk ) begin
        if (!rst) begin
            last_arvalid <= 1'b0;
        end
        else if (inst_addr_ok) begin
            last_arvalid <= 1'b1;
        end
        else if (arready) begin
            last_arvalid <= 1'b0;
        end
    end

    //data
    always @(posedge clk ) begin
        if (!rst) begin
            buf_rdata[0] <= 32'b0;
            buf_rdata[1] <= 32'b0;
            buf_rdata[2] <= 32'b0;
            buf_rdata[3] <= 32'b0;
            buf_valid    <= 1'b0 ;
            fill_counter <= 2'b0 ;
        end
        else if ((rid == 4'd0) && rvalid) begin
            buf_rdata[fill_counter] <= rdata           ;
            fill_counter            <= fill_counter + 1;
            if (rlast) begin
                buf_valid <= 1'b1;
            end
        end
        else if (inst_data_ok) begin
            buf_valid    <= 1'b0 ;
            fill_counter <= 2'b0 ; 
        end
    end

    //axi interface
    assign arid    = 4'd0;
    assign araddr  = last_addr;
    assign arlen   = 4'd3;
    assign arsize  = 3'd2;
    assign arburst = 3'd01;
    assign arlock  = 2'd0;
    assign arcache = 4'd0;
    assign arprot  = 3'd0;
    assign arvalid = last_arvalid; //接收到地址后下个周期表明arvalid，开始传输，并在传输开始后拉低

    assign rready  = 1'b1;
    
endmodule