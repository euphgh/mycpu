`timescale 1ns / 1ps
`include "../../../MyDefines.v"
module ALU(
        input   wire    [`SINGLE_WORD]  scr0,
        input	wire	[`SINGLE_WORD]  scr1,
        input   wire    [`ALUOP]        aluop,
        output  wire                    overflow,
        output  wire    [`SINGLE_WORD]  aluso
    );
    
    //所有操作符的定义{{{
    wire add_op = aluop[`ALU_ADD];
    wire sub_op = aluop[`ALU_SUB];
    wire and_op = aluop[`ALU_AND];
    wire or_op  = aluop[`ALU_OR ];
    wire nor_op = aluop[`ALU_NOR];
    wire xor_op = aluop[`ALU_XOR];
    wire slt_op = aluop[`ALU_SLT];
    wire sltu_op= aluop[`ALU_SLTU];
    wire sll_op = aluop[`ALU_SLL];
    wire srl_op = aluop[`ALU_SRL];
    wire sra_op = aluop[`ALU_SRA];
    wire lui_op = aluop[`ALU_LUI];
/*}}}*/
    //与、或、或非、异或、逻辑左移右移、算数右移、高位置数
    wire [31:0] and_res,or_res,nor_res,xor_res,sll_res,srl_res,sra_res,lui_res;
    assign and_res = scr0 & scr1;
    assign or_res = scr0 | scr1;
    assign nor_res = ~(scr0 | scr1);
    assign xor_res = scr0 ^ scr1;
    assign sll_res = scr1 << scr0[4:0] ;
    assign srl_res = scr1 >> scr0[4:0] ;
    assign sra_res = ($signed(scr1)) >>> scr0[4:0] ;
    assign lui_res = {scr1[15:0],16'b0};
    //加、减、无符号比较、有符号比较
    wire [31:0] add_sub_res;
    wire        crFlag;
    adder #(.BUS(32)) u_adder (
              .add_a                   ( scr0      ),
              .add_b                   ( scr1      ),
              .cin_i                   ( 1'b0      ),
              .adder_op                ( {add_op,sub_op,slt_op,sltu_op}   ),
              .crFlag                  (crFlag      ),

              .add_res                 ( add_sub_res    ),
              .overflow                ( overflow       )
          );
    //整理计算结果
    assign aluso  = ({32{add_op||sub_op||slt_op||sltu_op}} & add_sub_res)
           |({32{and_op}} & and_res)
           |({32{or_op}} & or_res)
           |({32{nor_op}} & nor_res)
           |({32{xor_op}} & xor_res)
           |({32{sll_op}} & sll_res)
           |({32{srl_op}} & srl_res)
           |({32{sra_op}} & sra_res)
           |({32{lui_op}} & lui_res) ;
endmodule
