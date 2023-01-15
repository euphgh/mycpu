`timescale 1ns / 1ps
module data_top (
    input          wire aclk   ,
    input          wire aresetn,

`ifdef EN_DCACHE_OP/*{{{*/
    input         dcache_req  ,
    input  [4 :0] dcache_op   ,
    input  [31:0] dcache_addr ,
    input  [19:0] dcache_tag  ,
    input         dcache_valid,
    input         dcache_dirty,
    output        dcache_ok   ,
`endif /*}}}*/

    //CPU interface{{{
    input         data_req         ,
    input         data_wr          ,
    input  [1 :0] data_size        ,
    input  [11:0] data_index       , // index + offset 
    input  [19:0] data_tag         ,
    input         data_hasException,
    input         data_unCache     ,
    input  [3 :0] data_wstrb       ,
    input  [31:0] data_wdata       ,
    output [31:0] data_rdata       ,
    output        data_index_ok    ,
    output        data_data_ok     ,/*}}}*/

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
    output        bready  /*}}}*/
);
        //------------Data Cache{{{
    wire  [3 :0] data_cache_arid   ;
    wire  [31:0] data_cache_araddr ;
    wire  [3 :0] data_cache_arlen  ;
    wire  [2 :0] data_cache_arsize ;
    wire  [1 :0] data_cache_arburst;
    wire  [1 :0] data_cache_arlock ;
    wire  [3 :0] data_cache_arcache;
    wire  [2 :0] data_cache_arprot ;
    wire         data_cache_arvalid;
    wire         data_cache_arready;

    wire  [3 :0] data_cache_rid    ;
    wire  [31:0] data_cache_rdata  ;
    wire  [1 :0] data_cache_rresp  ;
    wire         data_cache_rlast  ;
    wire         data_cache_rvalid ;
    wire         data_cache_rready ;

    wire  [3 :0] data_cache_awid   ;
    wire  [31:0] data_cache_awaddr ;
    wire  [3 :0] data_cache_awlen  ;
    wire  [2 :0] data_cache_awsize ;
    wire  [1 :0] data_cache_awburst;
    wire  [1 :0] data_cache_awlock ;
    wire  [3 :0] data_cache_awcache;
    wire  [2 :0] data_cache_awprot ;
    wire         data_cache_awvalid;
    wire         data_cache_awready;

    wire  [3 :0] data_cache_wid    ;
    wire  [31:0] data_cache_wdata  ;
    wire  [3 :0] data_cache_wstrb  ;
    wire         data_cache_wlast  ;
    wire         data_cache_wvalid ;
    wire         data_cache_wready ;

    wire  [3 :0] data_cache_bid    ;
    wire  [1 :0] data_cache_bresp  ;
    wire         data_cache_bvalid ;
    wire         data_cache_bready ;

    // Data Uncache <-> Data Cache
    wire        data_uca_req    ;
    wire        data_uca_wr     ;
    wire [1 :0] data_uca_size   ;
    wire [31:0] data_uca_addr   ;
    wire [31:0] data_uca_wdata  ;
    wire [3 :0] data_uca_wstrb  ;
    wire [31:0] data_uca_rdata  ;
    wire        data_uca_addr_ok;
    wire        data_uca_data_ok;

    //-----------Data Uncache
    wire  [3 :0] data_uncache_arid   ;
    wire  [31:0] data_uncache_araddr ;
    wire  [3 :0] data_uncache_arlen  ;
    wire  [2 :0] data_uncache_arsize ;
    wire  [1 :0] data_uncache_arburst;
    wire  [1 :0] data_uncache_arlock ;
    wire  [3 :0] data_uncache_arcache;
    wire  [2 :0] data_uncache_arprot ;
    wire         data_uncache_arvalid;
    wire         data_uncache_arready;

    wire  [3 :0] data_uncache_rid    ;
    wire  [31:0] data_uncache_rdata  ;
    wire  [1 :0] data_uncache_rresp  ;
    wire         data_uncache_rlast  ;
    wire         data_uncache_rvalid ;
    wire         data_uncache_rready ;

    wire  [3 :0] data_uncache_awid   ;
    wire  [31:0] data_uncache_awaddr ;
    wire  [3 :0] data_uncache_awlen  ;
    wire  [2 :0] data_uncache_awsize ;
    wire  [1 :0] data_uncache_awburst;
    wire  [1 :0] data_uncache_awlock ;
    wire  [3 :0] data_uncache_awcache;
    wire  [2 :0] data_uncache_awprot ;
    wire         data_uncache_awvalid;
    wire         data_uncache_awready;

    wire  [3 :0] data_uncache_wid    ;
    wire  [31:0] data_uncache_wdata  ;
    wire  [3 :0] data_uncache_wstrb  ;
    wire         data_uncache_wlast  ;
    wire         data_uncache_wvalid ;
    wire         data_uncache_wready ;

    wire  [3 :0] data_uncache_bid    ;
    wire  [1 :0] data_uncache_bresp  ;
    wire         data_uncache_bvalid ;
    wire         data_uncache_bready ;
    dcache u_dcache_tp (
        .clk                  (aclk                ),
        .rst                  (aresetn             ),
        .data_req             (data_req            ),
        .data_wr              (data_wr             ),
        .data_size            (data_size           ),
        .data_index           (data_index          ),
        .data_tag             (data_tag            ),
        .data_hasException    (data_hasException   ),
        .data_unCache         (data_unCache        ),
        .data_wstrb           (data_wstrb          ),
        .data_wdata           (data_wdata          ),
        .data_rdata           (data_rdata          ),
        .data_index_ok        (data_index_ok       ),
        .data_data_ok         (data_data_ok        ),
        .arid                 (data_cache_arid     ),
        .araddr               (data_cache_araddr   ),
        .arlen                (data_cache_arlen    ),
        .arsize               (data_cache_arsize   ),
        .arburst              (data_cache_arburst  ),
        .arlock               (data_cache_arlock   ),
        .arcache              (data_cache_arcache  ),
        .arprot               (data_cache_arprot   ), 
        .arvalid              (data_cache_arvalid  ),
        .arready              (data_cache_arready  ),
        .rid                  (data_cache_rid      ),
        .rdata                (data_cache_rdata    ),
        .rresp                (data_cache_rresp    ),
        .rlast                (data_cache_rlast    ),
        .rvalid               (data_cache_rvalid   ),
        .rready               (data_cache_rready   ),
        .awid                 (data_cache_awid     ),
        .awaddr               (data_cache_awaddr   ),
        .awlen                (data_cache_awlen    ),
        .awsize               (data_cache_awsize   ),
        .awburst              (data_cache_awburst  ),
        .awlock               (data_cache_awlock   ),
        .awcache              (data_cache_awcache  ),
        .awprot               (data_cache_awprot   ),
        .awvalid              (data_cache_awvalid  ),
        .awready              (data_cache_awready  ),
        .wid                  (data_cache_wid      ),
        .wdata                (data_cache_wdata    ),
        .wstrb                (data_cache_wstrb    ),
        .wlast                (data_cache_wlast    ),
        .wvalid               (data_cache_wvalid   ),
        .wready               (data_cache_wready   ),
        .bid                  (data_cache_bid      ),
        .bvalid               (data_cache_bvalid   ),
        .bresp                (data_cache_bresp    ),
        .bready               (data_cache_bready   ),
        .data_uncache_req     (data_uca_req    ),
        .data_uncache_size    (data_uca_size   ),
        .data_uncache_wr      (data_uca_wr     ),
        .data_uncache_addr    (data_uca_addr   ),
        .data_uncache_wdata   (data_uca_wdata  ),
        .data_uncache_wstrb   (data_uca_wstrb  ),
        .data_uncache_rdata   (data_uca_rdata  ),
        .data_uncache_addr_ok (data_uca_addr_ok),
        .data_uncache_data_ok (data_uca_data_ok)
    );
    data_uncache u_data_uncache(
        .clk                  (aclk                ),
        .rst                  (aresetn             ),
        .data_req             (data_uca_req        ),
        .data_size            (data_uca_size       ),
        .data_wr              (data_uca_wr         ),
        .data_addr            (data_uca_addr       ),
        .data_wdata           (data_uca_wdata      ),
        .data_wstrb           (data_uca_wstrb      ),
        .data_rdata           (data_uca_rdata      ),
        .data_addr_ok         (data_uca_addr_ok    ),
        .data_data_ok         (data_uca_data_ok    ),
        .arid                 (data_uncache_arid   ),
        .araddr               (data_uncache_araddr ),
        .arlen                (data_uncache_arlen  ),
        .arsize               (data_uncache_arsize ),
        .arburst              (data_uncache_arburst),
        .arlock               (data_uncache_arlock ),
        .arcache              (data_uncache_arcache),
        .arprot               (data_uncache_arprot ), 
        .arvalid              (data_uncache_arvalid),
        .arready              (data_uncache_arready),
        .rid                  (data_uncache_rid    ),
        .rdata                (data_uncache_rdata  ),
        .rresp                (data_uncache_rresp  ),
        .rlast                (data_uncache_rlast  ),
        .rvalid               (data_uncache_rvalid ),
        .rready               (data_uncache_rready ),
        .awid                 (data_uncache_awid   ),
        .awaddr               (data_uncache_awaddr ),
        .awlen                (data_uncache_awlen  ),
        .awsize               (data_uncache_awsize ),
        .awburst              (data_uncache_awburst),
        .awlock               (data_uncache_awlock ),
        .awcache              (data_uncache_awcache),
        .awprot               (data_uncache_awprot ),
        .awvalid              (data_uncache_awvalid),
        .awready              (data_uncache_awready),
        .wid                  (data_uncache_wid    ),
        .wdata                (data_uncache_wdata  ),
        .wstrb                (data_uncache_wstrb  ),
        .wlast                (data_uncache_wlast  ),
        .wvalid               (data_uncache_wvalid ),
        .wready               (data_uncache_wready ),
        .bid                  (data_uncache_bid    ),
        .bvalid               (data_uncache_bvalid ),
        .bresp                (data_uncache_bresp  ),
        .bready               (data_uncache_bready )
    );
    //}}}
data_mux  u_data_mux (/*{{{*/
    .clk                     ( aclk         ),
    .rst_n                   ( aresetn      ),

    .arid_dc                 ( data_cache_arid      ),
    .araddr_dc               ( data_cache_araddr    ),
    .arlen_dc                ( data_cache_arlen     ),
    .arsize_dc               ( data_cache_arsize    ),
    .arburst_dc              ( data_cache_arburst   ),
    .arlock_dc               ( data_cache_arlock    ),
    .arcache_dc              ( data_cache_arcache   ),
    .arprot_dc               ( data_cache_arprot    ),
    .arvalid_dc              ( data_cache_arvalid   ),
    .rready_dc               ( data_cache_rready    ),
    .awid_dc                 ( data_cache_awid      ),
    .awaddr_dc               ( data_cache_awaddr    ),
    .awlen_dc                ( data_cache_awlen     ),
    .awsize_dc               ( data_cache_awsize    ),
    .awburst_dc              ( data_cache_awburst   ),
    .awlock_dc               ( data_cache_awlock    ),
    .awcache_dc              ( data_cache_awcache   ),
    .awprot_dc               ( data_cache_awprot    ),
    .awvalid_dc              ( data_cache_awvalid   ),
    .wid_dc                  ( data_cache_wid       ),
    .wdata_dc                ( data_cache_wdata     ),
    .wstrb_dc                ( data_cache_wstrb     ),
    .wlast_dc                ( data_cache_wlast     ),
    .wvalid_dc               ( data_cache_wvalid    ),
    .bready_dc               ( data_cache_bready    ),
    .arready_dc              ( data_cache_arready   ),
    .rid_dc                  ( data_cache_rid       ),
    .rdata_dc                ( data_cache_rdata     ),
    .rresp_dc                ( data_cache_rresp     ),
    .rlast_dc                ( data_cache_rlast     ),
    .rvalid_dc               ( data_cache_rvalid    ),
    .awready_dc              ( data_cache_awready   ),
    .wready_dc               ( data_cache_wready    ),
    .bid_dc                  ( data_cache_bid       ),
    .bvalid_dc               ( data_cache_bvalid    ),
    .bresp_dc                ( data_cache_bresp     ),

    .arid_du                 ( data_uncache_arid      ),
    .araddr_du               ( data_uncache_araddr    ),
    .arlen_du                ( data_uncache_arlen     ),
    .arsize_du               ( data_uncache_arsize    ),
    .arburst_du              ( data_uncache_arburst   ),
    .arlock_du               ( data_uncache_arlock    ),
    .arcache_du              ( data_uncache_arcache   ),
    .arprot_du               ( data_uncache_arprot    ),
    .arvalid_du              ( data_uncache_arvalid   ),
    .rready_du               ( data_uncache_rready    ),
    .awid_du                 ( data_uncache_awid      ),
    .awaddr_du               ( data_uncache_awaddr    ),
    .awlen_du                ( data_uncache_awlen     ),
    .awsize_du               ( data_uncache_awsize    ),
    .awburst_du              ( data_uncache_awburst   ),
    .awlock_du               ( data_uncache_awlock    ),
    .awcache_du              ( data_uncache_awcache   ),
    .awprot_du               ( data_uncache_awprot    ),
    .awvalid_du              ( data_uncache_awvalid   ),
    .wid_du                  ( data_uncache_wid       ),
    .wdata_du                ( data_uncache_wdata     ),
    .wstrb_du                ( data_uncache_wstrb     ),
    .wlast_du                ( data_uncache_wlast     ),
    .wvalid_du               ( data_uncache_wvalid    ),
    .bready_du               ( data_uncache_bready    ),
    .arready_du              ( data_uncache_arready   ),
    .rid_du                  ( data_uncache_rid       ),
    .rdata_du                ( data_uncache_rdata     ),
    .rresp_du                ( data_uncache_rresp     ),
    .rlast_du                ( data_uncache_rlast     ),
    .rvalid_du               ( data_uncache_rvalid    ),
    .awready_du              ( data_uncache_awready   ),
    .wready_du               ( data_uncache_wready    ),
    .bid_du                  ( data_uncache_bid       ),
    .bvalid_du               ( data_uncache_bvalid    ),
    .bresp_du                ( data_uncache_bresp     ),

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
    .wid                     ( wid          ),
    .wdata                   ( wdata        ),
    .wstrb                   ( wstrb        ),
    .wlast                   ( wlast        ),
    .wvalid                  ( wvalid       ),
    .bready                  ( bready       )
);/*}}}*/
endmodule
