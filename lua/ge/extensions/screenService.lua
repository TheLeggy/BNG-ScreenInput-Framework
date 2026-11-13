-- so it's like a cool thing that makes it easy to make screens
-- we send coordinates and related DOM events to the js 
-- and that makes development so much easier (win for you). 

local M = {}

M.dependencies = {"ui_imgui"}

M.drawBoxes = false

local logTag = "screenService"

local vehicle = nil
local registeredVehicles = {}
local boxes = {}
local triggers = {}
local referencePlanes = {}
local screenConfigs = {}
local triggerStates = {}
local lastHoveredBoxId = nil

local function parseJSON(path)
    local content = path and readFile(path)
    if not content then
        return nil
    end

    local success, result = pcall(jsonDecode, content)
    if not success then
        log("E", logTag, "Failed to parse JSON from " .. path .. ": " .. tostring(result))
        return nil
    end
    return result
end

local function findConfigByType(directory, configType)
    -- a jsonc beats a json of the same type
    for _, pattern in ipairs({"*.jsonc", "*.json"}) do
        for _, filepath in ipairs(FS:findFiles(directory, pattern, 0, true, false)) do
            local data = parseJSON(filepath)
            if data and data["$configType"] == configType then
                return filepath, data
            end
        end
    end
    return nil, nil
end

local function toVec3(t)
    if t and t.x and t.y and t.z then
        return vec3(t.x, t.y, t.z)
    end
    return nil
end

local function toId(value)
    if value then
        return tostring(value)
    end
    return nil
end

local function configureScreen(screenId, config)
    screenConfigs[screenId] = {
        width = config.width,
        height = config.height,
        aspectRatio = config.width / config.height
    }
end

local hitVector = vec3()
local function calculateScreenCoordinates(rayHitPos, obb)
    local halfExt = obb:getHalfExtents()
    hitVector:setSub2(rayHitPos, obb:getCenter())

    -- x is the width and z is the height
    local localX = hitVector:dot(obb:getAxis(0)) / halfExt.x
    local localZ = hitVector:dot(obb:getAxis(2)) / halfExt.z

    -- axis 0 points right to left
    return clamp(1 - (localX + 1) * 0.5, 0, 1), clamp((localZ + 1) * 0.5, 0, 1)
end

local function detectMouseEvent()
    local im = ui_imgui

    if im.IsMouseDragging(0) then
        return "drag", 0
    end
    if im.IsMouseClicked(0) then
        return "mousedown", 0
    end
    if im.IsMouseReleased(0) then
        return "mouseup", 0
    end

    local mouseWheel = im.GetIO().MouseWheel
    if mouseWheel ~= 0 then
        return "wheel", nil, mouseWheel
    end

    return "mousemove", nil

    -- TODO: look back at middle and right click events
    -- TODO: also wouldn't hurt to look at Pointer Events API
end

local holdSeconds = 0.5
local dragDeadzonePixels = 5

local function detectTriggerInteraction(triggerId)
    local im = ui_imgui
    local state = triggerStates[triggerId]
    if not state then
        state = {pressed = false}
        triggerStates[triggerId] = state
    end

    if im.IsMouseClicked(0) then
        state.pressed = true
        state.pressTime = os.clock()
        return {id = triggerId, action = "press"}
    end

    if not state.pressed then
        return nil
    end

    if im.IsMouseReleased(0) then
        state.pressed = false
        local duration = os.clock() - state.pressTime
        if duration > holdSeconds then
            return {id = triggerId, action = "hold", duration = duration}
        end
        return {id = triggerId, action = "click"}
    end

    if im.IsMouseDragging(0) then
        local delta = im.GetMouseDragDelta(0)
        if math.abs(delta.x) > dragDeadzonePixels or math.abs(delta.y) > dragDeadzonePixels then
            return {id = triggerId, action = "drag", deltaX = delta.x, deltaY = delta.y}
        end
    end
    return nil
end

local function quote(s)
    -- %q alone would let a nil through as "nil"
    return string.format("%q", s .. "")
end

local function packed(value)
    return quote(lpack.encode(value))
end

local function unpacking(value)
    return "lpack.decode(" .. packed(value) .. ")"
end

-- a vehicle without the controller has no screenInput
local function callScreenInput(functionName, args)
    vehicle:queueLuaCommand(string.format("if screenInput and screenInput.%s then screenInput.%s(%s) end",
        functionName, functionName, args))
