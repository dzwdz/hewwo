#include "linenoise/linenoise.h"
#include "net.h"
#include <stdio.h>
#include <stdlib.h>
#include <sys/select.h>

struct {
	struct linenoiseState ls;
	int fd;
} G;

static void
in_net(const char *s)
{
	linenoiseHide(&G.ls);
	puts(s);
	fflush(stdout);
	linenoiseShow(&G.ls);
}

static void
in_user(const char *line)
{
	printf("you: %s\r\n", line);
	dprintf(G.fd, "%s\r\n", line);
}

void
mainloop(const char *host, const char *port, const char *username)
{
	static char lsbuf[512];
	Bufio *bi;

	G.fd = dial(host, port);
	if (G.fd < 0) {
		fprintf(stderr, "couldn't connect to the server at %s:%s :(\n", host, port);
		exit(1);
	}

	bi = bufio_init();
	dprintf(G.fd, "USER username hostname svname :Real Name\r\n");
	dprintf(G.fd, "NICK %s\r\n", username);

	linenoiseEditStart(&G.ls, -1, -1, lsbuf, sizeof lsbuf, ": ");

	for (;;) {
		fd_set rfds;
		int ret;

		FD_ZERO(&rfds);
		FD_SET(0, &rfds);
		FD_SET(G.fd, &rfds);

		ret = select(G.fd+1, &rfds, NULL, NULL, NULL);
		if (ret == -1) {
			linenoiseEditStop(&G.ls);
			perror("select()");
			exit(1);
		}
		if (FD_ISSET(0, &rfds)) {
			char *line = linenoiseEditFeed(&G.ls);
			if (line == linenoiseEditMore) continue;
			linenoiseHide(&G.ls);
			if (line == NULL) {
				linenoiseEditStop(&G.ls);
				exit(0);
			}
			in_user(line);
			linenoiseFree(line);
			linenoiseEditStart(&G.ls, -1, -1, lsbuf, sizeof lsbuf, ": ");
		}
		if (FD_ISSET(G.fd, &rfds)) {
			bufio_read(bi, G.fd, in_net);
		}
	}
}

int
main()
{
	printf("hi! i'm an irc client. please give me a second to connect...\n");
	mainloop("localhost", "6667", "newbirc");
}
