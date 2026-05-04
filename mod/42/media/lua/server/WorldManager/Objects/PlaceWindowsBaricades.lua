--
-- Properties
--

BarricadedWorld = {
  ErosionSpeedValues = { 20, 50, 100, 200, 500 },
  TimeSinceApoValues = { 0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330, 360 },
  CurrentErosionPercentage = 0,
  CurrentWorldAgeDays = 0,
}

---@enum BarricadeType
local BarricadeType = {
  MetalSheet = "Base.SheetMetal",
  MetalBar = "Base.MetalBar",
}

---@enum BarricadedWorldModData
BarricadedWorldModData = {
  IsParsed = "BarricadedWorld:isDefinitiveParsed",
  IsPlayerPlaced = "BarricadedWorld:isPlayerPlaced",
  ParsedDay = "BarricadedWorld:parsedDay",
  SquareProcessed = "BarricadedWorld:squareProcessed",
}

local function logger(message, severity)
  print("[BarricadedWorld] " .. (severity or "INFO: ") .. message)
end

--- @type {
--- WindowBreak: integer, WindowBarricade: integer, WindowBarricadeMetal: integer, WindowBarricadeMetalBar: integer,
--- ExteriorDoorBreak: integer, ExteriorDoorBarricade: integer, InteriorDoorBreak: integer,
--- UseErosion: boolean, GarageBreak: integer, zMin: integer, zMax: integer, OnlyOnce: boolean }
--- }
local options = nil

--
-- Functions
--

---@param grid_square IsoGridSquare
function BarricadedWorld.loadGridsquare(grid_square)
  if isClient() == true then
    return
  end

  local square_mod_data = grid_square:getModData()

  -- HACK: Try improve performance by never running on previously visited areas.
  if options.OnlyOnce and square_mod_data[BarricadedWorldModData.SquareProcessed] then
    return
  elseif options.OnlyOnce then
    square_mod_data[BarricadedWorldModData.SquareProcessed] = true
    grid_square:transmitModdata()
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

    -- Don't run on player built objects
    if modData[BarricadedWorldModData.IsPlayerPlaced] then
      break
    end

    -- If the window or door has been loaded in the past 30 days, cancel barricaded world.
    if
      modData[BarricadedWorldModData.IsParsed]
      or (
        modData[BarricadedWorldModData.ParsedDay]
        and modData[BarricadedWorldModData.ParsedDay] + 30 >= BarricadedWorld.CurrentWorldAgeDays
      )
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
      if ZombRand(100) < BarricadedWorld.CurrentErosionPercentage or not options.UseErosion then
        if ZombRand(100) < options.WindowBreak then
          tileIsoObject:setSmashed(true)
          grid_square:addBrokenGlass()
          tileIsoObject:sendObjectChange(IsoObjectChange.STATE)
        end

        -- Only barricade windows on the ground floor
        if grid_square:getZ() ~= 0 then
          break
        end

        if ZombRand(100) < options.WindowBarricadeMetal then
          local metalType = BarricadeType.MetalSheet

          if ZombRand(100) < options.WindowBarricadeMetalBar then
            metalType = BarricadeType.MetalBar
          end

          BarricadedWorld.placeMetalBarricade({ index = i, type = metalType }, tileIsoObject)
        elseif ZombRand(100) < options.WindowBarricade then
          tileIsoObject:addRandomBarricades()
        end
      end

      if BarricadedWorld.CurrentErosionPercentage > 100 then
        modData[BarricadedWorldModData.IsParsed] = true
      end

      modData[BarricadedWorldModData.ParsedDay] = BarricadedWorld.CurrentWorldAgeDays
      tileIsoObject:transmitModData()

      break
    elseif instanceof(tileIsoObject, "IsoDoor") then
      ---@cast tileIsoObject IsoDoor We know the IsObject is a door here

      local tileModData = tileIsoObject:getModData()

      -- The more advanced the erosion, the more chances the following code has to happen.
      -- 25% of current erosion advancement means 25% chance for a windows to go through the Barricaded World code.
      if (ZombRand(100) < BarricadedWorld.CurrentErosionPercentage) or not options.UseErosion then
        local random = ZombRand(100)

        if tileIsoObject:getProperties():has(IsoPropertyType.GARAGE_DOOR) then
          if random < options.GarageBreak then
            tileIsoObject:destroy()
          end
        elseif tileIsoObject:isOutside() then
          if random < options.ExteriorDoorBarricade then
            tileIsoObject:addRandomBarricades()
          elseif ZombRand(100) < options.ExteriorDoorBreak then
            tileIsoObject:destroy()
          end
        else
          if random < options.InteriorDoorBreak then
            tileIsoObject:destroy()
          end
        end
      end

      if BarricadedWorld.CurrentErosionPercentage > 100 then
        tileModData[BarricadedWorldModData.IsParsed] = true
      end

      tileModData[BarricadedWorldModData.ParsedDay] = BarricadedWorld.CurrentWorldAgeDays
      tileIsoObject:transmitModData()

      break
    end
  end
end

---@param args {index: integer, type: string}
---@param object BarricadeAble
function BarricadedWorld.placeMetalBarricade(args, object)
  local barricade = IsoBarricade.AddBarricadeToObject(object, false)

  if barricade then
    local metal = instanceItem(args.type)
    if not metal then
      logger("Could not find metal to barricade with", "ERROR")
      return
    end

    if args.type == BarricadeType.MetalSheet then
      ---@diagnostic disable-next-line: param-type-mismatch
      barricade:addMetal(nil, metal)
    elseif args.type == BarricadeType.MetalBar then
      ---@diagnostic disable-next-line: param-type-mismatch
      barricade:addMetalBar(nil, metal)
    end

    barricade:transmitCompleteItemToClients()
    barricade:sendObjectChange(IsoObjectChange.STATE)
  end
end

function BarricadedWorld.onObjectAdded(isoObject)
  if instanceof(isoObject, "IsoWindow") or instanceof(isoObject, "IsoDoor") then
    local modData = isoObject:getModData()
    modData[BarricadedWorldModData.IsPlayerPlaced] = true
    isoObject:transmitModData()
  end
end

function BarricadedWorld.preCalculateErosion()
  BarricadedWorld.CurrentWorldAgeDays = getGameTime():getWorldAgeHours() / 24
  local sandboxOptions = getSandboxOptions()

  local timeSpent = BarricadedWorld.CurrentWorldAgeDays
    + BarricadedWorld.TimeSinceApoValues[sandboxOptions:getTimeSinceApo()]

  BarricadedWorld.CurrentErosionPercentage = (
    timeSpent / BarricadedWorld.ErosionSpeedValues[sandboxOptions:getErosionSpeed()]
  ) * 100
end

function BarricadedWorld.OnGameStart()
  options = SandboxVars.BarricadedWorld
  BarricadedWorld.preCalculateErosion()
end

function BarricadedWorld.EveryOneMinute()
  options = SandboxVars.BarricadedWorld
end

--
-- Finalize
--

Events.OnGameTimeLoaded.Add(BarricadedWorld.preCalculateErosion)
Events.OnGameStart.Add(BarricadedWorld.OnGameStart)
Events.OnObjectAdded.Add(BarricadedWorld.onObjectAdded)

Events.EveryDays.Add(BarricadedWorld.preCalculateErosion)
Events.EveryOneMinute.Add(BarricadedWorld.EveryOneMinute)

Events.LoadGridsquare.Add(BarricadedWorld.loadGridsquare)
