--[=[
	Client-side mirror of server player profile. Server is authoritative.
	Numbers replicate through Player attributes.

	@class PlayerDataServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local Maid = require("Maid")
local Signal = require("Signal")

local PlayerDataServiceClient = {}
PlayerDataServiceClient.ServiceName = "PlayerDataServiceClient"

local NUMBER_FIELDS = {
	Slugs = "SlugsChanged",
	SoupsEaten = "SoupsEatenChanged",
	GentParts = "GentPartsChanged",
	Batteries = "BatteriesChanged",
	ToolKits = "ToolKitsChanged",
	GentCards = "GentCardsChanged",
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

function PlayerDataServiceClient:Init(serviceBag)
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()
	self._player = Players.LocalPlayer
	self._profile = makeDefaultProfile()

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

	for _, signalName in ipairs({
		"SlugsChanged",
		"SoupsEatenChanged",
		"GentPartsChanged",
		"BatteriesChanged",
		"ToolKitsChanged",
		"GentCardsChanged",
		"ItemChanged",
		"WeaponChanged",
		"KeyCollected",
		"NoteCollected",
		"AudioLogCollected",
		"FlagChanged",
	}) do
		self._maid:GiveTask(self[signalName])
	end
end

function PlayerDataServiceClient:Start()
	for field in NUMBER_FIELDS do
		self:_syncNumberField(field)
		self._maid:GiveTask(self._player:GetAttributeChangedSignal(field):Connect(function()
			self:_syncNumberField(field)
		end))
	end

	self:_syncWeapon()
	self._maid:GiveTask(self._player:GetAttributeChangedSignal("Weapon"):Connect(function()
		self:_syncWeapon()
	end))

	self._maid:GiveTask(self._player.AttributeChanged:Connect(function(attributeName)
		self:_syncDynamicAttribute(attributeName)
	end))

	for attributeName in self._player:GetAttributes() do
		self:_syncDynamicAttribute(attributeName)
	end
end

function PlayerDataServiceClient:_syncNumberField(field: string)
	local old = self._profile[field] or 0
	local value = self._player:GetAttribute(field)
	if type(value) ~= "number" then
		value = 0
	end
	value = math.max(0, math.floor(value))
	self._profile[field] = value
	if value ~= old then
		local signal = self[NUMBER_FIELDS[field]]
		if signal then
			signal:Fire(value, old)
		end
	end
end

function PlayerDataServiceClient:_syncWeapon()
	local old = self._profile.Weapon
	local value = self._player:GetAttribute("Weapon")
	if type(value) ~= "string" or value == "" then
		value = nil
	end
	self._profile.Weapon = value
	if value ~= old then
		self.WeaponChanged:Fire(value, old)
	end
end

function PlayerDataServiceClient:_syncDynamicAttribute(attributeName: string)
	if string.sub(attributeName, 1, 5) == "Item_" then
		local itemId = string.sub(attributeName, 6)
		local old = self._profile.Items[itemId] or 0
		local value = self._player:GetAttribute(attributeName)
		if type(value) ~= "number" then
			value = 0
		end
		if value > 0 then
			self._profile.Items[itemId] = value
		else
			self._profile.Items[itemId] = nil
		end
		if value ~= old then
			self.ItemChanged:Fire(itemId, value, old)
		end
	elseif string.sub(attributeName, 1, 4) == "Key_" then
		local keyId = string.sub(attributeName, 5)
		local value = self._player:GetAttribute(attributeName) == true
		local old = self._profile.Keys[keyId] == true
		if value then
			self._profile.Keys[keyId] = true
		else
			self._profile.Keys[keyId] = nil
		end
		if value and not old then
			self.KeyCollected:Fire(keyId)
		end
	elseif string.sub(attributeName, 1, 5) == "Note_" then
		local noteId = string.sub(attributeName, 6)
		local value = self._player:GetAttribute(attributeName) == true
		local old = self._profile.Notes[noteId] == true
		if value then
			self._profile.Notes[noteId] = true
		else
			self._profile.Notes[noteId] = nil
		end
		if value and not old then
			self.NoteCollected:Fire(noteId)
		end
	elseif string.sub(attributeName, 1, 9) == "AudioLog_" then
		local logId = string.sub(attributeName, 10)
		local value = self._player:GetAttribute(attributeName) == true
		local old = self._profile.AudioLogs[logId] == true
		if value then
			self._profile.AudioLogs[logId] = true
		else
			self._profile.AudioLogs[logId] = nil
		end
		if value and not old then
			self.AudioLogCollected:Fire(logId)
		end
	elseif string.sub(attributeName, 1, 5) == "Flag_" then
		local name = string.sub(attributeName, 6)
		local old = self._profile.Flags[name]
		local value = self._player:GetAttribute(attributeName)
		self._profile.Flags[name] = value
		if value ~= old then
			self.FlagChanged:Fire(name, value, old)
		end
	end
end

function PlayerDataServiceClient:GetSlugs(): number
	return self._profile.Slugs
end
function PlayerDataServiceClient:GetSoupsEaten(): number
	return self._profile.SoupsEaten
end
function PlayerDataServiceClient:GetGentParts(): number
	return self._profile.GentParts
end
function PlayerDataServiceClient:GetBatteries(): number
	return self._profile.Batteries
end
function PlayerDataServiceClient:GetToolKits(): number
	return self._profile.ToolKits
end
function PlayerDataServiceClient:GetGentCards(): number
	return self._profile.GentCards
end
function PlayerDataServiceClient:GetItem(itemId: string): number
	return self._profile.Items[itemId] or 0
end
function PlayerDataServiceClient:HasItem(itemId: string, amount: number?): boolean
	return self:GetItem(itemId) >= (amount or 1)
end
function PlayerDataServiceClient:GetInventory(): { [string]: number }
	return deepCopy(self._profile.Items)
end
function PlayerDataServiceClient:GetWeapon(): string?
	return self._profile.Weapon
end
function PlayerDataServiceClient:HasKey(keyId: string): boolean
	return self._profile.Keys[keyId] == true
end
function PlayerDataServiceClient:GetKeys(): { string }
	local out = {}
	for id in self._profile.Keys do
		table.insert(out, id)
	end
	return out
end
function PlayerDataServiceClient:HasNote(noteId: string): boolean
	return self._profile.Notes[noteId] == true
end
function PlayerDataServiceClient:GetNotes(): { string }
	local out = {}
	for id in self._profile.Notes do
		table.insert(out, id)
	end
	return out
end
function PlayerDataServiceClient:HasAudioLog(logId: string): boolean
	return self._profile.AudioLogs[logId] == true
end
function PlayerDataServiceClient:GetAudioLogs(): { string }
	local out = {}
	for id in self._profile.AudioLogs do
		table.insert(out, id)
	end
	return out
end
function PlayerDataServiceClient:GetFlag(name: string)
	return self._profile.Flags[name]
end
function PlayerDataServiceClient:IsFlagSet(name: string): boolean
	local v = self._profile.Flags[name]
	return v ~= nil and v ~= false
end
function PlayerDataServiceClient:GetProfile()
	return deepCopy(self._profile)
end

function PlayerDataServiceClient:SetSlugs(amount: number)
	local old = self._profile.Slugs
	self._profile.Slugs = math.max(0, math.floor(amount))
	if self._profile.Slugs ~= old then
		self.SlugsChanged:Fire(self._profile.Slugs, old)
	end
end
function PlayerDataServiceClient:AddSlugs(amount: number)
	self:SetSlugs(self._profile.Slugs + amount)
end
function PlayerDataServiceClient:RemoveSlugs(amount: number): boolean
	if self._profile.Slugs < amount then
		return false
	end
	self:SetSlugs(self._profile.Slugs - amount)
	return true
end
function PlayerDataServiceClient:SetSoupsEaten(amount: number)
	local old = self._profile.SoupsEaten
	self._profile.SoupsEaten = math.max(0, math.floor(amount))
	if self._profile.SoupsEaten ~= old then
		self.SoupsEatenChanged:Fire(self._profile.SoupsEaten, old)
	end
end
function PlayerDataServiceClient:AddSoupEaten(amount: number?)
	self:SetSoupsEaten(self._profile.SoupsEaten + (amount or 1))
end
function PlayerDataServiceClient:SetGentParts(amount: number)
	local old = self._profile.GentParts
	self._profile.GentParts = math.max(0, math.floor(amount))
	if self._profile.GentParts ~= old then
		self.GentPartsChanged:Fire(self._profile.GentParts, old)
	end
end
function PlayerDataServiceClient:AddGentParts(amount: number?)
	self:SetGentParts(self._profile.GentParts + (amount or 1))
end
function PlayerDataServiceClient:SetBatteries(amount: number)
	local old = self._profile.Batteries
	self._profile.Batteries = math.max(0, math.floor(amount))
	if self._profile.Batteries ~= old then
		self.BatteriesChanged:Fire(self._profile.Batteries, old)
	end
end
function PlayerDataServiceClient:AddBatteries(amount: number?)
	self:SetBatteries(self._profile.Batteries + (amount or 1))
end
function PlayerDataServiceClient:SetToolKits(amount: number)
	local old = self._profile.ToolKits
	self._profile.ToolKits = math.max(0, math.floor(amount))
	if self._profile.ToolKits ~= old then
		self.ToolKitsChanged:Fire(self._profile.ToolKits, old)
	end
end
function PlayerDataServiceClient:AddToolKits(amount: number?)
	self:SetToolKits(self._profile.ToolKits + (amount or 1))
end
function PlayerDataServiceClient:SetGentCards(amount: number)
	local old = self._profile.GentCards
	self._profile.GentCards = math.max(0, math.floor(amount))
	if self._profile.GentCards ~= old then
		self.GentCardsChanged:Fire(self._profile.GentCards, old)
	end
end
function PlayerDataServiceClient:AddGentCards(amount: number?)
	self:SetGentCards(self._profile.GentCards + (amount or 1))
end
function PlayerDataServiceClient:AddItem(itemId: string, amount: number?)
	local old = self._profile.Items[itemId] or 0
	local new = old + (amount or 1)
	self._profile.Items[itemId] = new
	self.ItemChanged:Fire(itemId, new, old)
end
function PlayerDataServiceClient:RemoveItem(itemId: string, amount: number?): boolean
	local old = self._profile.Items[itemId] or 0
	local delta = amount or 1
	if old < delta then
		return false
	end
	local new = old - delta
	self._profile.Items[itemId] = if new > 0 then new else nil
	self.ItemChanged:Fire(itemId, new, old)
	return true
end
function PlayerDataServiceClient:AddKey(keyId: string)
	if self._profile.Keys[keyId] then
		return
	end
	self._profile.Keys[keyId] = true
	self.KeyCollected:Fire(keyId)
end
function PlayerDataServiceClient:RemoveKey(keyId: string)
	self._profile.Keys[keyId] = nil
end
function PlayerDataServiceClient:CollectNote(noteId: string): boolean
	if self._profile.Notes[noteId] then
		return false
	end
	self._profile.Notes[noteId] = true
	self.NoteCollected:Fire(noteId)
	return true
end
function PlayerDataServiceClient:CollectAudioLog(logId: string): boolean
	if self._profile.AudioLogs[logId] then
		return false
	end
	self._profile.AudioLogs[logId] = true
	self.AudioLogCollected:Fire(logId)
	return true
end
function PlayerDataServiceClient:SetFlag(name: string, value: any)
	local old = self._profile.Flags[name]
	if old == value then
		return
	end
	self._profile.Flags[name] = value
	self.FlagChanged:Fire(name, value, old)
end
function PlayerDataServiceClient:ClearFlag(name: string)
	self:SetFlag(name, nil)
end
function PlayerDataServiceClient:ResetProfile()
	self._profile = makeDefaultProfile()
end
function PlayerDataServiceClient:Destroy()
	self._maid:DoCleaning()
end

return PlayerDataServiceClient
