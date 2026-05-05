if BarricadedWorld == nil then
  BarricadedWorld = {}
end

function BarricadedWorld.setProtection(isoObject, value)
  local modData = isoObject:getModData()
  modData["BarricadedWorld:isPlayerPlaced"] = value
  isoObject:transmitModData()
end

---@param playerIndex integer
---@param context ISContextMenu
---@param worldobjects IsoObject[]
---@diagnostic disable-next-line: unused-local
function BarricadedWorld.contextMenuOptions(playerIndex, context, worldobjects)
  -- local playerObj = getSpecificPlayer(playerIndex)
  local tileIsoObject = nil

  for _, worldObject in ipairs(worldobjects) do
    if instanceof(worldObject, "IsoDoor") then
      tileIsoObject = worldObject
    elseif instanceof(worldObject, "IsoWindow") then
      tileIsoObject = worldObject
    end
  end

  if tileIsoObject then
    local modData = tileIsoObject:getModData()

    if modData["BarricadedWorld:isPlayerPlaced"] then
      context:addOption(
        "[BarricadedWorld] Disable erosion protection for " .. tileIsoObject:getName(),
        tileIsoObject,
        BarricadedWorld.setProtection,
        false
      )
    else
      context:addOption(
        "[BarricadedWorld] Enable erosion protection for " .. tileIsoObject:getName(),
        tileIsoObject,
        BarricadedWorld.setProtection,
        true
      )
    end
  end
end

Events.OnFillWorldObjectContextMenu.Add(BarricadedWorld.contextMenuOptions)