end

-- one table for every event keeps the GC quiet
local coordinateEvent = {}
local function sendCoordinateEvent(eventType, screenId, x, y, button, pixelX, pixelY, deltaY)
    local event = coordinateEvent
    event.type = eventType
    event.x = x
    event.y = y
    event.screenId = screenId
    event.button = button
    event.pixelX = pixelX
    event.pixelY = pixelY
    event.deltaY = deltaY
    callScreenInput("inputCoordinate", unpacking(event))
end

local function sendHover(boxId)
    callScreenInput("onHover", boxId and quote(boxId) or "nil")
end

local function sendPersistCallback(dataType, callbackId, value)
    callScreenInput("onPersistCallback", quote(dataType) .. ", " .. quote(callbackId) .. ", " .. packed(value))
end

local function axisRotation(x, y, z)
    local matrix = MatrixF(true)
    matrix:setFromEuler(vec3(math.rad(x), math.rad(y), math.rad(z)))
    return matrix
end

local function rotationMatrix(rot)
    if not (rot and rot.x and rot.y and rot.z) or (rot.x == 0 and rot.y == 0 and rot.z == 0) then
        return nil
    end

    -- one matrix per axis keeps the order x then y then z
    local result = axisRotation(rot.x, 0, 0)
    result:mul(axisRotation(0, rot.y, 0))
    result:mul(axisRotation(0, 0, rot.z))
    return result
end

local screenBoxColor = ColorF(1, 0.5, 0, 1)
local plainBoxColor = ColorF(0, 1, 1, 1)
local triggerColor = ColorF(0.5, 0, 1, 1)

local function drawBox(box, color)
    local center = box:getCenter()
    local halfExt = box:getHalfExtents()
    local x = halfExt.x * box:getAxis(0)
    local y = halfExt.y * box:getAxis(1)
    local z = halfExt.z * box:getAxis(2)

    local function corner(sx, sy, sz)
        return center + sx * x + sy * y + sz * z
    end

    for sz = 1, -1, -2 do
        debugDrawer:drawLine(corner(1, 1, sz), corner(-1, 1, sz), color)
        debugDrawer:drawLine(corner(1, 1, sz), corner(1, -1, sz), color)
        debugDrawer:drawLine(corner(1, -1, sz), corner(-1, -1, sz), color)
        debugDrawer:drawLine(corner(-1, -1, sz), corner(-1, 1, sz), color)
    end
    for sx = 1, -1, -2 do
        for sy = 1, -1, -2 do
            debugDrawer:drawLine(corner(sx, sy, 1), corner(sx, sy, -1), color)
        end
    end
end

local function drawLabel(pos, text, color)
    if debugDrawer.drawText then
        debugDrawer:drawText(pos, text, color)
    elseif debugDrawer.drawString then
        debugDrawer:drawString(pos, text, color)
    end
end

local function dimmed(color, factor)
    return ColorF(color.r * factor, color.g * factor, color.b * factor, color.a)
end

local function drawDashes(origin, direction, length, color, stride)
    for i = 1, 8, stride do
        debugDrawer:drawLine(origin + direction * (length * ((i - 1) / 8)), origin + direction * (length * (i / 8)),
            color)
    end
end

local function frameAxes(rot)
    return vec3(1, 0, 0):rotated(rot), vec3(0, 1, 0):rotated(rot), vec3(0, 0, 1):rotated(rot)
end

