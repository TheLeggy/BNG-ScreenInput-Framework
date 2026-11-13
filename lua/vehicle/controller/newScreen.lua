-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- universal screen controller for interactive HTML displays
-- uses effectively the same structure as the base game HTML texture system
-- integrated specifically with screenInput framework

-- to add your own features, I recommend copying this file to a local vehicle folder

local M = {}
M.type = "auxiliary"

local htmlTexture = require("htmlTexture")

local updateFPS = 90
local dataUpdateInterval = 1 / 24
local unitDefaults = {
    uiUnitLength = "metric",
    uiUnitTemperature = "c",
    uiUnitWeight = "kg",
    uiUnitTorque = "metric",
    uiUnitPower = "hp",
    uiUnitEnergy = "metric",
    uiUnitConsumptionRate = "metric",
    uiUnitVolume = "l",
    uiUnitPressure = "bar",
    uiUnitDate = "ger"
}

local configureScreenCommand = "if screenService and screenService.configureScreen then " ..
                                   "screenService.configureScreen(%q, {width = %s, height = %s}) end"

local controllerName = nil
local htmlTextureInstance = nil
local dataTimer = 0
local screenData = {
    electrics = {},
    powertrain = {},
    customModules = {}
}

local electricsConfig
local powertrainConfig
local customModuleConfig

local pendingSubscription = nil
local pendingMode = nil
local modePendingFlush = false

local electricsUpdate = nop
local powertrainUpdate = nop
local customModuleUpdate = nop

local function updateElectricsData()
    local values = electrics.values
    local data = screenData.electrics
    for i = 1, #electricsConfig do
        local name = electricsConfig[i]
        data[name] = values[name] or 0
    end
end

local function updatePowertrainData()
    for _, entry in ipairs(powertrainConfig) do
        local data = screenData.powertrain[entry.name]
        for _, property in ipairs(entry.properties) do
            data[property] = entry.device[property] or 0
        end
    end
end

local function updateCustomModuleData(dt)
    for _, entry in ipairs(customModuleConfig) do
        entry.controller.updateGaugeData(screenData.customModules[entry.name], dt)
    end
end

local function updateGFX(dt)
    dataTimer = dataTimer + dt
    if not htmlTextureInstance or not playerInfo.anyPlayerSeated or dataTimer < dataUpdateInterval then
        return
    end
    -- a long wait must not come back as a burst of updates
    dataTimer = dataTimer % dataUpdateInterval

    if modePendingFlush then
        if pendingMode then
            htmlTextureInstance:callJS("updateMode", pendingMode)
        end
        modePendingFlush = false
    end

    electricsUpdate(dt)
    powertrainUpdate(dt)
    customModuleUpdate(dt)
    htmlTextureInstance:callJS("updateData", screenData)
end

local function setupElectricsData(config)
    if not config then
        return
    end

    electricsConfig = {}
    for _, name in pairs(config) do
        table.insert(electricsConfig, name)
    end
    electricsUpdate = updateElectricsData
end

local function setupPowertrainData(config)
    if not config then
        return
    end

    local propertiesByDevice = {}
    for _, row in pairs(tableFromHeaderTable(config)) do
        propertiesByDevice[row.deviceName] = propertiesByDevice[row.deviceName] or {}
        table.insert(propertiesByDevice[row.deviceName], row.property)
    end

    powertrainConfig = {}
    for deviceName, properties in pairs(propertiesByDevice) do
        local device = powertrain.getDevice(deviceName)
        if device then
            table.insert(powertrainConfig, {device = device, name = deviceName, properties = properties})
            screenData.powertrain[deviceName] = {}
        end
    end
    powertrainUpdate = updatePowertrainData
end

