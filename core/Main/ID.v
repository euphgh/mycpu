// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/06/30 20:47
// Last Modified : 2022/07/26 19:18
// File Name     : ID.v
// Description   : 从InstQueue取指令,解码,确定发射模式,读寄存器,发射
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/06/30   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "MyDefines.v"
module ID (
    input   wire	clk,
    input   wire	rst,

    /////////////////////////////////////////////////
    ///////////////     寄存器输入   ////////////////{{{
    /////////////////////////////////////////////////
    input   wire    [`FOUR_WORDS]                   IF_inst_p_i,
    input	wire	[`IQ_VALID]                     ID_upDateMode_i,   // 可选宏定义三种 
    input   wire    [4*`SINGLE_WORD]                IF_predDest_p_i,
    input   wire    [3:0]                           IF_predTake_p_i,
    input   wire    [4*`ALL_CHECKPOINT]             IF_predInfo_p_i,
    input   wire	[`SINGLE_WORD]                  IF_instBasePC_i,
    input   wire	                                IF_valid_i,
    input   wire	[3:0]                           IF_instEnable_i,
    input   wire    [2:0]                           IF_instNum_i,
    input	wire                                    IF_hasException_i,
    input	wire    [`EXCCODE]                      IF_ExcCode_i,
    input	wire	                                IF_isRefill_i,
    /*}}}*/

    //////////////////////////////////////////////////
    //////////////     线信号输入      ///////////////{{{
    //////////////////////////////////////////////////
    //刷新流水线
    input	wire	SBA_flush_w_i,      
    input	wire	CP0_excOccur_w_i,   
    // 流水线控制
    input	wire	                        EXE_down_allowin_w_i,        // 逐级互锁信号
    input	wire	                        EXE_up_allowin_w_i,        // 逐级互锁信号
    // 数据回写
    input	wire	                        PBA_writeEnable_w_i,
    input	wire	[`GPR_NUM]              PBA_writeNum_w_i,   
    input	wire	[`SINGLE_WORD]          PBA_forwardData_w_i,
    input	wire	                        WB_writeEnable_w_i, 
    input	wire	[`GPR_NUM]              WB_writeNum_w_i,    
    input	wire	[`SINGLE_WORD]          WB_forwardData_w_i, 

    // 其他段的指令ID送回ID段,更新寄存器状态，回写段不需要
    input	wire	[`GPR_NUM]              EXE_up_writeNum_w_i,    
    input	wire	[`FORWARD_MODE]         EXE_up_forwardMode_w_i,    

    input	wire	[`GPR_NUM]              MEM_writeNum_w_i,       
    input	wire	[`FORWARD_MODE]         MEM_forwardMode_w_i,       

    input	wire	[`FORWARD_MODE]         EXE_down_forwardMode_w_i,  
    input	wire	[`GPR_NUM]              EXE_down_writeNum_w_i,  

    input	wire	[`GPR_NUM]              SBA_writeNum_w_i,       
    input	wire	[`FORWARD_MODE]         SBA_forwardMode_w_i,       

    input	wire	[`GPR_NUM]              PREMEM_writeNum_w_i,    
    input	wire	[`FORWARD_MODE]         PREMEM_forwardMode_w_i,    

    input	wire	[`FORWARD_MODE]         REEXE_forwardMode_w_i,     
    input	wire	[`GPR_NUM]              REEXE_writeNum_w_i,     
    // 如果下端流水线存在危险指令,全部暂停
    input	wire	                        EXE_down_hasDangerous_w_i,  
    input	wire	                        MEM_hasDangerous_w_i,       
    input	wire	                        PREMEM_hasDangerous_w_i,     
    input	wire	                        WB_hasDangerous_w_i,     
    /*}}}*/

    //////////////////////////////////////////////////
    //////////////     线信号输出      ///////////////{{{
    //////////////////////////////////////////////////
    // InstQueue反馈信号
    output   wire                           ID_stopFetch_o,
    // 流水线控制
    output	wire	                        ID_down_valid_w_o,
    output	wire	                        ID_up_valid_w_o,
    output	wire	[`IQ_VALID]             ID_upDateMode_o,   // 可选宏定义三种 
/*}}}*/

    /////////////////////////////////////////////////
    ///////////////     寄存器输出   ////////////////{{{
    /////////////////////////////////////////////////
    //上段
    output	wire	[`GPR_NUM]              ID_up_writeNum_o,             // 回写寄存器数值,0为不回写
    output	wire	[2*`SINGLE_WORD]        ID_up_readData_o,           // 寄存器值rsrt
    //算数,位移
    output	wire	[`SINGLE_WORD]          ID_up_oprand0_o,            // 经过多路选择,选择指令自带的数据
    output	wire	                        ID_up_oprand0IsReg_o,       
    output	wire	                        ID_up_oprand1IsReg_o,       
    output	wire	[`FORWARD_MODE]         ID_up_forwardSel0_o,        // 用于选择前递信号
    output	wire	                        ID_up_data0Ready_o,         // 表示该operand是否可用
    output	wire	[`SINGLE_WORD]          ID_up_oprand1_o,            // 经过多路选择器,选择WB前递数据或立即数或SA的第一个操作数
    output	wire	[`FORWARD_MODE]         ID_up_forwardSel1_o,        // 用于选择前递信号
    output	wire	                        ID_up_data1Ready_o,         // 表示该operand是否可用
    output	wire	[`ALUOP]                ID_up_aluOprator_o,
    // 异常
    output	wire	[`SINGLE_WORD]          ID_up_VAddr_o,              // 用于debug和异常处理
    output	wire    [`EXCCODE]              ID_up_ExcCode_o,            // 异常信号	
    output	wire	                        ID_up_hasException_o,         // 存在异常
    output	wire                            ID_up_exceptionRisk_o,      // 存在异常的风险
    output	wire	[`EXCEPRION_SEL]        ID_up_exceptionSel_o,
    output	wire	[`TRAP_KIND]            ID_up_trapKind_o,           // 自陷指令的种类
    // 分支确认的信息
    output	wire                            ID_up_branchRisk_o,         // 存在分支确认失败的风险
    output	wire	[`REPAIR_ACTION]        ID_up_repairAction_o,       // 预测的分支类型
    output	wire	[`SINGLE_WORD]          ID_up_predDest_o,           // 预测的分支地址
    output	wire	                        ID_up_predTake_o,           // 预测的分支跳转
    output	wire	[`ALL_CHECKPOINT]       ID_up_checkPoint_o,         // 分支预测检查点
    output	wire    [`BRANCH_KIND]          ID_up_branchKind_o,         // 分支指令的种类
    //下段
    output	wire	[`GPR_NUM]              ID_down_writeNum_o,         // 回写寄存器数值,0为不回写
    output	wire	[2*`SINGLE_WORD]        ID_down_readData_o,         // 寄存器值rsrt
    output	wire	                        ID_down_isDelaySlot_o,      // 表示该指令是否是延迟槽指令
    output	wire	                        ID_down_isDangerous_o,      // 表示该指令在执行期间不得执行其他指令
    output	wire	[`SINGLE_WORD]          ID_down_VAddr_o,            // 用于debug和异常处理
    //算数,位移
    output	wire	[`SINGLE_WORD]          ID_down_oprand0_o,          // 经过多路选择器,选择WB前递数据或立即数或SA的第一个操作数
    output	wire	                        ID_down_oprand0IsReg_o,     
    output	wire	                        ID_down_oprand1IsReg_o,     
    output	wire	[`FORWARD_MODE]         ID_down_forwardSel0_o,      // 用于选择前递信号
    output	wire	                        ID_down_data0Ready_o,       // 表示该operand是否可用
    output	wire	[`SINGLE_WORD]          ID_down_oprand1_o,          // 经过多路选择器,选择WB前递数据或立即数或SA的第一个操作数
    output	wire	[`FORWARD_MODE]         ID_down_forwardSel1_o,      // 用于选择前递信号
    output	wire	                        ID_down_data1Ready_o,       // 表示该operand是否可用
    output	wire	[`ALUOP]                ID_down_aluOprator_o,
    // 乘除指令类信息
    output	wire	[`MDUOP]                ID_down_mduOperator_o,      // 包括乘除,clo,clz和累加累减
    output	wire	[`HILO]                 ID_down_readHiLo_o,         // 只有指令需要将HiLo写入GPR,该信号才会拉高,包括clo/z,mul,mfhilo
    output	wire	[`HILO]                 ID_down_writeHiLo_o,        // 需要根据数值写HiLo的指令,有madd,/sub,mult,div,mtc0,其中mtc0是类似与add做运算,之后将运算结果写入
    // 异常处理类信息
    output	wire    [`EXCCODE]              ID_down_ExcCode_o,          // 异常信号	
    output	wire	[`EXCEPRION_SEL]        ID_down_exceptionSel_o,
    output	wire	                        ID_down_hasException_o,       // 存在异常
    output	wire                            ID_down_exceptionRisk_o,    // 存在异常的风险
    output	wire	[`CP0_POSITION]         ID_down_positionCp0_o,      // {rd,sel}
    output	wire	                        ID_down_readCp0_o,          // 只有指令需要将cp0写入GPR,该信号才会拉高,mfc0
    output	wire	                        ID_down_eret_o,
    output	wire	                        ID_down_writeCp0_o,         // 只有指令需要将GPR写入cp0,该信号才会拉高,mtc0,直接将rt寄存器的数值接入
    output	wire	[`TRAP_KIND]            ID_down_trapKind_o,           // 自陷指令的种类
    // 访存类信息
    output	wire	                        ID_down_memReq_o,           // 表示访存请求
    output	wire	                        ID_down_memWR_o,            // 表示访存类型
    output	wire	                        ID_down_memAtom_o,          // 表示该访存操作是原子访存操作,需要读写LLbit
    output	wire    [`LOAD_MODE]            ID_down_loadMode_o,         // load模式	
    output	wire    [`STORE_MODE]           ID_down_storeMode_o,        // store模式	
    // TLB指令
    output	wire	                        ID_down_isTLBInst_o,        // 表示是TLB指令
    output	wire	[`TLB_INST]             ID_down_TLBInstOperator_o,  // 执行的种类
    // Cache指令,和乘除法相同，如果操作数没有准备好就不能发射
    output	wire	                        ID_down_isCacheInst_o,      // 表示是Cache指令
    output	wire	[`CACHE_OP]             ID_down_CacheOperator_o     // Cache指令op
    /*}}}*/
);
    /*autodef*/   
    /*{{{*/
    //Start of automatic define
    //Start of automatic reg
    //Define flip-flop registers here
    //Define combination registers here
    //End of automatic reg
    //Start of automatic wire
    //Define assign wires here
    //Define instance wires here
    wire [`IQ_VALID]                   IQ_supplyValid           ;
    wire [2*`SINGLE_WORD]              IQ_VAddr_p               ;
    wire [2*`SINGLE_WORD]              IQ_inst_p                ;
    wire [1:0]                         IQ_hasException_p        ;
    wire [2*`EXCCODE]                  IQ_ExcCode_p             ;
    wire [2*`SINGLE_WORD]              IQ_predDest_p            ;
    wire [1:0]                         IQ_predTake_p            ;
    wire [2*`ALL_CHECKPOINT]           IQ_checkPoint_p          ;
    wire                               IQ_full                  ;
    wire                               IQ_empty                 ;
    wire [$clog2(`IQ_CAPABILITY):0]    IQ_number_w              ;
    wire [1:0]                         IQ_isRefill_p            ;
    wire [2*`SINGLE_WORD]              AB_Inst_p                ;
    wire [2*`SINGLE_WORD]              AB_VAddr_p               ;
    wire [2*`SINGLE_WORD]              AB_predDest_p            ;
    wire [1:0]                         AB_hasException_p        ;
    wire [1:0]                         AB_predTake_p            ;
    wire [2*`EXCCODE]                  AB_ExcCode_p             ;
    wire [2*`ALL_CHECKPOINT]           AB_checkPoint_p          ;
    wire [`ISSUE_MODE]                 AB_issueMode_w           ;
    wire [4*`GPR_NUM]                  AB_regReadNum_p_w        ;
    wire [3:0]                         AB_needRead_p_w          ; // WIRE_NEW
    wire [2*`GPR_NUM]                  AB_regWriteNum_p_w       ;
    wire [1:0]                         AB_isRefill_p            ;
    wire [4*`SINGLE_WORD]              readData_p_o             ;
    wire [1:0]                         ID_exceptionRisk_p       ;
    wire [1:0]                         decorderException_p      ;
    wire [2*`EXTEND_ACTION]            extendAction_p           ;
    wire [2*`EXCCODE]                  decorderExcCode_p        ;
    //End of automatic wire
    //End of automatic define
    wire [`SINGLE_WORD]                instOffset               ;
    wire [`EXTEND_ACTION]              extendAction_up [1:0]    ;
    wire [`SINGLE_WORD]                extendedRes_up  [1:0]    ;