local function drawReferencePlane(origin, planeRot, vehRot)
    local axisLength = 0.12
    local labelOffset = 0.015
    local arrowSize = 0.008

    local function drawVehicleAxis(axis, side, color, name)
        local dim = dimmed(color, 0.6)
        local posEnd = origin + axis * axisLength
        local negEnd = origin - axis * axisLength

        debugDrawer:drawLine(origin, posEnd, color)
        drawDashes(origin, -axis, axisLength, dim, 2)

        local arrowBase = posEnd - axis * arrowSize
        for _, across in ipairs({side, axis:cross(side)}) do
            local offset = across * (arrowSize * 0.5)
            debugDrawer:drawLine(posEnd, arrowBase + offset, color)
            debugDrawer:drawLine(posEnd, arrowBase - offset, color)
        end

        local tick = side * 0.005
        debugDrawer:drawLine(posEnd + tick, posEnd - tick, color)
        debugDrawer:drawLine(negEnd + tick, negEnd - tick, dim)

        drawLabel(posEnd + axis * labelOffset, name .. "+", color)
        drawLabel(negEnd - axis * labelOffset, name .. "-", dim)
    end

    local function drawPlaneAxis(axis, side, color, name)
        local length = axisLength * 0.85
        local posEnd = origin + axis * length

        drawDashes(origin, axis, length, color, 2)
        drawDashes(origin, -axis, length, dimmed(color, 0.5), 3)

        local arrowBase = posEnd - axis * (arrowSize * 0.8)
        local offset = side * (arrowSize * 0.4)
        debugDrawer:drawLine(posEnd, arrowBase + offset, color)
        debugDrawer:drawLine(posEnd, arrowBase - offset, color)

        drawLabel(posEnd + axis * labelOffset, name .. "+ (rel)", dimmed(color, 0.8))
    end

    local function drawRotationArc(rotAxis, from, to, color, label, reversed)
        local radius = axisLength * 0.8 * 0.3
        local arrowLength = 0.006
        local quarterTurn = math.pi / 2

        local function onArc(angle, distance)
            return origin + (from * math.cos(angle) + to * math.sin(angle)) * distance
        end

        for i = 1, 20 do
            debugDrawer:drawLine(onArc((i - 1) * quarterTurn / 20, radius), onArc(i * quarterTurn / 20, radius), color)
        end

        local angle = reversed and 0 or quarterTurn
        local tangent = to * math.cos(angle) - from * math.sin(angle)
        local tip = onArc(angle, radius)
        local base = tip + tangent * (reversed and arrowLength or -arrowLength)
        local offset = rotAxis:cross(tangent) * (arrowLength * 0.6)
        debugDrawer:drawLine(tip, base + offset, color)
        debugDrawer:drawLine(tip, base - offset, color)

        drawLabel(onArc(math.pi / 4, radius * 1.3), label, color)
    end

    local vehX, vehY, vehZ = frameAxes(vehRot)
    drawVehicleAxis(vehX, vehY, ColorF(1, 0, 0, 1), "X")
    drawVehicleAxis(vehY, vehZ, ColorF(0, 1, 0, 1), "Y")
    drawVehicleAxis(vehZ, vehY, ColorF(0, 0, 1, 1), "Z")

    local planeX, planeY, planeZ = frameAxes(planeRot)
    drawPlaneAxis(planeX, planeY, ColorF(1, 0.3, 0.3, 1), "X")
    drawPlaneAxis(planeY, planeZ, ColorF(0.3, 1, 0.3, 1), "Y")
    drawPlaneAxis(planeZ, planeY, ColorF(0.3, 0.3, 1, 1), "Z")

    drawRotationArc(planeX, planeZ, planeY, ColorF(0, 1, 1, 0.8), "RX", false)
    drawRotationArc(planeY, planeZ, planeX, ColorF(1, 1, 0, 0.8), "RY", true)
    drawRotationArc(planeZ, planeY, planeX, ColorF(1, 0, 1, 0.8), "RZ", true)

    local halfSize = 0.1
    local white = ColorF(1, 1, 1, 1)
    local corners = {
        origin + planeX * halfSize + planeY * halfSize,
        origin - planeX * halfSize + planeY * halfSize,
        origin - planeX * halfSize - planeY * halfSize,
        origin + planeX * halfSize - planeY * halfSize
    }
    for i = 1, 4 do
        debugDrawer:drawLine(corners[i], corners[i % 4 + 1], white)
    end
end

local maxHitDistance = 2

-- fresh ones every frame would feed the GC
local vehRot = quat()
local vehPos = vec3()
local vehMat = nil
local obb = OrientedBox3F()
local boxPos = vec3()
local rayHitPos = vec3()
local frameCounter = 0

-- the last mousemove that went to the vehicle
local lastMovePixelX = nil
local lastMovePixelY = nil
local lastMoveScreenId = nil
local dragSequenceActive = false
local clickSuppressedByDrag = false

local function forgetLastMove()
    lastMovePixelX, lastMovePixelY, lastMoveScreenId = nil, nil, nil
end

local function endDragSequence()
    dragSequenceActive = false
    clickSuppressedByDrag = false
end

local function planeWorldTransform(plane)
    local world = plane.world
    if world.frame ~= frameCounter then
        world.rotMat = vehMat:copy()
        if plane.rotMat then
            world.rotMat:mul(plane.rotMat)
        end
        world.rotQuat:set(world.rotMat:toQuatF())
        world.pos:set(plane.pos)
        world.pos:setRotate(vehRot)
        world.pos:setAdd(vehPos)
        world.frame = frameCounter
    end
    return world
