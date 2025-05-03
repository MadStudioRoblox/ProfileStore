--[[
MAD STUDIO

-[ProfileStoreTest]---------------------------------------

	Automatic testing of the PofileStore module
	
--]]

local TEST_MOCK = false
local PREFIX = "[PS_TEST]: "

----- Dependencies -----

local ProfileStore

do
	local yielded = true
	task.spawn(function()
		ProfileStore = require(game.ServerScriptService.ProfileStore)
		yielded = false
	end)
	if yielded == true then
		error(PREFIX .. `Module shouldn't yield when required`)
	end
end

local AUTO_SAVE_PERIOD = 10
ProfileStore.SetConstant("AUTO_SAVE_PERIOD", AUTO_SAVE_PERIOD) -- Faster auto-save lets tests proceed faster

----------

local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")

local function DeepCopyTable(t)
	local copy = {}
	for key, value in pairs(t) do
		if type(value) == "table" then
			copy[key] = DeepCopyTable(value)
		else
			copy[key] = value
		end
	end
	return copy
end

local function KeyToString(key)
	if type(key) == "string" then
		return "\"" .. key .. "\""
	else
		return tostring(key)
	end
end

local function TableToString(t: {})
	local output = "{"
	local entries = 0
	for key, value in pairs(t) do
		entries = entries + 1
		if type(value) == "string" then
			output = output .. (entries > 1 and ", " or "") .. "[" .. KeyToString(key) .. "] = \"" .. value .. "\""
		elseif type(value) == "number" then
			output = output .. (entries > 1 and ", " or "") .. "[" .. KeyToString(key) .. "] = " .. value
		elseif type(value) == "table" then
			output = output .. (entries > 1 and ", " or "") .. "[" .. KeyToString(key) .. "] = " .. TableToString(value)
		elseif type(value) == "userdata" then
			if typeof(value) == "Instance" then
				output = output .. (entries > 1 and ", " or "") .. "[" .. KeyToString(key) .. "] = Instance:" .. tostring(value)
			else
				output = output .. (entries > 1 and ", " or "") .. "[" .. KeyToString(key) .. "] = userdata:" .. typeof(value)
			end
		else
			output = output .. (entries > 1 and ", " or "") .. "[" .. KeyToString(key) .. "] = " .. tostring(value)
		end
	end
	output = output .. "}"
	return output
end

local FailCount = 0
local PassCount = 0

local function TestPass(test_txt: string, is_pass: boolean)
	print(PREFIX .. test_txt .. ": " .. (if is_pass == true then "PASS ✅" else "FAIL ❌"))
	if is_pass == true then
		PassCount += 1
	else
		FailCount += 1
	end
end

local function MockUpdateAsync(mock_data_store: {}, store_name: string, profile_key: string, transform_fn: () -> ())
	
	local profile_store = mock_data_store[store_name]
	
	if profile_store == nil then
		profile_store = {}
		mock_data_store[store_name] = profile_store
	end
	
	local transform = transform_fn(profile_store[profile_key])
	
	if transform == nil then
		return nil
	else
		
		local epoch_time = math.floor(os.time() * 1000)
		local mock_entry = profile_store[profile_key]
		
		if mock_entry == nil then
			mock_entry = {
				Data = nil,
				CreatedTime = epoch_time,
				UpdatedTime = epoch_time,
				VersionId = 0,
				UserIds = {},
				MetaData = {},
			}
			profile_store[profile_key] = mock_entry
		end
		
		mock_entry.UpdatedTime = epoch_time
		mock_entry.VersionId += 1
		mock_entry.Data = DeepCopyTable(transform)
		
		return DeepCopyTable(mock_entry.Data)
		
	end
	
end

local function UpdateAsync(store_name: string, profile_key: string, transform_fn: () -> (), is_mock: boolean?)
	if ProfileStore.DataStoreState ~= "Access" or is_mock == true then
		return MockUpdateAsync(
			if is_mock == true then ProfileStore.Test().UserMockStore else ProfileStore.Test().MockStore,
			store_name,
			profile_key,
			transform_fn
		)
	else
		local data_store = DataStoreService:GetDataStore(store_name)
		return data_store:UpdateAsync(profile_key, transform_fn)
	end
end

local function UniqueKey(identifier: any?)
	local guid = tostring(HttpService:GenerateGUID(false))
	guid = string.gsub(guid, "-", "")
	return (if identifier ~= nil then tostring(identifier) .. "_" else "") .. guid
end

local Store1Live
local Store1 = ProfileStore.New(UniqueKey("Store1"), {Counter = 0, Array = {}})

if TEST_MOCK == true then
	
	Store1Live = Store1
	Store1 = Store1.Mock
	
	print(PREFIX .. `Testing ProfileStore in MOCK mode`)
	
end

