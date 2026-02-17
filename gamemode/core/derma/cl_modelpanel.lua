
DEFINE_BASECLASS("DModelPanel")

local PANEL = {}
local MODEL_ANGLE = Angle(0, 45, 0)

function PANEL:Init()
	self.brightness = 1
	self:SetCursor("arrow")
	self:SetMouseInputEnabled(true)
end

function PANEL:SetModel(model, skin, bodygroups)
	if (IsValid(self.Entity)) then
		self.Entity:Remove()
		self.Entity = nil
	end

	if (!ClientsideModel) then
		return
	end

	local entity = ClientsideModel(model, RENDERGROUP_OPAQUE)

	if (!IsValid(entity)) then
		return
	end

	entity:SetNoDraw(true)
	entity:SetIK(false)

	if (skin) then
		entity:SetSkin(skin)
	end

	if (isstring(bodygroups)) then
		entity:SetBodyGroups(bodygroups)
	end

	local sequence = entity:LookupSequence("idle_unarmed")

	if (sequence <= 0) then
		sequence = entity:SelectWeightedSequence(ACT_IDLE)
	end

	if (sequence > 0) then
		entity:ResetSequence(sequence)
	else
		local found = false

		for _, v in ipairs(entity:GetSequenceList()) do
			if ((v:lower():find("idle") or v:lower():find("fly")) and v != "idlenoise") then
				entity:ResetSequence(v)
				found = true

				break
			end
		end

		if (!found) then
			entity:ResetSequence(4)
		end
	end

	self.Entity = entity
end

function PANEL:LayoutEntity(entity)
	-- Enable smooth drag rotation
	if (self.bDragging) then
		local mx = gui.MouseX() - self.iDragStartX
		local my = gui.MouseY() - self.iDragStartY
		
		self.aLookAngle = self.aDragStartAngle + Angle(my * 0.5, -mx * 0.5, 0)
	end
	
	-- Set the model angle
	if (self.aLookAngle) then
		entity:SetAngles(self.aLookAngle)
	else
		entity:SetAngles(MODEL_ANGLE)
	end
	
	-- Update head tracking
	local scrW, scrH = ScrW(), ScrH()
	local xRatio = gui.MouseX() / scrW
	local yRatio = gui.MouseY() / scrH
	local x, _ = self:LocalToScreen(self:GetWide() / 2)
	local xRatio2 = x / scrW
	
	entity:SetPoseParameter("head_pitch", yRatio*90 - 30)
	entity:SetPoseParameter("head_yaw", (xRatio - xRatio2)*90 - 5)
	entity:SetIK(false)

	if (self.copyLocalSequence) then
		entity:SetSequence(LocalPlayer():GetSequence())
		entity:SetPoseParameter("move_yaw", 360 * LocalPlayer():GetPoseParameter("move_yaw") - 180)
	end

	self:RunAnimation()
end

function PANEL:OnMousePressed(code)
	if (code == MOUSE_LEFT) then
		self.bDragging = true
		self.iDragStartX = gui.MouseX()
		self.iDragStartY = gui.MouseY()
		self.aDragStartAngle = self.aLookAngle or MODEL_ANGLE
		self:MouseCapture(true)
	end
end

function PANEL:OnMouseReleased(code)
	if (code == MOUSE_LEFT) then
		self.bDragging = false
		self:MouseCapture(false)
	end
end

function PANEL:DrawModel()
	local brightness = self.brightness * 0.4
	local brightness2 = self.brightness * 1.5

	render.SetStencilEnable(false)
	render.SetColorMaterial()
	render.SetColorModulation(1, 1, 1)
	render.SetModelLighting(0, brightness2, brightness2, brightness2)

	for i = 1, 4 do
		render.SetModelLighting(i, brightness, brightness, brightness)
	end

	local fraction = (brightness / 1) * 0.1

	render.SetModelLighting(5, fraction, fraction, fraction)

	-- Excecute Some stuffs
	if (self.enableHook) then
		hook.Run("DrawHelixModelView", self, self.Entity)
	end

	self.Entity:DrawModel()

	if (self.enableHook) then
		hook.Run("PostDrawHelixModelView", self, self.Entity)
	end
end



vgui.Register("ixModelPanel", PANEL, "DModelPanel")