end

local function computeOBB(v)
    local rot, origin, baseMat = vehRot, vehPos, vehMat
    local plane = referencePlanes[v.refPlane or "0"] or referencePlanes["0"]
    if plane then
        local world = planeWorldTransform(plane)
        rot, origin, baseMat = world.rotQuat, world.pos, world.rotMat
    end

    boxPos:set(v.pos)
    boxPos:setRotate(rot)
    boxPos:setAdd(origin)

    local boxMat = baseMat:copy()
    if v.rotMat then
        boxMat:mul(v.rotMat)
    end
    boxMat:setPosition(boxPos)
    obb:set2(boxMat, v.size)
end

local function rayDistanceToOBB(ray)
    local nearHit, farHit = intersectsRay_OBB(ray.pos, ray.dir, obb:getCenterHalfExtentAxes())
    -- a box behind the camera still crosses the ray's line
    if farHit <= 0 then
        return math.huge
    end
    return nearHit
end

local function handleScreenHit(box, screenConfig, ray, dist)
    rayHitPos:set(ray.pos.x + ray.dir.x * dist, ray.pos.y + ray.dir.y * dist, ray.pos.z + ray.dir.z * dist)
    local cx, cy = calculateScreenCoordinates(rayHitPos, obb)
    cx = clamp(cx + box.translateX * (cx - 0.5), 0, 1)
    cy = clamp(cy + box.translateY * (cy - 0.5), 0, 1)
    local pixelX = math.floor(cx * screenConfig.width)
    local pixelY = math.floor(cy * screenConfig.height)
    local screenId = box.screenId

    local eventType, button, mouseWheel = detectMouseEvent()
    local sendType = eventType
    local sendClickAfterMouseup = false
    if eventType == "mousedown" then
        dragSequenceActive = true
        clickSuppressedByDrag = false
    elseif eventType == "drag" then
        -- a drag can reach us without its press
        if not dragSequenceActive then
            sendCoordinateEvent("mousedown", screenId, cx, cy, button, pixelX, pixelY)
            dragSequenceActive = true
        end
        clickSuppressedByDrag = true
        sendType = "mousemove"
    elseif eventType == "mouseup" then
        sendClickAfterMouseup = dragSequenceActive and not clickSuppressedByDrag
        endDragSequence()
    end

    if sendType == "mousemove" then
        -- a still cursor has nothing new to send
        if pixelX == lastMovePixelX and pixelY == lastMovePixelY and screenId == lastMoveScreenId then
            return
        end
        lastMovePixelX, lastMovePixelY, lastMoveScreenId = pixelX, pixelY, screenId
    else
        -- a click can change the DOM under the cursor
        forgetLastMove()
    end

    sendCoordinateEvent(sendType, screenId, cx, cy, button, pixelX, pixelY, mouseWheel and mouseWheel * -100)
    if sendClickAfterMouseup then
        sendCoordinateEvent("click", screenId, cx, cy, button, pixelX, pixelY)
    end
end

