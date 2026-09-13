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
end)
local globalEnv = getgenv()
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
local dungeonTeamDropdown
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
    goldDoorsOpened = {},
    goldRoomsOpened = {},
    completedChests = {},
    teamApplied = false,
    teamApplying = false,
    teleportDistance = 120,
    flySpeed = 140,
    teleportDistanceSlider = nil,
    flySpeedSlider = nil,
    startedAt = 0,
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
    secondArtifact = ""
}
local scanPets
local rebuildPetDropdowns
local selectedCount
local syncDungeonControls

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
                autoPassive = Feature.autoPassiveEnabled
            },
            autoFarm = {
                mode = Feature.autoFarmMode
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
            autoPassive = data.features.autoPassive == true
        }
    end
    if type(data.autoFarm) == "table" then
        local mode = data.autoFarm.mode
        if mode == Feature.MODE_LOWEST_HEALTH or mode == Feature.MODE_HIGHEST_HEALTH then
            Feature.autoFarmMode = mode
        else
            Feature.autoFarmMode = Feature.MODE_NEAREST
        end
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

    if type(data.dungeonSelection) == "table" then
        for key, value in pairs(data.dungeonSelection) do
            if dungeonSelection[key] ~= nil and type(value) == type(dungeonSelection[key]) then
                dungeonSelection[key] = value
            end
        end
    end
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

Feature.rebuildAutoPassivePetDropdown = function()
    beginDropdownSync()
    AutoPassive.resolvePendingAutoPassiveSelection()
    AutoPassiveMaps.optionToUID = {}
    AutoPassiveMaps.optionByUID = {}

    local values = {}
    for _, pet in ipairs(AutoPassive.getPassivePets()) do
        local option = string.format(
            "%s | Lv.%s | UID:%s",
            petDisplayName(pet),
            tostring(pet.Level or "?"),
            tostring(pet.UID)
        )
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
    pcall(function()
        character:PivotTo(CFrame.new(pivot.Position + Vector3.new(0, 4, 0)))
    end)
    task.wait(0.35)
    return true
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

    return true
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
    local health = healthValue and tonumber(healthValue.Value)
    local maxHealth = maxHealthValue and tonumber(maxHealthValue.Value)
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
    if not Feature.autoFarmEnabled or dungeonActive then
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

local function applyEquippedPets(desired)
    local current = getStoreTable("EquippedPets", true)
    local amount = 0
    pcall(function()
        amount = tonumber(GetMultiplier.EquipAmount(LocalPlayer)) or 0
    end)
    local localData = getStoreTable("EquippedPets")
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

    local function matchesTarget()
        local actual = getStoreTable("EquippedPets", true)
        for slot = 1, amount do
            if tostring(slotValue(actual, slot) or "") ~= tostring(target[slot] or "") then
                return false
            end
        end
        return true
    end

    local function sendChanges()
        local actual = getStoreTable("EquippedPets", true)
        local changed = false

        for slot = 1, amount do
            local oldUID = slotValue(actual, slot)
            local newUID = target[slot]
            if tostring(oldUID or "") ~= tostring(newUID or "") and oldUID then
                protectedCall("Unequip dungeon pet", function()
                    ManagePet:FireServer(oldUID, "Unequip")
                end)
                changed = true
                task.wait(0.08)
            end
        end

        for slot = 1, amount do
            local oldUID = slotValue(actual, slot)
            local newUID = target[slot]
            if newUID and tostring(oldUID or "") ~= tostring(newUID) then
                protectedCall("Equip dungeon pet", function()
                    ManagePet:FireServer(newUID, "Equip", slot)
                end)
                changed = true
                task.wait(0.08)
            end
        end
        return changed
    end

    for _ = 1, 3 do
        sendChanges()
        if matchesTarget() then
            localData = getStoreTable("EquippedPets", true)
            setStoreValue("EquippedPets", localData, 2)
            return true
        end
        task.wait(0.35)
    end

    for slot = 1, amount do
        localData[tostring(slot)] = target[slot] or nil
    end
    setStoreValue("EquippedPets", localData, 2)
    task.wait(0.35)
    if matchesTarget() then
        return true
    end
    return false, "Team pet chua dong bo du so luong equip."
