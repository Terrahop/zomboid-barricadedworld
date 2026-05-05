-----
--- Properties
-----

local state = {
  ErosionSpeedValues = { 20, 50, 100, 200, 500 },
  TimeSinceApoValues = { 0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330, 360 },
  CurrentErosionPercentage = 0,
  CurrentWorldAgeDays = 0,
}

---@enum BarricadedWorldModData
local ModData = {
  IsParsed = "BarricadedWorld:isDefinitiveParsed",
  IsPlayerPlaced = "BarricadedWorld:isPlayerPlaced",
  ParsedDay = "BarricadedWorld:parsedDay",
  SquareProcessed = "BarricadedWorld:squareProcessed",
}

---@enum BarricadeType
local BarricadeType = {
  MetalSheet = "Base.SheetMetal",
  MetalBar = "Base.MetalBar",
}

--- @type {
--- WindowBreak: integer, WindowBarricade: integer, WindowBarricadeMetal: integer, WindowBarricadeMetalBar: integer,
--- ExteriorDoorBreak: integer, ExteriorDoorBarricade: integer, InteriorDoorBreak: integer,
--- UseErosion: boolean, GarageBreak: integer, zMin: integer, zMax: integer, OnlyOnce: boolean, IgnoreClaimed: boolean }
--- }
local options = nil

-----
--- Logic
-----

--- Attempt to barricade door with a metal sheet or metal bars.
---@param type BarricadeType
---@param object BarricadeAble
local function placeMetalBarricade(object, type)
  local barricade = IsoBarricade.AddBarricadeToObject(object, false)

  if barricade then
    local metal = instanceItem(type)
    if not metal then
      error("Could not find metal to barricade with: " .. type)
      return
    end

    if type == BarricadeType.MetalSheet then
      ---@diagnostic disable-next-line: param-type-mismatch
      barricade:addMetal(nil, metal)
    elseif type == BarricadeType.MetalBar then
      ---@diagnostic disable-next-line: param-type-mismatch
      barricade:addMetalBar(nil, metal)
    end

    barricade:transmitCompleteItemToClients()
    barricade:sendObjectChange(IsoObjectChange.STATE)
  end
end

