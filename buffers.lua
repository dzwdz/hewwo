buffers = {
	tbl = {},
}

function buffers:switch(chan)
	printf("--- switching to %s", chan)
	conn.chan = chan
	if self.tbl[chan] then
		-- TODO remember last seen message to prevent spam?
		for ent in self.tbl[chan]:iter() do
			printcmd(ent.line, ent.ts)
		end
		self.tbl[chan].unread = 0
		self.tbl[chan].mentions = 0
	else
		-- TODO error out
		print("-- (creating buffer)")
	end
end

-- pushes a fresh irc command to a buffer
-- urgency controls if the message should be printed as its pushed.
-- urgency == 0  ->  printed iff the buffer is visible
-- urgency >  0  ->  always printed, potentially with an urgency prefix
-- urgency <  0  ->  not printed
function buffers:push(buf, line, urgency)
	urgency = urgency or 0

	local ts = os.time()
	self:make(buf)
	local b = self.tbl[buf]
	b:push({line=line, ts=ts})
	if buf ~= conn.chan then
		self.tbl[buf].unread = self.tbl[buf].unread + 1
		if urgency > 0 then
			-- TODO store original nickname for mention purposes
			-- otherwise /nick will break shit
			self.tbl[buf].mentions = self.tbl[buf].mentions + 1
		end
	end

	if urgency >= 0 and buffers:is_visible(buf) then
		printcmd(line, ts)
	elseif urgency > 0 then
		printcmd(line, ts, buf)
	end
end

function buffers:is_visible(buf)
	return buf == conn.chan
end

function buffers:make(buf)
	if not self.tbl[buf] then
		self.tbl[buf] = ringbuf:new(200)
		self.tbl[buf].state = "unknown"
		self.tbl[buf].unread = 0
		self.tbl[buf].mentions = 0
	end
end

function buffers:count_unread()
	local unread = 0
	local mentions = 0
	for _, buf in pairs(buffers.tbl) do
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


ringbuf = {
	cap = 0,
	first = 1,
	last = 0,
}

function ringbuf:new(capacity)
	return setmetatable({cap=capacity, first=1, last=0}, {__index=self})
end

function ringbuf:push(el)
	if self.last == 0 then
		self.last = 1
	elseif self.last == self.cap then
		self.last = 1
		self.first = 2
	else
		self.last = self.last + 1
		if self.last == self.first then
			if self.first == self.cap then
				self.first = 1
			else
				self.first = self.last + 1
			end
		end
	end
	self[self.last] = el
end

function ringbuf:iter()
	local i = self.first
	local done = false
	return function()
		if done then return nil end
		local el = self[i]
		first = false
		if i == self.last then
			done = true
		elseif i == self.cap then
			i = 1
		else
			i = i + 1
		end
		return el
	end
end
