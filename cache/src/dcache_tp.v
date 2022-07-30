`timescale 1ns / 1ps
`include "../Cacheconst.vh"
//`define EN_DCACHE_OP
module dcache_tp(
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
    // Signal Define
    //三段流水
    //index -> tag -> data
    //sin_ ... sta_ ... sda_ ...
    //sin段
    wire        sin_req   ;
    wire        sin_wr    ;
    wire [1 :0] sin_size  ;
    wire [6 :0] sin_index ;
    wire [4 :0] sin_offset;
    wire [3 :0] sin_wstrb ;
    wire [31:0] sin_wdata ;
    //sta段
    reg         sta_req         ;
    reg         sta_wr          ;
    reg  [1 :0] sta_size        ;
    reg  [6 :0] sta_index       ;
    reg  [4 :0] sta_offset      ;
    wire [19:0] sta_tag         ;
    wire        sta_hasException;
    wire        sta_unCache     ;
    reg  [3 :0] sta_wstrb       ;
    reg  [31:0] sta_wdata       ;
    //sda段
    reg          sda_req            ;
    reg          sda_wr             ;
    reg [1  :0]  sda_size           ;
    reg [6  :0]  sda_index          ;
    reg [4  :0]  sda_offset         ;
    reg [19 :0]  sda_tag            ;
    reg          sda_hasException   ;
    reg          sda_unCache        ;
    reg [3  :0]  sda_wstrb          ;
    reg [31 :0]  sda_wdata          ;
    reg [20 :0]  sda_tagv_back [3:0];
    reg [255:0]  sda_rdata     [3:0];
    reg          sda_uca_addr_ok    ;
    reg          sda_wb_addr_ok     ;
    reg          sda_raw_col        ;
    reg [3 :0]   sda_raw_wstrb      ;
    reg [7 :0]   sda_raw_data [3:0] ;
    //主自动机状态
    reg [3:0] cache_stat;
    //RESET
    reg [6:0] reset_counter;
    //REFILL
    reg  [2  :0] refill_counter       ;
    reg  [31 :0] refill_buf_data [7:0];
    reg  [7  :0] refill_buf_valid     ;
    wire [31 :0] refill_wen [3:0]     ;
    wire [255:0] refill_wdata         ;
    //FINISH AND RECOVER
    wire hit_fin;
    wire [31:0] hit_fin_data;
    //PLRU
    reg [2:0] plru [127:0];
    reg [3:0] way         ;  
    // 初始化使用的循环控制变量
    integer i;
    // 命中信号
    wire [3 :0] hit_way     ;
    wire        hit_run     ;
    wire [1 :0] hit_loc     ;
    wire [31:0] hit_run_data;
    // tagv块
    wire [3 :0] tag_wen        ;
    wire [3 :0] val_wen        ;
    wire [6 :0] tagv_index     ;
    wire [19:0] tagv_wdata     ;
    wire        tagv_valid     ;
    wire [20:0] tagv_back [3:0];
    // data块
    wire [31 :0] cache_wen   [3:0];
    wire [6  :0] cache_rindex     ;
    wire [6  :0] cache_windex     ;
    wire [255:0] cache_wdata      ;
    wire [255:0] cache_rdata [3:0];
    // dirty位
    reg  [3:0] dirty [127:0];
    wire [2:0] dirty_loc    ;
    // WRITEBUFFER
    wire         hit_write        ;
    wire [4  :0] sl_wen           ;//移位用
    wire [31 :0] write_wstrb      ;
    wire [31 :0] write_wen [3:0]  ;//写使能信号
    wire [255:0] write_buffer_line;
    wire [7:0] raw_data [3:0];
    // VICTIM BUFFER
    reg  [3 :0] victim_stat;
    reg  [31:0] victim_addr;
    reg  [31:0] victim_buffer_data [7:0];
    reg  [2 :0] victim_counter;
    // dcacheop
`ifdef EN_DCACHE_OP
    reg  [4 :0] ca_op_reg;
    reg  [1 :0] ca_way_reg;
    reg  [3 :0] ca_tag_wen;
    reg  [19:0] ca_htag_reg;   //HIT类型
    reg  [19:0] ca_wtag_reg;   //写入的数据
    reg  [6 :0] ca_index_reg;
    reg  [3 :0] ca_val_wen;
    reg         ca_val_reg;
    reg  [3 :0] ca_dirty_wen;
    reg         ca_dirty_reg;
    reg         ca_need_wb; //是否为需要写回内存的操作
    wire [3 :0] ca_hit      ;//是否命中
    wire [1 :0] ca_hit_loc  ;
    wire        ca_wb_end   ;
    wire        deal_cache_op;
    reg  [31:0] ca_wb_addr;
    reg  [255:0] ca_wb_data;
    wire [1:0] ca_dirty_loc;
`endif    
    // 额外的转换信号
    reg ok_send_arv;//是否允许开始AXI读
    ////////////////////////////////////////////////////////

    //TODO ADD
    wire [31:0] sda_data_rdata;
    reg [31:0] real_rdata ;
    always @(posedge clk ) begin
        if (!rst) begin
            real_rdata <= 32'b0;
        end
        else if (data_data_ok) begin
            real_rdata <= sda_data_rdata;
        end else begin
        end 
    end
    ////////////////////////////////////////////////////////
    //TODO 与CPU交互
`ifdef EN_DCACHE_OP
    assign dcache_ok     = (cache_stat == `CA_OP && !ca_need_wb) || (ca_wb_end);
    assign deal_cache_op = (cache_stat ==`RUN) && !sda_req && !sta_req && dcache_req;
    assign data_index_ok =  !deal_cache_op &&
                            (cache_stat != `RESET && cache_stat != `IDLE && cache_stat != `CA_OP && cache_stat != `CA_SEL && cache_stat != `CA_WB) 
                            && sin_req & (!sda_req | data_data_ok);