end

local function applyDungeonTeam(index)
    local team = getStoreTable("PetTeams", true)[index]
    if type(team) ~= "table" then
        return false, "Khong tim thay team dungeon."
    end
    local applied, reason = applyEquippedPets(team.UIDs or {})
    if not applied then
        return false, reason
    end
    return team
end

local function applyDungeonTitle(title)
    title = cleanText(title)
    protectedCall("Change title", function()
        ChangeTitle:FireServer(title == "" and "Unequip" or title)
    end)
    setStoreValue("CurrentTitle", title, 2)
end

local function applyDungeonAvatar(avatar)
    avatar = cleanText(avatar)
    protectedCall("Equip avatar", function()
        AttemptAvatarEquip:InvokeServer(avatar)
    end)
    setStoreValue("CurrentAvatar", avatar, 2)
end

local function applyDungeonAura(aura)
    aura = cleanText(aura)
    protectedCall("Equip aura", function()
        EquipAura:FireServer(aura)
    end)
    setStoreValue("CurrentAura", aura, 2)
end

local function applyDungeonArtifact(artifact, slot)
    artifact = cleanText(artifact)
    protectedCall("Equip artefact", function()
        EquipArtefact:FireServer(artifact, slot)
    end)
    setStoreValue(slot, artifact, 1)
end

local function applyDungeonLoadout(loadout)
    if type(loadout) ~= "table" then
        return
    end

    local avatar = loadout.Avatar
    if type(avatar) == "string" and avatar ~= "" then
        applyDungeonAvatar(avatar)
    end

    local aura = loadout.Aura
    if type(aura) == "string" then
        protectedCall("Equip team aura", function()
            EquipAura:FireServer(aura)
        end)
        setStoreValue("CurrentAura", aura, 2)
    end

    local title = loadout.Title
    if type(title) == "string" then
        applyDungeonTitle(title)
    end

    local artifact = loadout.Artefact
    if type(artifact) == "string" then
        applyDungeonArtifact(artifact, "CurrentArtefact")
    end

    local secondArtifact = loadout.SecondArtefact
    if type(secondArtifact) == "string" then
        applyDungeonArtifact(secondArtifact, "CurrentSecondArtefact")
    end
end

function DungeonFarm.ensureTeamApplied()
    if DungeonFarm.teamApplied then
        return true
    end
    if DungeonFarm.teamApplying then
        local deadline = os.clock() + 10
        while alive() and DungeonFarm.teamApplying and os.clock() < deadline do
            task.wait(0.1)
        end
        return DungeonFarm.teamApplied
    end

    DungeonFarm.teamApplying = true
    local ok, team = protectedCall("Apply dungeon team", function()
        return applyDungeonTeam(dungeonSelection.teamIndex)
    end)
    if ok and team then
        protectedCall("Apply dungeon team loadout", function()
            applyDungeonLoadout(team.Loadout)
        end)
        DungeonFarm.teamApplied = true
        DungeonFarm.lastMessage = "Da doi sang team dungeon sau khi vao map."
    end
    DungeonFarm.teamApplying = false
    return DungeonFarm.teamApplied
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

function DungeonFarm.getActiveDungeonInfo()
    local worlds = workspace:FindFirstChild("Worlds")
    local dungeon = worlds and worlds:FindFirstChild("Dungeon")
    if dungeon and dungeon:GetAttribute("Active") then
        local ownerValue = dungeon:FindFirstChild("FriendsWithUserId")
        local ownerId = ownerValue and tonumber(ownerValue.Value) or 0
        return dungeon, ownerId
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

function DungeonFarm.findPrompt(dungeon)
    local map = dungeon and dungeon:FindFirstChild("Map")
    if not map then
        return nil
    end

    for _, object in ipairs(map:GetDescendants()) do
        if object:IsA("ProximityPrompt") and object.Enabled then
            local part = object.Parent
            local room = part and part.Parent
            if part and part.Name == "ConfirmPart"
                and room and room:IsA("Model")
                and room:GetAttribute("MapPos") ~= nil then
                local key = room:GetFullName()
                if not DungeonFarm.completed[key] then
                    return object, room, part, key
                end
            end
        end
    end
    return nil
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

