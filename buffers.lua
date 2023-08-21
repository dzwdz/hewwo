local buffers = safeinit(...)

local Gs = require "state"
local i18n = require "i18n"
local ringbuf = require "ringbuf"
local ui = require "ui"

function buffers:switch(chan)
	if Gs.chan == chan then return end
	printf("--- switching to %s", chan)
	if Gs.chan then
		ui.hint(i18n.hint.buffer, chan, Gs.chan)
	end
	Gs.chan = chan
	local buf = Gs.buffers[chan]
	if buf then
		buffers:print(chan, config.switch_history)
		buf.unread = 0
		buf.mentions = 0
		if buf.onswitch then buf:onswitch() end
	else
		print("-- (new buffer)")
	end
end

--[[
Pushes a fresh IRC command to a buffer.
bufs: (a table of) target buffer names

ent.urgency:
	-1 don't bump unread
	 0 bump unread
	 1 bump mentions and bell
	 2 push to :mentions

ent.forceshow : boolean
]]
function buffers:push(bufs, line, ent)
	ent = ent or {}
	ent.line = line
	ent.ts = os.time()
	local urgency = ent.urgency or 0

	-- note: bufs can sometimes be empty, e.g. when running /QUIT or /NICK
	--       when not in any channels.
	if type(bufs) ~= "table" then bufs = {bufs} end
	if #bufs == 1 then
		ent.buf = bufs[1]
	end
	if urgency >= 2 then
		table.insert(bufs, ":mentions")
	end

	local visible = ent.forceshow or urgency >= 1
	-- has to be checked before updating buffers
	for _,name in ipairs(bufs) do
		visible = visible or buffers:is_visible(name)
	end
	if visible then
		ui.printcmd(ent, true)
	end

	for _,name in ipairs(bufs) do
		self:make(name)
		local b = Gs.buffers[name]
		b:push(ent)
		if not buffers:is_visible(name) then
			if urgency >= 0 then
				if b.unread == 0 and not visible then
					-- print first new message in unread channel
					ui.hint(i18n.hint.msg_in_unread)
					ui.printcmd(ent, true)
				end
				b.unread = b.unread + 1
			end
			if urgency >= 1 then
				b.mentions = b.mentions + 1
			end
		end
	end
end

function buffers:is_visible(buf)
	return buf == Gs.chan
end

function buffers:make(name)
	if not Gs.buffers[name] then
		local buf = ringbuf:new(config.buffer_history)
		buf.connected = nil
		buf.unread = 0
		buf.mentions = 0
		buf.users = {}
		Gs.buffers[name] = buf
	end
end

function buffers:print(name, count)
	local buf = Gs.buffers[name]
	if not buf then return end

	-- TODO refactor ringbuf, add ringbuf:iter(-50)
	local t = {}
	for ent in buf:iter() do
		table.insert(t, ent)
	end

	if count and count < #t then
		printf("-- printing only %d/%d messages. to see the rest, /history %s", count, #t, name)
	end
	for k,ent in ipairs(t) do
		-- if #t == 50, and count == 2, the first printed index is 49
		-- 49 <= 50 - 2  false
		-- 48 <= 50 - 2  true
		if not (count and k <= #t - count) then
			ui.printcmd(ent)
		end
	end
end

function buffers:count_unread()
	local unread = 0
	local mentions = 0
	for _, buf in pairs(Gs.buffers) do
		-- TODO this is inefficient
		-- either compute another way, or call updateprompt() less
		if buf.unread > 0 then
			unread = unread + 1
		end
		if buf.mentions > 0 then
			mentions = mentions + 1
		end
	end
	return unread, mentions
end

function buffers:leave(buf, who)
	if who == Gs.user then
		Gs.buffers[buf].connected = false
		Gs.buffers[buf].users = {}
	end
	Gs.buffers[buf].users[who] = nil
end

function buffers:is_special(name)
	return Gs.buffers[name] and string.match(name, "^:")
end

return buffers
