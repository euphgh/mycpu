/*
 * the cpu should contains:
 *      wire [31:0] debug_pc     [1:0];
 *      wire [3 :0] debug_wen    [1:0];
 *      wire [4 :0] debug_wnum   [1:0];
 *      wire [31:0] debug_wdata  [1:0];
 *      
 *      meanwhile, debug interface provided by loongson
 *      (debug_wb_pc, debug_wb_rf_wen, debug_wb_rf_wnum, debug_wb_rf_wdata) is ignored
 */

`timescale 1ns / 1ps 
`include "MyDefines.v"
`define FUNC_TEST
// `define CACHE_HIT_TEST
`define TRACE_REF_FILE          "../../../../../../mycpu/trace/golden_trace.txt"
`define CONFREG_OPEN_TRACE      soc_lite.u_confreg.open_trace
`define CONFREG_NUM_REG         soc_lite.u_confreg.num_data
`define CONFREG_NUM_MONITOR     soc_lite.u_confreg.num_monitor
`define CONFREG_UART_DISPLAY    soc_lite.u_confreg.write_uart_valid
`define CONFREG_UART_DATA       soc_lite.u_confreg.write_uart_data
`define END_PC                  32'hbfc00100

module tb_dual_issue_cpu;

reg resetn;
reg clk;

//goio
wire [15:0] led;
wire [1 :0] led_rg0;
wire [1 :0] led_rg1;
wire [7 :0] num_csn;
wire [6 :0] num_a_g;
wire [7 :0] switch;
wire [7 :0] switch_inv;
wire [3 :0] btn_key_col;
wire [3 :0] btn_key_row;
wire [1 :0] btn_step;
assign switch_inv  = 8'h00;
assign switch      = ~switch_inv;
assign btn_key_row = 4'd0;
assign btn_step    = 2'd3;
integer regNum;
integer hiloNum;
initial begin
    clk    = 1'b0;
    resetn = 1'b0;
    #2000;
    resetn = 1'b1;
end

always #5 clk=~clk;

soc_axi_lite_top #(.SIMULATION(1'b1)) soc_lite
(
    .resetn      (resetn    ),
    .clk         (clk       ),

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
wire [31:0] debug_wb_pc     [1:0];
wire [3 :0] debug_wb_wen    [1:0];
wire [4 :0] debug_wb_wnum   [1:0];
wire [31:0] debug_wb_wdata  [1:0];
wire [63:0] btrue;
wire [63:0] bfalse;
wire [63:0] btrueHit;
assign btrue = soc_lite.u_cpu.u_Main.u_EXEUP.truep;
assign btrueHit = soc_lite.u_cpu.u_Main.u_EXEUP.truehit;
assign bfalse = soc_lite.u_cpu.u_Main.u_EXEUP.falsep;

assign cpu_clk           = soc_lite.cpu_clk;
assign sys_clk           = soc_lite.sys_clk;

assign debug_wb_pc   [0] = soc_lite.u_cpu.u_Main.debug_wb_pc0;
assign debug_wb_wen  [0] = soc_lite.u_cpu.u_Main.debug_wb_rf_wen0;
assign debug_wb_wnum [0] = soc_lite.u_cpu.u_Main.debug_wb_rf_wnum0;
assign debug_wb_wdata[0] = soc_lite.u_cpu.u_Main.debug_wb_rf_wdata0;

assign debug_wb_pc   [1] = soc_lite.u_cpu.u_Main.debug_wb_pc1;
assign debug_wb_wen  [1] = soc_lite.u_cpu.u_Main.debug_wb_rf_wen1;
assign debug_wb_wnum [1] = soc_lite.u_cpu.u_Main.debug_wb_rf_wnum1;
assign debug_wb_wdata[1] = soc_lite.u_cpu.u_Main.debug_wb_rf_wdata1;
// open the trace file
integer trace_ref,status;
initial begin
    trace_ref = $fopen(`TRACE_REF_FILE, "r");
end
//get reference result in falling edge
reg        trace_cmp_flag;
reg        debug_end;

