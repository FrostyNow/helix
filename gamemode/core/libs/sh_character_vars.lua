
ix.char.RegisterVar("groups", {
	default = {},
	bSkipLabel = true,
	OnDisplay = function(self, container, payload)
		local faction = ix.faction.indices[payload.faction]
		if (!faction) then return end
		
		-- Only show if there are bodygroups OR skin groups for this model
		local hasBodyGroups = faction.bodyGroups and table.Count(faction.bodyGroups) > 0
		local hasSkinGroups = faction.skinGroups and table.Count(faction.skinGroups) > 0
		
		if (!hasBodyGroups and !hasSkinGroups) then return end

		local wrapper = container:Add("Panel")
		wrapper:Dock(TOP)
		wrapper:DockMargin(0, 32, 0, 0)

		-- Create separate containers to control order (Skin FIRST, then Bodygroups)
		local skinContainer = wrapper:Add("Panel")
		skinContainer:Dock(TOP)
		skinContainer:SetTall(0)

		local bodygroupsContainer = wrapper:Add("Panel")
		bodygroupsContainer:Dock(TOP)
		bodygroupsContainer:SetTall(0)

		local rows = {}
		local function AddControl(parent, id, data, isSkin)
			local row = parent:Add("Panel")
			row:Dock(TOP)
			row.bodyGroup = id
			row.excludeModels = data.excludeModels
			row.isSkin = isSkin

			if (isSkin) then
				-- Skin Slider Implementation
				local slider = row:Add("DNumSlider")
				slider:Dock(TOP)
				slider:SetText(L(data.name or "skin"):utf8upper())
				slider:SetMin(data.min or 0)
				slider:SetMax(data.max or 0)
				slider:SetDecimals(0)
				slider:SetTall(40)
				
				slider.Label:SetFont("ixMenuButtonLabelFont")
				slider.Label:SetFont("ixMenuButtonLabelFont")
				slider.Label:SetTextColor(color_white)
				slider.TextArea:SetFont("ixMenuButtonFont")
				slider.TextArea:SetTextColor(ix.config.Get("color"))
				
				local currentVal = (payload.groups and payload.groups[id]) or (payload.skin or data.min or 0)
				slider:SetValue(currentVal)
				
				slider.OnValueChanged = function(this, value)
					local val = math.Round(value)
					local groups = payload.groups or {}
					groups[id] = val
					payload:Set("groups", groups)
					payload:Set("skin", val)
				end
			else
				if (data.name) then
					local label = row:Add("DLabel")
					label:SetFont("ixMenuButtonLabelFont")
					label:SetText(L(data.name):utf8upper())
					label:SizeToContents()
					label:DockMargin(0, 0, 0, 8)
					label:Dock(TOP)
				end

				local comboBox = row:Add("DComboBox")
				comboBox:Dock(TOP)
				comboBox:SetFont("ixMenuButtonFont")
				comboBox:SetTall(40)
				comboBox:SetSortItems(false)
				comboBox.Paint = function(this, w, h)
					surface.SetDrawColor(0, 0, 0, 150)
					surface.DrawRect(0, 0, w, h)
				end

				local min = data.min or 0
				local max = data.max or 0
				local names = data.names

				for i = min, max do
					local text
					if (names and names[i]) then
						text = names[i]
					elseif (i == 0) then
						text = L("none")
					else
						text = L("Type") .. " " .. i
					end
					
					comboBox:AddChoice(text, i)
				end

				comboBox.OnSelect = function(this, index, value, data)
					local groups = payload.groups or {}
					groups[id] = data
					payload:Set("groups", groups)
				end
				
				local currentVal = (payload.groups and payload.groups[id]) or min
				local currentText
				if (names and names[currentVal]) then
					currentText = names[currentVal]
				elseif (currentVal == 0) then
					currentText = L("none")
				else
					currentText = L("Type") .. " " .. currentVal
				end
				
				comboBox:SetValue(currentText)
				
				local spacer = row:Add("Panel")
				spacer:SetTall(16)
				spacer:Dock(TOP)
			end
			
			row:InvalidateLayout(true)
			row:SizeToChildren(false, true)
			
			table.insert(rows, row)
			return row
		end

		if (hasBodyGroups) then
			for k, v in SortedPairs(faction.bodyGroups) do
				AddControl(bodygroupsContainer, k, v, false)
			end
			bodygroupsContainer:SizeToChildren(false, true)
		end

		local function UpdateVisibility(modelIndex)
			if (!IsValid(wrapper)) then return end
			if (!istable(faction.models)) then return end
			
			local modelData = faction.models[modelIndex]
			local modelPath
			if (modelData) then
				modelPath = istable(modelData) and modelData[1] or modelData
			end
			
			-- Handle skin slider dynamically using Entity
			local skinData = nil
			local panel = ix.gui.characterMenu
			
			if (IsValid(panel) and IsValid(panel.newCharacterPanel)) then
				local charPanel = panel.newCharacterPanel
				if (IsValid(charPanel.descriptionModel) and IsValid(charPanel.descriptionModel.Entity)) then
					local ent = charPanel.descriptionModel.Entity
					local count = ent:SkinCount()
					
					if (count > 1) then
						skinData = {
							name = "skin",
							min = 0,
							max = count - 1
						}
					end
				end
			end
			
			if (!skinData and faction.skinGroups and modelPath) then
				local lowerPath = string.lower(modelPath)
				lowerPath = string.gsub(lowerPath, "\\", "/")
				
				for k, v in pairs(faction.skinGroups) do
					local keyPath = string.lower(k)
					keyPath = string.gsub(keyPath, "\\", "/")
					
					if (keyPath == lowerPath) then
						skinData = v
						break
					end
				end
			end
			
			skinContainer:Clear()
			if (skinData) then
				AddControl(skinContainer, "skin", skinData, true)
				skinContainer:SizeToChildren(false, true)
			else
				skinContainer:SetTall(0)
			end
			
			local anyVisible = false
			
			for _, row in ipairs(rows) do
				if (!IsValid(row)) then continue end
				
				local visible = true
				if (row.isSkin) then
					visible = true
				elseif (row.excludeModels and modelPath and string.find(modelPath, row.excludeModels)) then
					visible = false
				end
				
				row:SetVisible(visible)
				if (visible) then
					anyVisible = true
				end
			end
			
			local spacer = wrapper:Add("Panel")
			spacer:SetTall(16)
			spacer:Dock(TOP)
			bodygroupsContainer:DockMargin(0, 16, 0, 0)
			
			if (anyVisible or IsValid(skinContainer) and skinContainer:GetTall() > 0) then
				wrapper:SetVisible(true)
				wrapper:InvalidateLayout(true)
				wrapper:SizeToChildren(false, true)
			else
				wrapper:SetVisible(false)
				wrapper:SetTall(0)
			end
		end
		
		local function ApplyBodyGroups(groups)
			local panel = ix.gui.characterMenu
			if (IsValid(panel) and IsValid(panel.newCharacterPanel)) then
				local charPanel = panel.newCharacterPanel
				
				local function ApplyToEntity(entity)
					if (IsValid(entity)) then
						for k, v in pairs(groups) do
							if (k == "skin") then continue end
							
							local index = entity:FindBodygroupByName(k)
							
							if (index == -1) then
								if (faction.bodyGroups[k] and faction.bodyGroups[k].name) then
									index = entity:FindBodygroupByName(faction.bodyGroups[k].name)
								end
								
								if (index == -1) then
									local searchKey = string.lower(string.gsub(k, "[%A]", "")) 
									for _, bg in ipairs(entity:GetBodyGroups()) do
										local bgName = string.lower(string.gsub(bg.name, "[%A]", ""))
										if (bgName == searchKey) then
											index = bg.id
											break
										end
									end
								end
							end
							
							if (index > -1) then
								entity:SetBodygroup(index, v)
							end
						end
					end
				end

				if (IsValid(charPanel.descriptionModel) and IsValid(charPanel.descriptionModel.Entity)) then
					ApplyToEntity(charPanel.descriptionModel.Entity)
				end
				
				if (IsValid(charPanel.factionModel) and IsValid(charPanel.factionModel.Entity)) then
					ApplyToEntity(charPanel.factionModel.Entity)
				end
				
				if (IsValid(charPanel.attributesModel) and IsValid(charPanel.attributesModel.Entity)) then
					ApplyToEntity(charPanel.attributesModel.Entity)
				end
				
				if (IsValid(charPanel.descriptionFace) and IsValid(charPanel.descriptionFace.Entity)) then
					ApplyToEntity(charPanel.descriptionFace.Entity)
				end
			end
		end

		payload:AddHook("model", function(value)
			UpdateVisibility(value)
			local groups = payload.groups or {}
			ApplyBodyGroups(groups)
		end)
		UpdateVisibility(payload.model)
		
		payload:AddHook("skin", function(value)
			local panel = ix.gui.characterMenu
			if (IsValid(panel) and IsValid(panel.newCharacterPanel)) then
				local charPanel = panel.newCharacterPanel
				
				if (IsValid(charPanel.descriptionModel) and IsValid(charPanel.descriptionModel.Entity)) then
					charPanel.descriptionModel.Entity:SetSkin(value)
				end
				
				if (IsValid(charPanel.factionModel) and IsValid(charPanel.factionModel.Entity)) then
					charPanel.factionModel.Entity:SetSkin(value)
				end
				
				if (IsValid(charPanel.attributesModel) and IsValid(charPanel.attributesModel.Entity)) then
					charPanel.attributesModel.Entity:SetSkin(value)
				end
				
				if (IsValid(charPanel.descriptionFace) and IsValid(charPanel.descriptionFace.Entity)) then
					charPanel.descriptionFace.Entity:SetSkin(value)
				end
			end
		end)

		payload:AddHook("groups", function(value)
			ApplyBodyGroups(value)
		end)
		
		return wrapper
	end,
	OnValidate = function(self, value, payload, client)
		return true
	end,
	OnAdjust = function(self, client, payload, value, newPayload)
		newPayload.data = newPayload.data or {}
		
		local finalGroups = {}
		local model = payload.model
		
		local faction = ix.faction.indices[payload.faction]
		local modelPath
		local factionBodyGroups = faction and faction.bodyGroups
		
		if (faction and faction.genderModels) then
			local index = payload.model
			local current = 0
			
			if (faction.genderModels.female) then
				local count = #faction.genderModels.female
				if (index <= current + count) then
					modelPath = faction.genderModels.female[index - current]
				end
				current = current + count
			end
			
			if (!modelPath and faction.genderModels.male) then
				local count = #faction.genderModels.male
				if (index <= current + count) then
					local localIndex = index - current
					if (localIndex > 0) then
						modelPath = faction.genderModels.male[localIndex]
					end
				end
				current = current + count
			end
			
			if (modelPath and istable(modelPath)) then
				modelPath = modelPath[1]
			end
		end

		if (!modelPath and faction) then
			local models = faction:GetModels(client)
			if (!models or table.Count(models) == 0) then models = faction.models end
			
			if (models) then
				local m = models[payload.model]
				if (m) then
					modelPath = istable(m) and m[1] or m
				end
			end
		end

		if (istable(value)) then
			if (modelPath) then
				local dummy = ents.Create("prop_physics")
				if (IsValid(dummy)) then
					dummy:SetModel(modelPath)
					local availableBodygroups = dummy:GetBodyGroups()

					for k, v in pairs(value) do
						if (isnumber(k)) then
							finalGroups[k] = v
						elseif (isstring(k)) then
							if (k == "skin") then
								newPayload.data.skin = v
							else
								local targetIndex = -1
								
								local index = dummy:FindBodygroupByName(k)
								if (index > -1) then
									targetIndex = index
								end
								
								if (targetIndex == -1) then
									local searchKey = string.lower(string.gsub(k, "[%A]", ""))
									
									for _, bg in ipairs(availableBodygroups) do
										local bgName = string.lower(string.gsub(bg.name, "[%A]", ""))
										
										if (bgName == searchKey) then
											targetIndex = bg.id
											break
										end
										
										if (string.lower(string.gsub(bg.name, " ", "")) == string.lower(k)) then
											targetIndex = bg.id
											break
										end
									end
								end

								if (targetIndex == -1 and factionBodyGroups and factionBodyGroups[k] and factionBodyGroups[k].name) then
									local altName = factionBodyGroups[k].name
									local index2 = dummy:FindBodygroupByName(altName)
									if (index2 > -1) then
										targetIndex = index2
									end
								end
								
								if (targetIndex > -1) then
									finalGroups[targetIndex] = v
								else
									finalGroups[k] = v
								end
							end
						end
					end
					
					dummy:Remove()
				else
					finalGroups = value
				end
			else
				for k, v in pairs(value) do
					if (isnumber(k)) then
						finalGroups[k] = v
					elseif (isstring(k)) then
						if (k == "skin") then
							newPayload.data.skin = v
						else
							finalGroups[k] = v
						end
					end
				end
			end
		end
		
		if (payload.skin) then
			newPayload.data.skin = payload.skin
		end
		
		newPayload.data.groups = finalGroups
	end,
	ShouldDisplay = function(self, container, payload)
		return true
	end
})

