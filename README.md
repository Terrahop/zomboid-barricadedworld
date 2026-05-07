# Barricaded World - Extended Erosion (Continued)

> A continuation of [Onkeens](https://steamcommunity.com/sharedfiles/filedetails/?id=2696986935) mod.

See source on [  Github](github.com/Terrahop/zomboid-barricadedworld)

## Description

Adds progressive deterioration of the world by barricading and destroying
windows and doors to simulate a world in the post-apocalypse. Most houses and
buildings will now actually appear like abandoned safe houses. It's designed
around playing on advanced erosion (6/12 months later time period).

## Features

- Windows have a chance to be destroyed and or barricaded
- Doors have a chance to be destroyed and or barricaded
- Garages have a chance to be destroyed
- Supports Multiplayer
- Safe houses in multiplayer won't be effected
- Context menu options to disable this effect on doors/windows, houses and buildings
- Erosion integration (see below)
- Highly Configurable (see sandbox options)

> Unfortunately due to the way this mod works, it can effect performance
> significantly when exploring the world. You'll need decent hardware to run it,
> there are some sandbox options available to improve performance but your
> mileage may vary.

## Erosion Integration

When erosion integration is enabled (default). The world will appear more damage
the longer time goes on if you start with standard time and erosion settings.

Chances of broken and barricaded garages/doors/windows depends on erosion advancement:

- In options, adjust erosion with "Erosion Speed" and keep "Erosion Days" at 0
- The more advanced the erosion, the more chances the following code has to happen
- 25% of current erosion advancement means 25% chance for a window to go through
  the Barricaded World code
- If erosion below 100%, 30 days after a place is loaded, if the place is loaded
  again, the code will be run again
- When code is loaded for a place at 100% erosion, it will not run anymore even
  past several days

Examples of Sandbox configuration for erosion:

- A world with normal "Erosion Speed" (100 days) and with "Month since Apocalypse"
  set to 2 (60 days) will start at 60% of Erosion.
- A world with very fast "Erosion Speed" (20 days) and with "Month since Apocalypse"
  set to 1 (30 days) will start at 100% of Erosion.

## Updates & Support

For now I consider this mod feature complete and in maintenance mode. There are
no plans for new features, only bug fixes **IF** I found the time but no promises.

## Recommendations

Recommended [sandbox options](https://imgur.com/SI3AHBl)

### Mods

> NOTE: if you plan to use the new [10 Years later Remake](https://steamcommunity.com/sharedfiles/filedetails/?id=3719766602) you don't need this mod, it already does window smashing and barricading.

- [Trash and Corpses](https://steamcommunity.com/sharedfiles/filedetails/?id=3662273535)
- [Project Seasons](https://steamcommunity.com/sharedfiles/filedetails/?id=3412105017)
- [Beauty of zomboid](https://steamcommunity.com/sharedfiles/filedetails/?id=3333779609&searchtext=BEAUTY)

## Credits

- Onkeen for the [original mod](https://steamcommunity.com/sharedfiles/filedetails/?id=2696986935).
- Amenophis for their [fix](https://steamcommunity.com/workshop/filedetails/discussion/2696986935/563626489222803655/#c595152144826431052) that started this continuation
