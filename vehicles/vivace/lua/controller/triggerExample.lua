local M = {}

local acMaxSound
local isPlaying = false

local function setPlaying(playing)
  isPlaying = playing
  if acMaxSound then
    obj:setVolumePitch(acMaxSound, playing and 1 or 0, 1)
  end
end

local function playSound()
  setPlaying(not isPlaying)
end

local function init()
  local soundNode = beamstate.nodeNameMap["ref"] or 0
  acMaxSound = obj:createSFXSource("vehicles/vivace/art/ac.wav", "AudioCloseLoop3D", "ac_max_loop", soundNode)
  setPlaying(false)
end

-- screenInput can load after this controller's init
local function initSecondStage()
  if screenInput then
    screenInput.registerLuaCallback("playSound", playSound)
  end
end

-- the game reruns both init stages on every vehicle reset for a controller without a reset
local function reset()
  setPlaying(false)
end

M.init = init
M.initSecondStage = initSecondStage
M.reset = reset
return M
