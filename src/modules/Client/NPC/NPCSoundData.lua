--[=[
	DataTable for all NPC audio. Drop real asset IDs in here — zero other
	code changes required. Voice lines and attack sounds that have no asset
	yet are left as empty strings; the audio system skips empty entries
	gracefully and falls back to a print log.

	To add a new NPC type: add a key matching the NPC's `SoundId` attribute.
	To add new sounds for an existing type: add entries to its sub-table.
	All keys that the audio system reads are documented below.

	@class NPCSoundData
	@author mrnoob
]=]

--\ Types \--
-- SoundSet = {
--   Footsteps   : { string }   — sound IDs, one played per step
--   Attack      : { string }   — one played per attack swing
--   VoiceLines  : { string }   — random patrol voice lines
--   Death       : { string }   — played on death
-- }

return {
	--\ Default — used when no specific SoundId attribute is set \--
	Default = {
		Footsteps = {
			-- "rbxassetid://0",
		},
		Attack = {
			-- "rbxassetid://0",
		},
		VoiceLines = {
			-- "rbxassetid://0",
		},
		Death = {
			-- "rbxassetid://0",
		},
	},

	--\ LostOne \--
	LostOne = {
		Footsteps = {
			-- "rbxassetid://0",
		},
		Attack = {
			-- "rbxassetid://0",
		},
		VoiceLines = {
			-- "rbxassetid://0",
		},
		Death = {
			-- "rbxassetid://0",
		},
	},

	--\ Bendy \--
	Bendy = {
		Footsteps = {
			-- "rbxassetid://0",
		},
		Attack = {
			-- "rbxassetid://0",
		},
		VoiceLines = {
			-- "rbxassetid://0",
		},
		Death = {
			-- "rbxassetid://0",
		},
	},
}
