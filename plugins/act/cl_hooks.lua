
local animationTime = 2

local PLUGIN = PLUGIN
PLUGIN.cameraFraction = 0

local function GetHeadBone(client)
	local head

	for i = 1, client:GetBoneCount() do
		local name = client:GetBoneName(i)

		if (string.find(name:lower(), "head")) then
			head = i
			break
		end
	end

	return head
end


function PLUGIN:ShouldDrawLocalPlayer(client)
	if (client:GetNetVar("actEnterAngle") and self.cameraFraction > 0.25) then
		return true
	elseif (self.cameraFraction > 0.25) then
		return true
	end
end

local forwardOffset = 16
local backwardOffset = -32
local heightOffset = Vector(0, 0, 20)
local idleHeightOffset = Vector(0, 0, 6)
local traceMin = Vector(-4, -4, -4)
local traceMax = Vector(4, 4, 4)

function PLUGIN:CalcView(client, origin)
	local enterAngle = client:GetNetVar("actEnterAngle")

	if (enterAngle and ix.plugin.Get("thirdperson") and ix.config.Get("thirdperson")) then
		return
	end

	local fraction = self.cameraFraction
	local offset = self.bIdle and forwardOffset or backwardOffset
	local height = self.bIdle and idleHeightOffset or heightOffset

	if (!enterAngle) then
		if (fraction > 0) then
			local view = {
				origin = LerpVector(fraction, origin, origin + self.forward * offset + height)
			}

			if (self.cameraTween) then
				self.cameraTween:update(FrameTime())
			end

			return view
		end

		return
	end

	local view = {}
	local forward = enterAngle:Forward()
	local head = GetHeadBone(client)

	local bFirstPerson = true

	if (ix.option.Get("thirdpersonEnabled", false)) then
		local originPosition = head and client:GetBonePosition(head) or client:GetPos()

		-- check if the camera will hit something
		local data = util.TraceHull({
			start = originPosition,
			endpos = originPosition - client:EyeAngles():Forward() * 48,
			mins = traceMin * 0.75,
			maxs = traceMax * 0.75,
			filter = client
		})

		bFirstPerson = data.Hit

		if (!bFirstPerson) then
			view.origin = data.HitPos
		end
	end

	if (bFirstPerson) then
		if (head) then
			local position = client:GetBonePosition(head) + forward * offset + height
			local data = {
				start = (client:GetBonePosition(head) or Vector(0, 0, 64)) + forward * 8,
				endpos = position + forward * offset,
				mins = traceMin,
				maxs = traceMax,
				filter = client
			}

			data = util.TraceHull(data)

			if (data.Hit) then
				view.origin = data.HitPos
			else
				view.origin = position
			end
		else
			view.origin = origin + forward * forwardOffset + height
		end
	end

	view.origin = LerpVector(fraction, origin, view.origin)

	if (self.cameraTween) then
		self.cameraTween:update(FrameTime())
	end

	return view
end

net.Receive("ixActEnter", function()
	PLUGIN.bIdle = net.ReadBool()
	PLUGIN.forward = LocalPlayer():GetNetVar("actEnterAngle"):Forward()
	PLUGIN.cameraTween = ix.tween.new(animationTime, PLUGIN, {
		cameraFraction = 1
	}, "outQuint")
end)

net.Receive("ixActLeave", function()
	PLUGIN.cameraTween = ix.tween.new(animationTime * 0.5, PLUGIN, {
		cameraFraction = 0
	}, "outQuint")
end)

local ghostEntity
local placementAct
local placementVariant
local placementAngle = 0

local function RemoveGhost()
	if (IsValid(ghostEntity)) then
		ghostEntity:Remove()
		ghostEntity = nil
	end

	placementAct = nil
	placementVariant = nil
	placementAngle = 0
end

net.Receive("ixActPlacementStart", function()
	placementAct = net.ReadString()
	placementVariant = net.ReadUInt(8)

	local client = LocalPlayer()
	local model = client:GetModel()

	if (IsValid(ghostEntity)) then
		ghostEntity:Remove()
	end

	ghostEntity = ClientsideModel(model)
	ghostEntity:SetNoDraw(true)
	ghostEntity:SetRenderMode(RENDERMODE_TRANSCOLOR)

	placementAngle = client:GetAngles().y

	-- Find the sequence to display
	local classes = ix.act.stored[placementAct]
	if (classes) then
		local modelClass = ix.anim.GetModelClass(model)
		local data = classes[modelClass]

		if (data) then
			local sequence = data.sequence[placementVariant]
			if (istable(sequence)) then
				sequence = sequence[1]
			end

			local sequenceID = ghostEntity:LookupSequence(sequence)
			if (sequenceID != -1) then
				ghostEntity:SetSequence(sequenceID)
				ghostEntity:SetCycle(0)
			end
		end
	end
end)

local placementValid = false

