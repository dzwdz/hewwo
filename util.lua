local util = safeinit(...)

local i18n = require "i18n"
local tests = require "tests"

function util.djb2(s)
	local hash = 5381|0
	for _,c in ipairs({string.byte(s, 1, -1)}) do
		hash = hash * 31 + c
	end
	return hash
end

-- for mentions
function util.nick_pattern(nick)
	-- TODO only works with alphanumeric nicks
	return "%f[%w]"..nick.."%f[^%w]"
end

function util.file_exists(path)
	local f = io.open(path)
	if f then
		f:close()
		return true
	else
		return false
	end
end

-- Takes a character-wise substring, preserving any original formatting.
-- TODO move to ui?
function util.visub(str, from, to)
	if from ~= 0 then error("unimplemented") end

	local i = 1
	local len = string.len(str)
	local res = ""
	-- TODO table.concat could be better for performance here
	local vlen = 0
	local utf8p = "("..utf8.charpattern..")"
	while i <= len do
		-- TODO factor out the escape code pattern into a global
		-- it's also used by ui.strip_ansi
		local a, b, match = string.find(str, "^(\x1b%[[^\x40-\x7E]*[\x40-\x7E])", i)
		if a then
			i = b+1
			res = res..match
		else
			a, b, match = string.find(str, utf8p, i)
			if not a then break end
			-- if a ~= i, whatever, pretend everything is fine anyways
			i = b+1
			if vlen < to then
				res = res..match
			end
			vlen = vlen + 1
		end
	end
	return res, vlen
end
tests.run(function(t)
	local vs = util.visub
	t(vs("\x1b[3m12345678\x1b[m", 0, 4), "\x1b[3m1234\x1b[m")
	t(vs("\x1b[3mąęźć\x1b[m", 0, 2), "\x1b[3mąę\x1b[m")
	t(vs("\x1b[3ma\x1b[mb\x1b[3mc\x1b[m", 0, 2), "\x1b[3ma\x1b[mb\x1b[3m\x1b[m")
end)

-- max_args doesn't include the command itself
-- see below for examples
function util.parsecmd(line, max_args, pipe)
	-- line = string.gsub(line, "^ *", "")  guaranteed to start with /

	local args = {}
	local pos = 1
	if pipe then
		local split = string.find(line, "|")
		if split then
			args.pipe = string.sub(line, split+1)
			line = string.sub(line, 1, split-1)
		end
	end
	line = string.gsub(line, " *$", "")
	while true do
		local ws, we = string.find(line, " +", pos)
		if ws and (not max_args or #args < max_args) then
			table.insert(args, string.sub(line, pos, ws-1))
			pos = we + 1
		else
			table.insert(args, string.sub(line, pos))
			break
		end
	end
	args[0] = string.gsub(args[1], "^/", "")
	table.remove(args, 1)
	return args
end
tests.run(function(t)
	t(util.parsecmd("/q dzwdz blah blah"), {[0]="q", "dzwdz", "blah", "blah"})
	t(util.parsecmd("/q dzwdz blah blah", 2), {[0]="q", "dzwdz", "blah blah"})
	t(util.parsecmd("/q   dzwdz   blah   blah", 2), {[0]="q", "dzwdz", "blah   blah"})

	t(util.parsecmd("/list | less"),
		{[0]="list", "|", "less"})
	t(util.parsecmd("/list | less", nil, true),
		{[0]="list", ["pipe"]=" less"})
end)

function util.config_load()
	package.loaded.config = nil
	package.loaded.config_default = nil

	config = {}
	config.ident = {}
	config.color = {}
	config.commands = {}
	require "config_default"
	local succ, res = xpcall(require, debug.traceback, "config")
	if not succ then
		print(res)
		print(i18n.err_config)
	end
end


return util
