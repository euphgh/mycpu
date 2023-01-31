`include "./core/MyDefines.v"
`timescale 1ns / 1ps
module mycpu_top (
    input  [5 :0]  ext_int,

    input          aclk   ,
    input          aresetn,

    output [3 :0]  arid   ,
    output [31:0]  araddr ,
    output [3 :0]  arlen  ,
    output [2 :0]  arsize ,
    output [1 :0]  arburst,
    output [1 :0]  arlock ,
    output [3 :0]  arcache,
    output [2 :0]  arprot ,
    output         arvalid,
    input          arready,

    input  [3 :0]  rid   ,
    input  [31:0]  rdata ,
    input  [1 :0]  rresp ,
    input          rlast ,
    input          rvalid,
    output         rready,

    output [3 :0]  awid   ,
    output [31:0]  awaddr ,
    output [3 :0]  awlen  ,
    output [2 :0]  awsize ,
    output [1 :0]  awburst,
    output [1 :0]  awlock ,
    output [3 :0]  awcache,
    output [2 :0]  awprot ,
    output         awvalid,
    input          awready,

    output [3 :0]  wid   ,
    output [31:0]  wdata ,
    output [3 :0]  wstrb ,
    output         wlast ,
    output         wvalid,
    input          wready,

    input  [3 :0]  bid   ,
    input  [1 :0]  bresp ,
    input          bvalid,
    output         bready,
    // no use (all tied to 0)
    output  [31:0]   debug_wb_pc,
    output  [3 :0]   debug_wb_rf_wen,
    output  [4 :0]   debug_wb_rf_wnum,
    output  [31:0]   debug_wb_rf_wdata
);
    // CPU wire{{{
    wire [127:0]                inst_rdata                      ;
    wire                        inst_index_ok                   ;
    wire                        inst_data_ok                    ;
    wire [31:0]                 data_rdata                      ;
    wire                        data_index_ok                   ;
    wire                        data_data_ok                    ;
    wire                        inst_req                        ;
    wire                        inst_wr                         ;
    wire [1:0]                  inst_size                       ;
    wire [7:0]                  inst_index                      ;
    wire [19:0]                 inst_tag                        ;
    wire                        inst_hasException               ;
    wire                        inst_unCache                    ;
    wire [31:0]                 inst_wdata                      ;
    wire                        data_req                        ;
    wire                        data_wr                         ;
    wire [1:0]                  data_size                       ;
    wire [11:0]                 data_index                      ;
    wire [19:0]                 data_tag                        ;
    wire                        data_unCache                    ;
    wire                        data_hasException               ;
    wire [3:0]                  data_wstrb                      ;
    wire [31:0]                 data_wdata                      ;
    wire [`SINGLE_WORD]         debug_wb_pc0                    ;
    wire [`SINGLE_WORD]         debug_wb_pc1                    ;
    wire [3:0]                  debug_wb_rf_wen0                ;
    wire [3:0]                  debug_wb_rf_wen1                ;
    wire [`GPR_NUM]             debug_wb_rf_wnum0               ;
    wire [`GPR_NUM]             debug_wb_rf_wnum1               ;
    wire [`SINGLE_WORD]         debug_wb_rf_wdata0              ;
    wire [`SINGLE_WORD]         debug_wb_rf_wdata1              ;/*}}}*/
    Main  u_Main (/*{{{*/
        .clk                     ( aclk                 ),
        .rst                     ( aresetn              ),
        .ext_int                 ( ext_int              ),
        .inst_rdata              ( inst_rdata           ),
        .inst_index_ok           ( inst_index_ok        ),
        .inst_data_ok            ( inst_data_ok         ),
        .data_rdata              ( data_rdata           ),
        .data_index_ok           ( data_index_ok        ),
        .data_data_ok            ( data_data_ok         ),
    
        .inst_req                ( inst_req             ),
        .inst_wr                 ( inst_wr              ),
        .inst_size               ( inst_size            ),
        .inst_index              ( inst_index           ),
        .inst_tag                ( inst_tag             ),
        .inst_hasException       ( inst_hasException    ),
        .inst_unCache            ( inst_unCache         ),
        .inst_wdata              ( inst_wdata           ),
        .data_req                ( data_req             ),
        .data_wr                 ( data_wr              ),
        .data_size               ( data_size            ),
        .data_index              ( data_index           ),
        .data_tag                ( data_tag             ),
        .data_unCache            ( data_unCache         ),
        .data_hasException       ( data_hasException    ),
        .data_wstrb              ( data_wstrb           ),
        .data_wdata              ( data_wdata           ),
        .debug_wb_pc0            ( debug_wb_pc0         ),
        .debug_wb_pc1            ( debug_wb_pc1         ),
        .debug_wb_rf_wen0        ( debug_wb_rf_wen0     ),
        .debug_wb_rf_wen1        ( debug_wb_rf_wen1     ),
        .debug_wb_rf_wnum0       ( debug_wb_rf_wnum0    ),
        .debug_wb_rf_wnum1       ( debug_wb_rf_wnum1    ),
        .debug_wb_rf_wdata0      ( debug_wb_rf_wdata0   ),
        .debug_wb_rf_wdata1      ( debug_wb_rf_wdata1   )
    );/*}}}*/
    cache_top  u_cache_top (/*{{{*/
    .aclk                         ( aclk                          ),
    .aresetn                      ( aresetn                       ),
    `ifdef EN_ICACHE_OP
    .icache_req                   ( icache_req                    ),
    .icache_op                    ( icache_op                     ),
    .icache_addr                  ( icache_addr                   ),
    .icache_tag                   ( icache_tag                    ),
    .icache_valid                 ( icache_valid                  ),
    .icache_ok                    ( icache_ok                     ),
    `endif
    `ifdef EN_DCACHE_OP
    .dcache_req                   ( dcache_req                    ),
    .dcache_op                    ( dcache_op                     ),
    .dcache_addr                  ( dcache_addr                   ),
    .dcache_tag                   ( dcache_tag                    ),
    .dcache_valid                 ( dcache_valid                  ),
    .dcache_dirty                 ( dcache_dirty                  ),
    .dcache_ok                    ( dcache_ok                     ),
    `endif
    .inst_req                     ( inst_req                      ),
    .inst_wr                      ( inst_wr                       ),
    .inst_size                    ( inst_size                     ),
    .inst_index                   ( inst_index                    ),
    .inst_tag                     ( inst_tag                      ),
    .inst_hasException            ( inst_hasException             ),
    .inst_unCache                 ( inst_unCache                  ),
    .inst_wdata                   ( inst_wdata                    ),
    .inst_rdata                   ( inst_rdata                    ),
    .inst_index_ok                ( inst_index_ok                 ),
    .inst_data_ok                 ( inst_data_ok                  ),

    .data_req                     ( data_req                      ),
    .data_wr                      ( data_wr                       ),
    .data_size                    ( data_size                     ),
    .data_index                   ( data_index                    ),
    .data_tag                     ( data_tag                      ),
    .data_hasException            ( data_hasException             ),
    .data_unCache                 ( data_unCache                  ),
    .data_wstrb                   ( data_wstrb                    ),
    .data_wdata                   ( data_wdata                    ),
    .data_rdata                   ( data_rdata                    ),
    .data_index_ok                ( data_index_ok                 ),
    .data_data_ok                 ( data_data_ok                  ),


    .arready                      ( arready                       ),
    .rid                          ( rid                           ),
    .rdata                        ( rdata                         ),
    .rresp                        ( rresp                         ),
    .rlast                        ( rlast                         ),
    .rvalid                       ( rvalid                        ),
    .awready                      ( awready                       ),
    .wready                       ( wready                        ),
    .bid                          ( bid                           ),
    .bresp                        ( bresp                         ),
    .bvalid                       ( bvalid                        ),
    .arid                         ( arid                          ),
    .araddr                       ( araddr                        ),
    .arlen                        ( arlen                         ),
    .arsize                       ( arsize                        ),
    .arburst                      ( arburst                       ),
    .arlock                       ( arlock                        ),
    .arcache                      ( arcache                       ),
    .arprot                       ( arprot                        ),
    .arvalid                      ( arvalid                       ),
    .rready                       ( rready                        ),
    .awid                         ( awid                          ),
    .awaddr                       ( awaddr                        ),
    .awlen                        ( awlen                         ),
    .awsize                       ( awsize                        ),
    .awburst                      ( awburst                       ),
    .awlock                       ( awlock                        ),
    .awcache                      ( awcache                       ),
    .awprot                       ( awprot                        ),
    .awvalid                      ( awvalid                       ),
    .wid                          ( wid                           ),
    .wdata                        ( wdata                         ),
    .wstrb                        ( wstrb                         ),
    .wlast                        ( wlast                         ),
    .wvalid                       ( wvalid                        ),
    .bready                       ( bready                        )
);/*}}}*/
endmodule
