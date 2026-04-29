
ENT.Type = "anim"
ENT.PrintName = "Container"
ENT.Category = "Helix"
ENT.Spawnable = false
ENT.bNoPersist = true

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "ID")
	self:NetworkVar("Bool", 0, "Locked")
	self:NetworkVar("String", 0, "DisplayName")
	self:NetworkVar("Bool", 1, "Fixed")
end

if (SERVER) then
	function ENT:Initialize()
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		self.receivers = {}
		self.Sessions = {}
		self.PasswordAttempts = {}

		local model = self:GetModel()
		local definition = ix.container.stored[model:lower()]

		if (definition) then
			self:SetDisplayName(definition.name)
		end

		local physObj = self:GetPhysicsObject()

		if (IsValid(physObj)) then
			physObj:EnableMotion(true)
			physObj:Wake()
		end

		ix.container.healthCache = ix.container.healthCache or {}
		local health = ix.container.healthCache[model]

		if (!health) then
			local dummy = ents.Create("prop_physics")
			dummy:SetModel(model)
			dummy:Spawn()

			health = dummy:Health() or 0
			ix.container.healthCache[model] = health
			dummy:Remove()
		end

		if (health > 0) then
			self:SetHealth(health)
			self:SetMaxHealth(health)
			self:SetNetVar("maxHealth", health)
			self:SetNetVar("health", health)
			self:SetNetVar("bNativelyDestructible", true)
			if (!self:GetNetVar("bNotDestructible")) then
				self.bDestructible = true
			end
		end
	end

	function ENT:OnTakeDamage(dmginfo)
		if (self.bDestructible and !self.bDestroying) then
			local newHealth = math.max(0, self:Health() - dmginfo:GetDamage())
			self:SetHealth(newHealth)
			self:SetNetVar("health", newHealth)

			if (newHealth <= 0) then
				self.bDestroying = true

				self:GibBreakClient(VectorRand() * 100)

				local phys = self:GetPhysicsObject()
				if (IsValid(phys)) then
					local surfaceData = util.GetSurfaceData(util.GetSurfaceIndex(phys:GetMaterial()))
					if (surfaceData and surfaceData.breakSound and surfaceData.breakSound != "") then
						self:EmitSound(surfaceData.breakSound, 75, 100)
					end
				end

				local inventory = self:GetInventory()

				if (inventory) then
					local items = inventory:GetItems()

					for _, v in pairs(items) do
						v.invID = 0

						local query = mysql:Update("ix_items")
							query:Update("inventory_id", 0)
							query:Where("item_id", v.id)
						query:Execute()

						ix.item.inventories[0] = ix.item.inventories[0] or {}
						ix.item.inventories[0][v.id] = v

						local bEnt = v:Spawn(self:LocalToWorld(self:OBBCenter()) + VectorRand() * 5)

						if (IsValid(bEnt)) then
							local phys = bEnt:GetPhysicsObject()

							if (IsValid(phys)) then
								phys:Wake()
								phys:ApplyForceCenter(VectorRand() * 50)
							end
						end
					end
				end

				self:Remove()
			end
		end
	end

	function ENT:SetInventory(inventory)
		if (inventory) then
			self:SetID(inventory:GetID())
		end
	end

	function ENT:SetMoney(amount)
		self.money = math.max(0, math.Round(tonumber(amount) or 0))
	end

	function ENT:GetMoney()
		return self.money or 0
	end

	function ENT:OnRemove()
		local index = self:GetID()

		if (!ix.shuttingDown and !self.ixIsSafe and ix.entityDataLoaded and index) then
			local inventory = ix.item.inventories[index]

			if (inventory) then
				ix.item.inventories[index] = nil

				local query = mysql:Delete("ix_items")
					query:Where("inventory_id", index)
				query:Execute()

				query = mysql:Delete("ix_inventories")
					query:Where("inventory_id", index)
				query:Execute()

				hook.Run("ContainerRemoved", self, inventory)
			end
		end
	end

	function ENT:OpenInventory(activator)
		local inventory = self:GetInventory()

		if (inventory) then
			local name = self:GetDisplayName()
			local definition = ix.container.stored[self:GetModel():lower()]

			ix.storage.Open(activator, inventory, {
				name = name,
				entity = self,
				searchTime = ix.config.Get("containerOpenTime", 0.7),
				data = {money = self:GetMoney()},
				OnPlayerOpen = function()
					if (definition and definition.OnOpen) then
					    definition.OnOpen(self, activator)
					end
				end,
				OnPlayerClose = function()
					if (definition and definition.OnClose) then
						definition.OnClose(self, activator)
					end

					ix.log.Add(activator, "closeContainer", name, inventory:GetID())
				end
			})

			if (self:GetLocked()) then
				self.Sessions = self.Sessions or {}
				self.Sessions[activator:GetCharacter():GetID()] = true
			end

			ix.log.Add(activator, "openContainer", name, inventory:GetID())
		end
	end

	function ENT:Use(activator)
		local inventory = self:GetInventory()

		if (inventory and (activator.ixNextOpen or 0) < CurTime()) then
			local character = activator:GetCharacter()

			if (character) then
				local definition = ix.container.stored[self:GetModel():lower()]

				self.Sessions = self.Sessions or {}

				if (self:GetLocked() and !self.Sessions[character:GetID()]) then
					self:EmitSound(definition and definition.locksound or "doors/default_locked.wav")

					if (!self.keypad) then
						net.Start("ixContainerPassword")
							net.WriteEntity(self)
						net.Send(activator)
					end
				else
					self:OpenInventory(activator)
				end
			end

			activator.ixNextOpen = CurTime() + 1
		end
	end
