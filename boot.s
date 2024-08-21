.option norvc # turn off compressed instructions for qemu

.section .data

welcome: .ascii "Welcome to Noomi's World!\n\0" # Noomi my dog's name lol
iamhart: .ascii "I am HART \0"
newline: .ascii "\n\0"
machinemode: .ascii "Mode: Machine\0"
interrupts_status: .ascii "Interrupts: "

_hartlock:
	.skip 1,0

_scratchpad:
	.skip 1024,0

_stacks:
	.skip 8192,0 # 8 cores supported, this space is used no matter what

.section .text.init
.global _start

_start:
	csrr t0, mhartid # get info about hardware threads (aka cores) 

	la t1, _stacks # set up stack for each hart
	li t2, 1024 # each hart gets 1024 bytes
	mul t3, t0, t2 # calculate this hart's starting point in the stack 
	add sp, t3, t1 # initialize stack pointer to starting point for hart

	csrr t0, mhartid
	bnez t0, _announce # wait until we are on the 0 thread 

	call _setup_uart # configure UART in order to write out to the world
	la a0, welcome # prep our arg register for the welcome message
	call _write_uart # write the welcome message 

	call _sanity_check # check machine status mode
	j _announce # announce our HART ID

	wfi 

.macro push
	sd ra, 0(sp) # push our ra onto the stack
	add sp, sp, 8 # increment the stack pointer
.endm

.macro pop
	add sp, sp, -8 # decrement the stack pointer
	ld ra, 0(sp) # pop the stack pointer into our return address
.endm

_sanity_check:
	push
	csrr t0, mstatus # read the machine status register
	li t1, 0xC00 # MPP is bits 11-12, so we need this mask for AND'ing 
	and t0, t1, t2 # it will be non-zero if we are in machine mode
	beq t1, t2, _sanity_check_end # if we aren't in machine mode, end
	la a0, machinemode # otherwise point to our machine mode string
	call _writeln # write the machine mode string	

_sanity_check_interrupts:
	csrr t0, mstatus
	la a0, interrupts_status 
	call _write_uart

	li t1, 0x8 # MIE is bit 4, so we need this mask for AND'ing 
	and t0, t1, t2 # isolate the bits we want
	li t3, 0x30 # '0'
	srai t2, t2, 3 # shift to get the actual number
	add t1, t2, t3 # calculate our ASCII number, offset from '0'
	la a0, _scratchpad # point to our scratchpad
	sb t1, 0(a0) # store this char in our scratchpad
	call _writeln # write it out

_sanity_check_end:
	pop
	ret

# a0 should contain the address of string to print
# writeln will write this string to the serial UART device + a newline
_writeln:
	push
	call _write_uart # write the contents of a0 out
	la a0, newline # point to our newline
	call _write_uart # write out newline out
	pop
	ret

_setup_uart:
	li t1, 0x10000001 # UART disable interrupts setting (UART+1)
	sb zero, 0(t1) # set disable interrupts
	li t1, 0x10000003 # UART Line Control Register (UART+3)
	li t2, 0x03 # UART setting for 8-bit output
	sb t2, 0(t1) # set UART output to 8-bit mode
	ret

_write_uart:
	push

_write_uart_loop:
	li t1, 0x10000000 # UART location
	lb t2, 0(a0) # load the first char into t2
	beqz t2, _write_uart_end # exit if we are at the string's end
	sb t2, 0(t1) # write the char out to UART
	li t2, 1 # 1 for incrementing
	add a0, t2, a0 # increment to the next char position
	j _write_uart_loop # repeat until end of string 

_write_uart_end:
	pop
	ret

_announce:
	la t0, _hartlock # point to our HART lock space
	lb t0, 0(t0) # get the current HART lock value
	csrr t1, mhartid # get the current HART ID
	bne t0, t1, _announce # loop until we are on the HART ID we want

	la a0, iamhart # point to our hart message
	call _write_uart # write out our hart message

	csrr t0, mhartid # our registers aren't guaranteed to persist, so...
	li t1, 0x30 # add 0x30 to get the ASCII for our HART ID
	add t0, t1, t0 # compute the HART ID ASCII
	la a0, _scratchpad # point to our scratchpad
	sb t0, 0(a0) # store the HART ID in the scratchpad
	call _writeln # write out our HART ID from the scratchpad
	
	csrr t0, mhartid # get the hart id again for incrementing
	li t1, 0x01 # load a 1 in order to increment our HART lock
	add t1, t0, t1 # add the 1 to our current HART ID
	la t2, _hartlock # point to our HART lock space
	sw t1, 0(t2) # store the new HART ID into our lock that we stop on

	j _wait # done

_wait:
	wfi

