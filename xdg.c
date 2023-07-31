/** xdg.c
 * Figures out the potential locations of Lua files (inc. configs).
 */

#include "config.h"
#include "hewwo.h"
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static char *cpycat(char *dst, const char *src);
static char *cpycatfree(char *dst, const char *src);
static char *lpath_base(char *dst, const char *base);
static char *config_path(void);

static char *
cpycat(char *dst, const char *src)
{
	char *new = malloc(strlen(dst) + strlen(src) + 1);
	if (!new) return NULL;
	strcpy(new, dst);
	strcat(new, src);
	return new;
}

static char *
cpycatfree(char *dst, const char *src)
{
	char *new = cpycat(dst, src);
	free(dst);
	return new;
}

static char *
lpath_base(char *dst, const char *base)
{
	if (base) {
		dst = cpycatfree(dst, base);
		dst = cpycatfree(dst, "/?.lua;");
		dst = cpycatfree(dst, base);
		dst = cpycatfree(dst, "/?/init.lua;");
	}
	return dst;
}

static char *
config_path(void)
{
	char *base;
	base = getenv("XDG_CONFIG_HOME");
	if (base) {
		return cpycat(base, LUADIR_LOCAL);
	}
	base = getenv("HOME");
	if (base) {
		return cpycat(base, "/.config" LUADIR_LOCAL);
	}
	return NULL;
}

const char *
get_luapath(void)
{
	char *res = strdup("");
	char *cfg_path = config_path();

	res = lpath_base(res, config_path());
	res = lpath_base(res, LUADIR_GLOBAL);

	free(cfg_path);
	return res;
}
