!!! notice
    Methods with `Async` in their name are methods that will yield - similar to how `task.wait()` is a function that yields

## Module

### .IsClosing
``` luau
ProfileStore.IsClosing   [bool] (read-only)
```
When the Roblox is shutting down this value will be set to `true` and
most methods will silently fail.

### .IsCriticalState
``` luau
ProfileStore.IsCriticalState   [bool] (read-only)
```
After an excessive amount of DataStore calls fail this value will temporarily
be set to `true` until the DataStore starts operating normally again. Might be
useful for analytics or notifying players in-game of possible service disturbances.

### .OnError
``` luau
ProfileStore.OnError   [Signal] (message, store_name, profile_key)
```
A signal for DataStore error logging. Example:
``` luau
ProfileStore.OnError:Connect(function(error_message, store_name, profile_key)
  print(`DataStore error (Store:{store_name};Key:{profile_key}): {error_message}`)
end)
```

### .OnOverwrite
``` luau
ProfileStore.OnOverwrite   [Signal] (store_name, profile_key)
```
A signal for events when a DataStore key returns a value that has all or some
of it's profile components set to invalid data types. E.g., accidentally setting
`Profile.Data` to a non table value. Example:
``` luau
ProfileStore.OnOverwrite:Connect(function(store_name, profile_key)
  print(`Overwrite has occurred for Store:{store_name}, Key:{profile_key}`)
end)
```

### .OnCriticalToggle
``` luau
ProfileStore.OnCriticalToggle   [Signal] (is_critical)
```
A signal that is called whenever `ProfileStore.IsCriticalState` changes. Example:
``` luau
ProfileStore.OnCriticalToggle:Connect(function(is_critical)
  if is_critical == true then
    print(`ProfileStore entered critical state`)
  else
    print(`ProfileStore critical state is over`)
  end
end)
```

### .DataStoreState
``` luau
ProfileStore.DataStoreState   [string] "NotReady" | "NoInternet" | "NoAccess" | "Access"
```
Indicates ProfileStore's access to the DataStore. If at first check `ProfileStore.DataStoreState`
is `"NotReady"`, it will eventually change to one of the other 3 possible values (`NoInternet`, `NoAccess` or `Access`) and
never change again. `"Access"` means ProfileStore can write to the DataStore.

