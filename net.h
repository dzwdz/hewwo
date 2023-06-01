#pragma once

int dial(const char *addr, const char *port);

typedef struct Bufio {
	int pos; /* pos == sizeof buf => ignore current line, read until CRLF */
	char buf[1024];
} Bufio;

Bufio *bufio_init(void);
int bufio_read(Bufio *bi, int fd, void (*callback)(const char *s));
