CFLAGS = -Wall -Wextra -Wpedantic -g

OBJS := main.o net.o linenoise/linenoise.o

newbirc: $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $^

.PHONY: clean
clean:
	rm -f newbirc $(OBJS)
