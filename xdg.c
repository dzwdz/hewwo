/** xdg.c
 * Figures out the potential locations of Lua files (inc. configs).
 * In order of preference:
 * 1. $XDG_CONFIG_HOME/hewwo/edge/
 * 2. /etc/hewwo/edge/
 * 3. the location of the executable
 */

#include "hewwo.h"
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define CFGDIR "/hewwo/edge/"

static char *cpycat(char *dst, const char *src);
static char *cpycatfree(char *dst, const char *src);
static char *lpath_base(char *dst, const char *base);
static char *config_path(void);
static char *exedir(void);

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
		dst = cpycatfree(dst, "?.lua;");
		dst = cpycatfree(dst, base);
		dst = cpycatfree(dst, "?/init.lua;");
	}
	return dst;
}

static char *
config_path(void)
{
	char *base;
	base = getenv("XDG_CONFIG_HOME");
	if (base) {
		return cpycat(base, CFGDIR);
	}
	base = getenv("HOME");
	if (base) {
		return cpycat(base, "/.config" CFGDIR);
	}
	return NULL;
}

static char *
exedir(void)
{
#ifdef __linux__
	static char buf[512];
	ssize_t ret;
	ret = readlink("/proc/self/exe", buf, sizeof buf);
	if (ret <= 0 && ret == sizeof buf) return NULL;
	buf[ret] = '\0';

	char *slash = strrchr(buf, '/');
	if (!slash) return NULL;
	slash[1] = '\0';
	return buf;
#else
	return NULL;
#endif
}

const char *
get_luapath(void)
{
	char *res = strdup("");
	char *cfg_path = config_path();

	res = lpath_base(res, cfg_path);
	res = lpath_base(res, "/etc" CFGDIR);
	res = lpath_base(res, exedir());

	free(cfg_path);
	return res;
}
