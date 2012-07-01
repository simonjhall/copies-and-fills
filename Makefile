libcofi_rpi.so: memcpy.o memset.o
	$(CC) -o libcofi_rpi.so -shared memcpy.o memset.o -g
memset.o: memset.s
	$(AS) memset.s -o memset.o -g
memcpy.o: memcpy.s
	$(AS) memcpy.s -o memcpy.o -g
