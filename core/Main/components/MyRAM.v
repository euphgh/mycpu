// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/31 10:49
// Last Modified : 2022/08/02 16:19
// File Name     : MyRAM.v
// Description   : 通用的64位双端口block memory,完全写优先
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/07/31   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns / 1ps

module MyRAM #(
    parameter MY_NUMBER     = 512,
    parameter MY_DATA_WIDTH = 32
)
(
    input                           clk,
    input                           wen,
    input  [$clog2(MY_NUMBER)-1:0]  rAddr,
    input  [$clog2(MY_NUMBER)-1:0]  wAddr,
    input  [MY_DATA_WIDTH-1:0]      wdata,
    output [MY_DATA_WIDTH-1:0]      rdata
);

    reg  [MY_DATA_WIDTH-1:0]    wline;
    reg                         collison_reg;
    wire [MY_DATA_WIDTH-1:0]    collison_output;
    wire [MY_DATA_WIDTH-1:0]    doutb;
    wire collison = (rAddr == wAddr) && wen;
    always @(posedge clk) begin
        collison_reg <= collison;
        wline        <= wdata;
    end
    assign rdata = collison_reg ? wline : doutb;

    // xpm_memory_sdpram: Simple Dual Port RAM
    // Xilinx Parameterized Macro, version 2019.2
    wire    [(MY_DATA_WIDTH/8)-1:0] wstrb = {MY_DATA_WIDTH/8{wen}};
    xpm_memory_sdpram #(
        .ADDR_WIDTH_A           ($clog2(MY_NUMBER)              ),
        .ADDR_WIDTH_B           ($clog2(MY_NUMBER)              ),
        .READ_DATA_WIDTH_B      (MY_DATA_WIDTH             ),
        .WRITE_DATA_WIDTH_A     (MY_DATA_WIDTH             ),
        .AUTO_SLEEP_TIME        (0              ),
        .BYTE_WRITE_WIDTH_A     (8              ),
        .CASCADE_HEIGHT         (0              ),
        .CLOCKING_MODE          ("common_clock" ),
        .ECC_MODE               ("no_ecc"       ),
        .MEMORY_INIT_FILE       ("none"         ),
        .MEMORY_INIT_PARAM      ("0"            ),
        .MEMORY_OPTIMIZATION    ("true"         ),
        .MEMORY_PRIMITIVE       ("block"        ),
        .MEMORY_SIZE            (MY_DATA_WIDTH*MY_NUMBER),
        .MESSAGE_CONTROL        (0              ),
        .READ_LATENCY_B         (1              ),
        .READ_RESET_VALUE_B     ("0"            ),
        .RST_MODE_A             ("SYNC"         ),
        .RST_MODE_B             ("SYNC"         ),
        .SIM_ASSERT_CHK         (1              ),
        .USE_EMBEDDED_CONSTRAINT(0              ),
        .USE_MEM_INIT           (0              ),
        .WAKEUP_TIME            ("disable_sleep"),
        .WRITE_MODE_B           ("read_first"   )
    )
    xpm_memory_sdpram_inst (
        .clka          (clk     ),
        .clkb          (clk     ),
        .rstb          (1'b0    ),
        .ena           (wen     ),
        .wea           (wstrb   ),
        .addra         (wAddr   ),
        .dina          (wdata   ),
        .enb           (1'b1    ),
        .addrb         (rAddr   ),
        .doutb         (rdata   ),
        .injectdbiterra(1'b0    ),
        .injectsbiterra(1'b0    ),
        .regceb        (1'b0    ),
        .sleep         (1'b0    ),
        .dbiterrb      (        ),
        .sbiterrb      (        )
    );
endmodule

