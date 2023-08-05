util = {}

function printf(...)
	print(string.format(...))
end

function djb2(s)
	local hash = 5381|0
	for _,c in ipairs({string.byte(s, 1, -1)}) do
		hash = hash * 31 + c
	end
	return hash
end

function hi(s) -- highlight
	if not s then return "" end
	local colors = config.color.nicks
	if not colors or #colors == 0 then return s end

	-- TODO highlighting commands in help prompts?
	local cid = djb2(s) % #colors
	local color = colors[cid+1]
	return "\x1b["..color.."m"..s.."\x1b[0m"
end

function nick_pattern(nick)
	-- TODO only works with alphanumeric nicks
	return "%f[%w]"..nick.."%f[^%w]"
end

function file_exists(path)
	local f = io.open(path)
	if f then
		f:close()
		return true
	else
		return false
	end
end

-- Takes a character-wise substring, preserving any original formatting.
function util.visub(str, from, to)
	if from ~= 0 then error("unimplemented") end

	local i = 1
	local len = string.len(str)
	local res = ""
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
run_test(function(t)
	local vs = util.visub
	t(vs("\x1b[3m12345678\x1b[m", 0, 4), "\x1b[3m1234\x1b[m")
	t(vs("\x1b[3mąęźć\x1b[m", 0, 2), "\x1b[3mąę\x1b[m")
	t(vs("\x1b[3ma\x1b[mb\x1b[3mc\x1b[m", 0, 2), "\x1b[3ma\x1b[mb\x1b[3m\x1b[m")
end)
