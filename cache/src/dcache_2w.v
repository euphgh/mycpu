`timescale 1ns / 1ps
`include "../Cacheconst.vh"
//`define EN_DCACHE_OP
// LINE  64 128 256
// BLOCK 16 8   4
module dcache_2w#(
    parameter LINE  = 128,
    parameter BLOCK = 8
)(
    input           clk,
    input           rst,

`ifdef EN_DCACHE_OP
    input         dcache_req  ,
    input  [4 :0] dcache_op   ,
    input  [31:0] dcache_addr ,
    input  [19:0] dcache_tag  ,
    input         dcache_valid,
    input         dcache_dirty,
    output        dcache_ok   ,
`endif

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
    output        data_data_ok     ,

    //  AXI接口信号定义:
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
    output        bready ,

    // data_uncache
    output        data_uncache_req,
    output        data_uncache_wr,
    output [1 :0] data_uncache_size,
    output [31:0] data_uncache_addr,
    output [3 :0] data_uncache_wstrb,
    output [31:0] data_uncache_wdata,
    input  [31:0] data_uncache_rdata,
    input         data_uncache_addr_ok,
    input         data_uncache_data_ok
);
    ////////////////////////////////////////////////////////
    //LOCAL PARAM
    localparam INDEX    = $clog2(LINE);
    localparam OFFSET   = 12 - INDEX  ;
    localparam LINESIZE = 32*BLOCK    ;
    localparam WEN_LEN  = 4 * BLOCK   ;
    ////////////////////////////////////////////////////////
    // Signal Define
    //三段流水
    //index -> tag -> data
    //sin_ ... sta_ ... sda_ ...
    //sin段
    wire               sin_req   ;
    wire               sin_wr    ;
    wire [1        :0] sin_size  ;
    wire [INDEX-1  :0] sin_index ;
    wire [OFFSET-1 :0] sin_offset;
    wire [3        :0] sin_wstrb ;
    wire [31       :0] sin_wdata ;
    //sta段
    reg                sta_req         ;
    reg                sta_wr          ;
    reg  [1        :0] sta_size        ;
    reg  [INDEX-1  :0] sta_index       ;
    reg  [OFFSET-1 :0] sta_offset      ;
    wire [19       :0] sta_tag         ;
    wire               sta_hasException;
    wire               sta_unCache     ;
    reg  [3        :0] sta_wstrb       ;
    reg  [31       :0] sta_wdata       ;
    //sda段
    reg                sda_req            ;
    reg                sda_wr             ;
    reg [1         :0] sda_size           ;
    reg [INDEX-1   :0] sda_index          ;
    reg [OFFSET-1  :0] sda_offset         ;
    reg [19        :0] sda_tag            ;
    reg                sda_hasException   ;
    reg                sda_unCache        ;
    reg [3         :0] sda_wstrb          ;
    reg [31        :0] sda_wdata          ;
    reg [20        :0] sda_tagv_back [1:0];
    reg [LINESIZE-1:0] sda_rdata     [1:0];
    reg                sda_uca_addr_ok    ;
    reg                sda_raw_col        ;
    reg [3         :0] sda_raw_wstrb      ;
    reg [7         :0] sda_raw_data [3:0] ;
    //主自动机状态
    reg [3:0] cache_stat;
    //RESET
    reg [INDEX-1:0] reset_counter;
    //REFILL
    reg  [$clog2(BLOCK)-1:0] fill_counter         ;
    reg  [31             :0] fill_data [BLOCK-1:0];
    reg  [BLOCK-1        :0] fill_valid           ;
    wire [WEN_LEN-1      :0] fill_wen [1:0]       ;
    wire [LINESIZE-1     :0] fill_wdata           ;
    //FINISH AND RECOVER
    //wire        hit_fin;
    //wire [31:0] hit_fin_data;
    //lru
    reg [LINE-1:0] lru;
    reg [1     :0] way ;
    // 命中信号
    wire [1 :0] hit_way     ;
    wire        hit_run     ;
    wire        hit_loc     ;
    wire [31:0] hit_run_data;
    wire [31:0] run_data [BLOCK-1:0];
    // tagv块
    wire [1       :0] tag_wen        ;
    wire [1       :0] val_wen        ;
    wire [INDEX-1 :0] tagv_index     ;
    wire [19      :0] tag_wdata      ;
    wire              tagv_valid     ;
    wire [20      :0] tagv_back [1:0];
    // data块
    wire [WEN_LEN   :0] cache_wen   [1:0];
    wire [INDEX-1   :0] cache_rindex     ;
    wire [INDEX-1   :0] cache_windex     ;
    wire [LINESIZE-1:0] cache_wdata      ;
    wire [LINESIZE-1:0] cache_rdata [1:0];
    // dirty位
    reg  [1:0] dirty [LINE-1:0];
    wire       dirty_loc       ;
    // WRITEINTO CACHE
    wire [$clog2(WEN_LEN)-1:0] sl_wen         ;//移位用 $clog2(32 = 4*BLOCK)
    wire [WEN_LEN-1        :0] write_wstrb    ;
    wire [WEN_LEN-1        :0] write_wen [1:0];//写使能信号
    wire [LINESIZE-1       :0] write_line     ;
    wire [7                :0] raw_data [3:0] ;
    wire                       hit_write      ;
    // VICTIM BUFFER
    reg  [2              :0] vic_stat            ;
    reg  [31             :0] vic_addr            ;
    reg  [31             :0] vic_data [BLOCK-1:0];
    reg  [$clog2(BLOCK)-1:0] vic_counter         ;
    // dcacheop
