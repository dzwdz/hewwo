/** main.c
 * The core of hewwo. Handles sockets, line-editing, multiplexing input.
 * Passes each line of input (both from the user and from the network) to
 * main.lua.
 */

#include "linenoise/linenoise.h"
#include "lua/lauxlib.h"
#include "lua/lualib.h"
#include "hewwo.h"
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/select.h>

struct {
	struct linenoiseState ls;
	lua_State *L;
	int fd;
	char *prompt;
	bool did_print; 
} G;

// general TODO: connection state machine

static void
l_callfn(char *name, char *arg)
{
	int base = lua_gettop(G.L);
	lua_getglobal(G.L, "debug");
	lua_getfield(G.L, -1, "traceback");
	lua_remove(G.L, -2); /* remove debug from the stack */

	lua_getglobal(G.L, name);
	if (arg) {
		lua_pushstring(G.L, arg);
	} else {
		lua_pushnil(G.L);
	}
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
	l_callfn("init", NULL);

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
			linenoiseEditStopSilent(&G.ls);
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

static void
completion(const char *buf, linenoiseCompletions *lc)
{
	int base = lua_gettop(G.L);
	lua_getglobal(G.L, "debug");
	lua_getfield(G.L, -1, "traceback");
	lua_remove(G.L, -2); /* remove debug from the stack */

	if (lua_getglobal(G.L, "completion") == LUA_TFUNCTION) {
		lua_pushstring(G.L, buf);
		if (lua_pcall(G.L, 1, 1, base+1) == LUA_OK) {
			int len = 0;
			if (!lua_isnil(G.L, -1)) {
				luaL_checktype(G.L, -1, LUA_TTABLE);
				len = luaL_len(G.L, -1);
				for (int i = 1; i <= len; i++) {
					lua_geti(G.L, -1, i);
					linenoiseAddCompletion(lc, lua_tostring(G.L, -1));
					lua_pop(G.L, 1);
				}
			}
			if (len == 0) {
				/* required to prevent raw tabs from getting inserted */
				linenoiseAddCompletion(lc, buf);
			}
		} else {
			linenoiseEditStop(&G.ls);
			// TODO shouldn't be fatal
			printf("I've hit a Lua error :(\n%s\n", lua_tostring(G.L, -1));
			exit(1);
		}
	}

	lua_settop(G.L, base);
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
	const char *arg = lua_tolstring(L, 1, NULL);
	char *copy;
	if (strcmp(arg, G.prompt) == 0) {
		return 0;
	}
	copy = strdup(arg);

	linenoiseHide(&G.ls);
	free(G.prompt);
	G.prompt = copy;
	G.ls.prompt = copy;
	G.ls.plen = strlen(copy);
	linenoiseShow(&G.ls);
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
main(int argc, char **argv)
{
	const char *host = "localhost", *port = "6667";
	if (1 < argc) host = argv[1];
	if (2 < argc) port = argv[2];
	if (3 < argc) {
		fprintf(stderr, "usage: hewwo [host] [port]\nhint: you've used too many arguments\n");
		return 1;
	}

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
	if (luaL_dostring(G.L, "require \"main\"")) {
		printf("I've hit a Lua error :(\n%s\n", lua_tostring(G.L, -1));
		exit(1);
	}

	linenoiseSetCompletionCallback(completion);

	printf("hi! i'm an irc client. please give me a second to connect...\n");
	mainloop(host, port);
	lua_close(G.L);
}
