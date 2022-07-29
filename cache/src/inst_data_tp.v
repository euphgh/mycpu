`timescale 1ns / 1ps
module inst_data_tp#(
    parameter LINE  = 128,
    parameter BLOCK = 8
)(
    input                     clk  ,
    input                     en   ,
    input  [4*BLOCK-1     :0] wen  ,
    input  [$clog2(LINE)-1:0] index,
    input  [32*BLOCK-1    :0] wdata,
    output [32*BLOCK-1    :0] rdata
);
    xpm_memory_spram #(
        .ADDR_WIDTH_A       ($clog2(LINE)   ),
        .AUTO_SLEEP_TIME    (0              ),
        .BYTE_WRITE_WIDTH_A (8              ),
        .CASCADE_HEIGHT     (0              ),
        .ECC_MODE           ("no_ecc"       ),
        .MEMORY_INIT_FILE   ("none"         ),
        .MEMORY_INIT_PARAM  ("0"            ),
        .MEMORY_OPTIMIZATION("true"         ),
        .MEMORY_PRIMITIVE   ("auto"         ),
        .MEMORY_SIZE        (32*BLOCK*LINE  ),
        .MESSAGE_CONTROL    (0              ),
        .READ_DATA_WIDTH_A  (32*BLOCK       ),
        .READ_LATENCY_A     (1              ),
        .READ_RESET_VALUE_A ("0"            ),
        .RST_MODE_A         ("SYNC"         ),
        .SIM_ASSERT_CHK     (0              ),
        .USE_MEM_INIT       (0              ),
        .WAKEUP_TIME        ("disable_sleep"),
        .WRITE_DATA_WIDTH_A (32*BLOCK       ),
        .WRITE_MODE_A       ("read_first"   )
    )
    xpm_memory_spram_inst (
        .douta(rdata),
        .addra(index),
        .clka (clk  ),
        .dina (wdata),
        .ena  (en   ),
        .wea  (wen  )
    );
endmodule
