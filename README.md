# MAD STUDIO - ProfileStore

ProfileStore is a Roblox DataStore wrapper that streamlines auto-saving, session locking and a few other features for the game developer. ProfileStore's source code runs on a single ModuleScript.

If you want to save time writing code for player data caching or want to prevent item "duping" in a game with trading - this can be a helpful resource!

💲💲💲 *Consider [donating R$ to the creator of ProfileStore (Click here)](https://www.roblox.com/games/103946622805308/MAD-STUDIO-Open-Source-Donations) if you find this resource helpful!*

## How does it work?

ProfileStore loads and caches data from a DataStore key on a single Roblox game server and prevents other game servers from accessing this data too soon by establishing a session lock and handling session lock conflicts between servers swiftly all while not using too many DataStore and MessagingService API calls.

Data units saved by ProfileStore are called **"profiles"** which can be accessed in-game by starting a **"session"**. During an active session you gain access to a table ([`Profile.Data`](/ProfileStore/api/#data)) which will either be saved to the DataStore on the next auto-save or when you manually end the session.

ProfileStore is primarily **player-data-oriented** and, by design, tweaked for a common use case where each game player would have a single profile dedicated to storing their game progress. Session locking addresses the issue of data access from more than one game server (which can cause item "dupes" in games with trading) by keeping track of which game server is currently caching data and gracefully switches ownership from one server to the other without failing new session requests. ProfileStore can still be used for non-player data storage, although ProfileStore's session locking is not ideal for quick writing from several game servers.

ProfileStore's module functions try to resemble the Roblox API for a sense of familiarity to Roblox developers. Methods with the `Async` keyword yield until a result is ready (e.g. `:StartSessionAsync()`), while others do not.

**ProfileStore is not designed (and never will be) for in-game leaderboards or any kind of global state.**

---

*Developed by [loleris](https://x.com/lolerismad)*

***See documentation:***
**[ProfileStore wiki](https://madstudioroblox.github.io/ProfileStore/)**

***Get it now on:***
[Roblox library](https://create.roblox.com/store/asset/109379033046155/ProfileStore)

If you need help integrating ProfileStore into your project, [join the discussion on the Roblox forums (Click here)](https://devforum.roblox.com/t/profilestore/3190543).