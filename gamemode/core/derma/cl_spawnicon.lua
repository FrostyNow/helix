
DEFINE_BASECLASS("DModelPanel")

local PANEL = {}

local function SelectPreferredSequence(entity)
	if (!IsValid(entity)) then
		return false
	end

	local modelClass = ix.anim.GetModelClass(entity:GetModel())
	local preferredSequences = {
		citizen_male = {"lineidle01", "lineidle02", "lineidle03", "lineidle04", "idle_unarmed"},
		citizen_female = {"lineidle01", "lineidle02", "lineidle03", "idle_unarmed"},
		metrocop = {"plazathreat2", "idle_baton", "idle_smg1", "idle_unarmed"},
		overwatch = {"idle_subtle", "idle_relaxed", "idle_angry", "idle_all_01", "idle_smg1", "idle_unarmed"}
	}
	local preferredActivities = {
		citizen_male = {ACT_IDLE},
		citizen_female = {ACT_IDLE},
		metrocop = {ACT_IDLE_ANGRY_SMG1, ACT_IDLE_SMG1, ACT_IDLE},
		overwatch = {ACT_IDLE_RELAXED, ACT_IDLE_ANGRY, ACT_IDLE_SMG1, ACT_IDLE}
	}

	for _, sequenceName in ipairs(preferredSequences[modelClass] or {}) do
		local sequence = entity:LookupSequence(sequenceName)

		if (sequence and sequence > 0) then
			entity:ResetSequence(sequence)
			return true
		end
	end

	for _, activity in ipairs(preferredActivities[modelClass] or {}) do
		local sequence = entity:SelectWeightedSequence(activity)

		if (sequence and sequence > 0) then
			entity:ResetSequence(sequence)
			return true
		end
	end

	return false
end

function PANEL:Init()
	self.defaultEyeTarget = Vector(0, 0, 64)
	self:SetHidden(false)

	for i = 0, 5 do
		if (i == 1 or i == 5) then
			self:SetDirectionalLight(i, Color(155, 155, 155))
		else
			self:SetDirectionalLight(i, Color(255, 255, 255))
		end
	end
end

function PANEL:SetModel(model, skin, hidden, bodygroups)
	BaseClass.SetModel(self, model)

	local entity = self.Entity

	if (skin) then
		entity:SetSkin(skin)
	end

	for i = 0, entity:GetNumBodyGroups() - 1 do
		entity:SetBodygroup(i, 0)
	end
	
	if (istable(bodygroups)) then
		for k, v in pairs(bodygroups) do
			local index = isnumber(k) and k or entity:FindBodygroupByName(k)

			if (isnumber(index) and index > -1) then
				entity:SetBodygroup(index, v)
			end
		end
	end

	if (!SelectPreferredSequence(entity)) then
		local sequence = entity:SelectWeightedSequence(ACT_IDLE)

		if (sequence <= 0) then
			sequence = entity:LookupSequence("idle_unarmed")
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
	end

	local data = PositionSpawnIcon(entity, entity:GetPos())

	if (data) then
		self:SetFOV(data.fov)
		self:SetCamPos(data.origin)
		self:SetLookAng(data.angles)
	end

	entity:SetIK(false)
	entity:SetEyeTarget(self.defaultEyeTarget)
end

function PANEL:SetHidden(hidden)
	if (hidden) then
		self:SetAmbientLight(color_black)
		self:SetColor(Color(0, 0, 0))

		for i = 0, 5 do
			self:SetDirectionalLight(i, color_black)
		end
	else
		self:SetAmbientLight(Color(20, 20, 20))
		self:SetAlpha(255)

		for i = 0, 5 do
			if (i == 1 or i == 5) then
				self:SetDirectionalLight(i, Color(155, 155, 155))
			else
				self:SetDirectionalLight(i, Color(255, 255, 255))
			end
		end
	end
end

function PANEL:LayoutEntity()
	self:RunAnimation()
end

function PANEL:OnMousePressed()
	if (self.DoClick) then
		self:DoClick()
	end
end

vgui.Register("ixSpawnIcon", PANEL, "DModelPanel")
