all:
	@mkdir -p ../lib ../include
	zig build-lib src/main.zig -lc -lenet -femit-h=../include/hermes.h -femit-bin=../lib/libhermes.a

clean:
	rm -f ../lib/libhermes.a ../include/hermes.h
	rm -rf zig-cache zig-out
