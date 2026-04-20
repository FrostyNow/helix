
local PLUGIN = PLUGIN

PLUGIN.name = "Containers"
PLUGIN.author = "Chessnut"
PLUGIN.description = "Provides the ability to store items."

ix.container = ix.container or {}
ix.container.stored = ix.container.stored or {}

ix.config.Add("containerSave", true, "Whether or not containers will save after a server restart.", nil, {
	category = "Containers"
})

ix.config.Add("containerOpenTime", 0.7, "How long it takes to open a container.", nil, {
	data = {min = 0, max = 50},
	category = "Containers"
})

ix.lang.AddTable("english", {
	containerCrateDesc = "A simple wooden crate.",
	containerLockerDesc = "A white locker.",
	containerMetalCabinetDesc = "A green metal cabinet.",
	containerFileCabinetDesc = "A metal filing cabinet.",
	containerRefrigeratorDesc = "A metal box for keeping food in.",
	containerLargeRefrigeratorDesc = "A large metal box for storing even more food in.",
	containerTrashBinDesc = "What do you expect to find in here?",
	containerDumpsterDesc = "A dumpster meant to stow away trash. It emanates an unpleasant smell.",
	containerAmmoCrateDesc = "A heavy crate that stores ammo.",
	containerFootlockerDesc = "A small chest to store belongings in.",
	containerItemCrateDesc = "A crate to store some belongings in.",
	containerCashRegisterDesc = "A register with some buttons and a drawer.",
	containerCardboardBoxDesc = "A simple cardboard box.",
	containerTrashCanDesc = "What do you expect to find in here?",
	containerDrawerDesc = "A simple drawer that slides in and out to open and close and is used for keeping things in.",
	containerDresserDesc = "A bedroom furniture used especially for keeping clothes in.",
	containerStoveDesc = "A large box-shaped device that is used to cook and heat food, either by putting the food inside or by putting it on the top.",
	containerWashingMachineDesc = "A machine for washing clothes, sheets, and other things made of cloth.",
	containerDeskDesc = "A table with drawers that you can work at.",
	containerMetalDeskDesc = "A table with drawers that you can work at.",
	containerIndestructible = "Container is now INDESTRUCTIBLE.",
	containerDestructible = "Container is now DESTRUCTIBLE.",
	containerStatus70 = "It is slightly damaged.",
	containerStatus50 = "It is heavily damaged.",
	containerStatus30 = "It is severely damaged and about to break.",
})

ix.lang.AddTable("korean", {
	["Crate"] = "나무 상자",
	containerCrateDesc = "평범한 나무 상자입니다.",
	["Locker"] = "사물함",
	containerLockerDesc = "하얀색 사물함입니다.",
	["Metal Cabinet"] = "철제 보관장",
	containerMetalCabinetDesc = "녹색 철제 보관장입니다.",
	["File Cabinet"] = "서랍",
	containerFileCabinetDesc = "철제 서랍입니다.",
	["Refrigerator"] = "냉장고",
	containerRefrigeratorDesc = "음식을 차갑게 보관할 수 있습니다.",
	["Large Refrigerator"] = "대형 냉장고",
	containerLargeRefrigeratorDesc = "더 많은 음식을 차갑게 보관할 수 있습니다.",
	["Trash Bin"] = "쓰레기통",
	containerTrashBinDesc = "여기서 찾을 만한 게 있기는 할까요?",
	["Dumpster"] = "대형 쓰레기통",
	containerDumpsterDesc = "쓰레기를 버리기 위한 대형 쓰레기통입니다. 별로 좋지 않은 냄새가 납니다.",
	["Ammo Crate"] = "탄약 상자",
	containerAmmoCrateDesc = "탄약을 보관하는 무거운 상자입니다.",
	["Footlocker"] = "트렁크",
	containerFootlockerDesc = "잡다한 것을 보관하는 작은 상자입니다.",
	["Item Crate"] = "물품 상자",
	containerItemCrateDesc = "잡다한 것을 보관하는 상자입니다.",
	["Cash Register"] = "금전 등록기",
	containerCashRegisterDesc = "단추가 여럿 달렸고 서랍이 있는 금전 등록기입니다.",
	["Cardboard Box"] = "골판지 상자",
	containerCardboardBoxDesc = "평범한 골판지 상자입니다.",
	["Trash Can"] = "쓰레기통",
	containerTrashCanDesc = "여기서 찾을 만한 게 있기는 할까요?",
	["Drawer"] = "서랍",
	containerDrawerDesc = "밀고 당겨 여닫을 수 있는 서랍입니다.",
	["Dresser"] = "옷장",
	containerDresserDesc = "보통 옷가지를 보관하는 데 쓰이는 침실 가구입니다.",
	["Stove"] = "가스레인지",
	containerStoveDesc = "음식을 안에 두거나 위에 올려 두고, 조리하거나 데우는 데 쓰입니다.",
	["Washing Machine"] = "세탁기",
	containerWashingMachineDesc = "옷이나 이불, 천으로 된 것들을 세탁하는 데 쓰입니다.",
	["Desk"] = "책상",
	containerDeskDesc = "서랍이 달린 사무용 탁자입니다.",
	["Metal Desk"] = "금속 책상",
	containerMetalDeskDesc = "서랍이 달린 사무용 탁자입니다.",
	containerIndestructible = "이제 이 보관함은 부서지지 않습니다.",
	containerDestructible = "이제 이 보관함은 부서질 수 있습니다.",
	containerStatus70 = "조금 파손되었습니다.",
	containerStatus50 = "크게 파손되었습니다.",
	containerStatus30 = "심각하게 파손되어 금방이라도 부서질 것 같습니다.",
})

