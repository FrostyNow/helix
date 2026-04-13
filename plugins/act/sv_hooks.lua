
local PLUGIN = PLUGIN

util.AddNetworkString("ixActEnter")
util.AddNetworkString("ixActLeave")
util.AddNetworkString("ixActPlacementStart")
util.AddNetworkString("ixActRequest")

function PLUGIN:CanPlayerEnterAct(client, modelClass, variant, act)
	if (!client:Alive() or client:GetLocalVar("ragdoll") or client:WaterLevel() > 0 or !client:IsOnGround()) then
		return false, L("notNow", client)
	end

	-- check if player's model class has an entry in this act table
	modelClass = modelClass or ix.anim.GetModelClass(client:GetModel())
	local data = act[modelClass]

	if (!data) then
		return false, L("modelNoSeq", client)
	end

	-- some models don't support certain variants
	local sequence = data.sequence[variant]

	if (!sequence) then
		return false, L("modelNoSeq", client)
	end

	return true
end

function PLUGIN:PlayerDeath(client)
	if (client.ixUntimedSequence) then
		client:SetNetVar("actEnterAngle")
		client:LeaveSequence()
		client.ixUntimedSequence = nil
	end
end

function PLUGIN:PlayerSpawn(client)
	if (client.ixUntimedSequence) then
		client:SetNetVar("actEnterAngle")
		client:LeaveSequence()
		client.ixUntimedSequence = nil
	end
end

function PLUGIN:OnCharacterFallover(client)
	if (client.ixUntimedSequence) then
		client:SetNetVar("actEnterAngle")
		client:LeaveSequence()
		client.ixUntimedSequence = nil
	end
end

function PLUGIN:PerformAct(client, actID, variant, pos, ang, bNoVerify)
	local classes = ix.act.stored[actID]
	if (!classes) then return end

	local modelClass = ix.anim.GetModelClass(client:GetModel())
	local bCanEnter, error = PLUGIN:CanPlayerEnterAct(client, modelClass, variant, classes)

	if (!bCanEnter) then
		client:NotifyLocalized(error)
		return
	end

	if (!bNoVerify) then
		-- Distance validation (to prevent teleporting across the map)
		if (client:GetPos():DistToSqr(pos) > 100 * 100) then
			client:NotifyLocalized("tooFar")
			return
		end
		
		-- Height validation (cannot jump to very high or very low places)
		if (math.abs(pos.z - client:GetPos().z) > 60) then
			client:NotifyLocalized("invalidPlacement")
			return
		end

		local data = classes[modelClass]
		local mainSequence = data.sequence[variant]
		local bIgnoreCollision = false

		if (istable(mainSequence) and mainSequence.ignoreCollision) then
			bIgnoreCollision = true
		end

		local checkFilter = function(ent)
			if (ent == client) then
				return false
			end

			if (bIgnoreCollision and IsValid(ent) and ent:GetClass():find("prop_")) then
				return false
			end

			return true
		end

		local checkTrace
		if (bIgnoreCollision) then
			-- Relaxed collision: Only check upper core (Z=25 to Z=60) to allow sitting on seats but prevent hiding in walls/crates
			checkTrace = util.TraceHull({
				start = pos + Vector(0, 0, 25),
				endpos = pos + Vector(0, 0, 25),
				mins = Vector(-6, -6, 0),
				maxs = Vector(6, 6, 35),
				filter = checkFilter
			})
		else
			-- Strict collision: Check full body
			checkTrace = util.TraceHull({
				start = pos + Vector(0, 0, 5),
				endpos = pos + Vector(0, 0, 5),
				mins = Vector(-12, -12, 0),
				maxs = Vector(12, 12, 60),
				filter = checkFilter
			})
		end

		if (checkTrace.StartSolid or (IsValid(checkTrace.Entity) and (checkTrace.Entity:IsPlayer() or checkTrace.Entity:IsNPC()))) then
			client:NotifyLocalized("invalidPlacement")
			return
		end

		-- Path validation: Cannot phase through walls (simple line trace)
		local pathTrace = util.TraceLine({
			start = client:EyePos(),
			endpos = pos + Vector(0, 0, 10),
			filter = checkFilter
		})

		if (pathTrace.Hit) then
			client:NotifyLocalized("invalidPath")
			return
		end

		-- Ground check: Slightly more generous search range
		local groundTrace = util.TraceLine({
			start = pos + Vector(0, 0, 15),
			endpos = pos - Vector(0, 0, 30),
			filter = client
		})

		if (!groundTrace.Hit) then
			client:NotifyLocalized("invalidPlacement")
			return
		end
	end

	local data = classes[modelClass]
	local mainSequence = data.sequence[variant]
	local mainDuration

	-- Handle sequence data (offset, check, etc)
	if (istable(mainSequence)) then
		if (mainSequence.check) then
			local result = mainSequence.check(client, pos, ang)
			if (result) then
				client:NotifyLocalized(result)
				return
			end
		end

		if (mainSequence.offset) then
			pos = pos + mainSequence.offset(client)
		end

		mainDuration = mainSequence.duration
		mainSequence = mainSequence[1]
	end

	local startSequence = data.start and data.start[variant] or ""
	local startDuration

	if (istable(startSequence)) then
		startDuration = startSequence.duration
		startSequence = startSequence[1]
	end

	client:SetNetVar("actEnterAngle", ang)
	client:SetPos(pos)

	client:ForceSequence(startSequence, function()
		client.ixUntimedSequence = data.untimed
		local duration = client:ForceSequence(mainSequence, function()
			if (data.finish) then
				local finishSequence = data.finish[variant]
				local finishDuration

				if (istable(finishSequence)) then
					finishDuration = finishSequence.duration
					finishSequence = finishSequence[1]
				end

				client:ForceSequence(finishSequence, function()
					PLUGIN:ExitAct(client)
				end, finishDuration)
			else
				PLUGIN:ExitAct(client)
			end
		end, data.untimed and 0 or (mainDuration or nil))

		if (!duration) then
			PLUGIN:ExitAct(client)
			client:NotifyLocalized("modelNoSeq")
			return
		end
	end, startDuration, nil)

	net.Start("ixActEnter")
		net.WriteBool(data.idle or false)
	net.Send(client)

	client.ixNextAct = CurTime() + 4
end

net.Receive("ixActRequest", function(len, client)
	local actID = net.ReadString()
	local variant = net.ReadUInt(8)
	local pos = net.ReadVector()
	local ang = net.ReadAngle()

	PLUGIN:PerformAct(client, actID, variant, pos, ang, false)
end)
