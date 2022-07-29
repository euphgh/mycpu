`timescale 1ns / 1ps
`include "../Cacheconst.vh"
//`define EN_ICACHE_OP
module icache_4w16b64l(
    input           clk,
    input           rst,

`ifdef EN_ICACHE_OP
    input         icache_req  ,
    input  [4 :0] icache_op   ,
    input  [31:0] icache_addr ,
    input  [19:0] icache_tag  ,
    input         icache_valid,
    output        icache_ok   ,
`endif

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

    // inst_uncache
    output         inst_uncache_req    ,
    output [31 :0] inst_uncache_addr   ,
    input  [127:0] inst_uncache_rdata  ,
    input          inst_uncache_addr_ok,
    input          inst_uncache_data_ok
);
    ////////////////////////////////////////////////////////
    // Signal Define
    //三段流水
    //index -> tag -> data
    //sin_ ... sta_ ... sda_ ...
    //sin段
    wire       sin_req   ;
    wire [1:0] sin_size  ;
    wire [5:0] sin_index ;
    wire [1:0] sin_offset;
    //sta段
    reg         sta_req         ;
    reg  [1 :0] sta_size        ;
    reg  [5 :0] sta_index       ;
    reg  [1 :0] sta_offset      ;
    wire [19:0] sta_tag         ;
    wire        sta_hasException;
    wire        sta_unCache     ;
    //sda段
    reg         sda_req            ;
    reg [1  :0] sda_size           ;
    reg [5  :0] sda_index          ;
    reg [1  :0] sda_offset         ;
    reg [19 :0] sda_tag            ;
    reg         sda_hasException   ;
    reg         sda_unCache        ;
    reg [20 :0] sda_tagv_back [3:0];
    reg [511:0] sda_rdata     [3:0];
    reg         sda_uca_addr_ok    ;
    //主自动机状态
    reg [3:0] cache_stat;
    //RESET
    reg [5:0] reset_counter;
    //REFILL
    reg [3 :0] fill_counter       ;
    reg [31:0] fill_buf_data [15:0];
    reg [15:0] fill_buf_valid     ;
    reg [19:0] fill_tag           ;
    reg [5 :0] fill_index         ;
    //HIT FINISH AND REFILL
    wire         hit_fill     ;
    wire [127:0] hit_fill_data;
    //PLRU
    reg [2:0] plru [63:0];
    reg [3:0] way         ;
    // 初始化使用的循环控制变量
    integer i;
    // 命中信号
    wire [3  :0] hit_way     ;
    wire         hit_run     ;
    wire [1  :0] loc         ;
    wire [127:0] hit_run_data;
    // tagv块
    wire [3 :0] tag_wen        ;
    wire [3 :0] val_wen        ;
    wire [5 :0] tagv_index     ;
    wire [19:0] tagv_wdata     ;
    wire        tagv_valid     ;
    wire [20:0] tagv_back [3:0];
    // data块
    wire [63 :0] data_wen   [3:0];
    wire [5  :0] data_index      ;
    wire [511:0] data_wdata      ;
    wire [511:0] data_rdata [3:0];
    // icacheop
`ifdef EN_ICACHE_OP
    reg  [4 :0] ca_op_reg    ;//操作类型
    reg  [1 :0] ca_way_reg   ;//输入信号中包含的路信息
    reg  [3 :0] ca_tag_wen   ;//tag写使能
    reg  [19:0] ca_htag_reg  ;//HIT比对
    reg  [19:0] ca_wtag_reg  ;//写入的数据
    reg  [5 :0] ca_index_reg ;//行号
    reg  [3 :0] ca_val_wen   ;//valid写使能
    reg         ca_val_reg   ;//valid写数据
    wire [3 :0] ca_hit       ;//是否命中
    wire        deal_cache_op;
`endif
    ////////////////////////////////////////////////////////

    //TODO 与CPU信号交互