task.spawn(function()
	
	if ProfileStore.DataStoreState == "NotReady" then
		print(PREFIX .. `Waiting for DataStore API access check`)
		repeat task.wait() until ProfileStore.DataStoreState ~= "NotReady"
	end
	
	local is_api_access = ProfileStore.DataStoreState == "Access"
	
	print(PREFIX .. `Begin...`)

	-- Versioning test:

	if is_api_access == true and TEST_MOCK == false then
		
		-- Due to a change to DataStore versioning on July 2024, this test can only retreive one version
		-- and thus doesn't truly test the feature. ProfileStore versioning was directly ported from ProfileService
		-- versioning which was tested properly before.
		-- SOURCE: https://devforum.roblox.com/t/data-stores-versioning-changes-are-going-live/3093227

		-- Creating several versions for the same key:
		
		local key = "Versioning"

		local profile = Store1:StartSessionAsync(key)
		profile.Data.Gold = 10
		profile:EndSession()

		local payload = Store1:GetAsync(key)
		payload.Data.Gold += 10
		payload:SetAsync()

		local query = Store1:VersionQuery(
			key,
			Enum.SortDirection.Descending,
			nil,
			DateTime.fromUnixTimestamp(os.time() + 10000) -- Future time
		)
		
		local result = query:NextAsync()
		
		local is_pass = result and result.Data.Gold == 20 or false
		
		Store1:RemoveAsync(key)
		
		TestPass(`Versioning test`, is_pass)

	elseif TEST_MOCK == false then
		
		print(PREFIX .. `Skipping versioning test due to no API access`)
		
	end
	
	-- Test profile payloads:
	
	do

		print(PREFIX .. `Payload test ⏳... (Will take around {AUTO_SAVE_PERIOD} seconds)`)

		-- Create profile with some data and a message:
		
		local key = "PayloadTest"

		local profile = Store1:StartSessionAsync(key)
		profile.Data = {
			Coins = 68,
		}
		profile:AddUserId(2312310)
		profile.RobloxMetaData = {Playtime = 123456}
		
		Store1:MessageAsync(key, {GiftType = "SpecialGift"})

		-- We need the profile to be active, and ensure all above data is saved in the DataStore:
		
		profile.OnAfterSave:Wait()

		if #profile.global_updates == 0 then
			error(PREFIX .. `Message was not received`)
		end

		-- Create a profile payload:

		profile.Data.Coins = 1000000 -- The player JUST received tons of cash!!! Payloads can lose up to
		-- several minutes of in-game progress when overwriting. You should use :StartSessionAsync()
		-- even in manual editing if you want to protect live in-game progress.

		local payload = Store1:GetAsync(key)
		payload.Data.Coins += 1
		payload:AddUserId(50)

		local message_received = false
		
		payload:MessageHandler(function(message, is_processed_callback)
			if message.GiftType == "SpecialGift" then
				message_received = true
			end
		end)

		if message_received ~= true then
			error(PREFIX .. `Message was not received in GET profile`)
		end
		
		-- Message clear test:
		
		local a_message_was_cleared = false
		
		payload:MessageHandler(function(message, is_processed_callback) -- A function like this will clear all unprocessed messages
			a_message_was_cleared = true
			is_processed_callback()
		end)
		
		local messages_empty = true
		
		payload:MessageHandler(function()
			messages_empty = false
		end)

		if messages_empty == false or a_message_was_cleared == false then
			error(PREFIX .. `Message clear test fail`)
		end

		payload:SetAsync()

		-- The profile should lose its session lock:

		local start = os.clock()
		local wait_for_profile = true
		
		profile.OnSessionEnd:Connect(function()
			wait_for_profile = false
		end)
		
		while wait_for_profile == true do
			if os.clock() - start > 120 then
				error(PREFIX .. `Session steal by payload timeout`)
			end
			task.wait()
		end

		if profile:IsActive() == true then
			error(PREFIX .. `Faulty :IsActive()`)
		end

		-- Load and check new data:

		profile = Store1:GetAsync(key)

		local key_info = profile.KeyInfo
		local metadata = key_info:GetMetadata()
		local user_ids = key_info:GetUserIds()
		
		local active_messages = 0
		
		profile:MessageHandler(function()
			active_messages += 1
		end)

		local is_passed = profile.Data.Coins == 69
			and metadata.Playtime == 123456 and table.find(user_ids, 2312310) ~= nil
			and table.find(user_ids, 50) ~= nil and active_messages == 0
		
		Store1:RemoveAsync(key)
		
		TestPass(`Payload test`, is_passed)

	end
	
	-- Test KeyInfo:

	do
		
		local key = "KeyInfoTest"

		local profile = Store1:StartSessionAsync(key)
		
		profile.RobloxMetaData = {Color = {0.955, 0, 0}, Dedication = "Veteran"}
		profile:AddUserId(2312310)
		profile:AddUserId(50)
		profile:AddUserId(420)
		profile:RemoveUserId(50)

		profile:EndSession()
		
		profile.OnAfterSave:Wait()

		local key_info = profile.KeyInfo
		local metadata = key_info:GetMetadata()
		local user_ids = key_info:GetUserIds()

		local is_color_good = type(metadata.Color) == "table"
			and metadata.Color[1] == 0.955
			and metadata.Color[2] == 0
			and metadata.Color[3] == 0

		local is_passed = is_color_good == true
			and metadata.Dedication == "Veteran" and table.find(user_ids, 2312310) ~= nil
			and table.find(user_ids, 420) ~= nil and table.find(user_ids, 50) == nil

		if is_api_access == true and profile.is_mock ~= true and type(key_info) == "table" then
			error(PREFIX .. `Mock KeyInfo leak`)
		end
		
		Store1:RemoveAsync(key)

		TestPass(`DataStore KeyInfo (Roblox Metadata) test`, is_passed)

	end
	
	-- Test MOCK:
	
	if TEST_MOCK == true then
		
		local key = UniqueKey("Mock")
		
		local success_mock, error_message = pcall(function()
			local profile_live = Store1:StartSessionAsync(key)
			wait(1)
			local profile_mock = Store1Live:StartSessionAsync(key)
			profile_live:EndSession()
			profile_mock:EndSession()
			Store1:RemoveAsync(key)
			Store1Live:RemoveAsync(key)
		end)
		
		TestPass(`Mock test`, success_mock == true)
		
		if success_mock == false then
			print(`ERROR:`, error_message)
		end
		
	end
	
	-- Message test:

	do
		
		print(PREFIX .. `Message test ⏳... (Will take a few seconds)`)

		local key = UniqueKey(2)

		local profile = Store1:StartSessionAsync(key)

		local message_received_1 = false
		local message_received_2 = false
		local fell_through = false
		
		local processed_names = {}

		profile:MessageHandler(function(message, is_processed_callback)
			
			if message.UpdateTag == "Hello!" then
				message_received_1 = true
				is_processed_callback()
				Store1:MessageAsync(key, {UpdateTag = "Another!"})
			elseif message.UpdateTag == "Another!" then
				message_received_2 = true
				is_processed_callback()
			end
			
			if processed_names[message.UpdateTag] ~= nil then
				error(PREFIX .. `A message was processed too many times`)
			end
			
			processed_names[message.UpdateTag] = true
			
		end)
		
		profile:MessageHandler(function(message)
			if message.UpdateTag == "Hello!" then
				error(PREFIX .. `A message was passed to another handler after confirming processed status`)
			elseif message.UpdateTag == "No!" then
				fell_through = true
			end
		end)
		
		Store1:MessageAsync(key, {UpdateTag = "No!"})
		Store1:MessageAsync(key, {UpdateTag = "Yes!"})
		Store1:MessageAsync(key, {UpdateTag = "Hello!"})
		
		local start = os.clock()
		
		while message_received_1 == false or message_received_2 == false do
			if os.clock() - start > 120 then
				error(PREFIX .. `Message wait timeout`)
			end
			task.wait()
		end

		profile:EndSession()
		
		-- From this point on, checking a profile in any way immediately should result in active 2 messages
		
		local profile_get
		task.spawn(function()
			profile_get = Store1:GetAsync(key)
		end)
		
		profile = Store1:StartSessionAsync(key)
		
		repeat task.wait() until profile_get ~= nil
		
		local active_messages = 0
		local active_messages_get = 0

		profile:MessageHandler(function()
			active_messages += 1
		end)
		
		profile_get:MessageHandler(function()
			active_messages_get += 1
		end)
		
		profile:EndSession()
		
		-- Check message removal through payload:
		
		local payload = Store1:GetAsync(key)
		
		payload:MessageHandler(function(message, is_processed_callback)
			is_processed_callback()
		end)
		
		payload:SetAsync()
		
		profile = Store1:StartSessionAsync(key)
		
		local active_messages_after_clear = 0
		
		payload:MessageHandler(function(message, is_processed_callback)
			active_messages_after_clear += 1
		end)
		
		profile:EndSession()
		Store1:RemoveAsync(key)

		TestPass(`Message test`, active_messages == 2 and active_messages_get == 2 and fell_through == true and active_messages_after_clear == 0)

	end
	
	-- LastSavedData test: 

	do
		
		print(PREFIX .. `LastSavedData test ⏳... (Will take around {AUTO_SAVE_PERIOD} seconds)`)

		local key = UniqueKey("LastSaved")

		local profile = Store1:StartSessionAsync(key)
		profile.Data.LoadedFirstTime = true
		profile.Data.PurchaseIds = {}
		table.insert(profile.Data.PurchaseIds, "a")
		
		local initial_check = profile.LastSavedData ~= profile.Data

		profile.OnAfterSave:Wait()
		
		local is_pass = initial_check and profile.LastSavedData ~= profile.Data
			and profile.LastSavedData.LoadedFirstTime == true
			and profile.LastSavedData.PurchaseIds ~= nil
			and profile.LastSavedData.PurchaseIds[1] == "a"
		
		profile:EndSession()
		Store1:RemoveAsync(key)

		TestPass("LastSavedData test", is_pass)

	end
	
	-- .OnOverwrite test:

	do

		print(PREFIX .. `.OnOverwrite test ⏳... (Will take around {AUTO_SAVE_PERIOD} seconds)`)

		local key = UniqueKey("Overwrite")

		local signal_received = false

		ProfileStore.OnOverwrite:Connect(function(store_name, profile_key)
			if store_name == Store1.Name and profile_key == key then
				signal_received = true
			end
		end)

		UpdateAsync(Store1.Name, key, function() -- Injecting data that doesn't match the DataStore internal schema
			return {"ThisAintRight"}
		end, TEST_MOCK)

		local profile = Store1:StartSessionAsync(key)
		profile:EndSession()
		Store1:RemoveAsync(key)

		TestPass(`.OnOverwrite test`, signal_received == true)

	end
	
	-- Test #1: (Rapid consecutive session start-end and profile removal)
	
	do
		
		local key = UniqueKey(1)
	
		for i = 1, 2 do
			local profile = Store1:StartSessionAsync(key)
			profile.Data.Counter = profile.Data.Counter and profile.Data.Counter + 1 or 1
			profile:EndSession()
		end
		
		local profile_get1 = Store1:GetAsync(key)
		Store1:RemoveAsync(key)
		local profile_get2 = Store1:GetAsync(key)
		
		TestPass(`Test #1`, profile_get1.Data.Counter == 2 and profile_get2 == nil)
		
	end
	
	-- Test #2: (Other types of repeat session starts)
	
	do
		
		local key = UniqueKey(2)
	
		local profile

		local success = pcall(function() -- Should fail
			profile = Store1:StartSessionAsync(key) -- This should succeed
			profile = Store1:StartSessionAsync(key) -- This should error
		end)
		
		profile:EndSession()

		local success_2 = pcall(function()
			profile = Store1:StartSessionAsync(key)
			profile:EndSession()
			profile = Store1:StartSessionAsync(key)
		end)
		
		profile:EndSession()
		Store1:RemoveAsync(key)
		
		TestPass(`Test #2`, success == false and success_2 == true)
		
	end
	
	-- Test #3: (Session start grabbing)
	
	do
		
		local key = UniqueKey(3)
		
		local profiles = {}
		
		-- If :StartSessionAsync() is called several times quickly, only the last call should
		-- receive the profile reference and others should return nil without throwing an error.
		-- This is to prevent race conditions where a user might rejoin faster than the first
		-- session manages to start.
		
		for i = 1, 3 do
			task.spawn(function()
				profiles[i] = Store1:StartSessionAsync(key) or 0
			end)
		end

		while profiles[1] == nil or profiles[2] == nil or profiles[3] == nil do
			wait()
		end
		
		profiles[3]:EndSession()
		Store1:RemoveAsync(key)

		TestPass(`Test #3`, profiles[1] == 0 and profiles[2] == 0 and type(profiles[3]) == "table")
		
	end
	
	-- Test #4: (External session steal simulation)
	
	do
	
		print(PREFIX .. `Test #4 ⏳... (Will take around {AUTO_SAVE_PERIOD} seconds)`)
		
		local key = UniqueKey(4)
		
		local profile = Store1:StartSessionAsync(key)
		
		UpdateAsync(Store1.Name, key, function() -- "Stealing" profile through injection
			return {
				Data = {},
				MetaData = {
					ProfileCreateTime = 0,
					SessionLoadCount = 0,
					ActiveSession = {123, 123},
					ForceLoadSession = nil,
					MetaTags = {},
				},
				GlobalUpdates = {0, {}},
			}
		end, TEST_MOCK)
		
		local start = os.clock()

		while profile:IsActive() == true do
			if os.clock() - start > 120 then
				error(PREFIX .. `Steal wait timeout`)
			end
			task.wait()
		end
		
		Store1:RemoveAsync(key)
		
		TestPass(`Test #4`, true)
		
	end
	
	-- Test #5: (Session swap between servers simulation)
	
	do
		
		print(PREFIX .. `Test #5 ⏳... (Will take around {AUTO_SAVE_PERIOD} seconds)`)
		
		local key = UniqueKey(5)
		
		local profile = Store1:StartSessionAsync(key)
		
		UpdateAsync(Store1.Name, key, function(data) -- Injecting profile table with force load request
			return {
				Data = {},
				MetaData = {
					ProfileCreateTime = 0,
					SessionLoadCount = 0,
					ActiveSession = data.MetaData.ActiveSession,
					ForceLoadSession = {123, 123},
					MetaTags = {},
				},
				GlobalUpdates = {0, {}},
			}
		end, TEST_MOCK)
		
		local start = os.clock()

		while profile:IsActive() == true do
			if os.clock() - start > 120 then
				error(PREFIX .. `Session swap wait timeout`)
			end
			task.wait()
		end
		
		Store1:RemoveAsync(key)

		TestPass(`Test #5`, true)
		
	end
	
	-- Test #6: (Templates and reconciliation)
	
	do
		
		local key = UniqueKey(6)
		
		local profile = Store1:StartSessionAsync(key)
		profile.Data = {Array = false}
		profile:Reconcile()
		
		local is_pass = profile.Data.Counter == 0 and profile.Data.Array == false
		
		profile:EndSession()
		Store1:RemoveAsync(key)
		
		TestPass(`Test #6`, is_pass)
		
	end

	-- Test #7: (utf8 character test)
	
	do
		
		local bad_keys = {
			"Hello World",
			"\237\190\140",
			"\xED\xA0\x80\xED\xB0\x80",
			"Hello World\255",
			"\237\190\140Hello World\237\190\140",
			"\xED\xA0\x80\xED\xB0\x80Hello World\xED\xA0\x80\xED\xB0\x80",
			-- Borrowed word sample
			"ï",
			"Hello Worldï",
			-- Hiragana sample
			"女",
			"Hello World女",
			-- Chinese sample
			"我",
			"Hello World我",
			-- Surrogate
			"\237\190\140Hello Worldï",
			"\237\190\140Hello World女",
			"\237\190\140Hello World我",
			-- Surrogate
			"\xED\xA0\x80\xED\xB0\x80Hello Worldï",
			"\xED\xA0\x80\xED\xB0\x80Hello World女",
			"\xED\xA0\x80\xED\xB0\x80Hello World我",
			-- Emojis
			"😀 😃 😄 😁 😆 😅 😂 🤣 🥲 🥹 ☺️ 😊 😇 🙂 🙃 😉 😌 😍 🥰 😘 😗 😙 😚 😋 😛 😝 😜 🤪 🤨 🧐 🤓 😎 🥸 🤩 🥳 😏 😒 😞 😔 😟 😕 🙁 ☹️ 😣 😖 😫 😩 🥺 😢 😭 😮‍💨 😤 😠 😡 🤬 🤯 😳 🥵 🥶 😱 😨 😰 😥 😓 🫣 🤗 🫡 🤔 🫢 🤭 🤫 🤥 😶 😶‍🌫️ 😐 😑 😬 🫨 🫠 🙄 😯 😦 😧 😮 😲 🥱 😴 🤤 😪 😵 😵‍💫 🫥 🤐 🥴 🤢 🤮 🤧 😷 🤒 🤕 🤑 🤠 😈 👿 👹 👺 🤡 💩 👻 💀 ☠️ 👽 👾 🤖 🎃 😺 😸 😹 😻 😼 😽 🙀 😿 😾 ",
			-- Hiragana
			[[あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん]],
			-- Katakana
			[[アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン]],
			-- Russian
			[[АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯбвгдеёжзийклмнопрстуфхцчшщъыьэюя]],
			-- Arabic 
			-- abjadī
			[[أبجدهوزحطيكلمنسعفصقرشتثخذضظغ]],
			-- hijāʾī
			[[ابتثجحخدذرزسشصضطظعغفقكلمنهوي]],
			-- Greek
			[[ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩαβγδεζηθικλμνξοπρστυφχψω]],
			-- Egyptian hieroglyphics
			[[𓀀 𓀁 𓀂 𓀃 𓀄 𓀅 𓀆 𓀇 𓀈 𓀉 𓀊 𓀋 𓀌 𓀍 𓀎 𓀏 𓀐 𓀑 𓀒 𓀓 𓀔 𓀕 𓀖 𓀗 𓀘 𓀙 𓀚 𓀛 𓀜 𓀝 𓀞 𓀟 𓀠 𓀡 𓀢 𓀣 𓀤 𓀥 𓀦 𓀧 𓀨 𓀩 𓀪 𓀫 𓀬 𓀭 𓀮 𓀯 𓀰 𓀱 𓀲 𓀳 𓀴 𓀵 𓀶 𓀷 𓀸 𓀹 𓀺 𓀻 𓀼 𓀽 𓀾 𓀿 𓁀 𓁁 𓁂 𓁃 𓁄 𓁅 𓁆 𓁇 𓁈 𓁉 𓁊 𓁋 𓁌 𓁍 𓁎 𓁏 𓁐 𓁑 𓁒 𓁓 𓁔 𓁕 𓁖 𓁗 𓁘 𓁙 𓁚 𓁛 𓁜 𓁝 𓁞 𓁟 𓁠 𓁡 𓁢 𓁣 𓁤 𓁥 𓁦 𓁧 𓁨 𓁩 𓁪 𓁫 𓁬 𓁭 𓁮 𓁯 𓁰 𓁱 𓁲 𓁳 𓁴 𓁵 𓁶 𓁷 𓁸 𓁹 𓁺 𓁻 𓁼 𓁽 𓁾 𓁿 𓂀 𓂁 𓂂 𓂃 𓂄 𓂅 𓂆 𓂇 𓂈 𓂉 𓂊 𓂋 𓂌 𓂍 𓂎 𓂏 𓂐 𓂑 𓂒 𓂓 𓂔 𓂕 𓂖 𓂗 𓂘 𓂙 𓂚 𓂛 𓂜 𓂝 𓂞 𓂟 𓂠 𓂡 𓂢 𓂣 𓂤 𓂥 𓂦 𓂧 𓂨 𓂩 𓂪 𓂫 𓂬 𓂭 𓂮 𓂯 𓂰 𓂱 𓂲 𓂳 𓂴 𓂵 𓂶 𓂷 𓂸 𓂹 𓂺 𓂻 𓂼 𓂽 𓂾 𓂿 𓃀 𓃁 𓃂 𓃃 𓃄 𓃅 𓃆 𓃇 𓃈 𓃉 𓃊 𓃋 𓃌 𓃍 𓃎 𓃏 𓃐 𓃑 𓃒 𓃓 𓃔 𓃕 𓃖 𓃗 𓃘 𓃙 𓃚 𓃛 𓃜 𓃝 𓃞 𓃟 𓃠 𓃡 𓃢 𓃣 𓃤 𓃥 𓃦 𓃧 𓃨 𓃩 𓃪 𓃫 𓃬 𓃭 𓃮 𓃯 𓃰 𓃱 𓃲 𓃳 𓃴 𓃵 𓃶 𓃷 𓃸 𓃹 𓃺 𓃻 𓃼 𓃽 𓃾 𓃿 𓄀 𓄁 𓄂 𓄃 𓄄 𓄅 𓄆 𓄇 𓄈 𓄉 𓄊 𓄋 𓄌 𓄍 𓄎 𓄏 𓄐 𓄑 𓄒 𓄓 𓄔 𓄕 𓄖 𓄗 𓄘 𓄙 𓄚 𓄛 𓄜 𓄝 𓄞 𓄟 𓄠 𓄡 𓄢 𓄣 𓄤 𓄥 𓄦 𓄧 𓄨 𓄩 𓄪 𓄫 𓄬 𓄭 𓄮 𓄯 𓄰 𓄱 𓄲 𓄳 𓄴 𓄵 𓄶 𓄷 𓄸 𓄹 𓄺 𓄻 𓄼 𓄽 𓄾 𓄿 𓅀 𓅁 𓅂 𓅃 𓅄 𓅅 𓅆 𓅇 𓅈 𓅉 𓅊 𓅋 𓅌 𓅍 𓅎 𓅏 𓅐 𓅑 𓅒 𓅓 𓅔 𓅕 𓅖 𓅗 𓅘 𓅙 𓅚 𓅛 𓅜 𓅝 𓅞 𓅟 𓅠 𓅡 𓅢 𓅣 𓅤 𓅥 𓅦 𓅧 𓅨 𓅩 𓅪 𓅫 𓅬 𓅭 𓅮 𓅯 𓅰 𓅱 𓅲 𓅳 𓅴 𓅵 𓅶 𓅷 𓅸 𓅹 𓅺 𓅻 𓅼 𓅽 𓅾 𓅿 𓆀 𓆁 𓆂 𓆃 𓆄 𓆅 𓆆 𓆇 𓆈 𓆉 𓆊 𓆋 𓆌 𓆍 𓆎 𓆏 𓆐 𓆑 𓆒 𓆓 𓆔 𓆕 𓆖 𓆗 𓆘 𓆙 𓆚 𓆛 𓆜 𓆝 𓆞 𓆟 𓆠 𓆡 𓆢 𓆣 𓆤 𓆥 𓆦 𓆧 𓆨 𓆩 𓆪 𓆫 𓆬 𓆭 𓆮 𓆯 𓆰 𓆱 𓆲 𓆳 𓆴 𓆵 𓆶 𓆷 𓆸 𓆹 𓆺 𓆻 𓆼 𓆽 𓆾 𓆿 𓇀 𓇁 𓇂 𓇃 𓇄 𓇅 𓇆 𓇇 𓇈 𓇉 𓇊 𓇋 𓇌 𓇍 𓇎 𓇏 𓇐 𓇑 𓇒 𓇓 𓇔 𓇕 𓇖 𓇗 𓇘 𓇙 𓇚 𓇛 𓇜 𓇝 𓇞 𓇟 𓇠 𓇡 𓇢 𓇣 𓇤 𓇥 𓇦 𓇧 𓇨 𓇩 𓇪 𓇫 𓇬 𓇭 𓇮 𓇯 𓇰 𓇱 𓇲 𓇳 𓇴 𓇵 𓇶 𓇷 𓇸 𓇹 𓇺 𓇻 𓇼 𓇽 𓇾 𓇿 𓈀 𓈁 𓈂 𓈃 𓈄 𓈅 𓈆 𓈇 𓈈 𓈉 𓈊 𓈋 𓈌 𓈍 𓈎 𓈏 𓈐 𓈑 𓈒 𓈓 𓈔 𓈕 𓈖 𓈗 𓈘 𓈙 𓈚 𓈛 𓈜 𓈝 𓈞 𓈟 𓈠 𓈡 𓈢 𓈣 𓈤 𓈥 𓈦 𓈧 𓈨 𓈩 𓈪 𓈫 𓈬 𓈭 𓈮 𓈯 𓈰 𓈱 𓈲 𓈳 𓈴 𓈵 𓈶 𓈷 𓈸 𓈹 𓈺 𓈻 𓈼 𓈽 𓈾 𓈿 𓉀 𓉁 𓉂 𓉃 𓉄 𓉅 𓉆 𓉇 𓉈 𓉉 𓉊 𓉋 𓉌 𓉍 𓉎 𓉏 𓉐 𓉑 𓉒 𓉓 𓉔 𓉕 𓉖 𓉗 𓉘 𓉙 𓉚 𓉛 𓉜 𓉝 𓉞 𓉟 𓉠 𓉡 𓉢 𓉣 𓉤 𓉥 𓉦 𓉧 𓉨 𓉩 𓉪 𓉫 𓉬 𓉭 𓉮 𓉯 𓉰 𓉱 𓉲 𓉳 𓉴 𓉵 𓉶 𓉷 𓉸 𓉹 𓉺 𓉻 𓉼 𓉽 𓉾 𓉿 𓊀 𓊁 𓊂 𓊃 𓊄 𓊅 𓊆 𓊇 𓊈 𓊉 𓊊 𓊋 𓊌 𓊍 𓊎 𓊏 𓊐 𓊑 𓊒 𓊓 𓊔 𓊕 𓊖 𓊗 𓊘 𓊙 𓊚 𓊛 𓊜 𓊝 𓊞 𓊟 𓊠 𓊡 𓊢 𓊣 𓊤 𓊥 𓊦 𓊧 𓊨 𓊩 𓊪 𓊫 𓊬 𓊭 𓊮 𓊯 𓊰 𓊱 𓊲 𓊳 𓊴 𓊵 𓊶 𓊷 𓊸 𓊹 𓊺 𓊻 𓊼 𓊽 𓊾 𓊿 𓋀 𓋁 𓋂 𓋃 𓋄 𓋅 𓋆 𓋇 𓋈 𓋉 𓋊 𓋋 𓋌 𓋍 𓋎 𓋏 𓋐 𓋑 𓋒 𓋓 𓋔 𓋕 𓋖 𓋗 𓋘 𓋙 𓋚 𓋛 𓋜 𓋝 𓋞 𓋟 𓋠 𓋡 𓋢 𓋣 𓋤 𓋥 𓋦 𓋧 𓋨 𓋩 𓋪 𓋫 𓋬 𓋭 𓋮 𓋯 𓋰 𓋱 𓋲 𓋳 𓋴 𓋵 𓋶 𓋷 𓋸 𓋹 𓋺 𓋻 𓋼 𓋽 𓋾 𓋿 𓌀 𓌁 𓌂 𓌃 𓌄 𓌅 𓌆 𓌇 𓌈 𓌉 𓌊 𓌋 𓌌 𓌍 𓌎 𓌏 𓌐 𓌑 𓌒 𓌓 𓌔 𓌕 𓌖 𓌗 𓌘 𓌙 𓌚 𓌛 𓌜 𓌝 𓌞 𓌟 𓌠 𓌡 𓌢 𓌣 𓌤 𓌥 𓌦 𓌧 𓌨 𓌩 𓌪 𓌫 𓌬 𓌭 𓌮 𓌯 𓌰 𓌱 𓌲 𓌳 𓌴 𓌵 𓌶 𓌷 𓌸 𓌹 𓌺 𓌻 𓌼 𓌽 𓌾 𓌿 𓍀 𓍁 𓍂 𓍃 𓍄 𓍅 𓍆 𓍇 𓍈 𓍉 𓍊 𓍋 𓍌 𓍍 𓍎 𓍏 𓍐 𓍑 𓍒 𓍓 𓍔 𓍕 𓍖 𓍗 𓍘 𓍙 𓍚 𓍛 𓍜 𓍝 𓍞 𓍟 𓍠 𓍡 𓍢 𓍣 𓍤 𓍥 𓍦 𓍧 𓍨 𓍩 𓍪 𓍫 𓍬 𓍭 𓍮 𓍯 𓍰 𓍱 𓍲 𓍳 𓍴 𓍵 𓍶 𓍷 𓍸 𓍹 𓍺 𓍻 𓍼 𓍽 𓍾 𓍿 𓎀 𓎁 𓎂 𓎃 𓎄 𓎅 𓎆 𓎇 𓎈 𓎉 𓎊 𓎋 𓎌 𓎍 𓎎 𓎏 𓎐 𓎑 𓎒 𓎓 𓎔 𓎕 𓎖 𓎗 𓎘 𓎙 𓎚 𓎛 𓎜 𓎝 𓎞 𓎟 𓎠 𓎡 𓎢 𓎣 𓎤 𓎥 𓎦 𓎧 𓎨 𓎩 𓎪 𓎫 𓎬 𓎭 𓎮 𓎯 𓎰 𓎱 𓎲 𓎳 𓎴 𓎵 𓎶 𓎷 𓎸 𓎹 𓎺 𓎻 𓎼 𓎽 𓎾 𓎿 𓏀 𓏁 𓏂 𓏃 𓏄 𓏅 𓏆 𓏇 𓏈 𓏉 𓏊 𓏋 𓏌 𓏍 𓏎 𓏏 𓏐 𓏑 𓏒 𓏓 𓏔 𓏕 𓏖 𓏗 𓏘 𓏙 𓏚 𓏛 𓏜 𓏝 𓏞 𓏟 𓏠 𓏡 𓏢 𓏣 𓏤 𓏥 𓏦 𓏧 𓏨 𓏩 𓏪 𓏫 𓏬 𓏭 𓏮 𓏯 𓏰 𓏱 𓏲 𓏳 𓏴 𓏵 𓏶 𓏷 𓏸 𓏹 𓏺 𓏻 𓏼 𓏽 𓏾 𓏿 𓐀 𓐁 𓐂 𓐃 𓐄 𓐅 𓐆 𓐇 𓐈 𓐉 𓐊 𓐋 𓐌 𓐍 𓐎 𓐏 𓐐 𓐑 𓐒 𓐓 𓐔 𓐕 𓐖 𓐗 𓐘 𓐙 𓐚 𓐛 𓐜 𓐝 𓐞 𓐟]],
		}
		for i = 1, 255 do 
			local char = string.char(i)
			bad_keys[char] = char
		end
		
		print(PREFIX .. `UTF-8 test ⏳... (Will take around {AUTO_SAVE_PERIOD} seconds)`)
		
		local key = UniqueKey(7)
		
		local profile = Store1:StartSessionAsync(key)
		for _, bad_key in bad_keys do
			profile.Data[bad_key] = bad_key
		end

		profile.OnAfterSave:Wait()

		--/Verify if the data is valid
		local function verify_json(str: string): boolean
			return (pcall(game:GetService("HttpService").JSONEncode, game:GetService("HttpService"), str))
		end

		--/Check if the data is valid
		local is_pass = true
		for cleaned_key, cleaned_value in pairs(profile.Data) do

			--/Make sure the key and value are valid
			if (typeof(cleaned_key) == "string" and not verify_json(cleaned_key)) or (typeof(cleaned_value) == "string" and not verify_json(cleaned_value)) then
				is_pass = false
			end
			
		end

		profile:EndSession()

		TestPass(`UTF-8 test`, is_pass)
		
	end
	
	-- Cache test:
	
	do
		
		task.wait(3)
		
		local test = ProfileStore.Test()
		
		local is_pass = next(test.ActiveSessionCheck) == nil
			and #test.AutoSaveList == 0
			and test.ActiveProfileLoadJobs == 0
			and test.ActiveProfileSaveJobs == 0
			and next(test.MockStore) == nil
			and next(test.UserMockStore) == nil
			and next(test.UpdateQueue) == nil
			
		TestPass(`Cache test`, is_pass)
		
		if is_pass == false then
			print(test)
		end
		
	end
	
	-- Summary:
	
	print(PREFIX .. `Test complete! PASS ✅ = {PassCount}; FAIL ❌ = {FailCount}`)
	
	if FailCount == 0 then
		print(PREFIX .. `Test PASSED ✅✅✅!`)
	else
		print(PREFIX .. `Test FAILED ❌❌❌!`)
	end

end)