
ITEM.name = "Ammo Base"
ITEM.model = "models/Items/BoxSRounds.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.ammo = "pistol" -- type of the ammo
ITEM.ammoAmount = 30 -- amount of the ammo
ITEM.description = "A Box that contains %s of Pistol Ammo"
ITEM.category = "Ammunition"
ITEM.useSound = "items/ammo_pickup.wav"
ITEM.ammoClip = nil -- How many rounds to use at once. If nil, use all.

function ITEM:GetDescription()
	return Format(L(self.description, self.ammoAmount))
end

if (CLIENT) then
	function ITEM:PaintOver(item, w, h)
		draw.SimpleText(
			item:GetData("rounds", item.ammoAmount), "DermaDefault", w - 5, h - 5,
			color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, 1, color_black
		)
	end
end

-- On player uneqipped the item, Removes a weapon from the player and keep the ammo in the item.
ITEM.functions.use = {
	name = "Load",
	tip = "useTip",
	icon = "icon16/add.png",
	OnRun = function(item)
		local client = item.player
		local rounds = item:GetData("rounds", item.ammoAmount)
		local currentAmmo = client:GetAmmoCount(item.ammo)
		local maxAmmo = game.GetAmmoMax(game.GetAmmoID(item.ammo))

		if (maxAmmo ~= -1 and currentAmmo >= maxAmmo) then
			client:NotifyLocalized("maxAmmoReached")
			return false
		end

		local amountToGive = item.ammoClip and math.min(rounds, item.ammoClip) or rounds

		if (maxAmmo ~= -1 and currentAmmo + amountToGive > maxAmmo) then
			amountToGive = maxAmmo - currentAmmo
		end

		client:GiveAmmo(amountToGive, item.ammo)
		client:EmitSound(item.useSound, 110)

		local remaining = rounds - amountToGive

		if (remaining > 0) then
			item:SetData("rounds", remaining)
			return false
		end

		return true
	end,
}

ITEM.functions.useall = {
	name = "Load All",
	tip = "useTip",
	icon = "icon16/accept.png",
	OnRun = function(item)
		local client = item.player
		local rounds = item:GetData("rounds", item.ammoAmount)
		local currentAmmo = client:GetAmmoCount(item.ammo)
		local maxAmmo = game.GetAmmoMax(game.GetAmmoID(item.ammo))

		if (maxAmmo ~= -1 and currentAmmo >= maxAmmo) then
			client:NotifyLocalized("maxAmmoReached")
			return false
		end

		local amountToGive = rounds

		if (maxAmmo ~= -1 and currentAmmo + amountToGive > maxAmmo) then
			amountToGive = maxAmmo - currentAmmo
		end

		client:GiveAmmo(amountToGive, item.ammo)
		client:EmitSound(item.useSound, 110)

		local remaining = rounds - amountToGive

		if (remaining > 0) then
			item:SetData("rounds", remaining)
			return false
		end

		return true
	end,
	OnCanRun = function(item)
		return item.ammoClip ~= nil
	end
}

-- Called after the item is registered into the item tables.
function ITEM:OnRegistered()
	if (ix.ammo) then
		ix.ammo.Register(self.ammo)
	end
end