/** main.c
 * The core of hewwo. Handles sockets, line-editing, multiplexing input.
 * Passes each line of input (both from the user and from the network) to
 * main.lua.
 */

#include "hewwo.h"
#include "linenoise/linenoise.h"
#include "lua/lauxlib.h"
#include "lua/lualib.h"
#include <assert.h>
#include <errno.h>
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/param.h>
#include <sys/select.h>
#include <sys/wait.h>
#include <unistd.h>

static void cback(char *name, int nresults, const char *arg);

static void in_net(char *s);
static void in_user(char *line);
static void sighandler(int signo);
static void ext_run(void);
static void completion(const char *buf, linenoiseCompletions *lc);

static int l_print(lua_State *L);
static int l_setprompt(lua_State *L);
static int l_writesock(lua_State *L);
static int l_history_add(lua_State *L);
static int l_history_resize(lua_State *L);
static int l_ext_run(lua_State *L);
static int l_ext_eof(lua_State *L);

static struct {
	struct linenoiseState ls;
	lua_State *L;
	int fd;
	char *prompt;
	bool did_print; 

	char *ext_cmd;
	pid_t ext_pid;
	FILE *ext_pipe;
} G;

static const luaL_Reg capi_reg[] = {
	{"print_internal", l_print},
	{"setprompt", l_setprompt},
	{"writesock", l_writesock},
	{"history_add", l_history_add},
	{"history_resize", l_history_resize},
	{"ext_run_internal", l_ext_run},
	{"ext_eof", l_ext_eof},
	{NULL, NULL}
};


static void
cback(char *name, int nresults, const char *arg)
{
	int base = lua_gettop(G.L);
	lua_getglobal(G.L, "debug");
	lua_getfield(G.L, -1, "traceback");
	lua_remove(G.L, -2); /* remove debug from the stack */

	lua_getglobal(G.L, "cback");
	if (lua_getfield(G.L, -1, name) != LUA_TFUNCTION) {
		// TODO that certainly shouldn't be fatal either

		linenoiseEditStop(&G.ls);
		printf("error: cback.%s isn't declared\n", name);
		exit(1);
	}
	lua_remove(G.L, -2); /* remove cback. from the stack */

	if (arg) {
		lua_pushstring(G.L, arg);
	} else {
		lua_pushnil(G.L);
	}
	/* stack:
	 * [base+1] = debug.traceback
	 * [base+2] = function to call
	 * [base+3] = argument
	 */
	assert(lua_gettop(G.L) == base + 3);
	if (lua_pcall(G.L, 1, nresults, base+1) != LUA_OK) {
		linenoiseEditStop(&G.ls);
		// TODO shouldn't always be fatal
		printf("I've hit a Lua error :(\n%s\n", lua_tostring(G.L, -1));
		exit(1);
	}
	/* stack:
	 * [base+1] = debug.traceback
	 * +nresults */
	assert(lua_gettop(G.L) == base + 1 + nresults);
	lua_remove(G.L, base+1);
}

static void
in_net(char *s)
{
	cback("in_net", 0, s);
}

static void
in_user(char *line)
{
	cback("in_user", 0, line);
}

static void
sighandler(int signo)
{
	(void)signo;
}

static void
ext_run(void)
{
	char *cmd = G.ext_cmd;
	int pipefd[2];
	int ret;
	if (G.ext_pid || G.ext_cmd == NULL) return;
	linenoiseHide(&G.ls);

	G.ext_cmd = NULL;
	if (pipe(pipefd) == -1) {
		perror("pipe()");
		return;
	}

	ret = fork();
	if (ret == -1) {
		perror("fork()");
		close(pipefd[0]);
		close(pipefd[1]);
	} else if (ret == 0) {
		dup2(pipefd[0], STDIN_FILENO);
		close(pipefd[1]);
		exit(system(cmd));
	} else {
		G.ext_pid = ret;
		close(pipefd[0]);
		if (G.ext_pipe) fclose(G.ext_pipe);
		G.ext_pipe = fdopen(pipefd[1], "a");
	}
	free(cmd);
}

