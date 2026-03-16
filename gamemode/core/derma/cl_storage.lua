
local PANEL = {}

AccessorFunc(PANEL, "money", "Money", FORCE_NUMBER)

function PANEL:Init()
	self:DockPadding(1, 1, 1, 1)
	self:SetTall(64)
	self:Dock(BOTTOM)

	self.moneyLabel = self:Add("DLabel")
	self.moneyLabel:Dock(TOP)
	self.moneyLabel:SetFont("ixGenericFont")
	self.moneyLabel:SetText("")
	self.moneyLabel:SetTextInset(2, 0)
	self.moneyLabel:SizeToContents()
	self.moneyLabel.Paint = function(panel, width, height)
		derma.SkinFunc("DrawImportantBackground", 0, 0, width, height, ix.config.Get("color"))
	end

	self.amountEntry = self:Add("ixTextEntry")
	self.amountEntry:Dock(FILL)
	self.amountEntry:SetFont("ixGenericFont")
	self.amountEntry:SetNumeric(true)
	self.amountEntry:SetValue("0")

	self.transferButton = self:Add("DButton")
	self.transferButton:SetFont("ixIconsMedium")
	self:SetLeft(false)
	self.transferButton.DoClick = function()
		local amount = math.max(0, math.Round(tonumber(self.amountEntry:GetValue()) or 0))
		self.amountEntry:SetValue("0")

		if (amount != 0) then
			self:OnTransfer(amount)
		end
	end

	self.bNoBackgroundBlur = true
end

function PANEL:SetLeft(bValue)
	if (bValue) then
		self.transferButton:Dock(LEFT)
		self.transferButton:SetText("s")
	else
		self.transferButton:Dock(RIGHT)
		self.transferButton:SetText("t")
	end
end

function PANEL:SetMoney(money)
	local name = string.gsub(ix.util.ExpandCamelCase(L2(ix.currency.plural, client)), "%s", "")

	self.money = math.max(math.Round(tonumber(money) or 0), 0)
	self.moneyLabel:SetText(string.format("%s: %d", name, money))
end

function PANEL:OnTransfer(amount)
end

function PANEL:Paint(width, height)
	derma.SkinFunc("PaintBaseFrame", self, width, height)
end

vgui.Register("ixStorageMoney", PANEL, "EditablePanel")

DEFINE_BASECLASS("Panel")
PANEL = {}

AccessorFunc(PANEL, "fadeTime", "FadeTime", FORCE_NUMBER)
AccessorFunc(PANEL, "frameMargin", "FrameMargin", FORCE_NUMBER)
AccessorFunc(PANEL, "storageID", "StorageID", FORCE_NUMBER)

function PANEL:Init()
	if (IsValid(ix.gui.openedStorage)) then
		ix.gui.openedStorage:Remove()
	end

	ix.gui.openedStorage = self

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:SetFadeTime(0.25)
	self:SetFrameMargin(4)

	self.storageInventory = self:Add("ixInventory")
	self.storageInventory.bNoBackgroundBlur = true
	self.storageInventory:ShowCloseButton(true)
	self.storageInventory:SetTitle("Storage")
	self.storageInventory.Close = function(this)
		net.Start("ixStorageClose")
		net.SendToServer()
		self:Remove()
	end

	self.storageMoney = self.storageInventory:Add("ixStorageMoney")
	self.storageMoney:SetVisible(false)
	self.storageMoney.OnTransfer = function(_, amount)
		net.Start("ixStorageMoneyTake")
			net.WriteUInt(self.storageID, 32)
			net.WriteUInt(amount, 32)
		net.SendToServer()
	end

	ix.gui.inv1 = self:Add("ixInventory")
	ix.gui.inv1.bNoBackgroundBlur = true
	ix.gui.inv1:ShowCloseButton(true)
	ix.gui.inv1.Close = function(this)
		net.Start("ixStorageClose")
		net.SendToServer()
		self:Remove()
	end

	self.localMoney = ix.gui.inv1:Add("ixStorageMoney")
	self.localMoney:SetVisible(false)
	self.localMoney:SetLeft(true)
	self.localMoney.OnTransfer = function(_, amount)
		net.Start("ixStorageMoneyGive")
			net.WriteUInt(self.storageID, 32)
			net.WriteUInt(amount, 32)
		net.SendToServer()
	end

	self:SetAlpha(0)
	self:AlphaTo(255, self:GetFadeTime())

	self.storageInventory:MakePopup()
	ix.gui.inv1:MakePopup()
