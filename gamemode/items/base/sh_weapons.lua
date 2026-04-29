
ITEM.name = "Weapon"
ITEM.description = "A Weapon."
ITEM.category = "Weapons"
ITEM.model = "models/weapons/w_pistol.mdl"
ITEM.class = "weapon_pistol"
ITEM.width = 2
ITEM.height = 2
ITEM.isWeapon = true
ITEM.isGrenade = false
ITEM.weaponCategory = "sidearm"
ITEM.useSound = "items/ammo_pickup.wav"

-- Inventory drawing
if (CLIENT) then
	function ITEM:PaintOver(item, w, h)
		if (item:GetData("equip")) then
			surface.SetDrawColor(110, 255, 110, 100)
			surface.DrawRect(w - 14, h - 14, 8, 8)
		end

		local ammo = item:GetData("ammo")
		if (ammo and ammo > 0) then
			draw.SimpleTextOutlined(ammo, "DermaDefault", w - 5, h - 5, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, 1, color_black)
		end
	end

	function ITEM:PopulateTooltip(tooltip)
		if (self:GetData("equip")) then
			local name = tooltip:GetRow("name")
			name:SetBackgroundColor(derma.GetColor("Success", tooltip))
		end
	end
end

-- On item is dropped, Remove a weapon from the player and keep the ammo in the item.
ITEM:Hook("drop", function(item)
	local inventory = ix.item.inventories[item.invID]

	if (!inventory) then
		return
	end

	-- the item could have been dropped by someone else (i.e someone searching this player), so we find the real owner
	local owner

	for client, character in ix.util.GetCharacters() do
		if (character:GetID() == inventory.owner) then
			owner = client
			break
		end
	end

	if (!IsValid(owner)) then
		return
	end

	if (item:GetData("equip")) then
		item:SetData("equip", nil)

		owner.carryWeapons = owner.carryWeapons or {}

		local weapon = owner.carryWeapons[item.weaponCategory]

		if (!IsValid(weapon)) then
			weapon = owner:GetWeapon(item.class)
		end

		if (IsValid(weapon)) then
			item:SetData("ammo", weapon:Clip1())

			owner:StripWeapon(item.class)
			owner.carryWeapons[item.weaponCategory] = nil
			owner:EmitSound(item.useSound, 80)
		end

		item:RemovePAC(owner)
	end
end)

-- On player uneqipped the item, Removes a weapon from the player and keep the ammo in the item.
ITEM.functions.EquipUn = { -- sorry, for name order.
	name = "unequip",
	tip = "unequipTip",
	icon = "icon16/cross.png",
	OnRun = function(item)
		item:Unequip(item.player, true)
		return false
	end,
	OnCanRun = function(item)
		local client = item.player

		return !IsValid(item.entity) and IsValid(client) and item:GetData("equip") == true and
			hook.Run("CanPlayerUnequipItem", client, item) != false
	end
}

ITEM.functions.Unclip = {
	name = "unclip",
	tip = "unclipTip",
	icon = "icon16/bullet_go.png",
	OnRun = function(item)
		local client = item.player
		local weapon = client.carryWeapons and client.carryWeapons[item.weaponCategory]

		if (!IsValid(weapon)) then
			weapon = client:GetWeapon(item.class)
		end

		if (!IsValid(weapon)) then return false end

		local clip = weapon:Clip1()
		if (clip <= 0) then return false end

		weapon:SetClip1(0)
		item:SetData("ammo", 0)

		local inventory = client:GetCharacter():GetInventory()
		local bSuccess = inventory:Add(item.clip)

		if (!bSuccess) then
			weapon:SetClip1(clip)
			item:SetData("ammo", clip)
			client:NotifyLocalized("invFull")
		end

		return false
	end,
	OnCanRun = function(item)
		local client = item.player

		if (!IsValid(client) or !item.clip or item:GetData("equip") != true) then
			return false
		end

		local weapon = client.carryWeapons and client.carryWeapons[item.weaponCategory]
		if (!IsValid(weapon)) then
			weapon = client:GetWeapon(item.class)
		end

		return IsValid(weapon) and weapon:Clip1() > 0
	end
}

-- On player eqipped the item, Gives a weapon to player and load the ammo data from the item.
ITEM.functions.Equip = {
	name = "equip",
	tip = "equipTip",
	icon = "icon16/tick.png",
	OnRun = function(item)
		item:Equip(item.player)
		return false
	end,
	OnCanRun = function(item)
		local client = item.player

		if (IsValid(client)) then
			local character = client:GetCharacter()

			if (character) then
				local faction = ix.faction.indices[character:GetFaction()]

				if (faction and faction.excludedItemBases and table.HasValue(faction.excludedItemBases, item.base or "")) then
					return false
				end
			end
		end

		return !IsValid(item.entity) and IsValid(client) and item:GetData("equip") != true and
			hook.Run("CanPlayerEquipItem", client, item) != false
	end
}

function ITEM:WearPAC(client)
	if (ix.pac and self.pacData) then
		client:AddPart(self.uniqueID, self)
	end
end

