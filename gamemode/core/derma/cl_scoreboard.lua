local rowPaintFunctions = {
	function(width, height)
	end,

	function(width, height)
		surface.SetDrawColor(30, 30, 30, 25)
		surface.DrawRect(0, 0, width, height)
	end
}

-- character icon
-- we can't customize the rendering of ModelImage so we have to do it ourselves
local PANEL = {}
local BODYGROUPS_EMPTY = "000000000"

-- Utility for admin info hints
local function CompactText(text, limit)
	if (text:utf8len() > limit) then
		return text:utf8sub(1, limit - 3) .. "..."
	end
	return text
end

local function IsAdminViewingAnonymous(client)
	if (!LocalPlayer():IsAdmin() or !IsValid(client)) then return false end
	
	local localCharacter = LocalPlayer():GetCharacter()
	local character = client:GetCharacter()

	if (localCharacter and character) then
		local bRecognize = hook.Run("IsCharacterRecognized", localCharacter, character:GetID()) or hook.Run("IsPlayerRecognized", client)
		return !bRecognize
	end

	return false
end

local adminAnonHintColor = Color(170, 170, 170)

local function BuildScoreboardIconState(client)
	local state = {
		bodygroups = "",
		signature = "",
		indexed = {},
		requiresDynamic = false
	}

	if (!IsValid(client)) then
		return state
	end

	local groups = client:GetBodyGroups()

	if (!istable(groups) or #groups == 0) then
		return state
	end

	local entries = {}

	for _, group in ipairs(groups) do
		local index = tonumber(group.id)

		if (index and index >= 0) then
			local value = math.max(tonumber(client:GetBodygroup(index)) or 0, 0)

			entries[#entries + 1] = {
				index = index,
				value = value
			}
		end
	end

	if (#entries == 0) then
		return state
	end

	table.sort(entries, function(a, b)
		return a.index < b.index
	end)

	local digits = {}
	local lastIndex = entries[#entries].index
	local signatureParts = {}

	for bodygroupIndex = 0, lastIndex do
		digits[bodygroupIndex + 1] = "0"
	end

	for _, entry in ipairs(entries) do
		state.indexed[entry.index] = entry.value
		signatureParts[#signatureParts + 1] = entry.index .. "=" .. entry.value
		digits[entry.index + 1] = tostring(math.min(entry.value, 9))

		if (entry.index > 8 or entry.value > 9) then
			state.requiresDynamic = true
		end
	end

	state.signature = table.concat(signatureParts, ";")
	state.bodygroups = table.concat(digits, "", 1, #digits)

	if (state.bodygroups:match("^0+$")) then
		state.bodygroups = ""
	end

	return state
end

local function CleanupScoreboardIcon(icon)
	if (icon.id) then
		hook.Remove("SpawniconGenerated", icon.id)
		icon.id = nil
	end

	if (IsValid(icon.renderer)) then
		icon.renderer:Remove()
		icon.renderer = nil
	end
end

AccessorFunc(PANEL, "model", "Model", FORCE_STRING)
AccessorFunc(PANEL, "bHidden", "Hidden", FORCE_BOOL)

function PANEL:Init()
	self:SetSize(64, 64)
	self.bodygroups = BODYGROUPS_EMPTY
end

function PANEL:GetBodygroupString()
	return self.bodygroups or ""
end

function PANEL:GetBodygroupSignature()
	return self.ixBodygroupSignature or ""
end

function PANEL:SetBodygroupSignature(signature)
	self.ixBodygroupSignature = signature or ""
end

function PANEL:ClearDynamicRenderer()
	self.ixUseDynamicRenderer = false

	if (IsValid(self.ixDynamicRenderer)) then
		self.ixDynamicRenderer:Remove()
		self.ixDynamicRenderer = nil
	end
end

function PANEL:SetModel(model, skin, bodygroups)
	model = model:gsub("\\", "/")
	self:ClearDynamicRenderer()

	if (isstring(bodygroups)) then
		if (bodygroups:len() == 9) then
			for i = 1, bodygroups:len() do
				self:SetBodygroup(i, tonumber(bodygroups[i]) or 0)
			end
		else
			self.bodygroups = BODYGROUPS_EMPTY
		end
	end

	self.model = model
	self.skin = skin
	self.path = "materials/spawnicons/" ..
		model:sub(1, #model - 4) .. -- remove extension
		((isnumber(skin) and skin > 0) and ("_skin" .. tostring(skin)) or "") .. -- skin number
		(self.bodygroups != BODYGROUPS_EMPTY and ("_" .. self.bodygroups) or "") .. -- bodygroups
		".png"

	local material = Material(self.path, "smooth")

	-- we don't have a cached spawnicon texture, so we need to forcefully generate one
	if (material:IsError()) then
		self.id = "ixScoreboardIcon" .. self.path
		self.renderer = self:Add("ModelImage")
		self.renderer:SetVisible(false)
		self.renderer:SetModel(model, skin, self.bodygroups)
		self.renderer:RebuildSpawnIcon()

		-- this is the only way to get a callback for generated spawn icons, it's bad but it's only done once
		hook.Add("SpawniconGenerated", self.id, function(lastModel, filePath, modelsLeft)
			filePath = filePath:gsub("\\", "/"):lower()

			if (filePath == self.path) then
				hook.Remove("SpawniconGenerated", self.id)

				self.material = Material(filePath, "smooth")
				self.renderer:Remove()
			end
		end)
	else
		self.material = material
	end
end

function PANEL:SetBodygroup(k, v)
	if (k < 0 or v < 0) then
		return
	end

	if (k > 8 or v > 9) then
		self.bodygroups = ""
		return
	end

	self.bodygroups = self.bodygroups:SetChar(k + 1, v)
end

function PANEL:GetModel()
	return self.model or "models/error.mdl"
end

function PANEL:GetSkin()
	return self.skin or 1
end

function PANEL:SetHidden(hidden)
	self.bHidden = tobool(hidden)

	if (IsValid(self.ixDynamicRenderer)) then
		local adminCanSeeHidden = self.bHidden and IsValid(LocalPlayer()) and LocalPlayer():IsAdmin()
		self.ixDynamicRenderer:SetHidden(self.bHidden and !adminCanSeeHidden)
		self.ixDynamicRenderer:SetVisible(true)
	end
end

function PANEL:SetDynamicRenderer(model, skin, bodygroups, signature)
	if (!isstring(model) or model == "") then
		return
	end

	self.model = model:gsub("\\", "/")
	self.skin = skin
	self:SetBodygroupSignature(signature)
	CleanupScoreboardIcon(self)
	self.material = nil
	self.ixUseDynamicRenderer = true

	if (!IsValid(self.ixDynamicRenderer)) then
		self.ixDynamicRenderer = self:Add("ixSpawnIcon")
		self.ixDynamicRenderer:Dock(FILL)
		self.ixDynamicRenderer:SetMouseInputEnabled(false)
		self.ixDynamicRenderer.LayoutEntity = function(panel, entity)
			entity:SetIK(false)
			entity:SetPlaybackRate(0)
			entity:SetCycle(0)
			entity:SetPoseParameter("head_pitch", 0)
			entity:SetPoseParameter("head_yaw", 0)
			entity:SetPoseParameter("aim_pitch", 0)
			entity:SetPoseParameter("aim_yaw", 0)
			entity:SetPoseParameter("eyes_pitch", 0)
			entity:SetPoseParameter("eyes_yaw", 0)
			panel:RunAnimation()
		end
	end

	local adminCanSeeHidden = self.bHidden and IsValid(LocalPlayer()) and LocalPlayer():IsAdmin()
	self.ixDynamicRenderer:SetModel(self.model, skin, self.bHidden and !adminCanSeeHidden, bodygroups)
	self.ixDynamicRenderer:SetHidden(self.bHidden and !adminCanSeeHidden)
	self.ixDynamicRenderer:SetVisible(true)
end

function PANEL:DoClick()
end

function PANEL:DoRightClick()
end

function PANEL:OnMouseReleased(key)
	if (key == MOUSE_LEFT) then
		self:DoClick()
	elseif (key == MOUSE_RIGHT) then
		self:DoRightClick()
	end
end

function PANEL:Paint(width, height)
	if (self.ixUseDynamicRenderer and IsValid(self.ixDynamicRenderer)) then
		if (self.bHidden and LocalPlayer():IsAdmin()) then
			surface.SetDrawColor(0, 0, 0, 110)
			surface.DrawRect(0, 0, width, height)
		end

		return
	end

	if (!self.material) then
		return
	end

	surface.SetMaterial(self.material)

	if (self.bHidden) then
		local bIsAdmin = LocalPlayer():IsAdmin()
		if (bIsAdmin) then
			surface.SetDrawColor(128, 128, 128, 255)
		else
			surface.SetDrawColor(0, 0, 0, 255)
		end
	else
		surface.SetDrawColor(255, 255, 255, 255)
	end

	surface.DrawTexturedRect(0, 0, width, height)
end

function PANEL:Think()
	if (self.ixUseDynamicRenderer and IsValid(self.ixDynamicRenderer)) then
		local adminCanSeeHidden = self.bHidden and IsValid(LocalPlayer()) and LocalPlayer():IsAdmin()
		self.ixDynamicRenderer:SetHidden(self.bHidden and !adminCanSeeHidden)
	end
end

function PANEL:OnRemove()
	self:ClearDynamicRenderer()
	CleanupScoreboardIcon(self)
end

vgui.Register("ixScoreboardIcon", PANEL, "Panel")

-- player row
PANEL = {}

AccessorFunc(PANEL, "paintFunction", "BackgroundPaintFunction")

function PANEL:Init()
	self:SetTall(64)

	self.icon = self:Add("ixScoreboardIcon")
	self.icon:Dock(LEFT)
	self.icon.DoRightClick = function()
		local client = self.player

		if (!IsValid(client)) then
			return
		end

		local menu = DermaMenu()

		menu:AddOption(L("viewProfile"), function()
			client:ShowProfile()
		end)

		menu:AddOption(L("copySteamID"), function()
			SetClipboardText(client:IsBot() and client:EntIndex() or client:SteamID())
		end)

		hook.Run("PopulateScoreboardPlayerMenu", client, menu)
		menu:Open()
	end

	self.icon:SetHelixTooltip(function(tooltip)
		local client = self.player

		if (IsValid(self) and IsValid(client)) then
			ix.hud.PopulatePlayerTooltip(tooltip, client)
		end
	end)

	self.name = self:Add("DLabel")
	self.name:DockMargin(4, 4, 0, 0)
	self.name:Dock(TOP)
	self.name:SetTextColor(color_white)
	self.name:SetFont("ixGenericFont")

	self.description = self:Add("DLabel")
	self.description:DockMargin(5, 0, 0, 0)
	self.description:Dock(TOP)
	self.description:SetTextColor(color_white)
	self.description:SetFont("ixSmallFont")

	self.paintFunction = rowPaintFunctions[1]
	self.nextThink = CurTime() + 1

	self.realNameHint = self.name:Add("DLabel")
	self.realNameHint:SetFont("ixAdminAnonHintFont")
	self.realNameHint:SetTextColor(adminAnonHintColor)
	self.realNameHint:SetMouseInputEnabled(false)
	self.realNameHint:SetVisible(false)

	self.realDescriptionHint = self.description:Add("DLabel")
	self.realDescriptionHint:SetFont("ixAdminAnonHintFont")
	self.realDescriptionHint:SetTextColor(adminAnonHintColor)
	self.realDescriptionHint:SetMouseInputEnabled(false)
	self.realDescriptionHint:SetVisible(false)
end

function PANEL:Update()
	local client = self.player
	local model = client:GetModel()
	local skin = client:GetSkin()
	local iconState = BuildScoreboardIconState(client)
	local name = hook.Run("GetCharacterName", client) or client:GetName()
	local description = hook.Run("GetCharacterDescription", client) or
		(client:GetCharacter() and client:GetCharacter():GetDescription()) or ""

	local bRecognize = false
	local localCharacter = LocalPlayer():GetCharacter()
	local character = IsValid(self.player) and self.player:GetCharacter()

	if (localCharacter and character) then
		bRecognize = hook.Run("IsCharacterRecognized", localCharacter, character:GetID())
			or hook.Run("IsPlayerRecognized", self.player)
	end

	self.icon:SetHidden(!bRecognize)
	self:SetZPos(bRecognize and 1 or 2)
	local previousSignature = self.icon:GetBodygroupSignature()

	if (iconState.requiresDynamic) then
		if (
			self.icon:GetModel() != model
			or self.icon:GetSkin() != skin
			or !self.icon.ixUseDynamicRenderer
			or previousSignature != iconState.signature
		) then
			self.icon:SetDynamicRenderer(model, skin, iconState.indexed, iconState.signature)
			self.icon:SetTooltip(nil)
		end
	elseif (
		self.icon:GetModel() != model
		or self.icon:GetSkin() != skin
		or self.icon.ixUseDynamicRenderer
		or self.icon:GetBodygroupString() != iconState.bodygroups
	) then
		self.icon:SetModel(model, skin, iconState.bodygroups)
		self.icon:SetTooltip(nil)
	end

	self.icon:SetBodygroupSignature(iconState.signature)

	if (self.name:GetText() != name) then
		self.name:SetText(name)
		self.name:SizeToContents()
	end

	if (self.description:GetText() != description) then
		self.description:SetText(description)
		self.description:SizeToContents()
	end

	-- Real info hints for admins
	local target = self.player
	local character = IsValid(target) and target:GetCharacter()
	local showHints = IsAdminViewingAnonymous(target) and character

	if (!showHints) then
		if (IsValid(self.realNameHint)) then
			self.realNameHint:SetVisible(false)
		end

		if (IsValid(self.realDescriptionHint)) then
			self.realDescriptionHint:SetVisible(false)
		end
	else
		local displayedName = self.name:GetText()
		local realName = character:GetVar("name") or character:GetName()

		if (displayedName != realName and IsValid(self.realNameHint)) then
			self.realNameHint:SetText(" (" .. CompactText(realName, 48) .. ")")
			self.realNameHint:SizeToContents()

			surface.SetFont(self.name:GetFont())
			local nameWidth = select(1, surface.GetTextSize(displayedName))
			self.realNameHint:SetPos(nameWidth + 4, 0)
			self.realNameHint:SetVisible(true)
		elseif (IsValid(self.realNameHint)) then
			self.realNameHint:SetVisible(false)
		end

		local displayedDescription = self.description:GetText()
		local realDescription = character:GetVar("description") or character:GetDescription() or ""

		if (realDescription != "" and displayedDescription != realDescription and IsValid(self.realDescriptionHint)) then
			self.realDescriptionHint:SetText(" (" .. CompactText(realDescription, 80) .. ")")
			self.realDescriptionHint:SizeToContents()

			surface.SetFont(self.description:GetFont())
			local descriptionWidth = select(1, surface.GetTextSize(displayedDescription))
			self.realDescriptionHint:SetPos(descriptionWidth + 4, 0)
			self.realDescriptionHint:SetVisible(true)
		elseif (IsValid(self.realDescriptionHint)) then
			self.realDescriptionHint:SetVisible(false)
		end
	end
end

function PANEL:Think()
	if (CurTime() >= self.nextThink) then
		local client = self.player

		if (!IsValid(client) or !client:GetCharacter() or self.character != client:GetCharacter() or self.team != client:Team()) then
			self:Remove()
			self:GetParent():SizeToContents()
		end

		self.nextThink = CurTime() + 1
	end
end

function PANEL:SetPlayer(client)
	self.player = client
	self.team = client:Team()
	self.character = client:GetCharacter()

	self:Update()
end

function PANEL:Paint(width, height)
	self.paintFunction(width, height)
end

vgui.Register("ixScoreboardRow", PANEL, "EditablePanel")

-- faction grouping
PANEL = {}

AccessorFunc(PANEL, "faction", "Faction")

function PANEL:Init()
	self:DockMargin(0, 0, 0, 16)
	self:SetTall(32)

	self.nextThink = 0
end

function PANEL:AddPlayer(client, index)
	if (!IsValid(client) or !client:GetCharacter() or hook.Run("ShouldShowPlayerOnScoreboard", client) == false) then
		return false
	end

	local id = index % 2 == 0 and 1 or 2
	local panel = self:Add("ixScoreboardRow")
	panel:SetPlayer(client)
	panel:Dock(TOP)
	panel:SetZPos(2)
	panel:SetBackgroundPaintFunction(rowPaintFunctions[id])

	self:SizeToContents()
	client.ixScoreboardSlot = panel

	return true
end

function PANEL:SetFaction(faction)
	self:SetColor(faction.color)
	self:SetText(L(faction.name))

	self.faction = faction
end

function PANEL:Update()
	local faction = self.faction

	if (team.NumPlayers(faction.index) == 0) then
		self:SetVisible(false)
		self:GetParent():InvalidateLayout()
	else
		local bHasPlayers

		for k, v in ipairs(team.GetPlayers(faction.index)) do
			if (!IsValid(v.ixScoreboardSlot)) then
				if (self:AddPlayer(v, k)) then
					bHasPlayers = true
				end
			else
				v.ixScoreboardSlot:Update()
				bHasPlayers = true
			end
		end

		self:SetVisible(bHasPlayers)
	end
end

vgui.Register("ixScoreboardFaction", PANEL, "ixCategoryPanel")

-- main scoreboard panel
PANEL = {}

function PANEL:Init()
	if (IsValid(ix.gui.scoreboard)) then
		ix.gui.scoreboard:Remove()
	end

	self:Dock(FILL)

	self.factions = {}
	self.nextThink = 0

	for i = 1, #ix.faction.indices do
		local faction = ix.faction.indices[i]

		local panel = self:Add("ixScoreboardFaction")
		panel:SetFaction(faction)
		panel:Dock(TOP)

		self.factions[i] = panel
	end

	ix.gui.scoreboard = self
end

function PANEL:Think()
	if (CurTime() >= self.nextThink) then
		for i = 1, #self.factions do
			local factionPanel = self.factions[i]

			factionPanel:Update()
		end

		self.nextThink = CurTime() + 0.5
	end
end

vgui.Register("ixScoreboard", PANEL, "DScrollPanel")

hook.Add("CreateMenuButtons", "ixScoreboard", function(tabs)
	tabs["scoreboard"] = function(container)
		container:Add("ixScoreboard")
	end
end)
