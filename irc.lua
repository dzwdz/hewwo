RPL_LIST = "322"
RPL_LISTEND = "323"
RPL_TOPIC = "332"
RPL_NAMREPLY = "353"
RPL_ENDOFMOTD = "376"
ERR_NOMOTD = "422"
ERR_NICKNAMEINUSE = "433"

function writecmd(...)
	local cmd = ""
	-- TODO enforce no spaces
	for i, v in ipairs({...}) do
		if i ~= 1 then
			cmd = cmd .. " "
			if i == #{...} then
				cmd = cmd .. ":"
			end
		end
		cmd = cmd .. v
	end
	writecmdraw(cmd)
end

function writecmdraw(cmd)
	if config.debug then
		print("=>", escape(cmd))
	end
	writesock(cmd)
	newcmd(":"..conn.user.."!@ "..cmd, false)
end

function parsecmd(line)
	local data = {}

	local pos = 1
	if string.sub(line, 1, 1) == ":" then
		pos = string.find(line, " ")
		if not pos then return end -- invalid message
		data.prefix = string.sub(line, 2, pos-1)
		pos = pos+1

		excl = string.find(data.prefix, "!")
		if excl then
			data.user = string.sub(data.prefix, 1, excl-1)
		end
	end
	while pos <= string.len(line) do
		local nextpos = nil
		if string.sub(line, pos, pos) ~= ":" then
			nextpos = string.find(line, " ", pos+1)
		else
			pos = pos+1
		end
		if not nextpos then
			nextpos = string.len(line)+1
		end
		table.insert(data, string.sub(line, pos, nextpos-1))
		pos = nextpos+1
	end

	local cmd = string.upper(data[1])
	if (cmd == "PRIVMSG" or cmd == "NOTICE") and string.sub(data[3], 1, 1) == "\1" then
		data.ctcp = {}
		local inner = string.gsub(string.sub(data[3], 2), "\1$", "")
		local split = string.find(inner, " ", 2)
		if split then
			data.ctcp.cmd = string.upper(string.sub(inner, 1, split-1))
			data.ctcp.params = string.sub(inner, split+1)
		else
			data.ctcp.cmd = string.upper(inner)
		end
	end

	return data
end

-- this mess isn't even correct. or at least it doesn't match up weechat's
-- settings quite right. 16+ should be correct, though.
local colormap = {
	[ 0] = 7,   [ 1] = 0,   [ 2] = 4,   [ 3] = 2,   [ 4] = 9,   [ 5] = 3,   
	[ 6] = 5,   [ 7] = 202, [ 8] = 11,  [ 9] = 10,  [10] = 6,   [11] = 14,  
	[12] = 12,  [13] = 13,  [14] = 8,   [15] = 7,   [16] = 52,  [17] = 94,  
	[18] = 100, [19] = 58,  [20] = 22,  [21] = 29,  [22] = 23,  [23] = 24,  
	[24] = 17,  [25] = 54,  [26] = 53,  [27] = 89,  [28] = 88,  [29] = 130, 
	[30] = 142, [31] = 64,  [32] = 28,  [33] = 35,  [34] = 30,  [35] = 25,  
	[36] = 18,  [37] = 91,  [38] = 90,  [39] = 125, [40] = 124, [41] = 166, 
	[42] = 184, [43] = 106, [44] = 34,  [45] = 49,  [46] = 37,  [47] = 33,  
	[48] = 19,  [49] = 129, [50] = 127, [51] = 161, [52] = 196, [53] = 208, 
	[54] = 226, [55] = 154, [56] = 46,  [57] = 86,  [58] = 51,  [59] = 75,  
	[60] = 21,  [61] = 171, [62] = 201, [63] = 198, [64] = 203, [65] = 215, 
	[66] = 227, [67] = 191, [68] = 83,  [69] = 122, [70] = 87,  [71] = 111, 
	[72] = 63,  [73] = 177, [74] = 207, [75] = 205, [76] = 217, [77] = 223, 
	[78] = 229, [79] = 193, [80] = 157, [81] = 158, [82] = 159, [83] = 153, 
	[84] = 147, [85] = 183, [86] = 219, [87] = 212, [88] = 16,  [89] = 233, 
	[90] = 235, [91] = 237, [92] = 239, [93] = 241, [94] = 244, [95] = 247, 
	[96] = 250, [97] = 254, [98] = 231, 
}

-- format irc messages for display, escaping unknown characters
-- https://modern.ircdocs.horse/formatting.html
function ircformat(s)
	-- DON'T USE \x1b[0m unless you're absolutely sure. check the correct code
	-- see tsetattr in http://git.suckless.org/st/file/st.c.html

	local function t(cur, enable, disable) -- toggle
		if cur then
			return false, disable
		else
			return true, enable
		end
	end

	local function color(fg, bg)
		local function get_fg(fg)
			if not fg then return "" end
			fg = tonumber(fg)
			if fg == 99 then
				return "\x1b[39m" -- reset
			else
				return string.format("\x1b[38;5;%sm", colormap[fg])
			end
		end
		local function get_bg(bg)
			if not bg then return "" end
			bg = tonumber(bg)
			if bg == 99 then
				return "\x1b[49m" -- reset
			else
				return string.format("\x1b[48;5;%sm", colormap[bg])
			end
		end
		return get_fg(fg) .. get_bg(bg)
	end

	local bold, italic, underline, reverse

	s = string.gsub(s, "[\x00-\x1F\x7F]", function (c)
		local r -- replacement

		if c == "\x02" then
			bold, r = t(bold, "\x1b[1m", "\x1b[22m")
		elseif c == "\x03" then
			-- color handling is a special beast. leave it for later
			return c
		elseif c == "\x1d" then
			italic, r = t(italic, "\x1b[3m", "\x1b[23m")
		elseif c == "\x1f" then
			underline, r = t(underline, "\x1b[4m", "\x1b[24m")
		elseif c == "\x16" then
			reverse, r = t(reverse, "\x1b[7m", "\x1b[27m")
		elseif c == "\x0F" then
			r = "\x1b[m"
			bold = false
			italic = false
			underline = false
			reverse = false
		end

		return r or escape_char(c)
	end)

	s = string.gsub(s, "\x03([0-9][0-9]?),([0-9][0-9]?)", color)
	s = string.gsub(s, "\x03([0-9][0-9]?)", color)
	s = string.gsub(s, "\x03", "\x1b[39m\x1b[49m")

	if string.find(s, "\x1b") then s = s.."\x1b[m" end -- reset if needed
	return s
end