### .New()
``` luau
ProfileStore.New(store_name, template?) --> [ProfileStore]
  -- store_name   [string] -- DataStore name
  -- template     nil or [table] -- Profile.Data will default
    -- to given table (deep-copy) when no data was saved previously
```
`ProfileStore` objects expose methods for reading and writing to profiles. Equivalent of [:GetDataStore()](https://create.roblox.com/docs/reference/engine/classes/DataStoreService#GetDataStore)
in Roblox [DataStoreService](https://create.roblox.com/docs/reference/engine/classes/DataStoreService) API.

!!! notice
    By default, `template` is only copied for `Profile.Data` for new profiles. Changes made to `template` can be applied to `Profile.Data` of previously saved profiles by calling [Profile:Reconcile()](#reconcile).
    Using templates and reconciliation is completely optional and you may alter `Profile.Data` with your own code alone.

### .SetConstant()
``` luau
ProfileStore.SetConstant(name, value)
  -- name    [string] "AUTO_SAVE_PERIOD" | "LOAD_REPEAT_PERIOD" | "FIRST_LOAD_REPEAT" | "SESSION_STEAL"
|   -- "ASSUME_DEAD" | "START_SESSION_TIMEOUT" | "CRITICAL_STATE_ERROR_COUNT" | "CRITICAL_STATE_ERROR_EXPIRE"
|   -- "CRITICAL_STATE_EXPIRE" | "MAX_MESSAGE_QUEUE"
  -- value   [number]
```
A feature for experienced developers who understand how ProfileStore works for changing internal constants
without having to fork the ProfileStore project.

## ProfileStore

### .Mock
```lua
local PlayerStore = ProfileStore.New("PlayerData", {})

-- This profile would be saved to the DataStore:
local LiveProfile = PlayerStore:StartSessionAsync("profile_key")
LiveProfile.Data.Value = 1
LiveProfile:EndSession()

-- This profile does not load data from the DataStore
-- nor save data to the DataStore:
-- (This data will disappear after the game server shuts down)
local MockProfile = PlayerStore.Mock:StartSessionAsync("profile_key")
MockProfile.Data.Value = 1
MockProfile:EndSession()
```

`ProfileStore.Mock` is a reflection of methods available in the `ProfileStore`, but said methods will now operate
on profiles stored on a separate "fake" DataStore that will be forgotten when the game server shuts down. Profiles loaded
using the same key from `ProfileStore` and `ProfileStore.Mock` will be different profiles because the regular and mock versions of a `ProfileStore` are isolated from each other.

`ProfileStore.Mock` is useful for customizing your testing environment in cases where you want
to [enable Roblox API services](https://create.roblox.com/docs/cloud-services/data-stores#enabling-studio-access) in studio,
but don't want ProfileStore to save to live keys:
``` luau
local RunService = game:GetService("RunService")
local PlayerStore = ProfileStore.New("PlayerData", {})
if RunService:IsStudio() == true then
  PlayerStore = PlayerStore.Mock
end
```

!!! notice
    Even when Roblox API services are unavailable, `ProfileStore` and `ProfileStore.Mock` will store profiles separately from each other.

### .Name
``` luau
ProfileStore.Name   [string] (read-only)
```
The name of the DataStore that was defined as the first argument of `ProfileStore.New()`.

### :StartSessionAsync()
``` luau
ProfileStore:StartSessionAsync(profile_key, params?) --> [Profile] or nil
  -- profile_key   [string] -- DataStore key
  -- params        nil or [table]: {
  --    Cancel: fn() -> (boolean)?
  --    Steal: boolean?
  -- }
```
Starts a session for a profile. If other servers call this method using the same `profile_key`
they would notify the server that currently owns the session to make a final save before
letting another server acquire the session. While a session is active you can expect any
changes to `Profile.Data` to be saved. You can find out whether a session has ended by checking `Profile:IsActive() == true`
or by listening to `Profile.OnSessionEnd`. You must always call `Profile:EndSession()` after
you're done working with a profile as failing to do so will make the game perform more and more DataStore requests.

The second optional argument to `ProfileStore:StartSessionAsync()` is a table with additional rules for the session start request:

- **`Cancel`** - If set to a function, the function will be called several times by ProfileStore to check whether
the profile session is still needed. If the profile is no longer needed, the `Cancel` function should return `true`.
The `Cancel` argument would be useful in rare cases where the DataStores are unresponsive and a player leaves
before a session was started allowing ProfileStore to stop making additional requests to the DataStore.
Using the `Cancel` argument also disables the default ProfileStore session start timeout as the developer
would decide when the profile is no longer needed.
- **`Steal`** - (e.g. `{Steal = true}`) If set to `true`, doesn't let an active session make final changes to `Profile.Data`
and immediately starts a session on the server calling `ProfileStore:StartSessionAsync()` with this argument.
**DO NOT USE THIS ARGUMENT FOR LOADING PLAYER DATA NORMALLY** - The `Steal` argument bypasses session locks which are needed for item "dupe" prevention.
This argument is only useful for debugging.

!!! failure "The `Steal` argument bypasses session locks which are needed for item "dupe" prevention - use this only if you know what you are doing"

Example usage:
``` luau
local Players = game:GetService("Players")
local profile = PlayerStore:StartSessionAsync(tostring(player.UserId), {
  Cancel = function()
    return player:IsDescendantOf(Players) == false
  end,
})
```

!!! notice
    ProfileStore saves profiles to live DataStore keys in Roblox Studio when [Roblox API services are enabled](https://create.roblox.com/docs/cloud-services/data-stores#enabling-studio-access). See [ProfileStore.Mock](#mock) if saving to live keys during testing is not desired.

!!! warning
    `:StartSessionAsync()` can return `nil` when another remote Roblox server attempts to start a session for the same profile at the same time.
    This case should be extremely rare and it would be recommended to [:Kick()](https://create.roblox.com/docs/reference/engine/classes/Player#Kick)
    the player if `:StartSessionAsync()` does not return a `Profile` object.

### :MessageAsync()
``` luau
ProfileStore:MessageAsync(profile_key, message) --> is_success [bool]
  -- profile_key   [string] -- DataStore key
  -- message       [table] -- Data to be stored in the profile before it's received
```
Sends a message to a profile regardless of whether a server has started a session for it.
Each `ProfileStore:MessageAsync()` call will use one [:UpdateAsync()](https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore#UpdateAsync)
call for sending the message and another [:UpdateAsync()](https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore#UpdateAsync)
call on the server that currently has a session started for the profile - This means
that `ProfileStore:MessageAsync()` is only to be used for when handling critical data like **gifting
paid items to in-game friends that may or may not be online at the moment**. If you don't mind the possibility
of your messages failing to deliver, use [MessagingService](https://create.roblox.com/docs/reference/engine/classes/MessagingService) instead.
See [`Profile:MessageHandler()`](#messagehandler) to learn how to receive messages.

### :GetAsync()
``` luau
ProfileStore:GetAsync(profile_key, version?) --> [Profile] or nil
  -- profile_key   [string]
  -- version       nil or [string] -- DataStore key version
```
Attempts to load the latest profile version (or a specified version via the `version` argument) from the DataStore without starting a session.
Returned `Profile` will not auto-save and you won't have to call `:EndSession()` for it.
Data in the returned `Profile` can be edited to create a payload which can be saved via [Profile:SetAsync()](#setasync).
If there's no data saved in the DataStore under a provided `profile_key`, `ProfileStore:GetAsync()` will return `nil`.

`:GetAsync()` is the the preferred way of reading player data without editing it.

!!! warning "`Profile.Data` will not be auto-saved when using `ProfileStore:GetAsync()`"

### :VersionQuery()
```lua
ProfileStore:VersionQuery(profile_key, sort_direction?, min_date?, max_date?) --> [VersionQuery]
  -- profile_key      [string]
  -- sort_direction   nil or [Enum.SortDirection] -- Defaults to "Ascending"
  -- min_date         nil or [DateTime] or [number] (epoch time millis)
  -- max_date         nil or [DateTime] or [number] (epoch time millis)
```
Creates a profile version query using [DataStore:ListVersionsAsync() (Official documentation)](https://create.roblox.com/docs/reference/engine/classes/DataStore#ListVersionsAsync). Results are retrieved through `VersionQuery:NextAsync()`.
Date definitions are easier with the [DateTime (Official documentation)](https://create.roblox.com/docs/reference/engine/datatypes/DateTime) library. User defined day and time will have to be converted to [Unix time (Wikipedia)](https://en.wikipedia.org/wiki/Unix_time) while taking their timezone into account to expect the most precise results, though you can be rough and just set the date and time in the UTC timezone and expect a maximum margin of error of 24 hours for your query results.

**Examples of query arguments:**

   - Pass `nil` for `sort_direction`, `min_date` and `max_date` to find the oldest available version
   - Pass `Enum.SortDirection.Descending` for `sort_direction`, `nil` for `min_date` and `max_date` to find the most recent version.
   - Pass `Enum.SortDirection.Descending` for `sort_direction`, `nil` for `min_date` and `DateTime` **defining a time before an event**
    (e.g. two days earlier before your game unrightfully stole 1,000,000 coins from a player) for `max_date` to find the most recent
    version of a `Profile` that existed before said event.

**Case example: "I lost all of my coins on August 14th!"**

```lua
-- Get a ProfileStore object with the same arguments you passed to the
--  ProfileStore that loads player Profiles:

local PlayerStore = ProfileStore.New("PlayerData", {})

-- If you can't figure out the exact time and timezone the player lost coins
--  in on the day of August 14th, then your best bet is to try querying
--  UTC August 13th. If the first entry still doesn't have the coins - 
--  try a new query of UTC August 12th and etc.

local max_date = DateTime.fromUniversalTime(2021, 08, 13) -- UTC August 13th, 2021

local query = PlayerStore:VersionQuery(
  "Player_2312310", -- The same profile key that gets passed to :LoadProfileAsync()
  Enum.SortDirection.Descending,
  nil,
  max_date
)

-- Get the first result in the query:
local profile = query:NextAsync()

if profile ~= nil then

  profile:SetAsync() -- This method does the actual rolling back;
    -- Don't call this method until you're sure about setting the latest
    -- version to a copy of the previous one

  print(`Rollback success!`)

  print(profile.Data) -- You'll be able to surf table contents if
    -- you're running this code in studio with access to API services
    -- enabled and have expressive output enabled; If the printed
    -- data doesn't have the coins, you'll want to change your
    -- query parameters.

else
  print(`No version to rollback to`)
end
```

**Case example: Studying data mutation over time**

```lua
-- You have ProfileStore working in your game. You join
--  the game with your own account and go to https://www.unixtimestamp.com
--  and save the current UNIX timestamp resembling present time.
--  You can then make the game alter your data by giving you
--  currency, items, experience, etc.

local PlayerStore = ProfileStore.New("PlayerData", {})

-- UNIX timestamp you saved:
local min_date = DateTime.fromUnixTimestamp(1628952101)
local print_minutes = 60 * 12 -- Print the next 12 hours of history

local query = PlayerStore:VersionQuery(
  "Player_2312310",
  Enum.SortDirection.Ascending,
  min_date
)

-- You can now attempt to print out every snapshot of your data saved
--  at an average periodic interval of 60 minutes (Roblox DataStore caching interval)
--  starting from the time you took the UNIX timestamp!

local finish_update_time = min_date.UnixTimestampMillis + (print_minutes * 60000)

print(`Fetching {print_minutes} minutes of saves:`)

local entry_count = 0

while true do

  entry_count +=1
  local profile = query:NextAsync()

  if profile ~= nil then

    if profile.KeyInfo.UpdatedTime > finish_update_time then
      if entry_count == 1 then
        print(`No entries found in set time period. (Start timestamp too early)`)
      else
        print(`Time period finished.`)
      end
      break
    end

    print(`Entry {entry_count} - {DateTime.fromUnixTimestampMillis(profile.KeyInfo.UpdatedTime):ToIsoDate()}`)

    print(profile.Data) -- Printing table for studio expressive output

  else
    if entry_count == 1 then
      print(`No entries found in set time period. (Start timestamp too late)`)
    else
      print(`No more entries in query.`)
    end
    break
  end

end
```

### :RemoveAsync()
``` luau
ProfileStore:RemoveAsync(profile_key) --> is_success [bool]
  -- profile_key   [string] -- DataStore key
```
You can use `:RemoveAsync()` to erase data from the DataStore. In live Roblox servers `:RemoveAsync()` must be used on
profiles created through `ProfileStore.Mock` after `Profile:EndSession()` and it's known that the `Profile` will no longer be loaded again.

## Profile

### .Data
``` luau
Profile.Data   [table]
```
This is the data that would resemble player progress or other data you wish to save to the [DataStore](https://create.roblox.com/docs/cloud-services/data-stores).
Changes to `Profile.Data` are guaranteed to save as long as you do so after checking for the condition `Profile:IsActive() == true` or
before the signal `Profile.OnSessionEnd` is triggered. The result of `Profile:IsActive()` can change at any moment, so critical data should
be stored to `Profile.Data` immediately after checking without yielding (e.g. `task.wait()`). If needed, you may set `Profile.Data`
to a new table reference (e.g. `Profile.Data = {}`). When `Profile:IsActive()` returns `false` changes to `Profile.Data` are no longer
stored to the DataStore.

### .LastSavedData
``` luau
Profile.LastSavedData   [table] (read-only)
```
This is a version of `Profile.Data` that has been successfully stored to the DataStore. Useful for
verifying what particular data has been saved, or for securely handling developer product purchases.

### .FirstSessionTime
``` luau
Profile.FirstSessionTime   [number] (read-only) -- Unix time
```
A [Unix timestamp]((https://en.wikipedia.org/wiki/Unix_time)) of when the profile was created.

### .SessionLoadCount
``` luau
Profile.SessionLoadCount   [number] (read-only)
```
Amount of times a session has been started for this profile.

### .Session
``` luau
Profile.Session   [table?] (read-only) -- nil or {PlaceId = number, JobId = string}
```
This value never changes after a profile object is created. After you start a session for a profile,
the `Profile.Session` will be equal to a `table` with it's `PlaceId` and `JobId` members set to the server you started
the session on. After you read a profile using [ProfileStore:GetAsync()](#getasync), `Profile.Session`
may be equal to `nil` or a `table` with it's `PlaceId` and `JobId` members set to the server that currently
has a session started for the profile.

### .RobloxMetaData
``` luau
Profile.RobloxMetaData   [table]
```
!!! failure "Be cautious of very harsh limits for maximum Roblox Metadata size - As of writing this, total table content size cannot exceed 300 characters."

A table that gets saved as [Metadata (Official documentation)](https://create.roblox.com/docs/cloud-services/data-stores#metadata) of a DataStore key belonging to the profile.
The way this table is saved is equivalent to using `DataStoreSetOptions:SetMetaData(Profile.RobloxMetaData)` and passing the `DataStoreSetOptions` object to a `:SetAsync()` call,
except changes will truly get saved on the next auto-save cycle or when the profile session is ended. Info
on Roblox metadata limits [can be found here](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits#metadata-limits).

### .UserIds
``` luau
Profile.UserIds [table] (read-only) -- {user_id [number], ...}
```
User ids associated with this profile. Entries must be added with [Profile:AddUserId()](#adduserid) and removed with [Profile:RemoveUserId()](#removeuserid).

### .KeyInfo
``` luau
Profile.KeyInfo [DataStoreKeyInfo]
```
The [DataStoreKeyInfo (Official documentation)](https://create.roblox.com/docs/reference/engine/classes/DataStoreKeyInfo)
instance related to this profile.

### .OnSave
``` luau
Profile.OnSave:Connect(function()
  print(`Profile.Data is about to be saved to the DataStore`)
end)
```
A signal that is fired right before whenever changes to `Profile.Data` are saved to the DataStore. Changes to `Profile.Data`
are expected to save when done at the moment of `Profile.OnSave` firing, but this guarantee is no longer valid after yielding
(e.g. using `task.wait()` or `:WaitForChild()`) and the condition `Profile:IsActive() == true` would have to be used instead.
`Profile.OnSave` will be fired before every auto-save, before a manual save caused by `Profile:Save()` and before a final save
after a session has been ended.

### .OnLastSave
``` luau
Profile.OnLastSave:Connect(function(reason: "Manual" | "External" | "Shutdown")
  print(`Profile.Data is about to be saved to the DataStore for the last time; Reason: {reason}`)
end)
```
A signal that is fired right before changes to `Profile.Data` are saved to the DataStore for the last time. Changes to `Profile.Data`
are expected to save when done at the moment of `Profile.OnLastSave` firing, but this guarantee is no longer valid after yielding
(e.g. using `task.wait()` or `:WaitForChild()`). `Profile.OnLastSave` will be fired after a session has ended in one of three ways:

- **`"Manual"`** - Developer code called `Profile:EndSession()`
- **`"External"`** - Another server started a session for the same profile
- **`"Shutdown"`** - The profile session has been ended automatically due to the server shutting down

One of `Profile.OnLastSave` uses is giving "logout penalties" where a player may receive punishment for
closing the game at the wrong time. Example:
``` luau
local InCombat = false

Profile.OnLastSave:Connect(function(reason)
  if reason ~= "Shutdown" then

    print(`The cause of the session ending is not due to a server shutdown`)

    -- If you didn't want the player to logout at this particular moment,
    -- this should be where you'd penalize the player. e.g.:

    if InCombat == true then
      Profile.Data.Coins -= 100
    end

  end
end)
```

!!! warning
    On rare occasions Roblox servers can crash and `Profile.OnLastSave` might never get the chance to fire.
    You should design your data saving code in a way where reacting to `Profile.OnLastSave` is not critical.

### .OnSessionEnd
``` luau
Profile.OnSessionEnd:Connect(function()
  print(`Profile session has ended - Profile.Data will no longer be saved to the DataStore`)
end)
```
The `Profile.OnSessionEnd` signal can be fired after the developer calls [`Profile:EndSession()`](#endsession),
Another server calls [`ProfileStore:StartSessionAsync()`] for the same profile or when the server is shutting down.
After the `Profile.OnSessionEnd` signal is fired, no further changes to `Profile.Data` should be made.
`Profile.OnSessionEnd` will fire even when a profile session is stolen, whereas `Profile.OnLastSave` would not.
In some cases it would be preferable to kick the player from the game when this signal is fired:

``` luau
Profile.OnSessionEnd:Connect(function()
  player:Kick(`Your data has been loaded on another server - please rejoin`)
end)
```

!!! warning
    `Profile.OnSessionEnd` should not be used for applying final changes to `Profile.Data`.
    Use `Profile.OnLastSave` instead.

### .OnAfterSave
``` luau
Profile.OnAfterSave:Connect(function(last_saved_data)
  print(`Profile.Data has been successfully saved to the DataStore:`, last_saved_data)
end)
```
This signal will fire every time after profile data has been accessed by [`GlobalDataStore:UpdateAsync()`](https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore#UpdateAsync).
After this signal is fired, the values [`Profile.LastSavedData`](#lastsaveddata) and [`Profile.KeyInfo`](#keyinfo) will have been changed -
[`Profile.LastSavedData`](#lastsaveddata) can be used to verify which particular changes to [`Profile.Data`](#data) have been
successfully saved to the DataStore.

### .ProfileStore
``` luau
Profile.ProfileStore   [ProfileStore] -- ProfileStore object this profile belongs to
```
The [`ProfileStore`](#new) object that was used to create this profile.

### .Key
``` luau
Profile.Key   [string] -- DataStore key
```
The DataStore key of this profile. This is the first passed argument to [`ProfileStore:StartSessionAsync()`](#startsessionasync)
or [`ProfileStore:GetAsync()`](#getasync).

### :IsActive()
``` luau
Profile:IsActive() --> [bool]
```
If  `Profile:IsActive()` returns `true`, changes to `Profile.Data` will be saved - this guarantee
will no longer be valid after yielding (e.g. using `task.wait()` or `:WaitForChild()`). When implementing in-game trading,
you may make changes to two profiles immediately without yielding after `Profile:IsActive()` returns `true` for the two profiles.

### :Reconcile()
``` luau
Profile:Reconcile()
```
Fills in missing variables inside `Profile.Data` from a template table that was provided as a second argument
to [`ProfileStore.New()`](#new). `Profile:Reconcile()` can be useful if you're making changes to your
data template over the course of your game's development.

### :EndSession()
``` luau
Profile:EndSession()
```
Stops auto-saving for this profile and saves `Profile.Data` to the DataStore for
the last time. Call this method after you're done working with the `Profile` object created by [`ProfileStore:StartSessionAsync()`](#startsessionasync).

Example:
``` luau
Players.PlayerRemoving:Connect(function(player)
    
  local profile = Profiles[player]
	
  if profile ~= nil then
    profile:EndSession()
    Profiles[player] = nil
  end
	
end)
```

### :AddUserId()
``` luau
Profile:AddUserId(user_id)
-- user_id [number]
```
Associates a `UserId` with the profile. Multiple users can be associated with a single profile by calling this method for each individual `UserId`.
The primary use of this method is to comply with GDPR (The right to erasure). More information in [official documentation](https://create.roblox.com/docs/cloud-services/data-stores#metadata).

### :RemoveUserId()
``` luau
Profile:RemoveUserId(user_id)
-- user_id [number]
```
Unassociates a `UserId` with the profile.

### :MessageHandler()
``` luau
Profile:MessageHandler(function(message, processed)
  print(`Message received:`, message)
  processed()
end)
```
Sets a function that will handle existing and future incoming messages sent to this profile by [`ProfileStore:MessageAsync()`](#messageasync).
The `message` argument is a `table` that was passed as the second argument to [`ProfileStore:MessageAsync()`](#messageasync).
The `processed` argument is a function that must be called to let ProfileStore know this message has
been processed. If a message is not processed by calling `processed()`, ProfileStore will continue to iterate through
other functions passed to `Profile:MessageHandler()` and will broadcast the same `message`. Unprocessed messages will
be broadcasted to new functions passed to `Profile:MessageHandler()` and will continue to do so when a profile session is started
another time (e.g. after a player joins the game again) until `processed()` is finally called.

### :Save()
``` luau
Profile:Save()
```
Calling `Profile:Save()` will immediately save `Profile.Data` to the DataStore when a profile session is still active (`Profile:IsActive()` returns `true`).
`Profile.Data` is already automatically saved to the DataStore on auto-saves and when the profile session is ended with `Profile:EndSession()`,
so `Profile:Save()` should only be used for critical moments like ensuring data related to [Developer Product](https://create.roblox.com/docs/production/monetization/developer-products)
purchases are saved before a server crash could occur. The cost of calling `Profile:Save()` is one [:UpdateAsync()](https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore#UpdateAsync)
call - see the official documentation on [DataStore limits](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits#server-limits) to
evaluate your use case.

### :SetAsync()
``` luau
Profile:SetAsync()
```

!!! warning "Only works for profiles loaded through [ProfileStore:GetAsync()](#getasync) or [ProfileStore:VersionQuery()](#versionquery)"

Saves `Profile.Data` of a profile loaded with [ProfileStore:GetAsync()](#getasync) to the DataStore disregarding any active sessions.
If there was a server that had an active session for that profile - that session will be ended.