CC=$(TARGET_CC)
CFLAGS=$(TARGET_CFLAGS) -Wall -O2 
LDFLAGS=$(TARGET_LDFLAGS)
LIBS=-lSDL2 -lSDL2_image
OBJECTS=main.o

all: trezor-emu

trezor-emu: $(OBJECTS)
	$(CC) $(OBJECTS) -o trezor-emu $(LIBS) $(LDFLAGS)

main.o: main.c
	$(CC) $(CFLAGS) -c main.c

clean:
	rm -f $(OBJECTS) trezor-emu