`timescale 1ns / 1ps
module data_data_tp#(
    parameter LINE  = 128,
    parameter BLOCK = 8
)(
    input                     clk   ,
    input                     en    ,
    input  [4*BLOCK-1     :0] wen   ,
    input  [$clog2(LINE)-1:0] rindex,
    input  [$clog2(LINE)-1:0] windex,
    input  [32*BLOCK-1    :0] wdata ,
    output [32*BLOCK-1    :0] rdata
);

    reg  [32*BLOCK-1    :0] wdata_reg;
    reg  [4*BLOCK-1     :0] wen_reg;
    reg                     col_reg;
    wire [32*BLOCK-1    :0] doutb;
    wire col = (rindex == windex) && |wen;

    always @(posedge clk) begin
        col_reg    <= col;
        wdata_reg  <= wdata;
        wen_reg    <= wen;
    end

    wire [32*BLOCK-1    :0] collison_output;

    genvar i;
    generate
        for (i = 0; i < (32*BLOCK); i = i + 1) begin
            assign collison_output[i] = wen_reg[i >> 3] ? wdata_reg[i] : doutb[i];
        end
    endgenerate

    assign rdata = col_reg ? collison_output : doutb;

    xpm_memory_sdpram #(
        .ADDR_WIDTH_A           ($clog2(LINE)              ),
        .ADDR_WIDTH_B           ($clog2(LINE)              ),
        .AUTO_SLEEP_TIME        (0              ),
        .BYTE_WRITE_WIDTH_A     (8              ),
        .CASCADE_HEIGHT         (0              ),
        .CLOCKING_MODE          ("common_clock" ),
        .ECC_MODE               ("no_ecc"       ),
        .MEMORY_INIT_FILE       ("none"         ),
        .MEMORY_INIT_PARAM      ("0"            ),
        .MEMORY_OPTIMIZATION    ("true"         ),
        .MEMORY_PRIMITIVE       ("block"        ),
        .MEMORY_SIZE            (32*BLOCK*LINE  ),
        .MESSAGE_CONTROL        (0              ),
        .READ_DATA_WIDTH_B      (32*BLOCK       ),
        .READ_LATENCY_B         (1              ),
        .READ_RESET_VALUE_B     ("0"            ),
        .RST_MODE_A             ("SYNC"         ),
        .RST_MODE_B             ("SYNC"         ),
        .SIM_ASSERT_CHK         (1              ),
        .USE_EMBEDDED_CONSTRAINT(0              ),
        .USE_MEM_INIT           (0              ),
        .WAKEUP_TIME            ("disable_sleep"),
        .WRITE_DATA_WIDTH_A     (32*BLOCK       ),
        .WRITE_MODE_B           ("read_first"   )
    )
    xpm_memory_sdpram_inst (
        .clka          (clk     ),
        .clkb          (clk     ),
        .rstb          (1'b0    ),
        .ena           (1'b1    ),
        .wea           (wen     ),
        .addra         (windex  ),
        .dina          (wdata   ),
        .enb           (1'b1    ),
        .addrb         (rindex  ),
        .doutb         (doutb   )
    );
endmodule