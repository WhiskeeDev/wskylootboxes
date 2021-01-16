if SERVER then return end

local menuOpen = false
local menuRef = nil
local width, height = ScrW() / 2, ScrH() / 2
local margin = 4
local padding = 6
local titleBarHeight = 38
local stockItemHeight = 65

hook.Add("PlayerButtonDown", "WskyTTTLootboxes_RequestInventoryData", function (ply, key)
  if (menuOpen or (key ~= KEY_F3 and key ~= KEY_I)) then return end
  requestNewData(true)
  menuOpen = true
end)

function rightClickItem(frame, item, itemID, itemName, itemPreviewData, inventoryModelPreview)
  if (!frame or !item) then return end

  -- Find cursor position and create menu.
  local posX, posY = frame:LocalCursorPos()
  local Menu = vgui.Create("DMenu", frame)
  Menu:SetPos(posX, posY)
  Menu:MoveToFront()

  -- Check if Item is a crate
  local crateTag = "crate_"
  if (string.StartWith(item.type, crateTag)) then
    Menu:AddOption("Open Crate", function ()
      net.Start("WskyTTTLootboxes_RequestCrateOpening")
        net.WriteString(itemID)
      net.SendToServer()
    end)
    Menu:AddSpacer()
  end
  
  
  local itemIsEquipped = (itemID == playerData.activeMeleeWeapon.itemID) or (itemID == playerData.activePrimaryWeapon.itemID) or (itemID == playerData.activeSecondaryWeapon.itemID) or (itemID == playerData.activePlayerModel.itemID)

  -- Check if Item is a playerModel or weapon
  if (not itemIsEquipped and (item.type == "playerModel" or item.type == "weapon")) then
    Menu:AddOption("Equip", function ()
      net.Start("WskyTTTLootboxes_EquipItem")
        net.WriteString(itemID)
      net.SendToServer()
      if (item.type == "playerModel" and inventoryModelPreview and item.modelName) then  inventoryModelPreview:SetModel(item.modelName) end
    end)
    Menu:AddSpacer()
  elseif (itemIsEquipped and (item.type == "playerModel" or item.type == "weapon")) then
    Menu:AddOption("Unequip", function ()
      net.Start("WskyTTTLootboxes_UnequipItem")
        net.WriteString(itemID)
      net.SendToServer()
    end)
    Menu:AddSpacer()
  end

  -- Give option to scrap/delete, if allowed.
  local scrapText = "Scrap Item (" .. item.value .. ")"
  if (item.value < 1) then scrapText = "Delete item" end
  if (item.value > -1) then
    Menu:AddOption(scrapText, function ()
      local width, height = width / 4, height / 4
      width = math.max(350, width)
      height = math.max(100, height)

      createDialog(width, height, "Are you sure you want to scrap this item?" , function ()
        net.Start("WskyTTTLootboxes_ScrapItem")
          net.WriteString(itemID)
        net.SendToServer()
      end)
    end)
    Menu:AddSpacer()
  end

  -- Give option to put on market, if allowed.
  local marketText = "Put item on market"
  if (item.value > -1) then
    local value = 0

    Menu:AddOption(marketText, function ()
      local questionPanel = vgui.Create("DFrame")
      questionPanel:MakePopup()
      questionPanel:SetSize( 400, 200 )
      questionPanel:Center()

      function sellItem()
        if (value and value > -1) then
          net.Start("WskyTTTLootboxes_SellItem")
            net.WriteString(itemID)
            net.WriteFloat(value)
          net.SendToServer()
        end
      end

      local valueEntry = vgui.Create( "DTextEntry", questionPanel )
      valueEntry:Dock(TOP)
      valueEntry:SetPlaceholderText("Enter value you want to sell your item for")
      valueEntry.OnEnter = function( self )
        value = tonumber(self:GetValue())
        questionPanel:Close()

        sellItem()
      end

      local continueBtn = vgui.Create("DButton", questionPanel)
      continueBtn:Dock(BOTTOM)
      continueBtn:SetText("Continue")
      continueBtn.DoClick = function ()
        value = tonumber(valueEntry:GetValue())
        questionPanel:Close()

        sellItem()
      end
    end)
  end
