//globaol{{{
`define ZEROWORD 32'h00000000
`define STARTPOINT 32'hbfc00000
`define SINGLE_WORD_LEN 32
`define SINGLE_WORD `SINGLE_WORD_LEN-1:0
`define FOUR_WORDS 127:0
`define TRUE 1'b1
`define FALSE 1'b0
`define SRAM_WRITE 1'b1
`define SRAM_READ 1'b0 
/*}}}*/
// exception define{{{
`define EXCCODE `EXCCODE_LEN-1:0
`define EXCCODE_LEN 5
`define NOEXCCODE 5'h0
`define INT     5'h0
`define MOD     5'h1
`define TLBL    5'h2
`define TLBS    5'h3
`define ADEL    5'h4
`define ADES    5'h5
`define SYS     5'h8
`define BP      5'h9
`define RI      5'ha
`define CPU     5'hb
`define OV      5'hc 
`define TR      5'hd
/*}}}*/
//cache{{{
`define CACHE_TAG   31:12
`define CACHE_TAG_ZERO   20'b0
`define CACHE_INDEX 11:4
`define CACHE_INDEX_ZERO 8'b0
`define INST_NUM_LEN 4
`define INST_NUM    `INST_NUM_LEN-1:0
/*}}}*/
// 预解码结果 如果不是分支指令，该编码结果为0{{{
`define B_SELECT `B_SEL_LEN-1:0
`define B_SEL_LEN   5
`define PHT_TAKE    0
`define MUST_TAKE   1
`define BTB_DEST    2
`define IJTC_DEST   3
`define RAS_DEST    4
/*}}}*/
//分支预测检查点长度定义{{{
`define ALL_CHECKPOINT  `ALL_CHECKPOINT_LEN-1:0
`define NO_CHECKPOINT   `ALL_CHECKPOINT_LEN'b0
`define IJTC_CHECKPOINT `IJTC_CHECKPOINT_LEN-1:0         // 记录全局分支历史
`define PHT_CHECKPOINT  `PHT_CHECKPOINT_LEN-1:0         // 记录局部分支历史,两位饱和计数器
`define RAS_CHECKPOINT  `RAS_CHECKPOINT_LEN-1:0         // 栈指针，栈元素
`define ALL_CHECKPOINT_LEN (`RAS_CHECKPOINT_LEN+`PHT_CHECKPOINT_LEN+`IJTC_CHECKPOINT_LEN)
`define PHT_CHECKPOINT_LEN 10
`define RAS_CHECKPOINT_LEN 36
`define IJTC_CHECKPOINT_LEN 8                           // 记录全局分支历史
/*}}}*/
// 分支恢复的所有动作和使能{{{
`define REPAIR_ACTION `REPAIR_ACTION_LEN-1:0
`define NO_REPAIRE_ACTION   `REPAIR_ACTION_LEN'b0
`define REPAIR_ACTION_LEN   8
`define NEED_REPAIR         7

`define PHT_ACTION          6:5
`define PHT_REPAIRE         2'b10
`define PHT_DIRECT          2'b01
`define PHT_NOACTION        2'b00

`define RAS_ACTION          4:3
`define RAS_PUSH            2'b01
`define RAS_POP             2'b10
`define RAS_REPAIRE         2'b11
`define RAS_NOACTION        2'b00

`define IJTC_ACTION         2:1
`define IJTC_REPAIRE        2'b10
`define IJTC_DIRECT         2'b01
`define IJTC_NOACTION       2'b00

`define BTB_ACTION          0
`define BTB_REPAIRE         1'b1
`define BTB_NOACTION        1'b0 /*}}}*/
//InstQueue
`define IQ_LENTH        `IQ_ENTRY_LEN-1:0
`define IQ_ENTRY_LEN    158
`define IQ_VALID        1:0
`define IQ_VALID_SINGLE 2'b01
`define IQ_VALID_DUAL   2'b11
`define IQ_VALID_NON    2'b00
`define IQ_CAPABILITY   16
`define IQ_GAP          5'd8
`define IQ_NUMBER_BIT   4'd
`define IQ_NUMBER_WID   3:0

`define IQ_CAP_WIDTH    $clog2(`IQ_CAPABILITY)
`define IQ_POINT        `IQ_CAP_WIDTH:0
`define IQ_NUMBER       `IQ_CAP_WIDTH-1:0
`define IQ_POINT_SIGN   `IQ_CAP_WIDTH
// ID_demandNum_i表示需要的指令条数
`define NO_DEMAND       2'b00
`define ONE_DEMAND      2'b01
`define TWO_DEMAND      2'b11
// FirstDecorder
`define INST_TYPE       5:0 
`define INST_DETAIL     5:0
`define GPR_NUM         `GPR_NUM_LEN-1:0
`define GPR_NUM_LEN     5
// EXE段ALU的异常选择{{{
`define EXCEPRION_SEL_LEN 2
`define EXCEPRION_SEL `EXCEPRION_SEL_LEN-1:0
`define EXCEPRION_OV    1
`define EXCEPRION_TR    0
/*}}}*/
// 解码器生成的选择信号{{{
// 选择操作数
`define OPRAND_SEL `OPRAND_SEL_LEN-1:0
`define OPRAND_SEL_LEN  3
//  rs
`define SEL_DELAYSLOT_PC    2
`define SEL_SA_FIELD        1
`define SEL_RS_DATA         0
//  rt
`define SEL_INST_OFFSET     2
`define SEL_EXTENDED_IMM    1
`define SEL_RT_DATA         0
 // 选择输出的寄存器号 
`define WRITENUM_SEL `WRITENUM_SEL_LEN-1 : 0
`define WRITENUM_SEL_LEN 3
`define SEL_31GPR   2
`define SEL_RT_NUM  1
`define SEL_RD_NUM  0
/*}}}*/
//Arbitrator{{{
`define ISSUE_MODE              1:0
`define NO_ISSUE                2'b00
`define SINGLE_ISSUE            2'b01
`define DUAL_ISSUE              2'b11
`define AT_SLOT_ZERO            2'b01
`define AT_SLOT_ONE             2'b10
/*}}}*/
// 立即数扩展器{{{
`define EXTEND_ACTION       `EXTEND_ACTION_LEN-1:0
`define EXTEND_ACTION_LEN   3
`define ZERO_EXTEND_IMMED   0
`define SIGN_EXTEND_IMMED   1
`define ZERO_EXTEND_INDEX   2
/*}}}*/
//前递{{{
`define FORWARD_MODE        `FORWARD_MODE_LEN-1:0
`define FORWARD_MODE_LEN    7
`define FORWARD_EXE_DOWN_BIT    6       
`define FORWARD_EXE_UP_BIT      5
`define FORWARD_PREMEM_BIT      4
`define FORWARD_SBA_BIT         3 
`define FORWARD_MEM_BIT         2
`define FORWARD_REEXE_BIT       1
`define FORWARD_ID_BIT          0   // 寄存器中有数据，无需前递
// 以上都是前递的寄存器数值
`define FORWARD_MODE_EXE_DOWN   `FORWARD_MODE_LEN'b1000000
`define FORWARD_MODE_EXE_UP     `FORWARD_MODE_LEN'b0100000
`define FORWARD_MODE_PREMEM     `FORWARD_MODE_LEN'b0010000
`define FORWARD_MODE_SBA        `FORWARD_MODE_LEN'b0001000
`define FORWARD_MODE_MEM        `FORWARD_MODE_LEN'b0000100
`define FORWARD_MODE_REEXE      `FORWARD_MODE_LEN'b0000010
`define FORWARD_MODE_ID         `FORWARD_MODE_LEN'b0000001

//alu运算种类{{{
`define ALUOP_LEN   14
`define ALUOP `ALUOP_LEN-1:0  
`define ALU_MOVN    13
`define ALU_MOVZ    12
`define ALU_ADD     11
`define ALU_SUB     10
`define ALU_AND     9
`define ALU_OR      8
`define ALU_NOR     7
`define ALU_XOR     6
`define ALU_SLT     5
`define ALU_SLTU    4
`define ALU_SLL     3
`define ALU_SRL     2
`define ALU_SRA     1
`define ALU_LUI     0
/*}}}*/
`define MDUOP `MDUOP_LEN-1:0 
`define MDUOP_LEN 9
`define MDU_MULT        0   //包括累计和寄存器也需要
`define MDU_MULU        1
`define MDU_DIV         2
`define MDU_DIVU        3
`define MDU_ADD         4
`define MDU_SUB         5
`define MDU_MULR        6 // 直连乘法
`define MDU_CLO         7
`define MDU_CLZ         8

`define MDU_REQ `MDU_REQ_LEN-1:0
`define MDU_REQ_LEN 8
`define MUL_REQ     0   // mult,multu和累计指令都会有
`define MUL_SIGN    1
`define DIV_REQ     2
`define DIV_SIGN    3
`define MT_REQ      4   // 是否是数据移动模式
`define MT_DEST     5   // 1'b1 表示高位hi,否则为lo
`define ACCUM_REQ   6   // 是否是累计模式     
`define ACCUM_OP    7   // 表示+或-
// EXE乘除输出接口
`define MATH_SEL    `MATH_SEL_LEN-1:0
`define MATH_SEL_LEN 4
`define MATH_ALU     3
`define MATH_MDU     2
`define MATH_CL      1
`define MATH_MULR    0
// 自陷指令{{{
`define TRAP_KIND `TRAP_KIND_LEN-1:0
`define TRAP_KIND_LEN   4
`define TRAP_EQUAL      3
`define TRAP_NEQUAL     2
`define TRAP_LT_LTU     1
`define TRAP_GE_GEU     0
/*}}}*/
// 分支指令的种类{{{
`define BRANCH_KIND     `BRANCH_KIND_LEN-1:0
`define BRANCH_KIND_LEN 6
`define BRANCH_EQUAL    5
`define BRANCH_NEQ      4
`define BRANCH_GE       3
`define BRANCH_LT       2
`define BRANCH_LE       1
`define BRANCH_GT       0
/*}}}*/
// readHiLo和writeHILO
`define HILO        1:0
`define HI_WRITE    0
`define LO_WRITE    1
`define HI_READ     0
`define LO_READ     1
// cp0段
`define CP0_POSITION    7:0
    // CP0寄存器的定义{{{
    // Status{{{
    `define ADDR_STATUS {5'd12,3'd0}
    `define BEV 22
    `define IM0 8
    `define IM1 9
    `define IM2 10
    `define IM3 11
    `define IM4 12
    `define IM5 13
    `define IM6 14
    `define IM7 15
    `define EXL 1
    `define IE  0/*}}}*/
    // Cause{{{
    `define  ADDR_CAUSE {5'd13,3'd0}
    `define BD  31
    `define TI  30
    `define IP0 8
    `define IP1 9
    `define IP2 10
    `define IP3 11
    `define IP4 12
    `define IP5 13
    `define IP6 14
    `define IP7 15/*}}}*/
    // Compare{{{
    `define  ADDR_COMPARE {5'd11,3'd0}
    // }}}
    // Count{{{
    `define  ADDR_COUNT {5'd9,3'd0}
    // }}}
    // EPC{{{
    `define  ADDR_EPC {5'd14,3'd0}
    // }}}
    // BadVAdder{{{
    `define  ADDR_BADVADDR {5'd8,3'd0}
    // }}}
    // Index{{{
    `define     P               31
    `define     INDEX           `TLB_WIDTH
    `define     ADDR_INDEX      {5'd0,3'd0}
    // }}}
    // EntryLo0{{{
    `define     LO_FPN          25:6
    `define     LO_C            5:3
    `define     LO_D            2
    `define     LO_V            1
    `define     LO_G            0
    `define     ADDR_ENRTYLO0   {5'd2,3'd0}
    // }}}
    // EntryLo1{{{
    `define     ADDR_ENRTYLO1   {5'd3,3'd0}
    // }}}
    // EntryHi {{{
    `define     HI_VPN          31:13
    `define     HI_ASID         7:0   
    `define     ADDR_ENRTYHI    {5'd10,3'd0}
    // }}}
    // Config {{{
    `define K0 2:0
    `define ADDR_CONFIG {5'd16,3'b0}
    // }}}
    // Config1{{{
    `define MMU_SIZE 6'd32
    `define IS  3'd0
    `define IL  3'd4
    `define IA  3'd0
    `define DS  3'd0
    `define DL  3'd4
    `define DA  3'd4
    `define ADDR_CONFIG1 {5'd16,3'b1}
    // }}}
    // }}}
// 访存信号
`define REQ_LOAD        1'b0
`define REQ_STORE       1'b1
// TLB指令信号
`define TLB_INST        `TLB_INST_LEN-1:0
`define TLB_INST_LEN    4
`define TLB_INST_TBLP   0
`define TLB_INST_TBLRI  1
`define TLB_INST_TBLWI  2
`define TLB_INST_TBLWR  3
// Cache指令信号
`define CACHE_OP        4:0
// 用于reg内部存储的各个操作数的位置 {{{
`define STAGE `SATGE_LEN-1:0
`define SATGE_LEN 4     
`define SATGE_DATAOK    4'b0000 
`define STAGE_EXE_UP    4'b0001
`define STAGE_EXE_DOWN  4'b0011
`define STAGE_SBA       4'b0101
`define STAGE_PERMEM    4'b1001
`define STAGE_REEXE     4'b1111
`define STAGE_MEM       4'b1101
`define STAGE_PBA       4'b0111
`define STAGE_WB        4'b1011
/*}}}*/
// 访问存储模式设置{{{
`define LOAD_MODE       6:0
`define LOAD_MODE_LB    7'b0000001
`define LOAD_MODE_LBU   7'b0000010
`define LOAD_MODE_LH    7'b0000100
`define LOAD_MODE_LHU   7'b0001000
`define LOAD_MODE_LW    7'b0010000
`define LOAD_MODE_LWL   7'b0100000
`define LOAD_MODE_LWR   7'b1000000
`define LOAD_MODE_LH_BIT    2
`define LOAD_MODE_LHU_BIT   3
`define LOAD_MODE_LW_BIT    4

`define LOAD_SEL        10:0
`define LOAD_SEL_LB     11'b00000000001
`define LOAD_SEL_LBU    11'b00000000010
`define LOAD_SEL_LH     11'b00000000100
`define LOAD_SEL_LHU    11'b00000001000
`define LOAD_SEL_LW     11'b00000010000
`define LOAD_SEL_R1     11'b00000100000
`define LOAD_SEL_R2     11'b00001000000
`define LOAD_SEL_R3     11'b00010000000
`define LOAD_SEL_L0     11'b00100000000
`define LOAD_SEL_L1     11'b01000000000
`define LOAD_SEL_L2     11'b10000000000
`define LOAD_LB_BIT     0
`define LOAD_LBU_BIT    1
`define LOAD_LH_BIT     2
`define LOAD_LHU_BIT    3
`define LOAD_LW_BIT     4
`define LOAD_R1_BIT     5
`define LOAD_R2_BIT     6
`define LOAD_R3_BIT     7
`define LOAD_L0_BIT     8
`define LOAD_L1_BIT     9
`define LOAD_L2_BIT     10

`define STORE_MODE      4:0
`define STORE_MODE_SB   0
`define STORE_MODE_SH   1
`define STORE_MODE_SW   2
`define STORE_MODE_SWL  3
`define STORE_MODE_SWR  4
/*}}}*/
// TLB_参数{{{
`define TLB_VPN 18:0
`define TLB_ASID 7:0
`define TLB_ODD_PAGE 1'b1
`define TLB_EVEN_PAGE 1'b0
`define TLB_PFN 19:0
// TLB 里面的各种位宽
`define CBITS 2:0
`define UNCACHED 3'd2
`define CACHED   3'd3
`define VPN2 89:71
`define ASID 70:63
`define MASK 62:51
`define PFN0 49:30
`define FLAG0 29:25
`define PFN1 24:5
`define FLAG1 4:0
`define TLB_SIZE  32
`define TLB_ENTRY_NUM $clog2(`TLB_SIZE)
`define TLB_WIDTH `TLB_ENTRY_NUM-1:0
/*}}}*/
//二维数组打包为一维数组{{{
`define PACK_ARRAY(PK_WIDTH,PK_LEN,PK_SRC,PK_DEST) \
                generate \
                for (genvar pk_idx = 0; pk_idx <(PK_LEN); pk_idx = pk_idx + 1) \
                begin \
                        assign PK_DEST[((PK_WIDTH)*pk_idx+((PK_WIDTH)-1)):((PK_WIDTH)*pk_idx)] = PK_SRC[pk_idx][((PK_WIDTH)-1):0]; \
                end \
                endgenerate
/*}}}*/
//一维数组展开为二维数组{{{
`define UNPACK_ARRAY(PK_WIDTH,PK_LEN,PK_DEST,PK_SRC) \
                generate \
                for (genvar unpk_idx=0; unpk_idx<(PK_LEN); unpk_idx = unpk_idx + 1) \
                begin \
                        assign PK_DEST[unpk_idx][((PK_WIDTH)-1):0] = PK_SRC[((PK_WIDTH)*unpk_idx+(PK_WIDTH-1)):((PK_WIDTH)*unpk_idx)]; \
                end \
                endgenerate
                /*}}}*/
