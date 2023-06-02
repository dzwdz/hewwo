#pragma once
#include <stdbool.h>

#define RPL_ENDOFMOTD	"376"
#define ERR_NOMOTD	"422"
#define ERR_NICKNAMEINUSE	"433"

typedef struct IRCMsg {
	char *user;
	/* RFC1459 2.3 specifies there may be up to 15 params.
	 * I'm using the first slot for the command. */
	char *argv[16];
	int argc;
} IRCMsg;

/** True on success. */
bool irc_parsemsg(char *s, IRCMsg *im);
