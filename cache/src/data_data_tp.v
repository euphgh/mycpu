`timescale 1ns / 1ps
module data_data_tp(
    input          clk,
    input          en,
    input  [31 :0] wen,
    input  [6  :0] rindex,
    input  [6  :0] windex,
    input  [255:0] wdata,
    output [255:0] rdata
);

    reg  [255:0] wdata_reg;
    reg  [31 :0] wen_reg;
    reg          col_reg;
    wire [255:0] doutb;
    wire col = (rindex == windex) && |wen;

    always @(posedge clk) begin
        col_reg    <= col;
        wdata_reg  <= wdata;
        wen_reg    <= wen;
    end

    wire [255:0] collison_output;

    genvar i;
    generate
        for (i = 0; i < 256; i = i + 1) begin
            assign collison_output[i] = wen_reg[i >> 3] ? wdata_reg[i] : doutb[i];
        end
    endgenerate

    assign rdata = col_reg ? collison_output : doutb;

    xpm_memory_sdpram #(
        .ADDR_WIDTH_A           (7              ),
        .ADDR_WIDTH_B           (7              ),
        .AUTO_SLEEP_TIME        (0              ),
        .BYTE_WRITE_WIDTH_A     (8              ),
        .CASCADE_HEIGHT         (0              ),
        .CLOCKING_MODE          ("common_clock" ),
        .ECC_MODE               ("no_ecc"       ),
        .MEMORY_INIT_FILE       ("none"         ),
        .MEMORY_INIT_PARAM      ("0"            ),
        .MEMORY_OPTIMIZATION    ("true"         ),
        .MEMORY_PRIMITIVE       ("block"        ),
        .MEMORY_SIZE            (32768          ),
        .MESSAGE_CONTROL        (0              ),
        .READ_DATA_WIDTH_B      (256            ),
        .READ_LATENCY_B         (1              ),
        .READ_RESET_VALUE_B     ("0"            ),
        .RST_MODE_A             ("SYNC"         ),
        .RST_MODE_B             ("SYNC"         ),
        .SIM_ASSERT_CHK         (1              ),
        .USE_EMBEDDED_CONSTRAINT(0              ),
        .USE_MEM_INIT           (0              ),
        .WAKEUP_TIME            ("disable_sleep"),
        .WRITE_DATA_WIDTH_A     (256            ),
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