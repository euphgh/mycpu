/*====================Ports Declaration====================*/
module adder
    #(parameter BUS = 4)
     (
         input  wire [BUS-1:0]  add_a,add_b, //data: a-b
         input  wire [3:0]      adder_op, //control:选择计算类型--{0:stlu,1:stl,2:-,3:+}
         input	wire	        cin_i,
         output wire [BUS-1:0]  add_res,
         output	wire	        crFlag,
         output wire            overflow
     );
/*====================Variable Declaration====================*/
    wire sub_op,slt_op,sltu_op,add_op;
    wire cin,cout,top_a,top_b;
    wire [BUS-1:0] add_sub_res,data_a,data_b;
    wire [BUS-1:0] sltu_res,slt_res;//根据溢出来判断
/*====================Function Code====================*/
    assign {add_op,sub_op,slt_op,sltu_op} = adder_op;
    assign cin = (sub_op|slt_op|sltu_op) ? 1'b1 : cin_i;
    assign data_a = add_a;
    assign data_b = (sub_op|slt_op|sltu_op) ? ~add_b : add_b;
    assign top_a = (sltu_op) ? 1'b0 : data_a[BUS-1];
    assign top_b = (sltu_op) ? 1'b0 : data_b[BUS-1];
    assign {cout,add_sub_res} = {top_a,data_a} + {top_b,data_b} + {{BUS{1'b0}},cin};
    assign overflow = (cout ^ add_sub_res[BUS-1]);

    assign slt_res[BUS-1:1] = 'b0;
    assign sltu_res[BUS-1:1] = 'b0;
    assign slt_res[0] = ((add_sub_res[BUS-1]) ? 1'b1:1'b0) ^ overflow;
    assign sltu_res[0] = (cout) ? 1'b0:1'b1;

    assign add_res = ({BUS{add_op||sub_op}} & add_sub_res)
                    |({BUS{slt_op}} & slt_res)
                    |({BUS{sltu_op}} & sltu_res);
    assign crFlag = cout;
endmodule
