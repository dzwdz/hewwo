#include "irc.h"
#include "linenoise/linenoise.h"
#include "lua/lauxlib.h"
#include "lua/lualib.h"
#include "net.h"
#include "xdg.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/select.h>

struct {
	struct linenoiseState ls;
	lua_State *L;
	int fd;

	char *prompt;

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
l_callfn(char *name, char *arg)
{
	int base = lua_gettop(G.L);
	lua_getglobal(G.L, "debug");
	lua_getfield(G.L, -1, "traceback");
	lua_remove(G.L, -2); /* remove debug from the stack */

	lua_getglobal(G.L, name);
	lua_pushstring(G.L, arg);
	if (lua_pcall(G.L, 1, 0, base+1) != LUA_OK) {
		linenoiseEditStop(&G.ls);
		// TODO shouldn't always be fatal
		printf("I've hit a Lua error :(\n%s\n", lua_tostring(G.L, -1));
		exit(1);
	}

	lua_settop(G.L, base);
}

static void
in_net(char *s)
{
	l_callfn("in_net", s);
}

static void
in_user(char *line)
{
	l_callfn("in_user", line);
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
	l_callfn("init", "Thank you for playing Wing Commander!");

	linenoiseEditStart(&G.ls, -1, -1, lsbuf, sizeof lsbuf, G.prompt);
	G.did_print = false;

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
			linenoiseEditStart(&G.ls, -1, -1, lsbuf, sizeof lsbuf, G.prompt);
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


static int
l_print(lua_State *L)
{
	/* based on luaB_print */
	if (!G.did_print) {
		linenoiseHide(&G.ls);
		G.did_print = true;
	}

	int n = lua_gettop(L); 
	for (int i = 1; i <= n; i++) {
		size_t l;
		const char *s = luaL_tolstring(L, i, &l);
		if (i > 1) {
			lua_writestring("\t", 1);
		}
		lua_writestring(s, l);
		lua_pop(L, 1);
	}
	lua_writestring("\r\n", 2);
	fflush(stdout);
	return 0;
}

static int
l_setprompt(lua_State *L)
{
	free(G.prompt);
	G.prompt = strdup(lua_tolstring(L, 1, NULL));
	return 0;
}

static int
l_writesock(lua_State *L)
{
	/* automatically inserts the \r\n */
	const char *s = luaL_checkstring(L, 1);
	dprintf(G.fd, "%s\r\n", s);
	return 0;
}

int
main()
{
	G.L = luaL_newstate();
	G.did_print = true;
	G.prompt = strdup(": ");

	luaL_openlibs(G.L);

	/* override package.{c,}path
	 * i want to avoid depending on cwd (and risking executing random code) */
	int base = lua_gettop(G.L);
	lua_getglobal(G.L, "package");
	lua_pushstring(G.L, get_luapath());
	lua_setfield(G.L, -2, "path");
	lua_pushstring(G.L, "");
	lua_setfield(G.L, -2, "cpath");
	lua_settop(G.L, base);

	/* prepare the c/lua interface */
	lua_register(G.L, "print", l_print);
	lua_register(G.L, "setprompt", l_setprompt);
	lua_register(G.L, "writesock", l_writesock);
	if (luaL_dofile(G.L, "main.lua")) {
		printf("I've hit a Lua error :(\n%s\n", lua_tostring(G.L, -1));
		exit(1);
	}

	printf("hi! i'm an irc client. please give me a second to connect...\n");
	mainloop("localhost", "6667");
	lua_close(G.L);
}