/*}}}*/
    InstQueue InstQueue_u (/*{{{*/
        .clk                    (clk                                        ), //input
        .rst                    (rst                                        ), //input
        // 取指令控制
        .ID_upDateMode_i        (ID_upDateMode_i[1:0]                       ), //input
        // 分支确认信号
        .IF_predDest_p_i        (IF_predDest_p_i[4*`SINGLE_WORD]            ), //input
        .IF_predTake_p_i        (IF_predTake_p_i[3:0]                       ), //input
        .IF_predInfo_p_i        (IF_predInfo_p_i[4*`ALL_CHECKPOINT]         ), //input
        // 四条指令的基地址
        .IF_instBasePC_i        (IF_instBasePC_i[`SINGLE_WORD]              ), //input
        // 送入指令FIFO的指令    
        .IF_valid_i             (IF_valid_i                                 ), //input
        .IF_instEnable_i        (IF_instEnable_i[3:0]                       ), //input
        .IF_inst_p_i            (IF_inst_p_i[`FOUR_WORDS]                   ), //input
        .IF_instNum_i           (IF_instNum_i[2:0]                          ), //input
        // 送入指令FIFO的异常信息
        .IF_hasException_i      (IF_hasException_i                          ), //input
        .IF_ExcCode_i           (IF_ExcCode_i[`EXCCODE]                     ), //input
        // 取出指令
        .IQ_supplyValid         (IQ_supplyValid  [`IQ_VALID]                ), //output
        .IQ_VAddr_p             (IQ_VAddr_p  [2*`SINGLE_WORD]               ), //output
        .IQ_inst_p              (IQ_inst_p  [2*`SINGLE_WORD]                ), //output
        .IQ_hasException_p      (IQ_hasException_p  [1:0]                   ), //output
        .IQ_ExcCode_p           (IQ_ExcCode_p  [2*`EXCCODE]                 ), //output
        .IQ_predDest_p          (IQ_predDest_p  [2*`SINGLE_WORD]            ), //output
        .IQ_predTake_p          (IQ_predTake_p  [1:0]                       ), //output
        .IQ_checkPoint_p        (IQ_checkPoint_p  [2*`ALL_CHECKPOINT]       ), //output
        .IQ_full                (IQ_full                                    ), //output
        .IQ_empty               (IQ_empty                                   ), //output
        .ID_stopFetch_o         (ID_stopFetch_o                             ), //output
        .IQ_number_w            (IQ_number_w  [$clog2(`IQ_CAPABILITY):0]    ), //output
        .IF_isRefill_i          (IF_isRefill_i                  ), //input
        .IQ_isRefill_p          (IQ_isRefill_p[1:0]             ), //output
        /*autoinst*/
        .SBA_flush_w_i          (SBA_flush_w_i                  ), //input
        .CP0_excOccur_w_i       (CP0_excOccur_w_i               )  //input
    );
    /*}}}*/
    Arbitrator Arbitrator_u (/*{{{*/
        .IQ_supplyValid          (IQ_supplyValid  [`IQ_VALID]              ), //input
        .IQ_inst_p               (IQ_inst_p  [2*`SINGLE_WORD]              ), //input
        .IQ_VAddr_p              (IQ_VAddr_p  [2*`SINGLE_WORD]             ), //input // INST_NEW
        .IQ_hasException_p       (IQ_hasException_p  [1:0]                 ), //input // INST_NEW
        .IQ_ExcCode_p            (IQ_ExcCode_p  [2*`EXCCODE]               ), //input // INST_NEW
        .IQ_predDest_p           (IQ_predDest_p  [2*`SINGLE_WORD]          ), //input // INST_NEW
        .IQ_predTake_p           (IQ_predTake_p  [1:0]                     ), //input // INST_NEW
        .IQ_checkPoint_p         (IQ_checkPoint_p  [2*`ALL_CHECKPOINT]     ), //input // INST_NEW
        .AB_Inst_p               (AB_Inst_p  [2*`SINGLE_WORD]              ), //output
        .AB_VAddr_p              (AB_VAddr_p  [2*`SINGLE_WORD]             ), //output // INST_NEW
        .AB_predDest_p           (AB_predDest_p  [2*`SINGLE_WORD]          ), //output // INST_NEW
        .AB_hasException_p       (AB_hasException_p  [1:0]                 ), //output // INST_NEW
        .AB_predTake_p           (AB_predTake_p  [1:0]                     ), //output // INST_NEW
        .AB_ExcCode_p            (AB_ExcCode_p  [2*`EXCCODE]               ), //output // INST_NEW
        .AB_checkPoint_p         (AB_checkPoint_p  [2*`ALL_CHECKPOINT]     ), //output // INST_NEW
        .AB_issueMode_w          (AB_issueMode_w  [`ISSUE_MODE]            ), //output
        .AB_regReadNum_p_w       (AB_regReadNum_p_w  [4*`GPR_NUM]          ), //output
        .AB_needRead_p_w         (AB_needRead_p_w                          ),
        .AB_regWriteNum_p_w      (AB_regWriteNum_p_w  [2*`GPR_NUM]         ), //output
        /*autoinst*/
        .IQ_isRefill_p          (IQ_isRefill_p[1:0]             ), //input
        .AB_isRefill_p          (AB_isRefill_p[1:0]             )  //output
    );
    wire    [`SINGLE_WORD]              AB_VAddr_up           [1:0];  
    wire    [`SINGLE_WORD]              AB_inst_up            [1:0];  
    wire    [0:0]                       AB_hasException_up    [1:0];  
    wire    [`EXCCODE]                  AB_ExcCode_up         [1:0];  
    wire    [`SINGLE_WORD]              AB_predDest_up        [1:0];  
    wire    [0:0]                       AB_predTake_up        [1:0];  
    wire    [`ALL_CHECKPOINT]           AB_checkPoint_up      [1:0];  
    `UNPACK_ARRAY(`SINGLE_WORD_LEN,2,AB_VAddr_up,AB_VAddr_p  )
    `UNPACK_ARRAY(`SINGLE_WORD_LEN,2,AB_inst_up,AB_Inst_p  )
    `UNPACK_ARRAY(1,2,AB_hasException_up,AB_hasException_p  )
    `UNPACK_ARRAY(`SINGLE_WORD_LEN,2,AB_predDest_up,AB_predDest_p  )
    `UNPACK_ARRAY(1,2,AB_predTake_up,AB_predTake_p  )
    `UNPACK_ARRAY(`ALL_CHECKPOINT_LEN,2,AB_checkPoint_up,AB_checkPoint_p  )
    `UNPACK_ARRAY(`EXCCODE_LEN,2,AB_ExcCode_up,AB_ExcCode_p  )
    /*}}}*/
    RegFile RegFile_u (/*{{{*/
        /*autoinst*/
        .clk                    (clk                                   ), //input
        .rst                    (rst                                   ), //input
        // 读端口 
        .AB_regReadNum_p_w      (AB_regReadNum_p_w  [4*`GPR_NUM]       ), //input
        .readData_p_o           (readData_p_o[4*`SINGLE_WORD]          ), //output
        // 写端口
        .PBA_writeEnable_w_i    (PBA_writeEnable_w_i                   ), //input
        .PBA_writeNum_w_i       (PBA_writeNum_w_i[`GPR_NUM]            ), //input
        .PBA_forwardData_w_i    (PBA_forwardData_w_i[`SINGLE_WORD]     ), //input
        .WB_writeEnable_w_i     (WB_writeEnable_w_i                    ), //input
        .WB_writeNum_w_i        (WB_writeNum_w_i[`GPR_NUM]             ), //input
        .WB_forwardData_w_i     (WB_forwardData_w_i[`SINGLE_WORD]      )  //input
    );
    wire    [`GPR_NUM]      readNum     [1:0][1:0]; // 第一个下标代表流水线，第二个代表rs,rt
    wire    [0:0]           needRead    [1:0][1:0]; // 第一个下标代表流水线，第二个代表rs,rt
    generate
        for (genvar i = 0; i < 2; i=i+1)	begin
            for (genvar j = 0; j < 2; j=j+1)	begin
                assign readNum[i][j] = AB_regReadNum_p_w[i*10+j*5+4:i*10+j*5];
                assign needRead[i][j] = AB_needRead_p_w[i*2+j:i*2+j];
                
            end
        end
    endgenerate
    /*}}}*/
    Decorder Decorder_u(/*{{{*/
        .AB_Inst_p                    (AB_Inst_p  [2*`SINGLE_WORD]              ), //input
        //算数,位移
        .ID_up_aluOprator_o           (ID_up_aluOprator_o[`ALUOP]               ), //output
        // 异常
        .ID_exceptionRisk_p           (ID_exceptionRisk_p                       ), //output
        //下段
        .ID_down_isDangerous_o        (ID_down_isDangerous_o                    ), //output
        //算数,位移
        .ID_down_aluOprator_o         (ID_down_aluOprator_o[`ALUOP]             ), //output
        // 乘除指令类信息
        .ID_down_mduOperator_o        (ID_down_mduOperator_o[`MDUOP]              ), //output
        .ID_down_readHiLo_o           (ID_down_readHiLo_o[`HILO]                ), //output
        .ID_down_writeHiLo_o          (ID_down_writeHiLo_o[`HILO]               ), //output
        .ID_up_branchRisk_o           (ID_up_branchRisk_o                       ), 
        .ID_up_repairAction_o         (ID_up_repairAction_o                     ), 
        // 异常处理类信息
        .ID_down_readCp0_o            (ID_down_readCp0_o                        ), //output
        .ID_down_writeCp0_o           (ID_down_writeCp0_o                       ), //output
        .ID_down_eret_o               (ID_down_eret_o                           ),
        // 访存类信息
        .ID_down_memReq_o             (ID_down_memReq_o                         ), //output
        .ID_down_memWR_o              (ID_down_memWR_o                          ), //output
        .ID_down_memAtom_o            (ID_down_memAtom_o                        ), //output
        .ID_down_loadMode_o           (ID_down_loadMode_o[`LOAD_MODE]           ), //output
        .ID_down_storeMode_o          (ID_down_storeMode_o[`STORE_MODE]         ), //output
        // TLB指令
        .ID_down_isTLBInst_o          (ID_down_isTLBInst_o                      ), //output
        .ID_down_TLBInstOperator_o    (ID_down_TLBInstOperator_o[`TLB_INST]     ), //output
        // Cache指令,和乘除法相同，如果操作数没有准备好就不能发射
        .ID_down_isCacheInst_o        (ID_down_isCacheInst_o                    ), //output
        .ID_down_CacheOperator_o      (ID_down_CacheOperator_o[`CACHE_OP]       ), //output
        .up_oprand0_sel               (up_oprand0_sel[`OPRAND_SEL]              ), //output
        .up_oprand1_sel               (up_oprand1_sel[`OPRAND_SEL]              ), //output
        .down_oprand0_sel             (down_oprand0_sel[`OPRAND_SEL]            ), //output
        .down_oprand1_sel             (down_oprand1_sel[`OPRAND_SEL]            ), //output
        .decorderException_p          (decorderException_p[1:0]                 ), //output
        .extendAction_p               (extendAction_p[2*`EXTEND_ACTION]         ),  //output
        .decorderExcCode_p            (decorderExcCode_p[2*`EXCCODE]            ), //output
        .ID_up_exceptionSel_o         (ID_up_exceptionSel_o[`EXCEPRION_SEL]     ), //output
        .ID_down_exceptionSel_o       (ID_down_exceptionSel_o[`EXCEPRION_SEL]   ), //output
        .ID_up_trapKind_o             (ID_up_trapKind_o[`TRAP_KIND]             ), //output // INST_NEW
        .ID_down_trapKind_o           (ID_down_trapKind_o[`TRAP_KIND]           ),  //output // INST_NEW
        .ID_up_branchKind_o           (ID_up_branchKind_o                       )
        /*autoinst*/
    );
    /*}}}*/
    ImmExtender ImmExtender_up(/*{{{*/
        /*autoinst*/
        .inst_index             (AB_inst_up[0][25:0]              ), //input
        .extendAction           (extendAction_up[0]               ), //input
        .extendedRes            (extendedRes_up[0]                )  //output
    );
    ImmExtender ImmExtender_down(
        /*autoinst*/
        .inst_index             (AB_inst_up[1][25:0]              ), //input
        .extendAction           (extendAction_up[1]               ), //input
        .extendedRes            (extendedRes_up[1]                )  //output
    );
    `UNPACK_ARRAY(`EXTEND_ACTION_LEN,2,extendAction_up,extendAction_p)
    /*}}}*/
    // 操作数的生成和准备{{{
    wire    [`SINGLE_WORD]  saField_up  [1:0];
    generate
        for (genvar i = 0; i < 2; i=i+1)	begin
            assign saField_up[i] = {27'b0,AB_inst_up[i][10:6]};
        end
    endgenerate
    wire    [`OPRAND_SEL]   up_oprand0_sel;
    wire    [`OPRAND_SEL]   up_oprand1_sel;
    wire    [`OPRAND_SEL]   down_oprand0_sel;
    wire    [`OPRAND_SEL]   down_oprand1_sel;
    wire    [`OPRAND_SEL]   oprand_sel  [1:0][1:0];
    assign oprand_sel[0][0] = up_oprand0_sel;
    assign oprand_sel[0][1] = up_oprand1_sel;
    assign oprand_sel[1][0] = down_oprand0_sel;
    assign oprand_sel[1][1] = down_oprand1_sel;
    assign instOffset = {extendedRes_up[0][29:0],2'b0};
    wire   [`SINGLE_WORD]   partialDelaySlot = extendAction_up[0][`ZERO_EXTEND_INDEX] ? {AB_VAddr_up[0][31:28],28'b0} : (AB_VAddr_up[0] + 3'd4);
    assign ID_up_oprand0_o =    up_oprand0_sel[`SEL_DELAYSLOT_PC]   ?   partialDelaySlot: saField_up[0];
    assign ID_up_oprand1_o =    up_oprand1_sel[`SEL_INST_OFFSET]    ?   instOffset : extendedRes_up[0];
    assign ID_down_oprand0_o =  saField_up[1];
    assign ID_down_oprand1_o =  extendedRes_up[1];
    assign ID_up_writeNum_o =   AB_regWriteNum_p_w[4:0];
                                
    assign ID_down_writeNum_o = AB_regWriteNum_p_w[9:5]; 
    assign {ID_down_readData_o,ID_up_readData_o} = readData_p_o;
    /*}}}*/
    // 前递选择子的获取{{{
    wire [`FORWARD_MODE]    forwardSel      [1:0][1:0];   //第一个参数代表两条流水线，后一个代表rs，rt
    wire [0:0]              WAR_conflict_up [1:0][1:0];  // 同上
    generate
        for (genvar l = 0; l < 2; l=l+1)	begin
            for (genvar k = 0; k < 2; k=k+1)	begin
                 assign forwardSel[l][k] =      (EXE_down_writeNum_w_i==readNum[l][k] && |readNum[l][k]) ? {EXE_down_forwardMode_w_i} :
                                                (EXE_up_writeNum_w_i==readNum[l][k] && |readNum[l][k]) ? {EXE_up_forwardMode_w_i} :
                                                (PREMEM_writeNum_w_i==readNum[l][k] && |readNum[l][k]) ? {PREMEM_forwardMode_w_i} :
                                                (SBA_writeNum_w_i==readNum[l][k] && |readNum[l][k]) ? {SBA_forwardMode_w_i} :
                                                (MEM_writeNum_w_i==readNum[l][k] && |readNum[l][k]) ? {MEM_forwardMode_w_i} :
                                                (REEXE_writeNum_w_i==readNum[l][k] && |readNum[l][k]) ? {REEXE_forwardMode_w_i} : `FORWARD_MODE_ID;
                // 必须要暂停的load写后读
                assign WAR_conflict_up[l][k] = forwardSel[l][k][`FORWARD_WB_BIT] && (forwardSel[l][k][`FORWARD_MEM_BIT] || forwardSel[l][k][`FORWARD_PREMEM_BIT]); 
            end
        end
    endgenerate
    assign ID_up_data0Ready_o = forwardSel[0][0][`FORWARD_ID_BIT];
    assign ID_up_data1Ready_o = forwardSel[0][1][`FORWARD_ID_BIT];
    assign ID_down_data0Ready_o = forwardSel[1][0][`FORWARD_ID_BIT];
    assign ID_down_data1Ready_o = forwardSel[1][1][`FORWARD_ID_BIT];
    assign ID_up_forwardSel0_o = forwardSel[0][0];
    assign ID_up_forwardSel1_o = forwardSel[0][1];
    assign ID_down_forwardSel0_o = forwardSel[1][0];
    assign ID_down_forwardSel1_o = forwardSel[1][1];
    assign ID_up_oprand0IsReg_o = oprand_sel[0][0][`SEL_RS_DATA];
    assign ID_up_oprand1IsReg_o = oprand_sel[0][1][`SEL_RT_DATA];
    assign ID_down_oprand0IsReg_o = oprand_sel[1][0][`SEL_RS_DATA];
    assign ID_down_oprand1IsReg_o = oprand_sel[1][1][`SEL_RT_DATA];
/*}}}*/
    // 流水暂停控制{{{ 
    wire WAR_conflict = (WAR_conflict_up[0][0]) || (WAR_conflict_up[1][0]) || (WAR_conflict_up[1][0]) || (WAR_conflict_up[1][1]);
    wire hasDangerous = EXE_down_hasDangerous_w_i || MEM_hasDangerous_w_i || PREMEM_hasDangerous_w_i || WB_hasDangerous_w_i;
    wire stop = WAR_conflict || hasDangerous;
    wire ok_to_change = !(|AB_issueMode_w) || (EXE_down_allowin_w_i && EXE_up_allowin_w_i && !stop);
    assign ID_upDateMode_o = !ok_to_change ? `NO_ISSUE : AB_issueMode_w;
    assign ID_up_valid_w_o = (AB_issueMode_w[1]) && !stop;
    assign ID_down_valid_w_o = (AB_issueMode_w[0]) && !stop;
/*}}}*/
    // 异常处理{{{
    // 此处的存在异常发生仅仅包括CPU,RI,SYS,BP的可解码异常，之后传递ALU选择信号
    wire    [0:0]       decorderException_up    [1:0];
    // 此处的异常代码号解码出来的结果包括CpU,RI,SYS,BP,TR,OV,这些互斥的代号
    wire    [`EXCCODE]  decorderExcCode_up      [1:0];
    `UNPACK_ARRAY(1,2,decorderException_up,decorderException_p)
    `UNPACK_ARRAY(`EXCCODE_LEN,2,decorderExcCode_up,decorderExcCode_p)
    assign ID_up_VAddr_o = AB_VAddr_up[0];
    assign ID_up_hasException_o = AB_hasException_up[0] || decorderException_up[0];
    assign ID_up_ExcCode_o = AB_hasException_up[0] ? AB_ExcCode_up[0] : decorderExcCode_up[0];
    // 此处包括任何可能产生异常的指令,除了上面之外,包括
    // trap,add,sub,load,store,mtc0,eret等
    assign ID_up_exceptionRisk_o = ID_up_hasException_o ? 1'b1 : ID_exceptionRisk_p[0];

    assign ID_down_VAddr_o = AB_VAddr_up[1];
    assign ID_down_hasException_o = AB_hasException_up[1] || decorderException_up[1];
    assign ID_down_ExcCode_o = AB_hasException_up[1] ? AB_ExcCode_up[1] : decorderExcCode_up[1];
    assign ID_down_exceptionRisk_o = ID_down_hasException_o ? 1'b1 : ID_exceptionRisk_p[1];
    assign ID_down_isDelaySlot_o = ID_up_branchRisk_o;
    assign ID_down_positionCp0_o = {AB_regWriteNum_p_w[9:5],AB_inst_up[1][2:0]};
/*}}}*/
    // 分支预测{{{
    assign ID_up_checkPoint_o = AB_checkPoint_up[0];
    assign ID_up_predDest_o = AB_predDest_up[0];
    assign ID_up_predTake_o = AB_predTake_up[0];
/*}}}*/
endmodule

