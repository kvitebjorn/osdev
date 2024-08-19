.option norvc # turn off compressed instructions for qemu

.section .data

welcome: .ascii "Welcome to Noomi's World\n\0"


.section .text.init
.global _start

_start:
	csrr t0, mhartid # get info about hardware threads (aka cores) 
	bnez t0, _wait # wait until we are on the 0 thread 
	call _setup_uart # configure UART in order to write out to the world
	la a0, welcome # prep our arg register for the welcome message
	call _write_uart # write the welcome message 

	wfi 

_setup_uart:
	li t1, 0x10000001 # UART disable interrupts setting (UART+1)
	sb zero, 0(t1) # set disable interrupts
	li t1, 0x10000003 # UART Line Control Register (UART+3)
	li t2, 0x03 # UART setting for 8-bit output
	sb t2, 0(t1) # set UART output to 8-bit mode
	ret

_write_uart:
	li t1, 0x10000000 # UART location
	lb t2, 0(a0) # load the first char into t2
	beqz t2, _write_uart_end # exit if we are at the string's end
	sb t2, 0(t1) # write the char out to UART
	li t2, 1 # 1 for incrementing
	add a0, t2, a0 # increment to the next char position
	j _write_uart # repeat until end of string 

_write_uart_end:

_wait:
	wfi

