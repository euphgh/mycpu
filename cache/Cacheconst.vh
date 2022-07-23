//MAIN FSM
`define IDLE    4'b0000
`define RUN     4'b0001
`define MISS    4'b0010
`define REFILL  4'b0011
`define FINISH  4'b0100
`define RECOVER 4'b0101
`define RESET   4'b1111
//CACHE_OP_STATE 
`define CA_SEL  4'b0110
`define CA_OP   4'b0111
`define CA_WB   4'b1000
//DCACHE_OP_CODE
`define DC_IWI  5'b00001
`define DC_IST  5'b01001
`define DC_HI   5'b10001
`define DC_HWI  5'b10101
//ICACHE_OP_CODE
`define IC_II   5'b00000
`define IC_IST  5'b01000
`define IC_HI   5'b10000
//PIPELINE
`define PIPELINE_RUN   1'b1
`define PIPELINE_IDLE  1'b0
//WRITE BUFFER
`define WB_IDLE  4'b0000
`define WB_WRITE 4'b0001
//VICTIM BUFFER
`define VIC_IDLE   4'b0000
`define VIC_MISS   4'b0001
`define VIC_AWRITE 4'b0010
`define VIC_WRITE  4'b0100
`define VIC_RES    4'b0101