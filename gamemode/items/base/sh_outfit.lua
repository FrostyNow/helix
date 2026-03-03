
ITEM.name = "Outfit"
ITEM.description = "A Outfit Base."
ITEM.category = "Outfit"
ITEM.model = "models/Gibs/HGIBS.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.outfitCategory = "model"
ITEM.pacData = {}
ITEM.equipSound = {
	"interface/items/inv_items_cloth_1.ogg",
	"interface/items/inv_items_cloth_2.ogg",
	"interface/items/inv_items_cloth_3.ogg"
}
ITEM.unequipSound = {
	"interface/items/inv_items_cloth_1.ogg",
	"interface/items/inv_items_cloth_2.ogg",
	"interface/items/inv_items_cloth_3.ogg"
}

local function PlayRandomSound(client, sound)
	if (istable(sound)) then
		client:EmitSound(sound[math.random(1, #sound)])
	elseif (isstring(sound)) then
		client:EmitSound(sound)
	end
end

--[[
-- This will change a player's skin after changing the model. Keep in mind it starts at 0.
ITEM.newSkin = 1
-- This will change a certain part of the model.
ITEM.replacements = {"group01", "group02"}
-- This will change the player's model completely.
ITEM.replacements = "models/manhack.mdl"
-- This will have multiple replacements.
ITEM.replacements = {
	{"male", "female"},
	{"group01", "group02"}
}

-- This will apply body groups.
ITEM.bodyGroups = {
	["blade"] = 1,
	["bladeblur"] = 1
}
]]--

-- Inventory drawing
if (CLIENT) then
	function ITEM:PaintOver(item, w, h)
		if (item:GetData("equip")) then
			surface.SetDrawColor(110, 255, 110, 100)
			surface.DrawRect(w - 14, h - 14, 8, 8)
		end
	end
end

function ITEM:AddOutfit(client)
	client = client or self.player or self:GetOwner()
	if (!IsValid(client)) then return end

	local character = client:GetCharacter()
	if (!character) then return end

	self:SetData("equip", true)

	local groups = character:GetData("groups", {})

	-- remove original bodygroups
	if (!table.IsEmpty(groups)) then
		local oldGroups = {}
		for i = 0, client:GetNumBodyGroups() - 1 do
			local name = client:GetBodygroupName(i)
			oldGroups[name] = client:GetBodygroup(i)
		end

		character:SetData("oldGroups" .. self.outfitCategory, oldGroups)
		character:SetData("groups", {})
	end

	if (isfunction(self.OnGetReplacement)) then
		character:SetData("oldModel" .. self.outfitCategory,
			character:GetData("oldModel" .. self.outfitCategory, self.player:GetModel()))
		character:SetModel(self:OnGetReplacement())
	elseif (self.replacement or self.replacements) then
		character:SetData("oldModel" .. self.outfitCategory,
			character:GetData("oldModel" .. self.outfitCategory, self.player:GetModel()))

		if (istable(self.replacements)) then
			if (#self.replacements == 2 and isstring(self.replacements[1])) then
				character:SetModel(self.player:GetModel():gsub(self.replacements[1], self.replacements[2]))
			else
				for _, v in ipairs(self.replacements) do
					character:SetModel(self.player:GetModel():gsub(v[1], v[2]))
				end
			end
		else
			character:SetModel(self.replacement or self.replacements)
		end
	end

	if (self.newSkin) then
		character:SetData("oldSkin" .. self.outfitCategory, self.player:GetSkin())
		self.player:SetSkin(self.newSkin)
	end

	-- get outfit saved bodygroups
	groups = self:GetData("groups", {})

	-- restore bodygroups saved to the item
	if (!table.IsEmpty(groups) and self:ShouldRestoreBodygroups()) then
		for k, v in pairs(groups) do
			local index = tonumber(k) or client:FindBodygroupByName(k)

			if (index and index > -1) then
				client:SetBodygroup(index, tonumber(v) or 0)
			end
		end
	-- apply default item bodygroups if none are saved
	elseif (istable(self.eqBodyGroups)) then
		for k, v in pairs(self.eqBodyGroups) do
			local index = client:FindBodygroupByName(k)

			if (index > -1) then
				client:SetBodygroup(index, v)
			end
		end
	end

	local materials  = self:GetData("submaterial", {})

	if (!table.IsEmpty(materials) and self:ShouldRestoreSubMaterials()) then
		for k, v in pairs(materials) do
			if (!isnumber(k) or !isstring(v)) then
				continue
			end

			client:SetSubMaterial(k - 1, v)
		end
	end

	if (istable(self.attribBoosts)) then
		for k, v in pairs(self.attribBoosts) do
			character:AddBoost(self.uniqueID, k, v)
		end
	end

	self:GetOwner():SetupHands()
	self:OnEquipped()
end

local function ResetSubMaterials(client)
	for k, _ in ipairs(client:GetMaterials()) do
		if (client:GetSubMaterial(k - 1) != "") then
			client:SetSubMaterial(k - 1)
		end
	end
end

function ITEM:RemoveOutfit(client)
	local character = client:GetCharacter()

	self:SetData("equip", false)

	local materials = {}

	for k, _ in ipairs(client:GetMaterials()) do
		if (client:GetSubMaterial(k - 1) != "") then
			materials[k] = client:GetSubMaterial(k - 1)
		end
	end

	-- save outfit submaterials
	if (!table.IsEmpty(materials)) then
		self:SetData("submaterial", materials)
	end

	-- remove outfit submaterials
	ResetSubMaterials(client)

	local groups = {}

	for i = 0, (client:GetNumBodyGroups() - 1) do
		local bodygroup = client:GetBodygroup(i)

		if (bodygroup > 0) then
			groups[i] = bodygroup
		end
	end

	-- save outfit bodygroups
	if (!table.IsEmpty(groups)) then
		self:SetData("groups", groups)
	end

	-- restore the original player model
	if (character:GetData("oldModel" .. self.outfitCategory)) then
		character:SetModel(character:GetData("oldModel" .. self.outfitCategory))
		character:SetData("oldModel" .. self.outfitCategory, nil)
	end

	-- restore the original player model skin
	if (self.newSkin) then
		if (character:GetData("oldSkin" .. self.outfitCategory)) then
			client:SetSkin(character:GetData("oldSkin" .. self.outfitCategory))
			character:SetData("oldSkin" .. self.outfitCategory, nil)
		else
			client:SetSkin(0)
		end
	end

	-- restore character original bodygroups
	groups = character:GetData("oldGroups" .. self.outfitCategory, {})

	-- restore original bodygroups
	if (!table.IsEmpty(groups)) then
		for k, v in pairs(groups) do
			local index = isnumber(k) and k or client:FindBodygroupByName(k)

			if (index and index > -1) then
				client:SetBodygroup(index, tonumber(v) or 0)
			end
		end

		character:SetData("groups", character:GetData("oldGroups" .. self.outfitCategory, {}))
		character:SetData("oldGroups" .. self.outfitCategory, nil)
	end

	-- Re-apply bodygroups from other equipped items to handle intersections
	for _, item in pairs(character:GetInventory():GetItems()) do
		if (item.id != self.id and item:GetData("equip") and (item.eqBodyGroups or item.bodyGroups)) then
			local bgs = item.eqBodyGroups or item.bodyGroups
			for bgName, bgValue in pairs(bgs) do
				local index = client:FindBodygroupByName(bgName)
				if (index > -1) then
					client:SetBodygroup(index, bgValue)
					
					local currentGroups = character:GetData("groups", {})
					currentGroups[index] = bgValue
					character:SetData("groups", currentGroups)
				end
			end
		end
	end

	if (istable(self.attribBoosts)) then
		for k, _ in pairs(self.attribBoosts) do
			character:RemoveBoost(self.uniqueID, k)
		end
	end

	for k, _ in pairs(self:GetData("outfitAttachments", {})) do
		self:RemoveAttachment(k, client)
	end

	self:GetOwner():SetupHands()
	self:OnUnequipped()
end

-- makes another outfit depend on this outfit in terms of requiring this item to be equipped in order to equip the attachment
-- also unequips the attachment if this item is dropped
function ITEM:AddAttachment(id)
	local attachments = self:GetData("outfitAttachments", {})
	attachments[id] = true

	self:SetData("outfitAttachments", attachments)
end

function ITEM:RemoveAttachment(id, client)
	local item = ix.item.instances[id]
	local attachments = self:GetData("outfitAttachments", {})

	if (item and attachments[id]) then
		item:OnDetached(client)
	end

	attachments[id] = nil
	self:SetData("outfitAttachments", attachments)
end

ITEM:Hook("drop", function(item)
	if (item:GetData("equip")) then
		local character = ix.char.loaded[item.owner]
		local client = character and character:GetPlayer() or item:GetOwner()

		if (IsValid(client)) then
			PlayRandomSound(client, item.unequipSound)
		end

		item.player = client
		item:RemoveOutfit(item:GetOwner())
	end
end)

ITEM.functions.EquipUn = { -- sorry, for name order.
	name = "unequip",
	tip = "unequipTip",
	icon = "icon16/cross.png",
	OnRun = function(item)
		local client = item.player
		PlayRandomSound(client, item.unequipSound)
		item:RemoveOutfit(client)
		return false
	end,
	OnCanRun = function(item)
		local client = item.player

		return !IsValid(item.entity) and IsValid(client) and item:GetData("equip") == true and
			hook.Run("CanPlayerUnequipItem", client, item) != false
	end
}

ITEM.functions.Equip = {
	name = "equip",
	tip = "equipTip",
	icon = "icon16/tick.png",
	OnRun = function(item)
		local client = item.player
		local char = client:GetCharacter()

		for k, _ in char:GetInventory():Iter() do
			if (k.id != item.id) then
				local itemTable = ix.item.instances[k.id]

				if (itemTable.pacData and k.outfitCategory == item.outfitCategory and itemTable:GetData("equip")) then
					client:NotifyLocalized(item.equippedNotify or "outfitAlreadyEquipped")
					return false
				end
			end
		end

		PlayRandomSound(client, item.equipSound)
		item:AddOutfit(client)
		return false
	end,
	OnCanRun = function(item)
		local client = item.player

		return !IsValid(item.entity) and IsValid(client) and item:GetData("equip") != true and item:CanEquipOutfit() and
			hook.Run("CanPlayerEquipItem", client, item) != false
	end
}

function ITEM:CanTransfer(oldInventory, newInventory)
	if (newInventory and self:GetData("equip")) then
		return false
	end

	return true
end

function ITEM:OnRemoved()
	if (self.invID != 0 and self:GetData("equip")) then
		self.player = self:GetOwner()
			self:RemoveOutfit(self.player)
		self.player = nil
	end
end

function ITEM:OnEquipped()
	hook.Run("OnItemEquipped", self, self:GetOwner())
end

function ITEM:OnUnequipped()
	hook.Run("OnItemUnequipped", self, self:GetOwner())
end

function ITEM:OnLoadout()
	if (self:GetData("equip")) then
		self:AddOutfit(self.player or self:GetOwner())
	end
end

function ITEM:CanEquipOutfit()
	return true
end

function ITEM:ShouldRestoreBodygroups()
	return true
end

function ITEM:ShouldRestoreSubMaterials()
	return true
end