local function onUpdate()
    if not vehicle or not vehicle.getPosition or not (boxes[1] or triggers[1]) then
        return
    end

    -- the button came up while we weren't looking
    if dragSequenceActive and not ui_imgui.IsMouseDown(0) and not ui_imgui.IsMouseReleased(0) then
        endDragSequence()
    end

    local ray = getCameraMouseRay()

    vehMat = vehicle:getRefNodeMatrix()
    vehRot:set(vehMat:toQuatF())
    vehPos:set(vehicle:getPositionXYZ())
    frameCounter = frameCounter + 1

    if M.drawBoxes then
        for _, plane in pairs(referencePlanes) do
            local world = planeWorldTransform(plane)
            drawReferencePlane(world.pos, world.rotQuat, vehRot)
        end
    end

    local hoveredBoxId = nil
    for k = 1, #boxes do
        local box = boxes[k]
        local screenConfig = screenConfigs[box.screenId]

        -- the screen can register after its boxes load
        if not box.size and screenConfig then
            box.size = vec3(box.scale, box.depth, box.scale / screenConfig.aspectRatio)
        end

        if box.size then
            computeOBB(box)
            if M.drawBoxes then
                drawBox(obb, box.screenId and screenBoxColor or plainBoxColor)
            end

            local dist = rayDistanceToOBB(ray)
            if screenConfig and dist < maxHitDistance then
                hoveredBoxId = box.id
                handleScreenHit(box, screenConfig, ray, dist)
            end
        end
    end

    for k = 1, #triggers do
        local trigger = triggers[k]
        computeOBB(trigger)
        if M.drawBoxes then
            drawBox(obb, triggerColor)
        end

        if trigger.id and rayDistanceToOBB(ray) < maxHitDistance then
            local eventData = detectTriggerInteraction(trigger.id)
            if eventData then
                callScreenInput("onTrigger", unpacking(eventData))
            end
        end
    end

    if hoveredBoxId ~= lastHoveredBoxId then
        if lastHoveredBoxId then
            -- the page would keep its button held down
            if dragSequenceActive and lastMovePixelX then
                sendCoordinateEvent("mouseup", lastMoveScreenId, nil, nil, 0, lastMovePixelX, lastMovePixelY)
                endDragSequence()
            end
            sendHover(nil)
        end
        if hoveredBoxId then
            sendHover(hoveredBoxId)
        end
        lastHoveredBoxId = hoveredBoxId
        forgetLastMove()
    end
end

local function directoryOf(path)
    return path:match("^(.+)/[^/]+$")
end

local function parsePlane(planeData)
    return {
        pos = toVec3(planeData.pos) or vec3(0, 0, 0),
        rotMat = rotationMatrix(planeData.rot),
        world = {
            rotQuat = quat(),
            pos = vec3(),
            frame = -1
        }
    }
end

local function loadReferencePlanes(directory)
    referencePlanes = {}

    local _, fileData
    if directory then
        _, fileData = findConfigByType(directory, "referencePlane")
    end
    if not fileData then
        return
    end

    if fileData.planes then
        for i = 1, #fileData.planes do
            local planeData = fileData.planes[i]
            referencePlanes[tostring(planeData.id or i - 1)] = parsePlane(planeData)
        end
    elseif fileData.pos or fileData.rot then
        referencePlanes["0"] = parsePlane(fileData)
    end
end