function DungeonFarm.findGoldDoor(dungeon)
    local map = dungeon and dungeon:FindFirstChild("Map")
    if not map then
        return nil
    end

    for _, object in ipairs(map:GetDescendants()) do
        if object:IsA("ProximityPrompt") and object.Enabled then
            local info = DungeonFarm.getDoorInfo(object, map)
            if info and info.roomKey
                and DungeonFarm.completed[info.roomKey]
                and not DungeonFarm.goldDoorsOpened[info.key] then
                return object, info.door, info.room, info.key, info.roomKey
            end
        end
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

function DungeonFarm.getChestTargets(dungeon)
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
        if not room
            or not DungeonFarm.completed[room:GetFullName()]
            or DungeonFarm.roomHasPendingGoldDoor(room) then
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

function DungeonFarm.clearEnemies(dungeon, token)
    local enemies = dungeon and dungeon:FindFirstChild("Enemies")
    local sendEvent = Bindable:FindFirstChild("SendPet")
    if not enemies then
        return false, "Khong tim thay folder Enemies."
    end
    if not sendEvent then
        return false, "Bindable.SendPet khong ton tai."
    end

    local function isLiveEnemy(enemy)
        if not (enemy and enemy.Parent == enemies and enemy:IsA("Model")) then
            return false
        end
        local health = Feature.getHealth(enemy)
        return health == nil or health > 0
    end

    local function getLiveEnemies()
        local result = {}
        for _, enemy in ipairs(enemies:GetChildren()) do
            if isLiveEnemy(enemy) then
                table.insert(result, enemy)
            end
        end
        return result
    end

    local function sendToEnemy(enemy)
        local ok, err = pcall(function()
            sendEvent:Fire(enemy, true, true)
        end)
        if not ok then
            return false, "Gui pet loi: " .. tostring(err)
        end
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

        local enemyList = getLiveEnemies()
        if #enemyList == 0 then
            DungeonFarm.lastEnemyCount = 0
            return true, "Da clear enemy."
        end

        -- Hold one target until it dies so movement never skips ahead to another enemy.
        local enemy = enemyList[1]
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
        while isLiveEnemy(enemy) do
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
            if os.clock() - lastSend >= 1 then
                local ok, reason = sendToEnemy(enemy)
                if not ok then
                    return false, reason
                end
                lastSend = os.clock()
            end

            local remaining = #getLiveEnemies()
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

        DungeonFarm.lastEnemyCount = #getLiveEnemies()
        DungeonFarm.updateStatus(
            "Dungeon Farm: COMBAT",
            string.format(
                "Room %s | Da ha %s | Con %d enemy",
                tostring(DungeonFarm.room or "?"),
                tostring(enemy.Name),
                DungeonFarm.lastEnemyCount
            )
        )
        task.wait(0.15)
    end

    if not enemies.Parent then
        DungeonFarm.lastEnemyCount = 0
        return true, "Da clear enemy."
    end
    return false, "Folder Enemies da bi dong khi dang combat."
end

