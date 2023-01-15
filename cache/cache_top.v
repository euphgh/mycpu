`timescale 1ns / 1ps
module cache_top (
    input          aclk   ,
    input          aresetn,

`ifdef EN_ICACHE_OP/*{{{*/
    input         icache_req  ,
    input  [4 :0] icache_op   ,
    input  [31:0] icache_addr ,
    input  [19:0] icache_tag  ,
    input         icache_valid,
    output        icache_ok   ,
`endif/*}}}*/
`ifdef EN_DCACHE_OP/*{{{*/
    input         dcache_req  ,
    input  [4 :0] dcache_op   ,
    input  [31:0] dcache_addr ,
    input  [19:0] dcache_tag  ,
    input         dcache_valid,
    input         dcache_dirty,
    output        dcache_ok   ,
`endif /*}}}*/

    // CPU interface{{{
    input            inst_req         ,
    input            inst_wr          ,
    input  [1 :0]    inst_size        ,
    input  [7 :0]    inst_index       ,
    input  [19:0]    inst_tag         ,
    input            inst_hasException,
    input            inst_unCache     ,
    input  [31 :0]   inst_wdata       ,
    output [127:0]   inst_rdata       ,
    output           inst_index_ok    ,
    output           inst_data_ok     ,

    input            data_req         ,
    input            data_wr          ,
    input  [1 :0]    data_size        ,
    input  [11:0]    data_index       , // index + offset 
    input  [19:0]    data_tag         ,
    input            data_hasException,
    input            data_unCache     ,
    input  [3 :0]    data_wstrb       ,
    input  [31:0]    data_wdata       ,
    output [31:0]    data_rdata       ,
    output           data_index_ok    ,
    output           data_data_ok     ,/*}}}*/

    // AXI master interface{{{
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
    output         bready
);/*}}}*/
    // Itop wire{{{
    wire  [3 :0] inst_top_arid   ;
    wire  [31:0] inst_top_araddr ;
    wire  [3 :0] inst_top_arlen  ;
    wire  [2 :0] inst_top_arsize ;
    wire  [1 :0] inst_top_arburst;
    wire  [1 :0] inst_top_arlock ;
    wire  [3 :0] inst_top_arcache;
    wire  [2 :0] inst_top_arprot ;
    wire         inst_top_arvalid;
    wire         inst_top_arready;

    wire  [3 :0] inst_top_rid    ;
    wire  [31:0] inst_top_rdata  ;
    wire  [1 :0] inst_top_rresp  ;
    wire         inst_top_rlast  ;
    wire         inst_top_rvalid ;
    wire         inst_top_rready ;

    wire  [3 :0] inst_top_awid   ;
    wire  [31:0] inst_top_awaddr ;
    wire  [3 :0] inst_top_awlen  ;
    wire  [2 :0] inst_top_awsize ;
    wire  [1 :0] inst_top_awburst;
    wire  [1 :0] inst_top_awlock ;
    wire  [3 :0] inst_top_awcache;
    wire  [2 :0] inst_top_awprot ;
    wire         inst_top_awvalid;
    wire         inst_top_awready;

    wire  [3 :0] inst_top_wid    ;
    wire  [31:0] inst_top_wdata  ;
    wire  [3 :0] inst_top_wstrb  ;
    wire         inst_top_wlast  ;
    wire         inst_top_wvalid ;
    wire         inst_top_wready ;

    wire  [3 :0] inst_top_bid    ;
    wire  [1 :0] inst_top_bresp  ;
    wire         inst_top_bvalid ;
    wire         inst_top_bready ;/*}}}*/
inst_top  u_inst_top (/*{{{*/
    .aclk                    ( aclk                  ),
    .aresetn                 ( aresetn               ),
    `ifdef EN_ICACHE_OP
    .icache_req              ( icache_req            ),
    .icache_op               ( icache_op             ),
    .icache_addr             ( icache_addr           ),
    .icache_tag              ( icache_tag            ),
    .icache_valid            ( icache_valid          ),
    .icache_ok               ( icache_ok             ),
    `endif                  
    .inst_req                ( inst_req              ),
    .inst_wr                 ( inst_wr               ),
    .inst_size               ( inst_size             ),
    .inst_index              ( inst_index            ),
    .inst_tag                ( inst_tag              ),
    .inst_hasException       ( inst_hasException     ),
    .inst_unCache            ( inst_unCache          ),
    .inst_wdata              ( inst_wdata            ),
    .inst_rdata              ( inst_rdata            ),
    .inst_index_ok           ( inst_index_ok         ),
    .inst_data_ok            ( inst_data_ok          ),

    .arid                    ( inst_top_arid                  ),
    .araddr                  ( inst_top_araddr                ),
    .arlen                   ( inst_top_arlen                 ),
    .arsize                  ( inst_top_arsize                ),
    .arburst                 ( inst_top_arburst               ),
    .arlock                  ( inst_top_arlock                ),
    .arcache                 ( inst_top_arcache               ),
    .arprot                  ( inst_top_arprot                ),
    .arvalid                 ( inst_top_arvalid               ),
    .arready                 ( inst_top_arready               ),

    .rid                     ( inst_top_rid                   ),
    .rdata                   ( inst_top_rdata                 ),
    .rresp                   ( inst_top_rresp                 ),
    .rlast                   ( inst_top_rlast                 ),
    .rvalid                  ( inst_top_rvalid                ),
    .rready                  ( inst_top_rready                ),

    .awid                    ( inst_top_awid                  ),
    .awaddr                  ( inst_top_awaddr                ),
    .awlen                   ( inst_top_awlen                 ),
    .awsize                  ( inst_top_awsize                ),
    .awburst                 ( inst_top_awburst               ),
    .awlock                  ( inst_top_awlock                ),
    .awcache                 ( inst_top_awcache               ),
    .awprot                  ( inst_top_awprot                ),
    .awvalid                 ( inst_top_awvalid               ),
    .awready                 ( inst_top_awready               ),

    .wid                     ( inst_top_wid                   ),
    .wdata                   ( inst_top_wdata                 ),
    .wstrb                   ( inst_top_wstrb                 ),
    .wlast                   ( inst_top_wlast                 ),
    .wvalid                  ( inst_top_wvalid                ),
    .wready                  ( inst_top_wready                ),

    .bid                     ( inst_top_bid                   ),
    .bvalid                  ( inst_top_bvalid                ),
    .bresp                   ( inst_top_bresp                 ),
    .bready                  ( inst_top_bready                )
);/*}}}*/
    // Dtop wire{{{
    wire  [3 :0] data_top_arid   ;
    wire  [31:0] data_top_araddr ;
    wire  [3 :0] data_top_arlen  ;
    wire  [2 :0] data_top_arsize ;
    wire  [1 :0] data_top_arburst;
    wire  [1 :0] data_top_arlock ;
    wire  [3 :0] data_top_arcache;
    wire  [2 :0] data_top_arprot ;
    wire         data_top_arvalid;
    wire         data_top_arready;

    wire  [3 :0] data_top_rid    ;
    wire  [31:0] data_top_rdata  ;
    wire  [1 :0] data_top_rresp  ;
    wire         data_top_rlast  ;
    wire         data_top_rvalid ;
    wire         data_top_rready ;

    wire  [3 :0] data_top_awid   ;
    wire  [31:0] data_top_awaddr ;
    wire  [3 :0] data_top_awlen  ;
    wire  [2 :0] data_top_awsize ;
    wire  [1 :0] data_top_awburst;
    wire  [1 :0] data_top_awlock ;
    wire  [3 :0] data_top_awcache;
    wire  [2 :0] data_top_awprot ;
    wire         data_top_awvalid;
    wire         data_top_awready;

    wire  [3 :0] data_top_wid    ;
    wire  [31:0] data_top_wdata  ;
    wire  [3 :0] data_top_wstrb  ;
    wire         data_top_wlast  ;
    wire         data_top_wvalid ;
    wire         data_top_wready ;

    wire  [3 :0] data_top_bid    ;
    wire  [1 :0] data_top_bresp  ;
    wire         data_top_bvalid ;
    wire         data_top_bready ;/*}}}*/
data_top  u_data_top (/*{{{*/
    .aclk                    ( aclk                  ),
    .aresetn                 ( aresetn               ),
    `ifdef EN_DCACHE_OP     
    .dcache_req              ( dcache_req            ),
    .dcache_op               ( dcache_op             ),
    .dcache_addr             ( dcache_addr           ),
    .dcache_tag              ( dcache_tag            ),
    .dcache_valid            ( dcache_valid          ),
    .dcache_dirty            ( dcache_dirty          ),
    .dcache_ok               ( dcache_ok             ),
    `endif
    .data_req                ( data_req              ),
    .data_wr                 ( data_wr               ),
    .data_size               ( data_size             ),
    .data_index              ( data_index            ),
    .data_tag                ( data_tag              ),
    .data_hasException       ( data_hasException     ),
    .data_unCache            ( data_unCache          ),
    .data_wstrb              ( data_wstrb            ),
    .data_wdata              ( data_wdata            ),
    .data_rdata              ( data_rdata            ),
    .data_index_ok           ( data_index_ok         ),
    .data_data_ok            ( data_data_ok          ),

    .arready                 ( data_top_arready               ),
    .arid                    ( data_top_arid                  ),
    .araddr                  ( data_top_araddr                ),
    .arlen                   ( data_top_arlen                 ),
    .arsize                  ( data_top_arsize                ),
    .arburst                 ( data_top_arburst               ),
    .arlock                  ( data_top_arlock                ),
    .arcache                 ( data_top_arcache               ),
    .arprot                  ( data_top_arprot                ),
    .arvalid                 ( data_top_arvalid               ),

    .rid                     ( data_top_rid                   ),
    .rdata                   ( data_top_rdata                 ),
    .rresp                   ( data_top_rresp                 ),
    .rlast                   ( data_top_rlast                 ),
    .rvalid                  ( data_top_rvalid                ),
    .rready                  ( data_top_rready                ),

    .awid                    ( data_top_awid                  ),
    .awaddr                  ( data_top_awaddr                ),
    .awlen                   ( data_top_awlen                 ),
    .awsize                  ( data_top_awsize                ),
    .awburst                 ( data_top_awburst               ),
    .awlock                  ( data_top_awlock                ),
    .awcache                 ( data_top_awcache               ),
    .awprot                  ( data_top_awprot                ),
    .awvalid                 ( data_top_awvalid               ),
    .awready                 ( data_top_awready               ),
    .wready                  ( data_top_wready                ),

    .wid                     ( data_top_wid                   ),
    .wdata                   ( data_top_wdata                 ),
    .wstrb                   ( data_top_wstrb                 ),
    .wlast                   ( data_top_wlast                 ),
    .wvalid                  ( data_top_wvalid                ),

    .bready                  ( data_top_bready                ),
    .bid                     ( data_top_bid                   ),
    .bvalid                  ( data_top_bvalid                ),
    .bresp                   ( data_top_bresp                 )

);/*}}}*/
axi_2to1_arbiter  u_axi_2to1_arbiter (/*{{{*/
    .arid_0                  ( inst_top_arid      ),
    .araddr_0                ( inst_top_araddr    ),
    .arlen_0                 ( inst_top_arlen     ),
    .arsize_0                ( inst_top_arsize    ),
    .arburst_0               ( inst_top_arburst   ),
    .arlock_0                ( inst_top_arlock    ),
    .arcache_0               ( inst_top_arcache   ),
    .arprot_0                ( inst_top_arprot    ),
    .arvalid_0               ( inst_top_arvalid   ),
    .arready_0               ( inst_top_arready   ),
    .rready_0                ( inst_top_rready    ),
    .rid_0                   ( inst_top_rid       ),
    .rdata_0                 ( inst_top_rdata     ),
    .rresp_0                 ( inst_top_rresp     ),
    .rlast_0                 ( inst_top_rlast     ),
    .rvalid_0                ( inst_top_rvalid    ),
    .awid_0                  ( inst_top_awid      ),
    .awaddr_0                ( inst_top_awaddr    ),
    .awlen_0                 ( inst_top_awlen     ),
    .awsize_0                ( inst_top_awsize    ),
    .awburst_0               ( inst_top_awburst   ),
    .awlock_0                ( inst_top_awlock    ),
    .awcache_0               ( inst_top_awcache   ),
    .awprot_0                ( inst_top_awprot    ),
    .awvalid_0               ( inst_top_awvalid   ),
    .awready_0               ( inst_top_awready   ),
    .wid_0                   ( inst_top_wid       ),
    .wdata_0                 ( inst_top_wdata     ),
    .wstrb_0                 ( inst_top_wstrb     ),
    .wlast_0                 ( inst_top_wlast     ),
    .wready_0                ( inst_top_wready    ),
    .wvalid_0                ( inst_top_wvalid    ),
    .bready_0                ( inst_top_bready    ),
    .bid_0                   ( inst_top_bid       ),
    .bvalid_0                ( inst_top_bvalid    ),
    .bresp_0                 ( inst_top_bresp     ),


    .arid_1                  ( data_top_arid      ),
    .araddr_1                ( data_top_araddr    ),
    .arlen_1                 ( data_top_arlen     ),
    .arsize_1                ( data_top_arsize    ),
    .arburst_1               ( data_top_arburst   ),
    .arlock_1                ( data_top_arlock    ),
    .arcache_1               ( data_top_arcache   ),
    .arprot_1                ( data_top_arprot    ),
    .arvalid_1               ( data_top_arvalid   ),
    .rready_1                ( data_top_rready    ),
    .awid_1                  ( data_top_awid      ),
    .awaddr_1                ( data_top_awaddr    ),
    .awlen_1                 ( data_top_awlen     ),
    .awsize_1                ( data_top_awsize    ),
    .awburst_1               ( data_top_awburst   ),
    .awlock_1                ( data_top_awlock    ),
    .awcache_1               ( data_top_awcache   ),
    .awprot_1                ( data_top_awprot    ),
    .awvalid_1               ( data_top_awvalid   ),
    .wid_1                   ( data_top_wid       ),
    .wdata_1                 ( data_top_wdata     ),
    .wstrb_1                 ( data_top_wstrb     ),
    .wlast_1                 ( data_top_wlast     ),
    .wvalid_1                ( data_top_wvalid    ),
    .bready_1                ( data_top_bready    ),
    .arready_1               ( data_top_arready   ),
    .rid_1                   ( data_top_rid       ),
    .rdata_1                 ( data_top_rdata     ),
    .rresp_1                 ( data_top_rresp     ),
    .rlast_1                 ( data_top_rlast     ),
    .rvalid_1                ( data_top_rvalid    ),
    .awready_1               ( data_top_awready   ),
    .wready_1                ( data_top_wready    ),
    .bid_1                   ( data_top_bid       ),
    .bvalid_1                ( data_top_bvalid    ),
    .bresp_1                 ( data_top_bresp     ),


    .arready                 ( arready     ),
    .rid                     ( rid         ),
    .rdata                   ( rdata       ),
    .rresp                   ( rresp       ),
    .rlast                   ( rlast       ),
    .rvalid                  ( rvalid      ),
    .awready                 ( awready     ),
    .wready                  ( wready      ),
    .bid                     ( bid         ),
    .bvalid                  ( bvalid      ),
    .bresp                   ( bresp       ),
    .arid                    ( arid        ),
    .araddr                  ( araddr      ),
    .arlen                   ( arlen       ),
    .arsize                  ( arsize      ),
    .arburst                 ( arburst     ),
    .arlock                  ( arlock      ),
    .arcache                 ( arcache     ),
    .arprot                  ( arprot      ),
    .arvalid                 ( arvalid     ),
    .rready                  ( rready      ),
    .awid                    ( awid        ),
    .awaddr                  ( awaddr      ),
    .awlen                   ( awlen       ),
    .awsize                  ( awsize      ),
    .awburst                 ( awburst     ),
    .awlock                  ( awlock      ),
    .awcache                 ( awcache     ),
    .awprot                  ( awprot      ),
    .awvalid                 ( awvalid     ),
    .wid                     ( wid         ),
    .wdata                   ( wdata       ),
    .wstrb                   ( wstrb       ),
    .wlast                   ( wlast       ),
    .wvalid                  ( wvalid      ),
    .bready                  ( bready      )
);/*}}}*/
endmodule
