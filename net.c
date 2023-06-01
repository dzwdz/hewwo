#include "net.h"
#include <arpa/inet.h>
#include <assert.h>
#include <netdb.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>

int
dial(const char *addr, const char *port)
{
	/* Basically just the example from Beej. */
	struct addrinfo hints, *servinfo, *it;
	int fd;

	memset(&hints, 0, sizeof(hints));
	hints.ai_family = AF_UNSPEC;
	hints.ai_socktype = SOCK_STREAM;

	if (getaddrinfo(addr, port, &hints, &servinfo) != 0) {
		return -1;
	}

	for (it = servinfo; it; it = it->ai_next) {
		fd = socket(it->ai_family, it->ai_socktype, it->ai_protocol);
		if (fd < 0) {
			continue;
		}
		if (connect(fd, it->ai_addr, it->ai_addrlen) == -1) {
			close(fd);
			continue;
		}
		return fd;
	}

	return -2;
}

Bufio *
bufio_init(void)
{
	return calloc(1, sizeof(Bufio));
}

int
bufio_read(Bufio *bi, int fd, void (*callback)(const char *s))
{
	assert(memchr(bi->buf, '\r', bi->pos) == NULL);

	int toread = sizeof(bi->buf) - bi->pos;
	if (toread <= 0) {
		// TODO
	}

	int ret = read(fd, bi->buf + bi->pos, toread);
	if (ret < 0) return ret;
	bi->pos += ret;

	for (;;) {
		char *cr = memchr(bi->buf, '\r', bi->pos);
		if (!cr) break;

		*cr = '\0';
		char *s = bi->buf;
		if (*s == '\n') s++;
		callback(s);

		int len = cr+1 - bi->buf; /* include NUL */
		memmove(bi->buf, cr+1, bi->pos - len);
		bi->pos -= len;
	}
	return ret;
}
