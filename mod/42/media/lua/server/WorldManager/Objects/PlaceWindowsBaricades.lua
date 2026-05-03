--
-- Properties
--

BarricadedWorld = {
  ErosionSpeedValues = { 20, 50, 100, 200, 500 },
  TimeSinceApoValues = { 0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330, 360 },
  CurrentErosionPercentage = 0,
  CurrentWorldAgeDays = 0,
}
PlaceWindowsBaricades = {}

---@enum BarricadeType
local BarricadeType = {
  MetalSheet = "Base.SheetMetal",
  MetalBar = "Base.MetalBar",
}

---@enum OModData
local IModData = {
  IsParsed = "BarricadedWorld:isDefinitiveParsed",
  IsPlayerPlaced = "BarricadedWorld:isPlayerPlaced",
  ParsedDay = "BarricadedWorld:parsedDay",
}

--
-- Properties
--

---@param grid_square IsoGridSquare
function PlaceWindowsBaricades.loadGridsquare(grid_square)
  if isClient() == true then
    return
  end

  --- @type {
  --- WindowBreak: integer, WindowBarricade: integer, WindowBarricadeMetal: integer, WindowBarricadeMetalBar: integer,
  --- ExteriorDoorBreak: integer, ExteriorDoorBarricade: integer, InteriorDoorBreak: integer,
  --- UseErosion: boolean, GarageBreak: integer, zMin: integer, zMax: integer }
  --- }
  local options = SandboxVars.BarricadedWorld

  local square_z = grid_square:getZ()

  if (square_z < options.zMin) or (square_z > options.zMax) then
    return
  end

  local square_objects = grid_square:getObjects()
  local square_objects_size = square_objects:size()

  if square_objects_size == 0 then
    return
  end

  for i = 0, square_objects_size - 1 do
    local tileIsoObject = square_objects:get(i)

    if not tileIsoObject then
      break
    end

    local modData = tileIsoObject:getModData()

    -- Don't run on player built objects
    if modData[IModData.IsPlayerPlaced] then
      break
    end

    -- If the window or door has been loaded in the past 30 days, cancel barricaded world.
    if
        modData[IModData.IsParsed]
        or (modData[IModData.ParsedDay] and modData[IModData.ParsedDay] + 30 >= BarricadedWorld.CurrentWorldAgeDays)
    then
      break
    end

    if instanceof(tileIsoObject, "IsoWindow") then
      ---@cast tileIsoObject IsoWindow We know the IsObject is a window here

      local coords = { x = grid_square:getX(), y = grid_square:getY(), z = grid_square:getZ() }

      if not instanceof(tileIsoObject, "BarricadeAble") then
        break
      end

      -- The more advanced the erosion, the more chances the following code has to happen.
      -- 25% of current erosion advancement means 25% chance for a windows to go through the Barricaded World code.
      if ZombRand(100) < BarricadedWorld.CurrentErosionPercentage or not options.UseErosion then
        if ZombRand(100) < options.WindowBreak then
          print("SMASHING window")
          tileIsoObject:smashWindow(false, false)
        end

        if coords.z ~= 0 then
          break
        end

        local randomBaricadeLocation = ZombRand(4)
        local barricadeLocation = randomBaricadeLocation <= 2

        local random = ZombRand(100)

        if random < options.WindowBarricadeMetal then
          print("Barricading window with METAL")
          local metalType = BarricadeType.MetalSheet

          if ZombRand(100) < options.WindowBarricadeMetalBar then
            metalType = BarricadeType.MetalBar
          end

          local args = {
            index = i,
            type = metalType,
            condition = 10,
          }
          PlaceWindowsBaricades.placeMetalBarricade(args, tileIsoObject, barricadeLocation)
        elseif random < options.WindowBarricade then
          print("Barricading window with WOOD")
          tileIsoObject:addRandomBarricades()
        end
      end

      if BarricadedWorld.CurrentErosionPercentage > 100 then
        modData[IModData.IsParsed] = true
      end

      modData[IModData.ParsedDay] = BarricadedWorld.CurrentWorldAgeDays
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
            print("Destroying GARAGE")
            tileIsoObject:destroy()
            break
          end
        elseif tileIsoObject:isOutside() then
          if random < options.ExteriorDoorBreak then
            print("Destroying EXTERIOR DOOR")
            tileIsoObject:destroy()
            break
          elseif random < options.ExteriorDoorBarricade then
            print("Barricading EXTERIOR DOOR with WOOD")
            tileIsoObject:addRandomBarricades()
          end
        else
          if random < options.InteriorDoorBreak then
            print("Destroying INTERIOR DOOR")
            tileIsoObject:destroy()
            break
          end
        end
      end

      if BarricadedWorld.CurrentErosionPercentage > 100 then
        tileModData[IModData.IsParsed] = true
      end

      tileModData[IModData.ParsedDay] = BarricadedWorld.CurrentWorldAgeDays
      tileIsoObject:transmitModData()

      break
    end
  end
end

function PlaceWindowsBaricades.isGettable(sq, i)
  return sq:getObjects():get(i)
end

---comment
---@param args {index: integer, type: string, condition: integer}
---@param object BarricadeAble
---@param barricadeLocation boolean
function PlaceWindowsBaricades.placeMetalBarricade(args, object, barricadeLocation)
  local barricade = IsoBarricade.AddBarricadeToObject(object, false)

  if barricade then
    local metal = instanceItem(args.type)

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

function PlaceWindowsBaricades.onObjectAdded(isoObject)
  if instanceof(isoObject, "IsoWindow") or instanceof(isoObject, "IsoDoor") then
    local modData = isoObject:getModData()
    modData[IModData.IsPlayerPlaced] = true
    isoObject:transmitModData()
  end
end

function PlaceWindowsBaricades.preCalculateErosion()
  BarricadedWorld.CurrentWorldAgeDays = getGameTime():getWorldAgeHours() / 24
  local sandboxOptions = getSandboxOptions()

  local timeSpent = BarricadedWorld.CurrentWorldAgeDays
      + BarricadedWorld.TimeSinceApoValues[sandboxOptions:getTimeSinceApo()]

  BarricadedWorld.CurrentErosionPercentage = (
    timeSpent / BarricadedWorld.ErosionSpeedValues[sandboxOptions:getErosionSpeed()]
  ) * 100
end

--
-- Finalize
--

Events.OnGameTimeLoaded.Add(PlaceWindowsBaricades.preCalculateErosion)
Events.EveryDays.Add(PlaceWindowsBaricades.preCalculateErosion)
Events.OnGameStart.Add(PlaceWindowsBaricades.preCalculateErosion)

Events.OnObjectAdded.Add(PlaceWindowsBaricades.onObjectAdded)
Events.LoadGridsquare.Add(PlaceWindowsBaricades.loadGridsquare)