void
mainloop(const char *host, const char *port)
{
	// TODO merge into main()
	static char lsbuf[512];
	Bufio *bi;
	sigset_t emptyset, blockset;

	/* only handle SIGCHLD during pselect() */
	sigemptyset(&emptyset);
	sigemptyset(&blockset);
	sigaddset(&blockset, SIGCHLD);
	sigprocmask(SIG_BLOCK, &blockset, NULL);

	G.fd = dial(host, port);
	if (G.fd < 0) {
		fprintf(stderr, "couldn't connect to the server at %s:%s :(\n", host, port);
		exit(1);
	}

	bi = bufio_init();
	cback("init", 0, NULL);

	linenoiseEditStart(&G.ls, -1, -1, lsbuf, sizeof lsbuf, G.prompt);
	G.did_print = false;

	for (;;) {
		fd_set rfds;
		int ret;

		FD_ZERO(&rfds);
		if (G.ext_pid == 0) {
			FD_SET(0, &rfds);
		}
		if (G.fd != -1) {
			FD_SET(G.fd, &rfds);
		}
		/* If fd_set is empty, pselect still waits for a signal, as expected.
		 * well, at least on Linux it does. I think that's portable, though. */

		errno = 0;
		ret = pselect(MAX(1, G.fd+1), &rfds, NULL, NULL, NULL, &emptyset);
		if (ret >= 0) {
			if (FD_ISSET(0, &rfds)) {
				char *line = linenoiseEditFeed(&G.ls);
				if (line == linenoiseEditMore) continue;
				linenoiseHide(&G.ls);
				in_user(line);
				linenoiseFree(line);
				linenoiseEditStart(&G.ls, -1, -1, lsbuf, sizeof lsbuf, G.prompt);
			}
			if (G.fd != -1 && FD_ISSET(G.fd, &rfds)) {
				if (bufio_read(bi, G.fd, in_net) == 0) {
					close(G.fd);
					G.fd = -1;
					cback("disconnected", 0, NULL);
				}
			}
		} else if (errno != EINTR) {
			linenoiseEditStop(&G.ls);
			perror("select()");
			exit(1);
		}

		if (G.ext_pid && waitpid(G.ext_pid, NULL, WNOHANG) == G.ext_pid) {
			G.ext_pid = false;
			if (G.ext_pipe) {
				fclose(G.ext_pipe);
			}
			G.ext_pipe = NULL;
			cback("ext_quit", 0, NULL);

			linenoiseShow(&G.ls);
			G.did_print = false;
		}
		if (G.did_print) {
			linenoiseShow(&G.ls);
			G.did_print = false;
		}
		if (G.ext_cmd) {
			ext_run();
		}
	}
}

static void
completion(const char *buf, linenoiseCompletions *lc)
{
	int base = lua_gettop(G.L);
	int len = 0;

	cback("completion", 1, buf);

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

	lua_settop(G.L, base);
}

static int
l_print(lua_State *L)
{
	FILE *fp = stdout;
	/* based on luaB_print */

	if (G.ext_pid) {
		if (G.ext_pipe) {
			fp = G.ext_pipe;
		} else {
			return 0;
		}
	} else {
		if (!G.did_print) {
			linenoiseHide(&G.ls);
			G.did_print = true;
		}
	}

	int n = lua_gettop(L); 
	for (int i = 1; i <= n; i++) {
		size_t l;
		const char *s = luaL_tolstring(L, i, &l);
		if (i > 1) {
			fwrite("\t", 1, 1, fp);
		}
		fwrite(s, 1, l, fp);
		lua_pop(L, 1);
	}
	fwrite("\n", 1, 1, fp);
	fflush(fp);
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
	if (G.fd != -1) {
		dprintf(G.fd, "%s\r\n", s);
	}
	return 0;
}

static int
l_history_add(lua_State *L)
{
	const char *s = luaL_checkstring(L, 1);
	if (s) {
		linenoiseHistoryAdd(s);
	}
	return 0;
}

static int
l_history_resize(lua_State *L)
{
	linenoiseHistorySetMaxLen(luaL_checkinteger(L, 1));
	return 0;
}

static int
l_ext_run(lua_State *L)
{
	G.ext_cmd = strdup(luaL_checkstring(L, 1));
	return 0;
}

static int
l_ext_eof(lua_State *L)
{
	(void)L;
	if (G.ext_pipe) fclose(G.ext_pipe);
	G.ext_pipe = NULL;
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

	{
		struct sigaction sa = {0};
		sa.sa_handler = sighandler;
		if (sigaction(SIGCHLD, &sa, NULL) == -1) {
			perror("sigaction()");
			exit(1);
		}
	}

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
	luaL_newlib(G.L, capi_reg);
	lua_setglobal(G.L, "capi");
	if (luaL_dostring(G.L, "require \"main\"")) {
		printf("I've hit a Lua error :(\n%s\n", lua_tostring(G.L, -1));
		exit(1);
	}

	linenoiseSetCompletionCallback(completion);

	printf("hi! i'm an irc client. please give me a second to connect...\n");
	mainloop(host, port);
	lua_close(G.L);
}
