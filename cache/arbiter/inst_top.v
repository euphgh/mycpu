`timescale 1ns / 1ps
module inst_top (
    input          wire aclk   ,
    input          wire aresetn,

`ifdef EN_ICACHE_OP/*{{{*/
    input         icache_req  ,
    input  [4 :0] icache_op   ,
    input  [31:0] icache_addr ,
    input  [19:0] icache_tag  ,
    input         icache_valid,
    output        icache_ok   ,
`endif/*}}}*/

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
    output           inst_data_ok     ,/*}}}*/

    //  AXI接口信号定义:{{{
    output [3 :0] arid   ,
    output [31:0] araddr ,
    output [3 :0] arlen  ,
    output [2 :0] arsize ,
    output [1 :0] arburst,
    output [1 :0] arlock ,
    output [3 :0] arcache,
    output [2 :0] arprot , 
    output        arvalid,
    input         arready,

    input  [3 :0] rid    ,
    input  [31:0] rdata  ,
    input  [1 :0] rresp  ,
    input         rlast  ,
    input         rvalid ,
    output        rready ,

    output [3 :0] awid   ,
    output [31:0] awaddr ,
    output [3 :0] awlen  ,
    output [2 :0] awsize ,
    output [1 :0] awburst,
    output [1 :0] awlock ,
    output [3 :0] awcache,
    output [2 :0] awprot ,
    output        awvalid,
    input         awready,

    output [3 :0] wid    ,
    output [31:0] wdata  ,
    output [3 :0] wstrb  ,
    output        wlast  ,
    output        wvalid ,
    input         wready ,

    input  [3 :0] bid    ,
    input         bvalid ,
    input  [1 :0] bresp  ,
    output        bready/*}}}*/
);

    //------------Inst Cache-----------{{{
    wire  [3 :0] inst_cache_arid   ;
    wire  [31:0] inst_cache_araddr ;
    wire  [3 :0] inst_cache_arlen  ;
    wire  [2 :0] inst_cache_arsize ;
    wire  [1 :0] inst_cache_arburst;
    wire  [1 :0] inst_cache_arlock ;
    wire  [3 :0] inst_cache_arcache;
    wire  [2 :0] inst_cache_arprot ;
    wire         inst_cache_arvalid;
    wire         inst_cache_arready;

    wire  [3 :0] inst_cache_rid    ;
    wire  [31:0] inst_cache_rdata  ;
    wire  [1 :0] inst_cache_rresp  ;
    wire         inst_cache_rlast  ;
    wire         inst_cache_rvalid ;
    wire         inst_cache_rready ;

    wire  [3 :0] inst_cache_awid   ;
    wire  [31:0] inst_cache_awaddr ;
    wire  [3 :0] inst_cache_awlen  ;
    wire  [2 :0] inst_cache_awsize ;
    wire  [1 :0] inst_cache_awburst;
    wire  [1 :0] inst_cache_awlock ;
    wire  [3 :0] inst_cache_awcache;
    wire  [2 :0] inst_cache_awprot ;
    wire         inst_cache_awvalid;
    wire         inst_cache_awready;

    wire  [3 :0] inst_cache_wid    ;
    wire  [31:0] inst_cache_wdata  ;
    wire  [3 :0] inst_cache_wstrb  ;
    wire         inst_cache_wlast  ;
    wire         inst_cache_wvalid ;
    wire         inst_cache_wready ;

    wire  [3 :0] inst_cache_bid    ;
    wire  [1 :0] inst_cache_bresp  ;
    wire         inst_cache_bvalid ;
    wire         inst_cache_bready ;

    // Inst Uncache <-> Inst Cache
    wire          inst_uca_req     ;
    wire  [31 :0] inst_uca_addr    ;
    wire  [127:0] inst_uca_rdata   ;
    wire          inst_uca_addr_ok ;
    wire          inst_uca_data_ok ;

    //-----------Inst Uncache
    wire  [3 :0] inst_uncache_arid   ;
    wire  [31:0] inst_uncache_araddr ;
    wire  [3 :0] inst_uncache_arlen  ;
    wire  [2 :0] inst_uncache_arsize ;
    wire  [1 :0] inst_uncache_arburst;
    wire  [1 :0] inst_uncache_arlock ;
    wire  [3 :0] inst_uncache_arcache;
    wire  [2 :0] inst_uncache_arprot ;
    wire         inst_uncache_arvalid;
    wire         inst_uncache_arready;
    wire  [3 :0] inst_uncache_rid    ;
    wire  [31:0] inst_uncache_rdata  ;
    wire  [1 :0] inst_uncache_rresp  ;
    wire         inst_uncache_rlast  ;
    wire         inst_uncache_rvalid ;
    wire         inst_uncache_rready ;
    wire  [3 :0] inst_uncache_awid   = 0;
    wire  [31:0] inst_uncache_awaddr = 0;
    wire  [3 :0] inst_uncache_awlen  = 0;
    wire  [2 :0] inst_uncache_awsize = 0;
    wire  [1 :0] inst_uncache_awburst= 0;
    wire  [1 :0] inst_uncache_awlock = 0;
    wire  [3 :0] inst_uncache_awcache= 0;
    wire  [2 :0] inst_uncache_awprot = 0;
    wire         inst_uncache_awvalid= 0;
    wire         inst_uncache_awready   ;
    wire  [3 :0] inst_uncache_wid    = 0;
    wire  [31:0] inst_uncache_wdata  = 0;
    wire  [3 :0] inst_uncache_wstrb  = 0;
    wire         inst_uncache_wlast  = 0;
    wire         inst_uncache_wvalid = 0;
    wire         inst_uncache_wready    ;
    wire  [3 :0] inst_uncache_bid       ;
    wire  [1 :0] inst_uncache_bresp     ;
    wire         inst_uncache_bvalid    ;
    wire         inst_uncache_bready    ;
    // ICACHE and INST_UNCACHE
    icache  u_icache_tp (
        .clk                  (aclk                ),
        .rst                  (aresetn             ),
        .inst_req             (inst_req            ),
        .inst_wr              (inst_wr             ),
        .inst_size            (inst_size           ),
        .inst_index           (inst_index          ),
        .inst_tag             (inst_tag            ),
        .inst_hasException    (inst_hasException   ),
        .inst_unCache         (inst_unCache        ),
        .inst_wdata           (inst_wdata          ),
        .inst_rdata           (inst_rdata          ),
        .inst_index_ok        (inst_index_ok       ),
        .inst_data_ok         (inst_data_ok        ),
        .arid                 (inst_cache_arid     ),
        .araddr               (inst_cache_araddr   ),
        .arlen                (inst_cache_arlen    ),
        .arsize               (inst_cache_arsize   ),
        .arburst              (inst_cache_arburst  ),
        .arlock               (inst_cache_arlock   ),
        .arcache              (inst_cache_arcache  ),
        .arprot               (inst_cache_arprot   ), 
        .arvalid              (inst_cache_arvalid  ),
        .arready              (inst_cache_arready  ),
        .rid                  (inst_cache_rid      ),
        .rdata                (inst_cache_rdata    ),
        .rresp                (inst_cache_rresp    ),
        .rlast                (inst_cache_rlast    ),
        .rvalid               (inst_cache_rvalid   ),
        .rready               (inst_cache_rready   ),
        .awid                 (inst_cache_awid     ),
        .awaddr               (inst_cache_awaddr   ),
        .awlen                (inst_cache_awlen    ),
        .awsize               (inst_cache_awsize   ),
        .awburst              (inst_cache_awburst  ),
        .awlock               (inst_cache_awlock   ),
        .awcache              (inst_cache_awcache  ),
        .awprot               (inst_cache_awprot   ),
        .awvalid              (inst_cache_awvalid  ),
        .awready              (inst_cache_awready  ),
        .wid                  (inst_cache_wid      ),
        .wdata                (inst_cache_wdata    ),
        .wstrb                (inst_cache_wstrb    ),
        .wlast                (inst_cache_wlast    ),
        .wvalid               (inst_cache_wvalid   ),
        .wready               (inst_cache_wready   ),
        .bid                  (inst_cache_bid      ),
        .bvalid               (inst_cache_bvalid   ),
        .bresp                (inst_cache_bresp    ),
        .bready               (inst_cache_bready   ),
        .inst_uncache_req     (inst_uca_req        ),
        .inst_uncache_addr    (inst_uca_addr       ),
        .inst_uncache_rdata   (inst_uca_rdata      ),
        .inst_uncache_addr_ok (inst_uca_addr_ok    ),
        .inst_uncache_data_ok (inst_uca_data_ok    )
    );
    inst_uncache u_inst_uncache (
        .clk          (aclk                ),
        .rst          (aresetn             ),
        .inst_req     (inst_uca_req        ),
        .inst_addr    (inst_uca_addr       ),
        .inst_rdata   (inst_uca_rdata      ),
        .inst_addr_ok (inst_uca_addr_ok    ),
        .inst_data_ok (inst_uca_data_ok    ),
        .arid         (inst_uncache_arid   ),
        .araddr       (inst_uncache_araddr ),
        .arlen        (inst_uncache_arlen  ),
        .arsize       (inst_uncache_arsize ),
        .arburst      (inst_uncache_arburst),
        .arlock       (inst_uncache_arlock ),
        .arcache      (inst_uncache_arcache),
        .arprot       (inst_uncache_arprot ), 
        .arvalid      (inst_uncache_arvalid),
        .arready      (inst_uncache_arready),
        .rid          (inst_uncache_rid    ),
        .rdata        (inst_uncache_rdata  ),
        .rresp        (inst_uncache_rresp  ),
        .rlast        (inst_uncache_rlast  ),
        .rvalid       (inst_uncache_rvalid ),
        .rready       (inst_uncache_rready )
    );/*}}}*/

inst_mux  u_inst_mux (/*{{{*/
    .arid_ic                 ( inst_cache_arid      ),
    .araddr_ic               ( inst_cache_araddr    ),
    .arlen_ic                ( inst_cache_arlen     ),
    .arsize_ic               ( inst_cache_arsize    ),
    .arburst_ic              ( inst_cache_arburst   ),
    .arlock_ic               ( inst_cache_arlock    ),
    .arcache_ic              ( inst_cache_arcache   ),
    .arprot_ic               ( inst_cache_arprot    ),
    .arvalid_ic              ( inst_cache_arvalid   ),
    .arready_ic              ( inst_cache_arready   ),
    .awid_ic                 ( inst_cache_awid      ),
    .awaddr_ic               ( inst_cache_awaddr    ),
    .awlen_ic                ( inst_cache_awlen     ),
    .awsize_ic               ( inst_cache_awsize    ),
    .awburst_ic              ( inst_cache_awburst   ),
    .awlock_ic               ( inst_cache_awlock    ),
    .awcache_ic              ( inst_cache_awcache   ),
    .awprot_ic               ( inst_cache_awprot    ),
    .awvalid_ic              ( inst_cache_awvalid   ),
    .awready_ic              ( inst_cache_awready   ),
    .wid_ic                  ( inst_cache_wid       ),
    .wdata_ic                ( inst_cache_wdata     ),
    .wstrb_ic                ( inst_cache_wstrb     ),
    .wlast_ic                ( inst_cache_wlast     ),
    .wvalid_ic               ( inst_cache_wvalid    ),
    .wready_ic               ( inst_cache_wready    ),
    .rid_ic                  ( inst_cache_rid       ),
    .rdata_ic                ( inst_cache_rdata     ),
    .rresp_ic                ( inst_cache_rresp     ),
    .rlast_ic                ( inst_cache_rlast     ),
    .rvalid_ic               ( inst_cache_rvalid    ),
    .rready_ic               ( inst_cache_rready    ),
    .bid_ic                  ( inst_cache_bid       ),
    .bvalid_ic               ( inst_cache_bvalid    ),
    .bresp_ic                ( inst_cache_bresp     ),
    .bready_ic               ( inst_cache_bready    ),

    .clk                     ( aclk         ),
    .rst_n                   ( aresetn      ),
    .arid_iu                 ( inst_uncache_arid      ),
    .araddr_iu               ( inst_uncache_araddr    ),
    .arlen_iu                ( inst_uncache_arlen     ),
    .arsize_iu               ( inst_uncache_arsize    ),
    .arburst_iu              ( inst_uncache_arburst   ),
    .arlock_iu               ( inst_uncache_arlock    ),
    .arcache_iu              ( inst_uncache_arcache   ),
    .arprot_iu               ( inst_uncache_arprot    ),
    .arvalid_iu              ( inst_uncache_arvalid   ),
    .arready_iu              ( inst_uncache_arready   ),
    .awid_iu                 ( inst_uncache_awid      ),
    .awaddr_iu               ( inst_uncache_awaddr    ),
    .awlen_iu                ( inst_uncache_awlen     ),
    .awsize_iu               ( inst_uncache_awsize    ),
    .awburst_iu              ( inst_uncache_awburst   ),
    .awlock_iu               ( inst_uncache_awlock    ),
    .awcache_iu              ( inst_uncache_awcache   ),
    .awprot_iu               ( inst_uncache_awprot    ),
    .awvalid_iu              ( inst_uncache_awvalid   ),
    .awready_iu              ( inst_uncache_awready   ),
    .wid_iu                  ( inst_uncache_wid       ),
    .wdata_iu                ( inst_uncache_wdata     ),
    .wstrb_iu                ( inst_uncache_wstrb     ),
    .wlast_iu                ( inst_uncache_wlast     ),
    .wvalid_iu               ( inst_uncache_wvalid    ),
    .wready_iu               ( inst_uncache_wready    ),
    .rid_iu                  ( inst_uncache_rid       ),
    .rdata_iu                ( inst_uncache_rdata     ),
    .rresp_iu                ( inst_uncache_rresp     ),
    .rlast_iu                ( inst_uncache_rlast     ),
    .rvalid_iu               ( inst_uncache_rvalid    ),
    .rready_iu               ( inst_uncache_rready    ),
    .bid_iu                  ( inst_uncache_bid       ),
    .bvalid_iu               ( inst_uncache_bvalid    ),
    .bresp_iu                ( inst_uncache_bresp     ),
    .bready_iu               ( inst_uncache_bready    ),

    .arready                 ( arready      ),
    .rid                     ( rid          ),
    .rdata                   ( rdata        ),
    .rresp                   ( rresp        ),
    .rlast                   ( rlast        ),
    .rvalid                  ( rvalid       ),
    .awready                 ( awready      ),
    .wready                  ( wready       ),
    .bid                     ( bid          ),
    .bvalid                  ( bvalid       ),
    .bresp                   ( bresp        ),
    .arid                    ( arid         ),
    .araddr                  ( araddr       ),
    .arlen                   ( arlen        ),
    .arsize                  ( arsize       ),
    .arburst                 ( arburst      ),
    .arlock                  ( arlock       ),
    .arcache                 ( arcache      ),
    .arprot                  ( arprot       ),
    .arvalid                 ( arvalid      ),
    .rready                  ( rready       ),
    .awid                    ( awid         ),
    .awaddr                  ( awaddr       ),
    .awlen                   ( awlen        ),
    .awsize                  ( awsize       ),
    .awburst                 ( awburst      ),
    .awlock                  ( awlock       ),
    .awcache                 ( awcache      ),
    .awprot                  ( awprot       ),
    .awvalid                 ( awvalid      ),
    .wid                     ( wid          ),
    .wdata                   ( wdata        ),
    .wstrb                   ( wstrb        ),
    .wlast                   ( wlast        ),
    .wvalid                  ( wvalid       ),
    .bready                  ( bready       )
);/*}}}*/

endmodule
