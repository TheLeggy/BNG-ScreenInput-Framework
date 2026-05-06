export interface CoordinateEventData {
  type: "click" | "mousedown" | "mouseup" | "mousemove" | "mouseenter" | "mouseleave" | "drag" | "wheel";
  x: number;
  y: number;
  screenId?: string;
  button: number;
  deltaX: number;
  deltaY: number;
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

type ElectricsSchema = Record<string, number | boolean | string | null>;
type PowertrainSchema = Record<string, Record<string, number>>;
type CustomModulesSchema = Record<string, Record<string, any>>;

export interface ScreenDataSchema {
  electrics?: ElectricsSchema;
  powertrain?: PowertrainSchema;
  customModules?: CustomModulesSchema;
}

type DeepWriteable<T> = { -readonly [P in keyof T]: DeepWriteable<T[P]> };
type ScreenDataInstance<T extends ScreenDataSchema> = DeepWriteable<T>;

declare global {
  interface Window {
    // Screen Input Framework
    initScreenInput: (width?: number | SifConfig, height?: number, screenId?: string | null, options?: SifOptions) => void;
    defineScreenData: <T extends ScreenDataSchema>(schema: T) => ScreenDataInstance<T>;
    _sifConfig?: SifConfig;
    screenInput: {
      onInput: (eventData: CoordinateEventData) => void;
      callLua: (functionName: string, args: unknown) => void;
      onHover: (data: { boxId?: string | null }) => void;
      onTrigger?: (eventData: TriggerEventData) => void;
    };
    setup: (config: SifConfig) => void;
    updateData: (data: any) => void;
    updateMode: (data: any) => void;
    loadTS: (url: string) => Promise<void>;
    callVehicleLua: (functionName: string, args?: unknown) => void;
    persistSave: (filename: string, data: object, scope?: string, userId?: string, identifier?: string) => void;
    persistLoad: (filename: string, callback: (data: any) => void, scope?: string, userId?: string, identifier?: string) => void;
    persistExists: (filename: string, callback: (exists: boolean) => void, scope?: string, userId?: string, identifier?: string) => void;
    persistDelete: (filename: string, scope?: string, userId?: string, identifier?: string) => void;
    persistLoadMerged: (filename: string, callback: (data: any, sources: Record<string, string>) => void, userId?: string, identifier?: string) => void;
    persistRegisterDefaults: (filename: string, defaults: object) => void;
    persistInitDefaults: (filename: string) => void;
    persistResetToFactory: (filename: string, scope?: string, userId?: string, identifier?: string) => void;
    persistGetSource: (filename: string, key: string, callback: (source: string) => void, userId?: string, identifier?: string) => void;
    persistListUsers: (filename: string, callback: (users: string[]) => void, identifier?: string) => void;
    getLicensePlate: (callback: (plate: string) => void) => void;

    // BeamNG CEF globals
    bridge: {
      api: {
        engineLua: (cmd: string, callback?: (result: any) => void) => void;
        activeObjectLua: (cmd: string, callback?: (result: any) => void) => void;
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
