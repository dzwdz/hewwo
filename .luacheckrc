ignore = {
	"212", -- unused arguments
	"432", -- shadowed upvalues
}

globals = {
	"capi",
	"cback",
	"init_config",
	"ext",
	"print",
	"printf",
	"safeinit",
}

files["commands.lua"].ignore = {
	"312", -- value of argument overwritten before use
	"412", -- shadowing argument
}

files["main.lua"].globals = {
	"__config",
}
