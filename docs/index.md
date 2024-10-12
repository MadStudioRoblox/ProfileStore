# Home

ProfileStore is a Roblox DataStore wrapper that streamlines auto-saving, session locking
and a few other features for the game developer. ProfileStore's source code runs on a single
ModuleScript.

If you want to save time writing code for player data caching or want to prevent item
"duping" in a game with trading - this can be a helpful resource!

💲💲💲 *Consider [donating R$ to the creator of ProfileStore (Click here)](https://www.roblox.com/games/103946622805308/MAD-STUDIO-Open-Source-Donations) if you find this resource helpful!*

If you need help integrating ProfileStore into your project, [join the discussion on the Roblox forums (Click here)](https://devforum.roblox.com/t/profilestore/3190543).

## How does it work?

ProfileStore loads and caches data from a DataStore key on a single Roblox game server and
prevents other game servers from accessing this data too soon by establishing a session lock
and handling session lock conflicts between servers swiftly all while not using too many
DataStore and MessagingService API calls.

Data units saved by ProfileStore are called **"profiles"** which can be accessed in-game by
starting a **"session"**. During an active session you gain access to a table ([`Profile.Data`](/ProfileStore/api/#data))
which will either be saved to the DataStore on the next auto-save or when you manually end
the session.

ProfileStore is primarily **player-data-oriented** and, by design, tweaked for a common use
case where each game player would have a single profile dedicated to storing their game
progress. Session locking addresses the issue of data access from more than one game server
(which can cause item "dupes" in games with trading) by keeping track of which game server
is currently caching data and gracefully switches ownership from one server to the other
without failing new session requests. ProfileStore can still be used for non-player data
storage, although ProfileStore's session locking is not ideal for quick writing from several
game servers.

ProfileStore's module functions try to resemble the Roblox API for a sense of familiarity
to Roblox developers. Methods with the `Async` keyword yield until a result is ready
(e.g. `:StartSessionAsync()`), while others do not.

**ProfileStore is not designed (and never will be) for in-game leaderboards or any kind of global state.**

## Changes from ProfileService

ProfileStore is a successor to ProfileService - it uses a very similar mechanism for handling
session locks which has been improved to be more responsive at handling conflicts between
servers. Here's a list of significant changes:

- **Default auto-save period increased from 30 to 300 seconds** - Nearly x10 fewer DataStore
calls consume less server resources which means more scalability!
ProfileStore relies on auto-saves to store latest data and
resolve session conflicts in a single `:UpdateAsync()` call. With the addition of
MessagingService, ProfileStore can now auto-save slower while still reacting to external game
servers trying to take the session lock. Under normal circumstances ProfileStore should
outperform ProfileService in session conflict resolution time!

- **More performance, more server-friendly** - `MessagingService` 
helps resolve session conflicts much faster. ProfileStore also tries to strain Roblox services
less when things inevitably do go wrong with exponential backoff, timeouts and cancel conditions.

- **Outdated 7 second DataStore queue replaced** - An internal DataStore API call queue
is needed to ensure calls are satisfied in order. Roblox DataStores have changed since
ProfileService was released and the 7 second queue was replaced with a queue that performs
calls to the same DataStore key as soon as all previous calls finish.

- **Luau types for autocompletion** - This will help make fewer typos while writing code with
ProfileStore.

- **API cleanup** - Function and variable names have been changed to be shorter and more conventional.

- **`MetaTags` removed in favor of `Profile.LastSavedData`** - MetaTags has been a piece of data exclusively used to verify data that has been successfully saved to the DataStore. `Profile.LastSavedData` will also satisfy this purpose - every time `Profile.Data` is saved to the DataStore, `Profile.LastSavedData` will be updated with the version of `Profile.Data` that has been successfully saved to the DataStore.

- **New profile messaging system replacing `GlobalUpdates`** - GlobalUpdates was a complicated
system for writing to profiles regardless of whether a server is currently running a session
for them. [`ProfileStore:MessageAsync()`](/ProfileStore/api/#messageasync) is much easier to use and has fast delivery
time by utilizing MessagingService. Use this for features like in-game player gifting
where data delivery is crucial.

- **`Profile.OnSave`, `Profile.OnLastSave` and `Profile.OnAfterSave` signals** - Useful for
altering and reacting to data along ProfileStore's DataStore requests.

## Should I switch from ProfileService (the older module)?

ProfileStore hasn't been used a lot in production yet, but has been thoroughly tested by similar
tools that allowed ProfileService to stay mostly bug-free. Use this at your own risk and forward
any bugs to the creator of this module - we'll try to fix bugs super quickly!

It might be a good idea to let old projects keep using ProfileService and start using ProfileStore
for brand new ones, but if you're feeling risky...

ProfileStore DataStore profiles are backwards-compatible with ProfileService! ProfileService profiles
should load from the DataStore using the same keys in ProfileStore without issue, but
ProfileService (the older module) might have issues loading the same profiles again if you start using [`ProfileStore:MessageAsync()`](/ProfileStore/api/#messageasync)
(on the new module). You should first do Roblox studio tests with API access before pushing this change live.