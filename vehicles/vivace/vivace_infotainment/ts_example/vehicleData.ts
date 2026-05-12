/// <reference path="../../../../ui/modules/beamng.d.ts" />

export const vehicleData = defineScreenData({
  electrics: { rpm: 0, gear: 0, wheelspeed: 0 },
  powertrain: {
    mainEngine: { outputTorque1: 0, instantEngineLoad: 0 },
    gearbox: { gearIndex: 0 }
  },
  customModules: {
    combustionEngineData: { currentPower: 0, currentTorque: 0 }
  }
});
