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

local function optionChance(option)
  return 100 - option
end

-- Methods

function PlaceWindowsBaricades.loadGridsquare(sq)
  if isClient() == true then
    return
  end

  local options = SandboxVars.BarricadedWorld

  if options.OnlyGroundLevel and sq:getZ() ~= 0 then
    return
  end

  local square_objects = sq:getObjects()
  local square_objects_size = square_objects:size()

  if square_objects_size == 0 then
    return
  end

  -- for i = 0, sq:getObjects():size() - 1 do
  --   local tileIsoObject = sq:getObjects():get(i)

  for i = 0, square_objects_size - 1 do
    local tileIsoObject = square_objects:get(i)

    if not tileIsoObject then
      return
    end

    -- Searching for windows
    if instanceof(tileIsoObject, "IsoWindow") then
      local modData = tileIsoObject:getModData()

      -- If the window have not been loaded for the past 30 days, retry Barricaded World code
      if
        not modData["BarricadedWorld:isDefinitiveParsed"]
        and not modData["BarricadedWorld:isPlayerPlaced"]
        and (
          not modData["BarricadedWorld:parsedDate"]
          or modData["BarricadedWorld:parsedDate"] + 30 < BarricadedWorld.CurrentWorldAgeDays
        )
      then
        local coords = { x = sq:getX(), y = sq:getY(), z = sq:getZ() }
        ---@type IsoWindow
        local iso_window = PlaceWindowsBaricades.getBarricadeAble(coords.x, coords.y, coords.z, tileIsoObject:getObjectIndex())

        -- The more advanced the erosion, the more chances the following code has to happen.
        -- 25% of current erosion advancement means 25% chance for a windows to go through the Barricaded World code.
        if iso_window and (ZombRand(0, 100) < BarricadedWorld.CurrentErosionPercentage or not options.UseErosion) then
          if ZombRand(0, 100) >= optionChance(options.Window) then
            iso_window:smashWindow()
          end

          if coords.z == 0 then
            local randomBaricadeLocation = ZombRand(0, 4)
            local barricadeLocation = true

            if randomBaricadeLocation > 2 then
              barricadeLocation = false
            end

            local random = ZombRand(0, 100)

            if random >= optionChance(options.WindowBarricadeMetal) then
              local args = {
                x = coords.x,
                y = coords.y,
                z = coords.z,
                index = i,
                isMetal = true,
                isMetalBar = false,
                itemID = "Base.SheetMetal",
                condition = 10,
                amount = 1,
              }
              PlaceWindowsBaricades.placeBarricade(args, iso_window, barricadeLocation)
            elseif random >= optionChance(options.WindowBarricade) then
              tileIsoObject:addRandomBarricades()
            end
          end
        end

        if BarricadedWorld.CurrentErosionPercentage > 100 then
          modData["BarricadedWorld:isDefinitiveParsed"] = true
          tileIsoObject:transmitModData()
        end
      end

      modData["BarricadedWorld:parsedDate"] = BarricadedWorld.CurrentWorldAgeDays
      tileIsoObject:transmitModData()

      break
    elseif instanceof(tileIsoObject, "IsoDoor") then
      local tileModData = tileIsoObject:getModData()

      -- If the door have not been loaded for the past 30 days, retry Barricaded World code
      if
        not tileModData["BarricadedWorld:isDefinitiveParsed"]
        and not tileModData["BarricadedWorld:isPlayerPlaced"]
        and (
          not tileModData["BarricadedWorld:parsedDate"]
          or tileModData["BarricadedWorld:parsedDate"] + 30 < BarricadedWorld.CurrentWorldAgeDays
        )
      then
        -- The more advanced the erosion, the more chances the following code has to happen.
        -- 25% of current erosion advancement means 25% chance for a windows to go through the Barricaded World code.
        if (ZombRand(0, 100) < BarricadedWorld.CurrentErosionPercentage) or not options.UseErosion then
          local random = ZombRand(0, 100)

          -- if tileIsoObject:getSprite():getProperties():Is("GarageDoor") then
          --   if (random >= optionChance(options.Garage)) then
          --     tileIsoObject:destroy()
          --     break
          --   end
          -- else
          if tileIsoObject:isExteriorDoor(nil) then
            if random >= optionChance(options.ExteriorDoor) then
              tileIsoObject:destroy()
              break
            elseif ZombRand(0, 100) >= optionChance(options.ExteriorDoorBarricade) then
              tileIsoObject:addRandomBarricades()
            end
          else
            if random >= optionChance(options.InteriorDoor) then
              tileIsoObject:destroy()
              break
            end
          end
        end

        if BarricadedWorld.CurrentErosionPercentage > 100 then
          tileModData["BarricadedWorld:isDefinitiveParsed"] = true
          tileIsoObject:transmitModData()
        end
      end

      tileModData["BarricadedWorld:parsedDate"] = BarricadedWorld.CurrentWorldAgeDays
      tileIsoObject:transmitModData()

      break
    end
  end
