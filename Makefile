libcofi_rpi.so: memcpy.o memset.o
	$(CC) -o libcofi_rpi.so -shared memcpy.o memset.o -g
memset.o: memset.s
	$(AS) memset.S -o memset.o -g
memcpy.o: memcpy.s
	$(AS) memcpy.S -o memcpy.o -g