if (SERVER) then
	function FACTION_ApplyBodyGroups(client)
		local character = client:GetCharacter()
		if (character) then
			local groups = character:GetData("groups", {})
			
			for k, v in pairs(groups) do
				if (k == "skin") then
					client:SetSkin(v)
				else
					local index = k
					if (!isnumber(k)) then
						index = client:FindBodygroupByName(k)
					end
					
					if (index > -1) then
						client:SetBodygroup(index, v)
					end
				end
			end
		end
	end

	hook.Add("PlayerSpawn", "ixFactionBodyGroups", FACTION_ApplyBodyGroups)
	hook.Add("PlayerLoadedCharacter", "ixFactionBodyGroups", FACTION_ApplyBodyGroups)
end

-- Override the default model variable to fix layout issues with DScrollPanel
local modelVar = ix.char.vars["model"]
if (modelVar) then
	modelVar.bSkipLabel = true
	modelVar.OnDisplay = function(self, container, payload)
		local wrapper = container:Add("Panel")
		wrapper:Dock(TOP)
		
		local faction = ix.faction.indices[payload.faction]

		if (faction) then
			local models = faction:GetModels(LocalPlayer())
			local genderModels = faction.genderModels
			
			if (!genderModels) then
				local label = wrapper:Add("DLabel")
				label:SetFont("ixMenuButtonLabelFont")
				label:SetText(L("appearance"):utf8upper())
				label:SizeToContents()
				label:DockMargin(0, 32, 0, 8)
				label:Dock(TOP)
			end
			
			if (genderModels and payload.model) then
				for _, model in ipairs(genderModels["female"] or {}) do
					if ((isstring(models[payload.model]) and models[payload.model] == model) or 
						(istable(models[payload.model]) and models[payload.model][1] == model)) then
						payload:Set("gender", "female")
						break
					end
				end
			end
			
			local selectedGender = payload.gender or "male"
			local genderComboBox
			
			if (genderModels) then
				local row = wrapper:Add("Panel")
				row:Dock(TOP)
				
				local label = row:Add("DLabel")
				label:SetFont("ixMenuButtonLabelFont")
				label:SetText(L("gender"):utf8upper())
				label:SizeToContents()
				label:DockMargin(0, 32, 0, 8)
				label:Dock(TOP)
				
				genderComboBox = row:Add("DComboBox")
				genderComboBox:Dock(TOP)
				genderComboBox:SetFont("ixMenuButtonFont")
				genderComboBox:SetTall(40)
				genderComboBox:SetSortItems(false)
				genderComboBox.Paint = function(this, w, h)
					surface.SetDrawColor(0, 0, 0, 150)
					surface.DrawRect(0, 0, w, h)
				end
				
				genderComboBox:AddChoice(L("gender_male"), "male")
				genderComboBox:AddChoice(L("gender_female"), "female")
				
				if (selectedGender == "male") then
					genderComboBox:SetValue(L("gender_male"))
				else
					genderComboBox:SetValue(L("gender_female"))
				end
				
				local spacer = row:Add("Panel")
				spacer:SetTall(16)
				spacer:Dock(TOP)
				
				row:InvalidateLayout(true)
				row:SizeToChildren(false, true)
			end
			
			local layout = wrapper:Add("DIconLayout")
			layout:Dock(TOP)
			layout:SetSpaceX(4)
			layout:SetSpaceY(4)
			
			layout.OnSizeChanged = function(this, w, h)
				if (h < 100) then
					this:SetTall(100)
				end
				wrapper:SizeToChildren(false, true)
			end

			local function PopulateModels(gender)
				layout:Clear()
				
				for k, v in SortedPairs(models) do
					local modelPath = isstring(v) and v or v[1]
					local isMatch = false
					
					if (genderModels) then
						for _, gModel in ipairs(genderModels[gender]) do
							if (modelPath == gModel) then
								isMatch = true
								break
							end
						end
					else
						isMatch = true
					end
					
					if (isMatch) then
						local icon = layout:Add("SpawnIcon")
						icon:SetSize(64, 128)
						icon:InvalidateLayout(true)
						icon.DoClick = function(this)
							payload:Set("model", k)
						end
						icon.PaintOver = function(this, w, h)
							if (payload.model == k) then
								local color = ix.config.Get("color", color_white)

								surface.SetDrawColor(color.r, color.g, color.b, 200)

								for i = 1, 3 do
									local i2 = i * 2
									surface.DrawOutlinedRect(i, i, w - i2, h - i2)
								end
							end
						end

						if (isstring(v)) then
							icon:SetModel(v)
						else
							icon:SetModel(v[1], v[2] or 0, v[3])
						end
					end
				end
				
				layout:InvalidateLayout(true)
				layout:SizeToChildren(false, true)
				wrapper:InvalidateLayout(true)
				wrapper:SizeToChildren(false, true)
			end

			if (genderModels) then
				genderComboBox.OnSelect = function(this, index, value, data)
					if (payload.gender != data) then
						payload:Set("gender", data)
						
						local newModels = genderModels[data]
						if (newModels) then
							local randomModelPath = newModels[math.random(#newModels)]
							local newModelIndex = 1
							for k, v in ipairs(models) do
								local path = istable(v) and v[1] or v
								if (path == randomModelPath) then
									newModelIndex = k
									break
								end
							end
							
							payload:Set("model", newModelIndex)
						end

						PopulateModels(data)
					end
				end
				
				if (IsValid(wrapper)) then
					PopulateModels(selectedGender)
				end
			else
				PopulateModels(nil)
			end
		end
		
		wrapper:InvalidateLayout(true)
		wrapper:SizeToChildren(false, true)

		return wrapper
	end
end
