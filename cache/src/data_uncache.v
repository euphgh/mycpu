`timescale 1ns / 1ps
`include "../Cacheconst.vh"
module data_uncache (
    input         clk          ,
    input         rst       ,

    input         data_req     ,
    input  [1 :0] data_size    ,
    input         data_wr      ,
    input  [31:0] data_addr    ,
    input  [31:0] data_wdata   ,
    input  [3 :0] data_wstrb   ,
    output [31:0] data_rdata   ,
    output        data_addr_ok ,
    output        data_data_ok ,

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
    output        rready       ,

    output [3 :0] awid         ,
    output [31:0] awaddr       ,
    output [3 :0] awlen        ,
    output [2 :0] awsize       ,
    output [1 :0] awburst      ,
    output [1 :0] awlock       ,
    output [3 :0] awcache      ,
    output [2 :0] awprot       ,
    output        awvalid      ,
    input         awready      ,

    output [3 :0] wid          ,
    output [31:0] wdata        ,
    output [3 :0] wstrb        ,
    output        wlast        ,
    output        wvalid       ,
    input         wready       ,

    input  [3 :0] bid          ,
    input  [1 :0] bresp        ,
    input         bvalid       ,
    output        bready
);
    
    reg         last_req;
    reg [1 :0]  last_size;
    reg         last_op;
    reg [31:0]  last_addr;
    reg [31:0]  last_wdata;
    reg [3 :0]  last_wstrb;
    reg         last_arvalid;
    reg         last_awvalid;
    reg         last_wvalid;

    assign data_addr_ok = data_req && (last_req ? data_data_ok : 1'b1);
    assign data_data_ok = last_req && (last_op ? (bid == `DUNCA_BID) && bvalid : (rid ==`DUNCA_RID) && rvalid);
    assign data_rdata = rdata;

    always @(posedge clk ) begin
        if (!rst) begin
            last_req <= 1'b0;
        end
        else if (data_addr_ok) begin
            last_req <= data_req;
        end
        else if (data_data_ok) begin
            last_req <= 1'b0;
        end
    end

    always @(posedge clk ) begin
        if (!rst) begin
            last_size <= 2'b0;
        end
        else if (data_addr_ok) begin
            last_size <= data_size;
        end
    end

    always @(posedge clk ) begin
        if (!rst) begin
            last_op   <= 1'b0;
        end
        else if (data_addr_ok) begin
            last_op <= data_wr;
        end
    end

    always @(posedge clk ) begin
        if (!rst) begin
            last_addr   <= 32'b0;
        end
        else if (data_addr_ok) begin
            last_addr <= data_addr;
        end
    end

    always @(posedge clk ) begin
        if (!rst) begin
            last_wdata   <= 32'b0;
        end
        else if (data_addr_ok) begin
            last_wdata <= data_wdata;
        end
    end

    always @(posedge clk ) begin
        if (!rst) begin
            last_wstrb   <= 4'b0;
        end
        else if (data_addr_ok) begin
            last_wstrb <= data_wstrb;
        end
    end
    
    //arvalid
    always @(posedge clk ) begin
        if (!rst) begin
            last_arvalid <= 1'b0;
        end
        else if (data_addr_ok && !data_wr) begin
            last_arvalid <= 1'b1;
        end
        else if (arready) begin
            last_arvalid <= 1'b0;
        end
    end

    //awvalid
    always @(posedge clk ) begin
        if (!rst) begin
            last_awvalid <= 1'b0;
        end
        else if (data_addr_ok && data_wr) begin
            last_awvalid <= 1'b1;
        end
        else if (awready) begin
            last_awvalid <= 1'b0;
        end
    end

    //wvalid
    always @(posedge clk ) begin
        if (!rst) begin
            last_wvalid <= 1'b0;
        end
        else if (awvalid && awready) begin
            last_wvalid <= 1'b1;
        end
        else if (wready) begin
            last_wvalid <= 1'b0;
        end
    end


    // AXI Signals
    assign arid    = `DUNCA_ARID;
    assign araddr  = last_addr;
    assign arlen   = 4'd0;
    assign arsize  = {1'b0,last_size};
    assign arburst = 2'd0;
    assign arlock  = 2'd0;
    assign arcache = 4'd0;
    assign arprot  = 3'd0;
    assign arvalid = last_arvalid;

    assign rready  = 1'b1;

    assign awid    = `DUNCA_AWID;
    assign awaddr  = last_addr;
    assign awlen   = 4'd0;
    assign awsize  = {1'b0,last_size};
    assign awburst = 2'd0;
    assign awlock  = 2'd0;
    assign awcache = 4'd0;
    assign awprot  = 3'd0;
    assign awvalid = last_awvalid;

    assign wid     = `DUNCA_WID;
    assign wdata   = last_wdata;
    assign wstrb   = last_wstrb;
    assign wlast   = 1'd1;
    assign wvalid  = last_wvalid;

    assign bready  = 1'd1;
endmodule