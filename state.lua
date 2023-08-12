local Gs = {}

Gs.user = nil -- TODO rename to nick
Gs.active = false
Gs.chan = nil -- TODO rename to openbuf
Gs.buffers = {}
Gs.used_hints = {}
Gs.topics = {} -- map from channel to current topic

return Gs
