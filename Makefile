CFLAGS = -Wall -Wextra -g

OBJS := main.o \
        irc.o \
        net.o \
        linenoise/linenoise.o

newbirc: $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $^

.PHONY: clean
clean:
	rm -f newbirc $(OBJS)
