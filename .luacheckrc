ignore = {
	"212", -- unused arguments
	"432", -- shadowed upvalues
}

globals = {
	"capi",
	"cback",
	"config",
	"conn",
	"ext",
	"print",
	"printf",
	"safeinit",

-- TODO
	"RPL_LIST",
	"RPL_LISTEND",
	"RPL_TOPIC",
	"RPL_NAMREPLY",
	"RPL_ENDOFMOTD",
	"ERR_NOMOTD",
	"ERR_NICKNAMEINUSE",
}

files["commands.lua"].ignore = {
	"312", -- value of argument overwritten before use
	"412", -- shadowing argument
}