reg [31:0] ref_wb_pc;
reg [4 :0] ref_wb_wnum;
reg [31:0] ref_wb_wdata;

function [31:0] get_valid_wdata (
    input [31:0] wdata,
    input [3 :0] wen
);
begin

get_valid_wdata[31:24] = wdata[31:24] & {8{wen[3]}};
get_valid_wdata[23:16] = wdata[23:16] & {8{wen[2]}};
get_valid_wdata[15: 8] = wdata[15: 8] & {8{wen[1]}};
get_valid_wdata[7 : 0] = wdata[7 : 0] & {8{wen[0]}};

end
endfunction

reg debug_wb_err;
task compare (
    input [31:0] debug_wb_pc  ,
    input [3 :0] debug_wb_wen ,
    input [4 :0] debug_wb_wnum,
    input [31:0] debug_wb_wdata
);
begin
    if (|debug_wb_wen && debug_wb_wnum != 5'd0 && !debug_end && `CONFREG_OPEN_TRACE) begin
        trace_cmp_flag = 1'b0;
        while (!trace_cmp_flag && !($feof(trace_ref))) begin
            $fscanf(trace_ref, "%h %h %h %h", trace_cmp_flag,
                    ref_wb_pc, ref_wb_wnum, ref_wb_wdata);
        end
        if ((debug_wb_pc !== ref_wb_pc)     ||
            (debug_wb_wnum !== ref_wb_wnum) ||
            (get_valid_wdata(debug_wb_wdata, debug_wb_wen) !== get_valid_wdata(ref_wb_wdata, debug_wb_wen))) begin
            $display("--------------------------------------------------------------");
            $display("[%t] Error!!!", $time);
            $display("    reference: PC = 0x%8h, wb_wnum = 0x%2h, wb_wdata = 0x%8h",
                      ref_wb_pc, ref_wb_wnum, get_valid_wdata(ref_wb_wdata, debug_wb_wen));
            $display("    mycpu    : PC = 0x%8h, wb_wnum = 0x%2h, wb_wdata = 0x%8h",
                      debug_wb_pc, debug_wb_wnum, get_valid_wdata(debug_wb_wdata, debug_wb_wen));
            $display("--------------------------------------------------------------");
            debug_wb_err <= 1'b1;
            #15;
            $finish;
        end
    end
end
endtask

// simulate serial port
wire        uart_display = `CONFREG_UART_DISPLAY;
wire [7:0]  uart_data    = `CONFREG_UART_DATA;

always @(posedge sys_clk) begin
    if (uart_display && uart_data != 8'hff) begin
        $write("%c",uart_data);
    end
end

//compare result in rsing edge
always @(posedge cpu_clk)
begin
    #2;
    if (!resetn) begin
        debug_wb_err <= 1'b0;
    end 
    else if (debug_wb_pc[0]==`END_PC) begin
        compare(debug_wb_pc[0], debug_wb_wen[0], debug_wb_wnum[0], debug_wb_wdata[0]);
    end
    else begin
        compare(debug_wb_pc[0], debug_wb_wen[0], debug_wb_wnum[0], debug_wb_wdata[0]);
        compare(debug_wb_pc[1], debug_wb_wen[1], debug_wb_wnum[1], debug_wb_wdata[1]);    
    end 
end

//monitor numeric display
reg [7:0] err_count;
wire [31:0] confreg_num_reg = `CONFREG_NUM_REG;
reg  [31:0] confreg_num_reg_r;
always @(posedge sys_clk) begin
    confreg_num_reg_r <= confreg_num_reg;
    if (!resetn) begin
        err_count <= 8'd0;
    end
    else if (confreg_num_reg_r != confreg_num_reg && `CONFREG_NUM_MONITOR) begin
        if(confreg_num_reg[7:0]!=confreg_num_reg_r[7:0]+1'b1) begin
            $display("--------------------------------------------------------------");
            $display("[%t] Error(%d)!!! Occurred in number 8'd%02d Functional Test Point!",$time, err_count, confreg_num_reg[31:24]);
            $display("--------------------------------------------------------------");
            err_count <= err_count + 1'b1;
        end
        else if(confreg_num_reg[31:24]!=confreg_num_reg_r[31:24]+1'b1) begin
            $display("--------------------------------------------------------------");
            $display("[%t] Error(%d)!!! Unknown, Functional Test Point numbers are unequal!",$time,err_count);
            $display("--------------------------------------------------------------");
            $display("==============================================================");
            err_count <= err_count + 1'b1;
        end
        else begin
            $display("----[%t] Number 8'd%02d Functional Test Point PASS!!!", $time, confreg_num_reg[31:24]);
            $display("branch rate:\nright:\t%d\ntotal:\t%d\nhit:\t%d",btrue,(btrue+bfalse),btrueHit);
        end
    end
end


`ifdef CACHE_HIT_TEST
integer icache_req;
integer icache_miss;
integer dcache_req;
integer dcache_miss;
integer dcache_wvc;
integer dcache_wb;

initial begin
    icache_req = 0;
    dcache_req = 0;
    icache_req = 0;
    icache_miss = 0;
    dcache_miss = 0;
    dcache_wvc = 0;
    dcache_wb = 0;
end

always @(posedge cpu_clk) begin
    if (soc_lite.u_cpu.u_icache.inst_data_ok) begin
        icache_req = icache_req + 1;
    end
    if (soc_lite.u_cpu.u_icache.state == 3'h5) begin
        icache_miss = icache_miss + 1;
    end
    if (soc_lite.u_cpu.u_dcache.data_data_ok) begin
        dcache_req = dcache_req + 1;
    end
    if (soc_lite.u_cpu.u_dcache.state == 4'd9) begin
        dcache_miss = dcache_miss + 1;
    end
    if (soc_lite.u_cpu.u_dcache.state == 4'd6 && soc_lite.u_cpu.u_dcache.wb_ready) begin
        dcache_wb = dcache_wb + 1;
    end
    if (soc_lite.u_cpu.u_dcache.state == 4'd5 && !soc_lite.u_cpu.u_dcache.vc_full) begin
        dcache_wvc = dcache_wvc + 1;
    end
end
`endif

`ifdef FUNC_TEST

reg [31:0] last_valid_pc;

always @(posedge clk) begin
    if (debug_wb_pc[0] != 32'b0) begin
        last_valid_pc <= debug_wb_pc[0];
    end
end

//monitor current pc
initial begin
    $timeformat(-9, 0, " ns", 10);
    while (!resetn)
    #5;
    $display("==============================================================");
    $display("Test begin!");
    #100000;
    while(`CONFREG_NUM_MONITOR) begin
        #100000;
        $display ("        [%t] Test is running, wb_pc = 0x%8h, last valid pc = 0x%8h", $time, debug_wb_pc[0], last_valid_pc);
    end
end

`endif

//test end
wire global_err = debug_wb_err || (err_count != 8'd0);
wire test_end   = debug_wb_pc[0] == `END_PC || debug_wb_pc[1] == `END_PC;

always @(posedge cpu_clk) begin
    if (!resetn) begin
        debug_end <= 1'b0;
    end
    else if(test_end && !debug_end) begin
        debug_end <= 1'b1;
        $display("==============================================================");
        $display("Test end!");
        #40;
        //$fclose(trace_ref);
        $timeformat(-6, 0, " us", 10);
        if (global_err) begin
            $display("Fail!!!Total %d errors!",err_count);
        end
        else begin
            $display("----PASS!!!");
            $display("----Time: %t", $time);
            //$display("icache req = %d, icache miss         = %d", icache_req, icache_miss);
            //$display("dcache req = %d, dcache miss         = %d", dcache_req, dcache_miss);
            //$display("dcache wb  = %d, dcache write victim = %d", dcache_wb, dcache_wvc);
        end

	end
end

always @(*) begin
    if (debug_end) begin
        resetn = 1'b0;
        #2000;
        resetn = 1'b1;
    end
    
end
endmodule
