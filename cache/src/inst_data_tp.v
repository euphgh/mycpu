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
      .ADDR_WIDTH_A(7),              // DECIMAL
      .AUTO_SLEEP_TIME(0),           // DECIMAL
      .BYTE_WRITE_WIDTH_A(8),       // DECIMAL
      .CASCADE_HEIGHT(0),            // DECIMAL
      .ECC_MODE("no_ecc"),           // String
      .MEMORY_INIT_FILE("none"),     // String
      .MEMORY_INIT_PARAM("0"),       // String
      .MEMORY_OPTIMIZATION("true"),  // String
      .MEMORY_PRIMITIVE("auto"),     // String
      .MEMORY_SIZE(32768),            // DECIMAL
      .MESSAGE_CONTROL(0),           // DECIMAL
      .READ_DATA_WIDTH_A(256),        // DECIMAL
      .READ_LATENCY_A(1),            // DECIMAL
      .READ_RESET_VALUE_A("0"),      // String
      .RST_MODE_A("SYNC"),           // String
      .SIM_ASSERT_CHK(0),            // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_MEM_INIT(1),              // DECIMAL
      .WAKEUP_TIME("disable_sleep"), // String
      .WRITE_DATA_WIDTH_A(256),       // DECIMAL
      .WRITE_MODE_A("read_first")    // String
   )
   xpm_memory_spram_inst (
        .douta(rdata),  
        .addra(index),   
        .clka(clk),     
        .dina(wdata),   
        .ena(en),
        .wea(wen)                        
   );
    // cache_data_ram BANK_0_7(
    //     .clka(clk),
    //     .ena(en),
    //     .wea(wen),
    //     .addra(index),
    //     .dina(wdata),
    //     .douta(rdata)
    // );
endmodule