local function setupCustomModuleData(config)
    if not config then
        return
    end

    local propertiesByModule = {}
    for _, row in pairs(tableFromHeaderTable(config)) do
        propertiesByModule[row.moduleName] = propertiesByModule[row.moduleName] or {}
        if row.property then
            propertiesByModule[row.moduleName][row.property] = true
        end
    end

    customModuleConfig = {}
    for moduleName, properties in pairs(propertiesByModule) do
        local module = controller.getController("gauges/customModules/" .. moduleName)
        if module and module.setupGaugeData and module.updateGaugeData then
            module.setupGaugeData(properties, htmlTextureInstance)
            table.insert(customModuleConfig, {controller = module, name = moduleName, properties = properties})
            screenData.customModules[moduleName] = {}
        else
            log("E", "newScreen.setupCustomModuleData", "Can't find controller: " .. moduleName)
        end
    end
    customModuleUpdate = updateCustomModuleData
end

local function subscribeData(sub)
    -- every screen hears every subscription
    if sub.screenId and sub.screenId ~= controllerName then
        return
    end
    if not htmlTextureInstance then
        -- dont actually know if we need this but here just in case it goes to shit
        pendingSubscription = sub
        return
    end
    if sub.electrics then
        setupElectricsData(sub.electrics)
        screenData.electrics = {}
    end
    if sub.powertrain then
        setupPowertrainData(sub.powertrain)
    end
    if sub.customModules then
        setupCustomModuleData(sub.customModules)
    end
end

local function init(jbeamData)
    controllerName = jbeamData.screenId or jbeamData.name
end

local function logSetupError(problem)
    log("E", "newScreen.initSecondStage",
        "*** SCREENINPUT ERROR *** " .. problem .. " for screen '" .. tostring(controllerName) .. "'")
end

local function initSecondStage(jbeamData)
    local screenName, htmlPath, width, height
    if jbeamData.htmlPath ~= nil then
        screenName = jbeamData.screenId and "@" .. jbeamData.screenId
        htmlPath = "local://local/" .. jbeamData.htmlPath
        width = jbeamData.displayWidth
        height = jbeamData.displayHeight
    else
        -- Legacy format with nested configuration block
        local configData = jbeamData.configuration or {}
        for k, v in pairs(jbeamData) do
            if k:sub(1, #"configuration_") == "configuration_" then
                tableMergeRecursive(configData, v)
            end
        end
        screenName = configData.materialName
        htmlPath = configData.htmlPath
        width = configData.displayWidth
        height = configData.displayHeight
    end

    if not width then
        logSetupError("displayWidth missing from jbeam")
        return
    end
    if not height then
        logSetupError("displayHeight missing from jbeam")
        return
    end
    if not screenName then
        logSetupError("no material name (screenId)")
        return
    end
    if not htmlPath then
        logSetupError("no htmlPath")
        return
    end

    htmlTextureInstance = htmlTexture.new(screenName, htmlPath, width, height, updateFPS)

    if screenInput then
        screenInput.addScreen(htmlTextureInstance)
        screenInput.registerLuaCallback("subscribeData", subscribeData)
    end

    local displayData = jbeamData.displayData or {}
    setupElectricsData(displayData.electrics)
    setupPowertrainData(displayData.powertrain)
    setupCustomModuleData(displayData.customModules)

    if pendingSubscription then
        subscribeData(pendingSubscription)
        pendingSubscription = nil
    end

    local config = {
        screenId = controllerName,
        displayWidth = width,
        displayHeight = height
    }
    for setting, default in pairs(unitDefaults) do
        config[setting] = settings.getValue(setting) or default
    end
    htmlTextureInstance:callJS("setup", config)

    -- the page can miss a mode that arrives this early
    modePendingFlush = true

    obj:queueGameEngineLua(string.format(configureScreenCommand, controllerName, width, height))
end

-- the game reruns both init stages on every vehicle reset for a controller without a reset
local function reset()
end

local function setParameters(parameters)
    if htmlTextureInstance and parameters.modeName and parameters.modeColor then
        pendingMode = parameters
        htmlTextureInstance:callJS("updateMode", parameters)
    end
end

M.init = init
M.initSecondStage = initSecondStage
M.reset = reset
M.updateGFX = updateGFX
M.setParameters = setParameters
M.subscribeData = subscribeData

return M

-- mrow~
