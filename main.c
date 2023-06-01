#include "irc.h"
#include "linenoise/linenoise.h"
#include "net.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sys/select.h>

struct {
	struct linenoiseState ls;
	int fd;

	bool did_print; /* for lnprintf */
} G;

// Could be achieved without a macro. I don't care.
#define lnprintf(...) ({\
	if (!G.did_print) {\
		linenoiseHide(&G.ls);\
		G.did_print = true;\
	}\
	printf(__VA_ARGS__);\
})

static void
in_net(char *s)
{
	IRCMsg im;
	char *cmd;
	lnprintf("<= %s\r\n", s);

	if (!irc_parsemsg(s, &im)) return;
	cmd = im.argv[0];

	if (!strcmp(cmd, RPL_ENDOFMOTD) || !strcmp(cmd, ERR_NOMOTD)) {
		lnprintf("ok, i'm connected!\r\n");
	} else if (cmd[0] == '4') {
		// TODO the user should never see this, there should be friendly
		// strings for all errors
		lnprintf("IRC error: %s\r\n", im.argv[im.argc-1]);
	}


	if (G.did_print) {
		linenoiseShow(&G.ls);
		G.did_print = false;
	}
}

static void
in_user(char *line)
{
	if (line[0] == '/') {
		char *cmd = line+1;
		char *args = strchr(cmd, ' ');
		if (args) *args++ = '\0';

		if (!strcmp(cmd, "nick")) {
			dprintf(G.fd, "NICK %s\r\n", args);
		} else if (!strcmp(cmd, "join")) {
			dprintf(G.fd, "JOIN %s\r\n", args);
		} else {
			printf("unknown command \"%s\" :(\r\n", cmd);
		}
	} else {
		printf("=> %s\r\n", line);
		dprintf(G.fd, "%s\r\n", line);
	}
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
	char *username = getenv("USER");
	if (username == NULL) {
		username = "townie";
	}

	printf("hi! i'm an irc client. please give me a second to connect...\n");
	mainloop("localhost", "6667", username);
}
