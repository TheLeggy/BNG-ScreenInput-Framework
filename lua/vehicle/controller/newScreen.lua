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

local electricsUpdate = nop
local powertrainUpdate = nop
local customModuleUpdate = nop

-- Update electrics data
local function updateElectricsData(dt)
    for _, v in ipairs(electricsConfig) do
        screenData.electrics[v] = electrics.values[v] or 0
    end
end

-- Update powertrain data
local function updatePowertrainData(dt)
    for _, v in ipairs(powertrainConfig) do
        for _, n in ipairs(v.properties) do
            screenData.powertrain[v.device.name][n] = v.device[n] or 0
        end
    end
end

-- Update custom module data
local function updateCustomModuleData(dt)
    for _, module in ipairs(customModuleConfig) do
        module.controller.updateGaugeData(screenData.customModules[module.name], dt)
    end
end

-- Main update loop
local function updateGFX(dt)
    updateTimer = updateTimer + dt

    if playerInfo.anyPlayerSeated and obj:getUpdateUIflag() then
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

-- Setup powertrain data sources
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
            table.insert(powertrainConfig, {
                device = device,
                properties = v
            })
            screenData.powertrain[k] = {}
        end
    end

    powertrainUpdate = updatePowertrainData
end

-- Setup custom module data sources
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
    local controllerPath = "gauges/customModules/"
    for k, v in pairs(mergedConfig) do
        local c = controller.getController(controllerPath .. k)
        if c and c.setupGaugeData and c.updateGaugeData then
            c.setupGaugeData(v, htmlTextureInstance)
            table.insert(customModuleConfig, {
                controller = c,
                name = k,
                properties = v
            })
            screenData.customModules[k] = {}
        else
            log("E", "newScreen.setupCustomModuleData", "Can't find controller: " .. k)
        end
    end

    customModuleUpdate = updateCustomModuleData
end

local function reset()
end

local function init(jbeamData)
    controllerName = jbeamData.name
end

local function initSecondStage(jbeamData)
    local displayData = jbeamData.displayData

    -- Merge config data from multiple parts so that some things can be defined in sub-parts
    -- Section name needs to be "configuration_xyz"
    local configData = jbeamData.configuration or {}
    for k, v in pairs(jbeamData) do
        if k:sub(1, #"configuration_") == "configuration_" then
            tableMergeRecursive(configData, v)
        end
    end

    if not configData then
        log("E", "newScreen.initSecondStage", "Can't find config data for screen: " .. (screenName or "unknown"))
        return
    end

    screenName = configData.materialName
    htmlPath = configData.htmlPath
    local width = configData.displayWidth
    local height = configData.displayHeight

    if not screenName then
        log("E", "newScreen.initSecondStage", "Got no material name for the texture, can't display anything...")
        return
    else
        if htmlPath then
            htmlTextureInstance = htmlTexture.new(screenName, htmlPath, width, height, updateFPS)

            -- Register with screenInput so it can receive screen input events
            if screenInput then
                screenInput.addScreen(htmlTextureInstance)
            end
        else
            log("E", "newScreen.initSecondStage", "Got no html path for the texture, can't display anything...")
            return
        end
    end

    setupElectricsData(displayData.electrics)
    setupPowertrainData(displayData.powertrain)
    setupCustomModuleData(displayData.customModules)

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
        uiUnitDate = settings.getValue("uiUnitDate") or "ger"
    }
    config = tableMerge(config, configData)

    htmlTextureInstance:callJS("setup", config)

    obj:queueGameEngineLua([[
    if screenService and screenService.configureScreen then
      screenService.configureScreen("]] .. controllerName .. [[", {
        width = ]] .. width .. [[,
        height = ]] .. height .. [[
      })
    end
  ]])
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

return M

-- mrow~