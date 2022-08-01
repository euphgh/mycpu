//func_test/axi/tb_top
//这个可以生成一个trace，最后末尾可能有点问题，不过大体上可以使用
`timescale 1ns / 1ps

`define TRACE_REF_FILE "D:/CODE/verilog/Cache/perf_test_v0.01/1.txt"
`define CONFREG_NUM_REG      soc_lite.u_confreg.num_data
`define CONFREG_OPEN_TRACE   soc_lite.u_confreg.open_trace
`define CONFREG_NUM_MONITOR  soc_lite.u_confreg.num_monitor
`define CONFREG_UART_DISPLAY soc_lite.u_confreg.write_uart_valid
`define CONFREG_UART_DATA    soc_lite.u_confreg.write_uart_data
`define END_PC 32'hbfc00100

module tb_top( );
reg resetn;
reg clk;

//goio
wire [15:0] led;
wire [1 :0] led_rg0;
wire [1 :0] led_rg1;
wire [7 :0] num_csn;
wire [6 :0] num_a_g;
wire [7 :0] switch;
wire [3 :0] btn_key_col;
wire [3 :0] btn_key_row;
wire [1 :0] btn_step;
assign switch      = 8'hff;
assign btn_key_row = 4'd0;
assign btn_step    = 2'd3;

initial
begin
    clk = 1'b0;
    resetn = 1'b0;
    #2000;
    resetn = 1'b1;
end
always #5 clk=~clk;
soc_axi_lite_top #(.SIMULATION(1'b1)) soc_lite
(
       .resetn      (resetn     ), 
       .clk         (clk        ),
    
        //------gpio-------
        .num_csn    (num_csn    ),
        .num_a_g    (num_a_g    ),
        .led        (led        ),
        .led_rg0    (led_rg0    ),
        .led_rg1    (led_rg1    ),
        .switch     (switch     ),
        .btn_key_col(btn_key_col),
        .btn_key_row(btn_key_row),
        .btn_step   (btn_step   )
    );   

//"cpu_clk" means cpu core clk
//"sys_clk" means system clk
//"wb" means write-back stage in pipeline
//"rf" means regfiles in cpu
//"w" in "wen/wnum/wdata" means writing
wire cpu_clk;
wire sys_clk;
wire [31:0] debug_wb_pc_1;
wire [3 :0] debug_wb_rf_wen_1;
wire [4 :0] debug_wb_rf_wnum_1;
wire [31:0] debug_wb_rf_wdata_1;
wire [31:0] debug_wb_pc_2;
wire [3 :0] debug_wb_rf_wen_2;
wire [4 :0] debug_wb_rf_wnum_2;
wire [31:0] debug_wb_rf_wdata_2;
assign cpu_clk           = soc_lite.cpu_clk;
assign sys_clk           = soc_lite.sys_clk;
assign debug_wb_pc_1       = soc_lite.debug_wb_pc_1;
assign debug_wb_rf_wen_1   = soc_lite.debug_wb_rf_wen_1;
assign debug_wb_rf_wnum_1  = soc_lite.debug_wb_rf_wnum_1;
assign debug_wb_rf_wdata_1 = soc_lite.debug_wb_rf_wdata_1;
assign debug_wb_pc_2       = soc_lite.debug_wb_pc_2;
assign debug_wb_rf_wen_2   = soc_lite.debug_wb_rf_wen_2;
assign debug_wb_rf_wnum_2  = soc_lite.debug_wb_rf_wnum_2;
assign debug_wb_rf_wdata_2 = soc_lite.debug_wb_rf_wdata_2;

// open the trace file;
integer trace_ref;
initial begin
    trace_ref = $fopen(`TRACE_REF_FILE, "w");
end

// generate trace
always @(posedge cpu_clk)
begin
    if(|debug_wb_rf_wen_1 && debug_wb_rf_wnum_1!=5'd0)
    begin
        $fdisplay(trace_ref, "%h %h %h %h", `CONFREG_OPEN_TRACE,
            debug_wb_pc_1, debug_wb_rf_wnum_1, debug_wb_rf_wdata_1);
    end 
    
    if(|debug_wb_rf_wen_2 && debug_wb_rf_wnum_2!=5'd0)
    begin
        $fdisplay(trace_ref, "%h %h %h %h", `CONFREG_OPEN_TRACE,
            debug_wb_pc_2, debug_wb_rf_wnum_2, debug_wb_rf_wdata_2);
    end 
end

//test end
wire test_end = (debug_wb_pc_1==`END_PC) || (debug_wb_pc_2==`END_PC) ;
always @(posedge cpu_clk)
begin
    if (!resetn)
    begin
    end
    else if(test_end)
    begin
	    $display("==============================================================");
	    $display("gettrace end!");
		 #10;
	    $fclose(trace_ref);
	    $finish;
	end
end
endmodule