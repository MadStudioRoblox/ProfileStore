ProfileStore uses Roblox [DataStores](https://create.roblox.com/docs/cloud-services/data-stores) to store profile data.
Roblox game servers have a limit on how many DataStore API requests can be made in a certain amount of time.
You can find official information on [Roblox DataStore limits by clicking here](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits#server-limits).
ProfileStore also uses Roblox [MessagingService](https://create.roblox.com/docs/reference/engine/classes/MessagingService#summary) to resolve session conflicts between multiple servers faster - Find information on [Roblox MessagingService limits by clicking here](https://create.roblox.com/docs/reference/engine/classes/MessagingService#summary).

*(During DataStore outages after a DataStore request results in an error ProfileStore may repeat requests faster or slower [using exponential backoff](https://en.wikipedia.org/wiki/Exponential_backoff))*

***Certain operations you may perform using ProfileStore will use up a certain amount of Roblox API requests:***

## On startup in Studio

- Uses 1 [`:SetAsync()`](https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore#SetAsync) call to check for DataStore API access.

## [`:StartSessionAsync()`](/ProfileStore/api/#startsessionasync)

**Until a session is started:**

- Usually uses 1 [`:UpdateAsync()`](https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore#UpdateAsync) call.
- If another server currently has a session started for the same profile, uses 1 [`:UpdateAsync()`](https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore#UpdateAsync) call
and 1 [`:PublishAsync()`](https://create.roblox.com/docs/reference/engine/classes/MessagingService#PublishAsync) call,
then 5 seconds later (`FIRST_LOAD_REPEAT`) will perform 1 [`:UpdateAsync()`](https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore#UpdateAsync) call and 1 
[`:PublishAsync()`](https://create.roblox.com/docs/reference/engine/classes/MessagingService#PublishAsync) call. While the session conflict is not resolved,
1 [`:UpdateAsync()`](https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore#UpdateAsync) call and 1 [`:PublishAsync()`](https://create.roblox.com/docs/reference/engine/classes/MessagingService#PublishAsync)
call will be repeated in 10 second intervals (`LOAD_REPEAT_PERIOD`) for the next 40 seconds (`SESSION_STEAL`) until finally a session will be stolen (1 [`:UpdateAsync()`](https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore#UpdateAsync) call). Expect all of these calls to happen when players rejoin your game immediately after experiencing a server crash.

**After a session is started and until the session ends:**

- Uses 1 [`:UpdateAsync()`](https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore#UpdateAsync) call in 300 second intervals (`AUTO_SAVE_PERIOD`).
When [`:Save()`](/ProfileStore/api/#save) is used, the 300 second timer will reset for this repeating call. This is the auto-save call.
- Subscribes to 1 [`MessagingService`](https://create.roblox.com/docs/reference/engine/classes/MessagingService) topic
(1 [`:SubscribeAsync()`](https://create.roblox.com/docs/reference/engine/classes/MessagingService#SubscribeAsync) call) -
this topic subscription will be ended when the profile session ends.

**After [`:EndSession()`](/ProfileStore/api/#endsession) is called OR another server starts a session for the same profile:**

- Usually uses 1 [`:UpdateAsync()`](https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore#UpdateAsync) call.
- In rare cases will use 2 [`:UpdateAsync()`](https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore#UpdateAsync) calls in quick succession
(1'st call - external session request detected; 2'nd call - locally broadcasting a final save and ending the session) when resolving a session conflict
if a [`MessagingService`](https://create.roblox.com/docs/reference/engine/classes/MessagingService) message asking for a session end was not received on time.

##  [`:MessageAsync()`](/ProfileStore/api/#messageasync)

- Uses 1 [`:UpdateAsync()`](https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore#UpdateAsync) call and 1
[`:PublishAsync()`](https://create.roblox.com/docs/reference/engine/classes/MessagingService#PublishAsync) call.
- If there's a server that currently has a session started for the targeted profile, 1 [`:UpdateAsync()`](https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore#UpdateAsync) call
will be used on that server regardless of whether [`:MessageAsync()`](/ProfileStore/api/#startsessionasync) was called on the same server. The 300 second auto-save interval timer would also be reset in this scenario.
ProfileStore does not assume developer code would immediately process a message sent by [`:MessageAsync()`](/ProfileStore/api/#startsessionasync) on the same server at all times, so
instant storage of the message to the DataStore is prioritized to ensure data persistence.

## [`:GetAsync()`](/ProfileStore/api/#getasync)

- Uses 1 [`GlobalDataStore:GetAsync()`](https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore#GetAsync) call.

## [`:RemoveAsync()`](/ProfileStore/api/#removeasync)

- Uses 1 [`GlobalDataStore:RemoveAsync()`](https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore#RemoveAsync) call.

## [`VersionQuery:NextAsync()`](/ProfileStore/api/#versionquery)

- May use 1 [`:ListVersionsAsync()`](https://create.roblox.com/docs/reference/engine/classes/DataStore#ListVersionsAsync) call
and may use 1 [`GlobalDataStore:GetAsync()`](https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore#GetAsync) call.

## [`:Save()`](/ProfileStore/api/#save)

- Uses 1 [`:UpdateAsync()`](https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore#UpdateAsync) call.

## [`:SetAsync()`](/ProfileStore/api/#setasync)

- Uses 1 [`:UpdateAsync()`](https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore#UpdateAsync) call.