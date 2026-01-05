-- sneppy snep snep! 

-- Be warned (!!!!): using this code means you give  
--    away your soul to the snow leopard gods!

-- the bridge between the boxes/trigger data and the screen
-- sends events and coordinates to the javascript for it to handle
-- execution is still lua-side though

local M = {}

local gaugeHTMLTextures = {}
local serviceExtension = ""
local triggerConfigPath = ""
local drawBoxes = false

local playerSeated = false
local driverNodeCid = 0
local isInside = false

-- Send JS calls to all registered HTML screens
local function callJS(...)
    for _, v in ipairs(gaugeHTMLTextures) do
        v:callJS(...)
    end
end

-- Camera positioning detection 
local function updateCameraState()
    local camPos = obj:getCameraPosition()
    local driverPos = obj:getPosition() + obj:getNodePosition(driverNodeCid)

    -- Check if camera is within 0.6m of driver position (interior view)
    isInside = driverPos and (camPos:distance(driverPos) <= 0.6) or false
end

local function onPlayersChanged(active)
    if active then
        obj:queueGameEngineLua([[
            if ]] .. serviceExtension .. [[ then
                ]] .. serviceExtension .. [[.setFocusCar(]] .. objectId .. [[)
                ]] .. serviceExtension .. [[.drawBoxes = ]] .. tostring(drawBoxes) .. [[
            end
        ]])
    end
end

local function updateGFX(dt)
    if playerInfo.anyPlayerSeated ~= playerSeated then
        onPlayersChanged(playerInfo.anyPlayerSeated)
        playerSeated = playerInfo.anyPlayerSeated
    end

    updateCameraState()
end

local function addScreen(htmlTexture)
    gaugeHTMLTextures[#gaugeHTMLTextures + 1] = htmlTexture
end

local function initLastStage()
    -- Load trigger boxes from configured path
    -- loadTriggers() will find the triggers file in the same directory
    if not triggerConfigPath or triggerConfigPath == "" then
        return -- No path configured, skip loading
    end

    obj:queueGameEngineLua([[
        if ]] .. serviceExtension .. [[ then
            local basePath = "]] .. triggerConfigPath .. [["
            local files = FS:findFiles(basePath, "*.json", 0, true, false)
            local jsoncFiles = FS:findFiles(basePath, "*.jsonc", 0, true, false)
            
            -- Combine json and jsonc files
            for _, file in ipairs(jsoncFiles) do
                table.insert(files, file)
            end

            -- Find the triggerBoxes file
            for _, filepath in ipairs(files) do
                local content = readFile(filepath)
                if content and content:match('"$configType"%s*:%s*"triggerBoxes"') then
                    -- Load trigger boxes (screen interaction areas)
                    ]] .. serviceExtension .. [[.loadBoxes(filepath)
                    -- Load triggers (physical volumes) - searches same directory
                    ]] .. serviceExtension .. [[.loadTriggers(filepath)
                    break
                end
            end
        end
    ]])
end

local function reset()
    -- Reset handled by screenService
end

local function init(jbeamData)
    serviceExtension = "screenService"

    -- Configure trigger config path from jbeam (optional)
    -- Defaults to vehicles/{model}/interactive_screen/ if not specified
    if jbeamData and jbeamData.triggerConfigPath then
        triggerConfigPath = jbeamData.triggerConfigPath
    else
        local vehModel = v.data.model
        triggerConfigPath = "vehicles/" .. vehModel .. "/interactive_screen/"
    end

    drawBoxes = jbeamData and jbeamData.drawBoxes or false

    -- Reload the screenService extension
    obj:queueGameEngineLua("extensions.reload('screenService')")

    driverNodeCid = beamstate.nodeNameMap["driver"] or 0
end

M.reset = reset
M.init = init
M.initLastStage = initLastStage
M.addScreen = addScreen
M.updateGFX = updateGFX

-- Coordinate-based input events (mouse clicks, drags, etc.)
local function inputCoordinate(eventData)
    callJS("screenInput.onInput", eventData)
end

M.inputCoordinate = inputCoordinate

-- Hover state changes (mouse enter/leave trigger boxes)
local function onHover(boxId)
    callJS("screenInput.onHover", {
        boxId = boxId
    })
end

M.onHover = onHover

-- Trigger events (press, click, hold, drag on trigger volumes)
local function onTrigger(eventData)
    callJS("screenInput.onTrigger", eventData)
end

M.onTrigger = onTrigger

-- Data load callbacks
local function onPersistLoaded(callbackId, packedData)
    local data = lpack.decode(packedData)
    callJS("persistCallback", {
        type = "loaded",
        callbackId = callbackId,
        data = data
    })
end

M.onPersistLoaded = onPersistLoaded

-- Data merged callbacks
local function onPersistMerged(callbackId, packedData, packedSources)
    local data = lpack.decode(packedData)
    local sources = lpack.decode(packedSources)
    callJS("persistCallback", {
        type = "merged",
        callbackId = callbackId,
        data = data,
        sources = sources
    })
end

M.onPersistMerged = onPersistMerged

-- Generic data callback handler
local function onPersistCallback(dataType, callbackId, packedData)
    local data = lpack.decode(packedData)
    callJS("persistCallback", {
        type = dataType,
        callbackId = callbackId,
        data = data
    })
end

M.onPersistCallback = onPersistCallback

-- Simple sound test function - calls testSound controller if available
local function playTestSound()
    if controller.testSound and controller.testSound.playClick then
        controller.testSound.playClick()
    end
end

M.playTestSound = playTestSound

local luaCallbackHandlers = {}

local function registerLuaCallback(functionName, handler)
    luaCallbackHandlers[functionName] = handler
end

local function onLuaCallback(functionName, args)
    if luaCallbackHandlers[functionName] then
        luaCallbackHandlers[functionName](args)
    else
        log("W", "screenInput.onLuaCallback", "No handler registered for: " .. tostring(functionName))
    end
end

M.registerLuaCallback = registerLuaCallback
M.onLuaCallback = onLuaCallback

rawset(_G, "screenInput", M)
return M
