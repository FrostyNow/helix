
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

net.Receive("ixActRequest", function(len, client)
	local actID = net.ReadString()
	local variant = net.ReadUInt(8)
	local pos = net.ReadVector()
	local ang = net.ReadAngle()

	local classes = ix.act.stored[actID]
	if (!classes) then return end

	local modelClass = ix.anim.GetModelClass(client:GetModel())
	local bCanEnter, error = PLUGIN:CanPlayerEnterAct(client, modelClass, variant, classes)

	if (!bCanEnter) then
		client:NotifyLocalized(error)
		return
	end

	-- Distance validation (to prevent teleporting across the map)
	if (client:GetPos():DistToSqr(pos) > 100 * 100) then
		client:NotifyLocalized("tooFar")
		return
	end

	-- Collision validation: target must be clear (Slightly relaxed hull for sync tolerance)
	local checkTrace = util.TraceHull({
		start = pos + Vector(0, 0, 5),
		endpos = pos + Vector(0, 0, 5),
		mins = Vector(-13, -13, 0),
		maxs = Vector(13, 13, 65),
		filter = client
	})

	if (checkTrace.Hit) then
		client:NotifyLocalized("invalidPlacement")
		return
	end

	-- Path validation: Cannot phase through walls (Slightly relaxed hull)
	local pathTrace = util.TraceHull({
		start = client:GetPos() + Vector(0, 0, 10),
		endpos = pos + Vector(0, 0, 10),
		mins = Vector(-10, -10, 5),
		maxs = Vector(10, 10, 55),
		filter = client
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

	local data = classes[modelClass]
	local mainSequence = data.sequence[variant]
	local mainDuration

	-- Handle sequence data (offset, check, etc)
	if (istable(mainSequence)) then
		if (mainSequence.check) then
			local result = mainSequence.check(client)
			if (result) then
				client:NotifyLocalized(result)
				return
			end
		end

		-- We'll use the user-provided position and angle instead of the default offset logic
		-- unless the user specifically wanted the offset to still apply?
		-- Actually, the user's intent is that THEY place the model.
		-- So we should use the provided pos/ang.

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
end)