`ifdef EN_DCACHE_OP
    reg  [4         :0] ca_op_reg   ;
    reg                 ca_way_reg  ;
    reg  [1         :0] ca_tag_wen  ;
    reg  [19        :0] ca_htag_reg ;   //HIT类型
    reg  [19        :0] ca_wtag_reg ;   //写入的数据
    reg  [INDEX-1   :0] ca_index_reg;
    reg  [1         :0] ca_val_wen  ;
    reg                 ca_val_reg  ;
    reg  [1         :0] ca_dirty_wen;
    reg                 ca_dirty_reg;
    reg                 ca_need_wb  ; //是否为需要写回内存的操作
    wire [1         :0] ca_hit      ;//是否命中
    wire                ca_hit_loc  ;
    wire                ca_wb_end   ;
    reg  [31        :0] ca_wb_addr  ;
    reg  [LINESIZE-1:0] ca_wb_data  ;
    wire                ca_dirty_loc;
    wire                ca_deal     ;     //是否处理cacheop
`endif
    // 额外的转换信号
    reg ok_send_arv;//是否允许开始AXI读
    // 初始化使用的循环控制变量
    integer i;
    // 锁存一拍返回的数据
    wire [31:0] ret_data_0;
    reg  [31:0] ret_data_1;
    ////////////////////////////////////////////////////////
    // 与CPU交互
`ifdef EN_DCACHE_OP
    assign dcache_ok     = (cache_stat == `CA_OP && !ca_need_wb) || (ca_wb_end);
    assign ca_deal       = (cache_stat == `RUN)  && !sda_req && !sta_req && dcache_req;
    assign data_index_ok = (cache_stat == `RUN)  && !ca_deal && sin_req && (!sda_req || data_data_ok);
`else
    assign data_index_ok = (cache_stat == `RUN) && sin_req && (!sda_req || data_data_ok);