function ix.container.Register(model, data)
	ix.container.stored[model:lower()] = data
end

ix.util.Include("sh_definitions.lua")

if (SERVER) then
	util.AddNetworkString("ixContainerPassword")
	util.AddNetworkString("ixContainerViewOnly")

	function PLUGIN:PlayerSpawnedProp(client, model, entity)
		model = tostring(model):lower()
		local data = ix.container.stored[model]

		if (data) then
			if (hook.Run("CanPlayerSpawnContainer", client, model, entity) == false) then return end

			local container = ents.Create("ix_container")
			container:SetPos(entity:GetPos())
			container:SetAngles(entity:GetAngles())
			container:SetModel(model)
			container:Spawn()

			ix.inventory.New(0, "container:" .. model:lower(), function(inventory)
				-- we'll technically call this a bag since we don't want other bags to go inside
				inventory.vars.isBag = true
				inventory.vars.isContainer = true

				if (IsValid(container)) then
					container:SetInventory(inventory)
					self:SaveContainer()
				end
			end)

			entity:Remove()
		end
	end

	function PLUGIN:CanSaveContainer(entity, inventory)
		return ix.config.Get("containerSave", true)
	end

	function PLUGIN:SaveContainer()
		local data = {}

		for _, v in ipairs(ents.FindByClass("ix_container")) do
			local inventory = v:GetInventory()

			if (hook.Run("CanSaveContainer", v, inventory) != false) then
				if (inventory) then
					local phys = v:GetPhysicsObject()
					local bFixed = (IsValid(phys) and !phys:IsMoveable())

					data[#data + 1] = {
						v:GetPos(),
						v:GetAngles(),
						inventory:GetID(),
						v:GetModel(),
						v.password,
						v:GetDisplayName(),
						v:GetMoney(),
						bFixed,
						v:GetNetVar("bNotDestructible", false)
					}
				end
			else
				local index = v:GetID()

				local query = mysql:Delete("ix_items")
					query:Where("inventory_id", index)
				query:Execute()

				query = mysql:Delete("ix_inventories")
					query:Where("inventory_id", index)
				query:Execute()
			end
		end

		self:SetData(data)
	end

	function PLUGIN:SaveData()
		if (!ix.shuttingDown) then
			self:SaveContainer()
		end
	end

	function PLUGIN:ContainerRemoved(entity, inventory)
		self:SaveContainer()
	end

	function PLUGIN:PhysgunDrop(client, entity)
		if (entity:GetClass() == "ix_container") then
			local phys = entity:GetPhysicsObject()

			if (IsValid(phys)) then
				entity:SetFixed(!phys:IsMoveable())
			end

			self:SaveContainer()
		end
	end

	function PLUGIN:OnPhysgunFreeze(weapon, phys, entity, client)
		if (entity:GetClass() == "ix_container") then
			entity:SetFixed(true)
			self:SaveContainer()
		end
	end

	function PLUGIN:LoadData()
		local data = self:GetData()

		if (data) then
			for _, v in ipairs(data) do
				local data2 = ix.container.stored[v[4]:lower()]

				if (data2) then
					local inventoryID = tonumber(v[3])

					if (!inventoryID or inventoryID < 1) then
						ErrorNoHalt(string.format(
							"[Helix] Attempted to restore container inventory with invalid inventory ID '%s' (%s, %s)\n",
							tostring(inventoryID), v[6] or "no name", v[4] or "no model"))

						continue
					end

					local entity = ents.Create("ix_container")
					entity:SetPos(v[1])
					entity:SetAngles(v[2])
					entity:SetModel(v[4])
					entity:Spawn()

					if (v[5]) then
						entity.password = v[5]
						entity:SetLocked(true)
						entity.Sessions = {}
						entity.PasswordAttempts = {}
					end

					if (v[6]) then
						entity:SetDisplayName(v[6])
					end

					if (v[7]) then
						entity:SetMoney(v[7])
					end

					ix.inventory.Restore(inventoryID, data2.width, data2.height, function(inventory)
						inventory.vars.isBag = true
						inventory.vars.isContainer = true

						if (IsValid(entity)) then
							entity:SetInventory(inventory)
						end
					end)

					local physObject = entity:GetPhysicsObject()
					local bFixed = v[8]

					if (IsValid(physObject)) then
						physObject:EnableMotion(!bFixed)
						entity:SetFixed(bFixed)
					end

					if (v[9]) then
						entity.bDestructible = false
						entity:SetNetVar("bNotDestructible", true)
					end
				end
			end
		end
	end

	net.Receive("ixContainerPassword", function(length, client)
		if ((client.ixNextContainerPassword or 0) > RealTime()) then
			return
		end

		local entity = net.ReadEntity()
		local steamID = client:SteamID()

		if (!IsValid(entity) or entity:GetClass() != "ix_container") then
			return
		end

		entity.PasswordAttempts = entity.PasswordAttempts or {}
		local attempts = entity.PasswordAttempts[steamID]

		if (attempts and attempts >= 10) then
			client:NotifyLocalized("passwordAttemptLimit")

			return
		end

		local password = net.ReadString()
		local dist = entity:GetPos():DistToSqr(client:GetPos())

		if (dist < 16384 and password) then
			if (entity.password and entity.password == password) then
				entity:OpenInventory(client)
			else
				entity.PasswordAttempts[steamID] = attempts and attempts + 1 or 1

				client:NotifyLocalized("wrongPassword")
			end
		end

		client.ixNextContainerPassword = RealTime() + 1
	end)

	ix.log.AddType("containerPassword", function(client, ...)
		local arg = {...}
		return string.format("%s has %s the password for '%s'.", client:Name(), arg[3] and "set" or "removed", arg[1], arg[2])
	end)

	ix.log.AddType("containerName", function(client, ...)
		local arg = {...}

		if (arg[3]) then
			return string.format("%s has set container %d name to '%s'.", client:Name(), arg[2], arg[1])
		else
			return string.format("%s has removed container %d name.", client:Name(), arg[2])
		end
	end)

	ix.log.AddType("openContainer", function(client, ...)
		local arg = {...}
		return string.format("%s opened the '%s' #%d container.", client:Name(), arg[1], arg[2])
	end, FLAG_NORMAL)

	ix.log.AddType("closeContainer", function(client, ...)
		local arg = {...}
		return string.format("%s closed the '%s' #%d container.", client:Name(), arg[1], arg[2])
	end, FLAG_NORMAL)
