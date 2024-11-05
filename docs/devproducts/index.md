This is a resource that can help you implement [Developer Products](https://create.roblox.com/docs/production/monetization/developer-products) into your
Roblox game when you're also using ProfileStore.

There are two ways you could handle [Developer Product](https://create.roblox.com/docs/production/monetization/developer-products) purchases -
one way is based on the [official Roblox documentation on handling developer product purchases](https://create.roblox.com/docs/production/monetization/developer-products#handling-developer-product-purchases), while the other way is based on
observations on how [Roblox MarketplaceService API](https://create.roblox.com/docs/reference/engine/classes/MarketplaceService) works.

**In these examples `local Profiles` is a reference to the `Profiles` table in the [Basic Usage example code](/ProfileStore/tutorial/#basic-usage) - you will need to have this code present for the examples below to work!**

## The official Roblox way

*(This is a Roblox official code example with alterations integrating ProfileStore)*

``` luau
local Profiles: {[player]: typeof(PlayerStore:StartSessionAsync())} = {} -- See Tutorial > Basic Usage

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local productFunctions = {}

-- Example: product ID 456456 awards 100 cash to the user
productFunctions[456456] = function(receipt, player, profile)
    profile.Data.Cash += 100
    -- We made changes to the player profile - perform an instant
    -- save to secure a player purchase against server crashes:
    profile:Save()
end

-- Example: product ID 123123 brings the user back to full health
productFunctions[123123] = function(receipt, player, profile)
	local character = player.Character
	local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")

	if humanoid then
		humanoid.Health = humanoid.MaxHealth
		-- Indicates a successful purchase
		return true
	end
end

local function processReceipt(receiptInfo)
	local userId = receiptInfo.PlayerId
	local productId = receiptInfo.ProductId

	local player = Players:GetPlayerByUserId(userId)
	if player then

        local profile = Profiles[player]

        while profile == nil and player.Parent == Players do
            profile = Profiles[player]
            if profile ~= nil then
                break
            end
            task.wait()
        end

        if profile ~= nil and profile:IsActive() == true then
            -- Gets the handler function associated with the developer product ID and attempts to run it
            local handler = productFunctions[productId]
            local success, result = pcall(handler, receiptInfo, player, profile)
            if success then
                -- The user has received their items
                -- Returns "PurchaseGranted" to confirm the transaction
                return Enum.ProductPurchaseDecision.PurchaseGranted
            else
                warn(`Failed to process receipt:`, receiptInfo, result)
            end
        end

	end

	-- The user's items couldn't be awarded
	-- Returns "NotProcessedYet" and tries again next time the user joins the experience
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Sets the callback
-- This can only be done once by one server-side script
MarketplaceService.ProcessReceipt = processReceipt

```

## Another way - Caching `PurchaseId`'s

Official Roblox documentation doesn't show a code example where the developer would delay
returning a `Enum.ProductPurchaseDecision` result in the `MarketplaceService.ProcessReceipt` callback
until it is known that the purchase has been successfully stored in the DataStore - this is not as relevant to
immediate consumables like "Buy this to kill everyone in this server", but more relevant to consumables like
in-game currency or even permanent perks. `MarketplaceService.ProcessReceipt` will continue requesting
developer code to handle a product purchase even after a player rejoins the game after a while - the
purchase handle request will provide a unique `PurchaseId` identifier which will stay consistent for
a particular single purchase even after a player rejoins the game.

At the moment of writing, observing `MarketplaceService.ProcessReceipt` behavior, we can see that
it doesn't mind code yielding inside of it until a `Enum.ProductPurchaseDecision` result is returned -
we can use this behavior to wait until we know data related to this purchase has been successfully saved
by ProfileStore.

If retaining player rewards for developer products is completely critical, it should be noted that the
"official Roblox way" would fail to do so on a very rare condition where at a time of a developer
product purchase all DataStore requests fail (or not even manage to happen on time) before the
game server experiences a crash. This can be prevented by storing a cache of `PurchaseId` identifiers
in `Profile.Data` and rewarding the player at the same time, then waiting for `Profile.LastSavedData` to
be updated while yielding the response to the `MarketplaceService.ProcessReceipt` request and, if the
`PurchaseId` is found in `Profile.LastSavedData` - return `Enum.ProductPurchaseDecision.PurchaseGranted`
for the `MarketplaceService.ProcessReceipt` callback.

This is how you could do it:

``` luau
local Profiles: {[player]: typeof(PlayerStore:StartSessionAsync())} = {} -- See Tutorial > Basic Usage

local PURCHASE_ID_CACHE_SIZE = 100

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local ProductFunctions = {}

ProductFunctions[456456] = function(receipt, player, profile)
    profile.Data.Cash += 100
    -- No Profile:Save() is needed in here compared to the previous example
end

function PurchaseIdCheckAsync(profile, purchase_id, grant_product): Enum.ProductPurchaseDecision
    -- Waits until purchase_id is confirmed to be saved to the DataStore or the profile session has ended

    if profile:IsActive() == true then

        local purchase_id_cache = profile.Data.PurchaseIdCache

        if purchase_id_cache == nil then
            purchase_id_cache = {}
            profile.Data.PurchaseIdCache = purchase_id_cache
        end

        -- Granting product if not received:

        if table.find(purchase_id_cache, purchase_id) == nil then

            local success, result = pcall(grant_product)
            if success ~= true then
                warn(`Failed to process receipt:`, profile.Key, purchase_id, result)
                return Enum.ProductPurchaseDecision.NotProcessedYet
            end

            while #purchase_id_cache >= PURCHASE_ID_CACHE_SIZE do
                table.remove(purchase_id_cache, 1)
            end

            table.insert(purchase_id_cache, purchase_id)

        end

        -- Waiting until the purchase is confirmed to be saved to the DataStore:

        local function is_purchase_saved()
            local saved_cache = profile.LastSavedData.PurchaseIdCache
            return if saved_cache ~= nil then table.find(saved_cache, purchase_id) ~= nil else false
        end

        if is_purchase_saved() == true then
            return Enum.ProductPurchaseDecision.PurchaseGranted
        end

        while profile:IsActive() == true do

            local last_saved_data = profile.LastSavedData

            profile:Save()

            if profile.LastSavedData == last_saved_data then
                profile.OnAfterSave:Wait()
            end

            if is_purchase_saved() == true then
                return Enum.ProductPurchaseDecision.PurchaseGranted
            end

            if profile:IsActive() == true then
                task.wait(10)
            end

        end

    end

    return Enum.ProductPurchaseDecision.NotProcessedYet

end

local function ProcessReceipt(receipt_info)

    local player = Players:GetPlayerByUserId(receipt_info.PlayerId)

    if player ~= nil then

        local profile = Profiles[player]

        while profile == nil and player.Parent == Players do
            profile = Profiles[player]
            if profile ~= nil then
                break
            end
            task.wait()
        end

        if profile ~= nil then

            if ProductFunctions[receipt_info.ProductId] == nil then
                warn(`No product function defined for ProductId {receipt_info.ProductId}; Player: {player.Name}`)
                return Enum.ProductPurchaseDecision.NotProcessedYet
            end

            return PurchaseIdCheckAsync(
                profile,
                receipt_info.PurchaseId,
                function()
                    ProductFunctions[receipt_info.ProductId](receipt_info, player, profile)
                end
            )

        end
       
    end

    return Enum.ProductPurchaseDecision.NotProcessedYet

end

MarketplaceService.ProcessReceipt = ProcessReceipt

```