`endif
    assign data_data_ok = sda_req && (hit_run || data_uncache_data_ok || sda_hasException);
    assign data_rdata   = ret_data_1;
    assign ret_data_0   = sda_unCache ? data_uncache_rdata :
                           sda_raw_col ? {raw_data[3],raw_data[2],raw_data[1],raw_data[0]} : hit_run_data;
    assign raw_data[0] = sda_raw_wstrb[0] ? sda_raw_data[0] : hit_run_data[7 : 0];
    assign raw_data[1] = sda_raw_wstrb[1] ? sda_raw_data[1] : hit_run_data[15: 8];
    assign raw_data[2] = sda_raw_wstrb[2] ? sda_raw_data[2] : hit_run_data[23:16];
    assign raw_data[3] = sda_raw_wstrb[3] ? sda_raw_data[3] : hit_run_data[31:24];
    
    //驱动data_uncache
    assign data_uncache_req   = !sda_hasException && sda_unCache && sda_req && !sda_uca_addr_ok;
    assign data_uncache_size  = sda_size;
    assign data_uncache_addr  = {sda_tag,sda_index,sda_offset};
    assign data_uncache_wr    = sda_wr;
    assign data_uncache_wstrb = sda_wstrb;
    assign data_uncache_wdata = sda_wdata;
    
    // AXI 读
    assign arid    = `DCACHE_ARID;
    assign araddr  = {sda_tag , sda_index , sda_offset} & 32'hfffffffc;
    assign arvalid = ok_send_arv;
    assign arlock  = 2'd0;
    assign arcache = 4'd0;
    assign arprot  = 3'd0;
    assign arlen   = BLOCK-1;
    assign arsize  = 3'd2;
    assign arburst = 2'b10;//warp Mode
    assign rready  = (cache_stat == `REFILL);

    //AXI 写
    assign awid    = `DCACHE_AWID;
    assign awlen   = BLOCK-1;
    assign awburst = 2'b01;
    assign awsize  = 3'd2;
    assign awlock  = 2'b0;
    assign awcache = 4'b0;
    assign awprot  = 3'b0;
    assign awaddr  = vic_addr;
    assign awvalid = vic_stat == `VIC_AWRITE;

    assign wid    = `DCACHE_AWID;
    assign wdata  = vic_data[vic_counter];
    assign wvalid = vic_stat == `VIC_WRITE;
    assign wlast  = vic_counter == BLOCK-1;
    assign wstrb  = 4'b1111;

    assign bready = vic_stat == `VIC_RES;
    ////////////////////////////////////////////////////////

    //sin段信号处理
    assign sin_req    = data_req             ;
    assign sin_wr     = data_wr              ;
    assign sin_size   = data_size            ;
    assign sin_index  = data_index[11-:INDEX];
    assign sin_offset = data_index[0+:OFFSET];
    assign sin_wstrb  = data_wstrb           ;
    assign sin_wdata  = data_wdata           ;

    //sta段保存从sin段流入的信号
    assign sta_tag          = data_tag         ;
    assign sta_hasException = data_hasException;
    assign sta_unCache      = data_unCache     ;
    always @(posedge clk ) begin
        if (!rst) begin
            sta_req    <= 0;
            sta_wr     <= 0;
            sta_size   <= 0;
            sta_index  <= 0;
            sta_offset <= 0;
            sta_wstrb  <= 0;
            sta_wdata  <= 0;
        end
        //接收信号
        else if (data_index_ok) begin
            sta_req    <= sin_req   ;
            sta_wr     <= sin_wr    ;
            sta_size   <= sin_size  ;
            sta_index  <= sin_index ;
            sta_offset <= sin_offset;
            sta_wstrb  <= sin_wstrb ;
            sta_wdata  <= sin_wdata ;
        end
        else if (data_data_ok | !sda_req) begin
            sta_req    <= 0;
            sta_wr     <= 0;
            sta_size   <= 0;
            sta_index  <= 0;
            sta_offset <= 0;
            sta_wstrb  <= 0;
            sta_wdata  <= 0;
        end else begin
        end
    end

    //sda段暂存从sta段流入的信号
    always @(posedge clk ) begin
        if (!rst) begin
            sda_req          <= 0;
            sda_wr           <= 0;
            sda_size         <= 0;
            sda_index        <= 0;
            sda_offset       <= 0;
            sda_tag          <= 0;
            sda_hasException <= 0;
            sda_unCache      <= 0;
            sta_wstrb        <= 0;
            sda_wdata        <= 0;
            for (i = 0; i < 2; i = i+1) begin 
                sda_tagv_back[i] <= 0;
                sda_rdata[i]     <= 0;
            end
        end
        //接收信号
        else if (data_data_ok | !sda_req) begin
            sda_req          <= sta_req         ;
            sda_wr           <= sta_wr          ;
            sda_size         <= sta_size        ;
            sda_index        <= sta_index       ;
            sda_offset       <= sta_offset      ;
            sda_tag          <= sta_tag         ;
            sda_hasException <= sta_hasException;
            sda_wstrb        <= sta_wstrb       ;
            sda_unCache      <= sta_unCache     ;
            sda_wdata        <= sta_wdata       ;
            for (i = 0; i < 2; i = i+1) begin 
                sda_tagv_back[i] <= tagv_back[i]  ;
                sda_rdata[i]     <= cache_rdata[i];
            end
            sda_uca_addr_ok  <= !sta_unCache && sta_hasException   ;
            sda_raw_col      <= (sta_index == sda_index) &&
                                (sta_offset[(OFFSET-1):2] == sda_offset[(OFFSET-1):2]) &&
                                (sta_tag == sta_tag) && sda_wr;
            sda_raw_wstrb    <= sda_wstrb;
            sda_raw_data[0]  <= {8{sda_wstrb[0]}} & sda_wdata[7 : 0];
            sda_raw_data[1]  <= {8{sda_wstrb[1]}} & sda_wdata[15: 8];
            sda_raw_data[2]  <= {8{sda_wstrb[2]}} & sda_wdata[23:16];
            sda_raw_data[3]  <= {8{sda_wstrb[3]}} & sda_wdata[31:24];
        end
        else if (cache_stat == `IDLE) begin
            for (i = 0; i < 2; i = i+1) begin 
                sda_tagv_back[i] <= tagv_back[i]  ;
                sda_rdata[i]     <= cache_rdata[i];
            end
        end
        else if (data_uncache_addr_ok) begin
            sda_uca_addr_ok  <= 1'b1;
        end else begin
        end
    end

    //cache状态转移自动机
    always @(posedge clk) begin
        if (!rst) begin
            cache_stat <= `RESET;
        end
        else begin
            (* full_case, parallel_case *)
            case (cache_stat)
                `IDLE    : cache_stat <= `RUN;
`ifdef EN_DCACHE_OP
                `RUN     : cache_stat <= (ca_deal) ? `CA_SEL:
                                         (sda_req && !sda_unCache && !hit_run && !sda_hasException) ? `MISS : `RUN;
                `CA_SEL  : cache_stat <= `CA_OP;
                `CA_OP   : cache_stat <= (ca_need_wb && vic_stat == `VIC_IDLE) ? `CA_WB : `RUN;
                `CA_WB   : cache_stat <= ca_wb_end ? `RUN : `CA_WB;
`else
                `RUN     : cache_stat <= (sda_req && !sda_unCache && !hit_run && !sda_hasException) ? `MISS : `RUN;
`endif
                `MISS    : cache_stat <= arready && arvalid ? `REFILL : `MISS;
                `REFILL  : cache_stat <= (rlast && rvalid && (rid == `DCACHE_RID)) ? `FINISH : `REFILL;
                `FINISH  : cache_stat <= `RECOVER;
                `RECOVER : cache_stat <= `IDLE;
                `RESET   : cache_stat <= (&reset_counter) ? `IDLE : `RESET; 
            endcase
        end
    end

    //RESET
    always @(posedge clk) begin
        if (!rst) begin
            reset_counter <= 0;//初始化为0，重置信号拉高后开始计数
        end
        else begin
            reset_counter <= reset_counter + 1'b1;
        end
    end

    //REFILL相关
    //一般持续8个周期
    always @(posedge clk) begin
        if (!rst) begin
            fill_counter <= 0 ;
        end
        else if (cache_stat == `MISS) begin
            fill_counter <= sda_offset[(OFFSET-1):2];
        end
        else if (rvalid && (rid == `DCACHE_RID)) begin
            fill_counter <= fill_counter + 1'b1;
        end
    end
    always @(posedge clk ) begin
        if (!rst) begin
            for (i = 0; i < BLOCK; i = i+1) begin 
                fill_data[i]  <= 0;
                fill_valid[i] <= 0;
            end
        end
        else if (rvalid && (rid == `DCACHE_RID)) begin
            fill_data[fill_counter]  <= rdata;
            fill_valid[fill_counter] <= 1'b1;
        end
        else if (cache_stat == `FINISH) begin
            fill_valid <= 0;
        end
    end
    assign fill_wen[0] = {WEN_LEN{way[0] & (cache_stat==`FINISH)}};
    assign fill_wen[1] = {WEN_LEN{way[1] & (cache_stat==`FINISH)}};
    generate
        genvar j;
        for(j=0;j<BLOCK;j=j+1) begin
            assign fill_wdata[(j*32)+:32] = fill_data[j];
        end
    endgenerate
    //HIT
    assign hit_way[0] = sda_tagv_back[0][0] & sda_tagv_back[0][20:1] == sda_tag;
    assign hit_way[1] = sda_tagv_back[1][0] & sda_tagv_back[1][20:1] == sda_tag;
    assign hit_run = |hit_way & cache_stat==`RUN & !sda_unCache;
    assign hit_loc = `encoder2_1(hit_way);
    generate
        for(j=0;j<BLOCK;j=j+1) begin
            assign run_data[j] = sda_rdata[hit_loc][(j*32)+:32];
        end
    endgenerate
    assign hit_run_data = run_data[sda_offset[(OFFSET-1):2]];
`ifdef EN_DCACHE_OP
    assign tag_wen    = (cache_stat == `RESET ) ? 2'b11                  :
                        (cache_stat == `FINISH) ? way                    :
                        (cache_stat == `CA_OP ) ? ca_tag_wen             :
                        2'b00;
    assign val_wen    = (cache_stat == `RESET ) ? 2'b11                  :
                        (cache_stat == `FINISH) ? way                    :
                        (cache_stat == `CA_OP ) ? ca_val_wen             :
                        2'b00;
    assign tagv_index = (ca_deal              ) ? dcache_addr[11-:INDEX] :
                        (cache_stat == `RESET ) ? reset_counter          :
                        (cache_stat == `IDLE  ) ? sta_index              :
                        (cache_stat == `CA_OP ) ? ca_index_reg           :
                        (cache_stat == `RUN   ) ? sin_index              :
                        sda_index;
    assign tag_wdata  = (cache_stat == `RESET ) ? 20'b0                  :
                        (cache_stat == `CA_OP ) ? ca_wtag_reg            :
                        sda_tag;
    assign tagv_valid = (cache_stat == `RESET ) ? 1'b0                   :
                        (cache_stat == `FINISH) ? 1'b1                   :
                        (cache_stat == `CA_OP ) ? ca_val_reg             :
                        1'b0;
`else
    assign tag_wen    = (cache_stat == `RESET )  ? 2'b11 :
                        (cache_stat == `FINISH) ? way :
                        2'b00;
    assign val_wen    = (cache_stat == `RESET )  ? 2'b11 :
                        (cache_stat == `FINISH) ? way :
                        2'b00;
    assign tagv_index = (cache_stat == `RESET ) ? reset_counter :
                        (cache_stat == `IDLE  ) ? sta_index     :
                        (cache_stat == `RUN   ) ? sin_index     :
                        sda_index;
    assign tag_wdata  = sda_tag;
    assign tagv_valid = !(&cache_stat);
`endif

    generate
        genvar k;
        for (k=0;k<2;k=k+1) begin
            data_tagv_tp#(
                .LINE(LINE)
            )
            Data_TagV_TP (
                .clk    (clk         ),
                .en     (1'b1        ),
                .tagwen (tag_wen[k]  ),
                .valwen (val_wen[k]  ),
                .index  (tagv_index  ),
                .wtag   (tag_wdata   ),
                .wvalid (tagv_valid  ),
                .back   (tagv_back[k])
            );
        end
    endgenerate
    // end
    
    // data
    assign cache_wen[0] = fill_wen[0] | write_wen[0];
    assign cache_wen[1] = fill_wen[1] | write_wen[1];
    assign cache_wdata  = (hit_write) ? write_line : fill_wdata;
    assign cache_windex = sda_index;
`ifdef EN_DCACHE_OP
    assign cache_rindex =   (ca_deal           ) ? dcache_addr[11-:INDEX] :
                            (cache_stat ==`IDLE) ? sta_index              :
                            (cache_stat ==`RUN ) ? sin_index              :
                            sda_index;
`else
    assign cache_rindex =   (cache_stat ==`IDLE) ? sta_index :
                            (cache_stat ==`RUN ) ? sin_index :
                            sda_index;
`endif
    
    generate
        for (k=0 ; k < 2 ; k = k + 1) begin
            data_data_tp#(
                .LINE(LINE),
                .BLOCK(BLOCK)
            )
            Data_Data_TP (
                .clk    ( clk      ),
                .en     ( 1'b1     ),
                .wen    ( cache_wen[k]  ),
                .rindex ( cache_rindex  ),
                .windex ( cache_windex  ),
                .wdata  ( cache_wdata   ),
                .rdata  ( cache_rdata[k])
            );
        end
    endgenerate
    //end

    //PLRU选路以及更新
    always @(posedge clk ) begin
        if (!rst) begin
            way <= 2'b0;
        end
        else if (cache_stat == `RUN && sda_req && !hit_run) begin
            case (lru[sda_index])
                1'b0: way <= 2'b01;
                1'b1: way <= 2'b10;
            endcase
        end else begin
        end
    end
    always @(posedge clk) begin
        if (!rst) begin
            for (i = 0; i < LINE; i = i+1) begin 
                lru[i] <= 0;
            end
        end
        else if (cache_stat == `MISS) begin
            case (way)
                2'b01: lru[sda_index] <= 1'b1;
                2'b10: lru[sda_index] <= 1'b0;
            endcase
        end else begin
        end
    end

    //dirty位处理
    assign dirty_loc = `encoder2_1(way);
`ifdef EN_DCACHE_OP
    assign ca_dirty_loc = `encoder2_1(ca_dirty_wen);
`endif
    always @(posedge clk ) begin
        if (!rst) begin
            for (i = 0; i < LINE; i = i+1) begin 
                dirty[i] <= 0;
            end
        end
        // 如果命中且为写操作，则直接修改对应行的dirty为1
        else if (hit_write) begin
            dirty[sda_index][hit_way] <= 1'b1;
        end
`ifdef EN_DCACHE_OP
        else if (cache_stat == `CA_OP && |ca_dirty_wen) begin
            dirty[ca_index_reg][ca_dirty_loc] <= ca_dirty_reg;
        end
`endif
    end

    assign hit_write    = sda_req && hit_run && sda_wr;
    assign sl_wen       = sda_offset[(OFFSET-1):2] << 2;
    assign write_wstrb  = {{(WEN_LEN-4){1'b0}},sda_wstrb} << sl_wen;
    assign write_wen[0] = {WEN_LEN{hit_way[0] && hit_write}} & write_wstrb;
    assign write_wen[1] = {WEN_LEN{hit_way[1] && hit_write}} & write_wstrb;
    assign write_line   = {BLOCK{sda_wdata}};

    //VICTIM BUFFER
    always @(posedge clk ) begin
        if (!rst) begin
            vic_stat <= `VIC_IDLE;
        end
        else begin
            case(vic_stat)
`ifdef EN_DCACHE_OP
                `VIC_IDLE  : vic_stat   <=  (sda_req && !hit_run)
                                            || (ca_need_wb && cache_stat == `CA_OP) ? `VIC_MISS : `VIC_IDLE;
                `VIC_MISS  : vic_stat   <=  (sda_tagv_back[dirty_loc][0] && dirty[sda_index][dirty_loc])
                                            || (cache_stat == `CA_WB)               ? `VIC_AWRITE: `VIC_IDLE;
                `VIC_AWRITE: vic_stat   <= (awready)                                ? `VIC_WRITE : `VIC_AWRITE;
                `VIC_WRITE : vic_stat   <= (wlast)                                  ? `VIC_RES   : `VIC_WRITE;
                `VIC_RES   : vic_stat   <= (bvalid)                                 ? `VIC_IDLE  : `VIC_RES;
`else
                `VIC_IDLE  : vic_stat   <= (sda_req && !hit_run)          ? `VIC_MISS  : `VIC_IDLE;
                `VIC_MISS  : vic_stat   <= (sda_tagv_back[dirty_loc][0] && dirty[sda_index][dirty_loc]) ? `VIC_AWRITE: `VIC_IDLE;
                `VIC_AWRITE: vic_stat   <= (awready)                      ? `VIC_WRITE : `VIC_AWRITE;
                `VIC_WRITE : vic_stat   <= (wlast)                        ? `VIC_RES   : `VIC_WRITE;
                `VIC_RES   : vic_stat   <= (bvalid)                       ? `VIC_IDLE  : `VIC_RES;
`endif

            endcase
        end
    end
    always @(posedge clk ) begin
        if (!rst) begin
            vic_addr <= 0;
        end
`ifdef EN_DCACHE_OP
        //TODO
        else if (vic_stat == `VIC_MISS && cache_stat == `CA_WB) begin
            vic_addr <= ca_wb_addr;
        end
        else if (vic_stat == `VIC_MISS) begin
            vic_addr <= {sda_tagv_back[dirty_loc],sda_index,{OFFSET{1'b0}}};
        end
`else
        else if (vic_stat == `VIC_MISS) begin
            vic_addr <= {sda_tagv_back[dirty_loc],sda_index,{OFFSET{1'b0}}};
        end
`endif
    end

    always @(posedge clk ) begin
        if (!rst) begin
            for (i = 0; i < BLOCK; i = i+1) begin
                vic_data[i] <= 0;
            end
        end
`ifdef EN_DCACHE_OP
        else if (vic_stat == `VIC_MISS && cache_stat == `CA_WB ) begin
            for (i=0;i<BLOCK;i = i+1) begin
                vic_data[i] <= ca_wb_data[(i*32)+:32];
            end
        end
        else if (vic_stat == `VIC_MISS) begin
            for (i=0;i<BLOCK;i = i+1) begin
                vic_data[i] <= cache_rdata[dirty_loc][(i*32)+:32];
            end
        end
`else
        else if (vic_stat == `VIC_MISS) begin
            for (i=0;i<BLOCK;i = i+1) begin
                vic_data[i] <= cache_rdata[dirty_loc][(i*32)+:32];
            end
        end
`endif
    end

    //换出计数
    always @(posedge clk) begin
        if (!rst) begin
            vic_counter <= 0;
        end
        else if (vic_stat == `VIC_AWRITE) begin
            vic_counter <= 0;
        end
        else if (vic_stat == `VIC_WRITE && wready) begin
            vic_counter <= vic_counter + 1'b1;
        end
    end

    always @(posedge clk ) begin
        if (!rst) begin
            ok_send_arv <= 1'b0;
        end
        else if (arready) begin
            ok_send_arv <= 1'b0;
        end
        else if (sda_req && !sda_unCache && !hit_run && vic_stat==`VIC_IDLE && (cache_stat == `RUN || cache_stat == `MISS)) begin
            ok_send_arv <= 1'b1;
        end
    end

    always @(posedge clk ) begin
        if (!rst) begin
            ret_data_1 <= 32'b0;
        end
        else if (data_data_ok) begin
            ret_data_1 <= ret_data_0;
        end else begin
        end
    end
    //CACHEOP IMP
    // sin段检测到cacheop请求，先不拉起indexok，直到sda_req = 0
    // 请求完成后，接收cacheop，进入cache_sel状态，阻塞正常请求
    // 完成cacheop，接收sin段请求
`ifdef EN_DCACHE_OP
    assign ca_hit[0] = (cache_stat == `CA_SEL) && (tagv_back[0][0]) && (tagv_back[0][20:1] == ca_htag_reg);
    assign ca_hit[1] = (cache_stat == `CA_SEL) && (tagv_back[1][0]) && (tagv_back[1][20:1] == ca_htag_reg);
    assign ca_hit_loc = `encoder2_1(ca_hit);
    assign ca_wb_end = (cache_stat == `CA_WB) && bvalid;
    always @(posedge clk) begin
        if (!rst) begin
            ca_op_reg    <= 0;
            ca_wtag_reg  <= 0;
            ca_index_reg <= 0;
            ca_way_reg   <= 0;
            ca_val_reg   <= 0;
            ca_dirty_reg <= 0;
            ca_need_wb   <= 0;
        end
        else if (ca_deal) begin
            ca_op_reg    <= dcache_op;
            ca_htag_reg  <= dcache_addr[31:12];
            ca_wtag_reg  <= dcache_tag;
            ca_index_reg <= dcache_addr[11-:INDEX];
            ca_way_reg   <= dcache_addr[12];
            ca_val_reg   <= dcache_valid;
            ca_dirty_reg <= dcache_dirty;
            ca_need_wb   <= 1'b0;
        end
        else if (cache_stat == `CA_SEL) begin
            case(ca_op_reg)
                `DC_IWI: begin
                    ca_tag_wen   <= 2'b0              ;
                    ca_val_wen   <= 2'b1 << ca_way_reg;
                    ca_val_reg   <= 1'b0              ;
                    ca_need_wb   <= tagv_back[ca_way_reg][0] && dirty[ca_index_reg][ca_way_reg];
                    ca_wb_addr   <= {tagv_back[ca_way_reg][20:1],ca_index_reg,{OFFSET{1'b0}}};
                    ca_wb_data   <= cache_rdata[ca_way_reg];
                end
                `DC_IST:begin
                    ca_tag_wen   <= 2'b1 << ca_way_reg;
                    ca_val_wen   <= 2'b1 << ca_way_reg;
                    ca_dirty_wen <= 2'b1 << ca_way_reg;
                    ca_need_wb   <= 1'b0              ;
                end
                `DC_HI:begin
                    ca_tag_wen   <= 2'b0  ;
                    ca_val_wen   <= ca_hit;
                    ca_val_reg   <= 1'b0  ;
                    ca_dirty_wen <= ca_hit;
                    ca_dirty_reg <= 1'b0  ;
                    ca_need_wb   <= 1'b0  ;//不需要写回内存
                end
                `DC_HWI:begin
                    ca_tag_wen   <= 2'b0  ;//不写tag
                    ca_val_wen   <= ca_hit;//修改val为0
                    ca_val_reg   <= 1'b0  ;
                    ca_dirty_wen <= ca_hit;//修改dirty为0
                    ca_dirty_reg <= 1'b0  ;
                    ca_need_wb   <= |ca_hit && dirty[ca_index_reg][ca_hit_loc] ;//需要写回内存
                    ca_wb_addr   <= {tagv_back[ca_hit_loc][20:1],ca_index_reg,{OFFSET{1'b0}}};
                    ca_wb_data   <= cache_rdata[ca_hit_loc];
                end
            endcase
        end
    end
`endif
endmodule