end

function PANEL:OnChildAdded(panel)
	panel:SetPaintedManually(true)
end

function PANEL:LayoutInventoryPanels()
	local margin = 32
	local spacing = 8
	local maxWidth = math.floor((self:GetWide() - margin * 2 - spacing) / 2)
	local maxHeight = self:GetTall() - margin * 2
	local storagePanel = self.storageInventory
	local localPanel = ix.gui.inv1

	if (IsValid(storagePanel) and storagePanel.FitToSpace) then
		storagePanel:FitToSpace(maxWidth, maxHeight, 64)
	end

	if (IsValid(localPanel) and localPanel.FitToSpace) then
		localPanel:FitToSpace(maxWidth, maxHeight, 64)
	end

	local leftWidth = IsValid(storagePanel) and storagePanel:GetWide() or 0
	local rightWidth = IsValid(localPanel) and localPanel:GetWide() or 0
	local totalWidth = leftWidth + rightWidth + (IsValid(storagePanel) and IsValid(localPanel) and spacing or 0)
	local startX = math.floor((self:GetWide() - totalWidth) * 0.5)

	if (IsValid(storagePanel)) then
		storagePanel:SetPos(startX, math.floor((self:GetTall() - storagePanel:GetTall()) * 0.5))
	end

	if (IsValid(localPanel)) then
		localPanel:SetPos(
			startX + leftWidth + (IsValid(storagePanel) and IsValid(localPanel) and spacing or 0),
			math.floor((self:GetTall() - localPanel:GetTall()) * 0.5)
		)
	end
end

function PANEL:SetLocalInventory(inventory)
	if (IsValid(ix.gui.inv1) and !IsValid(ix.gui.menu)) then
		ix.gui.inv1:SetInventory(inventory)
		self:LayoutInventoryPanels()
	end
end

function PANEL:SetLocalMoney(money)
	if (!self.localMoney:IsVisible()) then
		self.localMoney:SetVisible(true)
	end

	self.localMoney:SetMoney(money)
	self:LayoutInventoryPanels()
end

function PANEL:SetStorageTitle(title)
	self.storageInventory:SetTitle(L(title))
end

function PANEL:SetStorageInventory(inventory)
	self.storageInventory:SetInventory(inventory)
	self:LayoutInventoryPanels()

	ix.gui["inv" .. inventory:GetID()] = self.storageInventory
end

function PANEL:SetStorageMoney(money)
	if (!self.storageMoney:IsVisible()) then
		self.storageMoney:SetVisible(true)
	end

	self.storageMoney:SetMoney(money)
	self:LayoutInventoryPanels()
end

function PANEL:Think()
	local storageTall = IsValid(self.storageInventory) and self.storageInventory:GetTall() or 0
	local localTall = IsValid(ix.gui.inv1) and ix.gui.inv1:GetTall() or 0

	if (
		self.ixLastStorageTall != storageTall or
		self.ixLastLocalTall != localTall
	) then
		self.ixLastStorageTall = storageTall
		self.ixLastLocalTall = localTall
		self:LayoutInventoryPanels()
	end
end

function PANEL:Paint(width, height)
	ix.util.DrawBlurAt(0, 0, width, height)

	for _, v in ipairs(self:GetChildren()) do
		v:PaintManual()
	end
end

function PANEL:Remove()
	self:SetAlpha(255)
	self:AlphaTo(0, self:GetFadeTime(), 0, function()
		BaseClass.Remove(self)
	end)
end

function PANEL:OnRemove()
	if (!IsValid(ix.gui.menu)) then
		self.storageInventory:Remove()
		ix.gui.inv1:Remove()
	end
end

vgui.Register("ixStorageView", PANEL, "Panel")
