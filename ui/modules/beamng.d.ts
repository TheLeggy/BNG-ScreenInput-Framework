export interface CoordinateEventData {
  type:
    | "click"
    | "mousedown"
    | "mouseup"
    | "mousemove"
    | "mouseenter"
    | "mouseleave"
    | "wheel";
  x: number;
  y: number;
  screenId?: string;
  button?: number;
  deltaX?: number;
  deltaY?: number;
  pixelX?: number;
  pixelY?: number;
}

export interface TriggerEventData {
  id: string;
  action?: string;
  duration?: number;
  deltaX?: number;
  deltaY?: number;
}

export interface SifConfig {
  displayWidth?: number;
  displayHeight?: number;
  screenId?: string;
  [key: string]: any;
}

export interface SifOptions {
  enableHover?: boolean;
}

type BrakeThermals = {
  brakeSurfaceTemperature: number;
  brakeCoreTemperature: number;
  brakeThermalEfficiency: number;
};

// regen after a game update
export interface BeamNGElectrics {
  abs: number;
  absActive: boolean;
  accXSmooth: number;
  accYSmooth: number;
  accZSmooth: number;
  aileron: number;
  airflowspeed: number;
  airspeed: number;
  alsActive: boolean;
  alsState: "off" | "idle" | "armed" | "manualOverride" | "timeout";
  altitude: number;
  /** pessima only */
  auto_1: number;
  /** pessima only */
  auto_2: number;
  /** pessima only */
  auto_d: number;
  /** pessima only */
  auto_n: number;
  /** pessima only */
  auto_p: number;
  /** pessima only */
  auto_r: number;
  avgWheelAV: number;
  /** citybus only */
  bomblights: number;
  boost: number;
  boostMax: number;
  brake: number;
  brakeF: number;
  brakelight_signal_L: boolean | number;
  brakelight_signal_R: boolean | number;
  brakelights: number;
  /** large_roller only */
  brakeOverride: number;
  brakeR: number;
  /** citybus only */
  busbomb_d1: number;
  /** citybus only */
  busbomb_u0: number;
  /** citybus only */
  busbomb_u1: number;
  /** citybus only */
  busbomb_u2: number;
  /** citybus only */
  busbomb_u3: number;
  /** citybus only */
  busbomb_u4: number;
  /** citybus only */
  busbomb_u5: number;
  /** citybus only */
  busbomb_u6: number;
  /** citybus only */
  busbomb_u7: number;
  /** citybus only */
  busbomb_u8: number;
  /** citybus only */
  busbomb_u9: number;
  /** large_cannon only */
  cannon_lift: number;
  checkengine: boolean | number;
  /** bluebuck, etki, fullsize, miramar only */
  clockh: number;
  /** bluebuck, etki, fullsize, miramar only */
  clockmin: number;
  clutch: number;
  clutchRatio: number;
  cruiseControlActive: boolean;
  cruiseControlTarget: number;
  /** large_crusher only */
  crusher: number;
  /** sbr only */
  disp_1: number;
  /** sbr only */
  disp_2: number;
  /** sbr only */
  disp_3: number;
  /** sbr only */
  disp_4: number;
  /** sbr only */
  disp_5: number;
  /** sbr only */
  disp_6: number;
  /** sbr only */
  disp_7: number;
  /** sbr only */
  disp_D: number;
  /** sbr only */
  disp_N: number;
  /** sbr only */
  disp_Na: number;
  /** sbr only */
  disp_P: number;
  /** sbr only */
  disp_R: number;
  /** sbr only */
  disp_Ra: number;
  /** citybus only */
  doorLever: number;
  /** citybus only */
  doorlever: number;
  /** citybus only */
  dooropen: number;
  /** dryvan only */
  doorR: number;
  dseCrashStopped: number;
  dseRollingOver: number;
  dseRollOverStopped: number;
  dseWarningPulse: number;
  electricalLoadCoef: number;
  elevator: number;
  engineLoad: number;
  engineRunning: number;
  engineThrottle: number;
  esc: number;
  escActive: boolean | number;
  exhaustFlow: number;
  flap: number;
  fog: boolean | number;
  freezeState: boolean;
  frontBrakeLockOut: number;
  fuel: number;
  fuelCapacity: number;
  fuelVolume: number;
  gear: string;
  gear_A: number;
  gear_M: number;
  gearboxMode: string;
  gearIndex: number;
  gearModeIndex: number;
  hasABS: boolean;
  hasESC: boolean;
  hasTCS: boolean;
  hazard: number;
  hazard_enabled: boolean | number;
  head_rotation: number;
  head_tilt: number;
  /** large_roller only */
  heightLeverPosition: number;
  highbeam: boolean | number;
  highbeam_wigwag_L: number;
  highbeam_wigwag_R: number;
  hillAssist: number;
  horn: boolean | number;
  idlerpm: number;
  ignition: boolean | number;
  ignitionLevel: number;
  isABSBrakeActive: number;
  isShifting: boolean;
  isTCBrakeActive: number;
  isYCBrakeActive: number;
  jato: number;
  jatofuel: number;
  jatoInput: number;
  /** kickplate only */
  kickplateDirection: number;
  /** kickplate only */
  kickplateHasFired: number;
  /** kickplate only */
  kickplateIncorrectSpeed: number;
  /** kickplate only */
  kickplatePowerLevel: number;
  /** citybus only */
  kneel: number;
  /** cannon, large_angletester only */
  lifter: number;
  /** cannon, large_angletester only */
  lifter_input: number;
  lightbar: boolean | number;
  lights: number;
  lights_state: number;
  lockupClutchRatio: number;
  lowbeam: boolean | number;
  lowfuel: boolean | number;
  lowhighbeam: boolean | number;
  lowhighbeam_signal_L: boolean | number;
  lowhighbeam_signal_R: boolean | number;
  lowpressure: number;
  maxGearIndex: number;
  maxRegenStrength: number;
  maxrpm: number;
  minGearIndex: number;
  mode4WD: boolean | number;
  modeRangeBox: boolean | number;
  /** large_hamster_wheel, large_spinner only */
  motorFanSpin: number;
  nop: number;
  odometer: number;
  oil: boolean | number;
  oiltemp: number;
  parking: number;
  parkingbrake: number;
  parkingbrakelight: boolean | number;
  postCrashBrakeTriggered: number;
  radiatorFanSpin: number;
  /** testroller only */
  ramp_angle: number;
  regenFromBrake: number;
  regenFromOnePedal: number;
  regenStrength: number;
  regenThrottle: number;
  reverse: boolean | number;
  reverse_wigwag_L: boolean | number;
  reverse_wigwag_R: boolean | number;
  /** citybus only */
  rideheight: number;
  rpm: number;
  rpmspin: number;
  rpmTacho: number;
  rudder: number;
  running: boolean | number;
  /** cannon only */
  shoot: number;
  shouldShift: boolean;
  signal_L: boolean | number;
  signal_left_input: number;
  signal_R: boolean | number;
  signal_right_input: number;
  slat: number;
  /** rollover only */
  sled_position: number;
  smoothShiftLogicAV: number;
  /** spikestrip only */
  spikestrip_armed: number;
  /** sbr, vivace only */
  spoiler: boolean | number;
  /** scintilla only */
  spoilerF: number;
  /** scintilla only */
  spoilerR: number;
  steering: number;
  steering_input: number;
  steeringUnassisted: number;
  superchargerBoost: number;
  superchargerBoostMax: number;
  tcs: number;
  tcsActive: boolean | number;
  throttle: number;
  /** large_roller only */
  throttleLeverPosition: number;
  /** large_roller only */
  throttleManual: number;
  throttleOverride: number;
  /** rollover only */
  tilt_position: number;
  trip: number;
  turboBoost: number;
  turboBoostMax: number;
  turboRpmRatio: number;
  turnsignal: number;
  virtualAirspeed: number;
  watertemp: number;
  wheelspeed: number;
  wheelThermals: Record<string, BrakeThermals>;
  yawControlRequestReduceOversteer: number;
}

