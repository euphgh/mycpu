`timescale 1ns / 100ps
`include "./core/MyDefines.v"
module mycpu_top(
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
    /*autodef*/
    //Start of automatic define
    //Start of automatic reg
    //Define flip-flop registers here
    //Define combination registers here
    //End of automatic reg
    //Start of automatic wire
    //Define assign wires here
    //Define instance wires here
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
    wire [`SINGLE_WORD]         debug_wb_rf_wdata1              ;
    wire                        dcache_req  ;
    wire           [4 :0]       dcache_op   ;
    wire           [31:0]       dcache_addr ;
    wire           [19:0]       dcache_tag  ;
    wire                        dcache_valid;
    wire                        dcache_dirty;
    wire                        dcache_ok   ;
    wire                        icache_req  ;
    wire          [4 :0]        icache_op   ;
    wire          [31:0]        icache_addr ;
    wire          [19:0]        icache_tag  ;
    wire                        icache_valid;
    wire                        icache_ok   ;
    //End of automatic wire
    //End of automatic define
    Main  u_Main (//{{{
    .clk                     ( aclk                 ),
    .rst                     ( aresetn              ),
    .ext_int                 ( ext_int              ),
    .inst_rdata              ( inst_rdata           ),
    .inst_index_ok           ( inst_index_ok        ),
    .inst_data_ok            ( inst_data_ok         ),
    .data_rdata              ( data_rdata           ),
    .data_index_ok           ( data_index_ok        ),
    .icache_ok               ( icache_ok            ),

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
    .data_data_ok            ( data_data_ok         ),
    .data_tag                ( data_tag             ),
    .data_unCache            ( data_unCache         ),
    .data_hasException       ( data_hasException    ),
    .data_wstrb              ( data_wstrb           ),
    .data_wdata              ( data_wdata           ),
    .dcache_req              ( dcache_req           ),
    .dcache_op               ( dcache_op            ),
    .dcache_addr             ( dcache_addr          ),
    .dcache_tag              ( dcache_tag           ),
    .dcache_valid            ( dcache_valid         ),
    .dcache_dirty            ( dcache_dirty         ),
    .dcache_ok               ( dcache_ok            ),
    .icache_req              ( icache_req           ),
    .icache_op               ( icache_op            ),
    .icache_addr             ( icache_addr          ),
    .icache_tag              ( icache_tag           ),
    .icache_valid            ( icache_valid         ),
    .debug_wb_pc0            ( debug_wb_pc0         ),
    .debug_wb_pc1            ( debug_wb_pc1         ),
    .debug_wb_rf_wen0        ( debug_wb_rf_wen0     ),
    .debug_wb_rf_wen1        ( debug_wb_rf_wen1     ),
    .debug_wb_rf_wnum0       ( debug_wb_rf_wnum0    ),
    .debug_wb_rf_wnum1       ( debug_wb_rf_wnum1    ),
    .debug_wb_rf_wdata0      ( debug_wb_rf_wdata0   ),
    .debug_wb_rf_wdata1      ( debug_wb_rf_wdata1   )
);
    // }}}
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
    wire         inst_uncache_awready= 0;
    wire  [3 :0] inst_uncache_wid    = 0;
    wire  [31:0] inst_uncache_wdata  = 0;
    wire  [3 :0] inst_uncache_wstrb  = 0;
    wire         inst_uncache_wlast  = 0;
    wire         inst_uncache_wvalid = 0;
    wire         inst_uncache_wready = 0;
    wire  [3 :0] inst_uncache_bid    = 0;
    wire  [1 :0] inst_uncache_bresp  = 0;
    wire         inst_uncache_bvalid = 0;
    wire         inst_uncache_bready = 0;
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
        .icache_req           (icache_req          ),
        .icache_op            (icache_op           ),
        .icache_addr          (icache_addr         ),
        .icache_tag           (icache_tag          ),
        .icache_valid         (icache_valid        ),
        .icache_ok            (icache_ok           ),
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
        .dcache_req           (dcache_req          ),
        .dcache_op            (dcache_op           ),
        .dcache_addr          (dcache_addr         ),
        .dcache_tag           (dcache_tag          ),
        .dcache_valid         (dcache_valid        ),
        .dcache_dirty         (dcache_dirty        ),
        .dcache_ok            (dcache_ok           ),
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
    //-----Axi Bridge{{{
    axi_crossbar_0 u_axi_crossbar_0 (

        .aclk             (aclk   ),
        .aresetn          (aresetn),

        .s_axi_arid       ({data_cache_arid,        inst_cache_arid,        data_uncache_arid,          inst_uncache_arid}      ),
        .s_axi_araddr     ({data_cache_araddr,      inst_cache_araddr,      data_uncache_araddr,        inst_uncache_araddr}    ),
        .s_axi_arlen      ({data_cache_arlen,       inst_cache_arlen,       data_uncache_arlen,         inst_uncache_arlen}     ),
        .s_axi_arsize     ({data_cache_arsize,      inst_cache_arsize,      data_uncache_arsize,        inst_uncache_arsize}    ),
        .s_axi_arburst    ({data_cache_arburst,     inst_cache_arburst,     data_uncache_arburst,       inst_uncache_arburst}   ),
        .s_axi_arlock     ({data_cache_arlock,      inst_cache_arlock,      data_uncache_arlock,        inst_uncache_arlock}    ),
        .s_axi_arcache    ({data_cache_arcache,     inst_cache_arcache,     data_uncache_arcache,       inst_uncache_arcache}   ),
        .s_axi_arprot     ({data_cache_arprot,      inst_cache_arprot,      data_uncache_arprot,        inst_uncache_arprot}    ),
        .s_axi_arqos      ({4'd0,                   4'd0,                   4'd0,                       4'd0}                   ),
        .s_axi_arvalid    ({data_cache_arvalid,     inst_cache_arvalid,     data_uncache_arvalid,       inst_uncache_arvalid}   ),
        .s_axi_arready    ({data_cache_arready,     inst_cache_arready,     data_uncache_arready,       inst_uncache_arready}   ),

        .s_axi_rid        ({data_cache_rid,         inst_cache_rid,         data_uncache_rid,           inst_uncache_rid}       ),
        .s_axi_rdata      ({data_cache_rdata,       inst_cache_rdata,       data_uncache_rdata,         inst_uncache_rdata}     ),
        .s_axi_rresp      ({data_cache_rresp,       inst_cache_rresp,       data_uncache_rresp,         inst_uncache_rresp}     ),
        .s_axi_rlast      ({data_cache_rlast,       inst_cache_rlast,       data_uncache_rlast,         inst_uncache_rlast}     ),
        .s_axi_rvalid     ({data_cache_rvalid,      inst_cache_rvalid,      data_uncache_rvalid,        inst_uncache_rvalid}    ),
        .s_axi_rready     ({data_cache_rready,      inst_cache_rready,      data_uncache_rready,        inst_uncache_rready}    ),

        .s_axi_awid       ({data_cache_awid,        inst_cache_awid,        data_uncache_awid,          inst_uncache_awid}      ),
        .s_axi_awaddr     ({data_cache_awaddr,      inst_cache_awaddr,      data_uncache_awaddr,        inst_uncache_awaddr}    ),
        .s_axi_awlen      ({data_cache_awlen,       inst_cache_awlen,       data_uncache_awlen,         inst_uncache_awlen}     ),
        .s_axi_awsize     ({data_cache_awsize,      inst_cache_awsize,      data_uncache_awsize,        inst_uncache_awsize}    ),
        .s_axi_awburst    ({data_cache_awburst,     inst_cache_awburst,     data_uncache_awburst,       inst_uncache_awburst}   ),
        .s_axi_awlock     ({data_cache_awlock,      inst_cache_awlock,      data_uncache_awlock,        inst_uncache_awlock}    ),
        .s_axi_awcache    ({data_cache_awcache,     inst_cache_awcache,     data_uncache_awcache,       inst_uncache_awcache}   ),
        .s_axi_awprot     ({data_cache_awprot,      inst_cache_awprot,      data_uncache_awprot,        inst_uncache_awprot}    ),
        .s_axi_awqos      ({4'd0,                   4'd0,                   4'd0,                       4'd0}                   ),
        .s_axi_awvalid    ({data_cache_awvalid,     inst_cache_awvalid,     data_uncache_awvalid,       inst_uncache_awvalid}   ),
        .s_axi_awready    ({data_cache_awready,     inst_cache_awready,     data_uncache_awready,       inst_uncache_awready}   ),

        .s_axi_wid        ({data_cache_wid,         inst_cache_wid,         data_uncache_wid,           inst_uncache_wid}       ),
        .s_axi_wdata      ({data_cache_wdata,       inst_cache_wdata,       data_uncache_wdata,         inst_uncache_wdata}     ),
        .s_axi_wstrb      ({data_cache_wstrb,       inst_cache_wstrb,       data_uncache_wstrb,         inst_uncache_wstrb}     ),
        .s_axi_wlast      ({data_cache_wlast,       inst_cache_wlast,       data_uncache_wlast,         inst_uncache_wlast}     ),
        .s_axi_wvalid     ({data_cache_wvalid,      inst_cache_wvalid,      data_uncache_wvalid,        inst_uncache_wvalid}    ),
        .s_axi_wready     ({data_cache_wready,      inst_cache_wready,      data_uncache_wready,        inst_uncache_wready}    ),
        .s_axi_bid        ({data_cache_bid,         inst_cache_bid,         data_uncache_bid,           inst_uncache_bid}       ),
        .s_axi_bresp      ({data_cache_bresp,       inst_cache_bresp,       data_uncache_bresp,         inst_uncache_bresp}     ),
        .s_axi_bvalid     ({data_cache_bvalid,      inst_cache_bvalid,      data_uncache_bvalid,        inst_uncache_bvalid}    ),
        .s_axi_bready     ({data_cache_bready,      inst_cache_bready,      data_uncache_bready,        inst_uncache_bready}    ),

        .m_axi_arid       (arid   ),
        .m_axi_araddr     (araddr ),
        .m_axi_arlen      (arlen  ),
        .m_axi_arsize     (arsize ),
        .m_axi_arburst    (arburst),
        .m_axi_arlock     (arlock ),
        .m_axi_arcache    (arcache),
        .m_axi_arprot     (arprot ),
        .m_axi_arqos      (       ),
        .m_axi_arvalid    (arvalid),
        .m_axi_arready    (arready),
        .m_axi_rid        (rid    ),
        .m_axi_rdata      (rdata  ),
        .m_axi_rresp      (rresp  ),
        .m_axi_rlast      (rlast  ),
        .m_axi_rvalid     (rvalid ),
        .m_axi_rready     (rready ),
        .m_axi_awid       (awid   ),
        .m_axi_awaddr     (awaddr ),
        .m_axi_awlen      (awlen  ),
        .m_axi_awsize     (awsize ),
        .m_axi_awburst    (awburst),
        .m_axi_awlock     (awlock ),
        .m_axi_awcache    (awcache),
        .m_axi_awprot     (awprot ),
        .m_axi_awqos      (       ),
        .m_axi_awvalid    (awvalid),
        .m_axi_awready    (awready),
        .m_axi_wid        (wid    ),
        .m_axi_wdata      (wdata  ),
        .m_axi_wstrb      (wstrb  ),
        .m_axi_wlast      (wlast  ),
        .m_axi_wvalid     (wvalid ),
        .m_axi_wready     (wready ),
        .m_axi_bid        (bid    ),
        .m_axi_bresp      (bresp  ),
        .m_axi_bvalid     (bvalid ),
        .m_axi_bready     (bready )
    );
    //}}}
endmodule