`ifdef EN_ICACHE_OP
    assign icache_ok     = cache_stat == `CA_OP;
    assign deal_cache_op = (cache_stat ==`RUN) && !sda_req && !sta_req && icache_req;
    assign inst_index_ok = !deal_cache_op && sin_req && (!sda_req || inst_data_ok)
                           && (cache_stat != `RESET && cache_stat != `IDLE && cache_stat != `CA_OP && cache_stat != `CA_SEL);                          
`else
    assign inst_index_ok = (cache_stat != `RESET) && sin_req && (!sda_req || inst_data_ok);
`endif 
    assign inst_data_ok  = sda_req && (hit_run || hit_fill || inst_uncache_data_ok || sda_hasException);
    assign inst_rdata    = sda_unCache ? inst_uncache_rdata :
                           hit_fill    ? hit_fill_data      : hit_run_data;
    //驱动inst_uncache
    assign inst_uncache_req  = !sda_hasException && sda_unCache && sda_req && !sda_uca_addr_ok;
    assign inst_uncache_addr = {sda_tag, sda_index, sda_offset, 4'b0000};
    //---------------AXI交互-----------------------
    assign arid    = `ICACHE_ARID;
    assign araddr  = {sda_tag, sda_index ,sda_offset ,4'b0000};
    assign arvalid = (cache_stat == `MISS);
    assign arlen   = 4'd15;
    assign arsize  = 3'd2 ;
    assign arburst = 2'b10;//Wrap Mode
    assign arlock  = 2'd0 ;
    assign arcache = 4'd0 ;
    assign arprot  = 3'd0 ;
    assign rready  = (cache_stat == `REFILL);
    //NO-USE
    assign awid    = 4'd0;
    assign awlen   = 8'd0;
    assign awburst = 2'b00;
    assign awsize  = 3'd2;
    assign awaddr  = 32'b0;
    assign awvalid = 4'b0;
    assign wdata   = 32'b0;
    assign wvalid  = 4'b0;
    assign wlast   = 3'b0;
    assign bready  = 4'b0;
    //---------------------------------------------
    
    //sin段
    assign sin_req    = inst_req        ;
    assign sin_wr     = inst_wr         ;
    assign sin_size   = inst_size       ;
    assign sin_index  = inst_index [7:2];
    assign sin_offset = inst_index [1:0];
    assign sin_wdata  = inst_wdata      ;
   

    //sta段
    assign sta_tag          = inst_tag         ;
    assign sta_hasException = inst_hasException;
    assign sta_unCache      = inst_unCache     ;
    always @(posedge clk ) begin
        if (!rst) begin
            sta_req    <= 1'b0;
            sta_size   <= 2'b0;
            sta_index  <= 6'b0;
            sta_offset <= 2'b0;
        end
        //接收cache请求信号
        else if (inst_index_ok) begin
            sta_req    <= sin_req   ;
            sta_size   <= sin_size  ;
            sta_index  <= sin_index ;
            sta_offset <= sin_offset;
        end else if (!sda_req) begin
            sta_req    <= 1'b0;
            sta_size   <= 2'b0;
            sta_index  <= 6'b0;
            sta_offset <= 2'b0;
        end else begin
        end
    end
    
    //sda段暂存从sta段流入的信号
    always @(posedge clk ) begin
        if (!rst) begin
            sda_req          <= 1'b0 ;
            sda_size         <= 2'b0 ;
            sda_index        <= 6'b0 ;
            sda_offset       <= 2'b0 ;
            sda_tag          <= 20'b0;
            sda_hasException <= 1'b0 ;
            sda_unCache      <= 1'b0 ;
            for (i = 0; i < 4; i = i+1) begin 
                sda_tagv_back[i] <= 21'b0 ;
                sda_rdata[i]     <= 255'b0;
            end
        end
        else if (inst_index_ok | !sda_req) begin
            sda_req          <= sta_req         ;
            sda_size         <= sta_size        ;
            sda_index        <= sta_index       ;
            sda_offset       <= sta_offset      ;
            sda_tag          <= sta_tag         ;
            sda_hasException <= sta_hasException;
            sda_unCache      <= sta_unCache     ;
            sda_tagv_back[0] <= tagv_back[0]    ;
            sda_tagv_back[1] <= tagv_back[1]    ;
            sda_tagv_back[2] <= tagv_back[2]    ;
            sda_tagv_back[3] <= tagv_back[3]    ;
            sda_rdata[0]     <= data_rdata[0]   ;
            sda_rdata[1]     <= data_rdata[1]   ;
            sda_rdata[2]     <= data_rdata[2]   ;
            sda_rdata[3]     <= data_rdata[3]   ;
            sda_uca_addr_ok  <= !sta_unCache  && sta_hasException  ; // 如果存在异常，不请求uncache
        end
        else if (cache_stat == `IDLE) begin
            sda_tagv_back[0] <= tagv_back[0] ;
            sda_tagv_back[1] <= tagv_back[1] ;
            sda_tagv_back[2] <= tagv_back[2] ;
            sda_tagv_back[3] <= tagv_back[3] ;
            sda_rdata[0]     <= data_rdata[0];
            sda_rdata[1]     <= data_rdata[1];
            sda_rdata[2]     <= data_rdata[2];
            sda_rdata[3]     <= data_rdata[3];
        end
        else if (inst_data_ok) begin
            sda_req          <= 1'b0;
        end
        else if (inst_uncache_addr_ok) begin
            sda_uca_addr_ok  <= 1'b1;
        end else begin
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
`ifdef EN_ICACHE_OP
                //TODO
                `RUN:       cache_stat <= (deal_cache_op) ? `CA_SEL:
                                          (sda_req && !sda_unCache &&!hit_run && !sda_hasException) ? `MISS : `RUN;
                `CA_SEL:    cache_stat <= `CA_OP;
                `CA_OP:     cache_stat <= `RUN; //IC操作统一，控制信号简单
`else
                `RUN:       cache_stat <=  (sda_req && !sda_unCache && !hit_run && !sda_hasException) ? `MISS : `RUN;
`endif
                //如果axi从设备表示已经准备好向cache发送数据，进入REFILL状态
                `MISS:      cache_stat <= arready ? (`REFILL) : (`MISS);
                //根据rid，是否读写完成（rlast和rvaild）判断是否装载完成
                `REFILL:    cache_stat <= (rlast && rvalid && (rid == `ICACHE_RID)) ? (`FINISH) : (`REFILL);
                //装载完毕
                `FINISH:    cache_stat <= `RECOVER;
                //TODO 可能需要一个恢复状态，来获取到之前MISS的行对应的数据
                //`FINISH        -> `RECOVER            -> `IDLE            -> `RUN
                //返回装入的数据    读取下一个请求的数据   保存到sda段寄存器   对比TAG
                `RECOVER:   cache_stat <= `IDLE;
                //初始装载
                `RESET:     cache_stat <= (reset_counter == 63) ? `IDLE : `RESET; 
                default:    cache_stat <= `IDLE;
            endcase
        end
    end

    //RESET 相关
    //持续128个周期，每个周期将一行tag置为无效
    always @(posedge clk) begin
        if (!rst) begin 
            reset_counter <= 6'b0;//初始化为0，重置信号拉高后开始计数
        end 
        else begin
            reset_counter <= reset_counter + 6'b1;
        end 
    end

    //REFILL相关
    //一般持续8个周期
    always @(posedge clk) begin
        if (!rst) begin
            fill_counter <= 3'b0 ;
            fill_index   <= 6'b0;
            fill_tag     <= 20'b0  ;
        end
        else if (cache_stat == `MISS) begin
            fill_counter <= {sda_offset,2'b00};
            fill_index   <= sda_index;
            fill_tag     <= sda_tag  ;
        end
        // 地址握手完成，开始传输，计数器开始自�?
        // 请求字优先， 总线交互时设置ARBUSRT�?2b'10
        else if (rvalid && (rid == `ICACHE_RID)) begin
            fill_counter <= fill_counter + 4'b1;
        end else begin
        end
    end
    always @(posedge clk ) begin
        if (!rst) begin
            for (i = 0; i < 16; i = i+1) begin 
                fill_buf_data[i]  <= 32'b0;
                fill_buf_valid[i] <= 1'b0;
            end
        end
        else if (rvalid && (rid == `ICACHE_RID)) begin
            fill_buf_data[fill_counter]  <= rdata;
            fill_buf_valid[fill_counter] <= 1'b1;
        end
        else if (cache_stat == `FINISH) begin
            fill_buf_valid <= 16'b0;
        end else begin
        end
    end
    //REFILL下命中
    assign hit_fill      = fill_index == sda_index && fill_tag == sda_tag 
                            && (   (&fill_buf_valid[3 : 0] && sda_offset==2'b00)
                                || (&fill_buf_valid[7 : 4] && sda_offset==2'b01)
                                || (&fill_buf_valid[11: 8] && sda_offset==2'b10)
                                || (&fill_buf_valid[15:12] && sda_offset==2'b11)
                            );  
    assign hit_fill_data = {128{sda_offset==2'b00}} & {fill_buf_data[3 ],fill_buf_data[2 ],fill_buf_data[1 ],fill_buf_data[0 ]}
                         | {128{sda_offset==2'b01}} & {fill_buf_data[7 ],fill_buf_data[6 ],fill_buf_data[5 ],fill_buf_data[4 ]}
                         | {128{sda_offset==2'b10}} & {fill_buf_data[11],fill_buf_data[10],fill_buf_data[9 ],fill_buf_data[8 ]}
                         | {128{sda_offset==2'b11}} & {fill_buf_data[15],fill_buf_data[14],fill_buf_data[13],fill_buf_data[12]};
    //HIT
    assign hit_way[0] = sda_tagv_back[0][0] && sda_tagv_back[0][20:1] == sda_tag;
    assign hit_way[1] = sda_tagv_back[1][0] && sda_tagv_back[1][20:1] == sda_tag;
    assign hit_way[2] = sda_tagv_back[2][0] && sda_tagv_back[2][20:1] == sda_tag;
    assign hit_way[3] = sda_tagv_back[3][0] && sda_tagv_back[3][20:1] == sda_tag;
    assign hit_run = |hit_way && cache_stat==`RUN && !sda_unCache;
    assign loc = `encoder4_2(hit_way);
    assign hit_run_data = {128{sda_offset==2'b00}} & {sda_rdata[loc][127:  0]}
                        | {128{sda_offset==2'b01}} & {sda_rdata[loc][255:128]}
                        | {128{sda_offset==2'b10}} & {sda_rdata[loc][383:256]}
                        | {128{sda_offset==2'b11}} & {sda_rdata[loc][511:384]};
    //tagv
`ifdef EN_ICACHE_OP
    assign tag_wen =    (cache_stat == `RESET  ) ? 4'b1111    :
                        (cache_stat == `FINISH ) ? way        :
                        (cache_stat == `CA_OP  ) ? ca_tag_wen :
                        4'b0000;
    assign val_wen =    (cache_stat == `RESET  ) ? 4'b1111    :
                        (cache_stat == `FINISH ) ? way        :
                        (cache_stat == `CA_OP  ) ? ca_val_wen :
                        4'b0000;
    assign tagv_index = (cache_stat == `RESET  ) ? reset_counter     :
                        (cache_stat == `FINISH ) ? fill_index        :
                        (cache_stat == `RECOVER) ? sda_index         :
                        (deal_cache_op         ) ? icache_addr[11:6] :
                        (cache_stat == `CA_OP  ) ? ca_index_reg      :
                        (cache_stat ==`RUN     ) ? sin_index : sta_index;
    assign tagv_wdata = (cache_stat == `RESET  ) ? 20'b0      :
                        (cache_stat == `FINISH ) ? fill_tag : 
                        (cache_stat == `CA_OP  ) ? ca_wtag_reg : 20'b0;
    assign tagv_valid = (cache_stat == `RESET  ) ? 1'b0    :
                        (cache_stat == `FINISH ) ? 1'b1    : 
                        (cache_stat == `CA_OP  ) ? ca_val_reg : 1'b0;
`else 
    assign tag_wen =    (cache_stat == `RESET  ) ? 4'b1111 :
                        (cache_stat == `FINISH ) ? way     : 4'b0000;
    assign val_wen =    (cache_stat == `RESET  ) ? 4'b1111 :
                        (cache_stat == `FINISH ) ? way     : 4'b0000;
    assign tagv_index = (cache_stat == `RESET  ) ? reset_counter :
                        (cache_stat == `FINISH ) ? fill_index    : 
                        (cache_stat == `RUN    ) ? sin_index     :
                        (cache_stat == `IDLE   ) ? sta_index     : sda_index;
    assign tagv_wdata = fill_tag;
    assign tagv_valid = !(cache_stat == `RESET);
`endif
    generate
        genvar k;
        for (k=0;k<4;k=k+1) begin
            inst_tagv_tp#(
                .LINE(64)
            )
            Inst_TagV_TP (
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
    assign data_wen[0] = {64{way[0] && (cache_stat == `FINISH)}};
    assign data_wen[1] = {64{way[1] && (cache_stat == `FINISH)}};
    assign data_wen[2] = {64{way[2] && (cache_stat == `FINISH)}};
    assign data_wen[3] = {64{way[3] && (cache_stat == `FINISH)}};
    assign data_index  = (cache_stat == `FINISH ) ? fill_index :
                         (cache_stat==`RUN ) ? sin_index :
                         (cache_stat==`IDLE) ? sta_index : sda_index;
    assign data_wdata  = {fill_buf_data[15],fill_buf_data[14],fill_buf_data[13],fill_buf_data[12],
                          fill_buf_data[11],fill_buf_data[10],fill_buf_data[9 ],fill_buf_data[8 ],
                          fill_buf_data[7 ],fill_buf_data[6 ],fill_buf_data[5 ],fill_buf_data[4 ],
                          fill_buf_data[3 ],fill_buf_data[2 ],fill_buf_data[1 ],fill_buf_data[0 ]};
    generate
        for (k=0 ; k < 4 ; k = k + 1) begin
            inst_data_tp#(
                .LINE(64),
                .BLOCK(16)
            )
            Inst_Data_TP (
                .clk    (clk          ),
                .en     (1'b1         ),
                .wen    (data_wen[k]  ),
                .index  (data_index   ),
                .wdata  (data_wdata   ),
                .rdata  (data_rdata[k])
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
        end else begin
        end
    end
    always @(posedge clk) begin
        if (!rst) begin
            for (i = 0; i < 64; i = i+1) begin 
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
        end else begin
        end
    end


    //CACHEOP IMP
    // sin段检测到cacheop请求，先不拉起indexok，直到sda_req = 0
    // 请求完成后，接收cacheop，进入cache_sel状态，阻塞正常请求
    // 完成cacheop，接收sin段请求
`ifdef EN_ICACHE_OP
    assign ca_hit[0] = {cache_stat == `CA_SEL} && tagv_back[0][0] && (tagv_back[0][20:1] == ca_htag_reg);
    assign ca_hit[1] = (cache_stat == `CA_SEL) && tagv_back[1][0] && (tagv_back[1][20:1] == ca_htag_reg);
    assign ca_hit[2] = (cache_stat == `CA_SEL) && tagv_back[2][0] && (tagv_back[2][20:1] == ca_htag_reg);
    assign ca_hit[3] = (cache_stat == `CA_SEL) && tagv_back[3][0] && (tagv_back[3][20:1] == ca_htag_reg);
    always @(posedge clk) begin
        if (!rst) begin
            ca_op_reg    <= 5'b0;
            ca_tag_wen   <= 4'b0;
            ca_htag_reg  <= 20'b0;
            ca_wtag_reg  <= 20'b0;
            ca_index_reg <= 6'b0;
            ca_way_reg   <= 2'b0;
            ca_val_reg   <= 1'b0;
            ca_val_wen   <= 4'b0;
        end
        else if (deal_cache_op) begin
            ca_op_reg    <= icache_op;
            ca_htag_reg  <= icache_addr[31:12];
            ca_wtag_reg  <= icache_tag;
            ca_index_reg <= icache_addr[11: 6];
            ca_way_reg   <= icache_addr[13:12];
            ca_val_reg   <= icache_valid;
        end
        else if (cache_stat == `CA_SEL) begin
            case(ca_op_reg)
                `IC_II: begin
                    ca_tag_wen <= 4'b0              ;//不修改tag
                    ca_val_wen <= 4'b1 << ca_way_reg;//选中对应的路
                    ca_val_reg <= 1'b0              ;//tag无效化
                end
                `IC_IST:begin
                    ca_tag_wen <= 4'b1 << ca_way_reg;//选中对应的路
                    ca_val_wen <= 4'b1 << ca_way_reg;//选中对应的路
                end
                `IC_HI:begin
                    ca_tag_wen <= 4'b0  ;//不修改tag
                    ca_val_wen <= ca_hit;//选择命中的路
                    ca_val_reg <= 1'b0  ;//无效化命中的路
                end
            endcase
        end else begin
        end
    end
`endif
endmodule