else
	net.Receive("ixContainerPassword", function(length)
		local entity = net.ReadEntity()

		Derma_StringRequest(
			L("containerPasswordWrite"),
			L("containerPasswordWrite"),
			"",
			function(val)
				net.Start("ixContainerPassword")
					net.WriteEntity(entity)
					net.WriteString(val)
				net.SendToServer()
			end
		)
	end)

	net.Receive("ixContainerViewOnly", function()
		if (IsValid(ix.gui.openedStorage)) then
			ix.gui.openedStorage.storageInventory:ViewOnly()

			if (IsValid(ix.gui.openedStorage.storageMoney)) then
				ix.gui.openedStorage.storageMoney.transferButton:SetVisible(false)
			end

			if (IsValid(ix.gui.openedStorage.localMoney)) then
				ix.gui.openedStorage.localMoney.transferButton:SetVisible(false)
			end
		end
	end)
end

function PLUGIN:InitializedPlugins()
	for k, v in pairs(ix.container.stored) do
		if (v.name and v.width and v.height) then
			ix.inventory.Register("container:" .. k:lower(), v.width, v.height)
		else
			ErrorNoHalt("[Helix] Container for '"..k.."' is missing all inventory information!\n")
			ix.container.stored[k] = nil
		end
	end
end

function PLUGIN:CanTransferItem(itemDots, oldInv, newInv)
	if (oldInv and oldInv.storageInfo and oldInv.storageInfo.data.bReadOnly) then
		return false
	end

	if (newInv and newInv.storageInfo and newInv.storageInfo.data.bReadOnly) then
		return false
	end
end