function DungeonFarm.clearChests(dungeon, token)
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

        local chests = DungeonFarm.getChestTargets(dungeon)
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
        return false, "Thieu du lieu cua gold door."
    end
    local key = door:GetFullName()
    DungeonFarm.phase = "opening_door"
    DungeonFarm.updateStatus("Dungeon Farm: GOLD DOOR", "Dang bay toi cua vang trong room " .. tostring(room.Name) .. "...")
    if not DungeonFarm.flyTo(door, token) then
        return false, "Fly toi cua vang " .. tostring(room.Name) .. " that bai."
    end

    local ok, err = pcall(function()
        if type(fireproximityprompt) ~= "function" then
            error("fireproximityprompt khong ton tai trong executor.")
        end
        fireproximityprompt(prompt)
    end)
    if not ok then
        return false, "Instant interaction cua vang loi: " .. tostring(err)
    end

    local deadline = os.clock() + 20
    while alive() and token == DungeonFarm.token and DungeonFarm.enabled do
        if not prompt.Parent or not prompt.Enabled then
            DungeonFarm.goldDoorsOpened[key] = true
            DungeonFarm.goldRoomsOpened[room:GetFullName()] = true
            return true, "Da mo cua vang."
        end
        if os.clock() >= deadline then
            break
        end
        task.wait(0.25)
    end
    return false, "Cua vang " .. tostring(room.Name) .. " khong doi trang thai sau khi active."
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
    if not DungeonFarm.enabled or not dungeonActive then
        return
    end
    if not DungeonFarm.entered or DungeonFarm.running then
        return
    end

    DungeonFarm.token = DungeonFarm.token + 1
    local token = DungeonFarm.token
    DungeonFarm.running = true
    DungeonFarm.phase = "searching"
    DungeonFarm.room = nil
    DungeonFarm.targetRoom = nil
    DungeonFarm.targetPart = nil
    DungeonFarm.activationAt = 0
    DungeonFarm.lastEnemyCount = 0
    DungeonFarm.completed = {}
    DungeonFarm.attempts = {}
    DungeonFarm.goldDoorsOpened = {}
    DungeonFarm.goldRoomsOpened = {}
    DungeonFarm.completedChests = {}
    DungeonFarm.startedAt = os.clock()
    DungeonFarm.lastMessage = "Dang tim ConfirmPart active."

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
                local enemies = dungeon:FindFirstChild("Enemies")
                if enemies and #enemies:GetChildren() > 0 then
                    DungeonFarm.phase = "combat"
                    local ok, reason = DungeonFarm.clearEnemies(dungeon, token)
                    if not ok then
                        DungeonFarm.fail(reason, token)
                        return
                    end
                else
                    local chests = DungeonFarm.getChestTargets(dungeon)
                    if #chests > 0 then
                        DungeonFarm.phase = "chest"
                        local ok, reason = DungeonFarm.clearChests(dungeon, token)
                        if not ok then
                            DungeonFarm.fail(reason, token)
                            return
                        end
                    else
                        local doorPrompt, doorPart, doorRoom = DungeonFarm.findGoldDoor(dungeon)
                        if doorPrompt then
                            local ok, reason = DungeonFarm.openGoldDoor(doorPrompt, doorPart, doorRoom, token)
                            if not ok then
                                DungeonFarm.fail(reason, token)
                                return
                            end
                            task.wait(0.5)
                        else
                            local prompt, room, part, key = DungeonFarm.findPrompt(dungeon)
                            if not prompt then
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
                                    if enemies and #enemies:GetChildren() > 0 then
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

                                if enemies and #enemies:GetChildren() > 0 then
                                    DungeonFarm.phase = "combat"
                                    local ok, reason = DungeonFarm.clearEnemies(dungeon, token)
                                    if not ok then
                                        DungeonFarm.fail(reason, token)
                                        return
                                    end
                                end

                                DungeonFarm.completed[key] = true
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

local function restoreDungeonSession(reason)
    local session = dungeonSession
    if not session or session.restoring then
        return
    end
    session.restoring = true
    dungeonActive = false
    Feature.autoDungeonEnabled = false
    DungeonFarm.token = DungeonFarm.token + 1
    DungeonFarm.running = false
    DungeonFarm.entered = false
    DungeonFarm.phase = "idle"
    DungeonFarm.room = nil
    DungeonFarm.targetRoom = nil
    DungeonFarm.targetPart = nil
    DungeonFarm.activationAt = 0
    DungeonFarm.lastEnemyCount = 0
    DungeonFarm.completed = {}
    DungeonFarm.attempts = {}
    DungeonFarm.goldDoorsOpened = {}
    DungeonFarm.goldRoomsOpened = {}
    DungeonFarm.completedChests = {}
    DungeonFarm.teamApplied = false
    DungeonFarm.teamApplying = false
    DungeonFarm.lastMessage = reason or "Da khoi phuc cau hinh"
    DungeonFarm.updateStatus("Dungeon Farm: SAN SANG", DungeonFarm.lastMessage)
    dungeonWaiting = false
    dungeonWaitToken = dungeonWaitToken + 1
    if dungeonToggle then
        dungeonToggleUpdating = true
        pcall(function()
            dungeonToggle:Set(false)
        end)
        dungeonToggleUpdating = false
    end
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
            applyEquippedPets(session.equippedPets)
            applyDungeonTitle(session.title)
            applyDungeonAvatar(session.avatar)
            applyDungeonAura(session.aura)
            applyDungeonArtifact(session.artifact, "CurrentArtefact")
            applyDungeonArtifact(session.secondArtifact, "CurrentSecondArtefact")
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
        end)
    end)
