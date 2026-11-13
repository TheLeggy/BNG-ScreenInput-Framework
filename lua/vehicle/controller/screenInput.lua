-- the bridge between the boxes/trigger data and the screen
-- sends events and coordinates to the javascript for it to handle
-- execution is still lua-side though

local M = {}

local htmlTextures = {}
local luaCallbackHandlers = {}
local triggerConfigPath = ""
local drawBoxes = false
local playerSeated = false

-- this runs in the game engine's Lua
local loadConfigCommand = [[
if screenService then
    local files = FS:findFiles(basePath, "*.jsonc", 0, true, false)
    for _, file in ipairs(FS:findFiles(basePath, "*.json", 0, true, false)) do
        table.insert(files, file)
    end
    for _, filepath in ipairs(files) do
        local content = readFile(filepath)
        if content and content:match('"$configType"%s*:%s*"triggerBoxes"') then
            screenService.loadBoxes(filepath)
            screenService.loadTriggers(filepath)
            break
        end
    end
end
]]

local function callJS(...)
    for i = 1, #htmlTextures do
        htmlTextures[i]:callJS(...)
    end
end

local function addScreen(htmlTexture)
    htmlTextures[#htmlTextures + 1] = htmlTexture
end

local function init(jbeamData)
    triggerConfigPath = jbeamData and jbeamData.triggerConfigPath or
                            ("vehicles/" .. v.data.model .. "/interactive_screen/")
    drawBoxes = jbeamData and jbeamData.drawBoxes or false

    -- this is also what loads the extension the first time
    obj:queueGameEngineLua("extensions.reload('screenService')")
end

local function initLastStage()
    if triggerConfigPath == "" then
        return
    end
    obj:queueGameEngineLua(string.format("local basePath = %q\n", triggerConfigPath) .. loadConfigCommand)
end

-- the game reruns init on every vehicle reset for a controller without a reset
local function reset()
end

local function updateGFX()
    local seated = playerInfo.anyPlayerSeated
    if seated == playerSeated then
        return
    end
    playerSeated = seated

    if seated then
        obj:queueGameEngineLua(string.format(
            "if screenService then screenService.setFocusCar(%d) screenService.drawBoxes = %s end", objectId,
            tostring(drawBoxes)))
    end
end

local function inputCoordinate(eventData)
    callJS("screenInput.onInput", eventData)
end

local function onHover(boxId)
    callJS("screenInput.onHover", boxId)
end

local function onTrigger(eventData)
    callJS("screenInput.onTrigger", eventData)
end

local function onPersistCallback(dataType, callbackId, packedData)
    callJS("persistCallback", {
        type = dataType,
        callbackId = callbackId,
        data = lpack.decode(packedData)
    })
end

local function onPersistLoaded(callbackId, packedData)
    onPersistCallback("loaded", callbackId, packedData)
end

local function onPersistMerged(callbackId, packedData, packedSources)
    callJS("persistCallback", {
        type = "merged",
        callbackId = callbackId,
        data = lpack.decode(packedData),
        sources = lpack.decode(packedSources)
    })
end

local function registerLuaCallback(functionName, handler)
    local handlers = luaCallbackHandlers[functionName]
    if not handlers then
        handlers = {}
        luaCallbackHandlers[functionName] = handlers
    end

    -- a controller without a reset registers again on every vehicle reset
    for _, registered in ipairs(handlers) do
        if registered == handler then
            return
        end
    end
    table.insert(handlers, handler)
end

local function onLuaCallback(functionName, args)
    local handlers = luaCallbackHandlers[functionName]
    if not handlers then
        log("W", "screenInput.onLuaCallback", "No handler registered for: " .. tostring(functionName))
        return
    end
    for _, handler in ipairs(handlers) do
        handler(args)
    end
end

M.init = init
M.initLastStage = initLastStage
M.reset = reset
M.updateGFX = updateGFX
M.addScreen = addScreen

M.inputCoordinate = inputCoordinate
M.onHover = onHover
M.onTrigger = onTrigger
M.onPersistLoaded = onPersistLoaded
M.onPersistMerged = onPersistMerged
M.onPersistCallback = onPersistCallback
M.registerLuaCallback = registerLuaCallback
M.onLuaCallback = onLuaCallback

-- the game engine and the other controllers find us through this global
rawset(_G, "screenInput", M)
return M
