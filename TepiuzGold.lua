local addonName = ...
local db
local currentKey, currentName, currentRealm
local currentRaceAtlas
local characterSetting
local backpackHooked = false
local playerInWorld = false

local function InitializeDatabase()
    if type(TepiuzGoldDB) ~= "table" then
        TepiuzGoldDB = { version = 1, characters = {} }
    end

    db = TepiuzGoldDB
    db.version = db.version or 1
    if type(db.characters) ~= "table" then
        db.characters = {}
    end
end

local function UpdateMoney()
    -- After leaving the world, GetMoney can return a teardown-time zero.
    if not db or not currentKey or not playerInWorld or not UnitExists("player") then
        return
    end

    local character = db.characters[currentKey]
    if not character then
        character = {}
        db.characters[currentKey] = character
    end

    character.name = currentName
    character.realm = currentRealm
    character.raceAtlas = currentRaceAtlas
    character.money = GetMoney()
    character.lastUpdated = GetServerTime()
end

local function GetPlayerRaceAtlas()
    local _, race = UnitRace("player")
    local sex = UnitSex("player")
    if not race or (sex ~= 2 and sex ~= 3) then
        return
    end

    local atlas = GetRaceAtlas(race:lower(), sex == 3 and "female" or "male", true)
    if C_Texture.GetAtlasInfo(atlas) then
        return atlas
    end
end

local function ClearStorage()
    wipe(db.characters)
    UpdateMoney()
    characterSetting:SetValue("")
end

local function FormatMoney(copper)
    return C_CurrencyInfo.GetCoinTextureString(copper)
end

local function GetCharacterList()
    local characters, nameCounts = {}, {}
    local total = 0

    for key, character in pairs(db.characters) do
        characters[#characters + 1] = { key = key, character = character }
        nameCounts[character.name] = (nameCounts[character.name] or 0) + 1
        total = total + character.money
    end

    table.sort(characters, function(a, b)
        if a.key == currentKey or b.key == currentKey then
            return a.key == currentKey and b.key ~= currentKey
        end

        local aName, bName = a.character.name:lower(), b.character.name:lower()
        if aName ~= bName then
            return aName < bName
        end
        return a.key < b.key
    end)

    return characters, nameCounts, total
end

local function GetCharacterLabel(character, nameCounts)
    if nameCounts[character.name] > 1 then
        return character.name .. " - " .. character.realm
    end
    return character.name
end

local function RegisterSettings()
    local category, layout = Settings.RegisterVerticalLayoutCategory("Tepiuz Gold")
    local selectedKey = ""
    characterSetting = Settings.RegisterProxySetting(category, "TepiuzGold_SelectedCharacter",
        Settings.VarType.String, "Character", "",
        function() return selectedKey end,
        function(value) selectedKey = value end)

    local function GetOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add("", "Select a character")
        local characters, nameCounts = GetCharacterList()
        for _, entry in ipairs(characters) do
            local label = GetCharacterLabel(entry.character, nameCounts)
            if entry.key == currentKey then
                label = label .. " (current)"
            end
            container:Add(entry.key, label)
        end
        return container:GetData()
    end

    local dropdown = Settings.CreateDropdown(category, characterSetting, GetOptions,
        "Choose a stored character to delete. The current character is tracked automatically and cannot be deleted here.")
    local function CanDeleteSelected()
        local key = characterSetting:GetValue()
        return key ~= "" and key ~= currentKey and db.characters[key] ~= nil
    end

    local deleteButton = CreateSettingsButtonInitializer("Selected character", "Delete selected", function()
        if not CanDeleteSelected() then
            return
        end
        local key = characterSetting:GetValue()
        local character = db.characters[key]
        StaticPopup_ShowGenericConfirmation(
            ("Delete the stored balance for %s (%s)? It will be recorded again if you log into this character.")
                :format(character.name, character.realm),
            function()
                -- Confirm the original selection even if the dropdown changed while the dialog was open.
                if key ~= currentKey and db.characters[key] == character then
                    db.characters[key] = nil
                end
                characterSetting:SetValue("")
            end)
    end, "Remove only the selected character's stored balance.", true)
    deleteButton:SetParentInitializer(dropdown, CanDeleteSelected)
    layout:AddInitializer(deleteButton)

    local clearButton = CreateSettingsButtonInitializer("Stored characters", "Clear storage", function()
        StaticPopup_ShowGenericConfirmation(
            "Clear all Tepiuz Gold character balances? Your current character will be recorded again immediately.",
            ClearStorage)
    end, "Forget all stored characters. Your current character is recorded again immediately; others return when you log into them.", true)
    layout:AddInitializer(clearButton)
    Settings.RegisterAddOnCategory(category)
end

local function AppendGoldTooltip(button)
    if not currentKey or KeybindFrames_InQuickKeybindMode()
        or not GameTooltip:IsOwned(button) or not GameTooltip:IsShown() then
        return
    end

    UpdateMoney()
    local characters, nameCounts, total = GetCharacterList()
    local normal, highlight = NORMAL_FONT_COLOR, HIGHLIGHT_FONT_COLOR

    GameTooltip:AddLine(" ")

    for _, entry in ipairs(characters) do
        local character = entry.character
        local label = GetCharacterLabel(character, nameCounts)
        if character.raceAtlas and C_Texture.GetAtlasInfo(character.raceAtlas) then
            label = CreateAtlasMarkup(character.raceAtlas, 14, 14) .. " " .. label
        end

        local color = entry.key == currentKey and normal or highlight
        GameTooltip:AddDoubleLine(label, FormatMoney(character.money),
            color.r, color.g, color.b, highlight.r, highlight.g, highlight.b)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Total", FormatMoney(total),
        normal.r, normal.g, normal.b, highlight.r, highlight.g, highlight.b)
    GameTooltip:Show()
end

local function HookBackpack()
    if backpackHooked or not MainMenuBarBackpackButton then
        return
    end

    -- Hook the frame's copied method after Blizzard has built its tooltip.
    hooksecurefunc(MainMenuBarBackpackButton, "OnEnterInternal", AppendGoldTooltip)
    backpackHooked = true
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= addonName then
            return
        end
        InitializeDatabase()
        RegisterSettings()
        self:UnregisterEvent("ADDON_LOADED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("PLAYER_LEAVING_WORLD")
        self:RegisterEvent("PLAYER_MONEY")
        self:RegisterEvent("PLAYER_LOGOUT")
    elseif event == "PLAYER_ENTERING_WORLD" then
        currentName = NameUtil.GetUnmodifiedUnitFullName("player")
        currentRealm = GetRealmName()
        currentKey = currentRealm .. ":" .. currentName
        currentRaceAtlas = GetPlayerRaceAtlas()

        -- Upgrade this character's earlier first-name-only entry without double counting it.
        local firstName = UnitNameUnmodified("player")
        local legacyKey = currentRealm .. ":" .. firstName
        local legacyCharacter = db.characters[legacyKey]
        if legacyKey ~= currentKey and legacyCharacter and legacyCharacter.name == firstName then
            db.characters[currentKey] = db.characters[currentKey] or legacyCharacter
            db.characters[legacyKey] = nil
        end

        playerInWorld = true
        UpdateMoney()
        characterSetting:NotifyUpdate()
        HookBackpack()
    elseif event == "PLAYER_LEAVING_WORLD" then
        playerInWorld = false
    elseif event == "PLAYER_MONEY" or event == "PLAYER_LOGOUT" then
        UpdateMoney()
    end
end)