end

DungeonFarm.restore = restoreDungeonSession

local function startAutoDungeon()
    if tostring(getPlayerValue("World", "")) == "Dungeon" then
        dungeonActive = true
        if not DungeonFarm.ensureTeamApplied() then
            DungeonFarm.updateStatus("Dungeon Farm: LOI", "Khong doi duoc team dungeon.")
            return
        end
        DungeonFarm.entered = true
        if DungeonFarm.enabled then
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

    dungeonSession = {
        location = captureLocation(),
        equippedPets = copyEquippedPets(),
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
    DungeonFarm.phase = "starting"
    DungeonFarm.room = nil
    DungeonFarm.targetRoom = nil
    DungeonFarm.targetPart = nil
    DungeonFarm.lastEnemyCount = 0
    DungeonFarm.completed = {}
    DungeonFarm.attempts = {}
    DungeonFarm.goldDoorsOpened = {}
    DungeonFarm.goldRoomsOpened = {}
    DungeonFarm.completedChests = {}
    DungeonFarm.teamApplied = false
    DungeonFarm.teamApplying = false
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
        for _ = 1, 480 do
            if not alive() or not dungeonActive then
                return
            end
            local checkOK, arrived = protectedCall("Check dungeon travel", function()
                return tostring(getPlayerValue("World", "")) == "Dungeon"
            end)
            if checkOK and arrived then
                DungeonFarm.updateStatus("Dungeon Farm: TEAM", "Da vao dungeon; dang doi team da cai dat...")
                if not DungeonFarm.ensureTeamApplied() then
                    DungeonFarm.fail("Khong doi duoc team dungeon sau khi vao map.")
                    return
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
                DungeonFarm.phase = "waiting_activation"
                DungeonFarm.updateStatus(
                    "Dungeon Farm: CHO MO",
                    "Dang cho Dungeon.Active bat truoc khi teleport..."
                )
                task.wait(0.25)
                continue
            end

            if not activeSeen then
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

dungeonFinishConnection = DungeonFinish.OnClientEvent:Connect(function()
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
                    dungeonActive = false
                    DungeonFarm.teamApplied = false
                    DungeonFarm.teamApplying = false
                    DungeonFarm.phase = "idle"
                    DungeonFarm.updateStatus("Dungeon Farm: SAN SANG", "Dungeon da hoan tat.")
                end
            end
        end)
    end
end)

