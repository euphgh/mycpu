# DCACHE and ICACHE
1. 如果不使用测试代码，不需要定制ip核
2. 各文件说明
   1. - `/rtl/coe/axi_ram.coe` 测试用内容初始化文件，同比赛提供
   2. - `/rtl/sim/trace/dc_op.txt` 测试`dcacheop`时使用的指令序列
      - `/rtl/sim/trace/ic_op.txt` 测试`icacheop`时使用的指令序列
      - `/rtl/sim/trace/golden_trace_dcache_1.txt` 测试`dcache`行为的访存序列
      - `/rtl/sim/trace/golden_trace_dcache_2.txt` 测试`dcache`行为的访存序列
      - `/rtl/sim/trace/golden_trace_icache_1.txt` 测试`icache`行为的访存序列
      - `/rtl/sim/trace/golden_trace_icache_2.txt` 测试`icache`行为的访存序列
      - `/rtl/sim/cache_tb_tp.v` 不正确的代码，未作处理
      - `/rtl/sim/dc_op_tb.v` 测试`dcache_op`的代码
      - `/rtl/sim/dc_tb.v` 测试不含`dcache_op`的`dcache`访存的代码
      - `/rtl/sim/ic_op_tp.v` 测试`icache_op`的代码
      - `/rtl/sim/ic_tb.v` 测试不含`icache_op`的`dcache`访存的代码
      - `/rtl/sim/ic_ft_tb.v` 测试`ic_ft.v`模块的代码
   3. - `/rtl/src/cache_data_tp.v` 已不使用
      - `/rtl/src/cache_tagv_tp.v` 已不使用
      - `/rtl/src/Cacheconst.vh` 部分宏定义
      - `/rtl/src/data_data_tp.v` `dcache`使用的`bram`
      - `/rtl/src/data_tagv_tp.v` `dcache`使用的`tagv`模块
      - `/rtl/src/data_uncache.v` 处理由`dcache`发出的`uncache`访存命令
      - `/rtl/src/dcache_tp.v` `dcache`主模块
      - `/rtl/src/ic_ft.v` 仅用作测试的`icache`模块
      - `/rtl/src/inst_data_tp.v` `icache`使用的`bram`
      - `/rtl/src/inst_tagv_tp.v` `icache`使用的`tagv`模块
      - `/rtl/src/inst_uncache.v` 处理由`icache`发出的`uncache`访存命令
      - `/rtl/src/icache_tp.v` `icache`主模块 
3. 使用说明
   
   如果不使用cacheop等功能，在icache和dcache主模块最上方的宏定义处注释掉以下部分
   ```
   `define EN_ICACHE_OP
   `define EN_DCACHE_OP
   ```
   当不使用以上功能，连线方式可以参考`dc_tb.v`和`ic_tb.v`.若加入cacheop,连线方式参考`dc_op_tb.v`和`ic_op_tb.v`

   `dc_tb.v`中使用了一个axi_crossbar的ip核，我估计后面会使用到1x4的转接桥，这部分连线可以参考学长提供的dumptrace中mycpu_top.v的连线方式

