.option norvc # turn off compressed instructions for qemu

.section .data

welcome: .ascii "Welcome to Noomi's World!\n\0"
iamhart: .ascii "I am HART \0"
newline: .ascii "\n\0"

_hartlock:
	.skip 1,0

_scratchpad:
	.skip 1024,0

.section .text.init
.global _start

_start:
	csrr t0, mhartid # get info about hardware threads (aka cores) 
	bnez t0, _announce # wait until we are on the 0 thread 

	call _setup_uart # configure UART in order to write out to the world

	la a0, welcome # prep our arg register for the welcome message
	call _write_uart # write the welcome message 

	j _announce

	wfi 

# a0 should contain the address of string to print
# writeln will write this string to the serial UART device,
#   followed by a newline
_writeln:
	mv s0, ra # save return address since we do a `call` ourselves
	call _write_uart
	la a0, newline
	call _write_uart
	mv ra, s0 # set the return address back to what it was
	ret

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
	ret

_announce:
	la t0, _hartlock
	lb t0, 0(t0)
	csrr t1, mhartid
	bne t0, t1, _announce

	la a0, iamhart
	call _write_uart

	csrr t0, mhartid
	li t1, 0x30
	add t0, t1, t0
	la a0, _scratchpad
	sb t0, 0(a0)
	call _writeln 
	
	csrr t0, mhartid
	li t1, 0x01
	add t1, t0, t1
	la t2, _hartlock
	sw t1, 0(t2)

	fence
	
	j _wait

_wait:
	wfi