end

function renderMenu()
  if (!TryTranslation) then TryTranslation = LANG and LANG.TryTranslation or nil end

  if (menuRef) then menuRef:Close() end

  local inventoryMenuPanel = createBasicFrame(width, height, "Inventory", true)
  menuRef = inventoryMenuPanel
  inventoryMenuPanel.OnClose = function ()
    menuOpen = false
    menuRef = nil
  end

  local sheet = vgui.Create("DPropertySheet", inventoryMenuPanel)
  sheet:SetPos(0, titleBarHeight)
  sheet:SetSize(width, height - titleBarHeight)
  sheet.Paint = function () end

  local leftInventoryPanel = vgui.Create("DPanel")
  leftInventoryPanel.Paint = function () end

  local rightInventoryPanel = vgui.Create("DPanel")
  rightInventoryPanel.Paint = function () end

  local scroller = vgui.Create("DScrollPanel", leftInventoryPanel)
  scroller:Dock(FILL)
  scroller:InvalidateParent(true)

  local inventoryModelPreview = vgui.Create("DModelPanel", rightInventoryPanel)
  inventoryModelPreview:Dock(FILL)
  inventoryModelPreview:InvalidateParent(true)

  local playerModel = playerData.activePlayerModel.modelName
  if (string.len(playerModel) < 1) then playerModel = LocalPlayer():GetModel() end
  inventoryModelPreview:SetModel(playerModel)
  inventoryModelPreview:SetCamPos(Vector(0, -40, 45))
  function inventoryModelPreview.Entity:GetPlayerColor()
    return LocalPlayer():GetPlayerColor():ToColor() or Vector(1, 1, 1)
  end

  local divider = vgui.Create("DHorizontalDivider", sheet, "inventoryDivider")
  divider:Dock(FILL)
  divider:SetLeft(leftInventoryPanel)
  divider:SetRight(rightInventoryPanel)
  divider:SetDividerWidth(4)
  divider:SetLeftMin(width * 0.75)
  divider:SetLeftWidth(width * 0.75)
  divider:SetRightMin(width * 0.25)

  sheet:AddSheet("Inventory", divider)

  local storePanel = vgui.Create("DPanel", sheet)
  storePanel:Dock(FILL)
  storePanel.Paint = function () end
  sheet:AddSheet("Store", storePanel)

  -- local tradingPanel = vgui.Create("DPanel", sheet)
  -- tradingPanel:Dock(FILL)
  -- tradingPanel.Paint = function () end
  -- sheet:AddSheet("Trading", tradingPanel)

  local marketPanel = vgui.Create("DPanel", sheet)
  marketPanel:Dock(FILL)
  marketPanel.Paint = function () end
  sheet:AddSheet("Market", marketPanel)

  local marketScroller = vgui.Create("DScrollPanel", marketPanel)
  marketScroller:Dock(FILL)
  marketScroller.Paint = function () end


  -- draw inventory

  local itemNum = 0
  for itemIndex, item in pairs(playerData.inventory) do
    local itemID = item.itemID
    itemNum = itemNum + 1
    local itemName = getItemName(item)
    local itemPreviewData = getItemPreview(item)

    local offset = (itemNum - 1)
    local itemHeight = stockItemHeight
    local itemPanel = vgui.Create("DButton", scroller)
    local y = (itemHeight * offset) + (padding * offset) + padding

    itemPanel:Dock(TOP)
    itemPanel:DockMargin(margin, margin, margin, margin)
    itemPanel:SetHeight(itemHeight)
    itemPanel:SetText("")
    itemPanel:SetMouseInputEnabled(true)

    itemPanel.Paint = function (self, w, h)
      local color = Color(0, 0, 0, 80)
      draw.RoundedBox(0, 0, 0, w, h, color)
    end

    local itemPreviewContainer = vgui.Create("DPanel", itemPanel)
    itemPreviewContainer:SetMouseInputEnabled(true)
    itemPreviewContainer:Dock(LEFT)
    itemPreviewContainer:SetHeight(itemHeight)
    itemPreviewContainer:SetWidth(itemHeight)
    itemPreviewContainer.Paint = function (self, w, h)
      local color = Color(255, 255, 255, 20)
      draw.RoundedBox(0, 0, 0, w, h, color)
    end

    if (itemPreviewData.type == "icon") then
      local itemImage = vgui.Create("DImage", itemPreviewContainer)
      itemImage:Dock(FILL)
      itemImage:SetImage(itemPreviewData.data)
      itemImage:SetMouseInputEnabled(true)
    else
      local itemPreview = vgui.Create("DModelPanel", itemPreviewContainer)
      itemPreview:Dock(FILL)
      itemPreview:SetModel(itemPreviewData.data)
      itemPreview:SetMouseInputEnabled(false)
      itemPreview:SetMouseInputEnabled(true)

      function itemPreview:LayoutEntity(ent)
        if (itemPreviewData.type == "playerModel") then return end

        local rotation = -15
        if (ent:GetModel() == "models/weapons/w_crowbar.mdl") then
          rotation = 105
        end
        ent:SetAngles(Angle(rotation, 0, 0))
        return
      end

      local center = itemPreview.Entity:OBBCenter()
      itemPreview:SetLookAt(center-Vector(2, 0, -5))
      itemPreview:SetCamPos(center-Vector(-10, -20, -5))
      itemPreview:SetDirectionalLight(BOX_RIGHT, Color(255, 255, 255, 255))

      if (itemPreviewData.type == "playerModel") then
        local boneIndex = itemPreview.Entity:LookupBone("ValveBiped.Bip01_Head1")
        local eyepos = itemPreview.Entity:GetBonePosition(boneIndex or 0)
        eyepos:Add(Vector(0, 0, 2))	-- Move up slightly
        itemPreview:SetLookAt(eyepos)
        itemPreview:SetCamPos(eyepos-Vector(-14, 0, 0))	-- Move cam in front of eyes
        itemPreview.Entity:SetEyeTarget(eyepos-Vector(-12, 0, 0))
      end
    end

    local itemInfoPanel = vgui.Create("DPanel", itemPanel)
    itemInfoPanel:SetMouseInputEnabled(true)
    itemInfoPanel:Dock(FILL)
    itemInfoPanel.Paint = function (self, w, h)
      draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 0))
      surface.SetFont("WskyFontSmaller")
      local _, textHeight = surface.GetTextSize(itemName)
      local color = Color(255, 255, 255, 255)
      if (item.tier == "Exotic") then
        color = Color(240, 190, 15, 255)
      elseif (item.tier == "Legendary") then
        color = Color(170, 115, 235, 255)
      elseif (item.tier == "Rare") then
        color = Color(40, 140, 195, 255)
      elseif (item.tier == "Uncommon") then
        color = Color(40, 155, 115, 255)
      end
      draw.SimpleText(itemName, "WskyFontSmaller", padding, padding, color)
      if (item.type == "weapon") then
        draw.SimpleText(getWeaponCategory(item.className) .. " weapon", "WskyFontSmaller", padding, textHeight + padding)
      end
    end

    local itemButtonClickable = vgui.Create("DButton", itemPanel)
    itemButtonClickable:SetPos(0, 0)
    itemButtonClickable:SetSize(divider:GetLeftWidth() - (margin * 2), itemHeight)
    itemButtonClickable:SetText("")
    itemButtonClickable:SetMouseInputEnabled(true)
    itemButtonClickable.Paint = function (self, w, h)
      local equipped = false
      
      if (item.type == 'playerModel' and playerData.activePlayerModel.itemID == itemID) then
          equipped = true
      elseif (item.type == 'weapon') then
        if (playerData.activeMeleeWeapon.itemID == itemID) then
          equipped = true
        elseif (playerData.activePrimaryWeapon.itemID == itemID) then
          equipped = true
        elseif (playerData.activeSecondaryWeapon.itemID == itemID) then
          equipped = true
        end
      end

      if (equipped) then
        surface.SetDrawColor(120, 255, 120, 120)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
      end
    end
    itemButtonClickable.DoRightClick = function () rightClickItem(inventoryMenuPanel, item, itemID, itemName, itemPreviewData, inventoryModelPreview) end

  end

  -- draw store items

  local itemNum = 0
  for itemIndex, item in pairs(storeItems) do
    local itemID = item.itemID
    itemNum = itemNum + 1
    local itemName = getItemName(item)
    local itemPreviewData = getItemPreview(item)

    local offset = (itemNum - 1)
    local itemHeight = stockItemHeight
    local itemPanel = vgui.Create("DButton", storePanel)
    local y = (itemHeight * offset) + (padding * offset) + padding

    itemPanel:Dock(TOP)
    itemPanel:DockMargin(margin, margin, margin, margin)
    itemPanel:SetHeight(itemHeight)
    itemPanel:SetText("")
    itemPanel:SetMouseInputEnabled(true)

    itemPanel.Paint = function (self, w, h)
      local color = Color(0, 0, 0, 80)
      draw.RoundedBox(0, 0, 0, w, h, color)
    end

    local itemPreviewContainer = vgui.Create("DPanel", itemPanel)
    itemPreviewContainer:SetMouseInputEnabled(true)
    itemPreviewContainer:Dock(LEFT)
    itemPreviewContainer:SetHeight(itemHeight)
    itemPreviewContainer:SetWidth(itemHeight)
    itemPreviewContainer.Paint = function (self, w, h)
      local color = Color(255, 255, 255, 20)
      draw.RoundedBox(0, 0, 0, w, h, color)
    end

    local itemPriceTag = vgui.Create("DPanel", itemPanel)
    itemPriceTag:Dock(RIGHT)
    itemPriceTag:SetHeight(itemHeight)
    itemPriceTag:SetWidth(itemHeight)
    itemPriceTag.Paint = function (self, w, h)
      local color = Color(0, 202, 255, 225)
      draw.RoundedBox(0, 0, 0, w, h, color)

      surface.SetFont("WskyFontSmaller")
      local text = item.value
      local priceWidth, priceHeight = surface.GetTextSize(text)
      draw.SimpleText(text, "WskyFontSmaller", (w - priceWidth) / 2, (h - priceHeight) / 2)
    end

    if (itemPreviewData.type == "icon") then
      local itemImage = vgui.Create("DImage", itemPreviewContainer)
      itemImage:Dock(FILL)
      itemImage:SetImage(itemPreviewData.data)
      itemImage:SetMouseInputEnabled(true)
    else
      local itemPreview = vgui.Create("DModelPanel", itemPreviewContainer)
      itemPreview:Dock(FILL)
      itemPreview:SetModel(itemPreviewData.data)
      itemPreview:SetMouseInputEnabled(false)
      itemPreview:SetMouseInputEnabled(true)

      function itemPreview:LayoutEntity(ent)
        if (itemPreviewData.type == "playerModel") then return end

        local rotation = -15
        if (ent:GetModel() == "models/weapons/w_crowbar.mdl") then
          rotation = 105
        end
        ent:SetAngles(Angle(rotation, 0, 0))
        return
      end

      local center = itemPreview.Entity:OBBCenter()
      itemPreview:SetLookAt(center-Vector(2, 0, -5))
      itemPreview:SetCamPos(center-Vector(-10, -20, -5))
      itemPreview:SetDirectionalLight(BOX_RIGHT, Color(255, 255, 255, 255))

      if (itemPreviewData.type == "playerModel") then
        local boneIndex = itemPreview.Entity:LookupBone("ValveBiped.Bip01_Head1")
        local eyepos = itemPreview.Entity:GetBonePosition(boneIndex or 0)
        eyepos:Add(Vector(0, 0, 2))	-- Move up slightly
        itemPreview:SetLookAt(eyepos)
        itemPreview:SetCamPos(eyepos-Vector(-14, 0, 0))	-- Move cam in front of eyes
        itemPreview.Entity:SetEyeTarget(eyepos-Vector(-12, 0, 0))
      end
    end

    local itemInfoPanel = vgui.Create("DPanel", itemPanel)
    itemInfoPanel:SetMouseInputEnabled(true)
    itemInfoPanel:Dock(FILL)
    itemInfoPanel.Paint = function (self, w, h)
      draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 0))
      surface.SetFont("WskyFontSmaller")
      draw.SimpleText(itemName, "WskyFontSmaller", margin, margin)
    end

    local itemButtonClickable = vgui.Create("DButton", itemPanel)
    itemButtonClickable:SetPos(0, 0)
    itemButtonClickable:SetSize(divider:GetLeftWidth() - (margin * 2), itemHeight)
    itemButtonClickable:SetText("")
    itemButtonClickable:SetMouseInputEnabled(true)
    itemButtonClickable.Paint = function (self, w, h)
      local equipped = false
      
      if (item.type == 'playerModel' and playerData.activePlayerModel.itemID == itemID) then
          equipped = true
      elseif (item.type == 'weapon') then
        if (playerData.activeMeleeWeapon.itemID == itemID) then
          equipped = true
        elseif (playerData.activePrimaryWeapon.itemID == itemID) then
          equipped = true
        elseif (playerData.activeSecondaryWeapon.itemID == itemID) then
          equipped = true
        end
      end

      if (equipped) then
        surface.SetDrawColor(120, 255, 120, 120)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
      end
    end
    itemButtonClickable.DoClick = function () 
      net.Start("WskyTTTLootboxes_BuyFromStore")
        net.WriteFloat(itemIndex)
      net.SendToServer()
    end

  end

  -- draw market items

  local itemNum = 0
  for itemIndex, item in pairs(marketData.items) do
    local itemID = item.itemID
    itemNum = itemNum + 1
    local itemName = getItemName(item)
    local itemPreviewData = getItemPreview(item)

    local offset = (itemNum - 1)
    local itemHeight = stockItemHeight
    local itemPanel = vgui.Create("DButton", marketScroller)
    local y = (itemHeight * offset) + (padding * offset) + padding

    itemPanel:Dock(TOP)
    itemPanel:DockMargin(margin, margin, margin, margin)
    itemPanel:SetHeight(itemHeight)
    itemPanel:SetText("")
    itemPanel:SetMouseInputEnabled(true)

    itemPanel.Paint = function (self, w, h)
      local color = Color(0, 0, 0, 80)
      draw.RoundedBox(0, 0, 0, w, h, color)
    end

    local itemPreviewContainer = vgui.Create("DPanel", itemPanel)
    itemPreviewContainer:SetMouseInputEnabled(true)
    itemPreviewContainer:Dock(LEFT)
    itemPreviewContainer:SetHeight(itemHeight)
    itemPreviewContainer:SetWidth(itemHeight)
    itemPreviewContainer.Paint = function (self, w, h)
      local color = Color(255, 255, 255, 20)
      draw.RoundedBox(0, 0, 0, w, h, color)
    end

    local itemPriceTag = vgui.Create("DPanel", itemPanel)
    itemPriceTag:Dock(RIGHT)
    itemPriceTag:SetHeight(itemHeight)
    itemPriceTag:SetWidth(itemHeight)
    itemPriceTag.Paint = function (self, w, h)
      local color = Color(0, 202, 255, 225)
      draw.RoundedBox(0, 0, 0, w, h, color)

      surface.SetFont("WskyFontSmaller")
      local text = item.value
      local priceWidth, priceHeight = surface.GetTextSize(text)
      draw.SimpleText(text, "WskyFontSmaller", (w - priceWidth) / 2, (h - priceHeight) / 2)
    end

    if (itemPreviewData.type == "icon") then
      local itemImage = vgui.Create("DImage", itemPreviewContainer)
      itemImage:Dock(FILL)
      itemImage:SetImage(itemPreviewData.data)
      itemImage:SetMouseInputEnabled(true)
    else
      local itemPreview = vgui.Create("DModelPanel", itemPreviewContainer)
      itemPreview:Dock(FILL)
      itemPreview:SetModel(itemPreviewData.data)
      itemPreview:SetMouseInputEnabled(false)
      itemPreview:SetMouseInputEnabled(true)

      function itemPreview:LayoutEntity(ent)
        if (itemPreviewData.type == "playerModel") then return end

        local rotation = -15
        if (ent:GetModel() == "models/weapons/w_crowbar.mdl") then
          rotation = 105
        end
        ent:SetAngles(Angle(rotation, 0, 0))
        return
      end

      local center = itemPreview.Entity:OBBCenter()
      itemPreview:SetLookAt(center-Vector(2, 0, -5))
      itemPreview:SetCamPos(center-Vector(-10, -20, -5))
      itemPreview:SetDirectionalLight(BOX_RIGHT, Color(255, 255, 255, 255))

      if (itemPreviewData.type == "playerModel") then
        local boneIndex = itemPreview.Entity:LookupBone("ValveBiped.Bip01_Head1")
        local eyepos = itemPreview.Entity:GetBonePosition(boneIndex or 0)
        eyepos:Add(Vector(0, 0, 2))	-- Move up slightly
        itemPreview:SetLookAt(eyepos)
        itemPreview:SetCamPos(eyepos-Vector(-14, 0, 0))	-- Move cam in front of eyes
        itemPreview.Entity:SetEyeTarget(eyepos-Vector(-12, 0, 0))
      end
    end

    local itemInfoPanel = vgui.Create("DPanel", itemPanel)
    itemInfoPanel:SetMouseInputEnabled(true)
    itemInfoPanel:Dock(FILL)
    itemInfoPanel.Paint = function (self, w, h)
      draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 0))
      surface.SetFont("WskyFontSmaller")
      local _, textHeight = surface.GetTextSize(itemName)
      local color = Color(255, 255, 255, 255)
      if (item.tier == "Exotic") then
        color = Color(240, 190, 15, 255)
      elseif (item.tier == "Legendary") then
        color = Color(170, 115, 235, 255)
      elseif (item.tier == "Rare") then
        color = Color(40, 140, 195, 255)
      elseif (item.tier == "Uncommon") then
        color = Color(40, 155, 115, 255)
      end
      draw.SimpleText(itemName, "WskyFontSmaller", margin, margin, color)
      draw.SimpleText("Seller: " .. item.ownerName and item.ownerName or item.owner, "WskyFontSmaller", margin, textHeight + margin)
    end

    local itemButtonClickable = vgui.Create("DButton", itemPanel)
    itemButtonClickable:SetPos(0, 0)
    itemButtonClickable:SetSize(divider:GetLeftWidth() - (margin * 2), itemHeight)
    itemButtonClickable:SetText("")
    itemButtonClickable:SetMouseInputEnabled(true)
    itemButtonClickable.Paint = function (self, w, h)
      local equipped = false
      
      if (item.type == 'playerModel' and playerData.activePlayerModel.itemID == itemID) then
          equipped = true
      elseif (item.type == 'weapon') then
        if (playerData.activeMeleeWeapon.itemID == itemID) then
          equipped = true
        elseif (playerData.activePrimaryWeapon.itemID == itemID) then
          equipped = true
        elseif (playerData.activeSecondaryWeapon.itemID == itemID) then
          equipped = true
        end
      end

      if (equipped) then
        surface.SetDrawColor(120, 255, 120, 120)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
      end
    end
    itemButtonClickable.DoClick = function () 
      net.Start("WskyTTTLootboxes_BuyFromMarket")
        net.WriteFloat(itemIndex)
      net.SendToServer()
    end

  end

  local bottomPaddingBlock = vgui.Create("DPanel", scroller)
  bottomPaddingBlock:Dock(TOP)
  bottomPaddingBlock:DockMargin(margin, margin * 2, margin * 2, margin)
  bottomPaddingBlock:SetHeight(itemHeight)
  bottomPaddingBlock:SetText("")
  bottomPaddingBlock:SetMouseInputEnabled(true)
end

net.Receive("WskyTTTLootboxes_OpenPlayerInventory", renderMenu)