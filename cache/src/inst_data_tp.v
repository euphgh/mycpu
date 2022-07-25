`timescale 1ns / 1ps
module inst_data_tp(
    input          clk,
    input          en,
    input  [31 :0] wen,
    input  [6  :0] index,
    input  [255:0] wdata,
    output [255:0] rdata
);
    xpm_memory_spram #(
        .ADDR_WIDTH_A       (7              ),
        .AUTO_SLEEP_TIME    (0              ),
        .BYTE_WRITE_WIDTH_A (8              ),
        .CASCADE_HEIGHT     (0              ),
        .ECC_MODE           ("no_ecc"       ),
        .MEMORY_INIT_FILE   ("none"         ),
        .MEMORY_INIT_PARAM  ("0"            ),
        .MEMORY_OPTIMIZATION("true"         ),
        .MEMORY_PRIMITIVE   ("auto"         ),
        .MEMORY_SIZE        (32768          ),
        .MESSAGE_CONTROL    (0              ),
        .READ_DATA_WIDTH_A  (256            ),
        .READ_LATENCY_A     (1              ),
        .READ_RESET_VALUE_A ("0"            ),
        .RST_MODE_A         ("SYNC"         ),
        .SIM_ASSERT_CHK     (0              ),
        .USE_MEM_INIT       (1              ),
        .WAKEUP_TIME        ("disable_sleep"),
        .WRITE_DATA_WIDTH_A (256            ),
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
