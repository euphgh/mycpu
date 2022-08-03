	.file	1 "hello.c"
	.section .mdebug.abi32
	.previous
	.gnu_attribute 4, 1
	.abicalls
	.text
	.align	2
	.globl	test1
	.ent	test1
	.type	test1, @function
test1:
	.set	nomips16
	.frame	$fp,32,$31		# vars= 16, regs= 1/0, args= 0, gp= 8
	.mask	0x40000000,-4
	.fmask	0x00000000,0
	.set	noreorder
	.set	nomacro
	
	addiu	$sp,$sp,-32
	sw	$fp,28($sp)
	move	$fp,$sp
	.cprestore	0
	sw	$4,32($fp)
	sw	$0,16($fp)
	sw	$0,12($fp)
	sw	$0,8($fp)
	sw	$0,12($fp)
	b	$L2
	nop

$L5:
	sw	$0,8($fp)
	b	$L3
	nop

$L4:
	lw	$2,16($fp)
	nop
	addiu	$2,$2,1
	sw	$2,16($fp)
	lw	$2,8($fp)
	nop
	addiu	$2,$2,1
	sw	$2,8($fp)
$L3:
	lw	$2,8($fp)
	nop
	slt	$2,$2,2
	bne	$2,$0,$L4
	nop

	lw	$2,12($fp)
	nop
	addiu	$2,$2,1
	sw	$2,12($fp)
$L2:
	lw	$2,12($fp)
	lw	$3,32($fp)
	nop
	slt	$2,$2,$3
	bne	$2,$0,$L5
	nop

	lw	$2,16($fp)
	move	$sp,$fp
	lw	$fp,28($sp)
	addiu	$sp,$sp,32
	j	$31
	nop

	.set	macro
	.set	reorder
	.end	test1
	.align	2
	.globl	main
	.ent	main
	.type	main, @function
main:
	.set	nomips16
	.frame	$fp,56,$31		# vars= 16, regs= 3/0, args= 16, gp= 8
	.mask	0xc0010000,-4
	.fmask	0x00000000,0
	.set	noreorder
	.set	nomacro
	
	addiu	$sp,$sp,-56
	sw	$31,52($sp)
	sw	$fp,48($sp)
	sw	$16,44($sp)
	move	$fp,$sp
	.cprestore	16
	li	$4,7			# 0x7
	.option	pic0
	jal	test1
	nop

	.option	pic2
	lw	$28,16($fp)
	move	$16,$2
	li	$4,3			# 0x3
	.option	pic0
	jal	test1
	nop

	.option	pic2
	lw	$28,16($fp)
	addu	$2,$16,$2
	sw	$2,24($fp)
	move	$sp,$fp
	lw	$31,52($sp)
	lw	$fp,48($sp)
	lw	$16,44($sp)
	addiu	$sp,$sp,56
	j	$31
	nop

	.set	macro
	.set	reorder
	.end	main
	.ident	"GCC: (GNU) 4.3.0"
