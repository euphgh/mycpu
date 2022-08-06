## ICACHE

### 1.结构

128行，每行8*32，4路，一次性返回4条指令，地址cpu给的时候就不给低四位，所以只会命中每行的前半行或者后半行

三段流水，两组段间寄存器

-   以sin\_开头的信号，为连接接口的信号，重点是对输入的index做了个切分
-   以sta\_开头的信号，为在时钟上升沿保存的sin\_信号，以及部分连接接口的信号
-   以sda\_开头的信号，为在时钟上升沿保存的sta\_信号，以及部分由子模块返回的数据

### 2.代码结构

1.   与CPU的接口信号

2.   sta_hit_way后面讲

3.   驱动inst_uncache的信号

4.   axi交互信号

5.   sin部分的信号处理

6.   sta部分的信号处理

7.   sda部分的信号处理

8.   cache主状态机

     状态的说明在代码中有

9.   reset部分

10.   refill部分

11.   判断是否命中部分

12.   sda段需要的命中信号处理

13.   tagv模块控制信号

14.   data模块控制信号

15.   plru

16.   cacheop控制

### 3. cache行为

从重置开始，先做128个周期的清除tag有效位的操作，然后经过一个周期的idle状态，进入run状态。

先说和cpu的交互，cpu第一拍给index和req，cache给indexok，第二拍给tag，uncache，hasExce信号，cache不用给反应，第三拍cache给dataok和rdata即可

正常发生命中的行为：

1.   sin段收到req，判断自己可以接受请求（sda段请求完成或者sda没有请求，就可以流入请求额），同周期拉高indexok，在此过程中，将index传给tagv和data模块，让他们在这个周期取数据和tagv
2.   第二拍，sta接受了sin的信号，以及来自tagv和data的数据，可以判断是否命中了，这就是sta_hit_way的作用，具体的判断包括两部分，正常命中就是cache处于run状态，且sta_tag与tagvback符号，就是命中了，另一种情况是IDLE状态下，等下讲
     命中信息，和命中数据（sta_hit_run_data，名字应该改一下的）都选择出来，直接传给下一段，这样做是为了提高频率，如果最后一段再选择数据，路径比较长
3.   第三拍，sda接收sta的信号，检查uncache和exception信号，命中信号，如果命中，且无异常，就可以拉高data_ok了。数据直接用sda_back_data。

如果不命中的行为：

1.   在上面第二拍的时候可以知道发生不命中了，这个信号会传给第三拍。第三拍拿着这个结果，和保存下来的地址信息（sda开头的地址信息），开始访存，cache进入miss状态，接下来基本上都是sda打头的信息在工作，所以我保留了四路全部的tag和data，因为dcache写回被替换行的时候得用，icache可能用不到

2.   fill整个状态接收到的数据都保存到fill\_buf\_data中，用fill\_buf\_valid指出是否有效，装回到data模块的事情，只在finish周期做，改写tag也是finish状态改

3.   最不同的一点是FINISH状态后，我这里需要加一个状态，来恢复到正常工作状态

     -   RECOVER：向两个模块请求sda保存的地址的数据
     -   IDLE：==向两个模块请求sta保存的地址的数据==，sta_hit_way在这个时候会指出recover状态取出的数据是否命中。
     -   RUN状态：RECOVER请求的数据已经装到sad_back_data中了，可以返回
     -   下一个RUN状态：恢复正常，这时sda的数据是IDLE状态下读出来的。

     所以恢复的过程不太一样

uncache行为：

1.   uncache信号在第二拍给出，第二拍时会请求uncache模块执行，然后流入sda段，等待数据返回，比较简单

cacheop：

1.   执行流程基本同代昆学长，只是我在做完操作之后才会拉高icache_ok，icache不涉及对data的读写，所以没有数据的事，操作tag就行，II，IST之类的缩写就是书上写的指令的每个单词的第一个字母，应该不会太难懂

### 4. 部分注意的问题

tagv模块，data模块，输入的信号比较复杂，稍微注意一下，要是看不懂是干嘛的，就问我

能看到的wire 和reg不在最前面声明的，都是我后加的，没时间改了，有空可以改名和提前。

## DCACHE

流程基本一致，说说不同的地方

1.   和cpu的交互，cpu第一拍给index和req，cache给indexok，**==第二拍给tag，uncache，hasExce信号，cache给dataok，第三拍cache给rdata即可。注意，和icache不同==**

2.   所以dataok是根据icache中的sta_hit_way给的，需要注意一下，这部分我写的比较着急，可能有容易，也比较复杂

3.   因为dataok需要早一周期给，而uncache没收到数据给不了dataok，只能锁一拍。就是uca_ok。

4.   sda_data_ok是给自己内部控制用的，相当于icache那边的dataok，不然不好控制，这个信号必须所有的行为都比data_data_ok晚一周期并且一致。这点需要注意

5.   很多信号都是为了提前比对tag增加的。

6.   有个写后读的问题

     因为三拍，存在两种写后读的问题

     1.   sda和sin存在，这个时候sin读出的数据是经过处理的，就是data模块内部处理，逻辑和上次代昆和你讲的一样

     2.   sda和sta存在，这个时候sta将要给的数据需要根据wstrb来选择有效的数据返回，我这边的体现是

          ```verilog
           sda_raw_col      <= (sta_index == sda_index) && 
          (sta_offset[4:2] == sda_offset[4:2]) &&
          (sta_tag == sta_tag) && sda_wr;
          sda_raw_wstrb    <= sda_wstrb;
          sda_raw_data[0]  <= {8{sda_wstrb[0]}} & sda_wdata[7 : 0];
          sda_raw_data[1]  <= {8{sda_wstrb[1]}} & sda_wdata[15: 8];
          sda_raw_data[2]  <= {8{sda_wstrb[2]}} & sda_wdata[23:16];
          sda_raw_data[3]  <= {8{sda_wstrb[3]}} & sda_wdata[31:24];
          ```

          以及data_rdata那边简单的处理
     
     3.   写cache操作的操作在sda段完成。因为用的双端口，这个不是什么大问题
     
     4.   写cache数据操作只有run状态下和finish状态下存在，没有交集，所以写使能我用了位或，应该不会出问题
     
     5.   dirty处理，只有命中以及写操作可以置1，其他情况只用不改
     
     6.   victim_stat 控制写回axi的状态，也很简单，看一下就明白了。我这里不管写不写都先把数据和地址存下来了。真的要写就从存下来的数据和地址来控制
     
     7.   ok_send_arv：这个信号我拿来控制axi读，我希望读写不冲突，而且最开始写的时候限制的比较死，只要写的时候就不能读，所以是这个样子，后来也没改
     
     8.   其他没啥了。

有问题问我。

