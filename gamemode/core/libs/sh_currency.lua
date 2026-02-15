
--- A library representing the server's currency system.
-- @module ix.currency

ix.currency = ix.currency or {}
ix.currency.symbol = ix.currency.symbol or "$"
ix.currency.singular = ix.currency.singular or "dollar"
ix.currency.plural = ix.currency.plural or "dollars"
ix.currency.model = ix.currency.model or "models/props_lab/box01a.mdl"

--- Sets the currency type.
-- @realm shared
-- @string symbol The symbol of the currency.
-- @string singular The name of the currency in it's singular form.
-- @string plural The name of the currency in it's plural form.
-- @string model The model of the currency entity.
function ix.currency.Set(symbol, singular, plural, model)
	ix.currency.symbol = symbol
	ix.currency.singular = singular
	ix.currency.plural = plural
	ix.currency.model = model
end

--- Returns a formatted string according to the current currency.
-- @realm shared
-- @number amount The amount of cash being formatted.
-- @player client Optional client for server-side localization.
-- @treturn string The formatted string.
function ix.currency.Get(amount, client)
	local singular, plural
	
	if (CLIENT) then
		-- Try to localize, fall back to literal string if not a language key
		singular = L2(ix.currency.singular) or ix.currency.singular
		plural = L2(ix.currency.plural) or ix.currency.plural
	else
		-- Server-side: use client parameter for localization if provided
		if (client) then
			singular = L2(ix.currency.singular, client) or ix.currency.singular
			plural = L2(ix.currency.plural, client) or ix.currency.plural
		else
			-- No client provided, use literal strings
			singular = ix.currency.singular
			plural = ix.currency.plural
		end
	end
	
	if (amount == 1) then
		return ix.currency.symbol.."1 "..singular
	else
		return ix.currency.symbol..amount.." "..plural
	end
end

--- Spawns an amount of cash at a specific location on the map.
-- @realm shared
-- @vector pos The position of the money to be spawned.
-- @number amount The amount of cash being spawned.
-- @angle[opt=angle_zero] angle The angle of the entity being spawned.
-- @treturn entity The spawned money entity.
function ix.currency.Spawn(pos, amount, angle)
	if (!amount or amount < 0) then
		print("[Helix] Can't create currency entity: Invalid Amount of money")
		return
	end

	local money = ents.Create("ix_money")
	money:Spawn()

	if (IsValid(pos) and pos:IsPlayer()) then
		pos = pos:GetItemDropPos(money)
	elseif (!isvector(pos)) then
		print("[Helix] Can't create currency entity: Invalid Position")

		money:Remove()
		return
	end

	money:SetPos(pos)
	-- double check for negative.
	money:SetAmount(math.Round(math.abs(amount)))
	money:SetAngles(angle or angle_zero)
	money:Activate()

	return money
end

function GM:OnPickupMoney(client, moneyEntity)
	if (IsValid(moneyEntity)) then
		local amount = moneyEntity:GetAmount()

		client:GetCharacter():GiveMoney(amount)
	end
end

do
	local character = ix.meta.character

	function character:HasMoney(amount)
		if (amount < 0) then
			print("Negative Money Check Received.")
		end

		return self:GetMoney() >= amount
	end

	function character:GiveMoney(amount, bNoLog)
		amount = math.abs(amount)

		if (!bNoLog) then
			ix.log.Add(self:GetPlayer(), "money", amount)
		end

		self:SetMoney(self:GetMoney() + amount)

		return true
	end

	function character:TakeMoney(amount, bNoLog)
		amount = math.abs(amount)

		if (!bNoLog) then
			ix.log.Add(self:GetPlayer(), "money", -amount)
		end

		self:SetMoney(self:GetMoney() - amount)

		return true
	end
end
