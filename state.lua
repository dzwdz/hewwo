local Gs = {}

Gs.user = nil
Gs.active = false
Gs.nick_idx = 1
Gs.chan = nil
Gs.buffers = {}
Gs.used_hints = {}
Gs.topics = {} -- map from channel to current topic

return Gs
