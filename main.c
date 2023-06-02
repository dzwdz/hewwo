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

	char *cur_chan;
	char *nick;

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

// general TODO: connection state machine

static void
in_net(char *s)
{
	IRCMsg im;
	char *cmd;
	// lnprintf("<= %s\r\n", s);

	if (!irc_parsemsg(s, &im)) return;
	cmd = im.argv[0];

	if (!strcmp(cmd, RPL_ENDOFMOTD) || !strcmp(cmd, ERR_NOMOTD)) {
		lnprintf("ok, i'm connected!\r\n");
	} else if (cmd[0] == '4') {
		// TODO the user should never see this, there should be friendly
		// strings for all errors
		lnprintf("IRC error: %s\r\n", im.argv[im.argc-1]);
	} else if (!strcmp(cmd, "PRIVMSG")) {
		if (!strcmp(im.argv[1], G.cur_chan)) {
			lnprintf("<%s> %s\r\n", im.user, im.argv[2]);
		}
	} else if (!strcmp(cmd, "JOIN") && !strcmp(im.argv[1], G.cur_chan)) {
		lnprintf("--> %s has joined %s\r\n", im.user, im.argv[1]);
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
			// TODO store old nick in case of failure
			free(G.nick);
			G.nick = strdup(args);
			dprintf(G.fd, "NICK %s\r\n", args);
		} else if (!strcmp(cmd, "join")) {
			dprintf(G.fd, "JOIN %s\r\n", args);
			free(G.cur_chan);
			G.cur_chan = strdup(args);
		} else {
			lnprintf("unknown command \"%s\" :(\r\n", cmd);
		}
	} else if (!G.cur_chan) {
		lnprintf("you need to /join a channel before chatting\r\n");
	} else {
		// TODO validate chan connection / name
		lnprintf("<%s> %s\r\n", G.nick, line);
		dprintf(G.fd, "PRIVMSG %s :%s\r\n", G.cur_chan, line);
	}
}

const char *
get_prompt(void)
{
	static char *prompt = NULL;
	const char *chan = G.cur_chan ? G.cur_chan : "[server]";

	free(prompt);
	prompt = malloc(strlen(chan) + 3);
	strcpy(prompt, chan);
	strcat(prompt, ": ");
	return prompt;
}

void
mainloop(const char *host, const char *port)
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
	dprintf(G.fd, "NICK %s\r\n", G.nick);

	linenoiseEditStart(&G.ls, -1, -1, lsbuf, sizeof lsbuf, get_prompt());

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
			linenoiseEditStart(&G.ls, -1, -1, lsbuf, sizeof lsbuf, get_prompt());
		}
		if (FD_ISSET(G.fd, &rfds)) {
			bufio_read(bi, G.fd, in_net);
		}
		if (G.did_print) {
			linenoiseShow(&G.ls);
			G.did_print = false;
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
	G.nick = strdup(username);

	printf("hi! i'm an irc client. please give me a second to connect...\n");
	mainloop("localhost", "6667");
}
