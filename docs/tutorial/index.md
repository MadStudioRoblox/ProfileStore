## Getting ProfileStore

ProfileStore is supposed to be a ModuleScript which you should place inside your Roblox game's *ServerScriptService* or wherever else is preferred.
Since DataStores are server-side only, ProfileStore is also a module that should only run on the server-side.

### Option #1: Get ProfileService from the Roblox library

   - Get the library model [(click here)](https://create.roblox.com/store/asset/109379033046155/ProfileStore)
   - Make sure the "ProfileStore" ModuleScript is under `ServerScriptService`:

![Open toolbox menu](../images/Step1.jpg)

![Find the ProfileService model](../images/Step2.jpg)

![Move ProfileService to ServerScriptService](../images/Step3.jpg)

### Option #2: Github
* [ProfileStore repository](https://github.com/MadStudioRoblox/ProfileStore)

## Basic Usage

To start using ProfileStore, you need a piece of code that starts a profile session when a player joins. When a profile session is started,
changes to the `Profile.Data` table will be auto-saved periodically and saved for the last time after `Profile:EndSession()` is called.
You can find explanations for every method and property of `ProfileStore` and `Profile` objects in the [ProfileStore API](#/ProfileStore/api).

This code is a standard implementation of ProfileStore:

``` luau
local ProfileStore = require(game.ServerScriptService.ProfileStore)

-- The PROFILE_TEMPLATE table is what new profile "Profile.Data" will default to:
local PROFILE_TEMPLATE = {
   Cash = 0,
   Items = {},
}

local Players = game:GetService("Players")

local PlayerStore = ProfileStore.New("PlayerStore", PROFILE_TEMPLATE)
local Profiles: {[player]: typeof(PlayerStore:StartSessionAsync())} = {}

local function PlayerAdded(player)

   -- Start a profile session for this player's data:

   local profile = PlayerStore:StartSessionAsync(`{player.UserId}`, {
      Cancel = function()
         return player.Parent ~= Players
      end,
   })

   -- Handling new profile session or failure to start it:

   if profile ~= nil then

      profile:AddUserId(player.UserId) -- GDPR compliance
      profile:Reconcile() -- Fill in missing variables from PROFILE_TEMPLATE (optional)

      profile.OnSessionEnd:Connect(function()
         Profiles[player] = nil
         player:Kick(`Profile session end - Please rejoin`)
      end)

      if player.Parent == Players then
         Profiles[player] = profile
         print(`Profile loaded for {player.DisplayName}!`)
         -- EXAMPLE: Grant the player 100 coins for joining:
         profile.Data.Cash += 100
         -- You should set "Cash" in PROFILE_TEMPLATE and use "Profile:Reconcile()",
         -- otherwise you'll have to check whether "Data.Cash" is not nil
      else
         -- The player has left before the profile session started
         profile:EndSession()
      end

   else
      -- This condition should only happen when the Roblox server is shutting down
      player:Kick(`Profile load fail - Please rejoin`)
   end

end

-- In case Players have joined the server earlier than this script ran:
for _, player in Players:GetPlayers() do
   task.spawn(PlayerAdded, player)
end

Players.PlayerAdded:Connect(PlayerAdded)

Players.PlayerRemoving:Connect(function(player)
   local profile = Profiles[player]
   if profile ~= nil then
      profile:EndSession()
   end
end)

```