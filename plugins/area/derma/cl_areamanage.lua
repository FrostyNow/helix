local PLUGIN = PLUGIN
local PANEL = {}

function PANEL:Init()
	if (IsValid(ix.gui.areaManage)) then
		ix.gui.areaManage:Remove()
	end

	ix.gui.areaManage = self

	self:SetDeleteOnClose(true)
	self:SetSizable(true)
	self:SetTitle(L("areas"))
	self:SetSize(800, 600)
	self:Center()
	self:MakePopup()

	self.list = self:Add("DScrollPanel")
	self.list:Dock(FILL)

	self:Populate()
end

function PANEL:Populate()
	self.list:Clear()

	local sortedAreas = {}
	for id, info in pairs(ix.area.stored) do
		table.insert(sortedAreas, {id = id, info = info})
	end

	table.SortByMember(sortedAreas, "id", true)

	for _, v in ipairs(sortedAreas) do
		local id = v.id
		local info = v.info
		local panel = self.list:Add("DPanel")
		panel:Dock(TOP)
		panel:DockMargin(0, 0, 0, 5)
		panel:SetTall(36)
		panel.Paint = function(this, width, height)
			local color = info.properties.color or Color(0, 0, 0)
			surface.SetDrawColor(color.r, color.g, color.b, 150)
			surface.DrawRect(0, 0, width, height)
		end

		local nameLabel = panel:Add("DLabel")
		nameLabel:Dock(FILL)
		nameLabel:DockMargin(10, 0, 0, 0)
		nameLabel:SetFont("ixMediumLightFont")
		local displayName = info.properties.name != "" and info.properties.name or id
		nameLabel:SetText(id .. " (" .. displayName .. ")")
		nameLabel:SetTextColor(color_white)
		nameLabel:SetExpensiveShadow(1, Color(0, 0, 0, 200))

		local delBtn = panel:Add("DButton")
		delBtn:Dock(RIGHT)
		delBtn:DockMargin(0, 5, 5, 5)
		delBtn:SetText(L("delete"))
		delBtn:SetTextColor(Color(255, 100, 100))
		delBtn:SetWide(64)
		
		local editBtn = panel:Add("DButton")
		editBtn:Dock(RIGHT)
		editBtn:DockMargin(0, 5, 5, 5)
		editBtn:SetText(L("edit"))
		editBtn:SetWide(64)
		editBtn.DoClick = function()
			local editUI = vgui.Create("ixAreaEdit")
			editUI:SetEditMode(id, info)
		end

		delBtn.DoClick = function()
			local query = vgui.Create("DFrame")
			query:SetTitle(L("areaDelete"))
			query:SetSize(320, 120)
			query:Center()
			query:MakePopup()
			
			local label = query:Add("DLabel")
			label:SetText(L("areaDeleteConfirm", id))
			label:Dock(TOP)
			label:DockMargin(10, 10, 10, 10)
			label:SetContentAlignment(5)

			local btnPanel = query:Add("Panel")
			btnPanel:Dock(BOTTOM)
			btnPanel:SetTall(30)
			btnPanel:DockMargin(10, 0, 10, 10)

			local yesBtn = btnPanel:Add("DButton")
			yesBtn:Dock(LEFT)
			yesBtn:SetWide(140)
			yesBtn:SetText(L("yes"))
			yesBtn:SetTextColor(Color(255, 100, 100))
			yesBtn.DoClick = function()
				net.Start("ixAreaRemove")
					net.WriteString(id)
				net.SendToServer()
				panel:Remove()
				query:Remove()
			end

			local noBtn = btnPanel:Add("DButton")
			noBtn:Dock(RIGHT)
			noBtn:SetWide(140)
			noBtn:SetText(L("no"))
			noBtn.DoClick = function()
				query:Remove()
			end
		end
	end
end

vgui.Register("ixAreaManage", PANEL, "DFrame")