function PLUGIN:PlayerBindPress(client, bind, bPressed)
	if (client:GetNetVar("actEnterAngle")) then
		if (bind:find("+jump") and bPressed) then
			ix.command.Send("ExitAct")
			return true
		end
	end

	if (IsValid(ghostEntity)) then
		if (bPressed) then
			if (bind:find("+attack2")) then
				RemoveGhost()
				return true
			elseif (bind:find("+attack")) then
				if (!placementValid) then
					client:NotifyLocalized("invalidPlacement")
					return true
				end

				local trace = util.TraceHull({
					start = client:EyePos(),
					endpos = client:EyePos() + client:GetForward() * 100,
					filter = {client, ghostEntity},
					mins = Vector(-16, -16, 0),
					maxs = Vector(16, 16, 72)
				})

				local angles = Angle(0, placementAngle, 0)

				net.Start("ixActRequest")
					net.WriteString(placementAct)
					net.WriteUInt(placementVariant, 8)
					net.WriteVector(trace.HitPos)
					net.WriteAngle(angles)
				net.SendToServer()

				RemoveGhost()
				return true
			elseif (bind:find("invprev")) then
				placementAngle = placementAngle + 5
				return true
			elseif (bind:find("invnext")) then
				placementAngle = placementAngle - 5
				return true
			end
		end

		if (bind:find("+attack") or bind:find("+attack2")) then
			return true
		end
	end
end

function PLUGIN:Think()
	if (IsValid(ghostEntity)) then
		local client = LocalPlayer()
		local trace = util.TraceHull({
			start = client:EyePos(),
			endpos = client:EyePos() + client:GetForward() * 100,
			filter = {client, ghostEntity},
			mins = Vector(-16, -16, 0),
			maxs = Vector(16, 16, 72)
		})

		ghostEntity:SetPos(trace.HitPos)
		ghostEntity:SetAngles(Angle(0, placementAngle, 0))

		local bHeightPass = math.abs(trace.HitPos.z - client:GetPos().z) <= 60

		local bActCheckPass = true
		local bIgnoreCollision = false
		local classes = ix.act.stored[placementAct]
		if (classes) then
			local modelClass = ix.anim.GetModelClass(client:GetModel())
			local data = classes[modelClass]

			if (data) then
				local sequence = data.sequence[placementVariant]
				if (istable(sequence)) then
					if (sequence.check) then
						bActCheckPass = !sequence.check(client, trace.HitPos, Angle(0, placementAngle, 0))
					end
					if (sequence.ignoreCollision) then
						bIgnoreCollision = true
					end
				end
			end
		end

		local checkTrace
		if (bIgnoreCollision) then
			-- Relaxed collision
			checkTrace = util.TraceHull({
				start = trace.HitPos + Vector(0, 0, 25),
				endpos = trace.HitPos + Vector(0, 0, 25),
				mins = Vector(-6, -6, 0),
				maxs = Vector(6, 6, 35),
				filter = {client, ghostEntity}
			})
		else
			-- General collision check
			checkTrace = util.TraceHull({
				start = trace.HitPos + Vector(0, 0, 5),
				endpos = trace.HitPos + Vector(0, 0, 5),
				mins = Vector(-12, -12, 0),
				maxs = Vector(12, 12, 60),
				filter = {client, ghostEntity}
			})
		end

		-- Allow overlapping with simple props (like chairs) if they aren't players/NPCs, just check if we are stuck
		local bCollisionHit = checkTrace.StartSolid or (IsValid(checkTrace.Entity) and (checkTrace.Entity:IsPlayer() or checkTrace.Entity:IsNPC()))

		-- Path validation: Cannot phase through walls (simple line trace)
		local pathTrace = util.TraceLine({
			start = client:EyePos(),
			endpos = trace.HitPos + Vector(0, 0, 10),
			filter = {client, ghostEntity}
		})



		placementValid = !bCollisionHit and !pathTrace.Hit and bActCheckPass and bHeightPass
	end
end

function PLUGIN:PostDrawTranslucentRenderables()
	if (IsValid(ghostEntity)) then
		if (placementValid) then
			render.SetColorModulation(0.5, 1, 0.5)
		else
			render.SetColorModulation(1, 0.5, 0.5)
		end

		render.SetBlend(0.6)
			ghostEntity:DrawModel()
		render.SetBlend(1)
		render.SetColorModulation(1, 1, 1)
	end
end

function PLUGIN:HUDPaint()
	if (IsValid(ghostEntity)) then
		local text = L("actPlacementHint")
		surface.SetFont("ixMediumFont")
		local w, h = surface.GetTextSize(text)
		
		surface.SetDrawColor(0, 0, 0, 150)
		surface.DrawRect(ScrW() / 2 - w / 2 - 10, ScrH() * 0.8, w + 20, h + 10)
		
		draw.SimpleText(text, "ixMediumFont", ScrW() / 2, ScrH() * 0.8 + 5, color_white, TEXT_ALIGN_CENTER)
	end
end

function PLUGIN:OnCharacterMenuClosed()
	RemoveGhost()
end

function PLUGIN:OnCharacterLoad()
	RemoveGhost()
end