function ITEM:RemovePAC(client)
	if (ix.pac and self.pacData) then
		client:RemovePart(self.uniqueID)
	end
end

function ITEM:Equip(client, bNoSelect, bNoSound)
	local character = client:GetCharacter()

	if (character) then
		local faction = ix.faction.indices[character:GetFaction()]

		if (faction and faction.excludedItemBases and table.HasValue(faction.excludedItemBases, self.base or "")) then
			return false
		end
	end

	client.carryWeapons = client.carryWeapons or {}

	for _, k in pairs(client:GetCharacter():GetInventory():GetItems()) do
		if (k.id != self.id) then
			local itemTable = ix.item.instances[k.id]

			if (!itemTable) then
				client:NotifyLocalized("tellAdmin", "wid!xt")

				return false
			else
				if (itemTable.isWeapon and client.carryWeapons[self.weaponCategory] and itemTable:GetData("equip")) then
					client:NotifyLocalized("weaponSlotFilled", self.weaponCategory)

					return false
				end
			end
		end
	end

	if (client:HasWeapon(self.class)) then
		client:StripWeapon(self.class)
	end

	local weapon = client:Give(self.class, !self.isGrenade)

	if (IsValid(weapon)) then
		local ammoType = weapon:GetPrimaryAmmoType()

		client.carryWeapons[self.weaponCategory] = weapon

		if (!bNoSelect) then
			client:SelectWeapon(weapon:GetClass())
		end

		if (!bNoSound) then
			client:EmitSound(self.useSound, 80)
		end

		-- Remove default given ammo.
		if (!self.isGrenade and client:GetAmmoCount(ammoType) == weapon:Clip1() and self:GetData("ammo", 0) == 0) then
			client:RemoveAmmo(weapon:Clip1(), ammoType)
		end

		-- assume that a weapon with -1 clip1 and clip2 would be a throwable (i.e hl2 grenade)
		-- TODO: figure out if this interferes with any other weapons
		if (weapon:GetMaxClip1() == -1 and weapon:GetMaxClip2() == -1 and client:GetAmmoCount(ammoType) == 0) then
			client:SetAmmo(1, ammoType)
		end

		self:SetData("equip", true)

		if (self.isGrenade) then
			weapon:SetClip1(1)

			if (ammoType and ammoType != -1) then
				client:SetAmmo(1, ammoType)
			end
		else
			weapon:SetClip1(self:GetData("ammo", 0))
		end

		weapon.ixItem = self

		if (self.OnEquipWeapon) then
			self:OnEquipWeapon(client, weapon)
		end

		self:OnEquipped()
	else
		print(Format("[Helix] Cannot equip weapon - %s does not exist!", self.class))
	end
end

function ITEM:ConsumeGrenade(client, weapon)
	if (!self.isGrenade or !IsValid(client) or self.bPendingRemoval or ix.item.instances[self.id] != self) then
		return false
	end

	client.carryWeapons = client.carryWeapons or {}
	weapon = IsValid(weapon) and weapon or client.carryWeapons[self.weaponCategory]

	if (!IsValid(weapon)) then
		weapon = client:GetWeapon(self.class)
	end

	self.bPendingRemoval = true
	client.carryWeapons[self.weaponCategory] = nil
	self:SetData("ammo", 0)
	self:SetData("equip", nil)
	self:RemovePAC(client)

	if (IsValid(weapon)) then
		weapon.bStrippingGrenade = true
		weapon.ixItem = nil
		client:StripWeapon(self.class)
	end

	if (self.OnUnequipWeapon) then
		self:OnUnequipWeapon(client, weapon)
	end

	return self:Remove()
end

function ITEM:Unequip(client, bPlaySound, bRemoveItem)
	client.carryWeapons = client.carryWeapons or {}

	if (bRemoveItem and self.isGrenade) then
		return self:ConsumeGrenade(client)
	end

	self.bPendingRemoval = bRemoveItem == true

	local weapon = client.carryWeapons[self.weaponCategory]

	if (!IsValid(weapon)) then
		weapon = client:GetWeapon(self.class)
	end

	if (IsValid(weapon)) then
		weapon.ixItem = nil

		self:SetData("ammo", weapon:Clip1())
		client:StripWeapon(self.class)
	else
		print(Format("[Helix] Cannot unequip weapon - %s does not exist!", self.class))
	end

	if (bPlaySound) then
		client:EmitSound(self.useSound, 80)
	end

	client.carryWeapons[self.weaponCategory] = nil
	self:SetData("equip", nil)
	self:RemovePAC(client)

	if (self.OnUnequipWeapon) then
		self:OnUnequipWeapon(client, weapon)
	end

	self:OnUnequipped()

	if (bRemoveItem) then
		self:Remove()
	else
		self.bPendingRemoval = nil
	end
end

function ITEM:CanTransfer(oldInventory, newInventory)
	if (newInventory and self:GetData("equip")) then
		local owner = self:GetOwner()

		if (IsValid(owner)) then
			owner:NotifyLocalized("equippedWeapon")
		end

		return false
	end

	return true
end

