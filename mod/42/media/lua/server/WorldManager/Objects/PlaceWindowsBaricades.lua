--
-- Properties
--

PlaceWindowsBaricades = {};
ErosionSpeedValues = { 20, 50, 100, 200, 500 }
TimeSinceApoValues = { 0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330, 360 }
CurrentErosionPercentage = 0
CurrentWorldAgeDays = 0

local function optionChance(option)
  return 100 - option
end

-- Methods

function PlaceWindowsBaricades.loadGridsquare(sq)
  if isClient() == false then
    local options = SandboxVars.BarricadedWorld

    for i = 0, sq:getObjects():size() - 1 do
      local tileIsoObject = sq:getObjects():get(i);

      if tileIsoObject then
        -- Searching for windows
        if instanceof(tileIsoObject, "IsoWindow") then
          local modData = tileIsoObject:getModData()

          -- If the window have not been loaded for the past 30 days, retry Barricaded World code
          if (not modData["BarricadedWorld:isDefinitiveParsed"])
              and (not modData["BarricadedWorld:isPlayerPlaced"])
              and (not modData["BarricadedWorld:parsedDate"] or modData["BarricadedWorld:parsedDate"] + 30 < CurrentWorldAgeDays) then
            local coords = { x = sq:getX(), y = sq:getY(), z = sq:getZ() }
            object = PlaceWindowsBaricades.getBarricadeAble(coords.x, coords.y, coords.z, tileIsoObject:getObjectIndex());

            -- The more advanced the erosion, the more chances the following code has to happen.
            -- 25% of current erosion advancement means 25% chance for a windows to go through the Barricaded World code.
            if object and (ZombRand(0, 100) < CurrentErosionPercentage or (not options.UseErosion)) then
              if ZombRand(0, 100) >= optionChance(options.Window) then
                object:smashWindow()
              end

              if coords.z == 0 then
                local args = {}
                local randomBaricadeLocation = ZombRand(0, 4)
                local barricadeLocation = true

                if (randomBaricadeLocation > 2) then
                  barricadeLocation = false
                end

                local random = ZombRand(0, 100)

                if (random >= optionChance(options.WindowBarricadeMetal)) then
                  -- print("This window has metal sheet")
                  local args = {
                    x = coords.x,
                    y = coords.y,
                    z = coords.z,
                    index = i,
                    isMetal = true,
                    isMetalBar = false,
                    itemID =
                    'Base.MetalBar',
                    condition = 10,
                    amount = 1
                  }
                  PlaceWindowsBaricades.placeBarricade(args, object, barricadeLocation);
                elseif (random >= optionChance(options.WindowBarricade)) then
                  -- print("This window random planks")
                  tileIsoObject:addRandomBarricades()
                end
              end
            end

            if CurrentErosionPercentage > 100 then
              modData["BarricadedWorld:isDefinitiveParsed"] = true
              tileIsoObject:transmitModData()
            end
          end

          modData["BarricadedWorld:parsedDate"] = CurrentWorldAgeDays
          tileIsoObject:transmitModData()

          break -- Can't be both a window and a door, we found what we searched, stop the loop to gain performances
        elseif instanceof(tileIsoObject, "IsoDoor") then
          local tileModData = tileIsoObject:getModData()

          -- If the door have not been loaded for the past 30 days, retry Barricaded World code
          if (not tileModData["BarricadedWorld:isDefinitiveParsed"])
              and (not tileModData["BarricadedWorld:isPlayerPlaced"])
              and (
                not tileModData["BarricadedWorld:parsedDate"]
                or tileModData["BarricadedWorld:parsedDate"] + 30 < CurrentWorldAgeDays
              ) then
            -- The more advanced the erosion, the more chances the following code has to happen.
            -- 25% of current erosion advancement means 25% chance for a windows to go through the Barricaded World code.
            if (ZombRand(0, 100) < CurrentErosionPercentage) or (not options.UseErosion) then
              local random = ZombRand(0, 100)

              if tileIsoObject:getSprite():getProperties():Is("GarageDoor") then
                if (random >= optionChance(options.Garage)) then
                  tileIsoObject:destroy()
                  break
                end
              else
                if tileIsoObject:isExteriorDoor(nil) then
                  if (random >= optionChance(options.ExteriorDoor)) then
                    tileIsoObject:destroy()
                    break
                  elseif (ZombRand(0, 100) >= optionChance(options.ExteriorDoorBarricade)) then
                    tileIsoObject:addRandomBarricades()
                  end
                else
                  if (random >= optionChance(options.InteriorDoor)) then
                    tileIsoObject:destroy()
                    break
                  end
                end
              end
            end

            if CurrentErosionPercentage > 100 then
              tileModData["BarricadedWorld:isDefinitiveParsed"] = true
              tileIsoObject:transmitModData()
            end
          end

          tileModData["BarricadedWorld:parsedDate"] = CurrentWorldAgeDays
          tileIsoObject:transmitModData()
          break -- Can't be both a window and a door, we found what we searched, stop the loop to gain performances
        end
      end
    end
  end
end

function PlaceWindowsBaricades.isGettable(sq, i)
  return sq:getObjects():get(i)
end

function PlaceWindowsBaricades.getBarricadeAble(x, y, z, index)
  local sq = getCell():getGridSquare(x, y, z)
  if sq and index >= 0 and index < sq:getObjects():size() then
    o = sq:getObjects():get(index)
    if instanceof(o, 'BarricadeAble') then
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
        barricade:sendObjectChange('state')
      end
    elseif args.isMetalBar then
      local metal = instanceItem("Base.MetalBar")
      metal:setCondition(args.condition)
      barricade:addMetalBar(nil, metal)
      barricade:transmitCompleteItemToClients()
      barricade:sendObjectChange('state')
    else
      local plank = instanceItem("Base.Plank")

      for i = 0, args.amount - 1 do
        barricade:addPlank(nil, plank)

        if isServer() then
          if barricade:getNumPlanks() == 1 then
            barricade:transmitCompleteItemToClients()
          else
            barricade:sendObjectChange('state')
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
  CurrentWorldAgeDays = getGameTime():getWorldAgeHours() / 24
  local sandboxOptions = getSandboxOptions()
  local timeSpent = CurrentWorldAgeDays + TimeSinceApoValues[sandboxOptions:getTimeSinceApo()]
  CurrentErosionPercentage = (timeSpent / ErosionSpeedValues[sandboxOptions:getErosionSpeed()]) * 100
end

Events.OnGameTimeLoaded.Add(PlaceWindowsBaricades.preCalculateErosion)
Events.EveryDays.Add(PlaceWindowsBaricades.preCalculateErosion)
Events.OnGameStart.Add(PlaceWindowsBaricades.preCalculateErosion)

Events.OnObjectAdded.Add(PlaceWindowsBaricades.onObjectAdded)
Events.LoadGridsquare.Add(PlaceWindowsBaricades.loadGridsquare);