-- properties
properties.Add("container_setpassword", {
	MenuLabel = "Set Password",
	Order = 400,
	MenuIcon = "icon16/lock_edit.png",

	Filter = function(self, entity, client)
		if (entity:GetClass() != "ix_container") then return false end
		if (!gamemode.Call("CanProperty", client, "container_setpassword", entity)) then return false end

		return true
	end,

	Action = function(self, entity)
		Derma_StringRequest(L("containerPasswordWrite"), "", "", function(text)
			self:MsgStart()
				net.WriteEntity(entity)
				net.WriteString(text)
			self:MsgEnd()
		end)
	end,

	Receive = function(self, length, client)
		local entity = net.ReadEntity()

		if (!IsValid(entity)) then return end
		if (!self:Filter(entity, client)) then return end

		local password = net.ReadString()

		entity.Sessions = {}
		entity.PasswordAttempts = {}

		if (password:len() != 0) then
			entity:SetLocked(true)
			entity.password = password

			client:NotifyLocalized("containerPassword", password)
		else
			entity:SetLocked(false)
			entity.password = nil

			client:NotifyLocalized("containerPasswordRemove")
		end

		local name = entity:GetDisplayName()
		local inventory = entity:GetInventory()

		ix.log.Add(client, "containerPassword", name, inventory:GetID(), password:len() != 0)
	end
})

properties.Add("container_setname", {
	MenuLabel = "Set Name",
	Order = 400,
	MenuIcon = "icon16/tag_blue_edit.png",

	Filter = function(self, entity, client)
		if (entity:GetClass() != "ix_container") then return false end
		if (!gamemode.Call("CanProperty", client, "container_setname", entity)) then return false end

		return true
	end,

	Action = function(self, entity)
		Derma_StringRequest(L("containerNameWrite"), "", "", function(text)
			self:MsgStart()
				net.WriteEntity(entity)
				net.WriteString(text)
			self:MsgEnd()
		end)
	end,

	Receive = function(self, length, client)
		local entity = net.ReadEntity()

		if (!IsValid(entity)) then return end
		if (!self:Filter(entity, client)) then return end

		local name = net.ReadString()

		if (name:len() != 0) then
			entity:SetDisplayName(name)

			client:NotifyLocalized("containerName", name)
		else
			local definition = ix.container.stored[entity:GetModel():lower()]

			entity:SetDisplayName(definition and definition.name or "Container")

			client:NotifyLocalized("containerNameRemove")
		end

		local inventory = entity:GetInventory()

		ix.log.Add(client, "containerName", name, inventory:GetID(), name:len() != 0)
	end
})

properties.Add("container_view", {
	MenuLabel = "View",
	Order = 400,
	MenuIcon = "icon16/eye.png",

	Filter = function(self, entity, client)
		if (entity:GetClass() != "ix_container") then return false end
		if (!client:IsAdmin()) then return false end

		return true
	end,

	Action = function(self, entity)
		self:MsgStart()
			net.WriteEntity(entity)
		self:MsgEnd()
	end,

	Receive = function(self, length, client)
		local entity = net.ReadEntity()

		if (!IsValid(entity)) then return end
		if (!self:Filter(entity, client)) then return end

		local inventory = entity:GetInventory()

		if (inventory) then
			local bLocked = entity:GetLocked()

			ix.storage.Open(client, inventory, {
				name = entity:GetDisplayName(),
				entity = entity,
				searchTime = 0,
				data = {bReadOnly = bLocked}
			})

			if (bLocked) then
				net.Start("ixContainerViewOnly")
				net.Send(client)
			end
		end
	end
})

properties.Add("container_destructible", {
	MenuLabel = "Toggle Destructibility",
	Order = 401,
	MenuIcon = "icon16/shield.png",

	Filter = function(self, entity, client)
		if (entity:GetClass() != "ix_container") then return false end
		if (!client:IsAdmin()) then return false end
		if (!entity:GetNetVar("bNativelyDestructible")) then return false end

		return true
	end,

	Action = function(self, entity)
		self:MsgStart()
			net.WriteEntity(entity)
		self:MsgEnd()
	end,

	Receive = function(self, length, client)
		local entity = net.ReadEntity()

		if (!IsValid(entity)) then return end
		if (!self:Filter(entity, client)) then return end

		local bCurrent = entity:GetNetVar("bNotDestructible", false)
		local bNew = !bCurrent

		entity:SetNetVar("bNotDestructible", bNew)
		entity.bDestructible = !bNew

		if (bNew) then
			client:NotifyLocalized("containerIndestructible")
		else
			client:NotifyLocalized("containerDestructible")
		end

		ix.log.Add(client, "containerName", bNew and "Indestructible" or "Destructible", entity:GetInventory() and entity:GetInventory():GetID() or 0, true)
	end
})
