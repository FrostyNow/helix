
local PLUGIN = PLUGIN
local PANEL = {}

function PANEL:Init()
	if (IsValid(ix.gui.areaEdit)) then
		ix.gui.areaEdit:Remove()
	end

	ix.gui.areaEdit = self
	self.list = {}
	self.properties = {}
	self.propertyPanels = {}

	self:SetDeleteOnClose(true)
	self:SetSizable(true)
	self:SetTitle(L("areaNew"))

	self:MakePopup()

	-- scroll panel
	self.canvas = self:Add("DScrollPanel")
	self.canvas:Dock(FILL)

	local buildOrder = {
		"id",
		"name",
		"type",
		"display",
		"color",
		"comment"
	}

	for k, _ in pairs(ix.area.properties) do
		if (k != "name" and k != "display" and k != "color" and k != "comment") then
			buildOrder[#buildOrder + 1] = k
		end
	end

	for _, k in ipairs(buildOrder) do
		if (k == "id") then
			self.nameEntry = vgui.Create("ixTextEntry")
			self.nameEntry:SetFont("ixMediumLightFont")
			self.nameEntry:SetText(L("areaNew"))

			local listRow = self.canvas:Add("ixListRow")
			listRow:SetList(self.list)
			listRow:SetLabelText(L("areaID", "Area ID"))
			listRow:SetRightPanel(self.nameEntry)
			listRow:Dock(TOP)
			listRow:SizeToContents()
		elseif (k == "type") then
			self.typeEntry = self.canvas:Add("DComboBox")
			self.typeEntry:Dock(RIGHT)
			self.typeEntry:SetFont("ixMediumLightFont")
			self.typeEntry:SetTextColor(color_white)
			self.typeEntry.OnSelect = function(panel)
				panel:SizeToContents()
				panel:SetWide(panel:GetWide() + 12)
			end

			for id, name in pairs(ix.area.types) do
				self.typeEntry:AddChoice(L(name), id, id == "area")
			end

			local listRow = self.canvas:Add("ixListRow")
			listRow:SetList(self.list)
			listRow:SetLabelText(L("type"))
			listRow:SetRightPanel(self.typeEntry)
			listRow:Dock(TOP)
			listRow:SizeToContents()
		else
			local v = ix.area.properties[k]
			if (!v) then continue end

			local panel

			if (v.type == ix.type.string or v.type == ix.type.number) then
				panel = vgui.Create("ixTextEntry")
				panel:SetFont("ixMenuButtonFont")
				panel:SetText(tostring(v.default))

				if (v.type == ix.type.number) then
					panel.realGetValue = panel.GetValue
					panel.GetValue = function(this)
						return tonumber(this:realGetValue()) or v.default
					end
				end
				panel.SetValue = function(this, val)
					this:SetText(tostring(val))
				end
			elseif (v.type == ix.type.bool) then
				panel = vgui.Create("ixCheckBox")
				panel:SetChecked(v.default, true)
				panel:SetFont("ixMediumLightFont")
				panel.SetValue = function(this, val)
					this:SetChecked(val)
				end
			elseif (v.type == ix.type.color) then
				panel = vgui.Create("Panel")
				panel:SetSize(300, 64)

				panel.value = v.default

				panel.picker = vgui.Create("DColorCombo")
				panel.picker:SetColor(panel.value)
				panel.picker:SetVisible(false)
				panel.picker.OnValueChanged = function(_, newColor)
					if (panel.bUpdating) then return end
					panel.value = newColor
					if (IsValid(panel.combo)) then panel.combo:ChooseOptionID(1) end
					panel.updateInputs(true)
				end

				panel.display = panel:Add("DButton")
				panel.display:Dock(RIGHT)
				panel.display:SetWide(64)
				panel.display:SetText("")
				panel.display.Paint = function(_, width, height)
					surface.SetDrawColor(0, 0, 0, 255)
					surface.DrawOutlinedRect(0, 0, width, height)
					surface.SetDrawColor(panel.value)
					surface.DrawRect(4, 4, width - 8, height - 8)
				end
				panel.display.DoClick = function()
					if (!panel.picker:IsVisible()) then
						local x, y = panel.display:LocalToScreen(0, 0)
						panel.picker:SetPos(x - 130, y + 64)
						panel.picker:SetColor(panel.value)
						panel.picker:SetVisible(true)
						panel.picker:MakePopup()
					else
						panel.picker:SetVisible(false)
					end
				end

				local inputPanel = panel:Add("Panel")
				inputPanel:Dock(FILL)
				inputPanel:DockMargin(0, 0, 4, 0)

				panel.combo = inputPanel:Add("DComboBox")
				panel.combo:Dock(TOP)
				panel.combo:SetTall(24)
				panel.combo:SetFont("ixMediumLightFont")
				panel.combo:AddChoice(L("colorCustom", "Custom Component"), nil, true)
				panel.combo:AddChoice(L("colorTheme", "Theme Color"), ix.config.Get("color"))
				for _, faction in pairs(ix.faction.indices) do
					panel.combo:AddChoice(L(faction.name), faction.color)
				end
				for _, class in pairs(ix.class.list) do
					if (class.isDefault) then continue end
					if not (class.color) then continue end
					local color = class.color or (ix.faction.indices[class.faction] and ix.faction.indices[class.faction].color)
					if (color) then
						panel.combo:AddChoice(L(class.name), color)
					end
				end
				panel.combo.OnSelect = function(_, index, value, data)
					if (data) then
						panel.value = Color(data.r, data.g, data.b, data.a or 255)
						panel.updateInputs()
					end
				end

				panel.rgbInput = inputPanel:Add("ixTextEntry")
				panel.rgbInput:Dock(BOTTOM)
				panel.rgbInput:SetTall(36)
				panel.rgbInput:SetFont("ixMediumLightFont")
				panel.rgbInput:SetText(string.format("%d, %d, %d", panel.value.r, panel.value.g, panel.value.b))
				panel.rgbInput.OnChange = function(this)
					if (panel.bUpdating) then return end
					local exploded = string.Explode(",", this:GetValue())
					local r = tonumber((exploded[1] or ""):Trim()) or 255
					local g = tonumber((exploded[2] or ""):Trim()) or 255
					local b = tonumber((exploded[3] or ""):Trim()) or 255
					
					panel.value = Color(r, g, b, 255)
					if (IsValid(panel.combo)) then panel.combo:ChooseOptionID(1) end
					if (IsValid(panel.picker)) then
						panel.bUpdating = true
						panel.picker:SetColor(panel.value)
						panel.bUpdating = false
					end
				end

				panel.updateInputs = function(skipPicker)
					panel.bUpdating = true
					panel.rgbInput:SetText(string.format("%d, %d, %d", panel.value.r, panel.value.g, panel.value.b))
					panel.bUpdating = false
					if (!skipPicker and IsValid(panel.picker)) then
						panel.bUpdating = true
						panel.picker:SetColor(panel.value)
						panel.bUpdating = false
					end
				end

				panel.OnRemove = function()
					if (IsValid(panel.picker)) then
						panel.picker:Remove()
					end
				end

				panel.GetValue = function()
					return panel.value
				end

				panel.SetValue = function(this, val)
					this.value = val
					this.updateInputs()
				end
			end

			if (IsValid(panel)) then
				local labelText = k == "name" and L("areaDisplayName", "Display Name") or L(k)
				local row = self.canvas:Add("ixListRow")
				row:SetList(self.list)
				row:SetLabelText(labelText)
				row:SetRightPanel(panel)
				row:Dock(TOP)
				row:SizeToContents()
			end

			self.propertyPanels[k] = function(val)
				if (IsValid(panel) and panel.SetValue) then
					panel:SetValue(val)
				end
			end

			self.properties[k] = function()
				return panel:GetValue()
			end
		end
	end

	-- save button
	self.saveButton = self:Add("DButton")
	self.saveButton:SetText(L("save"))
	self.saveButton:SizeToContents()
	self.saveButton:Dock(BOTTOM)
	self.saveButton.DoClick = function()
		self:Submit()
	end

	self:SizeToContents()
	self:SetPos(64, 0)
	self:CenterVertical()
end

function PANEL:SetEditMode(id, info)
	self:SetTitle(L("areaEdit", "Edit Area") .. ": " .. id)
	self.areaID = id

	self.nameEntry:SetText(id)

	if (IsValid(self.typeEntry)) then
		self.typeEntry:SetValue(L(info.type))
	end
	
	for k, v in pairs(info.properties) do
		local func = self.propertyPanels[k]
		if (func) then
			func(v)
		end
	end
end

function PANEL:SizeToContents()
	local width = 600
	local height = 37

	for _, v in ipairs(self.canvas:GetCanvas():GetChildren()) do
		width = math.max(width, v:GetLabelWidth())
		height = height + v:GetTall()
	end

	self:SetWide(width + 200)
	self:SetTall(height + self.saveButton:GetTall() + 50)
end

function PANEL:Submit()
	local name = self.nameEntry:GetValue()

	if (ix.area.stored[name] and self.areaID != name) then
		ix.util.NotifyLocalized("areaAlreadyExists")
		return
	end

	local properties = {}

	for k, v in pairs(self.properties) do
		properties[k] = v()
	end

	if (self.areaID) then
		local newID = self.nameEntry:GetValue()
		local _, type = self.typeEntry:GetSelected()

		if (newID == "") then
			newID = self.areaID
		end

		net.Start("ixAreaEditProperties")
			net.WriteString(self.areaID)
			net.WriteString(newID)
			net.WriteString(type or "area")
			net.WriteTable(properties)
		net.SendToServer()
		self.areaID = newID
	else
		local _, type = self.typeEntry:GetSelected()

		net.Start("ixAreaAdd")
			net.WriteString(name)
			net.WriteString(type)
			net.WriteVector(PLUGIN.editStart)
			net.WriteVector(PLUGIN:GetPlayerAreaTrace().HitPos)
			net.WriteTable(properties)
		net.SendToServer()
	end

	PLUGIN.editStart = nil
	self:Remove()
end

function PANEL:OnRemove()
	PLUGIN.editProperties = nil
end

vgui.Register("ixAreaEdit", PANEL, "DFrame")

if (IsValid(ix.gui.areaEdit)) then
	ix.gui.areaEdit:Remove()
end