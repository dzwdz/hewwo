CFLAGS = -Wall -Wextra -g

OBJS := main.o \
        net.o \
        xdg.o \
        linenoise/linenoise.o

newbirc: $(OBJS) lua/liblua.a
	$(CC) $(LDFLAGS) -o $@ $^

.PHONY: clean
clean:
	rm -f newbirc $(OBJS)

lua/liblua.a:
	cd lua; make liblua.a
