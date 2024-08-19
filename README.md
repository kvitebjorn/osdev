Compilation Step: riscv64-unknown-elf-as boot.S -o boot.o

Linking Step: riscv64-unknown-elf-ld -T kernel.lds boot.o -o kernel.elf

qemu command: qemu-system-riscv64 -machine virt -cpu rv64 -smp 4 -m 128M -nographic -serial mon:stdio -bios none -kernel kernel.elf
