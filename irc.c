#include "irc.h"
#include <string.h>

bool
irc_parsemsg(char *s, IRCMsg *im)
{
	memset(im, 0, sizeof(*im));

	if (*s == ':') {
		im->prefix = s+1;
		while (*s != '\0' && *s != ' ') s++;
		if (*s == '\0') {
			return false;
		}
		*s++ = '\0';
	}

	while (*s && im->argc < 16) {
		if (*s == ':') {
			im->argv[im->argc++] = s + 1;
			break;
		} else {
			im->argv[im->argc++] = s;
			while (*s != '\0' && *s != ' ') {
				s++;
			}
			if (*s == '\0') {
				break;
			}
			*s++ = '\0';
		}
	}
	return true;
}