local worldValue = LocalPlayer:FindFirstChild("World") or LocalPlayer:WaitForChild("World", 10)
local dungeonWorldConnection
if worldValue then
    dungeonWorldConnection = worldValue.Changed:Connect(function(value)
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
                        if DungeonFarm.ensureTeamApplied() then
                            DungeonFarm.start()
                        else
                            DungeonFarm.updateStatus("Dungeon Farm: LOI", "Khong doi duoc team dungeon.")
                        end
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
                        dungeonActive = false
                        DungeonFarm.teamApplied = false
                        DungeonFarm.teamApplying = false
                        DungeonFarm.phase = "idle"
                        DungeonFarm.updateStatus("Dungeon Farm: SAN SANG", "Da roi khoi dungeon.")
                    end
                end
            end)
        end
    end)
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
    if not configLoaded
        or type(dungeonSelection.teamIndex) ~= "number"
        or dungeonSelection.teamIndex < 1
        or dungeonSelection.teamIndex > teamCount then
        dungeonSelection.teamIndex = getDungeonDefaultTeam()
    end
    local defaultTeam
    for option, index in pairs(dungeonTeamByOption) do
        if index == dungeonSelection.teamIndex then
            defaultTeam = option
            break
        end
    end

    local artifacts = makeDungeonArtifactOptions()
    local artifactOptions = {}
    for option, id in pairs(dungeonArtifactByOption) do
        if id == dungeonSelection.secondArtifact then artifactOptions[2] = option end
    end
    DungeonTab:Paragraph({
        Title = "Auto Dungeon",
        Desc = "Chon map, mode, kich thuoc va team. Artifact Passage luon duoc dung de mo dungeon; sau khi vao map moi doi sang team da chon."
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
    dungeonTeamDropdown = DungeonTab:Dropdown({
        Title = utf8Text("Doi hinh", 272, 7897, 105, 32, 104, 236, 110, 104),
        Values = teams,
        Value = defaultTeam,
        SearchBarEnabled = true,
        MenuWidth = 300,
        Callback = function(value)
            dungeonSelection.teamIndex = dungeonTeamByOption[value] or dungeonSelection.teamIndex
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
        Title = utf8Text("Bat Auto Dungeon", 66, 7853, 116, 32, 65, 117, 116, 111, 32, 68, 117, 110, 103, 101, 111, 110),
        Desc = utf8Text("Chay dungeon voi cau hinh da chon", 67, 104, 7841, 121, 32, 100, 117, 110, 103, 101, 111, 110, 32, 118, 7899, 105, 32, 99, 7845, 117, 32, 104, 236, 110, 104, 32, 273, 227, 32, 99, 104, 7885, 110),
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
                    dungeonWaiting = false
                    dungeonWaitToken = dungeonWaitToken + 1
                    restoreDungeonSession("Da dung Auto Dungeon")
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
        Title = "Bat Instant Dungeon Farm",
        Desc = "Gan thi teleport; xa thi fly noclip, active room, mo cua vang, clear enemy va chest.",
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
end

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
        controlsReady = false
        beginConfigApply()
        protectedCall("Load config", function()
            if autoEnabled then
                stopAutoAndReturn()
            end
            loadConfig()
            scanPets()
            updateMachineStatus()
            syncDungeonControls()
            Feature.syncControls()
            Feature.applySavedState()
        end)
        controlsReady = true
    end
})

SettingsTab:Button({
    Title = utf8Text("Mo Artefact tu xa", 77, 7903, 32, 65, 114, 116, 101, 102, 97, 99, 116, 32, 116, 7915, 32, 120, 97),
    Desc = utf8Text("Mo bang Artefact ma khong can di chuyen", 77, 7903, 32, 98, 7843, 110, 103, 32, 65, 114, 116, 101, 102, 97, 99, 116, 32, 109, 224, 32, 107, 104, 244, 110, 103, 32, 99, 7847, 110, 32, 100, 105, 32, 99, 104, 117, 121, 7875, 110),
    Callback = function()
        protectedCall("Open artefact GUI", openArtifactGui)
    end
})

protectedCall("Build dungeon controls", buildDungeonControls)
protectedCall("Build auto passive controls", AutoPassive.buildAutoPassiveControls)

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
    selectMapped(dungeonTeamDropdown, dungeonTeamByOption, dungeonSelection.teamIndex)
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
    Feature.autoDungeonEnabled = false
    Feature.autoPassiveEnabled = false
    Feature.autoPassiveRunToken = Feature.autoPassiveRunToken + 1
    Feature.autoFarmTarget = nil
    Feature.autoFarmLastSend = 0
    setToggleSilently(Feature.autoCloneToggle, false, function(value)
        Feature.autoCloneToggleUpdating = value
    end)
    setToggleSilently(Feature.autoFarmToggle, false, function(value)
        Feature.autoFarmToggleUpdating = value
    end)
    setToggleSilently(dungeonToggle, false, function(value)
        dungeonToggleUpdating = value
    end)
    setToggleSilently(Feature.autoPassiveToggle, false, function(value)
        Feature.autoPassiveToggleUpdating = value
    end)
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
    Feature.updateAutoPassiveStatus()
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
            end)
            task.wait(1)
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



