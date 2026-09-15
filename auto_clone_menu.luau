local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
pcall(function()
    local oldStatus = LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("AutoCloneStatus")
    if oldStatus then
        oldStatus:Destroy()
    end
    local oldDungeonMap = LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("AutoDungeonMap")
    if oldDungeonMap then
        oldDungeonMap:Destroy()
    end
end)
local globalEnv = getgenv()
globalEnv.__afs_build = 14
globalEnv.__auto_clone_state = globalEnv.__auto_clone_state or {generation = 0}
local persistentState = globalEnv.__auto_clone_state
persistentState.generation = (persistentState.generation or 0) + 1
local runtimeGeneration = persistentState.generation
globalEnv.__AC_GENERATION = (globalEnv.__AC_GENERATION or 0) + 1
local legacyGeneration = globalEnv.__AC_GENERATION

local function alive()
    return persistentState.generation == runtimeGeneration
        and globalEnv.__AC_GENERATION == legacyGeneration
end

-- Teardown lan execute truoc: disconnect game connections cu + destroy
-- WindUI window cu dung cach. Chi xoa con GUI se de lai ToggleKey handler
-- (RightShift) va connections song song -> bam RightShift crash khi
-- execute script 2 lan lien tiep.
-- (Dung globalEnv/Feature thay vi local moi de tranh tran registers main chunk.)
globalEnv.__afs_teardownPrevious = function()
    globalEnv.__afs_connections = globalEnv.__afs_connections or {}
    for _, conn in ipairs(globalEnv.__afs_connections) do
        pcall(function()
            conn:Disconnect()
        end)
    end
    globalEnv.__afs_connections = {}
    if globalEnv.__afs_window then
        pcall(function()
            globalEnv.__afs_window:Destroy()
        end)
        globalEnv.__afs_window = nil
    end
end
globalEnv.__afs_teardownPrevious()
globalEnv.__afs_trackConnection = function(conn)
    globalEnv.__afs_connections = globalEnv.__afs_connections or {}
    table.insert(globalEnv.__afs_connections, conn)
    return conn
end

local function safeNotify(WindUI, title, content)
    pcall(function()
        WindUI:Notify({
            Title = title,
            Content = content,
            Duration = 4,
            Icon = "info"
        })
    end)
end

local function getUIRoot()
    local ok, root = pcall(function()
        local coreGui = game:GetService("CoreGui")
        return coreGui:FindFirstChild("RobloxGui") or coreGui
    end)
    return ok and root or nil
end

local function cleanupOldWindUI()
    pcall(function()
        local hui = getUIRoot()
        if not hui then
            return
        end
        for _, child in ipairs(hui:GetChildren()) do
            if child.Name == "WindUI" or string.sub(child.Name, 1, 7) == "WindUI/" then
                child:Destroy()
            end
        end
    end)
end

cleanupOldWindUI()

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
pcall(function()
    WindUI:SetNotificationLower(true)
end)
pcall(function()
    WindUI:SetParent(getUIRoot())
end)

local Window = WindUI:CreateWindow({
    Title = "AFS",
    Icon = "refresh-cw",
    Author = "Auto Farm Suite",
    Folder = "CloneAutomation",
    Size = UDim2.fromOffset(760, 560),
    MinSize = Vector2.new(620, 420),
    MaxSize = Vector2.new(980, 720),
    Theme = "Dark",
    Resizable = true,
    HideSearchBar = true,
    ToggleKey = Enum.KeyCode.RightShift
})

globalEnv.__afs_window = Window

local MainTab = Window:Tab({
    Title = "Main",
    Icon = "home"
})

local CloneTab = Window:Tab({
    Title = "Auto Clone",
    Icon = "copy"
})

local FarmTab = Window:Tab({
    Title = "Auto Farm",
    Icon = "target"
})

local StatusTab = Window:Tab({
    Title = "Machine Status",
    Icon = "clock-3"
})

local SettingsTab = Window:Tab({
    Title = "Settings",
    Icon = "settings"
})

local DungeonTab = Window:Tab({
    Title = "Auto Dungeon",
    Icon = "swords"
})

local AutoPassiveTab = Window:Tab({
    Title = "Auto Passive",
    Icon = "sparkles"
})

globalEnv.__afs_fallenStarTab = Window:Tab({
    Title = "Fallen Star",
    Icon = "star"
})

local LocalDairebStore = require(ReplicatedStorage.ModuleScripts.LocalDairebStore)
LocalDairebStore.WaitForInit()
local Store = LocalDairebStore.GetStoreProxy("GameData")
local PetStats = require(ReplicatedStorage.ModuleScripts.PetStats)
local PassiveStats = require(ReplicatedStorage.ModuleScripts.PassiveStats)
local AutoPassiveModules = {
    PassiveCategories = require(ReplicatedStorage.ModuleScripts.PassiveCategories),
    PassiveAmount = require(ReplicatedStorage.ModuleScripts.PassiveAmount),
    MarketplaceHandler = require(ReplicatedStorage.ModuleScripts.MarketplaceHandler)
}
local GetMultiplier = require(ReplicatedStorage.ModuleScripts.GetMultiplier)
local WorldData = require(ReplicatedStorage.ModuleScripts.WorldData)
local ArtefactData = require(ReplicatedStorage.ModuleScripts.ArtefactData)
local ConfigValues = require(ReplicatedStorage.ModuleScripts.ConfigValues)

local Remote = ReplicatedStorage:WaitForChild("Remote")
local AttemptClone = Remote:WaitForChild("AttemptClone")
local AttemptWithdraw = Remote:WaitForChild("AttemptWithdrawCloneMachine")
local AttemptTravel = Remote:WaitForChild("AttemptTravel")
local SummonDungeon = Remote:WaitForChild("SummonDungeon")
local SetDungeonSetting = Remote:WaitForChild("SetDungeonSetting")
local ManagePet = Remote:WaitForChild("ManagePet")
local ChangeTitle = Remote:WaitForChild("ChangeTitle")
local AttemptAvatarEquip = Remote:WaitForChild("AttemptAvatarEquip")
local EquipAura = Remote:WaitForChild("EquipAura")
local EquipArtefact = Remote:WaitForChild("EquipArtefact")
local DungeonFinish = Remote:WaitForChild("DungeonFinish")
local Bindable = ReplicatedStorage:WaitForChild("Bindable")
local GlobalTime = ReplicatedStorage:WaitForChild("Misc"):WaitForChild("GlobalTime")
local ConfigPath = "AutoClone/config.json"
local RuntimeLogPath = "AutoClone/runtime.log"

local function readValue(instance, fallback)
    if not instance then
        return fallback
    end
    local ok, value = pcall(function()
        return instance.Value
    end)
    if ok and value ~= nil then
        return value
    end
    return fallback
end

local function getPlayerValue(name, fallback)
    local ok, value = pcall(function()
        local object = LocalPlayer and LocalPlayer:FindFirstChild(name)
        return object and object.Value
    end)
    if ok and value ~= nil then
        return value
    end
    return fallback
end

local function getGameTime()
    return tonumber(readValue(GlobalTime, 0)) or 0
end

local function getStoreValue(key, authoritative, fallback)
    local ok, value = pcall(function()
        if authoritative == nil then
            return Store:GetData(key)
        end
        return Store:GetData(key, authoritative)
    end)
    if ok then
        return value
    end
    return fallback
end

local function getStoreTable(key, authoritative)
    local value = getStoreValue(key, authoritative, nil)
    return type(value) == "table" and value or {}
end

local function setStoreValue(key, value, ttl)
    local ok, err = pcall(function()
        Store:SetLocalData(key, value, ttl)
    end)
    if not ok then
        warn("[AutoClone] SetLocalData failed for " .. tostring(key) .. ": " .. tostring(err))
    end
    return ok
end

local function safeSetThreadIdentity(identity)
    if type(setthreadidentity) ~= "function" then
        return true
    end
    local ok = pcall(setthreadidentity, identity)
    return ok
end

local function fileExists(path)
    if type(isfile) == "function" then
        local ok, result = pcall(isfile, path)
        return ok and result == true
    end
    if type(readfile) == "function" then
        local ok = pcall(readfile, path)
        return ok
    end
    return false
end

local function ensureConfigFolder()
    if type(makefolder) == "function" then
        pcall(makefolder, "AutoClone")
    end
    if type(isfolder) == "function" then
        local ok, exists = pcall(isfolder, "AutoClone")
        if ok and not exists then
            return false, "Khong tao duoc thu muc AutoClone."
        end
    end
    return true
end

local function encodeJson(value)
    if type(json) == "table" and type(json.encode) == "function" then
        local ok, result = pcall(function()
            return json.encode(value)
        end)
        if ok then
            return result
        end
    end
    return HttpService:JSONEncode(value)
end

local function decodeJson(value)
    if type(json) == "table" and type(json.decode) == "function" then
        local ok, result = pcall(function()
            return json.decode(value)
        end)
        if ok then
            return result
        end
    end
    return HttpService:JSONDecode(value)
end

local function utf8Text(fallback, ...)
    local codepoints = {...}
    local ok, result = pcall(function()
        if utf8 and type(utf8.char) == "function" then
            return utf8.char(table.unpack(codepoints))
        end
        return fallback
    end)
    return ok and result or fallback
end

local RarityHours = {
    Common = 0.25,
    Rare = 1,
    Epic = 3,
    Legendary = 5,
    Mythical = 8,
    Raid = 12,
    Secret = 16,
    Divine = 24,
    Special = 24
}

local OccupiedDataKeys = {
    "CloneMachineData",
    "IncubatorData",
    "VoidMachineData",
    "EvolveMachineData",
    "InfuserMachineData",
    "DupeMachineData"
}

local machineList = {}
local machineById = {}
local selectedUID = {}
local petByUID = {}
local optionToUID = {}
local optionByUID = {}
local petDropdown
local autoEnabled = false
local Feature = {
    autoCollectDropsEnabled = false,
    autoCollectDropsToggle = nil,
    autoCollectDropsToggleUpdating = false,
    tpPetEnabled = false,
    tpPetToggle = nil,
    tpPetToggleUpdating = false,
    attackWhileUltEnabled = false,
    attackWhileUltToggle = nil,
    attackWhileUltToggleUpdating = false,
    attackWhileUltLastFire = setmetatable({}, {__mode = "k"}),
    attackWhileUltLastScan = 0,
    mainStatusParagraph = nil,
    mainStatusLastUpdate = 0,
    mainSeenDrops = setmetatable({}, {__mode = "k"}),
    autoCloneToggle = nil,
    autoCloneToggleUpdating = false,
    autoFarmEnabled = false,
    autoFarmMode = "nearest",
    autoFarmTarget = nil,
    autoFarmLastSend = 0,
    autoFarmToggle = nil,
    autoFarmModeDropdown = nil,
    autoFarmStatusParagraph = nil,
    autoFarmToggleUpdating = false,
    autoFallenStarEnabled = false,
    autoFallenStarToggle = nil,
    autoFallenStarToggleUpdating = false,
    autoFallenStarIntervalSlider = nil,
    autoFallenStarTeamDropdown = nil,
    autoFallenStarStatusParagraph = nil,
    autoFallenStarInterval = 1,
    autoPassiveEnabled = false,
    autoPassiveToggle = nil,
    autoPassiveToggleUpdating = false,
    autoPassivePetDropdown = nil,
    autoPassiveTargetDropdown = nil,
    autoPassiveRarityDropdown = nil,
    autoPassiveKeepModeDropdown = nil,
    autoPassiveCurrencyDropdown = nil,
    autoPassiveCategoryDropdown = nil,
    autoPassiveSlotDropdown = nil,
    autoPassiveRollDelaySlider = nil,
    autoPassiveStatusParagraph = nil,
    autoPassiveSelectedUID = {},
    autoPassiveTargetPassives = {},
    autoPassiveTargetRarities = {},
    autoPassiveKeepMode = "passive",
    autoPassiveCurrency = "token",
    autoPassiveCategory = "",
    autoPassiveSlot = 1,
    autoPassiveRollDelayMin = 0.1,
    autoPassiveRollDelayMax = 2,
    autoPassiveRollDelayDefault = 0.3,
    autoPassiveRollDelay = 0.3,
    autoPassiveRunToken = 0,
    autoPassiveBusy = false,
    autoPassiveRollCount = 0,
    autoPassiveLastMessage = "Chua chay.",
    autoPassivePendingPets = nil,
    rebuildAutoPassivePetDropdown = nil,
    getAutoPassivePetRecords = nil,
    syncAutoPassiveControls = nil,
    updateAutoPassiveStatus = nil,
    autoDungeonEnabled = false,
    savedFeatureState = {},
    restoringFeatureState = false,
    syncControls = nil,
    applySavedState = nil,
    MODE_NEAREST = "nearest",
    MODE_LOWEST_HEALTH = "lowest_health",
    MODE_HIGHEST_HEALTH = "highest_health"
}
local AutoPassive = {}
Feature.passiveRarityOrder = {
    Common = 1,
    Rare = 2,
    Epic = 3,
    Legendary = 4,
    Mythical = 5,
    Secret = 6,
    Divine = 7
}

function AutoPassive.normalizeRollDelay(value)
    local delay = tonumber(value) or Feature.autoPassiveRollDelayDefault
    if delay < Feature.autoPassiveRollDelayMin then
        delay = Feature.autoPassiveRollDelayMin
    elseif delay > Feature.autoPassiveRollDelayMax then
        delay = Feature.autoPassiveRollDelayMax
    end
    return math.floor(delay * 10 + 0.5) / 10
end
local lastAction = {}
local initialLocation
local travelBusy = false
local statusParagraph
local infoParagraph
local selectedParagraph
local occupiedParagraph
local statusGui
local statusFrame
local statusTitle
local statusSummary
local machineStatusLabels = {}
local dungeonActive = false
local dungeonSession
local dungeonFinishConnection
local dungeonMapDropdown
local dungeonModeDropdown
local dungeonSizeDropdown
local dungeonNormalTeamDropdown
local dungeonGoldTeamDropdown
local dungeonSecondArtifactDropdown
local dungeonToggle
local dungeonToggleUpdating = false
local dungeonCooldownParagraph
local dungeonFarmToggle
local dungeonFarmStatusParagraph
local DungeonFarm = {
    enabled = true,
    toggleUpdating = false,
    token = 0,
    running = false,
    entered = false,
    phase = "idle",
    room = nil,
    targetRoom = nil,
    targetPart = nil,
    activationAt = 0,
    lastEnemyCount = 0,
    completed = {},
    attempts = {},
    goldRooms = {},
    goldDoorsOpened = {},
    goldRoomsOpened = {},
    completedChests = {},
    enemySeenAt = {},
    lastCombatTarget = nil,
    lastCombatSendAt = 0,
    combatSendCount = 0,
    lastCombatError = "",
    lastLiveScanAt = 0,
    lastLiveScanCount = 0,
    lastLiveScanUncertain = false,
    route = {},
    routeKey = "",
    routeTarget = nil,
    goldTargetKey = nil,
    goldTargetRoom = nil,
    greenTargetKey = nil,
    goldRoomKeys = {},
    greenRoomKeys = {},
    goldContentActive = false,
    goldRoomEmptySince = {},
    roomEmptySince = {},
    lastRouteWalkAt = 0,
    lastRouteWalkTargetKey = nil,
    routeFolder = nil,
    mapGui = nil,
    mapPanel = nil,
    mapTitle = nil,
    mapSummary = nil,
    mapCanvas = nil,
    mapLegend = nil,
    teamApplied = false,
    teamApplying = false,
    teamIndexApplied = nil,
    teamAppliedAt = 0,
    lastEquippedPetCount = 0,
    deadEnemies = {},
    teleportDistance = 120,
    flySpeed = 140,
    teleportDistanceSlider = nil,
    flySpeedSlider = nil,
    startedAt = 0,
    sessionDungeon = nil,
    lastMessage = "Chua chay."
}

function DungeonFarm.normalizeTeleportDistance(value)
    local distance = tonumber(value) or 120
    return math.clamp(math.floor(distance / 10 + 0.5) * 10, 25, 1000)
end

function DungeonFarm.normalizeFlySpeed(value)
    local speed = tonumber(value) or 140
    return math.clamp(math.floor(speed / 10 + 0.5) * 10, 40, 1000)
end
local dungeonWaiting = false
local dungeonWaitToken = 0
local configLoaded = false
local configApplying = fileExists(ConfigPath)
local configApplyToken = 0
local controlsReady = false
local pendingSelectedPets
local configNeedsMigration = false
local dropdownSyncing = false
local dropdownSyncToken = 0
local setupReady = false
local dungeonMapByOption = {}
local dungeonSizeByOption = {}
local dungeonTeamByOption = {}
local dungeonArtifactByOption = {}
local dungeonSelection = {
    mapId = "DBZ",
    mode = "Public",
    size = 1,
    teamIndex = 1,
    normalTeamIndex = 1,
    goldTeamIndex = 1,
    fallenStarTeamIndex = 1,
    secondArtifact = ""
}
local scanPets
local rebuildPetDropdowns
local selectedCount
local syncDungeonControls
local refreshTeamOptions

local function normalizeDungeonMapId(value)
    if type(value) ~= "string" or value == "" then
        return nil
    end
    if type(WorldData[value]) == "table" then
        return value
    end

    -- Older config files stored the display option instead of the world id.
    local id = value:match("%[([^%]]+)%]%s*$")
        or value:match("%[([^%]]+)%s*$")
    if id and type(WorldData[id]) == "table" then
        return id
    end
    return nil
end

function Feature.modeLabel(mode)
    if mode == Feature.MODE_LOWEST_HEALTH then
        return utf8Text("Mau thap nhat", 77, 225, 117, 32, 116, 104, 7845, 112, 32, 110, 104, 7845, 116)
    end
    if mode == Feature.MODE_HIGHEST_HEALTH then
        return utf8Text("Mau nhieu nhat", 77, 225, 117, 32, 110, 104, 105, 7873, 117, 32, 110, 104, 7845, 116)
    end
    return utf8Text("Gan nhat", 71, 7847, 110, 32, 110, 104, 7845, 116)
end

function Feature.modeFromLabel(label)
    if label == Feature.modeLabel(Feature.MODE_LOWEST_HEALTH) then
        return Feature.MODE_LOWEST_HEALTH
    end
    if label == Feature.modeLabel(Feature.MODE_HIGHEST_HEALTH) then
        return Feature.MODE_HIGHEST_HEALTH
    end
    return Feature.MODE_NEAREST
end

local function beginConfigApply()
    configApplying = true
    configApplyToken = configApplyToken + 1
    local token = configApplyToken
    task.delay(2, function()
        if token == configApplyToken then
            configApplying = false
        end
    end)
end

local function beginDropdownSync()
    dropdownSyncing = true
    dropdownSyncToken = dropdownSyncToken + 1
    local token = dropdownSyncToken
    -- WindUI fires Select callbacks in the same turn; release the guard before user input.
    task.defer(function()
        if token == dropdownSyncToken then
            dropdownSyncing = false
        end
    end)
end

local function getTaggedMachines()
    local ok, tagged = pcall(function()
        return CollectionService:GetTagged("CloneMachine")
    end)
    return ok and type(tagged) == "table" and tagged or {}
end

local function getMachines()
    local seen = {}
    local result = {}

    for _, machine in ipairs(getTaggedMachines()) do
        local ok, id = pcall(function()
            return machine:GetAttribute("CloneMachineId")
        end)
        if ok and id ~= nil and id ~= "" then
            id = tostring(id)
            if not seen[id] then
                seen[id] = true
                local path = id
                local world = ""
                pcall(function()
                    path = machine:GetFullName()
                    world = machine.Parent and machine.Parent.Name or ""
                end)
                table.insert(result, {
                    id = id,
                    path = path,
                    world = world,
                    instance = machine
                })
            end
        end
    end

    table.sort(result, function(a, b)
        return a.id < b.id
    end)

    return result
end

local function refreshMachineList()
    machineList = getMachines()
    machineById = {}
    for _, machine in ipairs(machineList) do
        machineById[machine.id] = machine
    end
end

refreshMachineList()

local function cleanText(value)
    if value == nil then
        return ""
    end
    local ok, text = pcall(tostring, value)
    if not ok then
        return ""
    end
    text = text:gsub("[%c]+", " "):gsub("%s+", " ")
    return text:match("^%s*(.-)%s*$") or ""
end

local function getPetSpeciesName(pet)
    if type(pet) ~= "table" then
        return "Unknown"
    end
    local stats = type(PetStats) == "table" and PetStats[pet.PetId]
    if type(stats) == "table" then
        local name = cleanText(stats.DisplayName or stats.Name or pet.PetId)
        return name ~= "" and name or (cleanText(pet.PetId) ~= "" and cleanText(pet.PetId) or "Unknown")
    end
    local name = cleanText(pet.PetId)
    return name ~= "" and name or "Unknown"
end

local function getPetCustomName(pet)
    if type(pet) ~= "table" then
        return ""
    end

    local stats = type(PetStats) == "table" and PetStats[pet.PetId]
    local defaults = {}
    local values = {}
    local function push(value)
        if value ~= nil then
            table.insert(values, value)
        end
    end

    push(pet.PetId)
    if type(stats) == "table" then
        push(stats.Name)
        push(stats.DisplayName)
    end
    for _, value in ipairs(values) do
        local key = string.lower(cleanText(value))
        if key ~= "" then
            defaults[key] = true
        end
    end

    -- Different game versions use one of these fields for a user-edited name.
    values = {}
    push(pet.CustomName)
    push(pet.Nickname)
    push(pet.NickName)
    push(pet.PetName)
    push(pet.Name)
    push(pet.DisplayName)
    if type(pet.Data) == "table" then
        push(pet.Data.CustomName)
        push(pet.Data.Nickname)
        push(pet.Data.PetName)
        push(pet.Data.Name)
        push(pet.Data.DisplayName)
    end
    for _, value in ipairs(values) do
        local name = cleanText(value)
        if name ~= "" and not defaults[string.lower(name)] then
            return name
        end
    end
    return ""
end

local function petDisplayName(pet)
    local species = getPetSpeciesName(pet)
    local custom = getPetCustomName(pet)
    if custom ~= "" then
        return custom .. " [" .. species .. "]"
    end
    return species
end

local function petPassivesKey(passives)
    if type(passives) ~= "table" then
        return ""
    end
    local names = {}
    for _, passive in ipairs(passives) do
        table.insert(names, cleanText(passive))
    end
    table.sort(names)
    return table.concat(names, "|")
end

local function makePetSelectionRecord(pet)
    local record = {
        PetId = cleanText(pet.PetId),
        CustomName = cleanText(pet.CustomName),
        Level = tonumber(pet.Level),
        BaseLevel = tonumber(pet.BaseLevel),
        Shiny = pet.Shiny == true,
        Void = pet.Void == true,
        Infused = pet.Infused == true,
        Skin = cleanText(pet.Skin),
        Passives = petPassivesKey(pet.Passives)
    }
    return record
end

local function findMatchingPet(selection, pets, usedUID)
    if type(selection) ~= "table" or type(pets) ~= "table" then
        return nil
    end

    local expectedPetId = cleanText(selection.PetId)
    local expectedCustom = cleanText(selection.CustomName)
    local bestPet
    local bestScore = -math.huge

    for _, pet in ipairs(pets) do
        if type(pet) == "table" and pet.UID ~= nil and not usedUID[tostring(pet.UID)] then
            local petId = cleanText(pet.PetId)
            local custom = cleanText(pet.CustomName)
            if (expectedPetId == "" or petId == expectedPetId)
                and (expectedCustom == "" and custom == "" or expectedCustom ~= "" and custom == expectedCustom) then
                local score = expectedCustom ~= "" and 10000 or 1000
                if expectedPetId ~= "" then
                    score = score + 1000
                end
                if selection.Level ~= nil and tonumber(pet.Level) == tonumber(selection.Level) then
                    score = score + 100
                end
                if selection.BaseLevel ~= nil and tonumber(pet.BaseLevel) == tonumber(selection.BaseLevel) then
                    score = score + 50
                end
                if selection.Shiny ~= nil and pet.Shiny == selection.Shiny then
                    score = score + 20
                end
                if selection.Void ~= nil and pet.Void == selection.Void then
                    score = score + 20
                end
                if selection.Infused ~= nil and pet.Infused == selection.Infused then
                    score = score + 20
                end
                if selection.Skin ~= nil and cleanText(pet.Skin) == cleanText(selection.Skin) then
                    score = score + 10
                end
                if selection.Passives ~= nil and petPassivesKey(pet.Passives) == cleanText(selection.Passives) then
                    score = score + 10
                end
                if score > bestScore then
                    bestScore = score
                    bestPet = pet
                end
            end
        end
    end
    return bestPet
end

local function resolvePendingPetSelection()
    if type(pendingSelectedPets) ~= "table" or #pendingSelectedPets == 0 then
        return
    end

    local pets = getStoreTable("Pets", true)
    local usedUID = {}
    local resolved = {}
    for _, selection in ipairs(pendingSelectedPets) do
        local pet = findMatchingPet(selection, pets, usedUID)
        if pet then
            local key = tostring(pet.UID)
            usedUID[key] = true
            table.insert(resolved, pet.UID)
        end
    end

    if #resolved > 0 then
        selectedUID = resolved
    end
    pendingSelectedPets = nil
end

local function inferSelectionFromCloneMachines()
    if #selectedUID == 0 then
        return false
    end

    local foundLiveUID = false
    for _, uid in ipairs(selectedUID) do
        if petByUID[tostring(uid)] then
            foundLiveUID = true
            break
        end
    end
    if foundLiveUID then
        return false
    end

    local inferred = {}
    local seenUID = {}
    local cloneData = getStoreTable("CloneMachineData", true)
    for _, machine in ipairs(machineList) do
        local record = type(cloneData[machine.id]) == "table" and cloneData[machine.id] or nil
        local uid = record and record.UID
        if uid ~= nil and petByUID[tostring(uid)] and not seenUID[tostring(uid)] then
            seenUID[tostring(uid)] = true
            table.insert(inferred, uid)
        end
    end
    if #inferred > 0 then
        selectedUID = inferred
        return true
    end
    return false
end

local function cloneDuration(pet)
    if type(pet) ~= "table" then
        return nil
    end
    local stats = type(PetStats) == "table" and PetStats[pet.PetId]
    if type(stats) ~= "table" or not stats.Rarity then
        return nil
    end
    if stats.CanRemove == false or stats.CantClone then
        return nil
    end

    local duration = (RarityHours[stats.Rarity] or 1e26) * 60 * 60 * 2

    if pet.Infused then
        duration = duration * 4
    elseif pet.Void then
        duration = duration * 2.75
    elseif pet.Shiny then
        duration = duration * 1.75
    end

    local passiveFactor = 1
    local passives = type(pet.Passives) == "table" and pet.Passives or {}
    for _, passiveName in ipairs(passives) do
        local passive = type(PassiveStats) == "table" and PassiveStats[passiveName]
        local chance = type(passive) == "table" and tonumber(passive.Chance) or nil
        if chance and chance > 0 then
            local factor = (1 / chance) ^ 0.025
            passiveFactor = passiveFactor + (math.max(factor, 1) - 1)
        end
    end

    return duration * passiveFactor
end

local function getTimeMultiplier()
    local ok, value = pcall(function()
        return tonumber(GetMultiplier.Time(LocalPlayer))
    end)
    if ok and value and value > 0 then
        return value
    end
    return 1
end

local function formatDuration(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local days = math.floor(seconds / 86400)
    seconds = seconds - days * 86400
    local hours = math.floor(seconds / 3600)
    seconds = seconds - hours * 3600
    local minutes = math.floor(seconds / 60)
    seconds = seconds - minutes * 60

    if days > 0 then
        return string.format("%dd %02dh %02dm", days, hours, minutes)
    end
    if hours > 0 then
        return string.format("%dh %02dm %02ds", hours, minutes, seconds)
    end
    return string.format("%dm %02ds", minutes, seconds)
end

local function makeStatusLabel(parent, size, position, textSize, color)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = size
    label.Position = position
    label.Font = Enum.Font.Gotham
    label.TextSize = textSize
    label.TextColor3 = color
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.TextWrapped = true
    label.Parent = parent
    return label
end

local function createStatusOverlay()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local oldGui = playerGui:FindFirstChild("AutoCloneStatus")
    if oldGui then
        oldGui:Destroy()
    end

    statusGui = Instance.new("ScreenGui")
    statusGui.Name = "AutoCloneStatus"
    statusGui.ResetOnSpawn = false
    statusGui.DisplayOrder = 999
    statusGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    statusGui.Parent = playerGui

    statusFrame = Instance.new("Frame")
    statusFrame.Name = "Panel"
    statusFrame.Position = UDim2.fromOffset(12, 170)
    statusFrame.Size = UDim2.fromOffset(680, 220)
    statusFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
    statusFrame.BackgroundTransparency = 0.08
    statusFrame.BorderSizePixel = 0
    statusFrame.Parent = statusGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = statusFrame

    statusTitle = makeStatusLabel(
        statusFrame,
        UDim2.new(1, -24, 0, 28),
        UDim2.fromOffset(12, 8),
        16,
        Color3.fromRGB(255, 255, 255)
    )
    statusTitle.Text = "Clone Machines"

    statusSummary = makeStatusLabel(
        statusFrame,
        UDim2.new(1, -24, 0, 24),
        UDim2.fromOffset(12, 38),
        12,
        Color3.fromRGB(180, 190, 205)
    )

    machineStatusLabels = {}
    for index = 1, 4 do
        machineStatusLabels[index] = makeStatusLabel(
            statusFrame,
            UDim2.new(1, -24, 0, 34),
            UDim2.fromOffset(12, 64 + (index - 1) * 36),
            12,
            Color3.fromRGB(225, 230, 238)
        )
    end
end

local function updateStatusOverlay(lines, multiplier, now, token)
    lines = type(lines) == "table" and lines or {}
    multiplier = tonumber(multiplier) or 1
    if not statusGui or not statusGui.Parent then
        createStatusOverlay()
    end

    statusTitle.Text = "Clone Machines | Time x" .. string.format("%.2f", multiplier)
    statusSummary.Text = string.format(
        "GameTime: %s | CloneToken: %s | Chon: %d/4 | Auto: %s",
        tostring(now),
        tostring(token),
        selectedCount(),
        autoEnabled and "BAT" or "TAT"
    )

    for index = 1, 4 do
        local label = machineStatusLabels[index]
        if label then
            label.Text = lines[index] or ("May " .. tostring(index) .. " | chua co du lieu")
            label.TextColor3 = string.find(label.Text, "XONG", 1, true)
                and Color3.fromRGB(120, 255, 160)
                or Color3.fromRGB(225, 230, 238)
        end
    end
end

local function setParagraph(paragraph, title, desc)
    local ok, err = pcall(function()
        safeSetThreadIdentity(5)
        if paragraph and paragraph.SetTitle and paragraph.SetDesc then
            paragraph:SetTitle(title)
            paragraph:SetDesc(desc)
        end
    end)
    safeSetThreadIdentity(8)
    if not ok then
        warn("AutoClone UI status error: " .. tostring(err))
    end
end

local function notifyStatus(title, content)
    safeNotify(WindUI, title, content)
end

local runtimeErrorAt = {}
local function reportRuntimeError(context, err)
    local message = tostring(err)
    warn("[AutoClone] " .. tostring(context) .. ": " .. message)

    local now = os.clock()
    if runtimeErrorAt[context] and now - runtimeErrorAt[context] < 2 then
        return
    end
    runtimeErrorAt[context] = now

    pcall(function()
        if type(appendfile) == "function" then
            ensureConfigFolder()
            appendfile(
                RuntimeLogPath,
                string.format("[%s] %s: %s\n", os.date("!%Y-%m-%d %H:%M:%S"), tostring(context), message)
            )
        end
    end)
    safeNotify(WindUI, "AutoClone loi", tostring(context) .. ": " .. string.sub(message, 1, 160))
end

local function protectedCall(context, callback)
    local function errorHandler(err)
        if type(debug) == "table" and type(debug.traceback) == "function" then
            return debug.traceback(tostring(err), 2)
        end
        return tostring(err)
    end

    local ok, result = xpcall(callback, errorHandler)
    if not ok then
        reportRuntimeError(context, result)
    end
    return ok, result
end

local function getOccupiedMachineUIDs()
    local occupied = {}
    for _, key in ipairs(OccupiedDataKeys) do
        local data = getStoreTable(key, true)
        for slot, record in pairs(data) do
            if type(record) == "table" then
                local source = key
                if key == "CloneMachineData" then
                    source = "CloneMachine " .. tostring(slot)
                elseif key == "VoidMachineData" then
                    source = "Limit Break " .. tostring(slot)
                elseif key == "InfuserMachineData" then
                    source = "Infuser " .. tostring(slot)
                elseif key == "EvolveMachineData" then
                    source = "Evolve " .. tostring(slot)
                elseif key == "IncubatorData" then
                    source = "Incubator " .. tostring(slot)
                end
                if record.UID ~= nil then
                    occupied[tostring(record.UID)] = source
                end
                if type(record.UIDs) == "table" then
                    for _, uid in pairs(record.UIDs) do
                        occupied[tostring(uid)] = source
                    end
                end
            end
        end
    end
    return occupied
end

local function getSelectedPetRecords()
    local byUID = {}
    for _, pet in ipairs(getStoreTable("Pets", true)) do
        if type(pet) == "table" and pet.UID ~= nil then
            byUID[tostring(pet.UID)] = pet
        end
    end

    local result = {}
    for _, uid in ipairs(selectedUID) do
        local pet = byUID[tostring(uid)]
        if pet then
            table.insert(result, makePetSelectionRecord(pet))
        end
    end
    return result
end

local function saveConfig(silent)
    if not controlsReady or Feature.restoringFeatureState or dropdownSyncing then
        return false
    end
    local ok, err = pcall(function()
        if type(writefile) ~= "function" then
            error("writefile API khong ton tai")
        end
        local folderOK, folderError = ensureConfigFolder()
        if not folderOK then
            error(folderError)
        end
        local encoded = encodeJson({
            selectedUID = selectedUID,
            selectedPets = getSelectedPetRecords(),
            dungeonSelection = dungeonSelection,
            features = {
                autoClone = autoEnabled,
                autoDungeon = Feature.autoDungeonEnabled,
                autoDungeonFarm = DungeonFarm.enabled,
                autoFarm = Feature.autoFarmEnabled,
                autoFallenStar = Feature.autoFallenStarEnabled,
                autoPassive = Feature.autoPassiveEnabled,
                autoCollectDrops = Feature.autoCollectDropsEnabled,
                tpPet = Feature.tpPetEnabled,
                attackWhileUlt = Feature.attackWhileUltEnabled,
                autoGate = Feature.gateFarm.enabled,
                autoGateOpen = Feature.gateFarm.openEnabled,
                autoGateFarm = Feature.gateFarm.farmEnabled
            },
            gate = {
                gateId = Feature.gateFarm.gateId,
                amount = Feature.gateFarm.amount,
                teamIndex = Feature.gateFarm.teamIndex,
                maxRuns = Feature.gateFarm.maxRuns
            },
            autoFarm = {
                mode = Feature.autoFarmMode
            },
            fallenStar = {
                interval = Feature.autoFallenStarInterval
            },
            autoPassive = {
                selectedUID = Feature.autoPassiveSelectedUID,
                selectedPets = Feature.getAutoPassivePetRecords(),
                targetPassives = Feature.autoPassiveTargetPassives,
                targetRarities = Feature.autoPassiveTargetRarities,
                keepMode = Feature.autoPassiveKeepMode,
                currency = Feature.autoPassiveCurrency,
                category = Feature.autoPassiveCategory,
                slot = Feature.autoPassiveSlot,
                rollDelay = Feature.autoPassiveRollDelay
            },
            dungeonFarm = {
                teleportDistance = DungeonFarm.teleportDistance,
                flySpeed = DungeonFarm.flySpeed
            }
        })
        writefile(ConfigPath, encoded)
        if type(isfile) == "function" and not fileExists(ConfigPath) then
            error("writefile khong tao duoc " .. ConfigPath)
        end
        if type(readfile) == "function" and readfile(ConfigPath) ~= encoded then
            error("noi dung config sau khi ghi khong khop")
        end
    end)
    if ok and not silent then
        notifyStatus("Config", "Da luu danh sach pet.")
    elseif not ok then
        notifyStatus("Config loi", tostring(err))
    end
    return ok
end

local function loadConfig()
    if not fileExists(ConfigPath) or type(readfile) ~= "function" then
        return
    end

    local ok, data = pcall(function()
        return decodeJson(readfile(ConfigPath))
    end)
    if not ok or type(data) ~= "table" then
        notifyStatus("Config loi", "File config khong hop le.")
        return
    end

    configLoaded = true
    Feature.savedFeatureState = {}
    if type(data.features) == "table" then
        Feature.savedFeatureState = {
            autoClone = data.features.autoClone == true,
            autoDungeon = data.features.autoDungeon == true,
            autoDungeonFarm = data.features.autoDungeonFarm ~= false,
            autoFarm = data.features.autoFarm == true,
            autoFallenStar = data.features.autoFallenStar == true,
            autoPassive = data.features.autoPassive == true,
            autoCollectDrops = data.features.autoCollectDrops == true,
            tpPet = data.features.tpPet == true,
            attackWhileUlt = data.features.attackWhileUlt == true,
            autoGate = data.features.autoGate == true,
            autoGateOpen = data.features.autoGateOpen == nil
                and data.features.autoGate == true
                or data.features.autoGateOpen == true,
            autoGateFarm = data.features.autoGateFarm == nil
                and data.features.autoGate == true
                or data.features.autoGateFarm == true
        }
    end
    if type(data.gate) == "table" then
        local farm = Feature.gateFarm
        if type(data.gate.gateId) == "string" and data.gate.gateId ~= "" then
            farm.gateId = data.gate.gateId
        end
        farm.amount = math.clamp(math.floor(tonumber(data.gate.amount) or farm.amount), 1, 5)
        farm.teamIndex = math.max(1, math.floor(tonumber(data.gate.teamIndex) or farm.teamIndex))
        farm.maxRuns = math.clamp(math.floor(tonumber(data.gate.maxRuns) or farm.maxRuns), 1, 20)
    end
    if type(data.autoFarm) == "table" then
        local mode = data.autoFarm.mode
        if mode == Feature.MODE_LOWEST_HEALTH or mode == Feature.MODE_HIGHEST_HEALTH then
            Feature.autoFarmMode = mode
        else
            Feature.autoFarmMode = Feature.MODE_NEAREST
        end
    end
    if type(data.fallenStar) == "table" then
        Feature.autoFallenStarInterval = math.clamp(
            tonumber(data.fallenStar.interval) or Feature.autoFallenStarInterval,
            0.5,
            10
        )
        Feature.fallenStarFarm.interval = Feature.autoFallenStarInterval
    end
    selectedUID = {}
    pendingSelectedPets = nil
    local seenUID = {}
    if type(data.selectedUID) == "table" then
        for _, uid in ipairs(data.selectedUID) do
            local key = tostring(uid)
            if uid ~= nil and key ~= "" and not seenUID[key] and #selectedUID < 4 then
                seenUID[key] = true
                table.insert(selectedUID, uid)
            end
        end
    end

    if type(data.selectedPets) == "table" then
        local records = {}
        for _, record in ipairs(data.selectedPets) do
            if type(record) == "table" then
                table.insert(records, record)
            end
        end
        if #records > 0 then
            pendingSelectedPets = records
        end
    end
    configNeedsMigration = pendingSelectedPets == nil and #selectedUID > 0

    Feature.autoPassiveSelectedUID = {}
    Feature.autoPassivePendingPets = nil
    if type(data.autoPassive) == "table" then
        local autoData = data.autoPassive
        local seenAutoUID = {}
        if type(autoData.selectedUID) == "table" then
            for _, uid in ipairs(autoData.selectedUID) do
                local key = tostring(uid)
                if uid ~= nil and key ~= "" and not seenAutoUID[key] then
                    seenAutoUID[key] = true
                    table.insert(Feature.autoPassiveSelectedUID, uid)
                end
            end
        end
        if type(autoData.selectedPets) == "table" and #autoData.selectedPets > 0 then
            Feature.autoPassivePendingPets = {}
            for _, record in ipairs(autoData.selectedPets) do
                if type(record) == "table" then
                    table.insert(Feature.autoPassivePendingPets, record)
                end
            end
        end
        Feature.autoPassiveTargetPassives = {}
        if type(autoData.targetPassives) == "table" then
            for _, value in ipairs(autoData.targetPassives) do
                if type(value) == "string" and value ~= "" then
                    table.insert(Feature.autoPassiveTargetPassives, value)
                end
            end
        end
        Feature.autoPassiveTargetRarities = {}
        if type(autoData.targetRarities) == "table" then
            for _, value in ipairs(autoData.targetRarities) do
                if type(value) == "string" and Feature.passiveRarityOrder[value] then
                    table.insert(Feature.autoPassiveTargetRarities, value)
                end
            end
        end
        if autoData.keepMode == "rarity" then
            Feature.autoPassiveKeepMode = "rarity"
        else
            Feature.autoPassiveKeepMode = "passive"
        end
        Feature.autoPassiveCurrency = autoData.currency == "shard" and "shard" or "token"
        if type(autoData.category) == "string" then
            Feature.autoPassiveCategory = autoData.category
        end
        local slot = tonumber(autoData.slot)
        if slot == 1 or slot == 2 then
            Feature.autoPassiveSlot = slot
        end
        Feature.autoPassiveRollDelay = AutoPassive.normalizeRollDelay(autoData.rollDelay)
    end

    local savedDungeonSelection = type(data.dungeonSelection) == "table"
        and data.dungeonSelection
        or nil
    local savedNormalTeam = savedDungeonSelection
        and type(savedDungeonSelection.normalTeamIndex) == "number"
    local savedGoldTeam = savedDungeonSelection
        and type(savedDungeonSelection.goldTeamIndex) == "number"
    if savedDungeonSelection then
        for key, value in pairs(savedDungeonSelection) do
            if dungeonSelection[key] ~= nil and type(value) == type(dungeonSelection[key]) then
                dungeonSelection[key] = value
            end
        end
    end
    if not savedNormalTeam then
        dungeonSelection.normalTeamIndex = tonumber(dungeonSelection.teamIndex) or 1
        configNeedsMigration = true
    end
    if not savedGoldTeam then
        dungeonSelection.goldTeamIndex = dungeonSelection.normalTeamIndex
        configNeedsMigration = true
    end
    dungeonSelection.teamIndex = dungeonSelection.normalTeamIndex
    dungeonSelection.fallenStarTeamIndex = math.max(
        1,
        math.floor(tonumber(dungeonSelection.fallenStarTeamIndex) or dungeonSelection.normalTeamIndex)
    )
    dungeonSelection.mapId = normalizeDungeonMapId(dungeonSelection.mapId) or "DBZ"
    if type(data.dungeonFarm) == "table" then
        DungeonFarm.teleportDistance = DungeonFarm.normalizeTeleportDistance(data.dungeonFarm.teleportDistance)
        DungeonFarm.flySpeed = DungeonFarm.normalizeFlySpeed(data.dungeonFarm.flySpeed)
    end
end

local function getPets()
    local pets = getStoreTable("Pets", true)
    local result = {}

    for _, pet in ipairs(pets) do
        if type(pet) == "table" and cloneDuration(pet) then
            table.insert(result, pet)
        end
    end

    table.sort(result, function(a, b)
        local nameA = petDisplayName(a)
        local nameB = petDisplayName(b)
        if nameA == nameB then
            return (tonumber(a.Level) or 0) > (tonumber(b.Level) or 0)
        end
        return nameA < nameB
    end)

    return result
end

local function getOccupiedPetSummary()
    local occupied = getOccupiedMachineUIDs()
    local pets = getStoreTable("Pets", true)
    local lines = {}
    for _, pet in ipairs(pets) do
        local source = type(pet) == "table" and pet.UID ~= nil and occupied[tostring(pet.UID)] or nil
        if source then
            table.insert(lines, string.format(
                "%s | Lv.%s | UID:%s | %s",
                petDisplayName(pet),
                tostring(pet.Level or "?"),
                tostring(pet.UID),
                tostring(source)
            ))
        end
    end
    table.sort(lines)
    if #lines == 0 then
        return utf8Text("Khong co pet nao dang o may khac.", 75, 104, 244, 110, 103, 32, 99, 243, 32, 112, 101, 116, 32, 110, 224, 111, 32, 273, 97, 110, 103, 32, 7903, 32, 109, 225, 121, 32, 107, 104, 225, 99, 46)
    end
    return table.concat(lines, "\n")
end

local function buildPetOption(pet, occupiedByUID)
    local occupied = type(occupiedByUID) == "table" and occupiedByUID[tostring(pet.UID)] or nil
    local suffix = occupied and (utf8Text(" | Dang o ", 32, 124, 32, 272, 97, 110, 103, 32, 7903, 32) .. tostring(occupied)) or ""
    return string.format(
        "%s | Lv.%s | UID:%s%s",
        petDisplayName(pet),
        tostring(pet.Level or "?"),
        tostring(pet.UID),
        suffix
    )
end

local function refreshSelectedPetMap()
    petByUID = {}
    local pets = getStoreTable("Pets", true)
    for _, pet in ipairs(pets) do
        if type(pet) == "table" and pet.UID ~= nil then
            petByUID[tostring(pet.UID)] = pet
        end
    end
end

selectedCount = function()
    local count = 0
    for _, uid in ipairs(selectedUID) do
        if uid ~= nil then
            count = count + 1
        end
    end
    return count
end

local function updateSelectionInfo()
    local lines = {}
    for index, machine in ipairs(machineList) do
        local uid = selectedUID[index]
        local pet = uid and petByUID[tostring(uid)]
        if pet then
            table.insert(lines, string.format(
                "%s: %s | Lv.%s | UID:%s",
                machine.id,
                petDisplayName(pet),
                tostring(pet.Level or "?"),
                tostring(pet.UID)
            ))
        else
            table.insert(lines, machine.id .. ": chua chon")
        end
    end
    setParagraph(selectedParagraph, "Da chon " .. tostring(selectedCount()) .. "/4", table.concat(lines, "\n"))
end

local function updateOccupiedInfo()
    setParagraph(occupiedParagraph, utf8Text("Pet dang o may khac", 80, 101, 116, 32, 273, 97, 110, 103, 32, 7903, 32, 109, 225, 121, 32, 107, 104, 225, 99), getOccupiedPetSummary())
end

function AutoPassive.collectMappedDropdownValues(value, mapping)
    local result = {}
    local seen = {}
    mapping = type(mapping) == "table" and mapping or {}

    local function addOption(option)
        if type(option) ~= "string" then
            return
        end
        local uid = mapping[option]
        local key = uid and tostring(uid)
        if key and not seen[key] then
            seen[key] = true
            table.insert(result, uid)
        end
    end

    if type(value) == "table" then
        for key, item in pairs(value) do
            if type(item) == "string" then
                addOption(item)
            elseif type(item) == "table" then
                addOption(item.Title or item.Name or item[1])
            elseif item == true and type(key) == "string" then
                addOption(key)
            end
        end
    elseif type(value) == "string" then
        addOption(value)
    end

    return result
end

local function collectDropdownUIDs(value)
    return AutoPassive.collectMappedDropdownValues(value, optionToUID)
end

rebuildPetDropdowns = function()
    beginDropdownSync()
    refreshSelectedPetMap()
    resolvePendingPetSelection()
    if inferSelectionFromCloneMachines() then
        configNeedsMigration = true
    end

    optionToUID = {}
    optionByUID = {}

    local pets = getPets()
    local occupiedByUID = getOccupiedMachineUIDs()
    local values = {}

    for _, pet in ipairs(pets) do
        if type(pet) == "table" and pet.UID ~= nil then
            local option = buildPetOption(pet, occupiedByUID)
            optionToUID[option] = pet.UID
            optionByUID[tostring(pet.UID)] = option
            table.insert(values, option)
        end
    end

    if #values == 0 then
        values = {"Khong co pet clone duoc"}
    end

    local selectedOptions = {}
    local validUIDs = {}
    for _, uid in ipairs(selectedUID) do
        if petByUID[tostring(uid)] and optionByUID[tostring(uid)] then
            table.insert(selectedOptions, optionByUID[tostring(uid)])
            validUIDs[tostring(uid)] = true
        end
    end
    local orderedSelection = {}
    for _, uid in ipairs(selectedUID) do
        if validUIDs[tostring(uid)] then
            table.insert(orderedSelection, uid)
        end
    end
    selectedUID = orderedSelection

    -- Danh sach pet khong doi thi giu dropdown cu (tao moi dropdown WindUI
    -- voi hang tram pet la nguyen nhan do vai giay moi lan tai cau hinh).
    local dropdownKey = table.concat(values, "\n") .. "|sel|" .. table.concat(selectedOptions, "\n")
    if petDropdown and dropdownKey == Feature.lastPetDropdownKey then
        updateSelectionInfo()
        updateOccupiedInfo()
        return
    end
    Feature.lastPetDropdownKey = dropdownKey

    local dropdownConfig = {
        Title = "Chon pet clone (toi da 4)",
        Desc = "Hien ten tu dat, loai, Level, UID. Thu tu chon se gan vao may A/B/K/M.",
        Values = values,
        MenuWidth = 300,
        Multi = true,
        AllowNone = true,
        SearchBarEnabled = true,
        Value = selectedOptions,
        Callback = function(value)
            if configApplying or dropdownSyncing then
                return
            end
            local requestedUID = collectDropdownUIDs(value)
            local requestedByUID = {}
            for _, uid in ipairs(requestedUID) do
                requestedByUID[tostring(uid)] = uid
            end

            local nextSelection = {}
            local seenUID = {}
            local fullSelection = type(value) == "table"
                and value.Title == nil
                and value.Name == nil
            if fullSelection then
                -- WindUI normally sends the complete Multi selection as an array.
                for _, uid in ipairs(selectedUID) do
                    local key = tostring(uid)
                    if requestedByUID[key] and not seenUID[key] then
                        seenUID[key] = true
                        table.insert(nextSelection, requestedByUID[key])
                    end
                end
                for _, uid in ipairs(requestedUID) do
                    local key = tostring(uid)
                    if not seenUID[key] then
                        seenUID[key] = true
                        table.insert(nextSelection, uid)
                    end
                end
            else
                -- Some WindUI builds report only the option that was toggled.
                local toggledUID = requestedUID[1]
                if toggledUID then
                    local toggledKey = tostring(toggledUID)
                    for _, uid in ipairs(selectedUID) do
                        local key = tostring(uid)
                        if key ~= toggledKey and not seenUID[key] then
                            seenUID[key] = true
                            table.insert(nextSelection, uid)
                        end
                    end
                    if not table.find(selectedUID, toggledUID) and #nextSelection < 4 then
                        table.insert(nextSelection, toggledUID)
                    end
                else
                    nextSelection = selectedUID
                end
            end

            if #nextSelection > 4 then
                notifyStatus("Toi da 4 pet", "Bo qua pet thu 5 tro di.")
                while #nextSelection > 4 do
                    table.remove(nextSelection)
                end
            end

            selectedUID = nextSelection
            updateSelectionInfo()
            saveConfig(true)
        end
    }
    if #selectedOptions > 0 then
        dropdownConfig.Value = selectedOptions
    end
    local staleDropdownFrame
    local uiRoot = getUIRoot()
    local dropdownRoot = uiRoot and uiRoot:FindFirstChild("WindUI/Dropdowns")
    local firstOption = values[1]
    if dropdownRoot and firstOption then
        for _, candidate in ipairs(dropdownRoot:GetChildren()) do
            for _, element in ipairs(candidate:GetDescendants()) do
                if (element:IsA("TextLabel") or element:IsA("TextButton")) and element.Text == firstOption then
                    staleDropdownFrame = candidate
                    break
                end
            end
            if staleDropdownFrame then
                break
            end
        end
    end
    if petDropdown then
        pcall(function()
            petDropdown:Destroy()
        end)
    end
    if staleDropdownFrame and staleDropdownFrame.Parent then
        pcall(function()
            staleDropdownFrame:Destroy()
        end)
    end
    petDropdown = CloneTab:Dropdown(dropdownConfig)

    updateSelectionInfo()
    updateOccupiedInfo()
end

local AutoPassiveMaps = {
    optionToUID = {},
    optionByUID = {},
    optionToPassive = {},
    categoryByOption = {}
}

function AutoPassive.getPassivePets()
    local result = {}
    for _, pet in ipairs(getStoreTable("Pets", true)) do
        if type(pet) == "table" and pet.UID ~= nil then
            table.insert(result, pet)
        end
    end
    table.sort(result, function(a, b)
        local nameA = petDisplayName(a)
        local nameB = petDisplayName(b)
        if nameA == nameB then
            return (tonumber(a.Level) or 0) > (tonumber(b.Level) or 0)
        end
        return nameA < nameB
    end)
    return result
end

Feature.getAutoPassivePetRecords = function()
    local byUID = {}
    for _, pet in ipairs(getStoreTable("Pets", true)) do
        if type(pet) == "table" and pet.UID ~= nil then
            byUID[tostring(pet.UID)] = pet
        end
    end
    local result = {}
    for _, uid in ipairs(Feature.autoPassiveSelectedUID) do
        local pet = byUID[tostring(uid)]
        if pet then
            table.insert(result, makePetSelectionRecord(pet))
        end
    end
    return result
end

function AutoPassive.resolvePendingAutoPassiveSelection()
    if type(Feature.autoPassivePendingPets) ~= "table" or #Feature.autoPassivePendingPets == 0 then
        return
    end
    local pets = AutoPassive.getPassivePets()
    local usedUID = {}
    local resolved = {}
    for _, selection in ipairs(Feature.autoPassivePendingPets) do
        local pet = findMatchingPet(selection, pets, usedUID)
        if pet then
            local key = tostring(pet.UID)
            usedUID[key] = true
            table.insert(resolved, pet.UID)
        end
    end
    if #resolved > 0 then
        Feature.autoPassiveSelectedUID = resolved
    end
    Feature.autoPassivePendingPets = nil
end

Feature.readPassiveMenu = function()
    -- Tim menu dropdown Pet roll passive DANG MO. Tra ve {menu, picked} voi
    -- picked la UID cac pet khop o Search hien tai (rong = khong chon gi de
    -- tranh chon ca balo); nil neu khong thay menu.
    -- (WindUI loc search bang TabItem.Visible; option text nam o
    -- TabItem.Frame.Title.TextLabel.)
    local maps = AutoPassiveMaps.optionToUID
    local uiRoot = getUIRoot()
    local dropdownRoot = uiRoot and uiRoot:FindFirstChild("WindUI/Dropdowns")
    if not dropdownRoot then
        return nil
    end
    local function isShown(inst, top)
        local cur = inst
        while cur and cur ~= top do
            local vis = nil
            pcall(function()
                vis = cur.Visible
            end)
            if vis == false then
                return false
            end
            cur = cur.Parent
        end
        return true
    end
    for _, canvas in ipairs(dropdownRoot:GetChildren()) do
        local canvasVisible = false
        pcall(function()
            canvasVisible = canvas.Visible ~= false
        end)
        if canvasVisible then
            local menu, needle = nil, ""
            local labels = {}
            for _, element in ipairs(canvas:GetDescendants()) do
                if element:IsA("TextBox") then
                    local placeholder, text = "", ""
                    pcall(function()
                        placeholder = element.PlaceholderText or ""
                    end)
                    pcall(function()
                        text = element.Text or ""
                    end)
                    if string.find(string.lower(placeholder), "search", 1, true) then
                        needle = text
                        if not menu then
                            menu = element.Parent
                            while menu and menu.Parent ~= canvas do
                                menu = menu.Parent
                            end
                        end
                    end
                elseif element:IsA("TextLabel") then
                    local text = nil
                    pcall(function()
                        text = element.Text
                    end)
                    if type(text) == "string" and maps[text] ~= nil then
                        table.insert(labels, element)
                    end
                end
            end
            if menu and #labels > 0 then
                needle = string.lower(cleanText(needle))
                if needle == "" then
                    return {menu = menu, picked = {}}
                end
                local hidesMismatch = false
                for _, label in ipairs(labels) do
                    local text = ""
                    pcall(function()
                        text = string.lower(label.Text or "")
                    end)
                    if not string.find(text, needle, 1, true) and not isShown(label, menu) then
                        hidesMismatch = true
                        break
                    end
                end
                local picked = {}
                local seenUID = {}
                for _, label in ipairs(labels) do
                    local text = ""
                    pcall(function()
                        text = string.lower(label.Text or "")
                    end)
                    local matched = string.find(text, needle, 1, true) ~= nil
                    local take = matched
                    if hidesMismatch then
                        take = matched and isShown(label, menu)
                    end
                    if take then
                        local uid = nil
                        pcall(function()
                            uid = maps[label.Text]
                        end)
                        if uid ~= nil and not seenUID[tostring(uid)] then
                            seenUID[tostring(uid)] = true
                            table.insert(picked, uid)
                        end
                    end
                end
                return {menu = menu, picked = picked}
            end
        end
    end
    return nil
end

Feature.toggleVisiblePassivePets = function()
    local info = Feature.readPassiveMenu()
    if not info then
        return
    end
    local picked = info.picked
    if #picked == 0 then
        notifyStatus("Auto Passive", "Khong thay pet nao khop Search.")
        return
    end
    local selectedSet = {}
    for _, uid in ipairs(Feature.autoPassiveSelectedUID) do
        selectedSet[tostring(uid)] = true
    end
    local allSelected = true
    for _, uid in ipairs(picked) do
        if not selectedSet[tostring(uid)] then
            allSelected = false
            break
        end
    end
    local nextSelection = {}
    if allSelected then
        local drop = {}
        for _, uid in ipairs(picked) do
            drop[tostring(uid)] = true
        end
        for _, uid in ipairs(Feature.autoPassiveSelectedUID) do
            if not drop[tostring(uid)] then
                table.insert(nextSelection, uid)
            end
        end
    else
        nextSelection = Feature.autoPassiveSelectedUID
        for _, uid in ipairs(picked) do
            if not selectedSet[tostring(uid)] then
                selectedSet[tostring(uid)] = true
                table.insert(nextSelection, uid)
            end
        end
    end
    Feature.autoPassiveSelectedUID = nextSelection
    local options = {}
    for _, uid in ipairs(nextSelection) do
        local option = AutoPassiveMaps.optionByUID[tostring(uid)]
        if option then
            table.insert(options, option)
        end
    end
    -- Cap nhat tick truc tiep, KHONG rebuild (rebuild se dong menu dang mo).
    beginDropdownSync()
    if Feature.autoPassivePetDropdown then
        pcall(function()
            Feature.autoPassivePetDropdown:Select(options)
        end)
    end
    Feature.updateAutoPassiveStatus()
    saveConfig(true)
end

Feature.pollPassiveMenuInject = function()
    -- Gan o tick chon-tat-ca vao trong menu dropdown dang mo, ngay duoi o
    -- Search (bam trong menu nen khong bi dong menu). Menu dong/mo lai thi
    -- tu gan lai vi nut la con cua menu.
    local info = Feature.readPassiveMenu()
    if not info or not info.menu or not info.menu.Parent then
        return
    end
    local menu = info.menu
    local button = menu:FindFirstChild("__AFS_SelectAll")
    if not button or not button.Parent then
        button = Instance.new("TextButton")
        button.Name = "__AFS_SelectAll"
        button.Size = UDim2.new(1, 0, 0, 30)
        button.LayoutOrder = 2
        button.Font = Enum.Font.GothamMedium
        button.TextSize = 14
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.BackgroundColor3 = Color3.fromRGB(45, 48, 56)
        button.BorderSizePixel = 0
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = button
        button.Parent = menu
        button.MouseButton1Click:Connect(function()
            protectedCall("Passive select-all toggle", function()
                Feature.toggleVisiblePassivePets()
            end)
        end)
    end
    local picked = info.picked
    local selectedSet = {}
    for _, uid in ipairs(Feature.autoPassiveSelectedUID) do
        selectedSet[tostring(uid)] = true
    end
    local allSelected = #picked > 0
    for _, uid in ipairs(picked) do
        if not selectedSet[tostring(uid)] then
            allSelected = false
            break
        end
    end
    pcall(function()
        if #picked == 0 then
            button.Text = "[ ] Chon tat ca (go Search truoc)"
        elseif allSelected then
            button.Text = string.format("[x] Bo chon %d pet", #picked)
        else
            button.Text = string.format("[ ] Chon tat ca %d pet", #picked)
        end
    end)
end

Feature.rebuildAutoPassivePetDropdown = function()
    beginDropdownSync()
    AutoPassive.resolvePendingAutoPassiveSelection()
    AutoPassiveMaps.optionToUID = {}
    AutoPassiveMaps.optionByUID = {}

    local values = {}
    local labelCount = {}
    for _, pet in ipairs(AutoPassive.getPassivePets()) do
        -- Chi hien ten + passive (khong UID/Lv cho gon); trung ten thi danh
        -- so phan biet de map option->UID khong bi de nhau.
        local passives = {}
        if type(pet.Passives) == "table" then
            for _, name in ipairs(pet.Passives) do
                local text = cleanText(name)
                if text ~= "" then
                    table.insert(passives, text)
                end
            end
        end
        local passiveText = #passives > 0 and table.concat(passives, ", ") or "Chua co passive"
        local base = string.format("%s | %s", petDisplayName(pet), passiveText)
        labelCount[base] = (labelCount[base] or 0) + 1
        local option = base
        if labelCount[base] > 1 then
            option = string.format("%s (%d)", base, labelCount[base])
        end
        AutoPassiveMaps.optionToUID[option] = pet.UID
        AutoPassiveMaps.optionByUID[tostring(pet.UID)] = option
        table.insert(values, option)
    end
    if #values == 0 then
        values = {"Khong co pet"}
    end

    local selectedOptions = {}
    local validUIDs = {}
    for _, uid in ipairs(Feature.autoPassiveSelectedUID) do
        local option = AutoPassiveMaps.optionByUID[tostring(uid)]
        if option then
            table.insert(selectedOptions, option)
            validUIDs[tostring(uid)] = true
        end
    end
    local orderedSelection = {}
    for _, uid in ipairs(Feature.autoPassiveSelectedUID) do
        if validUIDs[tostring(uid)] then
            table.insert(orderedSelection, uid)
        end
    end
    Feature.autoPassiveSelectedUID = orderedSelection

    -- Giu dropdown cu khi danh sach khong doi (chong do nhu dropdown clone).
    local passiveDropdownKey = table.concat(values, "\n") .. "|sel|" .. table.concat(selectedOptions, "\n")
    if Feature.autoPassivePetDropdown
        and passiveDropdownKey == Feature.lastPassivePetDropdownKey then
        Feature.updateAutoPassiveStatus()
        return
    end
    Feature.lastPassivePetDropdownKey = passiveDropdownKey

    local dropdownConfig = {
        Title = "Pet roll passive",
        Desc = "Co the chon nhieu pet; tat ca se duoc xu ly trong cung mot dot.",
        Values = values,
        Value = selectedOptions,
        Multi = true,
        AllowNone = true,
        SearchBarEnabled = true,
        MenuWidth = 320,
        Callback = function(value)
            if configApplying or dropdownSyncing then
                return
            end
            local requested = AutoPassive.collectMappedDropdownValues(value, AutoPassiveMaps.optionToUID)
            local requestedByUID = {}
            for _, uid in ipairs(requested) do
                requestedByUID[tostring(uid)] = uid
            end
            local nextSelection = {}
            local seenUID = {}
            local fullSelection = type(value) == "table"
                and value.Title == nil
                and value.Name == nil
            if fullSelection then
                for _, uid in ipairs(Feature.autoPassiveSelectedUID) do
                    local key = tostring(uid)
                    if requestedByUID[key] and not seenUID[key] then
                        seenUID[key] = true
                        table.insert(nextSelection, requestedByUID[key])
                    end
                end
                for _, uid in ipairs(requested) do
                    local key = tostring(uid)
                    if not seenUID[key] then
                        seenUID[key] = true
                        table.insert(nextSelection, uid)
                    end
                end
            else
                local toggledUID = requested[1]
                if toggledUID then
                    local toggledKey = tostring(toggledUID)
                    for _, uid in ipairs(Feature.autoPassiveSelectedUID) do
                        local key = tostring(uid)
                        if key ~= toggledKey and not seenUID[key] then
                            seenUID[key] = true
                            table.insert(nextSelection, uid)
                        end
                    end
                    if not table.find(Feature.autoPassiveSelectedUID, toggledUID) then
                        table.insert(nextSelection, toggledUID)
                    end
                else
                    nextSelection = Feature.autoPassiveSelectedUID
                end
            end
            Feature.autoPassiveSelectedUID = nextSelection
            Feature.updateAutoPassiveStatus()
            saveConfig(true)
        end
    }
    if #selectedOptions > 0 then
        dropdownConfig.Value = selectedOptions
    end
    if Feature.autoPassivePetDropdown then
        pcall(function()
            Feature.autoPassivePetDropdown:Destroy()
        end)
    end
    Feature.autoPassivePetDropdown = AutoPassiveTab:Dropdown(dropdownConfig)
end

function AutoPassive.resolvePassivePointerLocal(passiveId)
    local pointer = passiveId
    local data = PassiveStats[pointer]
    while type(data) == "table" and data.Pointer ~= nil do
        pointer = data.Pointer
        data = PassiveStats[pointer]
    end
    return pointer
end

function AutoPassive.getPassiveRarityName(passiveId)
    local pointer = AutoPassive.resolvePassivePointerLocal(passiveId)
    local data = PassiveStats[pointer] or PassiveStats[passiveId]
    if type(data) ~= "table" then
        return "Unknown"
    end
    if data.Rarity then
        return tostring(data.Rarity)
    end
    local chance = tonumber(data.Chance)
    if not chance then
        return "Unknown"
    end
    if chance <= 0.0005 then return "Divine" end
    if chance <= 0.01 then return "Secret" end
    if chance <= 0.2 then return "Mythical" end
    if chance <= 0.8 then return "Legendary" end
    if chance <= 2 then return "Epic" end
    if chance <= 5 then return "Rare" end
    return "Common"
end

function AutoPassive.isPassiveRollable(data)
    return type(data) == "table"
        and (tonumber(data.Chance) or 0) > 0
        and not data.Hidden
        and not data.Unrollable
end

function AutoPassive.makeAutoPassiveTargetOptions()
    AutoPassiveMaps.optionToPassive = {}
    local entries = {}
    for id, data in pairs(PassiveStats) do
        if AutoPassive.isPassiveRollable(data) then
            local display = cleanText(data.DisplayName or data.Name or id)
            local rarity = AutoPassive.getPassiveRarityName(id)
            local option = string.format("%s | %s | %s", display ~= "" and display or id, rarity, id)
            AutoPassiveMaps.optionToPassive[option] = id
            table.insert(entries, {option = option, display = display, id = tostring(id)})
        end
    end
    table.sort(entries, function(a, b)
        if a.display == b.display then
            return a.id < b.id
        end
        return a.display < b.display
    end)
    local options = {}
    for _, entry in ipairs(entries) do
        table.insert(options, entry.option)
    end
    return options
end

function AutoPassive.makeAutoPassiveRarityOptions()
    local available = {}
    for id, data in pairs(PassiveStats) do
        if AutoPassive.isPassiveRollable(data) then
            local rarity = AutoPassive.getPassiveRarityName(id)
            if rarity ~= "Unknown" then
                available[rarity] = true
            end
        end
    end

    local options = {}
    for rarity in pairs(available) do
        table.insert(options, rarity)
    end
    table.sort(options, function(a, b)
        local orderA = Feature.passiveRarityOrder[a] or 99
        local orderB = Feature.passiveRarityOrder[b] or 99
        if orderA == orderB then
            return a < b
        end
        return orderA < orderB
    end)
    return options
end

function AutoPassive.makeAutoPassiveCategoryOptions()
    AutoPassiveMaps.categoryByOption = { ["Normal"] = "" }
    local seen = { ["Normal"] = true }
    for category in pairs(AutoPassiveModules.PassiveCategories) do
        local text = cleanText(category)
        if text ~= "" and not seen[text] then
            seen[text] = true
            AutoPassiveMaps.categoryByOption[text] = category
        end
    end
    for _, data in pairs(PassiveStats) do
        if type(data) == "table" and data.Category then
            local text = cleanText(data.Category)
            if text ~= "" and not seen[text] then
                seen[text] = true
                AutoPassiveMaps.categoryByOption[text] = data.Category
            end
        end
    end
    local options = {}
    for option in pairs(AutoPassiveMaps.categoryByOption) do
        table.insert(options, option)
    end
    table.sort(options, function(a, b)
        if a == "Normal" then return true end
        if b == "Normal" then return false end
        return a < b
    end)
    return options
end

function AutoPassive.getAutoPassivePet(uid)
    for _, pet in ipairs(getStoreTable("Pets", true)) do
        if type(pet) == "table" and tostring(pet.UID) == tostring(uid) then
            return pet
        end
    end
    return nil
end

function AutoPassive.autoPassiveCategoryValue()
    local category = cleanText(Feature.autoPassiveCategory)
    if category == "" then
        return nil
    end
    return category
end

function AutoPassive.getAutoPassiveTokenInfo()
    local tokenCost = 1
    local tokenId = "PassiveToken"
    local category = AutoPassive.autoPassiveCategoryValue()
    if category then
        local data = AutoPassiveModules.PassiveCategories[category]
        local normalized = category
        if normalized == "Christmas" then
            normalized = "Christmas2"
        elseif normalized == "Easter" then
            normalized = "Easter2"
        elseif normalized == "Summer24" then
            normalized = "Summer25"
        end
        if type(data) == "table" and data.TokenId then
            tokenId = data.TokenId
        else
            tokenId = normalized .. "PassiveToken"
        end
        if type(data) == "table" and data.TokenCost ~= nil then
            tokenCost = tonumber(data.TokenCost) or tokenCost
        end
    end
    local ownsDouble = false
    pcall(function()
        ownsDouble = AutoPassiveModules.MarketplaceHandler.OwnsGamePass("PassiveSpin") == true
    end)
    if ownsDouble then
        tokenCost = tokenCost * 2
    end
    return tokenId, tokenCost
end

function AutoPassive.getAutoPassiveShardInfo(pet)
    local ok, cost, shardId = pcall(function()
        local amount, id = AutoPassiveModules.PassiveAmount.Shards(pet)
        return amount, id
    end)
    if not ok then
        return nil, nil
    end
    cost = tonumber(cost)
    shardId = cleanText(shardId)
    local category = AutoPassive.autoPassiveCategoryValue()
    if category and cost then
        local data = AutoPassiveModules.PassiveCategories[category]
        local normalized = category
        if normalized == "Christmas" then
            normalized = "Christmas2"
        elseif normalized == "Easter" then
            normalized = "Easter2"
        elseif normalized == "Summer24" then
            normalized = "Summer25"
        end
        if normalized == "Christmas2" then
            shardId = "Christmas2025Shard"
        elseif type(data) == "table" and data.ShardId then
            shardId = data.ShardId
        elseif type(data) ~= "table" or data.UseNormalShards ~= true then
            shardId = normalized .. "Shard"
        end
        if type(data) == "table" and data.ShardCostMult then
            cost = math.floor(cost * (tonumber(data.ShardCostMult) or 1))
        end
    end
    return shardId, cost
end

function AutoPassive.getAutoPassiveCurrentValue(uid, slot)
    local pet = AutoPassive.getAutoPassivePet(uid)
    local passives = pet and type(pet.Passives) == "table" and pet.Passives or {}
    return pet, passives[slot]
end

function AutoPassive.autoPassiveMatches(uid)
    local _, current = AutoPassive.getAutoPassiveCurrentValue(uid, Feature.autoPassiveSlot)
    if not current then
        return false
    end
    if Feature.autoPassiveKeepMode == "rarity" then
        local currentRarity = AutoPassive.getPassiveRarityName(current)
        return table.find(Feature.autoPassiveTargetRarities, currentRarity) ~= nil
    end
    return table.find(Feature.autoPassiveTargetPassives, current) ~= nil
end

function AutoPassive.autoPassiveSetToggle(value)
    if not Feature.autoPassiveToggle then
        return
    end
    Feature.autoPassiveToggleUpdating = true
    pcall(function()
        Feature.autoPassiveToggle:Set(value == true)
    end)
    Feature.autoPassiveToggleUpdating = false
end

Feature.updateAutoPassiveStatus = function()
    if not Feature.autoPassiveStatusParagraph then
        return
    end
    local selected = #Feature.autoPassiveSelectedUID
    local target = Feature.autoPassiveKeepMode == "rarity"
        and table.concat(Feature.autoPassiveTargetRarities, ", ")
        or table.concat(Feature.autoPassiveTargetPassives, ", ")
    if target == "" then
        target = "chua chon"
    end
    local currency = Feature.autoPassiveCurrency == "shard" and "Shard" or "PassiveToken"
    local desc = string.format(
        "Pet: %d | Slot: %d | Giu %s: %s | Currency: %s | Roll: %d | Delay: %.1fs | %s",
        selected,
        Feature.autoPassiveSlot,
        Feature.autoPassiveKeepMode == "rarity" and "quality" or "passive",
        target,
        currency,
        Feature.autoPassiveRollCount,
        Feature.autoPassiveRollDelay,
        Feature.autoPassiveLastMessage
    )
    setParagraph(
        Feature.autoPassiveStatusParagraph,
        "Auto Passive: " .. (Feature.autoPassiveEnabled and "BAT" or "TAT"),
        desc
    )
end

function AutoPassive.autoPassiveHasTarget()
    return (Feature.autoPassiveKeepMode == "rarity" and #Feature.autoPassiveTargetRarities > 0)
        or (Feature.autoPassiveKeepMode == "passive" and #Feature.autoPassiveTargetPassives > 0)
end

function AutoPassive.autoPassiveRollOne(uid, reservedCost)
    local pet = AutoPassive.getAutoPassivePet(uid)
    if not pet then
        return false, "pet khong ton tai"
    end
    local selected = {}
    for _, passive in ipairs(Feature.autoPassiveTargetPassives) do
        table.insert(selected, passive)
    end
    local category = AutoPassive.autoPassiveCategoryValue()
    local useTokens = Feature.autoPassiveCurrency == "token"
    local ok, err = pcall(function()
        Remote.RollPassive:FireServer(uid, category, useTokens, Feature.autoPassiveSlot, selected)
    end)
    if not ok then
        return false, tostring(err)
    end
    Feature.autoPassiveRollCount = Feature.autoPassiveRollCount + 1
    Feature.autoPassiveLastMessage = string.format("Da gui roll UID:%s (%s)", tostring(uid), tostring(reservedCost))
    Feature.updateAutoPassiveStatus()
    return true
end

function AutoPassive.autoPassiveRollBatch(jobs, runToken)
    local pickedEvent = Remote:FindFirstChild("PickedPassive")
    local responseCount = 0
    local connection
    if pickedEvent then
        local connected, result = pcall(function()
            return pickedEvent.OnClientEvent:Connect(function()
                responseCount = responseCount + 1
            end)
        end)
        if connected then
            connection = result
        end
    end

    local fired = 0
    for _, jobData in ipairs(jobs) do
        if not alive() or not Feature.autoPassiveEnabled or runToken ~= Feature.autoPassiveRunToken then
            break
        end
        local ok, result = AutoPassive.autoPassiveRollOne(jobData.uid, jobData.cost)
        if ok then
            fired = fired + 1
        else
            Feature.autoPassiveLastMessage = "Loi UID:" .. tostring(jobData.uid) .. " " .. tostring(result)
            Feature.updateAutoPassiveStatus()
        end
    end

    if connection and fired > 0 then
        local deadline = os.clock() + 1.5
        while responseCount < fired
            and alive()
            and Feature.autoPassiveEnabled
            and runToken == Feature.autoPassiveRunToken
            and os.clock() < deadline do
            Feature.autoPassiveLastMessage = string.format(
                "Dang cho ket qua batch %d/%d",
                responseCount,
                fired
            )
            Feature.updateAutoPassiveStatus()
            task.wait()
        end
    end
    if connection then
        pcall(function()
            connection:Disconnect()
        end)
    end
    if fired > 0 then
        Feature.autoPassiveLastMessage = string.format(
            "Da gui %d roll cung luc; nhan %d ket qua",
            fired,
            responseCount
        )
        Feature.updateAutoPassiveStatus()
        task.wait()
    end
    return fired, responseCount
end

function AutoPassive.stopAutoPassive(reason)
    Feature.autoPassiveEnabled = false
    Feature.autoPassiveRunToken = Feature.autoPassiveRunToken + 1
    AutoPassive.autoPassiveSetToggle(false)
    if reason then
        Feature.autoPassiveLastMessage = reason
        notifyStatus("Auto Passive", reason)
    end
    Feature.updateAutoPassiveStatus()
end

function AutoPassive.startAutoPassive()
    if Feature.autoPassiveBusy then
        return
    end
    if not AutoPassive.autoPassiveHasTarget() then
        AutoPassive.stopAutoPassive("Hay chon passive hoac pham chat can giu.")
        return
    end
    if #Feature.autoPassiveSelectedUID == 0 then
        AutoPassive.stopAutoPassive("Hay chon it nhat 1 pet.")
        return
    end

    Feature.autoPassiveRunToken = Feature.autoPassiveRunToken + 1
    local runToken = Feature.autoPassiveRunToken
    Feature.autoPassiveBusy = true
    task.spawn(function()
        while alive() and Feature.autoPassiveEnabled and runToken == Feature.autoPassiveRunToken do
            local jobs = {}
            local budget = {}
            local itemData = getStoreTable("Items", true)
            local tokenId, tokenCost = AutoPassive.getAutoPassiveTokenInfo()
            for _, uid in ipairs(Feature.autoPassiveSelectedUID) do
                if not AutoPassive.autoPassiveMatches(uid) then
                    local pet = AutoPassive.getAutoPassivePet(uid)
                    local itemId = tokenId
                    local cost = tokenCost
                    if Feature.autoPassiveCurrency == "shard" then
                        itemId, cost = AutoPassive.getAutoPassiveShardInfo(pet)
                    end
                    if pet and itemId and cost and cost > 0 then
                        budget[itemId] = budget[itemId]
                            or (tonumber(itemData[itemId]) or 0)
                        if budget[itemId] >= cost then
                            budget[itemId] = budget[itemId] - cost
                            table.insert(jobs, {uid = uid, cost = cost, itemId = itemId})
                        end
                    end
                end
            end

            if #jobs == 0 then
                local allKept = true
                for _, uid in ipairs(Feature.autoPassiveSelectedUID) do
                    if not AutoPassive.autoPassiveMatches(uid) then
                        allKept = false
                        break
                    end
                end
                if allKept then
                    AutoPassive.stopAutoPassive("Tat ca pet da dat muc tieu.")
                else
                    AutoPassive.stopAutoPassive("Het currency de roll.")
                end
                break
            end

            AutoPassive.autoPassiveRollBatch(jobs, runToken)
            task.wait()
        end
        Feature.autoPassiveBusy = false
        Feature.updateAutoPassiveStatus()
    end)
end

scanPets = function()
    refreshMachineList()
    rebuildPetDropdowns()
    if Feature.rebuildAutoPassivePetDropdown then
        Feature.rebuildAutoPassivePetDropdown()
    end
    updateOccupiedInfo()
    local pets = getPets()
    local occupied = getOccupiedMachineUIDs()
    local occupiedCount = 0
    for _ in pairs(occupied) do
        occupiedCount = occupiedCount + 1
    end
    notifyStatus(
        "Da quet tui pet",
        string.format("%d pet co the clone; loai %d UID dang nam trong may.", #pets, occupiedCount)
    )
end

local function updateMachineStatus()
    refreshSelectedPetMap()
    local cloneData = getStoreTable("CloneMachineData", true)
    local now = getGameTime()
    local multiplier = getTimeMultiplier()
    local lines = {}

    for index, machine in ipairs(machineList) do
        local desiredUID = selectedUID[index]
        local desiredPet = desiredUID and petByUID[tostring(desiredUID)]
        local record = type(cloneData[machine.id]) == "table" and cloneData[machine.id] or nil

        local finishTime = record and tonumber(record.FinishTime)
        if finishTime then
            local remainingGame = math.max(0, finishTime - now)
            local remainingReal = remainingGame / multiplier
            local recordPet = record.UID and petByUID[tostring(record.UID)]
            local recordName = recordPet and petDisplayName(recordPet) or ("UID " .. tostring(record.UID))
            local recordLabel = string.format("%s (UID:%s)", recordName, tostring(record.UID))

            if remainingGame > 0 then
                table.insert(lines, string.format(
                    "%s | Co pet: %s | Dang clone | game %s | real %s",
                    machine.id,
                    recordLabel,
                    formatDuration(remainingGame),
                    formatDuration(remainingReal)
                ))
            else
                table.insert(lines, string.format(
                    "%s | Co pet: %s | XONG | san sang rut",
                    machine.id,
                    recordLabel
                ))
            end
        elseif desiredPet then
            local duration = cloneDuration(desiredPet) or 0
            table.insert(lines, string.format(
                "%s | Trong may: khong | Muc tieu: %s (UID:%s) | game %s | real %s",
                machine.id,
                petDisplayName(desiredPet),
                tostring(desiredPet.UID),
                formatDuration(duration),
                formatDuration(duration / multiplier)
            ))
        else
            table.insert(lines, machine.id .. " | Khong co pet trong may | chua gan pet")
        end
    end

    if #lines == 0 then
        table.insert(lines, "Khong tim thay 4 CloneMachine.")
    end

    local token = getStoreTable("Items", true).CloneToken or 0
    setParagraph(statusParagraph, "Trang thai may | Time x" .. string.format("%.2f", multiplier), table.concat(lines, "\n"))
    setParagraph(infoParagraph, "Auto Clone: " .. (autoEnabled and "BAT" or "TAT"), "GameTime: " .. tostring(now) .. " | CloneToken: " .. tostring(token))
end

local function canAct(machineId, action)
    local current = lastAction[machineId]
    if current and os.clock() < current.expiresAt then
        return false
    end
    lastAction[machineId] = {
        action = action,
        expiresAt = os.clock() + 4
    }
    return true
end

local function setLocalClone(machineId, uid, duration)
    local data = getStoreTable("CloneMachineData")
    data[machineId] = {
        UID = uid,
        FinishTime = math.floor(getGameTime() + duration)
    }
    setStoreValue("CloneMachineData", data, 3)

    local items = getStoreTable("Items")
    local tokens = (tonumber(items.CloneToken or 0) or 0) - 1
    items.CloneToken = tokens > 0 and tokens or nil
    setStoreValue("Items", items, 1)
end

local function setLocalWithdraw(machineId)
    local data = getStoreTable("CloneMachineData")
    data[machineId] = nil
    setStoreValue("CloneMachineData", data, 1)
end

local function captureLocation()
    local character = LocalPlayer.Character
    local root = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
    if not root then
        return nil
    end
    local ok, cframe = pcall(function()
        return root.CFrame
    end)
    if not ok or not cframe then
        return nil
    end
    return {
        world = tostring(getPlayerValue("World", "")),
        cframe = cframe
    }
end

local function travelToWorld(world)
    world = tostring(world or "")
    if world == "" then
        return false
    end
    if tostring(getPlayerValue("World", "")) == world then
        return true
    end
    if travelBusy then
        return false
    end

    travelBusy = true
    local success = false
    local ok, spawnPoint = pcall(function()
        return AttemptTravel:InvokeServer(world, nil, nil)
    end)

    if ok and (typeof(spawnPoint) == "Vector3" or spawnPoint == true) then
        if typeof(spawnPoint) == "Vector3" then
            local character = LocalPlayer.Character
            if character then
                pcall(function()
                    character:PivotTo(CFrame.new(spawnPoint + Vector3.new(0, 3, 0)))
                end)
            end
            pcall(function()
                LocalPlayer:RequestStreamAroundAsync(spawnPoint, 8)
            end)
        end

        local bindable = ReplicatedStorage:FindFirstChild("Bindable")
        local teleported = bindable and bindable:FindFirstChild("Teleported")
        if teleported then
            pcall(function()
                teleported:Fire()
            end)
        end

        for _ = 1, 30 do
            if tostring(getPlayerValue("World", "")) == world then
                success = true
                break
            end
            task.wait(0.1)
        end
        if not success and typeof(spawnPoint) == "Vector3" then
            success = true
        end
    end

    travelBusy = false
    if not success then
        notifyStatus("Teleport loi", "Khong toi duoc map " .. world .. ".")
    end
    return success
end

Feature.fallenStarFarm = {
    enabled = false,
    interval = 1,
    nextScanAt = 0,
    lastSendAt = 0,
    target = nil,
    targetWorld = nil,
    seen = setmetatable({}, {__mode = "k"}),
    lastScanCount = 0,
    lastEventActive = false,
    lastMessage = "Chua quet.",
    lastChatAt = 0,
    farmStarted = false,
    previousLocation = nil,
    previousTeamIndex = nil
}

function Feature.fallenStarGetMeteorShowerValue()
    local multipliers = ReplicatedStorage:FindFirstChild("Multipliers")
    local value = multipliers and multipliers:FindFirstChild("MeteorShower")
    return value and value:IsA("BoolValue") and value.Value == true or false
end

function Feature.fallenStarGetWorldForInstance(instance)
    local worlds = workspace:FindFirstChild("Worlds")
    if not worlds or not instance then
        return nil
    end
    local current = instance
    while current and current.Parent and current.Parent ~= worlds do
        current = current.Parent
    end
    return current and current.Parent == worlds and current or nil
end

function Feature.fallenStarGetInstancePosition(instance)
    if not instance then
        return nil
    end
    if instance:IsA("BasePart") then
        return instance.Position
    end
    local root = Feature.getRoot(instance)
    if root then
        return root.Position
    end
    local ok, pivot = pcall(function()
        return instance:GetPivot()
    end)
    return ok and pivot and pivot.Position or nil
end

function Feature.fallenStarHasTargetEvidence(instance)
    if not instance then
        return false
    end
    local parentName = instance.Parent and string.lower(instance.Parent.Name) or ""
    if parentName == "enemies" or parentName == "newenemies" then
        return true
    end
    for _, name in ipairs({"Health", "MaxHealth", "Destroyable", "Targetable", "FallenStar"}) do
        if instance:FindFirstChild(name, true) then
            return true
        end
    end
    local ok, attributes = pcall(function()
        return instance:GetAttributes()
    end)
    if ok and type(attributes) == "table" then
        for name in pairs(attributes) do
            local lowered = string.lower(tostring(name))
            if string.find(lowered, "health", 1, true)
                or string.find(lowered, "target", 1, true)
                or string.find(lowered, "destroy", 1, true) then
                return true
            end
        end
    end
    return false
end

function Feature.fallenStarIsCandidate(instance)
    if not instance or not (instance:IsA("Model") or instance:IsA("BasePart")) then
        return false
    end
    local world = Feature.fallenStarGetWorldForInstance(instance)
    if not world then
        return false
    end
    local name = string.lower(instance.Name):gsub("[%s_%-]", "")
    if name ~= "fallenstar" and name ~= "meteor" and name ~= "meteorite"
        and name ~= "stardrop" and name ~= "star" then
        return false
    end
    local taggedEgg = false
    pcall(function()
        taggedEgg = CollectionService:HasTag(instance, "EggPurchase")
    end)
    if taggedEgg or not Feature.fallenStarHasTargetEvidence(instance) then
        return false
    end
    return Feature.fallenStarGetInstancePosition(instance) ~= nil
end

function Feature.fallenStarPostChat(message)
    local now = os.clock()
    if now - Feature.fallenStarFarm.lastChatAt < 1 then
        return
    end
    Feature.fallenStarFarm.lastChatAt = now
    local sent = false
    pcall(function()
        local localChat = ReplicatedStorage:FindFirstChild("SendLocalChatMessage")
        if localChat and localChat:IsA("BindableEvent") then
            localChat:Fire(message, Color3.fromRGB(255, 235, 80))
            sent = true
        end
    end)
    if sent then
        return
    end
    pcall(function()
        local service = game:GetService("TextChatService")
        local channel = service:FindFirstChild("TextChannels")
            and service.TextChannels:FindFirstChild("RBXGeneral")
        if channel then
            channel:DisplaySystemMessage("<font color=\"#FFE750\"><b>" .. tostring(message) .. "</b></font>")
        end
    end)
end

function Feature.fallenStarFarm.scan(force)
    if not Feature.fallenStarFarm.enabled then
        return {}
    end
    local now = os.clock()
    if not force and now < Feature.fallenStarFarm.nextScanAt then
        return nil
    end
    Feature.fallenStarFarm.nextScanAt = now + math.max(0.5, tonumber(Feature.fallenStarFarm.interval) or 1)
    local active = Feature.fallenStarGetMeteorShowerValue()
    Feature.fallenStarFarm.lastEventActive = active
    if not active then
        Feature.fallenStarFarm.target = nil
        Feature.fallenStarFarm.targetWorld = nil
        Feature.fallenStarFarm.lastScanCount = 0
        Feature.fallenStarFarm.lastMessage = "Dang cho Star Shower."
        return {}
    end

    local worlds = workspace:FindFirstChild("Worlds")
    local candidates = {}
    if worlds then
        for _, world in ipairs(worlds:GetChildren()) do
            for _, instance in ipairs(world:GetDescendants()) do
                if Feature.fallenStarIsCandidate(instance) then
                    local position = Feature.fallenStarGetInstancePosition(instance)
                    if position then
                        local record = {instance = instance, world = world, position = position}
                        table.insert(candidates, record)
                        if not Feature.fallenStarFarm.seen[instance] then
                            Feature.fallenStarFarm.seen[instance] = true
                            Feature.fallenStarPostChat(string.format(
                                "Fallen Star spawn tai map %s | X:%d Y:%d Z:%d",
                                world.Name,
                                math.floor(position.X + 0.5),
                                math.floor(position.Y + 0.5),
                                math.floor(position.Z + 0.5)
                            ))
                        end
                    end
                end
            end
        end
    end
    Feature.fallenStarFarm.lastScanCount = #candidates
    local character = LocalPlayer.Character
    local root = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
    table.sort(candidates, function(a, b)
        if not root then
            return a.world.Name < b.world.Name
        end
        return (a.position - root.Position).Magnitude < (b.position - root.Position).Magnitude
    end)
    local selected = candidates[1]
    Feature.fallenStarFarm.target = selected and selected.instance or nil
    Feature.fallenStarFarm.targetWorld = selected and selected.world or nil
    Feature.fallenStarFarm.lastMessage = selected
        and string.format("Tim thay %d star | %s", #candidates, selected.world.Name)
        or "Khong thay Fallen Star."
    return candidates
end

function Feature.fallenStarFarm.captureContext()
    if Feature.fallenStarFarm.farmStarted then
        return
    end
    Feature.fallenStarFarm.previousLocation = captureLocation()
    Feature.fallenStarFarm.previousTeamIndex = nil
    local equipped = getStoreTable("EquippedPets", true)
    for index, team in ipairs(getStoreTable("PetTeams", true)) do
        local uids = type(team) == "table" and type(team.UIDs) == "table" and team.UIDs or nil
        if uids then
            local matched = true
            local hasPet = false
            for slot, uid in pairs(uids) do
                if tostring(uid) ~= "" then
                    hasPet = true
                    local actual = equipped[tostring(slot)] or equipped[slot]
                    if tostring(actual or "") ~= tostring(uid) then
                        matched = false
                        break
                    end
                end
            end
            if matched and hasPet then
                Feature.fallenStarFarm.previousTeamIndex = index
                break
            end
        end
    end
    Feature.fallenStarFarm.previousTeamIndex = Feature.fallenStarFarm.previousTeamIndex
        or tonumber(dungeonSelection.normalTeamIndex)
    Feature.fallenStarFarm.farmStarted = true
end

function Feature.fallenStarFarm.restoreContext()
    if not Feature.fallenStarFarm.farmStarted then
        return
    end
    local location = Feature.fallenStarFarm.previousLocation
    local teamIndex = Feature.fallenStarFarm.previousTeamIndex
    Feature.fallenStarFarm.farmStarted = false
    Feature.fallenStarFarm.previousLocation = nil
    Feature.fallenStarFarm.previousTeamIndex = nil

    if teamIndex then
        pcall(function()
            DungeonFarm.ensureTeamApplied(teamIndex, "restore Fallen Star")
        end)
    end
    if location then
        pcall(function()
            if travelToWorld(location.world) then
                task.wait(0.2)
                local character = LocalPlayer.Character
                if character then
                    character:PivotTo(location.cframe)
                end
            end
        end)
    end
end

function Feature.fallenStarFarm.updateStatus()
    if not Feature.autoFallenStarStatusParagraph then
        return
    end
    if not Feature.fallenStarFarm.enabled then
        setParagraph(Feature.autoFallenStarStatusParagraph, "Auto Fallen Star: TAT", "Bat toggle de theo doi Star Shower.")
        return
    end
    local eventText = Feature.fallenStarFarm.lastEventActive and "BAT" or "CHO"
    local targetText = Feature.fallenStarFarm.target and Feature.fallenStarFarm.target.Parent
        and (tostring(Feature.fallenStarFarm.targetWorld and Feature.fallenStarFarm.targetWorld.Name or "?") .. " / " .. Feature.fallenStarFarm.target.Name)
        or "Khong co"
    setParagraph(
        Feature.autoFallenStarStatusParagraph,
        "Auto Fallen Star: BAT | Event: " .. eventText,
        string.format("Tim thay: %d | Target: %s | %s", Feature.fallenStarFarm.lastScanCount, targetText, Feature.fallenStarFarm.lastMessage)
    )
end

function Feature.fallenStarFarm.step()
    if not Feature.fallenStarFarm.enabled or dungeonActive or tostring(getPlayerValue("World", "")) == "Dungeon" then
        return
    end
    local candidates = Feature.fallenStarFarm.scan(false)
    if candidates == nil then
        candidates = {}
    end
    local target = Feature.fallenStarFarm.target
    local world = Feature.fallenStarFarm.targetWorld
    if not target or not target.Parent or not world then
        Feature.fallenStarFarm.restoreContext()
        Feature.fallenStarFarm.updateStatus()
        return
    end
    if not Feature.fallenStarFarm.farmStarted then
        Feature.fallenStarFarm.captureContext()
        local selectedTeam = math.max(1, math.floor(tonumber(dungeonSelection.fallenStarTeamIndex) or 1))
        if not DungeonFarm.ensureTeamApplied(selectedTeam, "Fallen Star") then
            Feature.fallenStarFarm.lastMessage = "Khong doi duoc team Fallen Star."
            Feature.fallenStarFarm.restoreContext()
            Feature.fallenStarFarm.updateStatus()
            return
        end
    end
    if tostring(getPlayerValue("World", "")) ~= world.Name then
        travelToWorld(world.Name)
        Feature.fallenStarFarm.nextScanAt = 0
        Feature.fallenStarFarm.updateStatus()
        return
    end
    local position = getInstancePosition(target)
    if not position then
        Feature.fallenStarFarm.target = nil
        Feature.fallenStarFarm.updateStatus()
        return
    end
    local character = LocalPlayer.Character
    local root = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
    if root and (root.Position - position).Magnitude > 35 then
        pcall(function()
            character:PivotTo(CFrame.new(position + Vector3.new(0, 5, 0)))
        end)
    end
    local sendPet = Bindable:FindFirstChild("SendPet")
    if sendPet and os.clock() - Feature.fallenStarFarm.lastSendAt >= 1 then
        Feature.fallenStarFarm.lastSendAt = os.clock()
        pcall(function()
            sendPet:Fire(target, true, true)
        end)
    end
    Feature.fallenStarFarm.updateStatus()
end

function Feature.fallenStarFarm.stop()
    Feature.fallenStarFarm.restoreContext()
    Feature.fallenStarFarm.target = nil
    Feature.fallenStarFarm.targetWorld = nil
    Feature.fallenStarFarm.lastScanCount = 0
    Feature.fallenStarFarm.lastMessage = "Da dung."
    Feature.fallenStarFarm.seen = setmetatable({}, {__mode = "k"})
    Feature.fallenStarFarm.updateStatus()
end
local function findTaggedMachine(machineId)
    for _, machine in ipairs(getTaggedMachines()) do
        local ok, id = pcall(function()
            return machine:GetAttribute("CloneMachineId")
        end)
        if ok and tostring(id) == tostring(machineId) then
            return machine
        end
    end
    return nil
end

local function moveToMachine(machine)
    if not machine or not travelToWorld(machine.world) then
        return false
    end

    local model = findTaggedMachine(machine.id) or machine.instance
    if not model then
        return false
    end

    local character = LocalPlayer.Character
    if not character then
        return false
    end

    local ok, pivot = pcall(function()
        return model:GetPivot()
    end)
    if not ok or not pivot then
        return false
    end
    local dest = CFrame.new(pivot.Position + Vector3.new(0, 4, 0))
    pcall(function()
        character:PivotTo(dest)
    end)
    -- Cho server nhan vi tri moi truoc khi Fire: server tu choi nap pet tu
    -- xa (0.35s cu khong du de replicate, nhat la khi doi world). Poll toi
    -- khi dung gan may (<=25), toi da 3 giay; giu chan neu bi keo ve.
    local deadline = os.clock() + 3
    while os.clock() < deadline do
        local char = LocalPlayer.Character
        local root = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
        local pos = nil
        pcall(function()
            pos = root and root.Position or nil
        end)
        if pos and (pos - pivot.Position).Magnitude <= 25 then
            return true
        end
        if char then
            pcall(function()
                char:PivotTo(dest)
            end)
        end
        task.wait(0.25)
    end
    return false
end

local function restoreInitialLocation()
    local location = initialLocation
    if not location then
        return false
    end
    if not travelToWorld(location.world) then
        return false
    end
    task.wait(0.2)
    local character = LocalPlayer.Character
    if character then
        pcall(function()
            character:PivotTo(location.cframe)
        end)
    end
    return true
end

local function stopAutoAndReturn()
    autoEnabled = false
    task.spawn(function()
        for _ = 1, 50 do
            if not travelBusy then
                break
            end
            task.wait(0.1)
        end
        protectedCall("Restore initial location", restoreInitialLocation)
    end)
end

local function doWithdraw(machineId)
    if not canAct(machineId, "withdraw") then
        return false
    end

    local ok, err = pcall(function()
        AttemptWithdraw:FireServer(machineId)
        setLocalWithdraw(machineId)
    end)

    if not ok then
        lastAction[machineId] = nil
        notifyStatus("Loi rut pet", tostring(err))
        return false
    end

    return true
end

local function doClone(machineId, pet)
    local duration = cloneDuration(pet)
    if not duration then
        return false
    end

    local items = getStoreTable("Items", true)
    if (tonumber(items.CloneToken) or 0) < 1 then
        return false
    end

    if not canAct(machineId, "clone") then
        return false
    end

    local ok, err = pcall(function()
        AttemptClone:FireServer(pet.UID, machineId)
        setLocalClone(machineId, pet.UID, duration)
    end)

    if not ok then
        lastAction[machineId] = nil
        notifyStatus("Loi nap pet", tostring(err))
        return false
    end

    -- Xac minh server da nhan (poll authoritative toi da 2s). That bai thi
    -- mo khoa cho thu lai ngay vong sau thay vi khoa 4s nhu truoc.
    local verified = false
    local deadline = os.clock() + 2
    while os.clock() < deadline do
        local data = getStoreTable("CloneMachineData", true)
        local record = type(data) == "table" and type(data[machineId]) == "table" and data[machineId] or nil
        if record and tostring(record.UID) == tostring(pet.UID) then
            verified = true
            break
        end
        task.wait(0.25)
    end
    if not verified then
        lastAction[machineId] = nil
    end
    return verified
end

local function autoStep()
    if not autoEnabled then
        return
    end

    refreshMachineList()
    refreshSelectedPetMap()

    local cloneData = getStoreTable("CloneMachineData", true)
    local now = getGameTime()
    local occupiedBy = {}

    for machineId, record in pairs(cloneData) do
        if type(record) == "table" and record.UID then
            occupiedBy[tostring(record.UID)] = tostring(machineId)
        end
    end

    local items = getStoreTable("Items", true)
    local tokenCount = tonumber(items.CloneToken) or 0
    local tokenWarningShown = false
    local visitedMachine = false

    for index, machine in ipairs(machineList) do
        if not autoEnabled then
            break
        end

        local desiredUID = selectedUID[index]
        local desiredPet = desiredUID and petByUID[tostring(desiredUID)]
        local record = type(cloneData[machine.id]) == "table" and cloneData[machine.id] or nil

        local finishTime = record and tonumber(record.FinishTime)
        if desiredPet and record and finishTime then
            local remaining = finishTime - now
            if remaining <= 0 then
                doWithdraw(machine.id)
            end
        elseif desiredPet and not record then
            local owner = occupiedBy[tostring(desiredPet.UID)]
            if owner and owner ~= machine.id then
                local ownerRecord = type(cloneData[owner]) == "table" and cloneData[owner] or nil
                if ownerRecord and tonumber(ownerRecord.FinishTime) and tonumber(ownerRecord.FinishTime) <= now then
                    local ownerMachine = machineById[tostring(owner)]
                    if ownerMachine then
                        doWithdraw(owner)
                    end
                end
            elseif tokenCount > 0 then
                if moveToMachine(machine) then
                    visitedMachine = true
                    if doClone(machine.id, desiredPet) then
                        tokenCount = tokenCount - 1
                        occupiedBy[tostring(desiredPet.UID)] = machine.id
                    end
                end
            elseif not tokenWarningShown then
                tokenWarningShown = true
                notifyStatus("Het CloneToken", "Khong con token de nap pet.")
            end
        end
    end

    if visitedMachine then
        restoreInitialLocation()
    end
end

function Feature.getRoot(model)
    if not model then
        return nil
    end
    return model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("UpperTorso")
        or model.PrimaryPart
end

function Feature.getHealth(model)
    local humanoid = model and model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        return tonumber(humanoid.Health) or 0, tonumber(humanoid.MaxHealth) or 0
    end

    local healthValue = model and model:FindFirstChild("Health", true)
    local maxHealthValue = model and model:FindFirstChild("MaxHealth", true)
    -- Enemy UI can also contain a Frame named Health; only read value-bearing objects.
    local health = healthValue and (healthValue:IsA("NumberValue") or healthValue:IsA("IntValue"))
        and tonumber(healthValue.Value)
    local maxHealth = maxHealthValue and (maxHealthValue:IsA("NumberValue") or maxHealthValue:IsA("IntValue"))
        and tonumber(maxHealthValue.Value)
    if health then
        return health, maxHealth or health
    end
    return nil, nil
end

function Feature.collectContainers()
    local containers = {}
    local seen = {}
    local function add(container)
        if container and not seen[container] then
            seen[container] = true
            table.insert(containers, container)
        end
    end

    local worldName = tostring(getPlayerValue("World", ""))
    local worlds = workspace:FindFirstChild("Worlds")
    local world = worlds and worlds:FindFirstChild(worldName)
    if world then
        add(world:FindFirstChild("Enemies"))
        add(world:FindFirstChild("NewEnemies"))
    end
    add(workspace:FindFirstChild("Enemies"))
    add(workspace:FindFirstChild("NewEnemies"))

    return containers
end

function Feature.getTargets()
    local character = LocalPlayer.Character
    local playerRoot = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
    if not playerRoot then
        return {}
    end

    local targets = {}
    local seen = {}
    for _, container in ipairs(Feature.collectContainers()) do
        for _, model in ipairs(container:GetChildren()) do
            if model:IsA("Model") and not seen[model] then
                seen[model] = true
                local root = Feature.getRoot(model)
                local health, maxHealth = Feature.getHealth(model)
                local untouchable = false
                pcall(function()
                    untouchable = CollectionService:HasTag(model, "Untouchable")
                end)
                if root and health and health > 0 and not untouchable then
                    table.insert(targets, {
                        model = model,
                        root = root,
                        distance = (root.Position - playerRoot.Position).Magnitude,
                        health = health,
                        maxHealth = maxHealth or health
                    })
                end
            end
        end
    end
    return targets
end

function Feature.selectTarget()
    local targets = Feature.getTargets()
    local selected
    for _, candidate in ipairs(targets) do
        if not selected then
            selected = candidate
        elseif Feature.autoFarmMode == Feature.MODE_LOWEST_HEALTH then
            if candidate.health < selected.health
                or (candidate.health == selected.health and candidate.distance < selected.distance) then
                selected = candidate
            end
        elseif Feature.autoFarmMode == Feature.MODE_HIGHEST_HEALTH then
            if candidate.health > selected.health
                or (candidate.health == selected.health and candidate.distance < selected.distance) then
                selected = candidate
            end
        elseif candidate.distance < selected.distance then
            selected = candidate
        end
    end
    return selected
end

function Feature.withdrawPets()
    Feature.autoFarmTarget = nil
    Feature.autoFarmLastSend = 0
    local event = Bindable:FindFirstChild("WithdrawPets")
    if event then
        protectedCall("Withdraw auto farm pets", function()
            event:Fire()
        end)
    end
end

function Feature.updateStatus()
    if not Feature.autoFarmStatusParagraph then
        return
    end
    if not Feature.autoFarmEnabled then
        setParagraph(Feature.autoFarmStatusParagraph, "Auto Farm: TAT", "Chua bat auto farm.")
        return
    end

    local target = Feature.autoFarmTarget
    if target and target.Parent and target.root then
        local playerRoot = LocalPlayer.Character
            and (LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or LocalPlayer.Character.PrimaryPart)
        local distance = playerRoot and (target.root.Position - playerRoot.Position).Magnitude or 0
        local health, maxHealth = Feature.getHealth(target.model)
        setParagraph(
            Feature.autoFarmStatusParagraph,
            "Auto Farm: BAT",
            string.format(
                "Mode: %s | Target: %s | Cach: %.1f | HP: %s/%s",
                Feature.modeLabel(Feature.autoFarmMode),
                tostring(target.model.Name),
                distance,
                tostring(math.floor(health or target.health)),
                tostring(math.floor(maxHealth or target.maxHealth))
            )
        )
    else
        setParagraph(Feature.autoFarmStatusParagraph, "Auto Farm: BAT", "Dang tim muc tieu...")
    end
end

function Feature.step()
    if not Feature.autoFarmEnabled or dungeonActive or Feature.autoFallenStarEnabled then
        return
    end

    local selected = Feature.selectTarget()
    if not selected then
        Feature.autoFarmTarget = nil
        Feature.updateStatus()
        return
    end

    local now = os.clock()
    local targetChanged = not Feature.autoFarmTarget or Feature.autoFarmTarget.model ~= selected.model
    if targetChanged or now - Feature.autoFarmLastSend >= 2 then
        local sendEvent = Bindable:FindFirstChild("SendPet")
        if not sendEvent then
            reportRuntimeError("Auto farm send", "Bindable.SendPet khong ton tai")
            return
        end
        local ok = protectedCall("Auto farm send", function()
            sendEvent:Fire(selected.model, true, true)
        end)
        if ok then
            Feature.autoFarmTarget = selected
            Feature.autoFarmLastSend = now
        end
    else
        Feature.autoFarmTarget = selected
    end
    Feature.updateStatus()
end

function Feature.isDropModel(model)
    if not model
        or not model:IsA("Model")
        or not model.PrimaryPart
        or model.Name == "MovingItem" then
        return false
    end

    local base = model:FindFirstChild("Base")
    if not base then
        return false
    end

    if model:FindFirstChild("ItemPart") then
        return true
    end
    if model:FindFirstChild("Item") then
        return true
    end
    if model:FindFirstChild("Core") and model:FindFirstChild("Aura") then
        return true
    end

    local coin = model:FindFirstChild("Coin")
    if coin and not model:FindFirstChild("Glow") then
        return true
    end
    return false
end

function Feature.collectDropsStep()
    if not Feature.autoCollectDropsEnabled then
        return
    end

    local character = LocalPlayer.Character
    local playerRoot = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
    local effects = workspace:FindFirstChild("Effects")
    if not playerRoot or not effects then
        return
    end

    for _, model in ipairs(effects:GetChildren()) do
        if Feature.isDropModel(model) and not Feature.mainSeenDrops[model] then
            local moved = pcall(function()
                model:PivotTo(playerRoot.CFrame)
            end)
            if not moved then
                moved = pcall(function()
                    model:SetPrimaryPartCFrame(playerRoot.CFrame)
                end)
            end
            if moved then
                Feature.mainSeenDrops[model] = true
            end
        end
    end
end

function Feature.applyTpPet()
    -- Spoof the Lightspeed (SummerTime) passive effect "Teleport" so pets use
    -- the game's own instant-teleport path (LocalPetHandler teleports pets
    -- straight to targets farther than 30 studs instead of walking over).
    -- The handler reads the effect once when each pet spawns, so the toggle
    -- applies to pets sent out after enabling (swap team / enter dungeon to
    -- respawn pets already out).
    local module = nil
    local ok = pcall(function()
        local folder = ReplicatedStorage:WaitForChild("ModuleScripts")
        module = folder:WaitForChild("HasPassive")
        module = require(module)
    end)
    if not ok or type(module) ~= "table" then
        return false
    end
    if Feature.tpPetEnabled then
        if not module.__tpPetWrapped then
            if type(module.GetEffect) ~= "function" then
                return false
            end
            module.__tpPetOriginal = module.GetEffect
            local original = module.GetEffect
            module.GetEffect = function(pet, name, ...)
                if name == "Teleport" then
                    return true
                end
                return original(pet, name, ...)
            end
            module.__tpPetWrapped = true
        end
    elseif module.__tpPetWrapped then
        -- Original is stored on the module itself so any reload generation
        -- can unwrap cleanly even after its own locals were reset.
        if type(module.__tpPetOriginal) == "function" then
            module.GetEffect = module.__tpPetOriginal
        end
        module.__tpPetOriginal = nil
        module.__tpPetWrapped = nil
    end
    return true
end

function Feature.getUltDmgModules()
    if Feature.ultDmgModules then
        return Feature.ultDmgModules
    end
    local ok, mods = pcall(function()
        local moduleScripts = ReplicatedStorage:WaitForChild("ModuleScripts")
        local handler = LocalPlayer:WaitForChild("PlayerScripts")
            :WaitForChild("StarterPlayerScriptsFolder")
            :WaitForChild("LocalPetHandler")
        return {
            StatCalc = require(moduleScripts:WaitForChild("StatCalc")),
            EnemyStats = require(moduleScripts:WaitForChild("EnemyStats")),
            HasPassive = require(moduleScripts:WaitForChild("HasPassive")),
            EnemyDamagedEffect = require(handler:WaitForChild("EnemyDamagedEffect")),
        }
    end)
    if ok and type(mods) == "table" then
        Feature.ultDmgModules = mods
        return mods
    end
    return nil
end

function Feature.showUltSupplementDamage(pet, enemy)
    -- Supplement hits are server-only, so mirror the game's own client visual
    -- (pet_attack): same damage formula, same delayed damage number + sound.
    if not (pet and pet.Parent and enemy and enemy.Parent) then
        return
    end
    local mods = Feature.getUltDmgModules()
    if not mods then
        return
    end
    local ok, damage = pcall(function()
        local fake = mods.StatCalc.GetFakeDataFromModel(pet)
        local petsData = getStoreTable("Pets", true)
        local world = tostring(getPlayerValue("World", ""))
        local amount = mods.StatCalc.GetStat("Attack", fake, world, LocalPlayer, petsData)
            * GetMultiplier.Dmg(LocalPlayer)
        local stats = mods.EnemyStats[enemy.Name]
        if stats and (stats.Boss or stats.RaidBoss) then
            local mult = mods.HasPassive.GetEffect(pet, "BossDamage")
            if mult ~= nil then
                amount = amount * mult
            end
        end
        return amount
    end)
    if not ok or tonumber(damage) == nil then
        return
    end
    task.delay(0.3, function()
        pcall(function()
            if pet.Parent and pet:FindFirstChild("Data") and pet.Data.Attacking.Value == enemy then
                mods.EnemyDamagedEffect.DoEffect(enemy, damage)
            end
        end)
    end)
end

function Feature.attackWhileUltStep()
    -- The game pauses normal hits while a pet casts its ability (combat_tick
    -- stretches AttackTime over the cast, ~4s after the 0.5s ult bar), so
    -- AbilityCount stalls through ult + lockout. Send the server our own
    -- PetAttack for ulting pets so normal damage and energy gain continue.
    -- Live-verified: server accepts the extra hits and AbilityCount rises.
    if not Feature.attackWhileUltEnabled then
        return
    end
    local now = os.clock()
    if now - Feature.attackWhileUltLastScan < 0.25 then
        return
    end
    Feature.attackWhileUltLastScan = now
    local petsFolder = workspace:FindFirstChild("Pets")
    local remoteFolder = ReplicatedStorage:FindFirstChild("Remote")
    local event = remoteFolder and remoteFolder:FindFirstChild("PetAttack")
    if not petsFolder or not event then
        return
    end
    for _, pet in ipairs(petsFolder:GetChildren()) do
        if pet:IsA("Model") then
            local data = pet:FindFirstChild("Data")
            local owner = data and data:FindFirstChild("Owner")
            local attacking = data and data:FindFirstChild("Attacking")
            local target = attacking and attacking.Value
            local useTime = data and data:FindFirstChild("AbilityUseTime")
            local slot = Feature.attackWhileUltLastFire[pet]
            if owner and owner.Value == LocalPlayer and target ~= nil and target.Parent ~= nil and useTime then
                local ulting = tonumber(useTime.Value) and useTime.Value > 0
                if ulting then
                    -- Refresh the window while the ult bar is up; it also
                    -- covers the few seconds of attack lockout after it.
                    if type(slot) ~= "table" then
                        slot = { t = 0 }
                        Feature.attackWhileUltLastFire[pet] = slot
                    end
                    slot.untilTime = now + 4.5
                end
                if type(slot) == "table" and slot.untilTime and now < slot.untilTime then
                    if now - (slot.t or 0) >= 1 then
                        slot.t = now
                        pcall(function()
                            event:FireServer(pet)
                        end)
                        Feature.showUltSupplementDamage(pet, target)
                    end
                elseif slot then
                    Feature.attackWhileUltLastFire[pet] = nil
                end
            elseif slot then
                Feature.attackWhileUltLastFire[pet] = nil
            end
        end
    end
end

function Feature.updateMainStatus(force)
    if not Feature.mainStatusParagraph then
        return
    end
    local now = os.clock()
    if not force and now - Feature.mainStatusLastUpdate < 0.4 then
        return
    end
    Feature.mainStatusLastUpdate = now
    pcall(function()
        globalEnv.__afs_main = {
            collect = Feature.autoCollectDropsEnabled,
            tpPet = Feature.tpPetEnabled,
            ultHit = Feature.attackWhileUltEnabled,
            autoDungeon = Feature.autoDungeonEnabled,
            dungeonFarm = DungeonFarm.enabled,
            dungeonActive = dungeonActive,
            dungeonWaiting = dungeonWaiting,
            dungeonPhase = DungeonFarm.phase,
        }
    end)
    setParagraph(
        Feature.mainStatusParagraph,
        "Main | Collect drop: " .. (Feature.autoCollectDropsEnabled and "BAT" or "TAT")
            .. " | TP Pet: " .. (Feature.tpPetEnabled and "BAT" or "TAT")
            .. " | Ult Hit: " .. (Feature.attackWhileUltEnabled and "BAT" or "TAT"),
        "Auto collect drop khong gioi han khoang cach. TP Pet gia lap Lightspeed."
    )
end

function Feature.mainStep()
    Feature.collectDropsStep()
    Feature.attackWhileUltStep()
    Feature.fallenStarFarm.step()
    Feature.updateMainStatus(false)
end

local function openCloneGui()
    local bindable = ReplicatedStorage:FindFirstChild("Bindable")
    local event = bindable and bindable:FindFirstChild("AttemptCloneMachine")
    local machine = machineList[1]
    if event and machine then
        for _, tagged in ipairs(getTaggedMachines()) do
            local ok, id = pcall(function()
                return tagged:GetAttribute("CloneMachineId")
            end)
            if ok and tostring(id) == machine.id then
                event:Fire(tagged)
                break
            end
        end
    end
end

local function openDupeMachineGui()
    local mainGui = LocalPlayer.PlayerGui:FindFirstChild("MainGui")
    local bindable = ReplicatedStorage:FindFirstChild("Bindable")
    local chooser = bindable and bindable:FindFirstChild("ChooseDupeMachine")
    local opener = mainGui and mainGui:FindFirstChild("SetWindowOpen")
    if not chooser or not opener then
        notifyStatus("Dupe Machine", "Khong tim thay duong mo GUI Dupe Machine.")
        return
    end

    local machineNumber = 1
    local ok, tagged = pcall(function()
        return CollectionService:GetTagged("DupeMachine")
    end)
    if ok and type(tagged) == "table" and tagged[1] then
        local value = tagged[1]:GetAttribute("MachineNumber")
        if value ~= nil then
            machineNumber = value
        end
    end

    chooser:Fire(machineNumber)
    opener:Fire("DupeMachine", true)
    notifyStatus("Dupe Machine", "Da mo GUI Dupe Machine.")
end

local function openArtifactGui()
    local mainGui = LocalPlayer.PlayerGui:FindFirstChild("MainGui")
    local event = mainGui and mainGui:FindFirstChild("SetWindowOpen")
    if event then
        event:Fire("Artefact", true)
        notifyStatus("Artefact", utf8Text("Da mo bang Artefact.", 272, 227, 32, 109, 7903, 32, 98, 7843, 110, 103, 32, 65, 114, 116, 101, 102, 97, 99, 116, 46))
    else
        notifyStatus("Artefact", utf8Text("Khong tim thay bang Artefact.", 75, 104, 244, 110, 103, 32, 116, 236, 109, 32, 116, 104, 7845, 121, 32, 98, 7843, 110, 103, 32, 65, 114, 116, 101, 102, 97, 99, 116, 46))
    end
end

local function setWindowVisible(visible)
    local ok, err = pcall(function()
        safeSetThreadIdentity(5)
        local main = Window.UIElements and Window.UIElements.Main
        if main then
            main.Visible = visible
            local content = main:FindFirstChild("Main")
            if content then
                content.Visible = visible
            end
        end
        if visible then
            Window:Open()
        else
            Window:Close()
        end
    end)
    safeSetThreadIdentity(8)
    return ok, err
end

local function makeDungeonWorldOptions()
    local entries = {}
    local discovered = getStoreTable("DiscoveredWorlds", true)
    for id, data in pairs(WorldData) do
        if type(data) == "table"
            and (discovered[id] or data.EventWorld == true)
            and data.BaseLevel
            and data.BaseLevel ~= 0
            and not data.Hidden
            and not data.ComingSoon then
            table.insert(entries, {
                id = id,
                name = data.DisplayName or id,
                level = data.BaseLevel,
                event = data.EventWorld == true
            })
        end
    end
    if #entries == 0 and type(WorldData[dungeonSelection.mapId]) == "table" then
        local data = WorldData[dungeonSelection.mapId]
        table.insert(entries, {
            id = dungeonSelection.mapId,
            name = data.DisplayName or dungeonSelection.mapId,
            level = data.BaseLevel or 0,
            event = data.EventWorld == true
        })
    end
    table.sort(entries, function(a, b)
        if a.level ~= b.level then
            return a.level < b.level
        end
        return a.id < b.id
    end)
    local options = {}
    for _, entry in ipairs(entries) do
        local prefix = entry.event and "[EVENT] " or ""
        table.insert(options, string.format("%s%s [%s]", prefix, entry.name, entry.id))
    end
    return options
end

local function makeDungeonTeamOptions()
    local options = {}
    local teams = getStoreTable("PetTeams", true)
    for index, team in ipairs(teams) do
        team = type(team) == "table" and team or {}
        local count = 0
        local uids = type(team.UIDs) == "table" and team.UIDs or {}
        for _ in pairs(uids) do
            count = count + 1
        end
        local option = string.format("%d | %s | %d pets", index, tostring(team.Name or index), count)
        dungeonTeamByOption[option] = index
        table.insert(options, option)
    end
    return options
end

local function makeDungeonArtifactOptions()
    local options = {"(None)"}
    dungeonArtifactByOption["(None)"] = ""
    for id, level in pairs(getStoreTable("Artefacts", true)) do
        local data = ArtefactData[id]
        if type(data) == "table" and tonumber(level or 0) > 0 then
            local option = string.format("%s | Lv.%s | %s", data.DisplayName or id, tostring(level), id)
            dungeonArtifactByOption[option] = id
            table.insert(options, option)
        end
    end
    table.sort(options, function(a, b)
        if a == "(None)" then return true end
        if b == "(None)" then return false end
        return a < b
    end)
    return options
end

local function getDungeonDefaultTeam()
    local equipped = getStoreTable("EquippedPets", true)
    local first = equipped["1"] or equipped[1]
    for index, team in ipairs(getStoreTable("PetTeams", true)) do
        local uids = type(team) == "table" and type(team.UIDs) == "table" and team.UIDs or {}
        local candidate = uids["1"] or uids[1]
        if first and candidate and tostring(first) == tostring(candidate) then
            return index
        end
    end
    return 1
end

local function copyEquippedPets()
    local result = {}
    for slot, uid in pairs(getStoreTable("EquippedPets", true)) do
        result[tostring(slot)] = uid
    end
    return result
end

local function findTeamIndexForEquipped(equipped)
    equipped = type(equipped) == "table" and equipped or {}
    local teams = getStoreTable("PetTeams", true)
    local amount = 0
    pcall(function()
        amount = math.floor(tonumber(GetMultiplier.EquipAmount(LocalPlayer)) or 0)
    end)
    if amount < 1 then
        for slot in pairs(equipped) do
            amount = math.max(amount, tonumber(slot) or 0)
        end
        for _, team in ipairs(teams) do
            local uids = type(team) == "table" and team.UIDs or {}
            for slot in pairs(type(uids) == "table" and uids or {}) do
                amount = math.max(amount, tonumber(slot) or 0)
            end
        end
    end
    if amount < 1 then
        return nil
    end

    local function slotValue(data, slot)
        return type(data) == "table" and (data[tostring(slot)] or data[slot]) or nil
    end

    local preferred = getDungeonDefaultTeam()
    local fallback
    for index, team in ipairs(teams) do
        local uids = type(team) == "table" and team.UIDs or nil
        if type(uids) == "table" then
            local matches = true
            local hasPet = false
            for slot = 1, amount do
                local actual = slotValue(equipped, slot)
                local expected = slotValue(uids, slot)
                if actual ~= nil or expected ~= nil then
                    hasPet = hasPet or expected ~= nil or actual ~= nil
                end
                if tostring(actual or "") ~= tostring(expected or "") then
                    matches = false
                    break
                end
            end
            if matches and hasPet then
                if index == preferred then
                    return index
                end
                fallback = fallback or index
            end
        end
    end
    return fallback
end

local function applyEquippedPets(desired)
    local amount = 0
    pcall(function()
        amount = tonumber(GetMultiplier.EquipAmount(LocalPlayer)) or 0
    end)
    desired = type(desired) == "table" and desired or {}

    if amount < 1 then
        return false, "Khong doc duoc so slot equip hien tai."
    end

    local target = {}
    for slot = 1, amount do
        local uid = desired[tostring(slot)] or desired[slot]
        if uid ~= nil and tostring(uid) ~= "" then
            target[slot] = uid
        end
    end

    local function slotValue(data, slot)
        return data[tostring(slot)] or data[slot]
    end

    local function matchesTarget(actual)
        for slot = 1, amount do
            if tostring(slotValue(actual, slot) or "") ~= tostring(target[slot] or "") then
                return false
            end
        end
        return true
    end

    local function sendChanges()
        local actual = getStoreTable("EquippedPets", true)
        local sentEquip = {}
        for slot = 1, amount do
            local oldUID = slotValue(actual, slot)
            local newUID = target[slot]
            if tostring(oldUID or "") ~= tostring(newUID or "") and oldUID then
                pcall(function()
                    ManagePet:FireServer(oldUID, "Unequip")
                end)
            end
            if newUID and tostring(oldUID or "") ~= tostring(newUID)
                and not sentEquip[tostring(newUID)] then
                pcall(function()
                    ManagePet:FireServer(newUID, "Equip", slot)
                end)
                sentEquip[tostring(newUID)] = true
            end
        end
    end

    for _ = 1, 8 do
        sendChanges()
        task.wait(0.5)
        if matchesTarget(getStoreTable("EquippedPets", true)) then
            local localData = getStoreTable("EquippedPets")
            for slot = 1, amount do
                localData[tostring(slot)] = target[slot] or nil
            end
            setStoreValue("EquippedPets", localData, 1)
            return true
        end
    end

    -- One final pass mirrors the game's team handler without masking a partial sync.
    sendChanges()
    task.wait(0.5)
    if not matchesTarget(getStoreTable("EquippedPets", true)) then
        return false, "Team pet chua dong bo du so luong equip."
    end
    local localData = getStoreTable("EquippedPets")
    for slot = 1, amount do
        localData[tostring(slot)] = target[slot] or nil
    end
    setStoreValue("EquippedPets", localData, 1)
    return true
end

function DungeonFarm.getTeamSlotUID(team, slot)
    local uids = type(team) == "table" and team.UIDs or nil
    if type(uids) ~= "table" then
        return nil
    end
    return uids[slot] or uids[tostring(slot)]
end

function DungeonFarm.getEquipSlotCount()
    local amount = 0
    pcall(function()
        amount = tonumber(GetMultiplier.EquipAmount(LocalPlayer)) or 0
    end)
    return math.max(0, math.floor(amount))
end

function DungeonFarm.getEquippedPetCount()
    local equipped = getStoreTable("EquippedPets", true)
    local count = 0
    if type(equipped) ~= "table" then
        DungeonFarm.lastEquippedPetCount = 0
        return 0
    end
    for slot, uid in pairs(equipped) do
        local slotNumber = tonumber(slot)
        if slotNumber and slotNumber >= 1
            and uid ~= nil
            and uid ~= false
            and tostring(uid) ~= "" then
            count = count + 1
        end
    end
    DungeonFarm.lastEquippedPetCount = count
    return count
end

function DungeonFarm.normalizedUID(value)
    if value == nil or value == false or tostring(value) == "" then
        return ""
    end
    return tostring(value)
end

function DungeonFarm.getTeamPetCount(team)
    local uids = type(team) == "table" and team.UIDs or nil
    if type(uids) ~= "table" then
        return 0
    end

    local count = 0
    local amount = DungeonFarm.getEquipSlotCount()
    if amount > 0 then
        for slot = 1, amount do
            if DungeonFarm.normalizedUID(uids[slot] or uids[tostring(slot)]) ~= "" then
                count = count + 1
            end
        end
        return count
    end

    for slot, uid in pairs(uids) do
        if tonumber(slot) and DungeonFarm.normalizedUID(uid) ~= "" then
            count = count + 1
        end
    end
    return count
end

function DungeonFarm.teamPetsMatch(team)
    local amount = DungeonFarm.getEquipSlotCount()
    if amount < 1 then
        return false
    end
    if DungeonFarm.getEquippedPetCount() == 0 then
        return false
    end
    local equipped = getStoreTable("EquippedPets", true)
    for slot = 1, amount do
        local actual = equipped[tostring(slot)] or equipped[slot]
        if DungeonFarm.normalizedUID(actual) ~= DungeonFarm.normalizedUID(DungeonFarm.getTeamSlotUID(team, slot)) then
            return false
        end
    end
    return true
end

function DungeonFarm.teamLoadoutMatches(team)
    local loadout = type(team) == "table" and team.Loadout or nil
    if type(loadout) ~= "table" then
        return true
    end

    local fields = {
        {source = "Title", store = "CurrentTitle"},
        {source = "Avatar", store = "CurrentAvatar"},
        {source = "Aura", store = "CurrentAura"},
        {source = "Artefact", store = "CurrentArtefact"},
        {source = "SecondArtefact", store = "CurrentSecondArtefact"}
    }
    for _, field in ipairs(fields) do
        if loadout[field.source] ~= nil
            and cleanText(getStoreValue(field.store, true, "") or "")
                ~= cleanText(loadout[field.source]) then
            return false
        end
    end
    return true
end

function DungeonFarm.findNativeEquipTeam()
    if type(filtergc) ~= "function" then
        return nil, "filtergc API khong ton tai trong executor."
    end
    local ok, callback = pcall(function()
        return filtergc("function", {
            Name = "equip_team",
            IgnoreExecutor = true
        }, true)
    end)
    if not ok or type(callback) ~= "function" then
        return nil, "Khong tim thay handler native equip_team."
    end
    return callback
end

local function applyDungeonTeam(index)
    index = tonumber(index)
    if not index then
        return false, "Team dungeon khong hop le."
    end
    index = math.max(1, math.floor(index))

    local team = getStoreTable("PetTeams", true)[index]
    if type(team) ~= "table" or type(team.UIDs) ~= "table" then
        return false, "Khong tim thay team dungeon."
    end

    local equipTeam, reason = DungeonFarm.findNativeEquipTeam()
    if not equipTeam then
        return false, reason
    end

    local function invokeTeam(teamIndex)
        local called, callError = pcall(function()
            equipTeam(teamIndex)
        end)
        if not called then
            return false, "Goi native equip_team loi: " .. tostring(callError)
        end
        task.wait(0.35)
        return true
    end

    local function waitForTeamPets(timeout)
        local deadline = os.clock() + timeout
        while alive() and os.clock() < deadline do
            if DungeonFarm.teamPetsMatch(team) then
                DungeonFarm.lastEquippedPetCount = DungeonFarm.getEquippedPetCount()
                return true
            end
            DungeonFarm.lastEquippedPetCount = DungeonFarm.getEquippedPetCount()
            task.wait(0.2)
        end
        return false
    end

    if DungeonFarm.teamPetsMatch(team) then
        DungeonFarm.lastEquippedPetCount = DungeonFarm.getEquippedPetCount()
        return true, team
    end

    -- Native equip_team updates the pet store asynchronously. Poll one request
    -- to completion before retrying so each retry does not reset that sync.
    for attempt = 1, 3 do
        local called, callError = invokeTeam(index)
        if not called then
            return false, callError
        end
        if waitForTeamPets(3.5) then
            return true, team
        end

        if not alive() then
            return false, "Dungeon script da duoc reload trong luc doi team."
        end
        if attempt < 3 then
            task.wait(0.5)
        end
    end

    return false, "Native equip_team chua dong bo du pet va loadout cua team."
end

local function applyDungeonTitle(title, force)
    title = cleanText(title)
    local current = cleanText(getStoreValue("CurrentTitle", true, "") or "")
    if force or current ~= title then
        protectedCall("Change title", function()
            ChangeTitle:FireServer(title == "" and "Unequip" or title)
        end)
    end
    setStoreValue("CurrentTitle", title, 2)
end

local function applyDungeonAvatar(avatar, force)
    avatar = cleanText(avatar)
    local current = cleanText(getStoreValue("CurrentAvatar", true, "") or "")
    if force or current ~= avatar then
        local selected = avatar ~= "" and avatar or current
        if selected ~= "" then
            protectedCall("Equip avatar", function()
                AttemptAvatarEquip:InvokeServer(selected)
            end)
        end
    end
    setStoreValue("CurrentAvatar", avatar, 2)
end

local function applyDungeonAura(aura, force)
    aura = cleanText(aura)
    local current = cleanText(getStoreValue("CurrentAura", true, "") or "")
    if force or current ~= aura then
        protectedCall("Equip aura", function()
            EquipAura:FireServer(aura)
        end)
    end
    setStoreValue("CurrentAura", aura, 2)
end

local function applyDungeonArtifact(artifact, slot, force)
    artifact = cleanText(artifact)
    local current = cleanText(getStoreValue(slot, true, "") or "")
    if force or current ~= artifact then
        protectedCall("Equip artefact", function()
            EquipArtefact:FireServer(artifact, slot)
        end)
    end
    setStoreValue(slot, artifact, 1)
end

local function applyDungeonLoadout(loadout)
    if type(loadout) ~= "table" then
        return
    end

    local avatar = type(loadout.Avatar) == "string" and cleanText(loadout.Avatar) or nil
    local aura = type(loadout.Aura) == "string" and cleanText(loadout.Aura) or nil
    local title = type(loadout.Title) == "string" and cleanText(loadout.Title) or nil
    local artifact = type(loadout.Artefact) == "string" and cleanText(loadout.Artefact) or nil
    local secondArtifact = type(loadout.SecondArtefact) == "string"
        and cleanText(loadout.SecondArtefact)
        or nil

    -- Team loadouts can be applied while the store is still catching up after teleport.
    -- Re-send the five fields so the visual state and the saved team stay aligned.
    for _ = 1, 3 do
        if avatar ~= nil then
            applyDungeonAvatar(avatar, true)
        end
        if aura ~= nil then
            applyDungeonAura(aura, true)
        end
        if title ~= nil then
            applyDungeonTitle(title, true)
        end
        if artifact ~= nil then
            applyDungeonArtifact(artifact, "CurrentArtefact", true)
        end
        if secondArtifact ~= nil then
            applyDungeonArtifact(secondArtifact, "CurrentSecondArtefact", true)
        end
        task.wait(0.35)
    end
end

function DungeonFarm.ensureTeamApplied(index, role)
    index = tonumber(index)
        or tonumber(dungeonSelection.normalTeamIndex)
        or tonumber(dungeonSelection.teamIndex)
        or 1
    index = math.max(1, math.floor(index))

    if DungeonFarm.teamApplied and DungeonFarm.teamIndexApplied == index then
        local team = getStoreTable("PetTeams", true)[index]
        if type(team) == "table" then
            local deadline = os.clock() + 3
            while alive() and os.clock() < deadline do
                if DungeonFarm.getEquippedPetCount() > 0 and DungeonFarm.teamPetsMatch(team) then
                    return true
                end
                task.wait(0.2)
            end
            -- A just-applied team can briefly disappear while the native store
            -- republishes all slots. Let it settle before issuing another swap.
            if os.clock() - (DungeonFarm.teamAppliedAt or 0) < 8 then
                return false
            end
        end
    end
    if DungeonFarm.teamApplying then
        local deadline = os.clock() + 15
        while alive() and DungeonFarm.teamApplying and os.clock() < deadline do
            task.wait(0.1)
        end
        if DungeonFarm.teamApplied and DungeonFarm.teamIndexApplied == index then
            local team = getStoreTable("PetTeams", true)[index]
            if type(team) == "table"
                and DungeonFarm.getEquippedPetCount() > 0
                and DungeonFarm.teamPetsMatch(team) then
                return true
            end
            if os.clock() - (DungeonFarm.teamAppliedAt or 0) < 8 then
                return false
            end
        end
    end

    DungeonFarm.teamApplying = true
    local ok, team = protectedCall("Apply dungeon " .. tostring(role or "team"), function()
        local applied, reason = applyDungeonTeam(index)
        if not applied then
            error(reason)
        end
        return reason
    end)
    if ok and type(team) == "table" then
        -- Do not call native equip_team again just because the authoritative
        -- pet store reports a transient zero during synchronization. The native
        -- team handler also owns the cosmetic loadout, so avoid sending those
        -- remotes separately while its pet sync is still settling.
        for _ = 1, 24 do
            local currentTeam = getStoreTable("PetTeams", true)[index]
            if type(currentTeam) ~= "table" then
                currentTeam = team
            end
            local equippedCountNow = DungeonFarm.getEquippedPetCount()
            if equippedCountNow > 0
                and DungeonFarm.teamPetsMatch(currentTeam) then
                DungeonFarm.teamApplying = false
                DungeonFarm.teamApplied = true
                DungeonFarm.teamIndexApplied = index
                DungeonFarm.teamAppliedAt = os.clock()
                DungeonFarm.lastEquippedPetCount = equippedCountNow
                DungeonFarm.lastMessage = "Da doi sang team " .. tostring(role or "dungeon") .. "."
                return true
            end
            task.wait(0.25)
        end
    end
    DungeonFarm.teamApplying = false
    DungeonFarm.teamApplied = false
    DungeonFarm.teamIndexApplied = nil
    DungeonFarm.teamAppliedAt = 0
    return false
end

function DungeonFarm.ensureEntryTeam(role)
    local index = tonumber(dungeonSelection.normalTeamIndex)
        or tonumber(dungeonSelection.teamIndex)
        or 1
    for attempt = 1, 5 do
        DungeonFarm.updateStatus(
            "Dungeon Farm: TEAM",
            string.format(
                "Dang dong bo team %d truoc khi vao dungeon (%d/5) | Pet %d",
                index,
                attempt,
                DungeonFarm.getEquippedPetCount()
            )
        )
        if DungeonFarm.ensureTeamApplied(index, role or "normal")
            and DungeonFarm.getEquippedPetCount() > 0 then
            return true
        end
        task.wait(0.5)
    end
    return false
end

function DungeonFarm.getRoomTeamIndex(room)
    local key = room and room:GetFullName() or ""
    if DungeonFarm.goldRoomKeys[key]
        or (DungeonFarm.greenRoomKeys and DungeonFarm.greenRoomKeys[key]) then
        return tonumber(dungeonSelection.goldTeamIndex)
            or tonumber(dungeonSelection.normalTeamIndex)
            or tonumber(dungeonSelection.teamIndex)
            or 1,
            "gold"
    end
    return tonumber(dungeonSelection.normalTeamIndex)
        or tonumber(dungeonSelection.teamIndex)
        or 1,
        "normal"
end

function DungeonFarm.ensureRoomTeam(room)
    local index, role = DungeonFarm.getRoomTeamIndex(room)
    return DungeonFarm.ensureTeamApplied(index, role)
end

local function getDungeonCooldownInfo()
    local now = getGameTime()
    local last = tonumber(getStoreValue("LastDungeon", true, 0) or 0) or 0
    local ownedArtifacts = getStoreTable("Artefacts", true)
    local passageLevel = tonumber(ownedArtifacts.Dungeon or 0) or 0
    local usingPassage = passageLevel > 0
    local factor
    if usingPassage and passageLevel > 0 then
        factor = 0.7676 ^ passageLevel
    else
        local ok, value = pcall(function()
            return tonumber(GetMultiplier.DungeonTime(LocalPlayer))
        end)
        factor = ok and value and value > 0 and value or 1
    end
    local base = tonumber(ConfigValues.DungeonTime) or 39600
    local total = math.min(base * factor, 39600)
    local remaining = math.max(0, last + total - now)
    return remaining, total, factor, passageLevel, usingPassage
end

local function updateDungeonCooldownStatus()
    if not dungeonCooldownParagraph then
        return
    end
    local remaining, total, factor, passageLevel, usingPassage = getDungeonCooldownInfo()
    local mode = usingPassage and ("Artifact of Passage Lv" .. tostring(passageLevel)) or utf8Text("Cau hinh hien tai", 67, 7845, 117, 32, 104, 236, 110, 104, 32, 104, 105, 7879, 110, 32, 116, 7841, 105)
    local title = remaining <= 0 and utf8Text("Dungeon san sang", 68, 117, 110, 103, 101, 111, 110, 32, 115, 7861, 110, 32, 115, 224, 110, 103) or "Cooldown dungeon"
    local desc = string.format(
        utf8Text("%s | Con %s | Tong %s | x%.3f", 37, 115, 32, 124, 32, 67, 242, 110, 32, 37, 115, 32, 124, 32, 84, 7893, 110, 103, 32, 37, 115, 32, 124, 32, 120, 37, 46, 51, 102),
        mode,
        formatDuration(remaining),
        formatDuration(total),
        factor
    )
    setParagraph(dungeonCooldownParagraph, title, desc)
end

function DungeonFarm.updateStatus(title, desc)
    if dungeonFarmStatusParagraph then
        setParagraph(dungeonFarmStatusParagraph, title, desc)
    end
end

function DungeonFarm.getDungeon()
    if tostring(getPlayerValue("World", "")) ~= "Dungeon" then
        return nil
    end
    local worlds = workspace:FindFirstChild("Worlds")
    return worlds and worlds:FindFirstChild("Dungeon")
end

function DungeonFarm.getDungeonActiveFlag(dungeon)
    if not dungeon then
        return false
    end
    local active = dungeon:GetAttribute("Active")
    if active == nil then
        local activeValue = dungeon:FindFirstChild("Active")
        active = activeValue and activeValue.Value
    end
    return active == true
end

function DungeonFarm.getActiveDungeonInfo()
    local worlds = workspace:FindFirstChild("Worlds")
    local dungeon = worlds and worlds:FindFirstChild("Dungeon")
    if dungeon and DungeonFarm.getDungeonActiveFlag(dungeon) then
        local ownerValue = dungeon:FindFirstChild("FriendsWithUserId")
        local ownerId = ownerValue and tonumber(ownerValue.Value) or 0
        -- Ignore a stale Active flag when the server has no live dungeon owner.
        if ownerId > 0 and (ownerId == LocalPlayer.UserId or Players:GetPlayerByUserId(ownerId)) then
            return dungeon, ownerId
        end
    end
    return nil, 0
end

function DungeonFarm.getOpenDungeon()
    local dungeon = DungeonFarm.getActiveDungeonInfo()
    return dungeon
end

function DungeonFarm.isDungeonOccupied()
    if tostring(getPlayerValue("World", "")) == "Dungeon" then
        return false, nil
    end

    local dungeon, ownerId = DungeonFarm.getActiveDungeonInfo()
    if not dungeon then
        return false, nil
    end

    return true, ownerId
end

function DungeonFarm.getRoomConfirmPrompt(room)
    if not room or not room.Parent then
        return nil
    end
    for _, object in ipairs(room:GetDescendants()) do
        if object:IsA("ProximityPrompt") and object.Enabled then
            local part = object.Parent
            if part and part:IsA("BasePart") and part.Name == "ConfirmPart" then
                return object, part
            end
        end
    end
    return nil
end

function DungeonFarm.findPrompt(dungeon)
    local rooms, startEntry, goldEntry = DungeonFarm.rebuildRoute(dungeon)
    if #DungeonFarm.route > 0 and startEntry and goldEntry then
        -- Only activate the first incomplete room. Later route rooms stay
        -- blocked until their red door has been opened from the prior room.
        local firstIncomplete
        for index, entry in ipairs(DungeonFarm.route) do
            if entry.room.Parent and not DungeonFarm.completed[entry.key] then
                local previous = index > 1 and DungeonFarm.route[index - 1] or nil
                if previous and DungeonFarm.completed[previous.key]
                    and (DungeonFarm.findRouteDoor(dungeon, previous.room, entry.room)
                        or DungeonFarm.roomHasPendingGoldDoor(previous.room)) then
                    -- A live route door still blocks this ConfirmPart. Let the
                    -- door phase interact first instead of flying through it.
                    return nil
                end
                firstIncomplete = entry
                break
            end
        end
        if firstIncomplete then
            local prompt, part = DungeonFarm.getRoomConfirmPrompt(firstIncomplete.room)
            if prompt then
                return prompt, firstIncomplete.room, part, firstIncomplete.key
            end
        end
    end

    -- A valid route with no actionable prompt means the route rooms are waiting
    -- on combat/chest/door, which the caller handles before reaching here.
    -- Stay on route instead of wandering into unrelated rooms.
    if goldEntry and #DungeonFarm.route > 0 then
        return nil
    end

    -- No path to the gold target yet: reveal toward gold, not just the nearest
    -- room, so the server exposes the missing connection without clearing
    -- unrelated branches.
    local character = LocalPlayer.Character
    local root = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
    local rootPos = root and root.Position or nil
    local bestPrompt, bestRoom, bestPart, bestKey
    local bestGoldDist, bestPlayerDist = math.huge, math.huge
    for _, entry in ipairs(rooms) do
        if entry.room.Parent and not DungeonFarm.completed[entry.key] then
            local prompt, part = DungeonFarm.getRoomConfirmPrompt(entry.room)
            if prompt then
                local goldDist = math.huge
                if goldEntry then
                    goldDist = math.abs(entry.x - goldEntry.x) + math.abs(entry.y - goldEntry.y)
                elseif #DungeonFarm.goldRooms > 0 then
                    for _, gold in ipairs(DungeonFarm.goldRooms) do
                        local dist = math.abs(entry.x - gold.x) + math.abs(entry.y - gold.y)
                        if dist < goldDist then
                            goldDist = dist
                        end
                    end
                else
                    goldDist = 0
                end
                local playerDist = rootPos and (entry.center - rootPos).Magnitude or 0
                if goldDist < bestGoldDist
                    or (goldDist == bestGoldDist and playerDist < bestPlayerDist) then
                    bestPrompt = prompt
                    bestRoom = entry.room
                    bestPart = part
                    bestKey = entry.key
                    bestGoldDist = goldDist
                    bestPlayerDist = playerDist
                end
            end
        end
    end
    return bestPrompt, bestRoom, bestPart, bestKey
end

function DungeonFarm.revealNextRouteRoom(dungeon, token)
    local now = os.clock()
    if now - (DungeonFarm.lastRouteWalkAt or 0) < 4 then
        return false
    end

    local _, startEntry = DungeonFarm.rebuildRoute(dungeon)
    if not startEntry or #DungeonFarm.route < 2 then
        return false
    end

    local firstIncomplete
    local firstIncompleteIndex
    for index, entry in ipairs(DungeonFarm.route) do
        if entry.room.Parent and not DungeonFarm.completed[entry.key] then
            firstIncomplete = entry
            firstIncompleteIndex = index
            break
        end
    end
    if not firstIncomplete then
        return false
    end

    -- A resumed run can start in a room that is already empty and has no
    -- ConfirmPart. Mark that frontier room first instead of waiting forever
    -- for a prompt that the server will never create.
    if firstIncomplete.room == startEntry.room then
        local prompt = DungeonFarm.getRoomConfirmPrompt(firstIncomplete.room)
        local liveEnemies, uncertainEnemies = DungeonFarm.getLiveEnemies(dungeon, firstIncomplete.room)
        local chests = DungeonFarm.getChestTargets(dungeon, firstIncomplete.room)
        if prompt or #liveEnemies > 0 or uncertainEnemies or #chests > 0
            or DungeonFarm.roomHasPendingGoldDoor(firstIncomplete.room) then
            return false
        end
        if DungeonFarm.canMarkRoomClearedSequential(dungeon, firstIncomplete.room) then
            DungeonFarm.markRoomCleared(firstIncomplete.room, firstIncomplete.key)
            DungeonFarm.lastMessage = "Da dong bo room frontier " .. tostring(firstIncomplete.room.Name) .. "."
        end
        return false
    end

    local walkEntry = firstIncomplete
    if firstIncompleteIndex and firstIncompleteIndex > 1 then
        local previous = DungeonFarm.route[firstIncompleteIndex - 1]
        if previous and DungeonFarm.completed[previous.key] then
            if DungeonFarm.findRouteDoor(dungeon, previous.room, firstIncomplete.room)
                or DungeonFarm.roomHasPendingGoldDoor(previous.room) then
                -- Never reveal a room by teleporting through an active door.
                return false
            end
            local character = LocalPlayer.Character
            local root = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
            local previousCenter = DungeonFarm.getRoomCenter(previous.room)
            if root and previousCenter and (root.Position - previousCenter).Magnitude <= 25 then
                -- We are already at the completed frontier. The next room is
                -- the only useful discovery target now.
                walkEntry = firstIncomplete
            else
                walkEntry = previous
            end
        end
    end

    local character = LocalPlayer.Character
    local root = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
    local target = walkEntry.room:FindFirstChild("RootPart") or walkEntry.room
    local center = DungeonFarm.getRoomCenter(walkEntry.room)
    if not (target and center and (not root or (root.Position - center).Magnitude > 25)) then
        return false
    end

    DungeonFarm.lastRouteWalkAt = now
    DungeonFarm.lastRouteWalkTargetKey = walkEntry.key
    DungeonFarm.phase = "route_walk"
    DungeonFarm.updateStatus(
        "Dungeon Farm: MO LOI ROUTE",
        string.format("Dang bay toi room %s de mo route an toan...", tostring(walkEntry.room.Name))
    )
    local reached = DungeonFarm.flyTo(target, token)
    if reached then
        DungeonFarm.lastMessage = "Da mo loi route toi room " .. tostring(walkEntry.room.Name) .. "."
    end
    return reached
end

function DungeonFarm.getConfirmPartState(dungeon)
    local map = dungeon and dungeon:FindFirstChild("Map")
    if not map then
        return 0, 0, 0
    end

    local rooms = {}
    for _, object in ipairs(map:GetDescendants()) do
        local part
        if object:IsA("BasePart") and object.Name == "ConfirmPart" then
            part = object
        elseif object:IsA("ProximityPrompt")
            and object.Parent
            and object.Parent:IsA("BasePart")
            and object.Parent.Name == "ConfirmPart" then
            part = object.Parent
        end
        if part then
            local room = part.Parent
            if room and room:IsA("Model") and room:GetAttribute("MapPos") ~= nil then
                local key = room:GetFullName()
                rooms[key] = rooms[key] or {room = room, part = part}
            end
        end
    end

    local total = 0
    local pending = 0
    local enabled = 0
    for key, entry in pairs(rooms) do
        total = total + 1
        if not DungeonFarm.completed[key] then
            pending = pending + 1
        end
        for _, object in ipairs(entry.part:GetChildren()) do
            if object:IsA("ProximityPrompt") and object.Enabled then
                enabled = enabled + 1
                break
            end
        end
    end
    return total, pending, enabled
end

function DungeonFarm.findRoom(instance, map)
    local current = instance
    while current and current ~= map do
        if current:IsA("Model") and current:GetAttribute("MapPos") ~= nil then
            return current
        end
        current = current.Parent
    end
    return nil
end

function DungeonFarm.getMapCoordinate(room)
    if not room then
        return nil, nil
    end
    local value = room:GetAttribute("MapPos")
    if typeof(value) == "Vector2" then
        return math.floor(value.X + 0.5), math.floor(value.Y + 0.5)
    end
    local x, y = tostring(value or room.Name):match("^%s*(%-?%d+)%s*,%s*(%-?%d+)%s*$")
    return tonumber(x), tonumber(y)
end

function DungeonFarm.getRoomCenter(room)
    if not room then
        return nil
    end
    local rootPart = room:FindFirstChild("RootPart")
    if rootPart and rootPart:IsA("BasePart") then
        return rootPart.Position
    end
    local ok, pivot = pcall(function()
        return room:GetPivot()
    end)
    return ok and pivot and pivot.Position or nil
end

function DungeonFarm.isGoldDoorPart(part)
    if not (part and part:IsA("BasePart") and part.Name == "Door") then
        return false
    end
    local color = part.Color
    return math.abs(color.R - 0.85098) <= 0.03
        and math.abs(color.G - 0.713726) <= 0.03
        and math.abs(color.B - 0.219608) <= 0.03
end

function DungeonFarm.markRoomCleared(room, explicitKey)
    local key = explicitKey
    if not key and room and room.Parent then
        key = room:GetFullName()
    end
    if not key then
        return
    end

    -- A gold room is complete only after this exact room's entry door was
    -- opened. Never let a route-wide scan mark a sibling gold room by proxy.
    if DungeonFarm.goldRoomKeys[key] and not DungeonFarm.goldRoomsOpened[key] then
        return false
    end

    DungeonFarm.completed[key] = true
    if DungeonFarm.goldRoomKeys[key] then
        DungeonFarm.goldRoomsOpened[key] = true
        -- Force the next route calculation to choose the next unfinished gold room.
        if DungeonFarm.goldTargetKey == key then
            DungeonFarm.goldTargetKey = nil
            DungeonFarm.goldTargetRoom = nil
            DungeonFarm.routeTarget = nil
            DungeonFarm.routeKey = ""
            DungeonFarm.route = {}
        end
    elseif DungeonFarm.greenTargetKey == key then
        -- After all gold rooms, keep the route focused on the final green room.
        DungeonFarm.greenTargetKey = nil
        DungeonFarm.routeTarget = nil
        DungeonFarm.routeKey = ""
        DungeonFarm.route = {}
    end
    if DungeonFarm.targetRoom == room then
        DungeonFarm.targetRoom = nil
        DungeonFarm.targetPart = nil
    end
end

function DungeonFarm.getRouteRooms(dungeon)
    local map = dungeon and dungeon:FindFirstChild("Map")
    local model = map and map:FindFirstChild("Model")
    local rooms = {}
    local byCoordinate = {}
    if not model then
        return rooms, byCoordinate
    end

    for _, room in ipairs(model:GetChildren()) do
        if room:IsA("Model") then
            local x, y = DungeonFarm.getMapCoordinate(room)
            local center = DungeonFarm.getRoomCenter(room)
            if x and y and center then
                local entry = {
                    room = room,
                    key = room:GetFullName(),
                    x = x,
                    y = y,
                    center = center,
                    neighbors = {}
                }
                table.insert(rooms, entry)
                byCoordinate[tostring(x) .. ":" .. tostring(y)] = entry
            end
        end
    end
    return rooms, byCoordinate
end

function DungeonFarm.getNativeMapFrame()
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local mainGui = playerGui and playerGui:FindFirstChild("MainGui")
    local minimap = mainGui and mainGui:FindFirstChild("DungeonMinimap")
    return minimap and minimap:FindFirstChild("MapFrame")
end

function DungeonFarm.getNativeMapCells()
    local mapFrame = DungeonFarm.getNativeMapFrame()
    local cells = {}
    if not mapFrame then
        return nil, cells
    end

    for _, object in ipairs(mapFrame:GetChildren()) do
        if object:IsA("GuiObject") then
            local x, y = tostring(object.Name):match("^%s*(%-?%d+),%s*(%-?%d+)%s*$")
            if x and y then
                cells[tostring(tonumber(x)) .. ":" .. tostring(tonumber(y))] = object
            end
        end
    end
    return mapFrame, cells
end

function DungeonFarm.isNativeGoldCell(cell)
    if not (cell and cell:IsA("GuiObject")) then
        return false
    end
    local color = cell.BackgroundColor3
    return math.abs(color.R - 198 / 255) <= 0.02
        and math.abs(color.G - 191 / 255) <= 0.02
        and math.abs(color.B - 134 / 255) <= 0.02
end

function DungeonFarm.findGoldRoomsFromMap(dungeon, rooms)
    local result = {}
    local nativeMap, nativeCells = DungeonFarm.getNativeMapCells()
    local hasNativeCells = nativeMap ~= nil and next(nativeCells) ~= nil
    for _, entry in ipairs(rooms) do
        local cell = nativeCells[tostring(entry.x) .. ":" .. tostring(entry.y)]
        local isGold = DungeonFarm.isNativeGoldCell(cell)
        if not isGold and not cell or not hasNativeCells then
            isGold = false
            for _, object in ipairs(entry.room:GetDescendants()) do
                if DungeonFarm.isGoldDoorPart(object) then
                    isGold = true
                    break
                end
            end
        end
        if isGold then
            table.insert(result, entry)
        end
    end
    return result
end

function DungeonFarm.findGoldRoomFromMap(dungeon, rooms)
    return DungeonFarm.findGoldRoomsFromMap(dungeon, rooms)[1]
end

function DungeonFarm.findCurrentMapRoom(rooms)
    local character = LocalPlayer.Character
    local root = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
    if root then
        local nearest
        local nearestDistance = math.huge
        for _, entry in ipairs(rooms) do
            local distance = (entry.center - root.Position).Magnitude
            if distance < nearestDistance then
                nearest = entry
                nearestDistance = distance
            end
        end
        return nearest
    end

    local targetRoom = DungeonFarm.targetRoom
    if targetRoom and targetRoom.Parent then
        for _, entry in ipairs(rooms) do
            if entry.room == targetRoom then
                return entry
            end
        end
    end
    return nil
end

function DungeonFarm.rebuildRoute(dungeon)
    local rooms, byCoordinate = DungeonFarm.getRouteRooms(dungeon)
    local startEntry = DungeonFarm.findCurrentMapRoom(rooms)
    local goldEntries = DungeonFarm.findGoldRoomsFromMap(dungeon, rooms)
    DungeonFarm.goldRooms = goldEntries
    DungeonFarm.goldRoomKeys = {}
    local entryByKey = {}
    for _, entry in ipairs(rooms) do
        entryByKey[entry.key] = entry
    end
    for _, entry in ipairs(goldEntries) do
        DungeonFarm.goldRoomKeys[entry.key] = true
    end
    -- Room xanh la (final) dung chung team vang; room do (boss) giu team thuong.
    DungeonFarm.greenRoomKeys = {}
    local greenEntries = DungeonFarm.findGreenRoomsFromMap(dungeon, rooms)
    for _, entry in ipairs(greenEntries) do
        DungeonFarm.greenRoomKeys[entry.key] = true
    end
    DungeonFarm.reconcileDungeonProgress(dungeon, rooms, goldEntries)

    local function linkByCoordinate(entry, nextX, nextY)
        local neighbour = byCoordinate[tostring(nextX) .. ":" .. tostring(nextY)]
        if neighbour and neighbour ~= entry then
            entry.neighbors[neighbour.key] = neighbour
            neighbour.neighbors[entry.key] = entry
            return true
        end
        return false
    end

    local nativeMap, nativeCells = DungeonFarm.getNativeMapCells()
    local nativeDoorCount = 0
    local physicalDoorCount = 0
    local nativeDirections = {
        {1, 0},
        {0, 1},
        {-1, 0},
        {0, -1}
    }

    for _, entry in ipairs(rooms) do
        local cell = nativeCells[tostring(entry.x) .. ":" .. tostring(entry.y)]
        if nativeMap and cell then
            for direction, offset in ipairs(nativeDirections) do
                local marker = cell:FindFirstChild("Door" .. tostring(direction))
                if marker and marker:IsA("GuiObject") then
                    nativeDoorCount = nativeDoorCount + 1
                    linkByCoordinate(entry, entry.x + offset[1], entry.y + offset[2])
                end
            end
        end

        -- Physical Door models cover clients where the minimap has not rendered yet.
        for _, object in ipairs(entry.room:GetChildren()) do
            local direction = object:IsA("Model") and object.Name:match("^Door([1-4])$")
            if direction then
                local directionIndex = tonumber(direction)
                local offset = directionIndex and nativeDirections[directionIndex]
                if offset then
                    physicalDoorCount = physicalDoorCount + 1
                    linkByCoordinate(entry, entry.x + offset[1], entry.y + offset[2])
                end
            elseif object:IsA("BasePart") and object.Name == "Door" then
                physicalDoorCount = physicalDoorCount + 1
                local delta = object.Position - entry.center
                local nextX, nextY
                if math.abs(delta.X) >= math.abs(delta.Z) then
                    nextX = entry.x + (delta.X >= 0 and 1 or -1)
                    nextY = entry.y
                else
                    nextX = entry.x
                    nextY = entry.y + (delta.Z >= 0 and 1 or -1)
                end
                linkByCoordinate(entry, nextX, nextY)
            end
        end
    end

    local function sortedNeighbours(entry)
        local result = {}
        for _, neighbour in pairs(entry.neighbors) do
            table.insert(result, neighbour)
        end
        table.sort(result, function(a, b)
            return a.key < b.key
        end)
        return result
    end

    local function shortestDistances(root)
        local distances = {}
        local previous = {}
        if not root then
            return distances, previous
        end
        distances[root.key] = 0
        previous[root.key] = false
        local queue = {root}
        local head = 1
        while head <= #queue do
            local current = queue[head]
            head = head + 1
            for _, neighbour in ipairs(sortedNeighbours(current)) do
                if distances[neighbour.key] == nil then
                    distances[neighbour.key] = distances[current.key] + 1
                    previous[neighbour.key] = current.key
                    table.insert(queue, neighbour)
                end
            end
        end
        return distances, previous
    end

    local distances = shortestDistances(startEntry)
    local allGoldComplete = #goldEntries > 0
    for _, entry in ipairs(goldEntries) do
        if not DungeonFarm.completed[entry.key] then
            allGoldComplete = false
            break
        end
    end

    -- Gold rooms are the primary objective. Once they are all clear, keep the
    -- same shortest-path logic but switch the target to the final green room.
    local targetEntries = allGoldComplete and greenEntries or goldEntries
    local targetKey = allGoldComplete and DungeonFarm.greenTargetKey or DungeonFarm.goldTargetKey
    local targetEntry = targetKey and entryByKey[targetKey] or nil
    if targetEntry and DungeonFarm.completed[targetEntry.key] then
        targetEntry = nil
        targetKey = nil
    end
    if not targetEntry then
        local bestDistance = math.huge
        local bestTie = math.huge
        for _, entry in ipairs(targetEntries) do
            local distance = distances[entry.key]
            if not DungeonFarm.completed[entry.key] and distance ~= nil then
                local tie = startEntry
                    and math.abs(entry.x - startEntry.x) + math.abs(entry.y - startEntry.y)
                    or math.huge
                if distance < bestDistance
                    or distance == bestDistance and (tie < bestTie or tie == bestTie and entry.key < (targetEntry and targetEntry.key or "~")) then
                    bestDistance = distance
                    bestTie = tie
                    targetEntry = entry
                end
            end
        end
        if allGoldComplete then
            DungeonFarm.greenTargetKey = targetEntry and targetEntry.key or nil
            DungeonFarm.goldTargetKey = nil
            DungeonFarm.goldTargetRoom = nil
        else
            DungeonFarm.goldTargetKey = targetEntry and targetEntry.key or nil
            DungeonFarm.greenTargetKey = nil
        end
    elseif allGoldComplete then
        DungeonFarm.greenTargetKey = targetEntry.key
        DungeonFarm.goldTargetKey = nil
        DungeonFarm.goldTargetRoom = nil
    else
        DungeonFarm.goldTargetKey = targetEntry.key
        DungeonFarm.greenTargetKey = nil
    end

    DungeonFarm.goldTargetRoom = allGoldComplete and nil or (targetEntry and targetEntry.room or nil)
    local startKey = startEntry and startEntry.key or ""
    local routeGoalKey = targetEntry and targetEntry.key or ""
    local roomSignature = {}
    for _, entry in ipairs(rooms) do
        table.insert(roomSignature, entry.key)
    end
    table.sort(roomSignature)

    local connectionSignature = {}
    for _, entry in ipairs(rooms) do
        local neighbours = {}
        for key in pairs(entry.neighbors) do
            table.insert(neighbours, key)
        end
        table.sort(neighbours)
        table.insert(connectionSignature, entry.key .. "=" .. table.concat(neighbours, ","))
    end
    table.sort(connectionSignature)

    local routeKey = table.concat({
        startKey,
        routeGoalKey,
        tostring(#rooms),
        tostring(nativeDoorCount),
        tostring(physicalDoorCount),
        table.concat(roomSignature, ";"),
        table.concat(connectionSignature, ";")
    }, "|")
    if routeKey == DungeonFarm.routeKey then
        return rooms, startEntry, targetEntry
    end
    DungeonFarm.routeKey = routeKey
    DungeonFarm.routeTarget = targetEntry and targetEntry.room or nil
    DungeonFarm.route = {}

    if not (startEntry and targetEntry) then
        return rooms, startEntry, targetEntry
    end

    local _, previous = shortestDistances(startEntry)
    if previous[targetEntry.key] == nil then
        return rooms, startEntry, targetEntry
    end

    local reversed = {}
    local key = targetEntry.key
    while key do
        local entry = entryByKey[key]
        if not entry then
            break
        end
        table.insert(reversed, entry)
        key = previous[key]
    end
    for index = #reversed, 1, -1 do
        table.insert(DungeonFarm.route, reversed[index])
    end
    return rooms, startEntry, targetEntry
end

function DungeonFarm.ensureMapOverlay()
    if DungeonFarm.mapGui and DungeonFarm.mapGui.Parent then
        return DungeonFarm.mapGui
    end
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then
        return nil
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "AutoDungeonMap"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 998
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = playerGui

    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.AnchorPoint = Vector2.new(1, 0)
    panel.Position = UDim2.new(1, -12, 0, 170)
    panel.Size = UDim2.fromOffset(330, 370)
    panel.BackgroundColor3 = Color3.fromRGB(21, 24, 31)
    panel.BackgroundTransparency = 0.08
    panel.BorderSizePixel = 0
    panel.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = panel
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(82, 94, 116)
    stroke.Transparency = 0.25
    stroke.Parent = panel

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(12, 8)
    title.Size = UDim2.new(1, -24, 0, 25)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = panel

    local summary = Instance.new("TextLabel")
    summary.BackgroundTransparency = 1
    summary.Position = UDim2.fromOffset(12, 34)
    summary.Size = UDim2.new(1, -24, 0, 34)
    summary.Font = Enum.Font.Gotham
    summary.TextSize = 11
    summary.TextColor3 = Color3.fromRGB(190, 199, 214)
    summary.TextWrapped = true
    summary.TextXAlignment = Enum.TextXAlignment.Left
    summary.TextYAlignment = Enum.TextYAlignment.Top
    summary.Parent = panel

    local canvas = Instance.new("Frame")
    canvas.Name = "Canvas"
    canvas.Position = UDim2.fromOffset(10, 75)
    canvas.Size = UDim2.new(1, -20, 0, 260)
    canvas.BackgroundColor3 = Color3.fromRGB(12, 14, 19)
    canvas.BorderSizePixel = 0
    canvas.ClipsDescendants = true
    canvas.Parent = panel
    local canvasCorner = Instance.new("UICorner")
    canvasCorner.CornerRadius = UDim.new(0, 7)
    canvasCorner.Parent = canvas

    local legend = Instance.new("TextLabel")
    legend.BackgroundTransparency = 1
    legend.Position = UDim2.fromOffset(12, 342)
    legend.Size = UDim2.new(1, -24, 0, 20)
    legend.Font = Enum.Font.Gotham
    legend.TextSize = 11
    legend.TextColor3 = Color3.fromRGB(175, 185, 202)
    legend.TextXAlignment = Enum.TextXAlignment.Left
    legend.Parent = panel

    DungeonFarm.mapGui = gui
    DungeonFarm.mapPanel = panel
    DungeonFarm.mapTitle = title
    DungeonFarm.mapSummary = summary
    DungeonFarm.mapCanvas = canvas
    DungeonFarm.mapLegend = legend
    return gui
end

function DungeonFarm.renderMapOverlay(dungeon)
    local gui = DungeonFarm.ensureMapOverlay()
    if not gui then
        return
    end
    gui.Enabled = true
    local canvas = DungeonFarm.mapCanvas
    if not canvas then
        return
    end
    for _, child in ipairs(canvas:GetChildren()) do
        child:Destroy()
    end

    local rooms, startEntry, goldEntry = DungeonFarm.rebuildRoute(dungeon)
    if #rooms == 0 then
        DungeonFarm.mapTitle.Text = "Dungeon Map | Dang cho map"
        DungeonFarm.mapSummary.Text = "Chua co du lieu room."
        DungeonFarm.mapLegend.Text = "P = vi tri hien tai | G = tat ca room vang"
        return
    end

    local _, nativeCells = DungeonFarm.getNativeMapCells()
    local canvasWidth = canvas.AbsoluteSize.X > 0 and canvas.AbsoluteSize.X or 310
    local canvasHeight = canvas.AbsoluteSize.Y > 0 and canvas.AbsoluteSize.Y or 260
    local gridSize = 17
    local cellSize = math.max(8, math.floor(math.min(canvasWidth, canvasHeight) / gridSize))
    local mapSize = cellSize * gridSize
    local mapOffsetX = math.max(0, math.floor((canvasWidth - mapSize) / 2))
    local mapOffsetY = math.max(0, math.floor((canvasHeight - mapSize) / 2))
    local routeByKey = {}
    for index, entry in ipairs(DungeonFarm.route) do
        routeByKey[entry.key] = index
    end
    local goldByKey = {}
    for _, entry in ipairs(DungeonFarm.goldRooms) do
        goldByKey[entry.key] = true
    end

    local function cellPosition(entry)
        -- Native DungeonMinimap uses x increasing right and y increasing down.
        local x = mapOffsetX + (entry.x - 1) * cellSize
        local y = mapOffsetY + (entry.y - 1) * cellSize
        return x, y
    end

    for index = 1, #DungeonFarm.route - 1 do
        local first = DungeonFarm.route[index]
        local second = DungeonFarm.route[index + 1]
        local x1, y1 = cellPosition(first)
        local x2, y2 = cellPosition(second)
        local line = Instance.new("Frame")
        line.BorderSizePixel = 0
        line.BackgroundColor3 = Color3.fromRGB(65, 205, 224)
        line.BackgroundTransparency = 0.1
        line.ZIndex = 1
        if x1 == x2 then
            line.Position = UDim2.fromOffset(x1 + cellSize / 2 - 2, math.min(y1, y2) + cellSize / 2)
            line.Size = UDim2.fromOffset(4, math.abs(y2 - y1) + 2)
        else
            line.Position = UDim2.fromOffset(math.min(x1, x2) + cellSize / 2, y1 + cellSize / 2 - 2)
            line.Size = UDim2.fromOffset(math.abs(x2 - x1) + 2, 4)
        end
        line.Parent = canvas
    end

    for _, entry in ipairs(rooms) do
        local x, y = cellPosition(entry)
        local cell = Instance.new("Frame")
        cell.Name = "Room_" .. tostring(entry.x) .. "_" .. tostring(entry.y)
        cell.Position = UDim2.fromOffset(x, y)
        cell.Size = UDim2.fromOffset(cellSize, cellSize)
        cell.BorderSizePixel = 0
        cell.ZIndex = 2

        local revealed = entry.room:FindFirstChild("ConfirmPart") ~= nil
        local routeIndex = routeByKey[entry.key]
        local isGoldRoom = goldByKey[entry.key] == true
        local nativeCell = nativeCells[tostring(entry.x) .. ":" .. tostring(entry.y)]
        if nativeCell then
            cell.BackgroundColor3 = nativeCell.BackgroundColor3
            cell.BackgroundTransparency = nativeCell.BackgroundTransparency
            cell.BorderColor3 = nativeCell.BorderColor3
            cell.BorderSizePixel = nativeCell.BorderSizePixel
        elseif isGoldRoom then
            cell.BackgroundColor3 = Color3.fromRGB(246, 190, 52)
        elseif entry == startEntry then
            cell.BackgroundColor3 = Color3.fromRGB(83, 220, 122)
        elseif routeIndex then
            cell.BackgroundColor3 = Color3.fromRGB(40, 150, 177)
        elseif revealed then
            cell.BackgroundColor3 = Color3.fromRGB(90, 100, 116)
        else
            cell.BackgroundColor3 = Color3.fromRGB(42, 47, 58)
        end
        cell.Parent = canvas

        if nativeCell then
            for _, nativeDoor in ipairs(nativeCell:GetChildren()) do
                if nativeDoor:IsA("GuiObject") and nativeDoor.Name:match("^Door[1-4]$") then
                    local door = nativeDoor:Clone()
                    door.Visible = true
                    door.ZIndex = 3
                    door.Parent = cell
                end
            end
        end

        if isGoldRoom or entry == startEntry then
            local marker = Instance.new("TextLabel")
            marker.BackgroundTransparency = 1
            marker.Size = UDim2.fromScale(1, 1)
            marker.Font = Enum.Font.GothamBold
            marker.TextSize = math.max(8, math.min(14, cellSize - 4))
            marker.TextColor3 = Color3.fromRGB(20, 25, 30)
            marker.Text = isGoldRoom and "G" or "P"
            marker.ZIndex = 4
            marker.Parent = cell
        end
    end

    local startText = startEntry and (tostring(startEntry.x) .. "," .. tostring(startEntry.y)) or "?"
    local goldText = goldEntry and (tostring(goldEntry.x) .. "," .. tostring(goldEntry.y)) or "?"
    local routeText = #DungeonFarm.route > 0 and tostring(#DungeonFarm.route) .. " room" or "chua tim thay"
    DungeonFarm.mapTitle.Text = "Dungeon Map | Room vang (native)"
    DungeonFarm.mapSummary.Text = string.format(
        "P %s -> G %s | Gold: %d | Route: %s | Da doc %d room",
        startText,
        goldText,
        #DungeonFarm.goldRooms,
        routeText,
        #rooms
    )
    DungeonFarm.mapLegend.Text = "P = vi tri hien tai | G = tat ca room vang | Mau = map game | Xanh = duong toi room vang"
end

function DungeonFarm.updateMapOverlay()
    local gui = DungeonFarm.ensureMapOverlay()
    if not gui then
        return
    end
    local dungeon = DungeonFarm.getDungeon()
    if not dungeon then
        gui.Enabled = false
        return
    end
    DungeonFarm.renderMapOverlay(dungeon)
end

function DungeonFarm.getDoorInfo(prompt, map)
    if not (prompt and map) then
        return nil
    end

    local current = prompt.Parent
    local door
    local taggedDoor = false
    local bossDoor = false
    while current and current ~= map do
        if current:IsA("BasePart") and current.Name == "Door" then
            door = current
        end
        if CollectionService:HasTag(current, "DungeonRoomDoor") then
            taggedDoor = true
        end
        if CollectionService:HasTag(current, "BossDoor") then
            bossDoor = true
        end
        current = current.Parent
    end
    if not door or bossDoor then
        return nil
    end

    local color = door.Color
    local goldColor = math.abs(color.R - 0.85098) <= 0.03
        and math.abs(color.G - 0.713726) <= 0.03
        and math.abs(color.B - 0.219608) <= 0.03
    local namedPrompt = prompt.Name == "DungeonRoomDoorRemotePrompt"
    if not (goldColor or namedPrompt or taggedDoor) then
        return nil
    end

    local room = DungeonFarm.findRoom(door, map)
    return {
        door = door,
        room = room,
        key = door:GetFullName(),
        roomKey = room and room:GetFullName() or nil
    }
end

function DungeonFarm.doorLeadsToRoom(door, room, target)
    if not (door and room and target and room.Parent and target.Parent) or room == target then
        return false
    end

    -- Prefer the native Door1..Door4 direction; position is a fallback for
    -- clients where the physical door model has no directional name.
    local sourceX, sourceY = DungeonFarm.getMapCoordinate(room)
    local targetX, targetY = DungeonFarm.getMapCoordinate(target)
    local center = DungeonFarm.getRoomCenter(room)
    if not (sourceX and sourceY and targetX and targetY and center) then
        return false
    end

    local directionIndex
    local current = door
    while current and current ~= room do
        if current:IsA("Model") then
            local direction = current.Name:match("^Door([1-4])$")
            if direction then
                directionIndex = tonumber(direction)
                break
            end
        end
        current = current.Parent
    end

    if directionIndex then
        local offsets = {
            {1, 0},
            {0, 1},
            {-1, 0},
            {0, -1}
        }
        local offset = offsets[directionIndex]
        return sourceX + offset[1] == targetX and sourceY + offset[2] == targetY
    end

    local delta = door.Position - center
    local nextX, nextY
    if math.abs(delta.X) >= math.abs(delta.Z) then
        nextX = sourceX + (delta.X >= 0 and 1 or -1)
        nextY = sourceY
    else
        nextX = sourceX
        nextY = sourceY + (delta.Z >= 0 and 1 or -1)
    end
    return nextX == targetX and nextY == targetY
end

function DungeonFarm.doorLeadsToGoldTarget(door, room, dungeon)
    local target = DungeonFarm.routeTarget
    return target and DungeonFarm.doorLeadsToRoom(door, room, target) or false
end

function DungeonFarm.findRouteDoor(dungeon, sourceRoom, targetRoom)
    local map = dungeon and dungeon:FindFirstChild("Map")
    if not (map and sourceRoom and targetRoom) then
        return nil
    end
    for _, object in ipairs(map:GetDescendants()) do
        if object:IsA("ProximityPrompt") and object.Enabled then
            local info = DungeonFarm.getDoorInfo(object, map)
            if info and info.room == sourceRoom
                and not DungeonFarm.goldDoorsOpened[info.key]
                and DungeonFarm.doorLeadsToRoom(info.door, sourceRoom, targetRoom) then
                return object, info
            end
        end
    end
    return nil
end

function DungeonFarm.findGoldDoor(dungeon)
    local map = dungeon and dungeon:FindFirstChild("Map")
    if not map then
        return nil
    end

    -- Open the door from the last completed route room to the first incomplete
    -- one. This also handles the red/green route after all gold rooms finish.
    local sourceEntry, targetEntry
    for index, entry in ipairs(DungeonFarm.route) do
        if entry.room.Parent and not DungeonFarm.completed[entry.key] then
            targetEntry = entry
            sourceEntry = index > 1 and DungeonFarm.route[index - 1] or nil
            break
        end
    end
    if sourceEntry and targetEntry
        and sourceEntry.room.Parent and targetEntry.room.Parent
        and DungeonFarm.completed[sourceEntry.key] then
        local object, info = DungeonFarm.findRouteDoor(dungeon, sourceEntry.room, targetEntry.room)
        if object and info then
            return object, info.door, info.room, info.key, info.roomKey
        end
        return nil
    end

    -- A known route target with no matching door must wait for discovery; do
    -- not fall back to an unrelated completed-room door.
    if DungeonFarm.routeTarget then
        return nil
    end

    local fallback
    for _, object in ipairs(map:GetDescendants()) do
        if object:IsA("ProximityPrompt") and object.Enabled then
            local info = DungeonFarm.getDoorInfo(object, map)
            if info and info.roomKey
                and DungeonFarm.completed[info.roomKey]
                and not DungeonFarm.goldDoorsOpened[info.key] then
                if not DungeonFarm.routeTarget
                    or DungeonFarm.doorLeadsToGoldTarget(info.door, info.room, dungeon) then
                    return object, info.door, info.room, info.key, info.roomKey
                end
                fallback = fallback or {object, info.door, info.room, info.key, info.roomKey}
            end
        end
    end
    if not DungeonFarm.routeTarget and fallback then
        return table.unpack(fallback)
    end
    return nil
end

function DungeonFarm.roomHasPendingGoldDoor(room)
    if not room then
        return false
    end
    for _, object in ipairs(room:GetDescendants()) do
        if object:IsA("ProximityPrompt") and object.Enabled then
            local info = DungeonFarm.getDoorInfo(object, room.Parent)
            if info then
                return true
            end
        end
    end
    return false
end

function DungeonFarm.getChestTargets(dungeon, focusRoom)
    local map = dungeon and dungeon:FindFirstChild("Map")
    if not map then
        return {}
    end

    local targets = {}
    local seen = {}
    local function addTarget(candidate)
        if not candidate or not candidate.Parent or not candidate:IsDescendantOf(map) then
            return
        end
        local target = candidate
        if not target:IsA("Model") then
            target = candidate:FindFirstAncestorOfClass("Model") or candidate
        end
        if not target.Parent or seen[target] then
            return
        end
        local room = DungeonFarm.findRoom(target, map)
        local isFocusRoom = focusRoom and room == focusRoom
        if not room
            or (not isFocusRoom and not DungeonFarm.completed[room:GetFullName()])
            or (not isFocusRoom and DungeonFarm.roomHasPendingGoldDoor(room)) then
            return
        end
        local key = target:GetFullName()
        if DungeonFarm.completedChests[key] then
            return
        end
        seen[target] = true
        table.insert(targets, target)
    end

    for _, chest in ipairs(CollectionService:GetTagged("Chest")) do
        addTarget(chest)
    end
    for _, object in ipairs(map:GetDescendants()) do
        if object:IsA("Model") and object.Name == "Closed Chest" then
            addTarget(object)
        end
    end
    return targets
end

function DungeonFarm.canMarkRoomClearedSequential(dungeon, room)
    if not (dungeon and room and room.Parent) then
        return false
    end

    local key = room:GetFullName()
    if DungeonFarm.goldRoomKeys[key] and not DungeonFarm.goldRoomsOpened[key] then
        DungeonFarm.roomEmptySince[key] = nil
        return false
    end
    if DungeonFarm.getRoomConfirmPrompt(room) then
        DungeonFarm.roomEmptySince[key] = nil
        return false
    end

    local liveEnemies, uncertain = DungeonFarm.getLiveEnemies(dungeon, room)
    local chestTargets = DungeonFarm.getChestTargets(dungeon, room)
    if #liveEnemies > 0 or uncertain or DungeonFarm.roomHasChestObject(room) or #chestTargets > 0 then
        DungeonFarm.roomEmptySince[key] = nil
        return false
    end

    -- Gold content and chests can appear a few ticks after the last enemy dies.
    local now = os.clock()
    local emptySince = DungeonFarm.roomEmptySince[key] or now
    DungeonFarm.roomEmptySince[key] = emptySince
    local settleTime = DungeonFarm.goldRoomKeys[key] and 4 or 1.5
    return now - emptySince >= settleTime
end

function DungeonFarm.isGoldRunComplete(dungeon)
    if #DungeonFarm.goldRooms == 0 then
        return false
    end

    for _, entry in ipairs(DungeonFarm.goldRooms) do
        if not DungeonFarm.completed[entry.key] then
            return false
        end
    end

    return #DungeonFarm.getChestTargets(dungeon) == 0
end

function DungeonFarm.isNativeGreenCell(cell)
    -- MapColors[4] trong DungeonGenerator: (101, 185, 101) = room xanh la
    -- cuoi main path (sau boss do). Tuong tu isNativeGoldCell.
    if not (cell and cell:IsA("GuiObject")) then
        return false
    end
    local color = cell.BackgroundColor3
    return math.abs(color.R - 101 / 255) <= 0.02
        and math.abs(color.G - 185 / 255) <= 0.02
        and math.abs(color.B - 101 / 255) <= 0.02
end

function DungeonFarm.findGreenRoomsFromMap(dungeon, rooms)
    local result = {}
    local _, nativeCells = DungeonFarm.getNativeMapCells()
    for _, entry in ipairs(rooms) do
        local cell = nativeCells[tostring(entry.x) .. ":" .. tostring(entry.y)]
        if DungeonFarm.isNativeGreenCell(cell) then
            table.insert(result, entry)
        end
    end
    return result
end

function DungeonFarm.isDoorOpenForProgress(door)
    if not door then
        return false
    end

    local promptCount = 0
    for _, object in ipairs(door:GetDescendants()) do
        if object:IsA("ProximityPrompt") then
            promptCount = promptCount + 1
            if not object.Enabled then
                return true
            end
        end
    end
    if promptCount > 0 then
        return false
    end

    -- Some clients remove/disable the prompt after the door opens. Physical
    -- state is the fallback when the prompt is no longer present.
    for _, object in ipairs(door:GetDescendants()) do
        if object:IsA("BasePart")
            and (not object.CanCollide or object.Transparency >= 0.8) then
            return true
        end
    end
    return false
end

function DungeonFarm.hasOpenedDoorToRoom(dungeon, rooms, targetRoom)
    local map = dungeon and dungeon:FindFirstChild("Map")
    if not (map and targetRoom) then
        return false
    end

    -- Disabled route prompts are the strongest restart-safe progress marker.
    for _, object in ipairs(map:GetDescendants()) do
        if object:IsA("ProximityPrompt") and not object.Enabled then
            local info = DungeonFarm.getDoorInfo(object, map)
            if info and info.room and DungeonFarm.doorLeadsToRoom(info.door, info.room, targetRoom) then
                DungeonFarm.goldDoorsOpened[info.key] = true
                return true
            end
        end
    end

    -- If the prompt was removed, inspect the physical Door1..Door4 model or
    -- Door part belonging to an adjacent room.
    for _, entry in ipairs(rooms or {}) do
        if entry.room ~= targetRoom and entry.room.Parent then
            for _, object in ipairs(entry.room:GetChildren()) do
                local isDoor = (object:IsA("Model") and object.Name:match("^Door[1-4]$"))
                    or (object:IsA("BasePart") and object.Name == "Door")
                if isDoor
                    and DungeonFarm.doorLeadsToRoom(object, entry.room, targetRoom)
                    and DungeonFarm.isDoorOpenForProgress(object) then
                    return true
                end
            end
        end
    end
    return false
end

function DungeonFarm.reconcileDungeonProgress(dungeon, rooms, goldEntries)
    -- Reconcile only the room the player is actually inside. A normal room can
    -- expose two gold doors; treating every disabled prompt as progress here
    -- makes both gold siblings look opened and skips the second room.
    local currentEntry = DungeonFarm.findCurrentMapRoom(rooms)
    for _, entry in ipairs(goldEntries or {}) do
        local key = entry.key
        if currentEntry and currentEntry.room == entry.room
            and DungeonFarm.hasOpenedDoorToRoom(dungeon, rooms, entry.room) then
            -- This is restart recovery for the current room only. Completion
            -- still goes through the normal enemy/chest settle checks below.
            DungeonFarm.goldRoomsOpened[key] = true
        end
    end
end

function DungeonFarm.isGreenRunComplete(dungeon)
    -- Xong khi: khong co room xanh nao, hoac tat ca da clear + het chest.
    local rooms = DungeonFarm.getRouteRooms(dungeon)
    local greens = DungeonFarm.findGreenRoomsFromMap(dungeon, rooms)
    if #greens == 0 then
        return true
    end
    for _, entry in ipairs(greens) do
        if entry.room.Parent and not DungeonFarm.completed[entry.key] then
            return false
        end
    end
    return #DungeonFarm.getChestTargets(dungeon) == 0
end

function DungeonFarm.roomHasChestObject(room)
    if not room then
        return false
    end
    for _, object in ipairs(room:GetDescendants()) do
        if CollectionService:HasTag(object, "Chest")
            or (object:IsA("Model") and object.Name == "Closed Chest") then
            return true
        end
    end
    return false
end

function DungeonFarm.reconcileCurrentGoldRoom(dungeon)
    local target = DungeonFarm.goldTargetRoom
    if not (target and target.Parent and DungeonFarm.goldRoomKeys[target:GetFullName()]) then
        return false
    end

    local rooms = DungeonFarm.getRouteRooms(dungeon)
    local current = DungeonFarm.findCurrentMapRoom(rooms)
    if not (current and current.room == target) then
        DungeonFarm.goldRoomEmptySince[target:GetFullName()] = nil
        return false
    end

    local liveEnemies, uncertainEnemies = DungeonFarm.getLiveEnemies(dungeon, target)
    local hasConfirm = DungeonFarm.getRoomConfirmPrompt(target) ~= nil
    local hasDoor = DungeonFarm.roomHasPendingGoldDoor(target)
    local hasChest = DungeonFarm.roomHasChestObject(target)
    local key = target:GetFullName()
    if not DungeonFarm.goldRoomsOpened[key] then
        DungeonFarm.goldRoomEmptySince[key] = nil
        return false
    end
    if #liveEnemies > 0 or uncertainEnemies or hasConfirm or hasDoor or hasChest then
        DungeonFarm.goldRoomEmptySince[key] = nil
        return false
    end

    local now = os.clock()
    local emptySince = DungeonFarm.goldRoomEmptySince[key] or now
    DungeonFarm.goldRoomEmptySince[key] = emptySince
    if now - emptySince < 6 then
        return false
    end

    -- A rejoin can resume inside an already-cleared gold room with no prompt or enemy.
    DungeonFarm.markRoomCleared(target)
    DungeonFarm.goldRoomEmptySince[key] = nil
    DungeonFarm.lastMessage = "Da xac nhan room vang " .. tostring(target.Name) .. "."
    DungeonFarm.updateStatus("Dungeon Farm: GOLD DONE", DungeonFarm.lastMessage)
    return true
end

function DungeonFarm.enemyCount(dungeon)
    local enemies = dungeon and dungeon:FindFirstChild("Enemies")
    return enemies and #enemies:GetChildren() or 0
end

function DungeonFarm.getTargetPosition(target)
    if not target or not target.Parent then
        return nil
    end
    if target:IsA("BasePart") then
        return target.Position
    end
    if target:IsA("Model") then
        local ok, pivot = pcall(function()
            return target:GetPivot()
        end)
        if ok and pivot then
            return pivot.Position
        end
    end
    return nil
end

function DungeonFarm.flyTo(targetPart, token)
    local character = LocalPlayer.Character
    local root = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
    local targetPosition = DungeonFarm.getTargetPosition(targetPart)
    if not (character and root and targetPart and targetPosition) then
        return false
    end

    local target = targetPosition + Vector3.new(0, 3, 0)
    local distance = (root.Position - target).Magnitude
    local teleportDistance = DungeonFarm.normalizeTeleportDistance(DungeonFarm.teleportDistance)
    local flySpeed = DungeonFarm.normalizeFlySpeed(DungeonFarm.flySpeed)
    DungeonFarm.teleportDistance = teleportDistance
    DungeonFarm.flySpeed = flySpeed
    local orientation = root.CFrame - root.Position

    local function placeCharacter(position)
        local nextCFrame = CFrame.new(position) * orientation
        local ok = pcall(function()
            character:PivotTo(nextCFrame)
            root.CFrame = nextCFrame
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
        return ok
    end

    if distance <= teleportDistance then
        if not placeCharacter(target) then
            return false
        end
        task.wait(0.08)
        return root.Parent and (root.Position - target).Magnitude <= 14
    end

    local collisionState = {}
    for _, object in ipairs(character:GetDescendants()) do
        if object:IsA("BasePart") then
            collisionState[object] = object.CanCollide
            object.CanCollide = false
        end
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local oldAnchored = root.Anchored
    local oldAutoRotate = humanoid and humanoid.AutoRotate
    local oldPlatformStand = humanoid and humanoid.PlatformStand
    root.Anchored = true
    if humanoid then
        humanoid.AutoRotate = false
        humanoid.PlatformStand = true
    end

    local travelBudget = math.max(35, distance / math.max(flySpeed, 40) * 2.5 + 8)
    local deadline = os.clock() + math.clamp(travelBudget, 35, 120)
    local reached = true
    local stalledSince = nil
    local lastDistance = distance

    while root.Parent and (root.Position - target).Magnitude > 8 do
        if not alive() or token ~= DungeonFarm.token or not DungeonFarm.enabled then
            reached = false
            break
        end
        if os.clock() >= deadline then
            reached = false
            break
        end
        if not targetPart.Parent then
            reached = false
            break
        end

        local delta = target - root.Position
        local distance = delta.Magnitude
        local step = math.min(flySpeed * 0.05, distance)
        if distance <= 0 then
            break
        end
        local previousPosition = root.Position
        if not placeCharacter(previousPosition + delta.Unit * step) then
            reached = false
            break
        end
        task.wait(0.05)
        local remainingDistance = (root.Position - target).Magnitude
        if remainingDistance < lastDistance - 0.5 then
            lastDistance = remainingDistance
            stalledSince = nil
        else
            stalledSince = stalledSince or os.clock()
            if os.clock() - stalledSince >= 2.5 then
                reached = false
                break
            end
        end
    end

    if reached and root.Parent then
        if not placeCharacter(target) then
            reached = false
        end
        task.wait(0.15)
        reached = reached and (root.Position - target).Magnitude <= 12
    end

    if humanoid then
        humanoid.AutoRotate = oldAutoRotate
        humanoid.PlatformStand = oldPlatformStand
    end
    root.Anchored = oldAnchored
    for object, canCollide in pairs(collisionState) do
        if object.Parent then
            object.CanCollide = canCollide
        end
    end
    return reached
end

function DungeonFarm.isLiveEnemy(enemy, enemies, _forceProbe)
    if not (enemy and enemy.Parent == enemies and enemy:IsA("Model")) then
        return false, false
    end
    if DungeonFarm.deadEnemies[enemy] then
        return false, false
    end

    local now = os.clock()
    DungeonFarm.enemySeenAt[enemy] = DungeonFarm.enemySeenAt[enemy] or now
    local dead = false
    local aliveFlag = true
    pcall(function()
        dead = enemy:GetAttribute("Dead") == true or enemy:GetAttribute("IsDead") == true
        aliveFlag = enemy:GetAttribute("Alive") ~= false
    end)
    if dead or not aliveFlag then
        return false, false
    end

    local health = Feature.getHealth(enemy)
    local attackable = false
    pcall(function()
        attackable = CollectionService:HasTag(enemy, "Attackable")
    end)
    if health ~= nil and health <= 0 then
        return false, false
    end

    -- Attackable can briefly exist before the model has the target parts that
    -- SendPet requires. Do not count an un-targetable model as a live enemy
    -- forever, otherwise one stale spawn leaves the room at "Con 1 enemy".
    local targetRoot = enemy.PrimaryPart
        or enemy:FindFirstChild("HumanoidRootPart", true)
        or enemy:FindFirstChild("RootPart", true)
    local targetReady = targetRoot ~= nil and enemy:FindFirstChild("Attackers") ~= nil
    if not targetReady then
        if now - DungeonFarm.enemySeenAt[enemy] < 4 then
            return false, true
        end
        return false, false
    end

    if attackable then
        return true, false
    end

    -- Attackable is added by the game's local enemy handler after spawn. Give it
    -- a short settle window, then treat an untagged model as stale.
    if now - DungeonFarm.enemySeenAt[enemy] < 4 then
        return false, true
    end
    return false, false
end

function DungeonFarm.enemyBelongsToRoom(enemy, room)
    if not room then
        return true
    end

    local enemyPosition = DungeonFarm.getTargetPosition(enemy)
    if not enemyPosition then
        return true
    end

    local ok, boxCFrame, boxSize = pcall(function()
        return room:GetBoundingBox()
    end)
    if ok and boxCFrame and boxSize then
        local localPosition = boxCFrame:PointToObjectSpace(enemyPosition)
        return math.abs(localPosition.X) <= boxSize.X / 2 + 16
            and math.abs(localPosition.Z) <= boxSize.Z / 2 + 16
            and math.abs(localPosition.Y) <= boxSize.Y / 2 + 30
    end

    local center = DungeonFarm.getRoomCenter(room)
    return not center or (enemyPosition - center).Magnitude <= 55
end

function DungeonFarm.getLiveEnemies(dungeon, room)
    local enemies = dungeon and dungeon:FindFirstChild("Enemies")
    local result = {}
    local uncertain = false
    if not enemies then
        return result, false
    end
    for _, enemy in ipairs(enemies:GetChildren()) do
        local live, unknown = DungeonFarm.isLiveEnemy(enemy, enemies)
        if live and DungeonFarm.enemyBelongsToRoom(enemy, room) then
            table.insert(result, enemy)
        elseif unknown and DungeonFarm.enemyBelongsToRoom(enemy, room) then
            uncertain = true
        end
    end
    DungeonFarm.lastLiveScanAt = os.clock()
    DungeonFarm.lastLiveScanCount = #result
    DungeonFarm.lastLiveScanUncertain = uncertain
    return result, uncertain
end

function DungeonFarm.clearEnemies(dungeon, token, room)
    local enemies = dungeon and dungeon:FindFirstChild("Enemies")
    local sendEvent = Bindable:FindFirstChild("SendPet")
    if not enemies then
        return false, "Khong tim thay folder Enemies."
    end
    if not sendEvent then
        return false, "Bindable.SendPet khong ton tai."
    end

    local function prepareEnemy(enemy)
        if not (enemy and enemy.Parent == enemies and enemy:IsA("Model")) then
            return false
        end
        local primary = enemy.PrimaryPart
            or enemy:FindFirstChild("HumanoidRootPart", true)
            or enemy:FindFirstChild("RootPart", true)
        if primary and primary:IsA("BasePart") and not enemy.PrimaryPart then
            pcall(function()
                enemy.PrimaryPart = primary
            end)
        end
        return enemy.PrimaryPart ~= nil and enemy:FindFirstChild("Attackers") ~= nil
    end

    local function sendToEnemy(enemy)
        if not prepareEnemy(enemy) then
            return false, "Enemy chua san sang target."
        end
        local ok, err = pcall(function()
            sendEvent:Fire(enemy, true, true)
        end)
        if not ok then
            DungeonFarm.lastCombatError = tostring(err)
            return false, "Gui pet loi: " .. tostring(err)
        end
        DungeonFarm.lastCombatTarget = enemy:GetFullName()
        DungeonFarm.lastCombatSendAt = os.clock()
        DungeonFarm.combatSendCount = DungeonFarm.combatSendCount + 1
        DungeonFarm.lastCombatError = ""
        return true
    end

    local deadline = os.clock() + 180
    while enemies.Parent do
        if not alive() or token ~= DungeonFarm.token or not DungeonFarm.enabled then
            return false, "Da dung dungeon farm."
        end
        if tostring(getPlayerValue("World", "")) ~= "Dungeon" then
            return false, "Da roi khoi dungeon."
        end
        if os.clock() >= deadline then
            return false, "Combat qua lau, het thoi gian cho room."
        end

        local enemyList, uncertain = DungeonFarm.getLiveEnemies(dungeon, room)
        if #enemyList == 0 then
            if uncertain then
                task.wait(0.25)
                continue
            end
            DungeonFarm.lastEnemyCount = 0
            return true, "Da clear enemy."
        end

        -- Pick the nearest READY target first so one unspawned model never
        -- blocks the rest of the room while the player stands still.
        local selfRoot = LocalPlayer.Character
            and (LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or LocalPlayer.Character.PrimaryPart)
        local selfPos = selfRoot and selfRoot.Position or nil
        table.sort(enemyList, function(a, b)
            if not selfPos then
                return tostring(a:GetFullName()) < tostring(b:GetFullName())
            end
            local pa = DungeonFarm.getTargetPosition(a)
            local pb = DungeonFarm.getTargetPosition(b)
            local da = pa and (pa - selfPos).Magnitude or math.huge
            local db = pb and (pb - selfPos).Magnitude or math.huge
            return da < db
        end)
        local enemy = nil
        for _, candidate in ipairs(enemyList) do
            if prepareEnemy(candidate) then
                enemy = candidate
                break
            end
        end
        if not enemy then
            -- Nothing ready yet (models still spawning): wait briefly and rescan
            -- instead of holding a dead handle while other enemies stay idle.
            task.wait(0.5)
            continue
        end
        DungeonFarm.updateStatus(
            "Dungeon Farm: COMBAT",
            string.format(
                "Room %s | Dang toi quai %s | Con %d enemy",
                tostring(DungeonFarm.room or "?"),
                tostring(enemy.Name),
                #enemyList
            )
        )
        if not DungeonFarm.flyTo(enemy, token) then
            return false, "Fly toi enemy " .. tostring(enemy.Name) .. " that bai."
        end

        local lastSend = 0
        local notReadySince = nil
        local droppedNotReady = false
        local lastFlyCheck = os.clock()
        local targetLive, targetUnknown = DungeonFarm.isLiveEnemy(enemy, enemies, true)
        while targetLive or targetUnknown do
            if not alive() or token ~= DungeonFarm.token or not DungeonFarm.enabled then
                return false, "Da dung dungeon farm."
            end
            if tostring(getPlayerValue("World", "")) ~= "Dungeon" then
                return false, "Da roi khoi dungeon."
            end
            if os.clock() >= deadline then
                return false, "Combat qua lau, het thoi gian cho room."
            end

            -- Re-send only to the current target while it remains alive.
            -- If it never becomes ready, drop it and re-pick instead of
            -- standing still while the rest of the room stays idle.
            if os.clock() - lastSend >= 1 then
                local ok, reason = sendToEnemy(enemy)
                if not ok and reason ~= "Enemy chua san sang target." then
                    return false, reason
                end
                if ok then
                    lastSend = os.clock()
                    notReadySince = nil
                elseif notReadySince == nil then
                    notReadySince = os.clock()
                elseif os.clock() - notReadySince >= 6 then
                    droppedNotReady = true
                    break
                end
            end

            -- The target can walk away while pets chase it: re-fly when far.
            if os.clock() - lastFlyCheck >= 3 then
                lastFlyCheck = os.clock()
                local myRoot = LocalPlayer.Character
                    and (LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or LocalPlayer.Character.PrimaryPart)
                local enemyPos = DungeonFarm.getTargetPosition(enemy)
                if myRoot and enemyPos and (myRoot.Position - enemyPos).Magnitude > 30 then
                    DungeonFarm.flyTo(enemy, token)
                end
            end

            targetLive, targetUnknown = DungeonFarm.isLiveEnemy(enemy, enemies, true)
            local remaining = #DungeonFarm.getLiveEnemies(dungeon, room)
            DungeonFarm.lastEnemyCount = remaining
            DungeonFarm.updateStatus(
                "Dungeon Farm: COMBAT",
                string.format(
                    "Room %s | Dang danh %s | Con %d enemy",
                    tostring(DungeonFarm.room or "?"),
                    tostring(enemy.Name),
                    remaining
                )
            )
            task.wait(0.25)
        end

        if not targetUnknown and not droppedNotReady then
            -- Exclude the dead model immediately so the next pass picks a fresh target.
            DungeonFarm.deadEnemies[enemy] = true
        end
        local refreshedEnemies, refreshedUncertain = DungeonFarm.getLiveEnemies(dungeon, room)
        DungeonFarm.lastEnemyCount = #refreshedEnemies
        DungeonFarm.updateStatus(
            "Dungeon Farm: COMBAT",
            string.format(
                droppedNotReady and "Room %s | Bo qua %s chua san sang | Con %d enemy"
                    or "Room %s | Da ha %s | Chuyen muc tieu | Con %d enemy",
                tostring(DungeonFarm.room or "?"),
                tostring(enemy.Name),
                DungeonFarm.lastEnemyCount
            )
        )
        if #refreshedEnemies == 0 and not refreshedUncertain then
            return true, "Da clear enemy."
        end
        task.wait(0.05)
    end

    if not enemies.Parent then
        DungeonFarm.lastEnemyCount = 0
        return true, "Da clear enemy."
    end
    return false, "Folder Enemies da bi dong khi dang combat."
end

function DungeonFarm.clearChests(dungeon, token, focusRoom)
    local sendEvent = Bindable:FindFirstChild("SendPet")
    if not sendEvent then
        return false, "Bindable.SendPet khong ton tai."
    end

    local deadline = os.clock() + 180
    local lastSend = 0
    while dungeon and dungeon.Parent do
        if not alive() or token ~= DungeonFarm.token or not DungeonFarm.enabled then
            return false, "Da dung dungeon farm."
        end
        if tostring(getPlayerValue("World", "")) ~= "Dungeon" then
            return false, "Da roi khoi dungeon."
        end
        if os.clock() >= deadline then
            return false, "Farm chest qua lau, het thoi gian cho chest."
        end

        local chests = DungeonFarm.getChestTargets(dungeon, focusRoom)
        if #chests == 0 then
            DungeonFarm.lastEnemyCount = 0
            return true, "Da clear chest."
        end

        if os.clock() - lastSend >= 1 then
            for _, chest in ipairs(chests) do
                if chest.Parent then
                    local ok, err = pcall(function()
                        sendEvent:Fire(chest, true, true)
                    end)
                    if not ok then
                        return false, "Gui pet danh chest loi: " .. tostring(err)
                    end
                end
            end
            lastSend = os.clock()
        end

        DungeonFarm.lastEnemyCount = #chests
        DungeonFarm.updateStatus(
            "Dungeon Farm: CHEST",
            string.format("Room %s | Con %d chest", tostring(DungeonFarm.room or "?"), DungeonFarm.lastEnemyCount)
        )
        task.wait(0.5)
    end
    return false, "Map Dungeon da bi dong khi farm chest."
end

function DungeonFarm.openGoldDoor(prompt, door, room, token)
    if not (prompt and door and room) then
        return false, "Thieu du lieu cua route door."
    end
    local key = door:GetFullName()
    DungeonFarm.phase = "opening_door"
    DungeonFarm.updateStatus("Dungeon Farm: ROUTE DOOR", "Dang bay toi route trong room " .. tostring(room.Name) .. "...")
    if not DungeonFarm.flyTo(door, token) then
        return false, "Fly toi route door " .. tostring(room.Name) .. " that bai."
    end

    local ok, err = pcall(function()
        if type(fireproximityprompt) ~= "function" then
            error("fireproximityprompt khong ton tai trong executor.")
        end
        fireproximityprompt(prompt)
    end)
    if not ok then
        return false, "Instant interaction route door loi: " .. tostring(err)
    end

    local deadline = os.clock() + 25
    local lastFire = 0
    local fireCount = 0
    while alive() and token == DungeonFarm.token and DungeonFarm.enabled do
        if not prompt.Parent or not prompt.Enabled then
            DungeonFarm.goldDoorsOpened[key] = true
            local sourceKey = room:GetFullName()
            if DungeonFarm.goldRoomKeys[sourceKey] then
                DungeonFarm.goldRoomsOpened[sourceKey] = true
            end
            local target = DungeonFarm.routeTarget
            if target and DungeonFarm.doorLeadsToRoom(door, room, target) then
                DungeonFarm.targetRoom = target
                DungeonFarm.room = target.Name
                local targetKey = target:GetFullName()
                local targetIsGold = DungeonFarm.goldRoomKeys[targetKey] == true
                DungeonFarm.goldContentActive = targetIsGold
                if targetIsGold then
                    DungeonFarm.goldRoomsOpened[targetKey] = true
                end
                -- The next loop iteration enforces the gold team via the
                -- combat/chest path, so a transient sync flap here must not
                -- abort the run right after the door opened.
                local targetTeamIndex, targetRole = DungeonFarm.getRoomTeamIndex(target)
                if not DungeonFarm.ensureTeamApplied(targetTeamIndex, targetRole) then
                    DungeonFarm.lastMessage = "Da mo route door, dang thu lai team muc tieu."
                    DungeonFarm.updateStatus("Dungeon Farm: TEAM", DungeonFarm.lastMessage)
                end
            end
            return true, "Da mo cua vang."
        end
        if os.clock() >= deadline then
            break
        end
        -- Single-fire was fragile: lag or drift left the prompt enabled and
        -- the farm stood still before the gold door. Keep firing while in
        -- range and re-fly when knocked away.
        if os.clock() - lastFire >= 1 then
            lastFire = os.clock()
            fireCount = fireCount + 1
            local myRoot = LocalPlayer.Character
                and (LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or LocalPlayer.Character.PrimaryPart)
            local doorPos = DungeonFarm.getTargetPosition(door)
            if myRoot and doorPos and (myRoot.Position - doorPos).Magnitude > 18 then
                DungeonFarm.updateStatus(
                    "Dungeon Farm: ROUTE DOOR",
                    string.format("Bi day khoi route door, bay lai (%d)...", fireCount)
                )
                DungeonFarm.flyTo(door, token)
            end
            pcall(function()
                fireproximityprompt(prompt)
            end)
        end
        task.wait(0.25)
    end
    return false, "Route door " .. tostring(room.Name) .. " khong doi trang thai sau khi active."
end

function DungeonFarm.fail(reason, token)
    if token and token ~= DungeonFarm.token then
        return
    end
    DungeonFarm.running = false
    DungeonFarm.phase = "error"
    DungeonFarm.lastMessage = tostring(reason)
    DungeonFarm.updateStatus("Dungeon Farm: LOI", tostring(reason))
    notifyStatus("Auto Dungeon", "Dungeon farm loi: " .. tostring(reason))
    Feature.autoDungeonEnabled = false
    if dungeonToggle then
        dungeonToggleUpdating = true
        pcall(function()
            dungeonToggle:Set(false)
        end)
        dungeonToggleUpdating = false
    end
    DungeonFarm.enabled = false
    if dungeonFarmToggle then
        DungeonFarm.toggleUpdating = true
        pcall(function()
            dungeonFarmToggle:Set(false)
        end)
        DungeonFarm.toggleUpdating = false
    end
    saveConfig(true)
    if DungeonFarm.restore then
        task.spawn(function()
            protectedCall("Restore failed dungeon farm", function()
                DungeonFarm.restore("Dungeon farm loi: " .. tostring(reason))
            end)
        end)
    end
end

function DungeonFarm.start()
    if tostring(getPlayerValue("World", "")) == "Dungeon" then
        -- Recover state when the player entered manually or the world callback ran first.
        dungeonActive = true
        DungeonFarm.entered = true
    end
    if not DungeonFarm.enabled or not dungeonActive then
        return
    end
    if not DungeonFarm.entered or DungeonFarm.running then
        return
    end

    local activeDungeon = DungeonFarm.getDungeon()
    local preserveProgress = DungeonFarm.sessionDungeon ~= nil
        and (activeDungeon == nil or DungeonFarm.sessionDungeon == activeDungeon)

    DungeonFarm.token = DungeonFarm.token + 1
    local token = DungeonFarm.token
    DungeonFarm.running = true
    DungeonFarm.phase = "searching"
    if not preserveProgress then
        DungeonFarm.room = nil
        DungeonFarm.targetRoom = nil
        DungeonFarm.targetPart = nil
        DungeonFarm.activationAt = 0
        DungeonFarm.lastEnemyCount = 0
        DungeonFarm.completed = {}
        DungeonFarm.attempts = {}
        DungeonFarm.goldRooms = {}
        DungeonFarm.goldDoorsOpened = {}
        DungeonFarm.goldRoomsOpened = {}
        DungeonFarm.completedChests = {}
        DungeonFarm.enemySeenAt = {}
        DungeonFarm.lastCombatTarget = nil
        DungeonFarm.lastCombatSendAt = 0
        DungeonFarm.combatSendCount = 0
        DungeonFarm.lastCombatError = ""
        DungeonFarm.lastLiveScanAt = 0
        DungeonFarm.lastLiveScanCount = 0
        DungeonFarm.lastLiveScanUncertain = false
        DungeonFarm.deadEnemies = {}
        DungeonFarm.route = {}
        DungeonFarm.routeKey = ""
        DungeonFarm.routeTarget = nil
        DungeonFarm.goldTargetKey = nil
        DungeonFarm.goldTargetRoom = nil
        DungeonFarm.greenTargetKey = nil
        DungeonFarm.goldRoomKeys = {}
        DungeonFarm.goldContentActive = false
        DungeonFarm.goldRoomEmptySince = {}
        DungeonFarm.roomEmptySince = {}
        DungeonFarm.lastRouteWalkAt = 0
        DungeonFarm.lastRouteWalkTargetKey = nil
        DungeonFarm.greenWaitSince = nil
        DungeonFarm.lastEquippedPetCount = DungeonFarm.getEquippedPetCount()
        DungeonFarm.teamApplied = false
        DungeonFarm.teamApplying = false
        DungeonFarm.teamIndexApplied = nil
        DungeonFarm.teamAppliedAt = 0
        DungeonFarm.startedAt = os.clock()
        DungeonFarm.lastMessage = "Dang tim ConfirmPart active."
    end
    if activeDungeon then
        DungeonFarm.sessionDungeon = activeDungeon
    end

    local entryTeamReady = false
    task.spawn(function()
        while alive() and dungeonActive and DungeonFarm.enabled and token == DungeonFarm.token do
            if tostring(getPlayerValue("World", "")) ~= "Dungeon" then
                if token == DungeonFarm.token then
                    DungeonFarm.running = false
                end
                return
            end

            local dungeon = DungeonFarm.getDungeon()
            if not dungeon then
                DungeonFarm.phase = "waiting"
                DungeonFarm.updateStatus("Dungeon Farm: CHO", "Dang cho map Dungeon load...")
                task.wait(0.5)
            else
                if DungeonFarm.sessionDungeon == nil then
                    DungeonFarm.sessionDungeon = dungeon
                end
                if not entryTeamReady then
                    local entryTeamIndex, entryTeamRole = DungeonFarm.getRoomTeamIndex(DungeonFarm.targetRoom)
                    DungeonFarm.phase = "team_retry"
                    DungeonFarm.updateStatus(
                        "Dungeon Farm: TEAM",
                        string.format(
                            "Dang dong bo team %d truoc khi farm | Pet %d",
                            entryTeamIndex,
                            DungeonFarm.getEquippedPetCount()
                        )
                    )
                    if not DungeonFarm.ensureTeamApplied(entryTeamIndex, entryTeamRole or "normal")
                        or DungeonFarm.getEquippedPetCount() == 0 then
                        DungeonFarm.lastMessage = "Dang thu lai equip team truoc khi farm."
                        task.wait(0.5)
                        continue
                    end
                    entryTeamReady = true
                end

                if DungeonFarm.getEquippedPetCount() == 0 then
                    local recoveryIndex, recoveryRole = DungeonFarm.getRoomTeamIndex(DungeonFarm.targetRoom)
                    DungeonFarm.phase = "team_recovery"
                    DungeonFarm.updateStatus(
                        "Dungeon Farm: TEAM LAI",
                        string.format("EquippedPets = 0 | dang nap lai team %d...", recoveryIndex)
                    )
                    if not DungeonFarm.ensureTeamApplied(recoveryIndex, recoveryRole or "normal")
                        or DungeonFarm.getEquippedPetCount() == 0 then
                        entryTeamReady = false
                        DungeonFarm.lastMessage = "Dang thu lai vi EquippedPets van dang 0."
                        task.wait(0.5)
                        continue
                    end
                end
                local _, currentEntry = DungeonFarm.rebuildRoute(dungeon)
                local staleTarget = DungeonFarm.targetRoom
                if staleTarget and staleTarget.Parent and currentEntry
                    and currentEntry.room ~= staleTarget then
                    -- Manual movement or a refreshed map invalidates the old
                    -- focus room; let the route scanner select the room now
                    -- under the player instead of waiting on stale state.
                    DungeonFarm.targetRoom = nil
                    DungeonFarm.targetPart = nil
                    DungeonFarm.room = nil
                end
                if DungeonFarm.reconcileCurrentGoldRoom(dungeon) then
                    task.wait(0.1)
                    continue
                end
                local enemies = dungeon:FindFirstChild("Enemies")
                local focusRoom = DungeonFarm.targetRoom and DungeonFarm.targetRoom.Parent
                    and currentEntry and currentEntry.room == DungeonFarm.targetRoom
                    and DungeonFarm.targetRoom or nil
                if not focusRoom and currentEntry then
                    -- Enemies from unrevealed/future rooms can exist in the
                    -- shared Enemies folder. Only fight the current route room.
                    focusRoom = currentEntry.room
                end
                local liveEnemies, uncertainEnemies
                if focusRoom then
                    liveEnemies, uncertainEnemies = DungeonFarm.getLiveEnemies(dungeon, focusRoom)
                else
                    liveEnemies, uncertainEnemies = DungeonFarm.getLiveEnemies(dungeon)
                end
                if #liveEnemies > 0 or uncertainEnemies then
                    local _, currentEntry = DungeonFarm.rebuildRoute(dungeon)
                    local combatRoom = DungeonFarm.targetRoom or (currentEntry and currentEntry.room)
                    if combatRoom then
                        DungeonFarm.targetRoom = combatRoom
                        DungeonFarm.room = combatRoom.Name
                    else
                        combatRoom = currentEntry and currentEntry.room or nil
                    end
                    -- Team sync can flap for a few seconds after a swap: retry the
                    -- loop instead of aborting the whole run and standing still.
                    if not DungeonFarm.ensureRoomTeam(combatRoom) then
                        DungeonFarm.phase = "team_retry"
                        DungeonFarm.lastMessage = "Dang thu lai equip team cho room combat."
                        DungeonFarm.updateStatus("Dungeon Farm: TEAM", DungeonFarm.lastMessage)
                        task.wait(1)
                        continue
                    end
                    DungeonFarm.phase = "combat"
                    local ok, reason = DungeonFarm.clearEnemies(dungeon, token, combatRoom)
                    if not ok then
                        DungeonFarm.fail(reason, token)
                        return
                    end
                    local chestOK, chestReason = DungeonFarm.clearChests(dungeon, token, combatRoom)
                    if not chestOK then
                        DungeonFarm.fail(chestReason, token)
                        return
                    end
                    if DungeonFarm.canMarkRoomClearedSequential(dungeon, combatRoom) then
                        DungeonFarm.markRoomCleared(combatRoom)
                    else
                        DungeonFarm.phase = "waiting_room"
                        DungeonFarm.lastMessage = "Room " .. tostring(combatRoom.Name)
                            .. " dang cho chest/du lieu on dinh."
                        DungeonFarm.updateStatus("Dungeon Farm: CHO ROOM", DungeonFarm.lastMessage)
                        task.wait(0.35)
                        continue
                    end
                else
                    local chests = DungeonFarm.getChestTargets(dungeon, focusRoom)
                    if #chests > 0 then
                        local map = dungeon:FindFirstChild("Map")
                        local chestRoom = map and DungeonFarm.findRoom(chests[1], map) or nil
                        local chestRooms = {}
                        if map then
                            for _, chest in ipairs(chests) do
                                local room = DungeonFarm.findRoom(chest, map)
                                if room then
                                    chestRooms[room] = true
                                end
                            end
                        end
                        if chestRoom then
                            DungeonFarm.room = chestRoom.Name
                        end
                        local chestTeamIndex, chestRole = DungeonFarm.getRoomTeamIndex(chestRoom)
                        if DungeonFarm.goldContentActive then
                            chestTeamIndex = tonumber(dungeonSelection.goldTeamIndex)
                                or tonumber(dungeonSelection.normalTeamIndex)
                                or 1
                            chestRole = "gold"
                        end
                        if not DungeonFarm.ensureTeamApplied(chestTeamIndex, chestRole) then
                            DungeonFarm.phase = "team_retry"
                            DungeonFarm.lastMessage = "Dang thu lai equip team cho room chest."
                            DungeonFarm.updateStatus("Dungeon Farm: TEAM", DungeonFarm.lastMessage)
                            task.wait(1)
                            continue
                        end
                        DungeonFarm.phase = "chest"
                        local ok, reason = DungeonFarm.clearChests(dungeon, token, chestRoom)
                        if not ok then
                            DungeonFarm.fail(reason, token)
                            return
                        end
                        for room in pairs(chestRooms) do
                            if DungeonFarm.canMarkRoomClearedSequential(dungeon, room) then
                                DungeonFarm.markRoomCleared(room)
                            end
                        end
                    else
                        if DungeonFarm.isGoldRunComplete(dungeon) then
                            if DungeonFarm.isGreenRunComplete(dungeon) then
                                local left, reason = DungeonFarm.leaveAfterGold(token)
                                if not left then
                                    DungeonFarm.fail(reason, token)
                                end
                                return
                            end
                            -- Gold xong: farm not room xanh la cuoi truoc khi out.
                            -- Roi xuong duoi, findPrompt se tu active/clear cac
                            -- room con lai (het gold thi no chon prompt gan nhat).
                            -- Chong ket: qua 5 phut khong xong xanh thi van out.
                            DungeonFarm.greenWaitSince = DungeonFarm.greenWaitSince or os.clock()
                            if os.clock() - DungeonFarm.greenWaitSince >= 300 then
                                DungeonFarm.updateStatus(
                                    "Dungeon Farm: OUT",
                                    "Qua 5 phut chua xong room xanh; out..."
                                )
                                local left, reason = DungeonFarm.leaveAfterGold(token)
                                if not left then
                                    DungeonFarm.fail(reason, token)
                                end
                                return
                            end
                            DungeonFarm.phase = "final"
                            DungeonFarm.updateStatus(
                                "Dungeon Farm: FINAL",
                                "Da xong room vang; dang farm room xanh la cuoi..."
                            )
                        end

                        -- Gold da xong (dang farm room xanh): khong mo cua vang
                        -- nua, di thang toi prompt room thuong.
                        local doorPrompt, doorPart, doorRoom
                        doorPrompt, doorPart, doorRoom = DungeonFarm.findGoldDoor(dungeon)
                        if doorPrompt then
                            if not DungeonFarm.ensureRoomTeam(doorRoom) then
                                DungeonFarm.phase = "team_retry"
                                DungeonFarm.lastMessage = "Dang thu lai equip team truoc cua vang."
                                DungeonFarm.updateStatus("Dungeon Farm: TEAM", DungeonFarm.lastMessage)
                                task.wait(1)
                                continue
                            end
                            local ok, reason = DungeonFarm.openGoldDoor(doorPrompt, doorPart, doorRoom, token)
                            if not ok then
                                DungeonFarm.fail(reason, token)
                                return
                            end
                            task.wait(0.5)
                        else
                            local pendingRoom = DungeonFarm.targetRoom
                            if pendingRoom and pendingRoom.Parent
                                and not DungeonFarm.completed[pendingRoom:GetFullName()]
                                and not DungeonFarm.getRoomConfirmPrompt(pendingRoom) then
                                local pendingIsCurrent = currentEntry and currentEntry.room == pendingRoom
                                if not pendingIsCurrent then
                                    DungeonFarm.targetRoom = nil
                                    DungeonFarm.targetPart = nil
                                    DungeonFarm.room = nil
                                    pendingRoom = nil
                                elseif DungeonFarm.canMarkRoomClearedSequential(dungeon, pendingRoom) then
                                    DungeonFarm.markRoomCleared(pendingRoom)
                                    DungeonFarm.roomEmptySince[pendingRoom:GetFullName()] = nil
                                    task.wait(0.1)
                                    continue
                                end
                                if pendingRoom then
                                    DungeonFarm.phase = "waiting_room"
                                    DungeonFarm.lastMessage = "Dang cho room " .. tostring(pendingRoom.Name)
                                        .. " spawn du enemy/chest truoc khi di tiep."
                                    DungeonFarm.updateStatus("Dungeon Farm: CHO ROOM", DungeonFarm.lastMessage)
                                    task.wait(0.5)
                                    continue
                                end
                            end
                            local prompt, room, part, key = DungeonFarm.findPrompt(dungeon)
                            if not prompt then
                                if DungeonFarm.revealNextRouteRoom(dungeon, token) then
                                    task.wait(0.35)
                                    continue
                                end
                                local totalConfirmParts, pendingConfirmParts, enabledConfirmParts =
                                    DungeonFarm.getConfirmPartState(dungeon)
                                if totalConfirmParts == 0 then
                                    DungeonFarm.phase = "waiting_map"
                                    DungeonFarm.updateStatus(
                                        "Dungeon Farm: CHO MAP",
                                        "Chua thay ConfirmPart nao; dang quet lai map..."
                                    )
                                elseif pendingConfirmParts > 0 then
                                    DungeonFarm.phase = "waiting"
                                    DungeonFarm.updateStatus(
                                        "Dungeon Farm: CHO CONFIRMPART",
                                        string.format(
                                            "Da thay %d cot | Con %d room chua clear | Active %d",
                                            totalConfirmParts,
                                            pendingConfirmParts,
                                            enabledConfirmParts
                                        )
                                    )
                                else
                                    DungeonFarm.phase = "waiting_map"
                                    DungeonFarm.updateStatus(
                                        "Dungeon Farm: CHO ROOM",
                                        string.format(
                                            "Da xu ly %d ConfirmPart | Dang cho room tiep theo hoac DungeonFinish...",
                                            totalConfirmParts
                                        )
                                    )
                                end
                                task.wait(0.5)
                            else
                                DungeonFarm.targetRoom = room
                                DungeonFarm.targetPart = part
                                DungeonFarm.room = room.Name
                                if not DungeonFarm.ensureRoomTeam(room) then
                                    DungeonFarm.fail("Khong doi duoc team cho room " .. tostring(room.Name) .. ".", token)
                                    return
                                end
                                local attempts = (DungeonFarm.attempts[key] or 0) + 1
                                DungeonFarm.attempts[key] = attempts
                                if attempts > 3 then
                                    DungeonFarm.fail("Khong active duoc room " .. tostring(room.Name) .. ".", token)
                                    return
                                end

                                DungeonFarm.phase = "flying"
                                DungeonFarm.updateStatus("Dungeon Farm: FLY", "Dang bay noclip toi room " .. tostring(room.Name) .. "...")
                                if not DungeonFarm.flyTo(part, token) then
                                    DungeonFarm.fail("Fly toi room " .. tostring(room.Name) .. " that bai.", token)
                                    return
                                end

                                DungeonFarm.phase = "activating"
                                DungeonFarm.activationAt = os.clock()
                                local transitioned = false
                                local promptGoneAt = nil
                                local deadline = os.clock() + 35
                                local lastActivation = 0
                                local activationAttempts = 0
                                while alive() and dungeonActive and DungeonFarm.enabled and token == DungeonFarm.token do
                                    local liveEnemies, uncertainEnemies = DungeonFarm.getLiveEnemies(dungeon, room)
                                    if #liveEnemies > 0 or uncertainEnemies then
                                        transitioned = true
                                        break
                                    end
                                    if not prompt.Parent or not prompt.Enabled then
                                        promptGoneAt = promptGoneAt or os.clock()
                                        if os.clock() - promptGoneAt >= 2 then
                                            transitioned = true
                                            break
                                        end
                                    else
                                        promptGoneAt = nil
                                    end
                                    if prompt.Parent and prompt.Enabled
                                        and os.clock() - lastActivation >= 0.75 then
                                        activationAttempts = activationAttempts + 1
                                        if activationAttempts > 6 then
                                            break
                                        end
                                        if activationAttempts > 1 then
                                            DungeonFarm.updateStatus(
                                                "Dungeon Farm: ACTIVE LAI",
                                                string.format(
                                                    "Room %s | Cot van con bat, thu lai lan %d/6",
                                                    tostring(room.Name),
                                                    activationAttempts
                                                )
                                            )
                                            if not DungeonFarm.flyTo(part, token) then
                                                DungeonFarm.fail(
                                                    "Fly lai toi cot " .. tostring(room.Name) .. " that bai.",
                                                    token
                                                )
                                                return
                                            end
                                        end
                                        local activated, activationError = pcall(function()
                                            if type(fireproximityprompt) ~= "function" then
                                                error("fireproximityprompt khong ton tai trong executor.")
                                            end
                                            fireproximityprompt(prompt)
                                        end)
                                        if not activated then
                                            DungeonFarm.fail("Instant interaction loi: " .. tostring(activationError), token)
                                            return
                                        end
                                        lastActivation = os.clock()
                                    end
                                    if os.clock() >= deadline then
                                        break
                                    end
                                    task.wait(0.25)
                                end

                                if not transitioned then
                                    DungeonFarm.fail("Room " .. tostring(room.Name) .. " khong doi trang thai sau khi active.", token)
                                    return
                                end

                                local liveEnemies, uncertainEnemies = DungeonFarm.getLiveEnemies(dungeon, room)
                                if #liveEnemies > 0 or uncertainEnemies then
                                    DungeonFarm.phase = "combat"
                                    local ok, reason = DungeonFarm.clearEnemies(dungeon, token, room)
                                    if not ok then
                                        DungeonFarm.fail(reason, token)
                                        return
                                    end
                                end

                                local chestOK, chestReason = DungeonFarm.clearChests(dungeon, token, room)
                                if not chestOK then
                                    DungeonFarm.fail(chestReason, token)
                                    return
                                end
                                if not DungeonFarm.canMarkRoomClearedSequential(dungeon, room) then
                                    DungeonFarm.phase = "waiting_room"
                                    DungeonFarm.lastMessage = "Room " .. tostring(room.Name)
                                        .. " dang cho chest/du lieu on dinh."
                                    DungeonFarm.updateStatus("Dungeon Farm: CHO ROOM", DungeonFarm.lastMessage)
                                    task.wait(0.35)
                                    continue
                                end

                                DungeonFarm.markRoomCleared(room, key)
                                DungeonFarm.roomEmptySince[key] = nil
                                DungeonFarm.attempts[key] = nil
                                DungeonFarm.lastMessage = "Da clear room " .. tostring(room.Name) .. "."
                                DungeonFarm.phase = "waiting"
                                DungeonFarm.updateStatus("Dungeon Farm: DA CLEAR", DungeonFarm.lastMessage)
                                task.wait(0.5)
                            end
                        end
                    end
                end
            end
        end
        if token == DungeonFarm.token then
            DungeonFarm.running = false
        end
    end)
end

local startAutoDungeon

local function restoreDungeonSession(reason)
    local session = dungeonSession
    if not session or session.restoring then
        return
    end
    session.restoring = true
    local dungeonActive = false
    -- Khong tat Auto Mo o day: xong 1 luot thi tu mo luot tiep (fail() va
    -- startAutoDungeon() tu tat toggle khi het summon/artifact).
    DungeonFarm.token = DungeonFarm.token + 1
    DungeonFarm.running = false
    DungeonFarm.entered = false
    DungeonFarm.sessionDungeon = nil
    DungeonFarm.phase = "idle"
    DungeonFarm.room = nil
    DungeonFarm.targetRoom = nil
    DungeonFarm.targetPart = nil
    DungeonFarm.activationAt = 0
    DungeonFarm.lastEnemyCount = 0
    DungeonFarm.completed = {}
    DungeonFarm.attempts = {}
    DungeonFarm.goldRooms = {}
    DungeonFarm.goldDoorsOpened = {}
    DungeonFarm.goldRoomsOpened = {}
    DungeonFarm.completedChests = {}
    DungeonFarm.enemySeenAt = {}
    DungeonFarm.lastCombatTarget = nil
    DungeonFarm.lastCombatSendAt = 0
    DungeonFarm.combatSendCount = 0
    DungeonFarm.lastCombatError = ""
    DungeonFarm.lastLiveScanAt = 0
    DungeonFarm.lastLiveScanCount = 0
    DungeonFarm.lastLiveScanUncertain = false
    DungeonFarm.deadEnemies = {}
    DungeonFarm.route = {}
    DungeonFarm.routeKey = ""
    DungeonFarm.routeTarget = nil
    DungeonFarm.goldTargetKey = nil
    DungeonFarm.goldTargetRoom = nil
    DungeonFarm.greenTargetKey = nil
    DungeonFarm.goldRoomKeys = {}
    DungeonFarm.goldContentActive = false
    DungeonFarm.goldRoomEmptySince = {}
    DungeonFarm.roomEmptySince = {}
    DungeonFarm.lastRouteWalkAt = 0
    DungeonFarm.lastRouteWalkTargetKey = nil
    DungeonFarm.teamApplied = false
    DungeonFarm.teamApplying = false
    DungeonFarm.teamIndexApplied = nil
    DungeonFarm.teamAppliedAt = 0
    DungeonFarm.lastMessage = reason or "Da khoi phuc cau hinh"
    DungeonFarm.updateStatus("Dungeon Farm: SAN SANG", DungeonFarm.lastMessage)
    dungeonWaiting = false
    dungeonWaitToken = dungeonWaitToken + 1
    saveConfig(true)

    task.spawn(function()
        protectedCall("Restore dungeon session", function()
            for _ = 1, 80 do
                if tostring(getPlayerValue("World", "")) ~= "Dungeon" then
                    break
                end
                task.wait(0.25)
            end

            if session.location and session.location.world then
                travelToWorld(session.location.world)
            end

            -- The native team handler restores pets and its saved cosmetics as
            -- one transaction; direct remotes can clear the pet store mid-sync.
            local restoredTeam = false
            if session.teamIndex then
                restoredTeam = DungeonFarm.ensureTeamApplied(session.teamIndex, "restore") == true
            end
            if not restoredTeam then
                applyEquippedPets(session.equippedPets)
                applyDungeonTitle(session.title)
                applyDungeonAvatar(session.avatar)
                applyDungeonAura(session.aura)
                applyDungeonArtifact(session.artifact, "CurrentArtefact")
                applyDungeonArtifact(session.secondArtifact, "CurrentSecondArtefact")
            end
            local dungeonSettings = type(session.dungeonSettings) == "table" and session.dungeonSettings or {}
            if dungeonSettings.Theme then
                protectedCall("Restore dungeon theme", function()
                    SetDungeonSetting:FireServer("Theme", dungeonSettings.Theme)
                end)
            end
            if dungeonSettings.Size then
                protectedCall("Restore dungeon size", function()
                    SetDungeonSetting:FireServer("Size", dungeonSettings.Size)
                end)
            end

            if session.location and session.location.cframe then
                local character = LocalPlayer.Character
                if character then
                    pcall(function()
                        character:PivotTo(session.location.cframe)
                    end)
                end
            end

            dungeonSession = nil
            notifyStatus("Auto Dungeon", reason or "Da khoi phuc cau hinh")
            updateMachineStatus()
            -- Auto Mo van bat thi tu mo luot tiep (cho server on dinh chut;
            -- startAutoDungeon tu cho cooldown/slot trong).
            if alive() and Feature.autoDungeonEnabled then
                task.wait(3)
                if alive() and Feature.autoDungeonEnabled then
                    protectedCall("Reopen dungeon", startAutoDungeon)
                end
            end
        end)
    end)
end

DungeonFarm.restore = restoreDungeonSession

function DungeonFarm.leaveAfterGold(token)
    if token and token ~= DungeonFarm.token then
        return false, "Dungeon farm token da thay doi."
    end
    DungeonFarm.phase = "leaving"
    DungeonFarm.updateStatus("Dungeon Farm: OUT", "Da farm xong dungeon; dang roi Dungeon...")

    local ok, reason = protectedCall("Leave dungeon after gold room", function()
        local travelEvent = Bindable:FindFirstChild("AttemptTravel")
        if not travelEvent then
            error("Bindable.AttemptTravel khong ton tai")
        end
        travelEvent:Fire("Tower")
    end)
    if not ok then
        return false, tostring(reason)
    end

    local deadline = os.clock() + 20
    while alive() and token == DungeonFarm.token and os.clock() < deadline do
        if tostring(getPlayerValue("World", "")) ~= "Dungeon" then
            if dungeonSession and not dungeonSession.restoring then
                task.delay(0.75, function()
                    if alive() and dungeonSession and not dungeonSession.restoring then
                        restoreDungeonSession("Da farm xong dungeon")
                    end
                end)
            end
            DungeonFarm.running = false
            return true
        end
        task.wait(0.25)
    end
    return false, "Khong roi duoc Dungeon sau khi farm xong."
end

-- Auto Gate (GatesMode): summon gate rank da chon, equip team, join, farm.
-- Khong them local top-level o day (main chunk da sat gioi han registers):
-- state nam trong Feature.gateFarm, ham dang Feature.gate*.
Feature.gateFarm = {
    enabled = false,
    openEnabled = false,
    farmEnabled = false,
    running = false,
    token = 0,
    gateId = "ERankGate",
    amount = 1,
    teamIndex = 1,
    maxRuns = 5,
    runsDone = 0,
    phase = "idle",
    lastMessage = "Chua chay.",
    wasInside = false,
    homeWorld = nil,
    emptySince = nil,
    insideSince = nil,
}

function Feature.gateRanks()
    return {
        {id = "ERankGate", name = "E Rank"},
        {id = "DRankGate", name = "D Rank"},
        {id = "CRankGate", name = "C Rank"},
        {id = "BRankGate", name = "B Rank"},
        {id = "ARankGate", name = "A Rank"},
        {id = "SRankGate", name = "S Rank"},
        {id = "ZRankGate", name = "Z Rank"},
        {id = "XRankGate", name = "X Rank"},
        {id = "AnniversaryRankGate", name = "Anniversary"},
    }
end

function Feature.gateOwned()
    local items = getStoreTable("Items", true)
    local result = {}
    for _, rank in ipairs(Feature.gateRanks()) do
        result[rank.id] = tonumber(items[rank.id]) or 0
    end
    return result
end

function Feature.gateGetDifficulty(gateId)
    local farm = Feature.gateFarm
    if not farm.itemStats then
        local ok, stats = pcall(function()
            return require(ReplicatedStorage.ModuleScripts.ItemStats)
        end)
        if not ok or type(stats) ~= "table" then
            return nil
        end
        farm.itemStats = stats
    end
    local entry = farm.itemStats[gateId]
    return type(entry) == "table" and entry.GateDifficulty or nil
end

function Feature.gatePickGate()
    -- Chon gate de mo: uu tien gate dang chon (target); het thi rot xuong
    -- rank thap hon con hang. Moi luot mo danh gia lai tu dau nen dang farm
    -- gate thap ma rot ra gate cao la tu quay len ngay lap tuc.
    -- Tra ve gateId, have; het sach tu target tro xuong thi tra ve nil.
    local farm = Feature.gateFarm
    local ranks = Feature.gateRanks()
    local owned = Feature.gateOwned()
    local targetIndex = 1
    for index, rank in ipairs(ranks) do
        if rank.id == farm.gateId then
            targetIndex = index
            break
        end
    end
    for index = targetIndex, 1, -1 do
        local id = ranks[index].id
        if (owned[id] or 0) >= 1 then
            return id, owned[id]
        end
    end
    return nil, 0
end

function Feature.gateReadOpen()
    local gate = workspace:FindFirstChild("Worlds")
        and workspace.Worlds:FindFirstChild("TimeChamber")
        and workspace.Worlds.TimeChamber:FindFirstChild("Gate")
    if not gate then
        return false, nil
    end
    local open = false
    pcall(function()
        open = CollectionService:HasTag(gate, "GateOpen") == true
    end)
    if not open then
        return false, nil
    end
    local runId = gate:GetAttribute("run_id")
    if runId == nil then
        return false, nil
    end
    return true, runId
end

function Feature.gateUpdateStatus(title, desc)
    local farm = Feature.gateFarm
    farm.lastMessage = tostring(desc or "")
    if farm.statusParagraph then
        setParagraph(farm.statusParagraph, title, desc)
    end
end

function Feature.gateSyncEnabled()
    -- enabled la master switch: loop chay khi it nhat 1 trong 2 bat.
    Feature.gateFarm.enabled = Feature.gateFarm.openEnabled or Feature.gateFarm.farmEnabled
end

function Feature.gateToggleOff(reason)
    -- 1 toggle tat: neu toggle kia con bat thi giu loop, chi bao status;
    -- ca 2 tat moi dung loop (va ve nha neu dang trong gate).
    local farm = Feature.gateFarm
    if farm.enabled then
        Feature.gateUpdateStatus("Auto Gate", tostring(reason))
        return
    end
    local inGate = tostring(getPlayerValue("World", "")) == "GatesMode"
    Feature.gateStop(reason)
    if inGate then
        Feature.gateGoHome(reason)
    end
end

function Feature.gateFail(reason)
    local farm = Feature.gateFarm
    farm.token = farm.token + 1
    farm.running = false
    farm.phase = "error"
    Feature.gateUpdateStatus("Auto Gate: LOI", tostring(reason))
    notifyStatus("Auto Gate", "Loi: " .. tostring(reason))
    farm.openEnabled = false
    farm.farmEnabled = false
    Feature.gateSyncEnabled()
    if farm.openToggle then
        farm.toggleUpdating = true
        pcall(function()
            farm.openToggle:Set(false)
        end)
        farm.toggleUpdating = false
    end
    if farm.farmToggle then
        farm.toggleUpdating = true
        pcall(function()
            farm.farmToggle:Set(false)
        end)
        farm.toggleUpdating = false
    end
    saveConfig(true)
end

function Feature.gateEnsureTeam(index)
    index = math.max(1, math.floor(tonumber(index) or 1))
    local teams = getStoreTable("PetTeams", true)
    local team = teams[index]
    if type(team) ~= "table" then
        return false
    end
    local equipTeam, reason = DungeonFarm.findNativeEquipTeam()
    if not equipTeam then
        Feature.gateUpdateStatus("Auto Gate: TEAM", tostring(reason))
        return false
    end
    local deadline = os.clock() + 12
    while alive() and os.clock() < deadline do
        local ok = true
        local amount = DungeonFarm.getEquipSlotCount()
        if amount > 0 and DungeonFarm.getEquippedPetCount() > 0 then
            local equipped = getStoreTable("EquippedPets", true)
            for slot = 1, amount do
                local actual = equipped[tostring(slot)] or equipped[slot]
                if DungeonFarm.normalizedUID(actual)
                    ~= DungeonFarm.normalizedUID(DungeonFarm.getTeamSlotUID(team, slot)) then
                    ok = false
                    break
                end
            end
            if ok then
                return true
            end
        else
            ok = false
        end
        if not ok then
            pcall(function()
                equipTeam(index)
            end)
        end
        task.wait(0.5)
    end
    return false
end

function Feature.gateIsLiveEnemy(model)
    -- Dieu kien song cua quai gate theo dung chuan game:
    -- TargetHandler.find_possible quet tag Attackable (tru Untouchable),
    -- health <= 0 (neu doc duoc) coi nhu chet.
    local valid = false
    pcall(function()
        valid = model:IsA("Model") and model.Parent ~= nil
    end)
    if not valid then
        return false
    end
    local dead, aliveFlag = false, true
    pcall(function()
        dead = model:GetAttribute("Dead") == true or model:GetAttribute("IsDead") == true
        aliveFlag = model:GetAttribute("Alive") ~= false
    end)
    if dead or not aliveFlag then
        return false
    end
    local attackable, untouchable = false, false
    pcall(function()
        attackable = CollectionService:HasTag(model, "Attackable")
        untouchable = CollectionService:HasTag(model, "Untouchable")
    end)
    if untouchable or not attackable then
        return false
    end
    local health = Feature.getHealth(model)
    if health ~= nil and health <= 0 then
        return false
    end
    return true
end

function Feature.gateInScope(model)
    -- Game quet tag Attackable tren TOAN game (moi world deu co quai ton tai),
    -- nen phai gioi han trong GatesMode keo gui pet sang map world khac.
    local worlds = workspace:FindFirstChild("Worlds")
    local gateWorld = worlds and worlds:FindFirstChild("GatesMode")
    if gateWorld then
        local inside = false
        pcall(function()
            inside = model:IsDescendantOf(gateWorld)
        end)
        if inside then
            return true
        end
    end
    local parent = model.Parent
    if parent == workspace:FindFirstChild("Enemies")
        or parent == workspace:FindFirstChild("NewEnemies") then
        return true
    end
    return false
end

function Feature.gatePrepareEnemy(enemy)
    -- Giong DungeonFarm prepareEnemy: LocalPetHandler chi nhan pet khi enemy
    -- co PrimaryPart + folder Attackers (find_nearest_slot doc
    -- enemy.Attackers; thieu la Fire loi vo ich). Tu gan PrimaryPart neu tim
    -- thay, tra ve nil khi quai chua spawn xong de chon con READY khac.
    local valid = false
    pcall(function()
        valid = enemy:IsA("Model") and enemy.Parent ~= nil
    end)
    if not valid then
        return nil
    end
    local primary = enemy.PrimaryPart
        or enemy:FindFirstChild("HumanoidRootPart", true)
        or enemy:FindFirstChild("RootPart", true)
    if primary and primary:IsA("BasePart") and not enemy.PrimaryPart then
        pcall(function()
            enemy.PrimaryPart = primary
        end)
    end
    if enemy.PrimaryPart == nil or enemy:FindFirstChild("Attackers") == nil then
        return nil
    end
    return enemy.PrimaryPart
end

function Feature.gateGetEnemies()
    if tostring(getPlayerValue("World", "")) ~= "GatesMode" then
        return {}
    end
    local result = {}
    local seen = {}
    -- Quet chinh theo tag Attackable nhu game (TargetHandler.find_possible).
    local ok, tagged = pcall(function()
        return CollectionService:GetTagged("Attackable")
    end)
    if ok and type(tagged) == "table" then
        for _, model in ipairs(tagged) do
            local valid = false
            pcall(function()
                valid = model:IsA("Model") and not seen[model]
            end)
            if valid then
                seen[model] = true
                if Feature.gateInScope(model) and Feature.gateIsLiveEnemy(model) then
                    table.insert(result, model)
                end
            end
        end
    end
    -- Fallback: quai vua spawn chua kip co tag Attackable thi van thay trong
    -- folder Enemies/NewEnemies neu co root + health>0 (da loc Untouchable).
    for _, target in ipairs(Feature.getTargets()) do
        local model = target.model
        local valid = false
        pcall(function()
            valid = model:IsA("Model") and model.Parent ~= nil and not seen[model]
        end)
        if valid then
            seen[model] = true
            if Feature.gateInScope(model) then
                table.insert(result, model)
            end
        end
    end
    return result
end

function Feature.gatePickTarget()
    -- Chon muc tieu trong gate theo che do farm hien tai, nhung CHI chon
    -- quai READY (co PrimaryPart + Attackers) nhu dungeon de SendPet co tac
    -- dung thay vi Fire vao model dang spawn.
    local character = LocalPlayer.Character
    local playerRoot = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
    if not playerRoot then
        return nil
    end
    local selected
    for _, model in ipairs(Feature.gateGetEnemies()) do
        local primary = Feature.gatePrepareEnemy(model)
        if primary then
            local root = Feature.getRoot(model) or primary
            local pos = nil
            pcall(function()
                pos = root.Position
            end)
            if pos then
                local candidate = {
                    model = model,
                    root = root,
                    distance = (pos - playerRoot.Position).Magnitude,
                    health = Feature.getHealth(model)
                }
                if not selected then
                    selected = candidate
                elseif Feature.autoFarmMode == Feature.MODE_LOWEST_HEALTH then
                    local ch = candidate.health == nil and math.huge or candidate.health
                    local sh = selected.health == nil and math.huge or selected.health
                    if ch < sh or (ch == sh and candidate.distance < selected.distance) then
                        selected = candidate
                    end
                elseif Feature.autoFarmMode == Feature.MODE_HIGHEST_HEALTH then
                    local ch = candidate.health == nil and -math.huge or candidate.health
                    local sh = selected.health == nil and -math.huge or selected.health
                    if ch > sh or (ch == sh and candidate.distance < selected.distance) then
                        selected = candidate
                    end
                elseif candidate.distance < selected.distance then
                    selected = candidate
                end
            end
        end
    end
    return selected
end

function Feature.gateSendPets()
    if tostring(getPlayerValue("World", "")) ~= "GatesMode" then
        return
    end
    local selected = Feature.gatePickTarget()
    if not (selected and selected.model and selected.model.Parent) then
        return
    end
    -- Bay nguoi thang vao quai (nhu farm dungeon) de pet luon trong tam danh,
    -- ke ca pet chua nhan Teleport.
    if (selected.distance or math.huge) > 8 then
        local character = LocalPlayer.Character
        local root = character
            and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
        if root and selected.root then
            pcall(function()
                character:PivotTo(
                    CFrame.new(selected.root.Position + Vector3.new(0, 2, 0))
                        * (root.CFrame - root.Position)
                )
            end)
        end
    end
    local sendEvent = Bindable:FindFirstChild("SendPet")
    if sendEvent then
        pcall(function()
            sendEvent:Fire(selected.model, true, true)
        end)
    end
end

function Feature.gateGoHome(reason)
    local farm = Feature.gateFarm
    local target = farm.homeWorld or "TimeChamber"
    Feature.gateUpdateStatus("Auto Gate: VE", tostring(reason or "Xong lượt gate."))
    travelToWorld(target)
end

function Feature.gateRefreshRefs()
    -- Teleport sang server moi (gate/dungeon) lam instance cu chet: chunk van
    -- chay nhung LocalPlayer/Remote/Bindable/Store tro toi DataModel cu.
    -- Lam moi chung + hook lai TP Pet de farm song trong server moi.
    pcall(function()
        local freshPlayers = game:GetService("Players")
        local freshPlayer = freshPlayers.LocalPlayer
        if freshPlayer and freshPlayer ~= LocalPlayer then
            LocalPlayer = freshPlayer
        end
    end)
    pcall(function()
        local freshRS = game:GetService("ReplicatedStorage")
        if freshRS and freshRS ~= ReplicatedStorage then
            ReplicatedStorage = freshRS
            local freshRemote = freshRS:FindFirstChild("Remote")
            if freshRemote then
                Remote = freshRemote
            end
            local freshBindable = freshRS:FindFirstChild("Bindable")
            if freshBindable then
                Bindable = freshBindable
            end
            local freshStoreMod = freshRS:FindFirstChild("ModuleScripts")
            if freshStoreMod then
                local freshLDS = freshStoreMod:FindFirstChild("LocalDairebStore")
                if freshLDS then
                    local okMod, mod = pcall(require, freshLDS)
                    if okMod and type(mod) == "table" and type(mod.GetStoreProxy) == "function" then
                        LocalDairebStore = mod
                        local okStore, proxy = pcall(function()
                            return mod.GetStoreProxy("GameData")
                        end)
                        if okStore and proxy then
                            Store = proxy
                        end
                    end
                end
            end
        end
    end)
    pcall(function()
        local freshCS = game:GetService("CollectionService")
        if freshCS and freshCS ~= CollectionService then
            CollectionService = freshCS
        end
    end)
    if Feature.tpPetEnabled then
        Feature.applyTpPet()
    end
end

function Feature.gateDismissVictory()
    -- Tu dong tat man hinh VICTORY/Congratulations (MainGui.GatesModeLose)
    -- sau khi xong gate de no khong che man hinh va khong chan luot tiep.
    -- Nut Confirm cua game cung chi lam 2 viec: Visible=false + bo chon
    -- gamepad, nen set thang Visible=false la du (firesignal khong co tac
    -- dung trong executor nay).
    local playerGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    local mainGui = playerGui and playerGui:FindFirstChild("MainGui")
    local endScreen = mainGui and mainGui:FindFirstChild("GatesModeLose")
    if not endScreen then
        return
    end
    local visible = false
    pcall(function()
        visible = endScreen.Visible == true
    end)
    if visible then
        pcall(function()
            endScreen.Visible = false
        end)
        pcall(function()
            local confirm = endScreen:FindFirstChild("Confirm")
            if confirm then
                confirm.Visible = false
            end
        end)
    end
end

function Feature.gateLoop(token)
    local farm = Feature.gateFarm
    local sendAt = 0
    while alive() and token == farm.token and farm.enabled do
        Feature.gateDismissVictory()
        if os.clock() - (farm.lastRefresh or 0) >= 5 then
            farm.lastRefresh = os.clock()
            Feature.gateRefreshRefs()
        end
        local world = tostring(getPlayerValue("World", ""))
        if world ~= "GatesMode" then
            if farm.wasInside then
                farm.wasInside = false
                farm.emptySince = nil
                farm.insideSince = nil
                farm.seenAny = false
                Feature.gateUpdateStatus("Auto Gate: XONG", "Xong 1 luot gate; mo gate tiep...")
                task.wait(1)
            end

            if not farm.openEnabled then
                if farm.phase ~= "open_off" then
                    farm.phase = "open_off"
                    Feature.gateUpdateStatus("Auto Gate: MO TAT", "Auto mo gate dang tat; tu mo tay hoac bat toggle.")
                end
                task.wait(0.5)
            else
            local open, runId = Feature.gateReadOpen()
            if open then
                farm.phase = "joining"
                Feature.gateUpdateStatus("Auto Gate: VAO", "Gate da mo; dang equip team va vao...")
                if tostring(getPlayerValue("World", "")) ~= "TimeChamber" then
                    Feature.gateUpdateStatus("Auto Gate: VE", "Dang ve TimeChamber de vao gate...")
                    travelToWorld("TimeChamber")
                    task.wait(1)
                else
                    if not Feature.gateEnsureTeam(farm.teamIndex) then
                        Feature.gateUpdateStatus("Auto Gate: TEAM", "Dang thu lai equip team...")
                        task.wait(1)
                    else
                    local joined = false
                    for _ = 1, 60 do
                        if not alive() or token ~= farm.token or not farm.enabled then
                            return
                        end
                        if tostring(getPlayerValue("World", "")) == "GatesMode" then
                            joined = true
                            break
                        end
                        local ok = pcall(function()
                            Remote.JoinGatesMode:FireServer(runId)
                            Bindable.AttemptTravel:Fire("GatesMode", true, runId)
                        end)
                        if not ok then
                            break
                        end
                        task.wait(0.5)
                    end
                    if not joined then
                        Feature.gateUpdateStatus("Auto Gate: CHO", "Khong vao duoc gate; thu lai...")
                        task.wait(2)
                    end
                end
                end
            else
                local currentId, have = Feature.gatePickGate()
                if not currentId then
                    Feature.gateFail("Het gate " .. tostring(farm.gateId) .. " tro xuong trong tui.")
                    return
                end
                local difficulty = Feature.gateGetDifficulty(currentId)
                if not difficulty then
                    Feature.gateFail("Khong doc duoc do kho gate.")
                    return
                end
                farm.phase = "summoning"
                local note = ""
                if currentId ~= farm.gateId then
                    note = string.format(" (tam farm %s vi het %s)", tostring(currentId), tostring(farm.gateId))
                end
                Feature.gateUpdateStatus(
                    "Auto Gate: MO",
                    string.format("Dang mo MAX gate %s (con %d)...%s", tostring(currentId), have, note)
                )
                pcall(function()
                    Remote.SummonGate:FireServer(difficulty, have)
                end)
                local deadline = os.clock() + 30
                while alive() and token == farm.token and farm.enabled and os.clock() < deadline do
                    if tostring(getPlayerValue("World", "")) == "GatesMode" then
                        break
                    end
                    if Feature.gateReadOpen() then
                        break
                    end
                    task.wait(0.5)
                end
            end
            end
            task.wait(0.5)
        elseif not farm.farmEnabled then
            if farm.phase ~= "farm_off" then
                farm.phase = "farm_off"
                Feature.gateUpdateStatus("Auto Gate: FARM TAT", "Auto farm gate dang tat; farm tay hoac bat toggle.")
            end
            task.wait(0.5)
        else
            if not farm.wasInside then
                farm.wasInside = true
                farm.insideSince = os.clock()
                farm.emptySince = nil
                farm.seenAny = false
                farm.phase = "farming"
                Feature.gateUpdateStatus("Auto Gate: FARM", "Dang farm trong gate...")
                -- Equip lai team de pet respawn va nhan Teleport (TP Pet chi co
                -- tac dung voi pet duoc goi ra sau khi bat).
                local eq = DungeonFarm.findNativeEquipTeam()
                if eq then
                    pcall(function()
                        eq(farm.teamIndex)
                    end)
                    task.wait(2)
                end
            end
            if not farm.seenAny then
                -- Gate dang dem gio cho (chua spawn quai): tu skip nhu nut StartNow.
                farm.skipAt = farm.skipAt or 0
                if os.clock() - farm.skipAt >= 5 then
                    farm.skipAt = os.clock()
                    pcall(function()
                        Remote.SkipGateWait:FireServer()
                    end)
                end
            end
            if os.clock() - (sendAt or 0) >= 1 then
                sendAt = os.clock()
                Feature.gateSendPets()
            end
            -- Chi roi khi da thay quai ma sach bong 30s (tranh out oan giua wave).
            if #Feature.gateGetEnemies() > 0 then
                farm.seenAny = true
                farm.emptySince = nil
            elseif farm.seenAny then
                farm.emptySince = farm.emptySince or os.clock()
                if os.clock() - farm.emptySince >= 30 then
                    Feature.gateUpdateStatus("Auto Gate: HET QUAI", "Khong con quai; roi gate...")
                    Feature.gateGoHome("Gate sach quai.")
                    task.wait(2)
                end
            end
            if farm.insideSince and os.clock() - farm.insideSince >= 600 then
                Feature.gateUpdateStatus("Auto Gate: HET GIO", "Qua 10 phut trong gate; roi gate...")
                Feature.gateGoHome("Het gio trong gate.")
                task.wait(2)
            end
            task.wait(0.25)
        end
    end
    if token == farm.token then
        farm.running = false
    end
end

function Feature.gateStart()
    local farm = Feature.gateFarm
    if farm.running then
        return
    end
    farm.token = farm.token + 1
    local token = farm.token
    farm.running = true
    farm.phase = "starting"
    farm.wasInside = tostring(getPlayerValue("World", "")) == "GatesMode"
    farm.emptySince = nil
    farm.insideSince = farm.wasInside and os.clock() or nil
    if farm.wasInside then
        farm.homeWorld = "TimeChamber"
    else
        local location = captureLocation()
        farm.homeWorld = location and location.world or "TimeChamber"
    end
    Feature.gateUpdateStatus("Auto Gate: BAT DAU", "Bat dau auto gate...")
    task.spawn(function()
        protectedCall("Auto gate loop", function()
            Feature.gateLoop(token)
        end)
    end)
end

function Feature.gateStop(reason)
    local farm = Feature.gateFarm
    farm.token = farm.token + 1
    farm.running = false
    farm.phase = "idle"
    Feature.gateUpdateStatus("Auto Gate: DUNG", tostring(reason or "Da dung."))
end

startAutoDungeon = function()
    dungeonSelection.mapId = normalizeDungeonMapId(dungeonSelection.mapId) or "DBZ"
    if tostring(getPlayerValue("World", "")) == "Dungeon" then
        dungeonActive = true
        local entryTeamReady = DungeonFarm.ensureEntryTeam("after-entry")
        DungeonFarm.entered = true
        if DungeonFarm.enabled then
            if not entryTeamReady then
                DungeonFarm.updateStatus(
                    "Dungeon Farm: TEAM LAI",
                    "Dang o Dungeon; farm se thu lai equip team truoc khi active room."
                )
            end
            DungeonFarm.start()
        else
            DungeonFarm.updateStatus("Dungeon Farm: TAT", "Farm dungeon dang tat.")
        end
        return
    end
    if dungeonActive or dungeonWaiting then
        return
    end
    local itemData = getStoreTable("Items", true)
    if (tonumber(itemData.DungeonSummon) or 0) < 1 then
        Feature.autoDungeonEnabled = false
        if dungeonToggle then
            dungeonToggleUpdating = true
            pcall(function()
                dungeonToggle:Set(false)
            end)
            dungeonToggleUpdating = false
        end
        saveConfig(true)
        notifyStatus("Auto Dungeon", "Khong con DungeonSummon.")
        return
    end

    local ownedArtifacts = getStoreTable("Artefacts", true)
    local passageLevel = tonumber(ownedArtifacts.Dungeon or 0) or 0
    if passageLevel < 1 then
        Feature.autoDungeonEnabled = false
        if dungeonToggle then
            dungeonToggleUpdating = true
            pcall(function()
                dungeonToggle:Set(false)
            end)
            dungeonToggleUpdating = false
        end
        saveConfig(true)
        notifyStatus("Auto Dungeon", "Can Artifact of Passage de mo dungeon.")
        return
    end

    local occupied = DungeonFarm.isDungeonOccupied()
    local remaining = getDungeonCooldownInfo()
    if occupied or remaining > 0 then
        dungeonWaiting = true
        dungeonWaitToken = dungeonWaitToken + 1
        local token = dungeonWaitToken
        if occupied then
            notifyStatus("Auto Dungeon", "Server dang co dungeon cua nguoi khac; se cho den khi hoan tat.")
        else
            notifyStatus("Auto Dungeon", utf8Text("Dang cho cooldown Artifact of Passage: ", 272, 97, 110, 103, 32, 99, 104, 7901, 32, 99, 111, 111, 108, 100, 111, 119, 110, 32, 65, 114, 116, 105, 102, 97, 99, 116, 32, 111, 102, 32, 80, 97, 115, 115, 97, 103, 101, 58, 32) .. formatDuration(remaining))
        end
        DungeonFarm.phase = occupied and "waiting_server" or "waiting_cooldown"
        task.spawn(function()
            while alive() and dungeonWaiting and token == dungeonWaitToken do
                local left = getDungeonCooldownInfo()
                local serverBusy = DungeonFarm.isDungeonOccupied()
                updateDungeonCooldownStatus()
                if left <= 0 and not serverBusy then
                    dungeonWaiting = false
                    protectedCall("Start dungeon after slot is ready", startAutoDungeon)
                    return
                end
                if serverBusy then
                    DungeonFarm.phase = "waiting_server"
                    DungeonFarm.updateStatus(
                        "Dungeon Farm: CHO SLOT",
                        "Server dang co dungeon khac; se tu dong thu lai sau khi dungeon ket thuc."
                    )
                elseif left > 0 then
                    DungeonFarm.phase = "waiting_cooldown"
                    DungeonFarm.updateStatus(
                        "Dungeon Farm: CHO COOLDOWN",
                        "Artifact of Passage con " .. formatDuration(left) .. "."
                    )
                end
                task.wait(3)
            end
        end)
        return
    end

    local previousEquippedPets = copyEquippedPets()
    local previousTeamIndex = findTeamIndexForEquipped(previousEquippedPets)
    local previousTeam = previousTeamIndex and getStoreTable("PetTeams", true)[previousTeamIndex] or nil
    dungeonSession = {
        location = captureLocation(),
        equippedPets = previousEquippedPets,
        teamIndex = previousTeamIndex,
        teamName = type(previousTeam) == "table" and previousTeam.Name or nil,
        title = getStoreValue("CurrentTitle", true, "") or "",
        avatar = getStoreValue("CurrentAvatar", true, "") or getPlayerValue("CurrentAvatar", "") or "",
        aura = getStoreValue("CurrentAura", true, "") or "",
        artifact = getStoreValue("CurrentArtefact", true, "") or "",
        secondArtifact = getStoreValue("CurrentSecondArtefact", true, "") or "",
        dungeonSettings = getStoreTable("DungeonSettings", true)
    }
    dungeonActive = true
    DungeonFarm.token = DungeonFarm.token + 1
    DungeonFarm.running = false
    DungeonFarm.entered = false
    DungeonFarm.sessionDungeon = nil
    DungeonFarm.phase = "starting"
    DungeonFarm.room = nil
    DungeonFarm.targetRoom = nil
    DungeonFarm.targetPart = nil
    DungeonFarm.lastEnemyCount = 0
    DungeonFarm.completed = {}
    DungeonFarm.attempts = {}
    DungeonFarm.goldRooms = {}
    DungeonFarm.goldDoorsOpened = {}
    DungeonFarm.goldRoomsOpened = {}
    DungeonFarm.completedChests = {}
    DungeonFarm.deadEnemies = {}
    DungeonFarm.route = {}
    DungeonFarm.routeKey = ""
    DungeonFarm.routeTarget = nil
    DungeonFarm.goldTargetKey = nil
    DungeonFarm.goldTargetRoom = nil
    DungeonFarm.greenTargetKey = nil
    DungeonFarm.goldRoomKeys = {}
    DungeonFarm.goldContentActive = false
    DungeonFarm.goldRoomEmptySince = {}
    DungeonFarm.roomEmptySince = {}
    DungeonFarm.lastRouteWalkAt = 0
    DungeonFarm.lastRouteWalkTargetKey = nil
    DungeonFarm.teamApplied = false
    DungeonFarm.teamApplying = false
    DungeonFarm.teamIndexApplied = nil
    DungeonFarm.startedAt = os.clock()
    DungeonFarm.lastMessage = "Dang tao dungeon..."
    DungeonFarm.updateStatus("Dungeon Farm: START", DungeonFarm.lastMessage)

    local openingArtifact = "Dungeon"
    local openingSecondArtifact = dungeonSelection.secondArtifact == "Dungeon"
        and ""
        or dungeonSelection.secondArtifact
    applyDungeonArtifact(openingArtifact, "CurrentArtefact")
    applyDungeonArtifact(openingSecondArtifact, "CurrentSecondArtefact")
    task.wait(0.15)
    protectedCall("Set dungeon theme", function()
        SetDungeonSetting:FireServer("Theme", dungeonSelection.mapId)
    end)
    protectedCall("Set dungeon size", function()
        SetDungeonSetting:FireServer("Size", dungeonSelection.size)
    end)
    protectedCall("Summon dungeon", function()
        SummonDungeon:FireServer(dungeonSelection.mode == "Friends", {
            Theme = dungeonSelection.mapId,
            Size = dungeonSelection.size
        })
    end)
    task.spawn(function()
        local lastTravelAttempt = 0
        local activeSeen = false
        local summonStartedAt = os.clock()
        local lastSummonAt = summonStartedAt
        local summonAttempts = 1
        for _ = 1, 480 do
            if not alive() or not dungeonActive then
                return
            end
            local checkOK, arrived = protectedCall("Check dungeon travel", function()
                return tostring(getPlayerValue("World", "")) == "Dungeon"
            end)
            if checkOK and arrived then
                DungeonFarm.updateStatus("Dungeon Farm: TEAM", "Da vao dungeon; dang doi team da cai dat...")
                if not DungeonFarm.ensureEntryTeam("after-entry")
                    or DungeonFarm.getEquippedPetCount() == 0 then
                    DungeonFarm.phase = "team_retry"
                    DungeonFarm.updateStatus(
                        "Dungeon Farm: TEAM LAI",
                        "Da vao dungeon nhung EquippedPets chua san sang; dang thu lai..."
                    )
                    task.wait(0.5)
                    continue
                end
                DungeonFarm.entered = true
                notifyStatus("Auto Dungeon", "Da vao dungeon: " .. dungeonSelection.mapId)
                if DungeonFarm.enabled then
                    DungeonFarm.start()
                else
                    DungeonFarm.updateStatus("Dungeon Farm: TAT", "Farm dungeon dang tat.")
                end
                return
            end

            local openDungeon = DungeonFarm.getOpenDungeon()
            if not openDungeon then
                activeSeen = false
                local serverBusy = DungeonFarm.isDungeonOccupied()
                if serverBusy then
                    DungeonFarm.phase = "waiting_server"
                    DungeonFarm.updateStatus(
                        "Dungeon Farm: CHO SLOT",
                        "Server vua co dungeon khac; se thu lai sau khi slot trong."
                    )
                elseif os.clock() - lastSummonAt >= 8 and summonAttempts < 3 then
                    summonAttempts = summonAttempts + 1
                    lastSummonAt = os.clock()
                    DungeonFarm.phase = "summoning"
                    DungeonFarm.updateStatus(
                        "Dungeon Farm: MO LAI",
                        string.format("Chua thay dungeon; gui lai yeu cau mo lan %d/3...", summonAttempts)
                    )
                    protectedCall("Retry summon dungeon", function()
                        SummonDungeon:FireServer(dungeonSelection.mode == "Friends", {
                            Theme = dungeonSelection.mapId,
                            Size = dungeonSelection.size
                        })
                    end)
                elseif os.clock() - summonStartedAt >= 45 then
                    DungeonFarm.fail("Khong xac nhan duoc dungeon sau 45 giay.", DungeonFarm.token)
                    return
                else
                    DungeonFarm.phase = "waiting_activation"
                    DungeonFarm.updateStatus(
                        "Dungeon Farm: DANG MO",
                        "Dang cho server xac nhan Dungeon.Active..."
                    )
                end
                task.wait(0.25)
                continue
            end

            if not activeSeen then
                DungeonFarm.phase = "entry_team"
                DungeonFarm.updateStatus(
                    "Dungeon Farm: TEAM TRUOC",
                    "Dungeon da mo; dang equip team truoc khi vao..."
                )
                if not DungeonFarm.ensureEntryTeam("before-entry")
                    or DungeonFarm.getEquippedPetCount() == 0 then
                    DungeonFarm.phase = "entry_team_retry"
                    DungeonFarm.updateStatus(
                        "Dungeon Farm: TEAM LAI",
                        "Chua xac nhan du pet; chua teleport vao dungeon."
                    )
                    task.wait(0.5)
                    continue
                end
                activeSeen = true
                lastTravelAttempt = os.clock()
                protectedCall("Travel to active dungeon", function()
                    local travelEvent = Bindable:FindFirstChild("AttemptTravel")
                    if not travelEvent then
                        error("Bindable.AttemptTravel khong ton tai")
                    end
                    travelEvent:Fire("Dungeon")
                end)
            elseif os.clock() - lastTravelAttempt >= 3 then
                lastTravelAttempt = os.clock()
                protectedCall("Retry travel to dungeon", function()
                    local travelEvent = Bindable:FindFirstChild("AttemptTravel")
                    if travelEvent then
                        travelEvent:Fire("Dungeon")
                    end
                end)
            end
            task.wait(0.25)
        end
        if alive() and dungeonActive and not DungeonFarm.entered then
            DungeonFarm.phase = "waiting_entry"
            DungeonFarm.lastMessage = "Dungeon da mo; dang cho ket noi teleport."
            DungeonFarm.updateStatus(
                "Dungeon Farm: CHO VAO",
                "Chua vao dungeon sau thoi gian cho; van giu che do cho de thu lai."
            )
            notifyStatus("Auto Dungeon", "Dungeon da mo; dang cho teleport ket noi lai.")
        end
    end)
end

-- Keep a small runtime probe available while validating dungeon flows after a client rejoin.
globalEnv.__auto_clone_debug = globalEnv.__auto_clone_debug or {}
globalEnv.__auto_clone_debug.setDungeon = function(mapId, mode, size, teamIndex)
    dungeonSelection.mapId = normalizeDungeonMapId(mapId) or dungeonSelection.mapId
    dungeonSelection.mode = mode == "Friends" and "Friends" or "Public"
    dungeonSelection.size = math.clamp(tonumber(size) or dungeonSelection.size, 0, 4)
    dungeonSelection.normalTeamIndex = math.max(
        1,
        math.floor(tonumber(teamIndex) or dungeonSelection.normalTeamIndex or dungeonSelection.teamIndex)
    )
    dungeonSelection.teamIndex = dungeonSelection.normalTeamIndex
    Feature.autoDungeonEnabled = true
    return startAutoDungeon()
end
globalEnv.__auto_clone_debug.checkTeam = function(teamIndex)
    local index = math.max(1, math.floor(tonumber(teamIndex) or dungeonSelection.normalTeamIndex or 1))
    local started = os.clock()
    local callOK, applied = protectedCall("Debug dungeon team check", function()
        return DungeonFarm.ensureTeamApplied(index, "debug")
    end)
    return {
        requested = index,
        callOK = callOK,
        applied = applied == true,
        elapsed = os.clock() - started,
        equippedPetCount = DungeonFarm.getEquippedPetCount(),
        teamApplied = DungeonFarm.teamApplied,
        teamIndexApplied = DungeonFarm.teamIndexApplied
    }
end
globalEnv.__auto_clone_debug.state = function()
    return {
        mapId = dungeonSelection.mapId,
        mode = dungeonSelection.mode,
        size = dungeonSelection.size,
        teamIndex = dungeonSelection.teamIndex,
        normalTeamIndex = dungeonSelection.normalTeamIndex,
        goldTeamIndex = dungeonSelection.goldTeamIndex,
        goldTargetKey = DungeonFarm.goldTargetKey,
        goldTargetRoom = DungeonFarm.goldTargetRoom and DungeonFarm.goldTargetRoom.Name or nil,
        greenTargetKey = DungeonFarm.greenTargetKey,
        goldRoomCount = #DungeonFarm.goldRooms,
        goldCompletedCount = (function()
            local count = 0
            for _, entry in ipairs(DungeonFarm.goldRooms) do
                if DungeonFarm.completed[entry.key] then
                    count = count + 1
                end
            end
            return count
        end)(),
        goldContentActive = DungeonFarm.goldContentActive,
        world = tostring(getPlayerValue("World", "")),
        dungeonActive = dungeonActive,
        dungeonWaiting = dungeonWaiting,
        autoDungeonEnabled = Feature.autoDungeonEnabled,
        farmEnabled = DungeonFarm.enabled,
        dungeonEntered = DungeonFarm.entered,
        dungeonRunning = DungeonFarm.running,
        equippedPetCount = DungeonFarm.getEquippedPetCount(),
        teamApplied = DungeonFarm.teamApplied,
        teamApplying = DungeonFarm.teamApplying,
        teamIndexApplied = DungeonFarm.teamIndexApplied,
        teamAppliedAge = DungeonFarm.teamAppliedAt > 0 and (os.clock() - DungeonFarm.teamAppliedAt) or nil,
        combatTarget = DungeonFarm.lastCombatTarget,
        combatSendCount = DungeonFarm.combatSendCount,
        combatSendAge = DungeonFarm.lastCombatSendAt > 0 and (os.clock() - DungeonFarm.lastCombatSendAt) or nil,
        combatError = DungeonFarm.lastCombatError,
        liveEnemyCount = DungeonFarm.lastLiveScanCount,
        liveEnemyUncertain = DungeonFarm.lastLiveScanUncertain,
        phase = DungeonFarm.phase,
        message = DungeonFarm.lastMessage
    }
end

dungeonFinishConnection = globalEnv.__afs_trackConnection(DungeonFinish.OnClientEvent:Connect(function()
    if alive() and dungeonActive then
        task.delay(1, function()
            if alive() and dungeonActive then
                if dungeonSession then
                    protectedCall("Restore completed dungeon", function()
                        restoreDungeonSession("Dungeon da hoan tat")
                    end)
                else
                    DungeonFarm.token = DungeonFarm.token + 1
                    DungeonFarm.running = false
                    DungeonFarm.entered = false
                    local dungeonActive = false
                    DungeonFarm.sessionDungeon = nil
                    DungeonFarm.teamApplied = false
                    DungeonFarm.teamApplying = false
                    DungeonFarm.teamIndexApplied = nil
                    DungeonFarm.route = {}
                    DungeonFarm.routeKey = ""
                    DungeonFarm.routeTarget = nil
                    DungeonFarm.goldTargetKey = nil
                    DungeonFarm.goldTargetRoom = nil
                    DungeonFarm.greenTargetKey = nil
                    DungeonFarm.goldRoomKeys = {}
                    DungeonFarm.phase = "idle"
                    DungeonFarm.updateStatus("Dungeon Farm: SAN SANG", "Dungeon da hoan tat.")
                end
            end
        end)
    end
end))

local worldValue = LocalPlayer:FindFirstChild("World") or LocalPlayer:WaitForChild("World", 10)
local dungeonWorldConnection
if worldValue then
    dungeonWorldConnection = globalEnv.__afs_trackConnection(worldValue.Changed:Connect(function(value)
        if alive() and tostring(value) == "Dungeon" then
            dungeonActive = true
            DungeonFarm.entered = true
            if DungeonFarm.enabled then
                task.delay(0.5, function()
                    if alive()
                        and dungeonActive
                        and DungeonFarm.enabled
                        and tostring(getPlayerValue("World", "")) == "Dungeon"
                        and not DungeonFarm.running then
                        -- Let the farm loop retry the team after the world and
                        -- pet store finish loading instead of stopping here.
                        DungeonFarm.start()
                    end
                end)
            end
        elseif alive() and dungeonActive and DungeonFarm.entered and tostring(value) ~= "Dungeon" then
            task.delay(1, function()
                if alive() and dungeonActive and tostring(getPlayerValue("World", "")) ~= "Dungeon" then
                    if dungeonSession then
                        protectedCall("Restore dungeon after travel", function()
                            restoreDungeonSession("Da roi khoi dungeon")
                        end)
                    else
                        DungeonFarm.token = DungeonFarm.token + 1
                        DungeonFarm.running = false
                        DungeonFarm.entered = false
                        local dungeonActive = false
                        DungeonFarm.sessionDungeon = nil
                        DungeonFarm.teamApplied = false
                        DungeonFarm.teamApplying = false
                        DungeonFarm.teamIndexApplied = nil
                        DungeonFarm.route = {}
                        DungeonFarm.routeKey = ""
                        DungeonFarm.routeTarget = nil
                        DungeonFarm.goldTargetKey = nil
                        DungeonFarm.goldTargetRoom = nil
                        DungeonFarm.greenTargetKey = nil
                        DungeonFarm.goldRoomKeys = {}
                        DungeonFarm.phase = "idle"
                        DungeonFarm.updateStatus("Dungeon Farm: SAN SANG", "Da roi khoi dungeon.")
                    end
                end
            end)
        end
    end))
end

local function buildDungeonControls()
    dungeonMapByOption = {}
    dungeonTeamByOption = {}
    dungeonArtifactByOption = {}
    if not configLoaded then
        dungeonSelection.secondArtifact = getStoreValue("CurrentSecondArtefact", true, "") or ""
    end
    dungeonSizeByOption = {
        Small = 0,
        Medium = 1,
        Large = 2,
        Insane = 3,
        Hellish = 4
    }
    local worlds = makeDungeonWorldOptions()
    for _, option in ipairs(worlds) do
        local id = option:match("%[(.-)%]$")
        if id then
            dungeonMapByOption[option] = id
        end
    end
    local defaultMap
    for option, id in pairs(dungeonMapByOption) do
        if id == dungeonSelection.mapId then
            defaultMap = option
            break
        end
    end
    defaultMap = defaultMap or worlds[1]

    local teams = makeDungeonTeamOptions()
    local teamCount = #getStoreTable("PetTeams", true)
    local defaultTeamIndex = getDungeonDefaultTeam()
    local normalTeamIndex = tonumber(dungeonSelection.normalTeamIndex)
        or tonumber(dungeonSelection.teamIndex)
        or defaultTeamIndex
    if teamCount > 0 then
        if not configLoaded then
            normalTeamIndex = defaultTeamIndex
        end
        normalTeamIndex = math.clamp(math.floor(normalTeamIndex), 1, teamCount)
    else
        normalTeamIndex = 1
    end
    local goldTeamIndex = tonumber(dungeonSelection.goldTeamIndex) or normalTeamIndex
    if teamCount > 0 then
        goldTeamIndex = math.clamp(math.floor(goldTeamIndex), 1, teamCount)
    else
        goldTeamIndex = 1
    end
    dungeonSelection.normalTeamIndex = normalTeamIndex
    dungeonSelection.goldTeamIndex = goldTeamIndex
    dungeonSelection.teamIndex = normalTeamIndex

    local defaultNormalTeam
    local defaultGoldTeam
    for option, index in pairs(dungeonTeamByOption) do
        if index == normalTeamIndex then
            defaultNormalTeam = option
        end
        if index == goldTeamIndex then
            defaultGoldTeam = option
        end
    end

    local artifacts = makeDungeonArtifactOptions()
    local artifactOptions = {}
    for option, id in pairs(dungeonArtifactByOption) do
        if id == dungeonSelection.secondArtifact then artifactOptions[2] = option end
    end
    DungeonTab:Paragraph({
        Title = "Auto Dungeon",
        Desc = "Chon map, mode, kich thuoc, team room thuong va team room vang. Artifact Passage luon duoc dung de mo dungeon; vao map se dung team room thuong."
    })
    dungeonCooldownParagraph = DungeonTab:Button({
        Title = "Cooldown dungeon",
        Desc = utf8Text("Dang kiem tra...", 272, 97, 110, 103, 32, 107, 105, 7875, 109, 32, 116, 114, 97, 46, 46, 46),
        Callback = function() end
    })
    dungeonMapDropdown = DungeonTab:Dropdown({
        Title = utf8Text("Ban do dungeon", 66, 7843, 110, 32, 273, 7891, 32, 100, 117, 110, 103, 101, 111, 110),
        Values = worlds,
        Value = defaultMap,
        SearchBarEnabled = true,
        MenuWidth = 300,
        Callback = function(value)
            dungeonSelection.mapId = dungeonMapByOption[value] or dungeonSelection.mapId
            saveConfig(true)
        end
    })
    dungeonModeDropdown = DungeonTab:Dropdown({
        Title = "Mode",
        Values = {"Public", "Friends"},
        Value = dungeonSelection.mode == "Friends" and "Friends" or "Public",
        Callback = function(value)
            dungeonSelection.mode = value
            saveConfig(true)
        end
    })
    dungeonSizeDropdown = DungeonTab:Dropdown({
        Title = utf8Text("Kich thuoc dungeon", 75, 237, 99, 104, 32, 116, 104, 432, 7899, 99, 32, 100, 117, 110, 103, 101, 111, 110),
        Values = {"Small", "Medium", "Large", "Insane", "Hellish"},
        Value = ({[0]="Small", [1]="Medium", [2]="Large", [3]="Insane", [4]="Hellish"})[dungeonSelection.size] or "Medium",
        Callback = function(value)
            dungeonSelection.size = dungeonSizeByOption[value] or dungeonSelection.size
            saveConfig(true)
        end
    })
    dungeonNormalTeamDropdown = DungeonTab:Dropdown({
        Title = "Team room thuong",
        Values = teams,
        Value = defaultNormalTeam,
        SearchBarEnabled = true,
        MenuWidth = 300,
        Callback = function(value)
            dungeonSelection.normalTeamIndex = dungeonTeamByOption[value] or dungeonSelection.normalTeamIndex
            dungeonSelection.teamIndex = dungeonSelection.normalTeamIndex
            saveConfig(true)
        end
    })
    dungeonGoldTeamDropdown = DungeonTab:Dropdown({
        Title = "Team room vang",
        Values = teams,
        Value = defaultGoldTeam,
        SearchBarEnabled = true,
        MenuWidth = 300,
        Callback = function(value)
            dungeonSelection.goldTeamIndex = dungeonTeamByOption[value] or dungeonSelection.goldTeamIndex
            saveConfig(true)
        end
    })
    DungeonTab:Paragraph({
        Title = "Artefact 1",
        Desc = "Artifact of Passage (tu dong khi mo dungeon)."
    })
    dungeonSecondArtifactDropdown = DungeonTab:Dropdown({
        Title = "Artefact 2",
        Values = artifacts,
        Value = artifactOptions[2] or "(None)",
        SearchBarEnabled = true,
        MenuWidth = 300,
        Callback = function(value)
            dungeonSelection.secondArtifact = dungeonArtifactByOption[value] or ""
            saveConfig(true)
        end
    })
    dungeonToggle = DungeonTab:Toggle({
        Title = "Auto Mo Dungeon",
        Desc = "Tu mo dungeon + vao map khi co slot. Tat khong anh huong farm dang chay.",
        Value = false,
        Callback = function(value)
            if dungeonToggleUpdating or Feature.restoringFeatureState then
                return
            end
            Feature.autoDungeonEnabled = value == true
            protectedCall("Auto dungeon toggle", function()
                if value then
                    startAutoDungeon()
                else
                    -- Chi dung cho mo luot moi; farm dang chay cu de chay tiep.
                    dungeonWaiting = false
                    dungeonWaitToken = dungeonWaitToken + 1
                    DungeonFarm.updateStatus("Dungeon Farm: MO TAT", "Da tat Auto Mo; farm dang chay van tiep tuc.")
                end
            end)
            saveConfig(true)
        end
    })

    dungeonFarmStatusParagraph = DungeonTab:Button({
        Title = "Dungeon Farm: SAN SANG",
        Desc = "Dung fly noclip + instant interaction de mo room.",
        Callback = function() end
    })
    DungeonFarm.teleportDistanceSlider = DungeonTab:Slider({
        Title = "Khoang cach dung teleport",
        Desc = "Neu muc tieu gan hon moc nay thi dung teleport; xa hon se fly noclip.",
        Value = {
            Min = 25,
            Max = 1000,
            Default = DungeonFarm.teleportDistance
        },
        Step = 10,
        Callback = function(value)
            if configApplying or dropdownSyncing then return end
            DungeonFarm.teleportDistance = DungeonFarm.normalizeTeleportDistance(value)
            saveConfig(true)
        end
    })
    DungeonFarm.flySpeedSlider = DungeonTab:Slider({
        Title = "Toc do fly dungeon",
        Desc = "Toc do di chuyen khi muc tieu nam ngoai moc teleport.",
        Value = {
            Min = 40,
            Max = 1000,
            Default = DungeonFarm.flySpeed
        },
        Step = 10,
        Callback = function(value)
            if configApplying or dropdownSyncing then return end
            DungeonFarm.flySpeed = DungeonFarm.normalizeFlySpeed(value)
            saveConfig(true)
        end
    })
    dungeonFarmToggle = DungeonTab:Toggle({
        Title = "Auto Farm Dungeon",
        Desc = "Gan thi teleport; xa thi fly noclip, active room, mo cua vang, clear enemy va chest. Tat khong anh huong mo dungeon.",
        Value = DungeonFarm.enabled,
        Callback = function(value)
            if DungeonFarm.toggleUpdating or Feature.restoringFeatureState then
                return
            end
            DungeonFarm.enabled = value == true
            DungeonFarm.token = DungeonFarm.token + 1
            if DungeonFarm.enabled and dungeonActive then
                DungeonFarm.running = false
                if DungeonFarm.entered then
                    DungeonFarm.start()
                else
                    DungeonFarm.phase = "waiting_entry"
                    DungeonFarm.updateStatus("Dungeon Farm: CHO VAO", "Dang cho vao Dungeon...")
                end
            elseif not DungeonFarm.enabled then
                DungeonFarm.running = false
                DungeonFarm.phase = "idle"
                DungeonFarm.updateStatus("Dungeon Farm: TAT", "Farm dungeon dang tat.")
            end
            saveConfig(true)
        end
    })
end

function AutoPassive.collectPlainDropdownValues(value)
    local result = {}
    local seen = {}
    local function add(item)
        if type(item) == "string" and item ~= "" and not seen[item] then
            seen[item] = true
            table.insert(result, item)
        end
    end
    if type(value) == "string" then
        add(value)
    elseif type(value) == "table" then
        for key, item in pairs(value) do
            if type(item) == "string" then
                add(item)
            elseif type(item) == "table" then
                add(item.Title or item.Name or item[1])
            elseif item == true and type(key) == "string" then
                add(key)
            end
        end
    end
    return result
end

function AutoPassive.buildAutoPassiveControls()
    local passiveOptions = AutoPassive.makeAutoPassiveTargetOptions()
    local rarityOptions = AutoPassive.makeAutoPassiveRarityOptions()
    local categoryOptions = AutoPassive.makeAutoPassiveCategoryOptions()

    AutoPassiveTab:Paragraph({
        Title = "Auto Passive",
        Desc = "Chon pet, passive/pham chat, slot va currency. Tat ca pet trong danh sach co the roll cung dot.",
    })
    Feature.autoPassiveStatusParagraph = AutoPassiveTab:Button({
        Title = "Auto Passive: TAT",
        Desc = "Chua cau hinh.",
        Callback = function() end
    })

    Feature.autoPassiveTargetDropdown = AutoPassiveTab:Dropdown({
        Title = "Passive can giu",
        Desc = "Dung khi che do giu theo passive chinh xac.",
        Values = passiveOptions,
        Multi = true,
        AllowNone = true,
        SearchBarEnabled = true,
        MenuWidth = 360,
        Callback = function(value)
            if configApplying or dropdownSyncing then return end
            Feature.autoPassiveTargetPassives = AutoPassive.collectMappedDropdownValues(value, AutoPassiveMaps.optionToPassive)
            Feature.updateAutoPassiveStatus()
            saveConfig(true)
        end
    })

    Feature.autoPassiveRarityDropdown = AutoPassiveTab:Dropdown({
        Title = "Pham chat can giu",
        Desc = "Dung khi che do giu theo quality.",
        Values = rarityOptions,
        Multi = true,
        AllowNone = true,
        Callback = function(value)
            if configApplying or dropdownSyncing then return end
            Feature.autoPassiveTargetRarities = AutoPassive.collectPlainDropdownValues(value)
            Feature.updateAutoPassiveStatus()
            saveConfig(true)
        end
    })

    Feature.autoPassiveKeepModeDropdown = AutoPassiveTab:Dropdown({
        Title = "Kieu giu",
        Values = {"Exact passive", "Quality"},
        Value = Feature.autoPassiveKeepMode == "rarity" and "Quality" or "Exact passive",
        Callback = function(value)
            if configApplying or dropdownSyncing then return end
            Feature.autoPassiveKeepMode = value == "Quality" and "rarity" or "passive"
            Feature.updateAutoPassiveStatus()
            saveConfig(true)
        end
    })

    Feature.autoPassiveCurrencyDropdown = AutoPassiveTab:Dropdown({
        Title = "Roll bang currency",
        Values = {"Passive token", "Shard"},
        Value = Feature.autoPassiveCurrency == "shard" and "Shard" or "Passive token",
        Callback = function(value)
            if configApplying or dropdownSyncing then return end
            Feature.autoPassiveCurrency = value == "Shard" and "shard" or "token"
            Feature.updateAutoPassiveStatus()
            saveConfig(true)
        end
    })

    Feature.autoPassiveCategoryDropdown = AutoPassiveTab:Dropdown({
        Title = "Passive category",
        Desc = "Normal dung PassiveToken; category event dung token rieng.",
        Values = categoryOptions,
        Value = (function()
            for option, category in pairs(AutoPassiveMaps.categoryByOption) do
                if tostring(category) == tostring(Feature.autoPassiveCategory) then
                    return option
                end
            end
            return "Normal"
        end)(),
        SearchBarEnabled = true,
        MenuWidth = 260,
        Callback = function(value)
            if configApplying or dropdownSyncing then return end
            Feature.autoPassiveCategory = AutoPassiveMaps.categoryByOption[value] or ""
            Feature.updateAutoPassiveStatus()
            saveConfig(true)
        end
    })

    Feature.autoPassiveSlotDropdown = AutoPassiveTab:Dropdown({
        Title = "Slot passive",
        Values = {"Slot 1", "Slot 2"},
        Value = Feature.autoPassiveSlot == 2 and "Slot 2" or "Slot 1",
        Callback = function(value)
            if configApplying or dropdownSyncing then return end
            Feature.autoPassiveSlot = value == "Slot 2" and 2 or 1
            Feature.updateAutoPassiveStatus()
            saveConfig(true)
        end
    })

    Feature.autoPassiveRollDelaySlider = AutoPassiveTab:Slider({
        Title = "Toc do roll passive",
        Desc = "Khoang cach giua cac dot roll, mac dinh 0.3 giay.",
        Value = {
            Min = Feature.autoPassiveRollDelayMin,
            Max = Feature.autoPassiveRollDelayMax,
            Default = Feature.autoPassiveRollDelay
        },
        Step = 0.1,
        Callback = function(value)
            if configApplying or dropdownSyncing then return end
            Feature.autoPassiveRollDelay = AutoPassive.normalizeRollDelay(value)
            Feature.updateAutoPassiveStatus()
            saveConfig(true)
        end
    })

    AutoPassiveTab:Button({
        Title = "Quet lai danh sach pet",
        Desc = "Cap nhat pet moi cho dropdown Auto Passive.",
        Callback = function()
            protectedCall("Scan passive pets", scanPets)
        end
    })

    Feature.autoPassiveToggle = AutoPassiveTab:Toggle({
        Title = "Bat Auto Passive",
        Desc = "Roll song song cac pet chua dat muc tieu.",
        Value = false,
        Callback = function(value)
            if Feature.autoPassiveToggleUpdating or Feature.restoringFeatureState then return end
            Feature.autoPassiveEnabled = value == true
            if Feature.autoPassiveEnabled then
                AutoPassive.startAutoPassive()
            else
                Feature.autoPassiveRunToken = Feature.autoPassiveRunToken + 1
                Feature.autoPassiveLastMessage = "Da dung."
                Feature.updateAutoPassiveStatus()
            end
            saveConfig(true)
        end
    })

    -- Vong nen gan o tick chon-tat-ca vao menu dropdown passive dang mo.
    task.spawn(function()
        while alive() do
            protectedCall("Passive menu watch", Feature.pollPassiveMenuInject)
            task.wait(0.5)
        end
    end)
end

Feature.mainStatusParagraph = MainTab:Button({
    Title = "Main | dang khoi tao",
    Desc = "Trang thai Auto collect drop.",
    Callback = function() end
})

Feature.autoCollectDropsToggle = MainTab:Toggle({
    Title = "Auto collect drop",
    Desc = "Dua drop trong workspace.Effects ve player khong gioi han khoang cach.",
    Value = false,
    Callback = function(value)
        if Feature.autoCollectDropsToggleUpdating or Feature.restoringFeatureState then
            return
        end
        Feature.autoCollectDropsEnabled = value == true
        if not Feature.autoCollectDropsEnabled then
            Feature.mainSeenDrops = setmetatable({}, {__mode = "k"})
        end
        Feature.updateMainStatus(true)
        saveConfig(true)
    end
})

Feature.tpPetToggle = MainTab:Toggle({
    Title = "TP Pet",
    Desc = "Gia lap passive Lightspeed (Teleport): pet tele thang toi quai o xa thay vi bay tu tu. Ap dung cho pet duoc goi ra sau khi bat (doi team / vao dungeon de respawn pet dang o ngoai).",
    Value = false,
    Callback = function(value)
        if Feature.tpPetToggleUpdating or Feature.restoringFeatureState then
            return
        end
        Feature.tpPetEnabled = value == true
        if not Feature.applyTpPet() then
            Feature.tpPetEnabled = false
            Feature.tpPetToggleUpdating = true
            pcall(function()
                Feature.tpPetToggle:Set(false)
            end)
            Feature.tpPetToggleUpdating = false
            safeNotify(WindUI, "TP Pet", "Khong hook duoc HasPassive, da tat lai.")
        elseif Feature.tpPetEnabled then
            safeNotify(WindUI, "TP Pet", "Da bat: pet goi ra sau day se tele toi quai.")
        end
        Feature.updateMainStatus(true)
        saveConfig(true)
    end
})

Feature.attackWhileUltToggle = MainTab:Toggle({
    Title = "Attack While Ult",
    Desc = "Danh tay trong luc pet dung skill: tu Fire PetAttack cho pet dang ult (AbilityUseTime > 0) moi 1 giay de damage va thanh nang luong van tang.",
    Value = false,
    Callback = function(value)
        if Feature.attackWhileUltToggleUpdating or Feature.restoringFeatureState then
            return
        end
        Feature.attackWhileUltEnabled = value == true
        if Feature.attackWhileUltEnabled then
            safeNotify(WindUI, "Attack While Ult", "Da bat: pet van danh tay trong luc ult.")
        end
        Feature.updateMainStatus(true)
        saveConfig(true)
    end
})

MainTab:Button({
    Title = "Mo GUI Dupe Machine",
    Desc = "Mo cua so Dupe Machine bang luong GUI cua game.",
    Callback = function()
        protectedCall("Open dupe machine GUI", openDupeMachineGui)
    end
})

statusParagraph = StatusTab:Button({
    Title = "Trang thai may",
    Desc = "Trang thai A/B/K/M cap nhat lien tuc trong tab nay.",
    Callback = function() end
})

infoParagraph = CloneTab:Button({
    Title = "Auto Clone: TAT",
    Desc = "Bang status se cap nhat lien tuc.",
    Callback = function() end
})

selectedParagraph = CloneTab:Button({
    Title = "Da chon 0/4",
    Desc = "Chua quet tui pet.",
    Callback = function() end
})

occupiedParagraph = CloneTab:Button({
    Title = utf8Text("Pet dang o may khac", 80, 101, 116, 32, 273, 97, 110, 103, 32, 7903, 32, 109, 225, 121, 32, 107, 104, 225, 99),
    Desc = utf8Text("Dang quet...", 272, 97, 110, 103, 32, 113, 117, 233, 116, 46, 46, 46),
    Callback = function() end
})
CloneTab:Button({
    Title = "Quet tui pet",
    Desc = "Cap nhat danh sach Name, Level, UID",
    Callback = function()
        protectedCall("Scan pets", scanPets)
    end
})

Feature.autoCloneToggle = CloneTab:Toggle({
    Title = "Bat Auto Clone",
    Desc = "Rut khi xong va nap lai pet da chon",
    Value = false,
    Callback = function(value)
        if Feature.autoCloneToggleUpdating or Feature.restoringFeatureState then
            return
        end
        protectedCall("Auto clone toggle", function()
            autoEnabled = value == true
            if autoEnabled and selectedCount() == 0 then
                autoEnabled = false
                Feature.autoCloneToggleUpdating = true
                pcall(function()
                    Feature.autoCloneToggle:Set(false)
                end)
                Feature.autoCloneToggleUpdating = false
                stopAutoAndReturn()
                notifyStatus("Chua chon pet", "Hay quet tui va chon it nhat 1 pet.")
                saveConfig(true)
                return
            end
            if autoEnabled then
                initialLocation = captureLocation()
                if not initialLocation then
                    autoEnabled = false
                    Feature.autoCloneToggleUpdating = true
                    pcall(function()
                        Feature.autoCloneToggle:Set(false)
                    end)
                    Feature.autoCloneToggleUpdating = false
                    stopAutoAndReturn()
                    notifyStatus("Khong lay duoc vi tri", "Nhan vat chua san sang.")
                    saveConfig(true)
                    return
                end
            else
                stopAutoAndReturn()
            end
            notifyStatus("Auto Clone", autoEnabled and "Da bat" or "Da tat")
            updateMachineStatus()
            saveConfig(true)
        end)
    end
})

CloneTab:Button({
    Title = "Mo GUI Clone Machine",
    Desc = "Mo giao dien may gan nhat ma khong can di toi",
    Callback = function()
        protectedCall("Open clone GUI", openCloneGui)
    end
})

Feature.autoFarmStatusParagraph = FarmTab:Button({
    Title = "Auto Farm: TAT",
    Desc = "Dang cho cau hinh.",
    Callback = function() end
})

Feature.autoFarmModeDropdown = FarmTab:Dropdown({
    Title = "Cach chon muc tieu",
    Values = {
        Feature.modeLabel(Feature.MODE_NEAREST),
        Feature.modeLabel(Feature.MODE_LOWEST_HEALTH),
        Feature.modeLabel(Feature.MODE_HIGHEST_HEALTH)
    },
    Value = Feature.modeLabel(Feature.autoFarmMode),
    Callback = function(value)
        if Feature.restoringFeatureState or dropdownSyncing then
            return
        end
        Feature.autoFarmMode = Feature.modeFromLabel(value)
        Feature.autoFarmTarget = nil
        Feature.autoFarmLastSend = 0
        saveConfig(true)
        Feature.updateStatus()
    end
})

Feature.autoFarmToggle = FarmTab:Toggle({
    Title = "Bat Auto Farm",
    Desc = "Gui ca team pet vao muc tieu trong map hien tai.",
    Value = false,
    Callback = function(value)
        if Feature.autoFarmToggleUpdating or Feature.restoringFeatureState then
            return
        end
        Feature.autoFarmEnabled = value == true
        if not Feature.autoFarmEnabled then
            Feature.withdrawPets()
        else
            Feature.autoFarmTarget = nil
            Feature.autoFarmLastSend = 0
            Feature.step()
        end
        saveConfig(true)
        Feature.updateStatus()
    end
})

SettingsTab:Button({
    Title = "Hop server it nguoi",
    Desc = "Tu chuyen sang server public it nguoi nhat (bo qua server hien tai).",
    Callback = function()
        protectedCall("Hop server", function()
            local TeleportService = game:GetService("TeleportService")
            local placeId = game.PlaceId
            local currentJob = game.JobId
            notifyStatus("Hop server", "Dang tim server it nguoi...")
            local cursor = nil
            local best = nil
            for _ = 1, 5 do
                local url = string.format(
                    "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100%s",
                    placeId,
                    cursor and ("&cursor=" .. tostring(cursor)) or ""
                )
                local ok, body = pcall(function()
                    return game:HttpGet(url)
                end)
                if not ok or type(body) ~= "string" or body == "" then
                    notifyStatus("Hop loi", "Khong lay duoc danh sach server.")
                    return
                end
                local okJson, data = pcall(function()
                    return decodeJson(body)
                end)
                if not okJson or type(data) ~= "table" or type(data.data) ~= "table" then
                    notifyStatus("Hop loi", "Du lieu server khong hop le.")
                    return
                end
                for _, server in ipairs(data.data) do
                    local playing = type(server) == "table" and tonumber(server.playing)
                    local maxPlayers = type(server) == "table" and tonumber(server.maxPlayers)
                    if playing and maxPlayers
                        and server.id ~= currentJob
                        and playing < maxPlayers then
                        -- sortOrder Asc: server dau tien du dieu kien la it nguoi nhat.
                        best = server
                        break
                    end
                end
                if best then
                    break
                end
                cursor = data.nextPageCursor
                if type(cursor) ~= "string" or cursor == "" then
                    break
                end
            end
            if not best then
                notifyStatus("Hop", "Khong tim duoc server trong; thu lai sau.")
                return
            end
            notifyStatus(
                "Hop server",
                string.format("Qua server %d/%d nguoi...", tonumber(best.playing) or 0, tonumber(best.maxPlayers) or 0)
            )
            local okTp, err = pcall(function()
                TeleportService:TeleportToPlaceInstance(placeId, best.id, LocalPlayer)
            end)
            if not okTp then
                notifyStatus("Hop loi", tostring(err))
            end
        end)
    end
})

SettingsTab:Button({
    Title = utf8Text("An menu", 7848, 110, 32, 109, 101, 110, 117),
    Desc = utf8Text("Dong menu; mo lai bang RightShift", 272, 243, 110, 103, 32, 109, 101, 110, 117, 59, 32, 109, 7903, 32, 108, 7841, 105, 32, 98, 7857, 110, 103, 32, 82, 105, 103, 104, 116, 83, 104, 105, 102, 116),
    Callback = function()
        protectedCall("Hide menu", function()
            local ok, err = setWindowVisible(false)
            if not ok then
                notifyStatus("UI loi", tostring(err))
            end
        end)
    end
})

SettingsTab:Button({
    Title = utf8Text("Luu cau hinh", 76, 432, 117, 32, 99, 7845, 117, 32, 104, 236, 110, 104),
    Desc = utf8Text("Tu luu pet va thiet lap vao AutoClone/config.json", 84, 7921, 32, 108, 432, 117, 32, 112, 101, 116, 32, 118, 224, 32, 116, 104, 105, 7871, 116, 32, 108, 7853, 112, 32, 118, 224, 111, 32, 65, 117, 116, 111, 67, 108, 111, 110, 101, 47, 99, 111, 110, 102, 105, 103, 46, 106, 115, 111, 110),
    Callback = function()
        protectedCall("Save config", saveConfig)
    end
})

SettingsTab:Button({
    Title = utf8Text("Tai cau hinh", 84, 7843, 105, 32, 99, 7845, 117, 32, 104, 236, 110, 104),
    Desc = utf8Text("Nap lai danh sach pet va thiet lap da luu", 78, 7841, 112, 32, 108, 7841, 105, 32, 100, 97, 110, 104, 32, 115, 225, 99, 104, 32, 112, 101, 116, 32, 118, 224, 32, 116, 104, 105, 7871, 116, 32, 108, 7853, 112, 32, 273, 227, 32, 108, 432, 117),
    Callback = function()
        -- Chay nen de nut nha ra ngay; dropdown giu lai khi pet khong doi
        -- nen lan tai lai sau cung nhe hon nhieu.
        notifyStatus("Cau hinh", "Dang tai cau hinh...")
        task.spawn(function()
            controlsReady = false
            beginConfigApply()
            protectedCall("Load config", function()
                if autoEnabled then
                    stopAutoAndReturn()
                end
                loadConfig()
                scanPets()
                task.wait()
                updateMachineStatus()
                task.wait()
                syncDungeonControls()
                task.wait()
                Feature.syncControls()
                task.wait()
                Feature.applySavedState()
            end)
            controlsReady = true
            notifyStatus("Cau hinh", "Da tai xong cau hinh.")
        end)
    end
})

SettingsTab:Button({
    Title = "Refresh team",
    Desc = "Quet lai danh sach PetTeams va cap nhat dropdown team.",
    Callback = function()
        protectedCall("Refresh teams", function()
            if refreshTeamOptions then
                refreshTeamOptions()
            end
        end)
    end
})

SettingsTab:Button({
    Title = utf8Text("Mo Artefact tu xa", 77, 7903, 32, 65, 114, 116, 101, 102, 97, 99, 116, 32, 116, 7915, 32, 120, 97),
    Desc = utf8Text("Mo bang Artefact ma khong can di chuyen", 77, 7903, 32, 98, 7843, 110, 103, 32, 65, 114, 116, 101, 102, 97, 99, 116, 32, 109, 224, 32, 107, 104, 244, 110, 103, 32, 99, 7847, 110, 32, 100, 105, 32, 99, 104, 117, 121, 7875, 110),
    Callback = function()
        protectedCall("Open artefact GUI", openArtifactGui)
    end
})

Feature.buildGateControls = function()
    local farm = Feature.gateFarm
    farm.tab = Window:Tab({
        Title = "Auto Gate",
        Icon = "door-open"
    })
    farm.tab:Paragraph({
        Title = "Auto Gate",
        Desc = "Chon gate va team. Tu mo MAX gate dang co, vao farm, chay den khi tat."
    })
    local owned = Feature.gateOwned()
    local options = {}
    farm.optionToId = {}
    for _, rank in ipairs(Feature.gateRanks()) do
        local option = string.format("%s Rank (%d)", rank.name, owned[rank.id] or 0)
        table.insert(options, option)
        farm.optionToId[option] = rank.id
    end
    local defaultGate = options[1]
    for option, id in pairs(farm.optionToId) do
        if id == farm.gateId then
            defaultGate = option
            break
        end
    end
    farm.gateDropdown = farm.tab:Dropdown({
        Title = "Gate",
        Values = options,
        Value = defaultGate,
        Callback = function(value)
            farm.gateId = farm.optionToId[value] or farm.gateId
            saveConfig(true)
        end
    })
    farm.runsSlider = nil
    farm.amountSlider = nil
    local teams = makeDungeonTeamOptions()
    local defaultTeam
    for option, index in pairs(dungeonTeamByOption) do
        if index == farm.teamIndex then
            defaultTeam = option
            break
        end
    end
    farm.teamDropdown = farm.tab:Dropdown({
        Title = "Team di gate",
        Values = teams,
        Value = defaultTeam,
        SearchBarEnabled = true,
        MenuWidth = 300,
        Callback = function(value)
            farm.teamIndex = dungeonTeamByOption[value] or farm.teamIndex
            saveConfig(true)
        end
    })
    farm.openToggle = farm.tab:Toggle({
        Title = "Auto Mo Gate",
        Desc = "Tu mo MAX gate dang co, equip team, vao GatesMode. Het quai tu ve.",
        Value = false,
        Callback = function(value)
            if farm.toggleUpdating or Feature.restoringFeatureState then
                return
            end
            farm.openEnabled = value == true
            Feature.gateSyncEnabled()
            protectedCall("Auto open gate toggle", function()
                if value then
                    Feature.gateStart()
                else
                    Feature.gateToggleOff("Da tat Auto Mo Gate.")
                end
            end)
            saveConfig(true)
        end
    })
    farm.farmToggle = farm.tab:Toggle({
        Title = "Auto Farm Gate",
        Desc = "Tu bay toi quai va gui pet farm trong GatesMode.",
        Value = false,
        Callback = function(value)
            if farm.toggleUpdating or Feature.restoringFeatureState then
                return
            end
            farm.farmEnabled = value == true
            Feature.gateSyncEnabled()
            protectedCall("Auto farm gate toggle", function()
                if value then
                    Feature.gateStart()
                else
                    Feature.gateToggleOff("Da tat Auto Farm Gate.")
                end
            end)
            saveConfig(true)
        end
    })
    farm.statusParagraph = farm.tab:Button({
        Title = "Auto Gate: SAN SANG",
        Desc = "Chon gate, so luong, team roi bat toggle.",
        Callback = function() end
    })
end

Feature.buildFallenStarControls = function()
    local teamOptions = makeDungeonTeamOptions()
    local defaultTeamOption = teamOptions[1]
    for option, index in pairs(dungeonTeamByOption) do
        if index == dungeonSelection.fallenStarTeamIndex then
            defaultTeamOption = option
            break
        end
    end
    globalEnv.__afs_fallenStarTab:Paragraph({
        Title = "Auto Farm Fallen Star",
        Desc = "Theo doi Star Shower, bao map spawn tren chat va tu toi farm Fallen Star."
    })
    Feature.autoFallenStarStatusParagraph = globalEnv.__afs_fallenStarTab:Button({
        Title = "Auto Fallen Star: TAT",
        Desc = "Dang cho bat toggle.",
        Callback = function() end
    })
    Feature.autoFallenStarTeamDropdown = globalEnv.__afs_fallenStarTab:Dropdown({
        Title = "Team danh Fallen Star",
        Desc = "Team se duoc equip truoc khi toi map co star.",
        Values = teamOptions,
        Value = defaultTeamOption,
        SearchBarEnabled = true,
        MenuWidth = 300,
        Callback = function(value)
            if configApplying or dropdownSyncing then
                return
            end
            dungeonSelection.fallenStarTeamIndex = dungeonTeamByOption[value] or dungeonSelection.fallenStarTeamIndex
            saveConfig(true)
        end
    })
    Feature.autoFallenStarIntervalSlider = globalEnv.__afs_fallenStarTab:Slider({
        Title = "Chu ky quet",
        Desc = "Khoang cach quet map de tim star moi.",
        Value = {
            Min = 0.5,
            Max = 10,
            Default = Feature.autoFallenStarInterval
        },
        Step = 0.5,
        Callback = function(value)
            if configApplying or dropdownSyncing then
                return
            end
            Feature.autoFallenStarInterval = math.clamp(
                math.floor((tonumber(value) or 1) * 2 + 0.5) / 2,
                0.5,
                10
            )
            Feature.fallenStarFarm.interval = Feature.autoFallenStarInterval
            Feature.fallenStarFarm.nextScanAt = 0
            Feature.fallenStarFarm.updateStatus()
            saveConfig(true)
        end
    })
    globalEnv.__afs_fallenStarTab:Button({
        Title = "Quet Fallen Star ngay",
        Desc = "Quet thu cong va thong bao neu event dang bat.",
        Callback = function()
            protectedCall("Scan fallen star", function()
                Feature.fallenStarFarm.nextScanAt = 0
                Feature.fallenStarFarm.scan(true)
                Feature.fallenStarFarm.updateStatus()
            end)
        end
    })
    Feature.autoFallenStarToggle = globalEnv.__afs_fallenStarTab:Toggle({
        Title = "Bat Auto Fallen Star",
        Desc = "Tu di map co star, tele toi vi tri va gui pet danh.",
        Value = false,
        Callback = function(value)
            if Feature.autoFallenStarToggleUpdating or Feature.restoringFeatureState then
                return
            end
            Feature.autoFallenStarEnabled = value == true
            Feature.fallenStarFarm.enabled = Feature.autoFallenStarEnabled
            Feature.fallenStarFarm.nextScanAt = 0
            if not Feature.fallenStarFarm.enabled then
                Feature.fallenStarFarm.stop()
            else
                Feature.fallenStarFarm.lastMessage = "Dang cho Star Shower."
                Feature.fallenStarFarm.updateStatus()
            end
            saveConfig(true)
        end
    })
end

protectedCall("Build dungeon controls", buildDungeonControls)
protectedCall("Build gate controls", Feature.buildGateControls)
protectedCall("Build auto passive controls", AutoPassive.buildAutoPassiveControls)
protectedCall("Build fallen star controls", Feature.buildFallenStarControls)

local function selectMapped(dropdown, mapping, wanted)
    if not dropdown or wanted == nil then
        return
    end
    for option, value in pairs(mapping) do
        if tostring(value) == tostring(wanted) then
            pcall(function()
                dropdown:Select(option)
            end)
            return
        end
    end
end

refreshTeamOptions = function()
    local teams = getStoreTable("PetTeams", true)
    dungeonTeamByOption = {}
    local options = makeDungeonTeamOptions()
    local teamCount = #teams

    local function clampTeamIndex(value, fallback)
        if teamCount < 1 then
            return 1
        end
        return math.clamp(math.floor(tonumber(value) or fallback or 1), 1, teamCount)
    end

    dungeonSelection.normalTeamIndex = clampTeamIndex(
        dungeonSelection.normalTeamIndex or dungeonSelection.teamIndex,
        1
    )
    dungeonSelection.goldTeamIndex = clampTeamIndex(
        dungeonSelection.goldTeamIndex or dungeonSelection.normalTeamIndex,
        dungeonSelection.normalTeamIndex
    )
    dungeonSelection.fallenStarTeamIndex = clampTeamIndex(
        dungeonSelection.fallenStarTeamIndex or dungeonSelection.normalTeamIndex,
        dungeonSelection.normalTeamIndex
    )
    dungeonSelection.teamIndex = dungeonSelection.normalTeamIndex

    local gateFarm = Feature.gateFarm
    gateFarm.teamIndex = clampTeamIndex(gateFarm.teamIndex, dungeonSelection.normalTeamIndex)

    local refreshed = 0
    for _, dropdown in pairs({
        dungeonNormalTeamDropdown,
        dungeonGoldTeamDropdown,
        Feature.autoFallenStarTeamDropdown,
        gateFarm.teamDropdown
    }) do
        if dropdown then
            local ok = pcall(function()
                dropdown:Refresh(options)
            end)
            if ok then
                refreshed = refreshed + 1
            end
        end
    end

    beginDropdownSync()
    if syncDungeonControls then
        syncDungeonControls()
    end
    selectMapped(gateFarm.teamDropdown, dungeonTeamByOption, gateFarm.teamIndex)
    saveConfig(true)
    notifyStatus(
        "Teams",
        string.format("Da quet %d team; cap nhat %d dropdown.", teamCount, refreshed)
    )
end

function AutoPassive.selectMappedMulti(dropdown, mapping, wanted)
    if not dropdown or type(wanted) ~= "table" then
        return
    end
    local selected = {}
    for _, wantedValue in ipairs(wanted) do
        for option, value in pairs(mapping) do
            if tostring(value) == tostring(wantedValue) then
                table.insert(selected, option)
                break
            end
        end
    end
    if #selected > 0 then
        pcall(function()
            dropdown:Select(selected)
        end)
    end
end

Feature.syncAutoPassiveControls = function()
    beginDropdownSync()
    AutoPassive.selectMappedMulti(Feature.autoPassiveTargetDropdown, AutoPassiveMaps.optionToPassive, Feature.autoPassiveTargetPassives)
    if Feature.autoPassiveRarityDropdown and #Feature.autoPassiveTargetRarities > 0 then
        pcall(function()
            Feature.autoPassiveRarityDropdown:Select(Feature.autoPassiveTargetRarities)
        end)
    end
    pcall(function()
        Feature.autoPassiveKeepModeDropdown:Select(Feature.autoPassiveKeepMode == "rarity" and "Quality" or "Exact passive")
        Feature.autoPassiveCurrencyDropdown:Select(Feature.autoPassiveCurrency == "shard" and "Shard" or "Passive token")
        local categoryOption = "Normal"
        for option, category in pairs(AutoPassiveMaps.categoryByOption) do
            if tostring(category) == tostring(Feature.autoPassiveCategory) then
                categoryOption = option
                break
            end
        end
        Feature.autoPassiveCategoryDropdown:Select(categoryOption)
        Feature.autoPassiveSlotDropdown:Select(Feature.autoPassiveSlot == 2 and "Slot 2" or "Slot 1")
        if Feature.autoPassiveRollDelaySlider then
            Feature.autoPassiveRollDelaySlider:Set(Feature.autoPassiveRollDelay)
        end
    end)
    Feature.updateAutoPassiveStatus()
end

syncDungeonControls = function()
    beginDropdownSync()
    selectMapped(dungeonMapDropdown, dungeonMapByOption, dungeonSelection.mapId)
    selectMapped(
        dungeonNormalTeamDropdown,
        dungeonTeamByOption,
        dungeonSelection.normalTeamIndex or dungeonSelection.teamIndex
    )
    selectMapped(
        dungeonGoldTeamDropdown,
        dungeonTeamByOption,
        dungeonSelection.goldTeamIndex or dungeonSelection.normalTeamIndex or dungeonSelection.teamIndex
    )
    selectMapped(
        Feature.autoFallenStarTeamDropdown,
        dungeonTeamByOption,
        dungeonSelection.fallenStarTeamIndex or dungeonSelection.normalTeamIndex or dungeonSelection.teamIndex
    )
    selectMapped(dungeonSecondArtifactDropdown, dungeonArtifactByOption, dungeonSelection.secondArtifact)
    local sizeNames = {[0] = "Small", [1] = "Medium", [2] = "Large", [3] = "Insane", [4] = "Hellish"}
    pcall(function()
        dungeonSizeDropdown:Select(sizeNames[dungeonSelection.size] or "Medium")
    end)
    pcall(function()
        dungeonModeDropdown:Select(dungeonSelection.mode == "Friends" and "Friends" or "Public")
    end)
    if dungeonFarmToggle then
        DungeonFarm.toggleUpdating = true
        pcall(function()
            dungeonFarmToggle:Set(DungeonFarm.enabled)
        end)
        DungeonFarm.toggleUpdating = false
    end
    pcall(function()
        if DungeonFarm.teleportDistanceSlider then
            DungeonFarm.teleportDistanceSlider:Set(DungeonFarm.teleportDistance)
        end
        if DungeonFarm.flySpeedSlider then
            DungeonFarm.flySpeedSlider:Set(DungeonFarm.flySpeed)
        end
    end)
end

Feature.syncControls = function()
    beginDropdownSync()
    if Feature.autoFarmModeDropdown then
        pcall(function()
            Feature.autoFarmModeDropdown:Select(Feature.modeLabel(Feature.autoFarmMode))
        end)
    end
    if Feature.autoFallenStarIntervalSlider then
        pcall(function()
            Feature.autoFallenStarIntervalSlider:Set(Feature.autoFallenStarInterval)
        end)
    end
    if Feature.syncAutoPassiveControls then
        Feature.syncAutoPassiveControls()
    end
end

local function setToggleSilently(toggle, value, markerSetter)
    if not toggle then
        return
    end
    markerSetter(true)
    pcall(function()
        toggle:Set(value == true)
    end)
    markerSetter(false)
end

Feature.applySavedState = function()
    local desired = type(Feature.savedFeatureState) == "table" and Feature.savedFeatureState or {}
    Feature.restoringFeatureState = true
    DungeonFarm.enabled = desired.autoDungeonFarm ~= false
    if dungeonFarmToggle then
        DungeonFarm.toggleUpdating = true
        pcall(function()
            dungeonFarmToggle:Set(DungeonFarm.enabled)
        end)
        DungeonFarm.toggleUpdating = false
    end
    autoEnabled = false
    Feature.autoFarmEnabled = false
    Feature.autoFallenStarEnabled = false
    Feature.fallenStarFarm.enabled = false
    Feature.autoDungeonEnabled = false
    Feature.autoPassiveEnabled = false
    Feature.autoPassiveRunToken = Feature.autoPassiveRunToken + 1
    Feature.autoFarmTarget = nil
    Feature.autoFarmLastSend = 0
    Feature.mainSeenDrops = setmetatable({}, {__mode = "k"})
    setToggleSilently(Feature.autoCloneToggle, false, function(value)
        Feature.autoCloneToggleUpdating = value
    end)
    setToggleSilently(Feature.autoFarmToggle, false, function(value)
        Feature.autoFarmToggleUpdating = value
    end)
    setToggleSilently(Feature.autoFallenStarToggle, false, function(value)
        Feature.autoFallenStarToggleUpdating = value
    end)
    setToggleSilently(dungeonToggle, false, function(value)
        dungeonToggleUpdating = value
    end)
    setToggleSilently(Feature.autoPassiveToggle, false, function(value)
        Feature.autoPassiveToggleUpdating = value
    end)
    setToggleSilently(Feature.autoCollectDropsToggle, false, function(value)
        Feature.autoCollectDropsToggleUpdating = value
    end)
    setToggleSilently(Feature.tpPetToggle, false, function(value)
        Feature.tpPetToggleUpdating = value
    end)
    setToggleSilently(Feature.attackWhileUltToggle, false, function(value)
        Feature.attackWhileUltToggleUpdating = value
    end)
    Feature.autoCollectDropsEnabled = false
    Feature.tpPetEnabled = false
    Feature.applyTpPet()
    Feature.attackWhileUltEnabled = false
    Feature.restoringFeatureState = false

    if desired.autoClone and selectedCount() > 0 then
        local location = captureLocation()
        if location then
            autoEnabled = true
            initialLocation = location
            setToggleSilently(Feature.autoCloneToggle, true, function(value)
                Feature.autoCloneToggleUpdating = value
            end)
        end
    end

    if desired.autoFarm then
        Feature.autoFarmEnabled = true
        setToggleSilently(Feature.autoFarmToggle, true, function(value)
            Feature.autoFarmToggleUpdating = value
        end)
    end

    if desired.autoFallenStar then
        Feature.autoFallenStarEnabled = true
        Feature.fallenStarFarm.enabled = true
        Feature.fallenStarFarm.nextScanAt = 0
        setToggleSilently(Feature.autoFallenStarToggle, true, function(value)
            Feature.autoFallenStarToggleUpdating = value
        end)
    end

    if desired.autoDungeon then
        Feature.autoDungeonEnabled = true
        setToggleSilently(dungeonToggle, true, function(value)
            dungeonToggleUpdating = value
        end)
        task.spawn(function()
            protectedCall("Start saved auto dungeon", startAutoDungeon)
        end)
    end

    if desired.autoPassive and AutoPassive.autoPassiveHasTarget() and #Feature.autoPassiveSelectedUID > 0 then
        Feature.autoPassiveEnabled = true
        setToggleSilently(Feature.autoPassiveToggle, true, function(value)
            Feature.autoPassiveToggleUpdating = value
        end)
        task.spawn(function()
            protectedCall("Start saved auto passive", AutoPassive.startAutoPassive)
        end)
    end
    if desired.autoCollectDrops then
        Feature.autoCollectDropsEnabled = true
        setToggleSilently(Feature.autoCollectDropsToggle, true, function(value)
            Feature.autoCollectDropsToggleUpdating = value
        end)
    end
    if desired.tpPet then
        Feature.tpPetEnabled = true
        setToggleSilently(Feature.tpPetToggle, true, function(value)
            Feature.tpPetToggleUpdating = value
        end)
        Feature.applyTpPet()
    end
    if desired.attackWhileUlt then
        Feature.attackWhileUltEnabled = true
        setToggleSilently(Feature.attackWhileUltToggle, true, function(value)
            Feature.attackWhileUltToggleUpdating = value
        end)
    end
    local gateFarm = Feature.gateFarm
    setToggleSilently(gateFarm.openToggle, false, function(value)
        gateFarm.toggleUpdating = value
    end)
    setToggleSilently(gateFarm.farmToggle, false, function(value)
        gateFarm.toggleUpdating = value
    end)
    gateFarm.openEnabled = false
    gateFarm.farmEnabled = false
    Feature.gateSyncEnabled()
    if type(gateFarm.optionToId) == "table" then
        local wantGate
        for option, id in pairs(gateFarm.optionToId) do
            if id == gateFarm.gateId then
                wantGate = option
                break
            end
        end
        if wantGate and gateFarm.gateDropdown then
            pcall(function()
                gateFarm.gateDropdown:Select(wantGate)
            end)
        end
    end
    selectMapped(gateFarm.teamDropdown, dungeonTeamByOption, gateFarm.teamIndex)
    if gateFarm.amountSlider then
        pcall(function()
            gateFarm.amountSlider:Set(gateFarm.amount)
        end)
    end
    if gateFarm.runsSlider then
        pcall(function()
            gateFarm.runsSlider:Set(gateFarm.maxRuns)
        end)
    end
    if desired.autoGateOpen then
        gateFarm.openEnabled = true
        setToggleSilently(gateFarm.openToggle, true, function(value)
            gateFarm.toggleUpdating = value
        end)
    end
    if desired.autoGateFarm then
        gateFarm.farmEnabled = true
        setToggleSilently(gateFarm.farmToggle, true, function(value)
            gateFarm.toggleUpdating = value
        end)
    end
    if desired.autoGateOpen or desired.autoGateFarm then
        Feature.gateSyncEnabled()
        task.spawn(function()
            protectedCall("Start saved auto gate", Feature.gateStart)
        end)
    end
    Feature.updateMainStatus(true)
    Feature.updateAutoPassiveStatus()
    Feature.fallenStarFarm.updateStatus()
end

local setupStarted = false
local function finishSetup(loadOldConfig)
    if setupStarted then
        return
    end
    setupStarted = true

    if loadOldConfig then
        beginConfigApply()
        protectedCall("Load startup config", loadConfig)
        protectedCall("Rebuild pet dropdown", rebuildPetDropdowns)
        protectedCall("Sync dungeon controls", syncDungeonControls)
        protectedCall("Sync auto farm controls", Feature.syncControls)
    else
        configApplyToken = configApplyToken + 1
        configApplying = false
        configLoaded = true
    end

    protectedCall("Startup pet scan", scanPets)
    protectedCall("Startup machine status", updateMachineStatus)
    protectedCall("Startup dungeon status", updateDungeonCooldownStatus)
    protectedCall("Restore saved feature state", Feature.applySavedState)
    if tostring(getPlayerValue("World", "")) == "Dungeon" and DungeonFarm.enabled then
        dungeonActive = true
        DungeonFarm.entered = true
        protectedCall("Attach existing dungeon farm", DungeonFarm.start)
    end
    controlsReady = true
    if not loadOldConfig then
        protectedCall("Startup config save", function()
            saveConfig(true)
        end)
    end
    protectedCall("Show menu", function()
        setWindowVisible(true)
    end)
    setupReady = true
    if loadOldConfig and configNeedsMigration then
        task.delay(3, function()
            if alive() and setupReady and #getSelectedPetRecords() > 0 then
                if saveConfig(true) then
                    configNeedsMigration = false
                end
            end
        end)
    end

    task.spawn(function()
        while alive() do
            protectedCall("Auto clone loop", function()
                autoStep()
                Feature.step()
                updateMachineStatus()
                Feature.updateStatus()
                updateDungeonCooldownStatus()
                DungeonFarm.updateMapOverlay()
            end)
            task.wait(1)
        end
    end)

    task.spawn(function()
        while alive() do
            protectedCall("Main feature loop", function()
                Feature.mainStep()
            end)
            task.wait(0.1)
        end
    end)

    notifyStatus("AFS", utf8Text("Menu da san sang.", 77, 101, 110, 117, 32, 273, 227, 32, 115, 7861, 110, 32, 115, 224, 110, 103, 46))
end

if fileExists(ConfigPath) then
    setWindowVisible(false)
    WindUI:Popup({
        Title = utf8Text("Tai cau hinh cu?", 84, 7843, 105, 32, 99, 7845, 117, 32, 104, 236, 110, 104, 32, 99, 361, 63),
        Icon = "folder-open",
        Content = utf8Text("Da tim thay cau hinh AFS cu. Ban muon tai lai khong?", 272, 227, 32, 116, 236, 109, 32, 116, 104, 7845, 121, 32, 99, 7845, 117, 32, 104, 236, 110, 104, 32, 65, 70, 83, 32, 99, 361, 46, 32, 66, 7841, 110, 32, 109, 117, 7889, 110, 32, 116, 7843, 105, 32, 108, 7841, 105, 32, 107, 104, 244, 110, 103, 63),
        CanClose = false,
        Buttons = {
            {
                Title = utf8Text("Tai cau hinh", 84, 7843, 105, 32, 99, 7845, 117, 32, 104, 236, 110, 104),
                Icon = "download",
                Variant = "Primary",
                Callback = function()
                    finishSetup(true)
                end
            },
            {
                Title = utf8Text("Bat dau moi", 66, 7855, 116, 32, 273, 7847, 117, 32, 109, 7899, 105),
                Icon = "rotate-ccw",
                Variant = "Tertiary",
                Callback = function()
                    finishSetup(false)
                end
            }
        }
    })
else
    finishSetup(false)
end
