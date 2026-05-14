--[=[
	Server-side player profile: currencies, inventory, keys, notes, audio logs,
	and flags. In-memory only. New profile every join.

	@class PlayerDataService
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local Maid = require("Maid")
local Signal = require("Signal")

local PlayerDataService = {}
PlayerDataService.ServiceName = "PlayerDataService"

local NUMBER_FIELDS = {
	Slugs = true,
	SoupsEaten = true,
	GentParts = true,
	Batteries = true,
	ToolKits = true,
	GentCards = true,
}

local function deepCopy(t)
	if type(t) ~= "table" then
		return t
	end

	local out = {}
	for k, v in t do
		out[k] = deepCopy(v)
	end

	return out
end

local function makeDefaultProfile()
	return {
		Slugs = 0,
		SoupsEaten = 0,
		GentParts = 0,
		Batteries = 0,
		ToolKits = 0,
		GentCards = 0,

		Items = {},
		Weapon = nil,
		Keys = {},
		Notes = {},
		AudioLogs = {},
		Flags = {},
	}
end

function PlayerDataService:Init(serviceBag)
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()
	self._profiles = {}

	self.ProfileAdded = Signal.new()
	self.ProfileRemoving = Signal.new()

	self.SlugsChanged = Signal.new()
	self.SoupsEatenChanged = Signal.new()
	self.GentPartsChanged = Signal.new()
	self.BatteriesChanged = Signal.new()
	self.ToolKitsChanged = Signal.new()
	self.GentCardsChanged = Signal.new()
	self.ItemChanged = Signal.new()
	self.WeaponChanged = Signal.new()
	self.KeyCollected = Signal.new()
	self.NoteCollected = Signal.new()
	self.AudioLogCollected = Signal.new()
	self.FlagChanged = Signal.new()

	self._maid:GiveTask(self.ProfileAdded)
	self._maid:GiveTask(self.ProfileRemoving)
	self._maid:GiveTask(self.SlugsChanged)
	self._maid:GiveTask(self.SoupsEatenChanged)
	self._maid:GiveTask(self.GentPartsChanged)
	self._maid:GiveTask(self.BatteriesChanged)
	self._maid:GiveTask(self.ToolKitsChanged)
	self._maid:GiveTask(self.GentCardsChanged)
	self._maid:GiveTask(self.ItemChanged)
	self._maid:GiveTask(self.WeaponChanged)
	self._maid:GiveTask(self.KeyCollected)
	self._maid:GiveTask(self.NoteCollected)
	self._maid:GiveTask(self.AudioLogCollected)
	self._maid:GiveTask(self.FlagChanged)
end

function PlayerDataService:Start()
	self._maid:GiveTask(Players.PlayerAdded:Connect(function(player)
		self:_setupPlayer(player)
	end))

	self._maid:GiveTask(Players.PlayerRemoving:Connect(function(player)
		self:_cleanupPlayer(player)
	end))

	for _, player in ipairs(Players:GetPlayers()) do
		self:_setupPlayer(player)
	end
end

function PlayerDataService:_setupPlayer(player: Player)
	if self._profiles[player] then
		return
	end

	local profile = makeDefaultProfile()
	self._profiles[player] = profile

	for field in NUMBER_FIELDS do
		player:SetAttribute(field, profile[field] or 0)
	end

	player:SetAttribute("Weapon", "")

	self.ProfileAdded:Fire(player, self:GetProfile(player))
end

function PlayerDataService:_cleanupPlayer(player: Player)
	local profile = self._profiles[player]
	if not profile then
		return
	end

	self.ProfileRemoving:Fire(player, self:GetProfile(player))
	self._profiles[player] = nil
end

function PlayerDataService:_getProfile(player: Player)
	local profile = self._profiles[player]
	if not profile then
		self:_setupPlayer(player)
		profile = self._profiles[player]
	end

	return profile
end

function PlayerDataService:_setNumberField(player: Player, field: string, amount: number, signal)
	assert(NUMBER_FIELDS[field], "Bad number field")
	assert(type(amount) == "number", "Bad amount")

	local profile = self:_getProfile(player)
	local old = profile[field] or 0
	local newValue = math.max(0, math.floor(amount))

	profile[field] = newValue

	if newValue ~= old then
		player:SetAttribute(field, newValue)

		if signal then
			signal:Fire(player, newValue, old)
		end
	end
end

function PlayerDataService:GetSlugs(player: Player): number
	return self:_getProfile(player).Slugs
end

function PlayerDataService:SetSlugs(player: Player, amount: number)
	self:_setNumberField(player, "Slugs", amount, self.SlugsChanged)
end

function PlayerDataService:AddSlugs(player: Player, amount: number?)
	self:SetSlugs(player, self:GetSlugs(player) + (amount or 1))
end

function PlayerDataService:RemoveSlugs(player: Player, amount: number): boolean
	assert(type(amount) == "number" and amount >= 0, "Bad amount")
	if self:GetSlugs(player) < amount then
		return false
	end
	self:SetSlugs(player, self:GetSlugs(player) - amount)
	return true
end

function PlayerDataService:GetSoupsEaten(player: Player): number
	return self:_getProfile(player).SoupsEaten
end

function PlayerDataService:SetSoupsEaten(player: Player, amount: number)
	self:_setNumberField(player, "SoupsEaten", amount, self.SoupsEatenChanged)
end

function PlayerDataService:AddSoupEaten(player: Player, amount: number?)
	self:SetSoupsEaten(player, self:GetSoupsEaten(player) + (amount or 1))
end

function PlayerDataService:GetGentParts(player: Player): number
	return self:_getProfile(player).GentParts
end

function PlayerDataService:SetGentParts(player: Player, amount: number)
	self:_setNumberField(player, "GentParts", amount, self.GentPartsChanged)
end

function PlayerDataService:AddGentParts(player: Player, amount: number?)
	self:SetGentParts(player, self:GetGentParts(player) + (amount or 1))
end

function PlayerDataService:RemoveGentParts(player: Player, amount: number): boolean
	assert(type(amount) == "number" and amount >= 0, "Bad amount")
	if self:GetGentParts(player) < amount then
		return false
	end
	self:SetGentParts(player, self:GetGentParts(player) - amount)
	return true
end

function PlayerDataService:GetBatteries(player: Player): number
	return self:_getProfile(player).Batteries
end

function PlayerDataService:SetBatteries(player: Player, amount: number)
	self:_setNumberField(player, "Batteries", amount, self.BatteriesChanged)
end

function PlayerDataService:AddBatteries(player: Player, amount: number?)
	self:SetBatteries(player, self:GetBatteries(player) + (amount or 1))
end

function PlayerDataService:RemoveBatteries(player: Player, amount: number): boolean
	assert(type(amount) == "number" and amount >= 0, "Bad amount")
	if self:GetBatteries(player) < amount then
		return false
	end
	self:SetBatteries(player, self:GetBatteries(player) - amount)
	return true
end

function PlayerDataService:GetToolKits(player: Player): number
	return self:_getProfile(player).ToolKits
end

function PlayerDataService:SetToolKits(player: Player, amount: number)
	self:_setNumberField(player, "ToolKits", amount, self.ToolKitsChanged)
end

function PlayerDataService:AddToolKits(player: Player, amount: number?)
	self:SetToolKits(player, self:GetToolKits(player) + (amount or 1))
end

function PlayerDataService:RemoveToolKits(player: Player, amount: number): boolean
	assert(type(amount) == "number" and amount >= 0, "Bad amount")
	if self:GetToolKits(player) < amount then
		return false
	end
	self:SetToolKits(player, self:GetToolKits(player) - amount)
	return true
end

function PlayerDataService:GetGentCards(player: Player): number
	return self:_getProfile(player).GentCards
end

function PlayerDataService:SetGentCards(player: Player, amount: number)
	self:_setNumberField(player, "GentCards", amount, self.GentCardsChanged)
end

function PlayerDataService:AddGentCards(player: Player, amount: number?)
	self:SetGentCards(player, self:GetGentCards(player) + (amount or 1))
end

function PlayerDataService:RemoveGentCards(player: Player, amount: number): boolean
	assert(type(amount) == "number" and amount >= 0, "Bad amount")
	if self:GetGentCards(player) < amount then
		return false
	end
	self:SetGentCards(player, self:GetGentCards(player) - amount)
	return true
end

function PlayerDataService:GetItem(player: Player, itemId: string): number
	return self:_getProfile(player).Items[itemId] or 0
end

function PlayerDataService:HasItem(player: Player, itemId: string, amount: number?): boolean
	return self:GetItem(player, itemId) >= (amount or 1)
end

function PlayerDataService:AddItem(player: Player, itemId: string, amount: number?)
	assert(type(itemId) == "string", "Bad itemId")

	local profile = self:_getProfile(player)
	local delta = amount or 1
	local old = profile.Items[itemId] or 0
	local new = old + delta

	profile.Items[itemId] = new
	player:SetAttribute("Item_" .. itemId, new)

	self.ItemChanged:Fire(player, itemId, new, old)
end

function PlayerDataService:RemoveItem(player: Player, itemId: string, amount: number?): boolean
	local profile = self:_getProfile(player)
	local delta = amount or 1
	local old = profile.Items[itemId] or 0

	if old < delta then
		return false
	end

	local new = old - delta
	profile.Items[itemId] = if new > 0 then new else nil
	player:SetAttribute("Item_" .. itemId, new)

	self.ItemChanged:Fire(player, itemId, new, old)
	return true
end

function PlayerDataService:GetInventory(player: Player): { [string]: number }
	return deepCopy(self:_getProfile(player).Items)
end

function PlayerDataService:GetWeapon(player: Player): string?
	return self:_getProfile(player).Weapon
end

function PlayerDataService:SetWeapon(player: Player, weaponId: string?)
	local profile = self:_getProfile(player)
	local old = profile.Weapon

	if old == weaponId then
		return
	end

	profile.Weapon = weaponId
	player:SetAttribute("Weapon", weaponId or "")
	self.WeaponChanged:Fire(player, weaponId, old)
end

function PlayerDataService:HasKey(player: Player, keyId: string): boolean
	return self:_getProfile(player).Keys[keyId] == true
end

function PlayerDataService:AddKey(player: Player, keyId: string)
	assert(type(keyId) == "string", "Bad keyId")

	local profile = self:_getProfile(player)

	if profile.Keys[keyId] then
		return
	end

	profile.Keys[keyId] = true
	player:SetAttribute("Key_" .. keyId, true)
	self.KeyCollected:Fire(player, keyId)
end

function PlayerDataService:RemoveKey(player: Player, keyId: string)
	local profile = self:_getProfile(player)
	profile.Keys[keyId] = nil
	player:SetAttribute("Key_" .. keyId, nil)
end

function PlayerDataService:GetKeys(player: Player): { string }
	local out = {}
	for id in self:_getProfile(player).Keys do
		table.insert(out, id)
	end
	return out
end

function PlayerDataService:HasNote(player: Player, noteId: string): boolean
	return self:_getProfile(player).Notes[noteId] == true
end

function PlayerDataService:CollectNote(player: Player, noteId: string): boolean
	assert(type(noteId) == "string", "Bad noteId")
	local profile = self:_getProfile(player)
	if profile.Notes[noteId] then
		return false
	end
	profile.Notes[noteId] = true
	player:SetAttribute("Note_" .. noteId, true)
	self.NoteCollected:Fire(player, noteId)
	return true
end

function PlayerDataService:HasAudioLog(player: Player, logId: string): boolean
	return self:_getProfile(player).AudioLogs[logId] == true
end

function PlayerDataService:CollectAudioLog(player: Player, logId: string): boolean
	assert(type(logId) == "string", "Bad logId")
	local profile = self:_getProfile(player)
	if profile.AudioLogs[logId] then
		return false
	end
	profile.AudioLogs[logId] = true
	player:SetAttribute("AudioLog_" .. logId, true)
	self.AudioLogCollected:Fire(player, logId)
	return true
end

function PlayerDataService:GetFlag(player: Player, name: string)
	return self:_getProfile(player).Flags[name]
end

function PlayerDataService:IsFlagSet(player: Player, name: string): boolean
	local value = self:_getProfile(player).Flags[name]
	return value ~= nil and value ~= false
end

function PlayerDataService:SetFlag(player: Player, name: string, value: any)
	assert(type(name) == "string", "Bad name")

	local profile = self:_getProfile(player)
	local old = profile.Flags[name]

	if old == value then
		return
	end

	profile.Flags[name] = value

	if type(value) == "boolean" or type(value) == "number" or type(value) == "string" or value == nil then
		player:SetAttribute("Flag_" .. name, value)
	end

	self.FlagChanged:Fire(player, name, value, old)
end

function PlayerDataService:ClearFlag(player: Player, name: string)
	self:SetFlag(player, name, nil)
end

function PlayerDataService:GetProfile(player: Player)
	return deepCopy(self:_getProfile(player))
end

function PlayerDataService:ResetProfile(player: Player)
	self._profiles[player] = makeDefaultProfile()

	local profile = self._profiles[player]
	for field in NUMBER_FIELDS do
		player:SetAttribute(field, profile[field] or 0)
	end

	player:SetAttribute("Weapon", "")
end

function PlayerDataService:Destroy()
	for player in self._profiles do
		self:_cleanupPlayer(player)
	end

	self._maid:DoCleaning()
end

return PlayerDataService
