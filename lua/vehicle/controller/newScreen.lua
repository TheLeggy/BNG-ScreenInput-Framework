-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- sneppy snep snep!

-- Be warned (!!!!): using this code means you give
--    away your soul to the snow leopard gods!

-- universal screen controller for interactive HTML displays
-- uses effectively the same structure as the base game HTML texture system
-- integrated specifically with screenInput framework

-- to add your own features, I recommend copying this file to a local vehicle folder

local M = {}
M.type = "auxiliary"

local htmlTexture = require("htmlTexture")

local controllerName = nil
local screenName = nil
local htmlPath = nil
local htmlTextureInstance = nil

local updateTimer = 0
local updateFPS = 90
local screenData = {
    electrics = {},
    powertrain = {},
    customModules = {}
}

local electricsConfig
local powertrainConfig
local customModuleConfig

local pendingSubscription = nil

local electricsUpdate = nop
local powertrainUpdate = nop
local customModuleUpdate = nop

-- Update electrics data
local function updateElectricsData(dt)
    for _, v in ipairs(electricsConfig) do
        screenData.electrics[v] = electrics.values[v] or 0
    end
end

local function updatePowertrainData(dt)
    for _, v in ipairs(powertrainConfig) do
        for _, n in ipairs(v.properties) do
            screenData.powertrain[v.name][n] = v.device[n] or 0
        end
    end
end

local function updateCustomModuleData(dt)
    for _, module in ipairs(customModuleConfig) do
        module.controller.updateGaugeData(screenData.customModules[module.name], dt)
    end
end

-- Main update loop
local function updateGFX(dt)
    updateTimer = updateTimer + dt

    if htmlTextureInstance and playerInfo.anyPlayerSeated and obj:getUpdateUIflag() then
        electricsUpdate(updateTimer)
        powertrainUpdate(updateTimer)
        customModuleUpdate(updateTimer)

        htmlTextureInstance:streamJS("updateData", "updateData", screenData)
        updateTimer = 0
    end
end

-- Setup electrics data sources
local function setupElectricsData(config)
    if not config then
        return
    end
    electricsConfig = {}
    for _, v in pairs(config) do
        table.insert(electricsConfig, v)
    end
    electricsUpdate = updateElectricsData
end

local function setupPowertrainData(config)
    if not config then
        return
    end
    local mergedConfig = {}
    for _, v in pairs(tableFromHeaderTable(config)) do
        mergedConfig[v.deviceName] = mergedConfig[v.deviceName] or {}
        table.insert(mergedConfig[v.deviceName], v.property)
    end

    powertrainConfig = {}
    for k, v in pairs(mergedConfig) do
        local device = powertrain.getDevice(k)
        if device then
            table.insert(powertrainConfig, {device = device, name = k, properties = v})
            screenData.powertrain[k] = {}
        end
    end

    powertrainUpdate = updatePowertrainData
end

local function setupCustomModuleData(config)
    if not config then
        return
    end

    local mergedConfig = {}
    for _, v in pairs(tableFromHeaderTable(config)) do
        mergedConfig[v.moduleName] = mergedConfig[v.moduleName] or {}
        if v.property then
            mergedConfig[v.moduleName][v.property] = true
        end
    end

    customModuleConfig = {}
    for k, v in pairs(mergedConfig) do
        local c = controller.getController("gauges/customModules/" .. k)
        if c and c.setupGaugeData and c.updateGaugeData then
            c.setupGaugeData(v, htmlTextureInstance)
            table.insert(customModuleConfig, {controller = c, name = k, properties = v})
            screenData.customModules[k] = {}
        else
            log("E", "newScreen.setupCustomModuleData", "Can't find controller: " .. k)
        end
    end

    customModuleUpdate = updateCustomModuleData
end

local function subscribeData(sub)
    if not htmlTextureInstance then
        -- dont actually know if we need this but here just in case it goes to shit
        pendingSubscription = sub
        return
    end
    if sub.electrics then
        setupElectricsData(sub.electrics)
        screenData.electrics = {}
    end
end

local function reset()
end

local function init(jbeamData)
    controllerName = jbeamData.screenId or jbeamData.name
end

local function initSecondStage(jbeamData)
    local displayData = jbeamData.displayData or {}

    local width, height
    if jbeamData.htmlPath ~= nil then
        screenName = "@" .. jbeamData.screenId
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
        log("E", "newScreen.initSecondStage", "*** SCREENINPUT ERROR *** displayWidth missing from jbeam for screen '" .. tostring(controllerName) .. "'")
        return
    end
    if not height then
        log("E", "newScreen.initSecondStage", "*** SCREENINPUT ERROR *** displayHeight missing from jbeam for screen '" .. tostring(controllerName) .. "'")
        return
    end

    if not screenName then
        log("E", "newScreen.initSecondStage", "*** SCREENINPUT ERROR *** no material name (screenId) for screen '" .. tostring(controllerName) .. "'")
        return
    end

    if not htmlPath then
        log("E", "newScreen.initSecondStage", "*** SCREENINPUT ERROR *** no htmlPath for screen '" .. tostring(controllerName) .. "'")
        return
    end

    htmlTextureInstance = htmlTexture.new(screenName, htmlPath, width, height, updateFPS)

    if not htmlTextureInstance then
        log("E", "newScreen.initSecondStage", "*** SCREENINPUT ERROR *** htmlTexture.new() failed for screen '" .. tostring(controllerName) .. "'. Material '" .. screenName .. "' may not exist on this mesh. Check screenId in jbeam matches the material name.")
        return
    end

    if screenInput then
        screenInput.addScreen(htmlTextureInstance)
        screenInput.registerLuaCallback("subscribeData", subscribeData)
    end

    setupElectricsData(displayData.electrics)
    setupPowertrainData(displayData.powertrain)
    setupCustomModuleData(displayData.customModules)

    if pendingSubscription then
        subscribeData(pendingSubscription)
        pendingSubscription = nil
    end

    local config = {
        uiUnitLength = settings.getValue("uiUnitLength") or "metric",
        uiUnitTemperature = settings.getValue("uiUnitTemperature") or "c",
        uiUnitWeight = settings.getValue("uiUnitWeight") or "kg",
        uiUnitTorque = settings.getValue("uiUnitTorque") or "metric",
        uiUnitPower = settings.getValue("uiUnitPower") or "hp",
        uiUnitEnergy = settings.getValue("uiUnitEnergy") or "metric",
        uiUnitConsumptionRate = settings.getValue("uiUnitConsumptionRate") or "metric",
        uiUnitVolume = settings.getValue("uiUnitVolume") or "l",
        uiUnitPressure = settings.getValue("uiUnitPressure") or "bar",
        uiUnitDate = settings.getValue("uiUnitDate") or "ger",
        screenId = controllerName,
        displayWidth = width,
        displayHeight = height
    }

    htmlTextureInstance:callJS("setup", config)

    if width and height then
        obj:queueGameEngineLua([[
        if screenService and screenService.configureScreen then
          screenService.configureScreen("]] .. controllerName .. [[", {
            width = ]] .. width .. [[,
            height = ]] .. height .. [[
          })
        end
      ]])
    end
end

local function setUIMode(parameters)
    if htmlTextureInstance then
        htmlTextureInstance:callJS("updateMode", parameters)
    end
end

local function setParameters(parameters)
    if parameters.modeName and parameters.modeColor then
        setUIMode(parameters)
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
