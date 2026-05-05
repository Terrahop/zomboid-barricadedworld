--- Make the player say a message.
---@param message string Message to say.
local function say(message)
  local player = getSpecificPlayer(0)
  if player then
    player:Say(message)
  end
end

--- Set protection state of iso window or door.
---@param isoObject IsoDoor|IsoWindow
---@param value boolean
local function setProtection(isoObject, value)
  local modData = isoObject:getModData()
  modData["BarricadedWorld:isPlayerPlaced"] = value and true or nil
  isoObject:transmitModData()
end

--- Set protection state of any iso window or door on a square.
---@param square IsoGridSquare
---@param value boolean
---@return integer count of objects modified
local function protectObjectsOnSquare(square, value)
  if not square then
    return 0
  end

  local count = 0
  local squareObjects = square:getObjects()

  for k = 0, squareObjects:size() - 1 do
    local isoObject = squareObjects:get(k)

    if isoObject and (instanceof(isoObject, "IsoWindow") or instanceof(isoObject, "IsoDoor")) then
      ---@cast isoObject IsoDoor|IsoWindow
      setProtection(isoObject, value)
      count = count + 1
    end
  end

  return count
end

--- Attempt to find the building this door or window is a part of.
---@param isoObject IsoDoor|IsoWindow
local function getObjectBuilding(isoObject)
  local sq = isoObject:getSquare()
  if not sq then
    return nil
  end

  local room = sq:getRoom()
  -- Handle south and east tiles that aren't considered inside the building.
  if not room then
    if isoObject:getNorth() then
      -- It's a North wall of the current square
      local adjacent = getCell():getGridSquare(sq:getX(), sq:getY() - 1, sq:getZ())
      if adjacent then
        room = adjacent:getRoom()
      end
    else
      -- It's a West wall of the current square
      local adjacent = getCell():getGridSquare(sq:getX() - 1, sq:getY(), sq:getZ())
      if adjacent then
        room = adjacent:getRoom()
      end
    end
  end

  local building = room:getBuilding()
  if not building then
    return nil
  end

  return building
end

--- Set protection state of every door and window of the building of an IsoObject
---@param isoObject IsoDoor|IsoWindow
---@param value boolean
local function setBuildingProtection(isoObject, value)
  local building = getObjectBuilding(isoObject)
  if not building then
    setProtection(isoObject, value)
    return
  end

  local buildingDef = building:getDef()
  local roomDefs = buildingDef:getRooms()
  local cell = getCell()
  local count = 0

  for i = 0, roomDefs:size() - 1 do
    local roomDef = roomDefs:get(i)
    local isoRoom = roomDef:getIsoRoom()

    if not isoRoom then
      break
    end

    local squares = isoRoom:getSquares()

    for j = 0, squares:size() - 1 do
      local square = squares:get(j)

      if not square then
        break
      end

      local x, y, z = square:getX(), square:getY(), square:getZ()

      -- Objects on this room square (north and west walls)
      count = count + protectObjectsOnSquare(square, value)

      -- South edge: objects with getNorth()==true on the square just below
      -- are the south wall of this room square
      count = count + protectObjectsOnSquare(cell:getGridSquare(x, y + 1, z), value)

      -- East edge: objects with getNorth()==false on the square just right
      -- are the east wall of this room square
      count = count + protectObjectsOnSquare(cell:getGridSquare(x + 1, y, z), value)
    end
  end

  local action = value and "protected" or "unprotected"
  say("Barricaded World: " .. count .. " objects " .. action .. " in this building.")
end

---@param playerIndex integer
---@param context ISContextMenu
---@param worldobjects IsoObject[]
---@diagnostic disable-next-line: unused-local
local function contextMenuOptions(playerIndex, context, worldobjects)
  local options = SandboxVars.BarricadedWorld

  if isClient() or (options.AllowProtectMP and not isAdmin()) then
    return
  end

  ---@type IsoObject|nil
  local tileIsoObject = nil

  for _, worldObject in ipairs(worldobjects) do
    if instanceof(worldObject, "IsoDoor") or instanceof(worldObject, "IsoWindow") then
      tileIsoObject = worldObject
      break
    end
  end

  ---@cast tileIsoObject IsoDoor|IsoWindow

  if not tileIsoObject then
    return
  end

  local barricadedWorldMenu = context:addOption("BarricadedWorld", tileIsoObject, nil)
  local subMenu = context:getNew(context)
  context:addSubMenu(barricadedWorldMenu, subMenu)

  local modData = tileIsoObject:getModData()
  local isProtected = modData["BarricadedWorld:isPlayerPlaced"]
  local objectName = tileIsoObject:getObjectName()

  if isProtected then
    subMenu:addOption("Disable protection for " .. objectName, tileIsoObject, setProtection, false)
  else
    subMenu:addOption("Enable protection for " .. objectName, tileIsoObject, setProtection, true)
  end

  -- On servers, players can claim houses to get building protection with the IgnoreClaimed sandbox option
  if not isClient() then
    local sq = tileIsoObject:getSquare()
    if sq then
      subMenu:addOption("Protect building", tileIsoObject, setBuildingProtection, true)
      subMenu:addOption("Unprotect building", tileIsoObject, setBuildingProtection, false)
    end
  end
end

Events.OnFillWorldObjectContextMenu.Add(contextMenuOptions)