`else
    assign data_index_ok = (cache_stat != `RESET) && sin_req & (!sda_req | data_data_ok);    
`endif
    assign data_data_ok  = sda_req & (hit_run | data_uncache_data_ok | sda_hasException);
    assign data_rdata    = real_rdata;
    assign sda_data_rdata    =  sda_unCache ? data_uncache_rdata : 
                                sda_raw_col ? {raw_data[3],raw_data[2],raw_data[1],raw_data[0]} : hit_run_data;
    assign raw_data[0] = sda_raw_wstrb[0] ? sda_raw_data[0] : hit_run_data[7 : 0];
    assign raw_data[1] = sda_raw_wstrb[1] ? sda_raw_data[1] : hit_run_data[15: 8];
    assign raw_data[2] = sda_raw_wstrb[2] ? sda_raw_data[2] : hit_run_data[23:16];
    assign raw_data[3] = sda_raw_wstrb[3] ? sda_raw_data[3] : hit_run_data[31:24];
    
    //驱动data_uncache
    assign data_uncache_req   = !sda_hasException & sda_unCache & sda_req & !sda_uca_addr_ok;
    assign data_uncache_size  = sda_size;
    assign data_uncache_addr  = {sda_tag,sda_index,sda_offset};
    assign data_uncache_wr    = sda_wr;
    assign data_uncache_wstrb = sda_wstrb;
    assign data_uncache_wdata = sda_wdata;
    
    // AXI 读
    assign arid    = `DCACHE_ARID;
    assign araddr  = {sda_tag , sda_index , sda_offset[4:2] , 2'b00 };
    assign arvalid = ok_send_arv;   
    assign arlock  = 2'd0;
    assign arcache = 4'd0;
    assign arprot  = 3'd0;
    assign arlen   = 8'd7;
    assign arsize  = 3'd2;
    assign arburst = 2'b10;//Wrap Mode
    assign rready  = (cache_stat == `REFILL);

    //AXI 写
    assign awid     = `DCACHE_AWID;
    assign awlen    = 4'd7;
    assign awburst  = 2'b01;
    assign awsize   = 3'd2;
    assign awlock   = 2'b0;
    assign awcache  = 4'b0;
    assign awprot   = 3'b0;
    assign awaddr   = victim_addr;
    assign awvalid  = victim_stat == `VIC_AWRITE;

    assign wdata    = victim_buffer_data[victim_counter];
    assign wvalid   = victim_stat == `VIC_WRITE;
    assign wid      = `DCACHE_AWID;
    assign wlast    = victim_counter == 3'd7;
    assign wstrb    = 4'b1111;

    assign bready   = victim_stat == `VIC_RES;
    ////////////////////////////////////////////////////////

    //sin段信号处理
    assign sin_req          = data_req         ;
    assign sin_wr           = data_wr          ;
    assign sin_size         = data_size        ;
    assign sin_index        = data_index[11:5] ;
    assign sin_offset       = data_index[4 :0] ;
    assign sin_wstrb        = data_wstrb       ;
    assign sin_wdata        = data_wdata       ;

    //sta段保存从sin段流入的信号
    assign sta_tag          = data_tag         ;
    assign sta_hasException = data_hasException;
    assign sta_unCache      = data_unCache     ;
    always @(posedge clk ) begin
        if (!rst) begin
            sta_req          <= 1'b0 ;
            sta_wr           <= 1'b0 ;
            sta_size         <= 2'b0 ;
            sta_index        <= 7'b0 ;
            sta_offset       <= 1'b0 ;
            sta_wstrb        <= 4'b0 ;
            sta_wdata        <= 32'b0;
        end
        //接收信号
        else if (data_index_ok) begin
            sta_req          <= sin_req         ;
            sta_wr           <= sin_wr          ;
            sta_size         <= sin_size        ;
            sta_index        <= sin_index       ;
            sta_offset       <= sin_offset      ;
            sta_wstrb        <= sin_wstrb       ;
            sta_wdata        <= sin_wdata       ;
        end
        else if (!sda_req) begin
            sta_req          <= 1'b0 ;
            sta_wr           <= 1'b0 ;
            sta_size         <= 2'b0 ;
            sta_index        <= 7'b0 ;
            sta_offset       <= 1'b0 ;
            sta_wstrb        <= 4'b0 ;
            sta_wdata        <= 32'b0;
        end
    end

    //sda段暂存从sta段流入的信号
    always @(posedge clk ) begin
        if (!rst) begin
            sda_req          <= 1'b0 ;
            sda_wr           <= 1'b0 ;
            sda_size         <= 2'b0 ;
            sda_index        <= 7'b0 ;
            sda_offset       <= 1'b0 ;
            sda_tag          <= 20'b0;
            sda_hasException <= 1'b0 ;
            sda_unCache      <= 1'b0 ;
            sta_wstrb        <= 4'b0 ;
            sda_wdata        <= 32'b0;
            for (i = 0; i < 4; i = i+1) begin 
                sda_tagv_back[i] <= 21'b0 ;
                sda_rdata[i]     <= 255'b0;
            end
        end
        //接收信号
        else if (data_index_ok | !sda_req) begin
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
            sda_tagv_back[0] <= tagv_back[0]    ;
            sda_tagv_back[1] <= tagv_back[1]    ;
            sda_tagv_back[2] <= tagv_back[2]    ;
            sda_tagv_back[3] <= tagv_back[3]    ;
            sda_rdata[0]     <= cache_rdata[0]  ;
            sda_rdata[1]     <= cache_rdata[1]  ;
            sda_rdata[2]     <= cache_rdata[2]  ;
            sda_rdata[3]     <= cache_rdata[3]  ;
            sda_uca_addr_ok  <= !sta_unCache && sta_hasException   ;
            sda_wb_addr_ok   <= !sta_wr         ;
            sda_raw_col      <= (sta_index == sda_index) && 
                                (sta_offset[4:2] == sda_offset[4:2]) &&
                                (sta_tag == sta_tag) && sda_wr;
            sda_raw_wstrb    <= sda_wstrb;
            sda_raw_data[0]  <= {8{sda_wstrb[0]}} & sda_wdata[7 : 0];
            sda_raw_data[1]  <= {8{sda_wstrb[1]}} & sda_wdata[15: 8];
            sda_raw_data[2]  <= {8{sda_wstrb[2]}} & sda_wdata[23:16];
            sda_raw_data[3]  <= {8{sda_wstrb[3]}} & sda_wdata[31:24];
        end
        else if (cache_stat == `IDLE) begin
            sda_tagv_back[0] <= tagv_back[0]  ;
            sda_tagv_back[1] <= tagv_back[1]  ;
            sda_tagv_back[2] <= tagv_back[2]  ;
            sda_tagv_back[3] <= tagv_back[3]  ;
            sda_rdata[0]     <= cache_rdata[0];
            sda_rdata[1]     <= cache_rdata[1];
            sda_rdata[2]     <= cache_rdata[2];
            sda_rdata[3]     <= cache_rdata[3];
        end
        //TODO 当数据传输完毕，需要拉低sda_req
        else if (data_data_ok) begin
            sda_req          <= 1'b0;
        end
        else if (data_uncache_addr_ok) begin
            sda_uca_addr_ok  <= 1'b1;
        end
        else if (hit_write) begin
            sda_wb_addr_ok <= 1'b1;
        end
    end

    //cache状态转移自动机
    always @(posedge clk) begin
        //重置信号有效
        if (!rst) begin
            cache_stat <= `RESET;
        end
        //其他情况
        else begin
            case (cache_stat)
                //用于调整时序
                `IDLE:      cache_stat <= `RUN;
                //如果发生了不命中，进入MISS状态
`ifdef EN_DCACHE_OP
                `RUN:       cache_stat <= (deal_cache_op) ? `CA_SEL:
                                          (sda_req && !sda_unCache &&!hit_run && !sda_hasException) ? `MISS : `RUN;
                `CA_SEL:    cache_stat <= `CA_OP;
                `CA_OP :    cache_stat <= ca_need_wb && victim_stat == `VIC_IDLE ? `CA_WB  : `RUN;
                `CA_WB :    cache_stat <= ca_wb_end  ? `RUN    : `CA_WB;
`else
                `RUN:       cache_stat <=  (sda_req && !sda_unCache &&!hit_run && !sda_hasException) ? `MISS : `RUN;
`endif
                //如果axi从设备表示已经准备好向cache发送数据，进入REFILL状态
                `MISS:      cache_stat <= arready && arvalid ? (`REFILL) : (`MISS);
                //根据rid，是否读写完成（rlast和rvaild）判断是否装载完成
                `REFILL:    cache_stat <= (rlast && rvalid && (rid == `DCACHE_RID)) ? (`FINISH) : (`REFILL);
                //装载完毕
                `FINISH:    cache_stat <= `RECOVER;
                //TODO 可能需要一个恢复状态，来获取到之前MISS的行对应的数据
                //`FINISH        -> `RECOVER            -> `IDLE            -> `RUN
                //返回装入的数据    读取下一个请求的数据   保存到sda段寄存器   对比TAG
                `RECOVER:   cache_stat <= `IDLE;
                //初始装载
                `RESET:     cache_stat <= (reset_counter == 127) ? `IDLE : `RESET; 
                default:    cache_stat <= `IDLE;
            endcase
        end
    end

    //RESET 相关
    //持续128个周期，每个周期将一行tag置为无效
    always @(posedge clk) begin
        if (!rst) begin 
            reset_counter <=7'b0;//初始化为0，重置信号拉高后开始计数
        end 
        else begin
            reset_counter <= reset_counter + 7'b1;
        end
    end

    //REFILL相关
    //一般持续8个周期
    always @(posedge clk) begin
        if (!rst) begin
            refill_counter <= 3'b0 ;
        end
        else if (cache_stat == `MISS) begin
            refill_counter <= sda_offset[4:2]   ;
        end
        // 地址握手完成，开始传输，计数器开始自�?
        // 请求字优先， 总线交互时设置ARBUSRT�?2b'10
        else if (rvalid && (rid == `DCACHE_RID)) begin
            refill_counter <= refill_counter + 3'b1;
        end
    end
    always @(posedge clk ) begin
        if (!rst) begin
            for (i = 0; i < 8; i = i+1) begin 
                refill_buf_data[i] <= 32'b0;
                refill_buf_valid[i] <= 1'b0;
            end
        end
        else if (rvalid && (rid == `DCACHE_RID)) begin
            refill_buf_data[refill_counter] <= rdata;
            refill_buf_valid[refill_counter] <= 1'b1;
        end
        else if (cache_stat == `FINISH) begin
            refill_buf_valid <= 8'b0;
        end
    end
    assign refill_wen[0] = {32{way[0] & (cache_stat==`FINISH)}};
    assign refill_wen[1] = {32{way[1] & (cache_stat==`FINISH)}};
    assign refill_wen[2] = {32{way[2] & (cache_stat==`FINISH)}};
    assign refill_wen[3] = {32{way[3] & (cache_stat==`FINISH)}}; 
    assign refill_wdata  = { refill_buf_data[7],refill_buf_data[6],refill_buf_data[5],refill_buf_data[4],
                             refill_buf_data[3],refill_buf_data[2],refill_buf_data[1],refill_buf_data[0] };
  
    //HIT
    assign hit_way[0] = sda_tagv_back[0][0] & sda_tagv_back[0][20:1] == sda_tag;
    assign hit_way[1] = sda_tagv_back[1][0] & sda_tagv_back[1][20:1] == sda_tag;
    assign hit_way[2] = sda_tagv_back[2][0] & sda_tagv_back[2][20:1] == sda_tag;
    assign hit_way[3] = sda_tagv_back[3][0] & sda_tagv_back[3][20:1] == sda_tag;
    assign hit_run = |hit_way & cache_stat==`RUN & !sda_unCache;
    assign hit_loc = `encoder4_2(hit_way);
    assign hit_run_data =  {32{sda_offset[4:2] ==3'b000}} & {sda_rdata[hit_loc][31 : 0 ]}
                        |  {32{sda_offset[4:2] ==3'b001}} & {sda_rdata[hit_loc][63 :32 ]}
                        |  {32{sda_offset[4:2] ==3'b010}} & {sda_rdata[hit_loc][95 :64 ]}
                        |  {32{sda_offset[4:2] ==3'b011}} & {sda_rdata[hit_loc][127:96 ]}
                        |  {32{sda_offset[4:2] ==3'b100}} & {sda_rdata[hit_loc][159:128]}
                        |  {32{sda_offset[4:2] ==3'b101}} & {sda_rdata[hit_loc][191:160]}
                        |  {32{sda_offset[4:2] ==3'b110}} & {sda_rdata[hit_loc][223:192]}
                        |  {32{sda_offset[4:2] ==3'b111}} & {sda_rdata[hit_loc][255:224]};
`ifdef EN_DCACHE_OP
    assign tag_wen =   (cache_stat == `RESET)  ? 4'b1111    :
                        (cache_stat == `FINISH) ? way        :
                        (cache_stat == `CA_OP)  ? ca_tag_wen :
                        4'b0000;
    assign val_wen =    (cache_stat == `RESET)  ? 4'b1111    :
                        (cache_stat == `FINISH) ? way        :
                        (cache_stat == `CA_OP)  ? ca_val_wen :
                        4'b0000;
    assign tagv_index = (cache_stat == `RESET)  ? reset_counter :
                        (cache_stat == `FINISH) ? sda_index  :
                        (cache_stat == `RECOVER)? sda_index     :
                        (deal_cache_op        ) ? dcache_addr[11:5] :
                        (cache_stat == `CA_OP)  ? ca_index_reg  :
                        (data_index_ok && cache_stat==`RUN) ? sin_index : sta_index;
    assign tagv_wdata = (cache_stat == `RESET)  ? 4'b1111    :
                        (cache_stat == `FINISH) ? sda_tag : 
                        (cache_stat == `CA_OP)  ? ca_wtag_reg : 20'b0;
    assign tagv_valid = (cache_stat == `RESET)  ? 1'b0    :
                        (cache_stat == `FINISH) ? 1'b1    : 
                        (cache_stat == `CA_OP)  ? ca_val_reg : 1'b0;
`else 
    assign tag_wen =    (cache_stat == `RESET)  ? 4'b1111 :
                        (cache_stat == `FINISH) ? way : 4'b0000;
    assign val_wen =    (cache_stat == `RESET)  ? 4'b1111 :
                        (cache_stat == `FINISH) ? way : 4'b0000;
    assign tagv_index = (cache_stat == `RESET) ? reset_counter :
                        (cache_stat == `FINISH) ? sda_index :
                        (cache_stat == `RECOVER)? sda_index :
                        (data_index_ok && cache_stat==`RUN) ? sin_index : sta_index;
    assign tagv_wdata = {20{cache_stat == `FINISH}} & sda_tag;
    assign tagv_valid = (cache_stat == `RESET) ? 1'b0 : 1'b1;
`endif

    generate
        genvar k;
        for (k=0;k<4;k=k+1) begin
            data_tagv_tp Data_TagV_TP (
                .clk    (clk         ),
                .en     (1'b1        ),
                .tagwen (tag_wen[k]  ),
                .valwen (val_wen[k]  ),
                .index  (tagv_index  ),
                .wtag   (tagv_wdata  ),
                .wvalid (tagv_valid  ),
                .back   (tagv_back[k])
            );
        end
    endgenerate  
    // end
    
    // data
    assign cache_wen[0] = refill_wen[0] | write_wen[0];
    assign cache_wen[1] = refill_wen[1] | write_wen[1];
    assign cache_wen[2] = refill_wen[2] | write_wen[2];
    assign cache_wen[3] = refill_wen[3] | write_wen[3];
    assign cache_wdata  = (cache_stat ==`FINISH) ? refill_wdata : write_buffer_line  ;
    assign cache_windex = sda_index;
`ifdef EN_DCACHE_OP
    assign cache_rindex = (deal_cache_op     ) ? dcache_addr[11:5] :
                          (cache_stat ==`IDLE) ? sta_index         : 
                          (cache_stat==`RUN  ) ? sin_index         : sda_index;
`else
    assign cache_rindex = (cache_stat ==`IDLE) ? sta_index :
                          (cache_stat ==`RUN ) ? sin_index : sda_index;
`endif
    
    generate
        for (k=0 ; k < 4 ; k = k + 1) begin
            data_data_tp  Data_Data_TP (
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
            way <= 4'b0;
        end
        else if (cache_stat == `RUN && sda_req && !hit_run) begin
            case (plru[sda_index])
                //选择第0路
                3'b000: way <= 4'b0001;
                3'b100: way <= 4'b0001;
                //选择第1路
                3'b010: way <= 4'b0010;
                3'b110: way <= 4'b0010;
                //选择第2路
                3'b001: way <= 4'b0100;
                3'b011: way <= 4'b0100;
                //选择第3路
                3'b101: way <= 4'b1000;
                3'b111: way <= 4'b1000;
            endcase
        end
    end
    always @(posedge clk) begin
        if (!rst) begin
            for (i = 0; i < 128; i = i+1) begin 
                plru[i] <= 3'b0;
            end
        end
        else if (cache_stat == `MISS) begin
            case (way)
                //选中0路，则plru为x00,调整为x11
                4'b0001: plru[sda_index] <= {plru[sda_index][2],1'b1,1'b1};
                //选中1路，则plru为x10,调整为x01
                4'b0010: plru[sda_index] <= {plru[sda_index][2],1'b0,1'b1};
                //选中2路，则plru为0x1,调整为1x0
                4'b0100: plru[sda_index] <= {1'b1,plru[sda_index][1],1'b0};
                //选中3路，则plru为1x1,调整为0x0
                4'b1000: plru[sda_index] <= {1'b0,plru[sda_index][1],1'b0};
            endcase
        end
    end

    //dirty位处理
    assign dirty_loc = `encoder4_2(way);
`ifdef EN_DCACHE_OP
    assign ca_dirty_loc = `encoder4_2(ca_dirty_wen);
`endif
    always @(posedge clk ) begin
        if (!rst) begin
            for (i = 0; i < 128; i = i+1) begin 
                dirty[i] <= 4'b0;
            end
        end
        // 如果命中且为写操作，则直接修改对应行的dirty为1
        else if (hit_write) begin
            dirty[sta_index][hit_way] <= 1'b1;
        end
`ifdef EN_DCACHE_OP
        else if (cache_stat == `CA_OP && |ca_dirty_wen) begin
            dirty[ca_index_reg][ca_dirty_loc] <= ca_dirty_reg;
        end
`endif 
        // // 如果MISS，则选择被牺牲行所在的way和index，修改dirty，此路在之后重新填回后根据last_op进行读或写
        // else if (cache_stat == `FINISH) begin
        //     dirty[sda_index][dirty_loc] <= sda_wr;
        // end
    end

    assign hit_write = sda_req && hit_run && sda_wr;

    assign sl_wen      = sda_offset[4:2] << 2;
    assign write_wstrb = {28'b0,sda_wstrb} << sl_wen;
    assign write_wen[0] = {32{hit_way[0] && hit_write}} & write_wstrb;
    assign write_wen[1] = {32{hit_way[1] && hit_write}} & write_wstrb;
    assign write_wen[2] = {32{hit_way[2] && hit_write}} & write_wstrb;
    assign write_wen[3] = {32{hit_way[3] && hit_write}} & write_wstrb;
    assign write_buffer_line = { 8{sda_wdata}};

    //VICTIM BUFFER
    always @(posedge clk ) begin
        if (!rst) begin
            victim_stat <= `VIC_IDLE;
        end
        else begin
            case(victim_stat)
`ifdef EN_DCACHE_OP
                `VIC_IDLE  : victim_stat   <= (sda_req && !hit_run) || (ca_need_wb && cache_stat == `CA_OP)         ? `VIC_MISS  : `VIC_IDLE;
                `VIC_MISS  : victim_stat   <= (dirty[sda_index][dirty_loc]) || (cache_stat == `CA_WB)   ? `VIC_AWRITE: `VIC_IDLE;
                `VIC_AWRITE: victim_stat   <= (awready)                      ? `VIC_WRITE : `VIC_AWRITE;
                `VIC_WRITE : victim_stat   <= (wlast)                        ? `VIC_RES   : `VIC_WRITE;
                `VIC_RES   : victim_stat   <= (bvalid)                       ? `VIC_IDLE  : `VIC_RES;
`else
                `VIC_IDLE  : victim_stat   <= (sda_req && !hit_run)          ? `VIC_MISS  : `VIC_IDLE;
                `VIC_MISS  : victim_stat   <= (dirty[sda_index][dirty_loc])  ? `VIC_AWRITE: `VIC_IDLE;
                `VIC_AWRITE: victim_stat   <= (awready)                      ? `VIC_WRITE : `VIC_AWRITE;
                `VIC_WRITE : victim_stat   <= (wlast)                        ? `VIC_RES   : `VIC_WRITE;
                `VIC_RES   : victim_stat   <= (bvalid)                       ? `VIC_IDLE  : `VIC_RES;
`endif
                
            endcase
        end
    end
    always @(posedge clk ) begin
        if (!rst) begin
            victim_addr <= 32'b0;
        end 
`ifdef EN_DCACHE_OP
        //TODO
        else if (victim_stat == `VIC_MISS && cache_stat == `CA_WB) begin
            victim_addr <= ca_wb_addr; 
        end
        else if (victim_stat == `VIC_MISS) begin
            victim_addr <= {sda_tagv_back[dirty_loc],sda_index,5'b00000}; 
        end
`else
        else if (victim_stat == `VIC_MISS) begin
            victim_addr <= {sda_tagv_back[dirty_loc],sda_index,5'b00000}; 
        end
`endif
    end

    always @(posedge clk ) begin
        if (!rst) begin
            for (i = 0; i < 8; i = i+1) begin 
                victim_buffer_data[i] <= 32'b0;
            end
        end
`ifdef EN_DCACHE_OP
        else if (victim_stat == `VIC_MISS && cache_stat == `CA_WB ) begin
            {victim_buffer_data[0],victim_buffer_data[1],victim_buffer_data[2],victim_buffer_data[3],victim_buffer_data[4],victim_buffer_data[5],victim_buffer_data[6],victim_buffer_data[7]} <= ca_wb_data;
        end
        else if (victim_stat == `VIC_MISS) begin
            {victim_buffer_data[0],victim_buffer_data[1],victim_buffer_data[2],victim_buffer_data[3],victim_buffer_data[4],victim_buffer_data[5],victim_buffer_data[6],victim_buffer_data[7]} <= cache_rdata[dirty_loc];
        end
`else
        else if (victim_stat == `VIC_MISS) begin
            {victim_buffer_data[0],victim_buffer_data[1],victim_buffer_data[2],victim_buffer_data[3],victim_buffer_data[4],victim_buffer_data[5],victim_buffer_data[6],victim_buffer_data[7]} <= cache_rdata[dirty_loc];
        end
`endif
    end
    
    //换出计数
    always @(posedge clk) begin
        if (!rst) begin
            victim_counter <= 3'd0;
        end
        else if (victim_stat == `VIC_AWRITE) begin
            victim_counter <= 3'd0;
        end
        else if (victim_stat == `VIC_WRITE && wready) begin
            victim_counter <= victim_counter + 3'd1;
        end
    end

    
    always @(posedge clk ) begin
        if (!rst) begin
            ok_send_arv <= 1'b0;
        end
        else if (arready) begin
            ok_send_arv <= 1'b0;
        end 
        else if (sda_req && !sda_unCache && !hit_run && victim_stat==`VIC_IDLE && (cache_stat == `RUN || cache_stat == `MISS)) begin
            ok_send_arv <= 1'b1;
        end
    end
    
    //CACHEOP IMP
    // sin段检测到cacheop请求，先不拉起indexok，直到sda_req = 0
    // 请求完成后，接收cacheop，进入cache_sel状态，阻塞正常请求
    // 完成cacheop，接收sin段请求
`ifdef EN_DCACHE_OP
    assign ca_hit[0] = (cache_stat == `CA_SEL) && (tagv_back[0][0]) && (tagv_back[0][20:1] == ca_htag_reg);
    assign ca_hit[1] = (cache_stat == `CA_SEL) && (tagv_back[1][0]) && (tagv_back[1][20:1] == ca_htag_reg);
    assign ca_hit[2] = (cache_stat == `CA_SEL) && (tagv_back[2][0]) && (tagv_back[2][20:1] == ca_htag_reg);
    assign ca_hit[3] = (cache_stat == `CA_SEL) && (tagv_back[3][0]) && (tagv_back[3][20:1] == ca_htag_reg);
    assign ca_hit_loc = `encoder4_2(ca_hit);
    assign ca_wb_end = (cache_stat == `CA_WB) && bvalid;
    always @(posedge clk) begin
        if (!rst) begin
            ca_op_reg    <= 5'b0;
            ca_wtag_reg  <= 20'b0;
            ca_index_reg <= 7'b0;
            ca_way_reg   <= 2'b0;
            ca_val_reg <= 1'b0;
            ca_dirty_reg <= 1'b0;
            ca_need_wb   <= 1'b0;
        end
        else if (deal_cache_op) begin
            ca_op_reg    <= dcache_op;
            ca_htag_reg  <= dcache_addr[31:12];
            ca_wtag_reg  <= dcache_tag;
            ca_index_reg <= dcache_addr[11: 5];
            ca_way_reg   <= dcache_addr[13:12];
            ca_val_reg <= dcache_valid;
            ca_dirty_reg <= dcache_dirty;
            ca_need_wb   <= 1'b0;
        end
        else if (cache_stat == `CA_SEL) begin
            case(ca_op_reg)
                `DC_IWI: begin
                    ca_tag_wen   <= 4'b0              ;
                    ca_val_wen   <= 4'b1 << ca_way_reg;
                    ca_val_reg   <= 1'b0              ;
                    ca_need_wb   <= tagv_back[ca_way_reg][0] && dirty[ca_index_reg][ca_way_reg];
                    ca_wb_addr   <= {tagv_back[ca_way_reg][20:1],ca_index_reg,5'b00000};
                    ca_wb_data   <= cache_rdata[ca_way_reg];
                end
                `DC_IST:begin
                    ca_tag_wen   <= 4'b1 << ca_way_reg;
                    ca_val_wen   <= 4'b1 << ca_way_reg;
                    ca_dirty_wen <= 4'b1 << ca_way_reg;
                    ca_need_wb   <= 1'b0              ;
                end
                `DC_HI:begin
                    ca_tag_wen   <= 4'b0  ;
                    ca_val_wen   <= ca_hit;
                    ca_val_reg   <= 1'b0  ;
                    ca_dirty_wen <= ca_hit;
                    ca_dirty_reg <= 1'b0  ;
                    ca_need_wb   <= 1'b0  ;//不需要写回内存
                end
                `DC_HWI:begin
                    ca_tag_wen   <= 4'b0  ;//不写tag
                    ca_val_wen   <= ca_hit;//修改val为0   
                    ca_val_reg   <= 1'b0  ;
                    ca_dirty_wen <= ca_hit;//修改dirty为0
                    ca_dirty_reg <= 1'b0  ;
                    ca_need_wb   <= |ca_hit && dirty[ca_index_reg][ca_hit_loc] ;//需要写回内存
                    ca_wb_addr   <= {tagv_back[ca_hit_loc][20:1],ca_index_reg,5'b00000};
                    ca_wb_data   <= cache_rdata[ca_hit_loc];
                end
            endcase
        end
    end
`endif
endmodule