---@param grid_square IsoGridSquare
local function loadGridsquare(grid_square)
  if isClient() == true or options == nil then
    return
  end

  local square_mod_data = grid_square:getModData()

  -- HACK: Try improve performance by never running on previously visited areas.
  if options.OnlyOnce and square_mod_data[ModData.SquareProcessed] then
    return
  elseif options.OnlyOnce then
    square_mod_data[ModData.SquareProcessed] = true
    grid_square:transmitModdata()
  end

  if options.IgnoreClaimed and SafeHouse.getSafeHouse(grid_square) then
    return
  end

  local square_z = grid_square:getZ()
  if (square_z < options.zMin) or (square_z > options.zMax) then
    return
  end

  local square_objects = grid_square:getObjects()
  local square_objects_size = square_objects:size()

  for i = 0, square_objects_size - 1 do
    local tileIsoObject = square_objects:get(i)

    if not tileIsoObject then
      break
    end

    local modData = tileIsoObject:getModData()

    -- Cancel barricaded world if player built
    -- or 100% erosion parsed objects
    -- or if the window/door has been processed in the past 30 days
    if
      modData[ModData.IsPlayerPlaced]
      or modData[ModData.IsParsed]
      or (modData[ModData.ParsedDay] and modData[ModData.ParsedDay] + 30 >= state.CurrentWorldAgeDays)
    then
      break
    end

    if instanceof(tileIsoObject, "IsoWindow") then
      ---@cast tileIsoObject IsoWindow We know the IsObject is a window here

      if not instanceof(tileIsoObject, "BarricadeAble") then
        break
      end

      -- The more advanced the erosion, the more chances the following code has to happen.
      -- 25% of current erosion advancement means 25% chance for a windows to go through the Barricaded World code.
      if ZombRand(100) < state.CurrentErosionPercentage or not options.UseErosion then
        if ZombRand(100) < options.WindowBreak then
          tileIsoObject:setSmashed(true)
          grid_square:addBrokenGlass()
          tileIsoObject:sendObjectChange(IsoObjectChange.STATE)
        end

        -- Only barricade windows on the ground floor
        if square_z ~= 0 then
          break
        end

        if ZombRand(100) < options.WindowBarricadeMetal then
          placeMetalBarricade(tileIsoObject, BarricadeType.MetalSheet)
        elseif ZombRand(100) < options.WindowBarricadeMetalBar then
          placeMetalBarricade(tileIsoObject, BarricadeType.MetalBar)
        elseif ZombRand(100) < options.WindowBarricade then
          tileIsoObject:addRandomBarricades()
        end
      end

      if state.CurrentErosionPercentage >= 100 then
        modData[ModData.IsParsed] = true
      end

      modData[ModData.ParsedDay] = state.CurrentWorldAgeDays
      tileIsoObject:transmitModData()

      break
    elseif instanceof(tileIsoObject, "IsoDoor") then
      ---@cast tileIsoObject IsoDoor We know the IsObject is a door here

      local tileModData = tileIsoObject:getModData()

      -- The more advanced the erosion, the more chances the following code has to happen.
      -- 25% of current erosion advancement means 25% chance for a windows to go through the Barricaded World code.
      if (ZombRand(100) < state.CurrentErosionPercentage) or not options.UseErosion then
        local random = ZombRand(100)

        if tileIsoObject:getProperties():has(IsoPropertyType.GARAGE_DOOR) then
          if random < options.GarageBreak then
            tileIsoObject:destroy()
            break
          end
        elseif tileIsoObject:isOutside() then
          if random < options.ExteriorDoorBarricade then
            tileIsoObject:addRandomBarricades()
          elseif ZombRand(100) < options.ExteriorDoorBreak then
            tileIsoObject:destroy()
            break
          end
        else
          if random < options.InteriorDoorBreak then
            tileIsoObject:destroy()
            break
          end
        end
      end

      if state.CurrentErosionPercentage >= 100 then
        tileModData[ModData.IsParsed] = true
      end

      tileModData[ModData.ParsedDay] = state.CurrentWorldAgeDays
      tileIsoObject:transmitModData()

      break
    end
  end
end

local function preCalculateErosion()
  state.CurrentWorldAgeDays = getGameTime():getWorldAgeHours() / 24
  local sandboxOptions = getSandboxOptions()

  local timeSpent = state.CurrentWorldAgeDays + state.TimeSinceApoValues[sandboxOptions:getTimeSinceApo()]

  state.CurrentErosionPercentage = (timeSpent / state.ErosionSpeedValues[sandboxOptions:getErosionSpeed()]) * 100
end

---@param isoObject IsoObject
local function checkPlayerPlaced(isoObject)
  if instanceof(isoObject, "IsoWindow") or instanceof(isoObject, "IsoDoor") then
    local modData = isoObject:getModData()
    modData[ModData.IsPlayerPlaced] = true
    isoObject:transmitModData()
  end
end

---@param isoObject IsoObject
local function cleanupModData(isoObject)
  local modData = isoObject:getModData()
  modData[ModData.IsParsed] = nil
  modData[ModData.IsPlayerPlaced] = nil
  modData[ModData.ParsedDay] = nil
  isoObject:transmitModData()
end

-----
--- Finalize
-----

Events.OnGameTimeLoaded.Add(function()
  preCalculateErosion()
end)

Events.OnGameStart.Add(function()
  options = SandboxVars.BarricadedWorld
  preCalculateErosion()
end)
Events.OnObjectAdded.Add(function(isoObject)
  checkPlayerPlaced(isoObject)
end)

Events.OnObjectAboutToBeRemoved.Add(function(isoObject)
  print("processing removal of: " .. isoObject:getName())
  cleanupModData(isoObject)
end)

Events.EveryDays.Add(function()
  preCalculateErosion()
end)

Events.EveryTenMinutes.Add(function()
  options = SandboxVars.BarricadedWorld
end)

Events.LoadGridsquare.Add(loadGridsquare)