function ITEM:OnLoadout()
	if (self:GetData("equip")) then
		local client = self.player or self:GetOwner()

		if (!IsValid(client)) then
			return
		end

		client.carryWeapons = client.carryWeapons or {}

		local character = client:GetCharacter()

		if (character) then
			local faction = ix.faction.indices[character:GetFaction()]

			if (faction and faction.excludedItemBases and table.HasValue(faction.excludedItemBases, self.base or "")) then
				self:SetData("equip", nil)
				return
			end
		end

		local weapon = client:Give(self.class, true)

		if (IsValid(weapon)) then
			local ammoType = weapon:GetPrimaryAmmoType()

			if (!self.isGrenade) then
				client:RemoveAmmo(weapon:Clip1(), ammoType)
			end
			
			client.carryWeapons[self.weaponCategory] = weapon
			weapon.ixItem = self

			if (self.isGrenade) then
				weapon:SetClip1(1)

				if (ammoType and ammoType != -1) then
					client:SetAmmo(1, ammoType)
				end
			else
				weapon:SetClip1(self:GetData("ammo", 0))
			end

			if (self.OnEquipWeapon) then
				self:OnEquipWeapon(client, weapon)
			end
		else
			print(Format("[Helix] Cannot give weapon - %s does not exist!", self.class))
		end
	end
end

function ITEM:OnSave()
	local weapon = self.player:GetWeapon(self.class)

	if (IsValid(weapon) and weapon.ixItem == self and self:GetData("equip")) then
		self:SetData("ammo", weapon:Clip1())
	end
end

function ITEM:OnRemoved()
	local inventory = ix.item.inventories[self.invID]
	local owner = inventory.GetOwner and inventory:GetOwner()

	if (IsValid(owner) and owner:IsPlayer()) then
		local weapon = owner:GetWeapon(self.class)

		if (IsValid(weapon)) then
			weapon:Remove()
		end

		self:RemovePAC(owner)
	end
end

hook.Add("PlayerDeath", "ixStripClip", function(client)
	local character = client:GetCharacter()

	if (!character) then
		return
	end

	client.carryWeapons = client.carryWeapons or {}

	for _, k in pairs(character:GetInventory():GetItems()) do
		if (k.isWeapon and k:GetData("equip")) then
			local weapon = client.carryWeapons[k.weaponCategory]

			if (!IsValid(weapon)) then
				weapon = client:GetWeapon(k.class)
			end

			if (k.isGrenade) then
				local ammo = k:GetData("ammo", 0)

				if (IsValid(weapon)) then
					local ammoType = weapon:GetPrimaryAmmoType()
					ammo = math.max(weapon:Clip1(), 0)

					if (ammoType and ammoType != -1) then
						ammo = math.max(ammo, client:GetAmmoCount(ammoType))
					end
				end

				if (ammo <= 0) then
					k:ConsumeGrenade(client, weapon)
					continue
				end

				k:SetData("ammo", ammo)
			else
				k:SetData("ammo", nil)
			end

			k:SetData("equip", nil)

			if (k.pacData) then
				k:RemovePAC(client)
			end

			k:OnUnequipped()
		end
	end

	client.carryWeapons = {}
end)

hook.Add("EntityRemoved", "ixRemoveGrenade", function(entity)
	local item = entity.ixItem

	-- hack to remove grenades after they've all been thrown
	if (item and !item.bPendingRemoval and item:GetData("equip") == true and (item.weaponCategory == "grenade" or item.class == "grenade" or item.isGrenade)) then
		local client = entity:GetOwner()

		if (!IsValid(client)) then
			client = item:GetOwner()
		end

		if (IsValid(client) and client:IsPlayer() and client:GetCharacter()) then
			local ammoType = entity:GetPrimaryAmmoType()

			-- Allow ammoType == -1 for custom SWEPs that do not use default ammo
			if (ammoType == -1 or client:GetAmmoCount(ammoType) <= 0) then
				item:ConsumeGrenade(client, entity)
			end
		end
	end
end)

function ITEM:OnEquipped()
	hook.Run("OnItemEquipped", self, self:GetOwner())
end

function ITEM:OnUnequipped()
	hook.Run("OnItemUnequipped", self, self:GetOwner())
end

function ITEM:OnEquip()
	self:Equip(self.player)
end

function ITEM:OnUnequip()
	self:Unequip(self.player, true)
end

if (SERVER) then
	hook.Add("PlayerTick", "ixGrenadeCheck", function(client)
		if (!client:Alive() or !client:GetCharacter() or !client.carryWeapons) then return end

		for k, weapon in pairs(client.carryWeapons) do
			if (IsValid(weapon) and weapon.ixItem and weapon.ixItem.isGrenade and not weapon.bStrippingGrenade) then
				local ammoType = weapon:GetPrimaryAmmoType()

				if (weapon:Clip1() <= 0 and (ammoType == -1 or client:GetAmmoCount(ammoType) <= 0)) then
					weapon.bStrippingGrenade = true
					local item = weapon.ixItem

					if (item and IsValid(client) and item:GetData("equip") == true) then
						item:ConsumeGrenade(client, weapon)
					end
				end
			end
		end
	end)
end
