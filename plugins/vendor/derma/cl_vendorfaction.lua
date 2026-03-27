local PANEL = {}

function PANEL:Init()
	self:SetSize(384, 420)
	self:Center()
	self:MakePopup()
	self:SetTitle(L"vendorFaction")
	self.scroll = self:Add("DScrollPanel")
	self.scroll:Dock(FILL)
	self.scroll:DockPadding(0, 0, 0, 4)

	self.factions = {}
	self.classes = {}

	for k, v in ipairs(ix.faction.indices) do
		local panel = self.scroll:Add("DPanel")
		panel:Dock(TOP)
		panel:DockPadding(4, 4, 4, 4)
		panel:DockMargin(0, 0, 0, 4)

		local faction = panel:Add("DCheckBoxLabel")
		faction:Dock(TOP)
		faction:SetText(L(v.name))
		faction:DockMargin(0, 0, 0, 4)

		self.factions[v.uniqueID] = faction

		local factionClasses = {}
		for _, v2 in ipairs(ix.class.list) do
			if (v2.faction == k) then
				local class = panel:Add("DCheckBoxLabel")
				class:Dock(TOP)
				class:DockMargin(16, 0, 0, 4)
				class:SetText(L(v2.name))

				-- SetChecked는 OnChange를 트리거하지 않으므로 noSend 불필요.
				-- 사용자가 직접 클릭할 때(DoClick → Toggle)만 OnChange가 발동됨.
				class.OnChange = function(this, state)
					self:updateVendor("class", v2.uniqueID)
				end

				self.classes[v2.uniqueID] = class
				table.insert(factionClasses, {panel = class, uniqueID = v2.uniqueID})

				panel:SetTall(panel:GetTall() + class:GetTall() + 4)
			end
		end

		faction.OnChange = function(this, state)
			-- 팩션 토글 전송
			self:updateVendor("faction", v.uniqueID)

			-- 하위 클래스들을 faction 상태에 맞게 동기화
			for _, classData in ipairs(factionClasses) do
				-- entity.classes 기준으로 현재 서버 상태 확인
				local classEnabled = (self.entity.classes[classData.uniqueID] == true)

				-- 서버 상태와 목표 상태가 다를 때만 토글 요청 전송
				if (state != classEnabled) then
					self:updateVendor("class", classData.uniqueID)
				end

				-- SetChecked는 OnChange를 트리거하지 않으므로 noSend 없이 바로 호출
				classData.panel:SetChecked(state)
			end
		end
	end
end

function PANEL:Setup()
	-- SetChecked는 OnChange를 트리거하지 않으므로 noSend 없이 바로 호출해도 안전
	for k, _ in pairs(self.entity.factions or {}) do
		if (IsValid(self.factions[k])) then
			self.factions[k]:SetChecked(true)
		end
	end

	for k, _ in pairs(self.entity.classes or {}) do
		if (IsValid(self.classes[k])) then
			self.classes[k]:SetChecked(true)
		end
	end
end

vgui.Register("ixVendorFactionEditor", PANEL, "DFrame")