end

function PlaceWindowsBaricades.isGettable(sq, i)
  return sq:getObjects():get(i)
end

function PlaceWindowsBaricades.getBarricadeAble(x, y, z, index)
  local sq = getCell():getGridSquare(x, y, z)
  if sq and index >= 0 and index < sq:getObjects():size() then
    local o = sq:getObjects():get(index)
    if instanceof(o, "BarricadeAble") then
      return o
    end
  end
  return nil
end

function PlaceWindowsBaricades.placeBarricade(args, object, barricadeLocation)
  local barricade = IsoBarricade.AddBarricadeToObject(object, barricadeLocation)

  if barricade then
    if args.isMetal then
      local metal = instanceItem("Base.SheetMetal")
      metal:setCondition(args.condition)
      barricade:addMetal(nil, metal)
      barricade:transmitCompleteItemToClients()
      if isServer() then
        barricade:sendObjectChange(IsoObjectChange.STATE)
      end
    elseif args.isMetalBar then
      local metal = instanceItem("Base.MetalBar")
      metal:setCondition(args.condition)
      barricade:addMetalBar(nil, metal)
      barricade:transmitCompleteItemToClients()

      if isServer() then
        barricade:sendObjectChange(IsoObjectChange.STATE)
      end
    else
      local plank = instanceItem("Base.Plank")

      for _ = 0, args.amount - 1 do
        barricade:addPlank(nil, plank)

        if isServer() then
          if barricade:getNumPlanks() == 1 then
            barricade:transmitCompleteItemToClients()
          else
            barricade:sendObjectChange(IsoObjectChange.STATE)
          end
        end
      end
    end
  end
  -- else print("No barricade location found");
end

function PlaceWindowsBaricades.onObjectAdded(isoObject)
  if instanceof(isoObject, "IsoWindow") or instanceof(isoObject, "IsoDoor") then
    local modData = isoObject:getModData()
    modData["BarricadedWorld:isPlayerPlaced"] = true
    isoObject:transmitModData()
  end
end

function PlaceWindowsBaricades.preCalculateErosion()
  BarricadedWorld.CurrentWorldAgeDays = getGameTime():getWorldAgeHours() / 24
  local sandboxOptions = getSandboxOptions()
  local timeSpent = BarricadedWorld.CurrentWorldAgeDays + BarricadedWorld.TimeSinceApoValues[sandboxOptions:getTimeSinceApo()]
  BarricadedWorld.CurrentErosionPercentage = (timeSpent / BarricadedWorld.ErosionSpeedValues[sandboxOptions:getErosionSpeed()]) * 100
end

Events.OnGameTimeLoaded.Add(PlaceWindowsBaricades.preCalculateErosion)
Events.EveryDays.Add(PlaceWindowsBaricades.preCalculateErosion)
Events.OnGameStart.Add(PlaceWindowsBaricades.preCalculateErosion)

Events.OnObjectAdded.Add(PlaceWindowsBaricades.onObjectAdded)
Events.LoadGridsquare.Add(PlaceWindowsBaricades.loadGridsquare)