type ElectricsValue = number | boolean | string | null;
type ElectricsSchema = Partial<BeamNGElectrics> &
  Record<string, ElectricsValue | Record<string, unknown>>;
type DeviceSchema = Record<string, number | boolean | string | null>;
type PowertrainSchema = Record<string, DeviceSchema>;
type CustomModulesSchema = Record<string, DeviceSchema>;

export interface ScreenDataSchema {
  electrics?: ElectricsSchema;
  powertrain?: PowertrainSchema;
  customModules?: CustomModulesSchema;
}

type DeepWriteable<T> = { -readonly [P in keyof T]: DeepWriteable<T[P]> };
export type ScreenDataInstance<T extends ScreenDataSchema> = DeepWriteable<T>;

declare global {
  function initScreenInput(
    width?: number | SifConfig | null,
    height?: number | null,
    screenId?: string | null,
    options?: SifOptions,
  ): void;
  function defineScreenData<T extends ScreenDataSchema>(
    schema: T,
  ): ScreenDataInstance<T>;
  function callVehicleLua(functionName: string, args?: unknown): void;
  function persistSave(
    filename: string,
    data: object,
    scope?: string,
    userId?: string,
    identifier?: string,
  ): void;
  function persistLoad(
    filename: string,
    callback: (data: any) => void,
    scope?: string,
    userId?: string,
    identifier?: string,
  ): void;
  function persistExists(
    filename: string,
    callback: (exists: boolean) => void,
    scope?: string,
    userId?: string,
    identifier?: string,
  ): void;
  function persistDelete(
    filename: string,
    scope?: string,
    userId?: string,
    identifier?: string,
  ): void;
  function persistLoadMerged(
    filename: string,
    callback: (data: any, sources: Record<string, string>) => void,
    userId?: string,
    identifier?: string,
  ): void;
  function persistRegisterDefaults(filename: string, defaults: object): void;
  function persistInitDefaults(filename: string): void;
  function persistResetToFactory(
    filename: string,
    scope?: string,
    userId?: string,
    identifier?: string,
  ): void;
  function persistGetSource(
    filename: string,
    key: string,
    callback: (source: string) => void,
    userId?: string,
    identifier?: string,
  ): void;
  function persistListUsers(
    filename: string,
    callback: (users: string[]) => void,
    identifier?: string,
  ): void;
  function getLicensePlate(callback: (plate: string) => void): void;

  interface Window {
    // Screen Input Framework
    initScreenInput: typeof initScreenInput;
    defineScreenData: typeof defineScreenData;
    _sifConfig?: SifConfig;
    screenInput: {
      onInput: (eventData: CoordinateEventData) => void;
      callLua: (functionName: string, args?: unknown) => void;
      onHover: (data: { boxId?: string | null } | string | null) => void;
      onTrigger?: (eventData: TriggerEventData) => void;
    };
    setup: (config: SifConfig) => void;
    updateData: (data: any) => void;
    updateMode: (data: any) => void;
    callVehicleLua: typeof callVehicleLua;
    persistSave: typeof persistSave;
    persistLoad: typeof persistLoad;
    persistExists: typeof persistExists;
    persistDelete: typeof persistDelete;
    persistLoadMerged: typeof persistLoadMerged;
    persistRegisterDefaults: typeof persistRegisterDefaults;
    persistInitDefaults: typeof persistInitDefaults;
    persistResetToFactory: typeof persistResetToFactory;
    persistGetSource: typeof persistGetSource;
    persistListUsers: typeof persistListUsers;
    getLicensePlate: typeof getLicensePlate;

    // BeamNG CEF globals
    bridge: {
      api: {
        engineLua: (cmd: string, callback?: (result: any) => void) => void;
        activeObjectLua: (
          cmd: string,
          callback?: (result: any) => void,
        ) => void;
        queueAllObjectLua: (cmd: string) => void;
        engineScript: (cmd: string, callback?: (result: any) => void) => void;
        subscribeToEvents: (data: string) => void;
        serializeToLua: (obj: any) => string;
      };
      events: {
        on: (eventName: string, callback: (...args: any[]) => void) => void;
        off: (eventName: string, callback: (...args: any[]) => void) => void;
        emit: (eventName: string, ...args: any[]) => void;
      };
      streams: {
        add: (streamNames: string[]) => void;
        remove: (streamNames: string[]) => void;
      };
      beamNG: typeof beamng;
      lua: object;
    };
  }

  const beamng: {
    ingame: boolean;
    shipping: boolean;
    product: string;
    version: string;
    versionshort: string;
    buildtype: string;
    buildinfo: string;
    language: string;
    clientId: number;
    sendEngineLua: (luaCode: string) => void;
    sendActiveObjectLua: (luaCode: string) => void;
    queueAllObjectLua: (luaCode: string) => void;
    sendGameEngine: (scriptCode: string) => void;
    subscribeToEvents: (str: string) => void;
  };

  // bngApi is window.bridge.api, not an alias for beamng
  const bngApi: Window["bridge"]["api"];
}

export {};
