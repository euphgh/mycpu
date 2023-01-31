// +FHDR----------------------------------------------------------------------------
// Project Name  : IC_Design
// Device        : Artix-7 xc7a200tfbg676-2
// Author        : Guanghui Hu
// Created On    : 2022/07/09 14:37
// Last Modified : 2022/07/23 10:28
// File Name     : RepairDecorder.v
// Description   :
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2022/07/09   Guanghui Hu     1.0                     Original
// -FHDR----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "../../../MyDefines.v"
module RepairDecorder (
    input	wire	[`SINGLE_WORD]      inst,
    input	wire	                    isDiffRes,
    output	wire	[`REPAIR_ACTION]    now_RepairAction
);
    /**
    * final修复的错误如下,一旦解码之后就不会改变
    *   1. B        nojump | jump x | PHT repair,RSA repair,BTB repair,           
    *   2. B        jump x | nojump | PHT repair,RSA repair,BTB repair,          
    *   4. BAL      nojump | jump y | PHT repair,          ,BTB repair,          
    *   4. BAL      jump x | nojump | PHT repair,          ,BTB repair,          
    *   4. J        jump x | jump y |           ,RSA repair,BTB repair,          
    *   6. JAL      jump x | jump y |           ,          ,BTB repair,
    *   5. JR(1-30) jump x | jump y |           ,RSA repair,BTB repair,IJTC repair
    *   8. JALR     jump x | jump y |           ,          ,BTB repair,IJTC repair
    *   7. JR($31)  jump x | jump y |           ,          ,BTB repair,            
    * pre修复,会根据两种预测结果改变分支修复的行为
    *   4. B        BTB nojump | PHT nojump | PHT direct,          ,          ,IJTC direct
    *   5. B        BTB jump x | PHT jump   | PHT direct,          ,          ,IJTC direct
    *   9. BAL      BTB nojump | PHT nojump | PHT direct,RSA Push  ,          ,IJTC direct
    *  10. BAL      BTB jump x | PHT jump x | PHT direct,RSA Push  ,          ,IJTC direct
    *  14. J        BTB jump x |     jump x |           ,          ,           IJTC direct
    *  16. JAL      BTB jump x |     jump x |           ,RSA Push  ,           IJTC direct
    *  18. JALR     BTB jump x | IJTCjump x |           ,RSA Push  ,          ,IJTC direct
    *  15. JR(1-30) BTB jump x | IJTCjump x |           ,          ,           IJTC direct
    *   7. JR($31)  BTB jump x | RSA jump x |           ,RSA Pop   ,          ,IJTC direct
    *
    *   2. B        BTB jump x | PHT nojump | PHT direct,          ,BTB repair,IJTC direct
    *   1. B        BTB nojump | PHT jump   | PHT direct,          ,BTB repair,IJTC direct
    *   6. BAL      BTB nojump | PHT jump x | PHT direct,RSA Push  ,BTB repair,IJTC direct
    *   8. BAL      BTB jump x | PHT jump   | PHT direct,RSA Push  ,BTB repair,IJTC direct
    *   7. BAL      BTB jump x | PHT nojump | PHT direct,RSA Push  ,BTB repair,IJTC direct
    *  18. JALR     BTB jump x | IJTCjump y |           ,RSA Push  ,BTB repair,IJTC direct
    *  15. JR(1-30) BTB jump x | IJTCjump y |           ,          ,BTB repair,IJTC direct
    *   7. JR($31)  BTB jump x | RSA jump y |           ,RSA Pop   ,BTB repair,IJTC direct
    */

    wire	[`REPAIR_ACTION]    now_RepairAction_m;

    /*autodef*//*{{{*/
    //Start of automatic define
    //Start of automatic reg
    //Define flip-flop registers here
    //Define combination registers here
    //End of automatic reg
    //Start of automatic wire
    //Define assign wires here
    wire                        isRsFull                        ;
    //Define instance wires here
    //End of automatic wire
    //End of automatic define}}}
        /*autoDecoder_Start*/ /*{{{*/
        
	assign	now_RepairAction_m[3]	=	(((!inst[26]&!inst[27]&!inst[28]&!inst[29]&!inst[30]&!inst[31])) &
 ((inst[0]))) |
 (!((!inst[26]&!inst[27]&!inst[28]&!inst[29]&!inst[30]&!inst[31])) &
 ((((inst[26]&!inst[27]&!inst[28]&!inst[29]&!inst[30]&!inst[31])) &
 ((inst[16]&inst[20]) | (!inst[16]&inst[20]))) |
 (!((inst[26]&!inst[27]&!inst[28]&!inst[29]&!inst[30]&!inst[31])) &
 ((inst[26]&inst[27]&!inst[28])))));
	assign	now_RepairAction_m[4]	=	(((!inst[26]&!inst[27]&!inst[28]&!inst[29]&!inst[30]&!inst[31])) &
 ((!inst[0]))) |
 (!((!inst[26]&!inst[27]&!inst[28]&!inst[29]&!inst[30]&!inst[31])) &
 (1'b0));
	assign	now_RepairAction_m[5]	=	(((!inst[26]&!inst[27]&!inst[28]&!inst[29]&!inst[30]&!inst[31])) &
 (1'b0)) |
 (!((!inst[26]&!inst[27]&!inst[28]&!inst[29]&!inst[30]&!inst[31])) &
 ((!inst[26]&!inst[27]&inst[28]) | (inst[26]&!inst[27]&inst[28]) | (inst[26]&inst[27]&inst[28]) | (!inst[26]&inst[27]&inst[28]) | (inst[26]&!inst[27]&!inst[28])));
	assign	now_RepairAction_m[6]	=	(((!inst[26]&!inst[27]&!inst[28]&!inst[29]&!inst[30]&!inst[31])) &
 (1'b0)) |
 (!((!inst[26]&!inst[27]&!inst[28]&!inst[29]&!inst[30]&!inst[31])) &
 (1'b0));
	assign	now_RepairAction_m[7]	=	(((!inst[26]&!inst[27]&!inst[28]&!inst[29]&!inst[30]&!inst[31])) &
 ((!inst[0]&!inst[1]&!inst[2]&inst[3]&!inst[4]&!inst[5]) | (inst[0]&!inst[1]&!inst[2]&inst[3]&!inst[4]&!inst[5]))) |
 (!((!inst[26]&!inst[27]&!inst[28]&!inst[29]&!inst[30]&!inst[31])) &
 ((((inst[26]&!inst[27]&!inst[28]&!inst[29]&!inst[30]&!inst[31])) &
 ((inst[16]&!inst[17]&!inst[18]&!inst[19]&!inst[20]) | (!inst[16]&!inst[17]&!inst[18]&!inst[19]&!inst[20]) | (inst[16]&!inst[17]&!inst[18]&!inst[19]&inst[20]) | (!inst[16]&!inst[17]&!inst[18]&!inst[19]&inst[20]))) |
 (!((inst[26]&!inst[27]&!inst[28]&!inst[29]&!inst[30]&!inst[31])) &
 ((!inst[26]&!inst[27]&inst[28]&!inst[29]&!inst[30]&!inst[31]) | (inst[26]&!inst[27]&inst[28]&!inst[29]&!inst[30]&!inst[31]) | (inst[26]&inst[27]&inst[28]&!inst[29]&!inst[30]&!inst[31]) | (!inst[26]&inst[27]&inst[28]&!inst[29]&!inst[30]&!inst[31]) | (!inst[26]&inst[27]&!inst[28]&!inst[29]&!inst[30]&!inst[31]) | (inst[26]&inst[27]&!inst[28]&!inst[29]&!inst[30]&!inst[31])))));
        /*autoDecoder_End*/ /*}}}*/
    assign isRsFull = &inst[25:21];
    assign now_RepairAction[`BTB_ACTION] = isDiffRes ? `BTB_REPAIRE : `BTB_NOACTION;
    assign now_RepairAction[`IJTC_ACTION] = `IJTC_DIRECT;
    assign now_RepairAction[`RAS_ACTION] =  isRsFull ? now_RepairAction_m[`RAS_ACTION] : `RAS_NOACTION;
    assign now_RepairAction[`PHT_ACTION] =  now_RepairAction_m[`PHT_ACTION];
    assign now_RepairAction[`NEED_REPAIR] = now_RepairAction_m[`NEED_REPAIR];
endmodule

