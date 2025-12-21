local M = {}

local acMaxSound
local soundNode
local isPlaying = false

local function playSound(args)
  if acMaxSound then
    isPlaying = not isPlaying
    local volume = isPlaying and 1.0 or 0.0
    obj:setVolumePitch(acMaxSound, volume, 1.0)
  end
end

local function init(jbeamData)
  soundNode = beamstate.nodeNameMap["ref"] or 0
  acMaxSound = obj:createSFXSource("vehicles/vivace/art/ac.wav", "AudioCloseLoop3D", "ac_max_loop", soundNode)
  if acMaxSound then
    obj:setVolumePitch(acMaxSound, 0.0, 1.0)
  end
  
  if screenInput then
    screenInput.registerLuaCallback("playSound", playSound)
    screenInput.registerLuaCallback("customAction", customAction)
  end
end

M.init = init
return M
