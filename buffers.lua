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
ent.display:
	-1 never display
	 0 display if appropriate
	 1 force display

ent.urgency:
	-1 don't bump unread
	 0 bump unread
	 1 bump mentions
	 2 push to :mentions
]]
function buffers:push(buf, line, ent)
	ent = ent or {}
	local urgency = ent.urgency or 0
	local display = ent.display
	if not display then
		if urgency >= 1 then
			display = 1
		else
			display = 0
		end
	end
	ent.line = line
	ent.ts = os.time()

	self:make(buf)
	local b = Gs.buffers[buf]
	b:push(ent)
	if buf ~= Gs.chan then
		if urgency >= 0 then
			Gs.buffers[buf].unread = Gs.buffers[buf].unread + 1
		end
		if urgency >= 1 and not buffers:is_visible(":mentions") then
			Gs.buffers[buf].mentions = Gs.buffers[buf].mentions + 1
		end
	end
	if urgency >= 2 then
		ent.buf = buf
		Gs.buffers[":mentions"]:push(ent)
	end

	if display >= 0 and buffers:is_visible(buf) then
		ui.printcmd(ent)
	elseif display > 0 then
		ui.printcmd(ent)
	elseif display >= 0 and urgency >= 0 and Gs.buffers[buf].unread == 1 then
		-- print first new message in a previously unread buffer
		ui.hint(i18n.hint.msg_in_unread)
		ui.printcmd(ent, buf)
	end
end

function buffers:is_visible(buf)
	return buf == Gs.chan
end

function buffers:make(buf)
	if not Gs.buffers[buf] then
		Gs.buffers[buf] = ringbuf:new(config.buffer_history)
		Gs.buffers[buf].connected = nil
		Gs.buffers[buf].unread = 0
		Gs.buffers[buf].mentions = 0
		Gs.buffers[buf].users = {}
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
			if buf.printcmd then
				-- XXX this is the only place where buf:printcmd is respected
				-- currently this is fine, but broadly it isn't
				buf:printcmd(ent)
			else
				ui.printcmd(ent)
			end
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
