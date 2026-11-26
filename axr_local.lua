-- Aleph X-Ray standalone, 2026-11-26: stand-in for Aleph's local library
-- (aleph_local.lua), which this plugin does not include.
--[[--
Aleph's X-Ray asks Aleph's library for the previous book of a series (for the
AI recap "The book before"). Without Aleph's library there is none to ask:
shared() returns nil and the recap uses the title alone, as Aleph does when a
book is not in its library.
]]

local Local = {}

function Local.shared() return nil end

return Local