else
	ENT.PopulateEntityInfo = true

	local COLOR_LOCKED = Color(200, 38, 19, 200)
	local COLOR_UNLOCKED = Color(135, 211, 124, 200)

	function ENT:OnPopulateEntityInfo(tooltip)
		local definition = ix.container.stored[self:GetModel():lower()]
		local bLocked = self:GetLocked()

		surface.SetFont("ixIconsSmall")

		local iconText = bLocked and "P" or "Q"
		local iconWidth, iconHeight = surface.GetTextSize(iconText)

		-- minimal tooltips have centered text so we'll draw the icon above the name instead
		if (tooltip:IsMinimal()) then
			local icon = tooltip:AddRow("icon")
			icon:SetFont("ixIconsSmall")
			icon:SetTextColor(bLocked and COLOR_LOCKED or COLOR_UNLOCKED)
			icon:SetText(iconText)
			icon:SizeToContents()
		end

		local title = tooltip:AddRow("name")
		title:SetImportant()
		title:SetText(L(self:GetDisplayName()))
		title:SetBackgroundColor(ix.config.Get("color"))
		title:SetTextInset(iconWidth + 8, 0)
		title:SizeToContents()

		if (!tooltip:IsMinimal()) then
			title.Paint = function(panel, width, height)
				panel:PaintBackground(width, height)

				surface.SetFont("ixIconsSmall")
				surface.SetTextColor(bLocked and COLOR_LOCKED or COLOR_UNLOCKED)
				surface.SetTextPos(4, height * 0.5 - iconHeight * 0.5)
				surface.DrawText(iconText)
			end
		end

		if (definition) then
			local description = tooltip:AddRow("description")
			description:SetText(L(definition.description))
			description:SizeToContents()
		end

		if (self:GetNetVar("bNativelyDestructible") and !self:GetNetVar("bNotDestructible")) then
			local status = tooltip:AddRow("status")
			status:SetVisible(false)

			local oldThink = tooltip.Think
			tooltip.Think = function(pnl)
				if (oldThink) then oldThink(pnl) end
				if (!IsValid(self) or !IsValid(status)) then return end

				local health = self:GetNetVar("health", self:Health())
				local maxHealth = self:GetNetVar("maxHealth", self:GetMaxHealth())

				if (health and maxHealth and maxHealth > 0) then
					local percent = health / maxHealth

					local statusText
					if (percent <= 0.3) then
						statusText = "containerStatus30"
					elseif (percent <= 0.5) then
						statusText = "containerStatus50"
					elseif (percent <= 0.7) then
						statusText = "containerStatus70"
					end

					if (statusText) then
						local localized = L(statusText)
						if (status:GetText() != localized or !status:IsVisible()) then
							status:SetText(localized)
							status:SizeToContents()
							status:SetVisible(true)
							pnl:SizeToContents()
						end

						if (percent <= 0.3) then
							status:SetBackgroundColor(Color(180, 50, 50))
						elseif (percent <= 0.5) then
							status:SetBackgroundColor(Color(180, 100, 50))
						else
							status:SetBackgroundColor(Color(180, 180, 50))
						end
					else
						if (status:IsVisible()) then
							status:SetText("")
							status:SizeToContents()
							status:SetVisible(false)
							status:SetBackgroundColor(Color(0, 0, 0, 0))
							pnl:SizeToContents()
						end
					end
				else
					if (status:IsVisible()) then
						status:SetText("")
						status:SizeToContents()
						status:SetVisible(false)
						status:SetBackgroundColor(Color(0, 0, 0, 0))
						pnl:SizeToContents()
					end
				end
			end
		end
	end
end

function ENT:GetInventory()
	return ix.item.inventories[self:GetID()]
end
