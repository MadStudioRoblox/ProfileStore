> Whether you're still writing your game code or already ran into a problem while using ProfileStore, this page can help you avoid some crucial mistakes.

## Problems in Roblox studio testing

By default, data saved with ProfileStore on Roblox Studio will not persist. This can be changed by [enabling studio access to API services](https://create.roblox.com/docs/cloud-services/data-stores#enabling-studio-access).

!!! warning "When studio access to API services is enabled, ProfileStore will write to live DataStore keys of the game you're editing (unless [ProfileStore.Mock](/ProfileStore/api/#mock) is used) and you might accidentally make unwanted changes to your game's saved data. For more info, check the [official documentation](https://create.roblox.com/docs/cloud-services/data-stores#enabling-studio-access)."

## Saving data which Roblox cannot serialize

ProfileStore does not check `Profile.Data` for data that cannot be serialized - be aware
that the DataStore can only save save data when your tables are devoid of:

- `NaN` values - you can check if a number is `NaN` by comparing it with itself - `print(NaN == NaN) --> false` (e.g., `Profile.Data = {Experience = 0/0}`). `NaN` values are a result of division by zero and edge cases of some math operations (`math.acos(2)` is `-NaN`).
- Table keys that are neither strings nor numbers (e.g., `Profile.Data[game.Workspace] = true`).
- Mixing string keys with number keys within the same table (e.g., `Profile.Data = {Coins = 100, [5] = "yes"}`).
- Storing tables with non-sequential indexes (e.g., `Profile.Data = {[1] = "Apple", [2] = "Banana", [3546] = "Peanut"}`). If you really have to store non-sequential numbers as indexes, you will have to turn those numbers into `string` indexes: `Profile.Data.Friends[tostring(user_id)] = {GoodFriend = true}`.
- Storing cyclic tables (e.g., `Profile.Data = {Self = Profile.Data}`).
- Storing any `userdata` including `Instance`, `Vector3`, `CFrame`, `Udim2`, etc. Check whether your value is a `userdata` by running `print(type(value) == "userdata")` (e.g., `Profile.Data = {LastPosition = Vector3.new(0, 0, 0)}`) - For storage, you will have to manually convert your `userdata` to tables, numbers and strings for storage (e.g., `Profile.Data = {LastPosition = {position.X, position.Y, position.Z} }`).

This is a limitation of the DataStore API - the service ProfileStore is based on.

!!! warning "When these data types are present in `Profile.Data` you may get DataStore errors and ProfileStore will fail to save that data"

## Profiles take too long to load

If your profiles are loading slower than 5 seconds, they're loading too slow.

**(MAKE SURE YOUR [ProfileStore](/ProfileStore/tutorial) MODULE IS UP TO DATE)**

**Possible reasons for this:**

 - *You're not running the latest version of ProfileStore [(click here to update)](/ProfileStore/tutorial)*
 - *You're not calling `Profile:EndSession()` after you're done working with profiles*
 - *You're not releasing your profiles __immediately__ after the player leaves the game*

Functions connected to [Players.PlayerRemoving](https://create.roblox.com/docs/reference/engine/classes/Players#PlayerRemoving)
can be tricky to notice errors for because, when testing alone, you will be leaving the game before the errors appear on the
[developer console](https://create.roblox.com/docs/studio/developer-console).

If a player hops to another server (*Server 2*) before the previous one (*Server 1*) calls `Profile:EndSession()` on the player's profile,
*Server 2* will wait until *Server 1* releases the profile. This may slow down session starting for profiles when the player hops servers.

The `print()` function can help you diagnose whether `Profile:EndSession()` is called on time:

``` luau
Profile.OnSessionEnd:Connect(function()
  print(`Profile session has ended ({Profile.Key}) - Profile.Data will no longer be saved to the DataStore`)
end)
```