local function loadBoxes(path)
    boxes = {}

    local fileData = parseJSON(path)
    if not fileData then
        return
    end

    local configType = fileData["$configType"]
    if configType and configType ~= "triggerBoxes" then
        log("E", logTag, "Expected $configType 'triggerBoxes', got '" .. tostring(configType) .. "' in " .. path)
    end

    -- a bare array of boxes works too
    local entries = fileData.boxes or (fileData[1] and fileData)
    if not entries then
        log("E", logTag, "Invalid trigger box file format in " .. path)
        return
    end

    loadReferencePlanes(directoryOf(path))

    local loaded = {}
    for k = 1, #entries do
        local entry = entries[k]
        local pos = toVec3(entry.pos)
        if pos then
            local box = {
                pos = pos,
                id = toId(entry.id),
                screenId = entry.screenId,
                refPlane = toId(entry.refPlane),
                translateX = entry.translateX or 0,
                translateY = entry.translateY or 0
            }

            if entry.screenId and entry.scale then
                box.scale = entry.scale
                box.depth = entry.depth or 0.0005
            else
                box.size = toVec3(entry.size)
            end

            if box.scale or box.size then
                box.rotMat = rotationMatrix(entry.rot)
                loaded[#loaded + 1] = box
            else
                log("E", logTag, "Box " .. k .. " missing size data (needs 'screenId'+'scale' or 'size')")
            end
        end
    end
    boxes = loaded
end

local function loadTriggers(path)
    triggers = {}
    triggerStates = {}

    local directory = path and directoryOf(path)
    if not directory then
        return
    end

    local triggerPath, fileData = findConfigByType(directory, "triggers")
    if not fileData then
        return
    end
    if not fileData.triggers then
        log("E", logTag, "Invalid trigger file format in " .. triggerPath)
        return
    end

    local loaded = {}
    for k = 1, #fileData.triggers do
        local entry = fileData.triggers[k]
        local pos = toVec3(entry.pos)
        local size = toVec3(entry.size)
        if pos and size then
            loaded[#loaded + 1] = {
                pos = pos,
                size = size,
                id = toId(entry.id),
                refPlane = toId(entry.refPlane),
                rotMat = rotationMatrix(entry.rot)
            }
        end
    end
    triggers = loaded
end

-- the page can call in before setFocusCar gives us a vehicle
local pendingCalls = {}

local function waitForVehicle(fn)
    return function(...)
        if vehicle then
            return fn(...)
        end
        pendingCalls[#pendingCalls + 1] = {fn = fn, args = {...}, argCount = select("#", ...)}
    end
end

local function callVehicleLua(functionName, args)
    local name = quote(tostring(functionName))
    vehicle:queueLuaCommand(string.format("screenInput.onLuaCallback(%s, %s)", name, unpacking(args)))
end

local function setFocusCar(id)
    vehicle = scenetree.findObject(id)
    registeredVehicles[id] = true
    if not vehicle then
        return
    end

    local calls = pendingCalls
    pendingCalls = {}
    for _, call in ipairs(calls) do
        -- one bad call must not eat the ones behind it
        local ok, err = pcall(call.fn, unpack(call.args, 1, call.argCount))
        if not ok then
            log("E", logTag, "A call made before the vehicle had focus failed: " .. tostring(err))
        end
    end
end

local function onVehicleDestroyed(vid)
    if vehicle and vehicle:getId() == vid then
        vehicle = nil
        vehMat = nil
        screenConfigs = {}
        boxes = {}
        triggers = {}
        referencePlanes = {}
        triggerStates = {}
        lastHoveredBoxId = nil
        endDragSequence()
        forgetLastMove()
    end
    registeredVehicles[vid] = nil
    if not next(registeredVehicles) then
        extensions.unload(M.__extensionName__)
    end
end

-- DATA SAVING
--------------------------------------------------------------------
-- Four levels (aka "scopes"):
--   "factory"    - immutable defaults
--   "global"     - defaults for the entire model
--   "identifier" - user account or vehicle
--   "user"       - driver profile within vehicle or account
--
--  "identifier" and "user" are branching - multiple can exist within the same model
--  "factory" and "global" can only have one
--
-- Hierarchy: factory -> global -> identifier -> user

local function sanitizePathComponent(str)
    if not str or str == "" then
        return "_default"
    end
    local sanitized = str:gsub("[<>:\"/\\|?*%c]", "_"):match("^%s*(.-)%s*$"):sub(1, 64)
    if sanitized == "" then
        return "_default"
    end
    return sanitized
end

local function getLicensePlateLocal()
    local licensePlate = vehicle and vehicle.licenseText
    if licensePlate and licensePlate ~= "" then
        return sanitizePathComponent(licensePlate)
    end
    return nil
end

local function getLicensePlate(callbackId)
    sendPersistCallback("plate", callbackId, getLicensePlateLocal())
end

local function modelPersistDir()
    return "settings/persist/" .. (vehicle.jbeam or "unknown")
end

local function buildPersistPath(filename, scope, userId, identifier)
    local dir = modelPersistDir()
    scope = scope or "global"

    if scope == "factory" then
        dir = dir .. "/_factory"
    elseif scope == "identifier" or scope == "user" then
        local id = identifier or getLicensePlateLocal()
        if not id then
            log("W", logTag, "No identifier or license plate found, returning to global scope")
        else
            dir = dir .. "/" .. sanitizePathComponent(id)
            if scope == "user" then
                dir = dir .. "/user/" .. sanitizePathComponent(userId)
            end
        end
    elseif scope ~= "global" then
        log("W", logTag, "Unknown scope '" .. tostring(scope) .. "', using global")
    end

    return dir .. "/" .. filename .. ".json", dir
end

local function deepMerge(base, source)
    if type(base) ~= "table" or type(source) ~= "table" then
        return source
    end

    local result = {}
    for k, v in pairs(base) do
        if type(v) == "table" then
            result[k] = deepMerge({}, v)
        else
            result[k] = v
        end
    end
    for k, v in pairs(source) do
        if type(v) == "table" and type(result[k]) == "table" then
            result[k] = deepMerge(result[k], v)
        else
            result[k] = v
        end
    end
    return result
end

local function persistSave(filename, data, scope, userId, identifier)
    local filePath, dir = buildPersistPath(filename, scope, userId, identifier)
    FS:directoryCreate(dir, true)
    jsonWriteFile(filePath, data, true)
    return true
end

local function persistLoadLocal(filename, scope, userId, identifier)
    if not vehicle then
        log("E", logTag, "Cannot load data - no vehicle active")
        return nil
    end

    local filePath = buildPersistPath(filename, scope, userId, identifier)
    local data = jsonReadFile(filePath)
    return data
end

local function persistLoad(filename, scope, userId, identifier, callbackId)
    local data = persistLoadLocal(filename, scope, userId, identifier)
    callScreenInput("onPersistLoaded", quote(callbackId) .. ", " .. packed(data))
end

local function persistExists(filename, scope, userId, identifier, callbackId)
    local filePath = buildPersistPath(filename, scope, userId, identifier)
    sendPersistCallback("exists", callbackId, FS:fileExists(filePath))
end

local function persistDelete(filename, scope, userId, identifier)
    local filePath = buildPersistPath(filename, scope, userId, identifier)
    if not FS:fileExists(filePath) then
        return false
    end

    FS:removeFile(filePath)
    log("I", logTag, "Deleted: " .. filePath)
    return true
end

local function persistListUsers(filename, identifier, callbackId)
    local users = {}
    local id = identifier or getLicensePlateLocal()
    if id then
        local userDir = modelPersistDir() .. "/" .. sanitizePathComponent(id) .. "/user"
        for _, dir in ipairs(FS:directoryList(userDir, false, true) or {}) do
            local userName = dir:match("([^/\\]+)$")
            if userName and FS:fileExists(userDir .. "/" .. userName .. "/" .. filename .. ".json") then
                table.insert(users, userName)
            end
        end
    end

    sendPersistCallback("users", callbackId, users)
end

local factoryDefaults = {}

local function persistRegisterDefaults(filename, defaults)
    if type(defaults) == "table" then
        factoryDefaults[filename] = defaults
    end
end

local function persistInitDefaults(filename, defaults)
    local filePath, dir = buildPersistPath(filename, "factory")
    if FS:fileExists(filePath) then
        log("W", logTag, "Factory defaults already exist: " .. filePath)
        return true
    end

    local defaultData = defaults or factoryDefaults[filename] or {}
    if not next(defaultData) then
        log("W", logTag, "No defaults provided for factory file: " .. filename)
        return false
    end

    FS:directoryCreate(dir, true)
    jsonWriteFile(filePath, defaultData, true)
    return true
end

local function persistResetToFactory(filename, scope, userId, identifier)
    if scope == "factory" then
        log("E", logTag, "Cannot reset factory scope")
        return false
    end
    return persistDelete(filename, scope, userId, identifier)
end

-- PRESET COPYING
--------------------------------------------------------------------
-- Copy a preset file from vehicle directory to a target scope
-- Mainly used for factory setting presets shipped with the vehicle mod
-- sourcePath: path to preset file relative to vehicle root (e.g., "presets/suspension_defaults.json")
-- filename: target settings filename (without .json extension)
-- targetScope: scope to copy to ("factory", "global", "identifier", or "user")
-- overwrite: if true, overwrites existing file (default: false for safety, but true recommended for factory)
-- userId: user ID (required if targetScope is "user")
-- identifier: custom identifier (overrides license plate for identifier/user scopes)

local function persistCopyPreset(sourcePath, filename, targetScope, overwrite, userId, identifier)
    if not vehicle then
        return false
    end

    local fullSourcePath = "vehicles/" .. (vehicle.jbeam or "unknown") .. "/" .. sourcePath
    if not FS:fileExists(fullSourcePath) then
        log("E", logTag, "Preset file not found: " .. fullSourcePath)
        return false
    end

    local presetData = parseJSON(fullSourcePath)
    if not presetData then
        log("E", logTag, "Failed to parse preset file: " .. fullSourcePath)
        return false
    end

    local targetPath, targetDir = buildPersistPath(filename, targetScope, userId, identifier)
    if FS:fileExists(targetPath) and overwrite ~= true then
        log("W", logTag, "Target file already exists (use overwrite=true to replace): " .. targetPath)
        return false
    end

    FS:directoryCreate(targetDir, true)
    if not jsonWriteFile(targetPath, presetData, true) then
        log("E", logTag, "Failed to write preset to: " .. targetPath)
        return false
    end
    return true
end

local function persistLoadMerged(filename, userId, identifier, callbackId)
    if not vehicle then
        return nil, nil
    end

    local result = {}
    local sources = {}
    local function mergeScope(scope, data)
        if not data then
            return
        end
        result = deepMerge(result, data)
        for k in pairs(data) do
            sources[k] = scope
        end
    end

    local factoryData = persistLoadLocal(filename, "factory", nil, identifier)
    if not factoryData and factoryDefaults[filename] then
        factoryData = factoryDefaults[filename]
        persistInitDefaults(filename)
    end
    mergeScope("factory", factoryData)
    mergeScope("global", persistLoadLocal(filename, "global", nil, identifier))

    if identifier or getLicensePlateLocal() then
        mergeScope("identifier", persistLoadLocal(filename, "identifier", nil, identifier))
        if userId then
            mergeScope("user", persistLoadLocal(filename, "user", userId, identifier))
        end
    end

    if callbackId then
        callScreenInput("onPersistMerged", quote(callbackId) .. ", " .. packed(result) .. ", " .. packed(sources))
    end

    if not next(result) then
        return nil, nil
    end
    return result, sources
end

local function persistGetSource(filename, key, userId, identifier, callbackId)
    local _, sources = persistLoadMerged(filename, userId, identifier)
    sendPersistCallback("source", callbackId, sources and sources[key])
end

---- QUERY API for Individual Scopes
--------------------------------------------------------------------
-- Get a property from a specific scope (not merged)
-- filename: settings file name (without .json)
-- key: property key to query
-- scope: scope to query ("factory", "global", "identifier", or "user")
-- userId: user ID (required if scope is "user")
-- identifier: custom identifier (overrides license plate for identifier/user scopes)
local function persistGetInScope(filename, key, scope, userId, identifier)
    local data = persistLoadLocal(filename, scope, userId, identifier)
    if data and data[key] ~= nil then
        return data[key]
    end

    local defaults = scope == "factory" and factoryDefaults[filename]
    if defaults then
        return defaults[key]
    end
    return nil
end

---- QUERY API for Downstream Search
--------------------------------------------------------------------
-- Find a property by searching the hierarchy in order (most specific first)
-- Searches downstream: user -> vehicle -> global -> factory
-- Returns the first match found, along with which scope it came from
-- filename: settings file name (without .json)
-- key: property key to query
-- userId: user ID (includes user scope in search)
-- identifier: custom identifier (overrides license plate)
local function persistFindInHierarchy(filename, key, userId, identifier)
    local value

    if userId then
        value = persistGetInScope(filename, key, "user", userId, identifier)
        if value ~= nil then
            return value, "user"
        end
    end

    if identifier or getLicensePlateLocal() then
        value = persistGetInScope(filename, key, "identifier", nil, identifier)
        if value ~= nil then
            return value, "identifier"
        end
    end

    for _, scope in ipairs({"global", "factory"}) do
        value = persistGetInScope(filename, key, scope)
        if value ~= nil then
            return value, scope
        end
    end

    return nil, nil
end

-- QUERY API for Merged Results
--------------------------------------------------------------------
-- Get any property from merged settings (factory -> global -> identifier -> user)
-- Returns the effective value after all scope merges, or nil if not found
-- This is the final merged value where later scopes override earlier ones
-- For advanced cases (userId, custom identifier), use persistLoadMerged() directly
-- filename: settings file name (without .json)
-- key: property key to query
local function persistGet(filename, key)
    local data = persistLoadMerged(filename)
    return data and data[key]
end

--------------------------------------------------------------------

M.onUpdate = onUpdate
M.setFocusCar = setFocusCar
M.loadBoxes = loadBoxes
M.loadTriggers = loadTriggers
M.onVehicleDestroyed = onVehicleDestroyed
M.configureScreen = configureScreen
M.callVehicleLua = waitForVehicle(callVehicleLua)

M.persistSave = waitForVehicle(persistSave)
M.persistLoad = waitForVehicle(persistLoad)
M.persistExists = waitForVehicle(persistExists)
M.persistDelete = waitForVehicle(persistDelete)
M.persistListUsers = waitForVehicle(persistListUsers)
M.getLicensePlate = waitForVehicle(getLicensePlate)
M.persistRegisterDefaults = persistRegisterDefaults
M.persistInitDefaults = waitForVehicle(persistInitDefaults)
M.persistResetToFactory = waitForVehicle(persistResetToFactory)
M.persistLoadMerged = waitForVehicle(persistLoadMerged)
M.persistGetSource = waitForVehicle(persistGetSource)
M.persistGet = persistGet
M.persistGetInScope = persistGetInScope
M.persistFindInHierarchy = persistFindInHierarchy
M.persistCopyPreset = persistCopyPreset

return M

-- woof
