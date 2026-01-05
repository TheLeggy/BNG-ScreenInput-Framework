/**
 * sneppy snep snep!
 *
 * Be warned (!!!!): using this code means you give
 *     away your soul to the snow leopard gods!
 *
 * Translates BeamNG coordinate events to browser-like events
 *
 * Part of the screenInput framework - makes vehicle HTML displays actually usable
 * by converting 3D raycasts into standard DOM events. Effectively allows the HTML
 * to treat coordinate input as if it was running on a tablet, but also provides
 * the flexibility to handle more complex interactions when needed.
 */

class ScreenInputHandler {
  constructor(screenWidth, screenHeight, screenId = null) {
    this.screenWidth = screenWidth;
    this.screenHeight = screenHeight;
    this.screenId = screenId;
    this.enableHover = false;
    this.lastHoverElement = null;
    this.hoveredElements = [];
    this.lastMouseMoveTime = 0;
    this.mouseMoveThrottle = 1; // was 11ms. throttled way less cause it seems to make no difference anyway?
  }

  getDownstreamChain(element) {
    const chain = [];
    let current = element;
    while (current && current !== document.body) {
      chain.push(current);
      current = current.parentElement;
    }
    return chain;
  }

  /**
   * Main event handler called from Lua
   * @param {Object} eventData - Event data from BeamNG coordinate system
   */
  handleEvent(eventData) {
    const { type, x, y, screenId, button, deltaX, deltaY, pixelX, pixelY } =
      eventData;

    // Convert normalized coordinates to pixels if needed
    const clientX =
      pixelX !== undefined ? pixelX : Math.floor(x * this.screenWidth);
    const clientY =
      pixelY !== undefined ? pixelY : Math.floor(y * this.screenHeight);

    const element = document.elementFromPoint(clientX, clientY);

    switch (type) {
      case "click":
        this.handleClick(element, clientX, clientY, button);
        break;
      case "mousedown":
        this.handleMouseDown(element, clientX, clientY, button);
        break;
      case "mouseup":
        this.handleMouseUp(element, clientX, clientY, button);
        break;
      case "mousemove":
        this.handleMouseMove(element, clientX, clientY);
        break;
      case "mouseenter":
        this.handleMouseEnter(element, clientX, clientY);
        break;
      case "mouseleave":
        this.handleMouseLeave(element, clientX, clientY);
        break;
      case "drag":
        this.handleDrag(element, clientX, clientY, deltaX, deltaY);
        break;
      case "wheel":
        this.handleWheel(element, clientX, clientY, deltaY);
        break;
    }
  }

  handleClick(element, x, y, button) {
    if (!element) return;

    const event = new MouseEvent("click", {
      bubbles: true,
      cancelable: true,
      clientX: x,
      clientY: y,
      button: button,
      view: window,
    });

    element.dispatchEvent(event);
  }

  handleMouseDown(element, x, y, button) {
    if (!element) return;

    const event = new MouseEvent("mousedown", {
      bubbles: true,
      cancelable: true,
      clientX: x,
      clientY: y,
      button: button,
      view: window,
    });

    element.dispatchEvent(event);
  }

  handleMouseUp(element, x, y, button) {
    if (!element) return;

    const event = new MouseEvent("mouseup", {
      bubbles: true,
      cancelable: true,
      clientX: x,
      clientY: y,
      button: button,
      view: window,
    });

    element.dispatchEvent(event);
  }

  handleMouseMove(element, x, y) {
    // Manual hover tracking needed because CSS :hover doesn't activate
    // when we synthesize events from coordinate data
    if (element !== this.lastHoverElement) {
      const newChain = element ? this.getDownstreamChain(element) : [];
      const oldChain = this.hoveredElements;

      // Remove .hovered from elements no longer in the chain
      if (this.enableHover) {
        for (const el of oldChain) {
          if (!newChain.includes(el)) {
            el.classList.remove("hovered");
          }
        }
      }

      // Dispatch leave event to previous direct element only
      if (this.lastHoverElement && !newChain.includes(this.lastHoverElement)) {
        const leaveEvent = new MouseEvent("mouseleave", {
          bubbles: false,
          cancelable: true,
          clientX: x,
          clientY: y,
          view: window,
        });
        this.lastHoverElement.dispatchEvent(leaveEvent);
      }

      // Add .hovered to new elements in the chain
      if (this.enableHover) {
        for (const el of newChain) {
          if (!oldChain.includes(el)) {
            el.classList.add("hovered");
          }
        }
      }

      // Dispatch enter event to new direct element only
      if (element && !oldChain.includes(element)) {
        const enterEvent = new MouseEvent("mouseenter", {
          bubbles: false,
          cancelable: true,
          clientX: x,
          clientY: y,
          view: window,
        });
        element.dispatchEvent(enterEvent);
      }

      this.lastHoverElement = element;
      this.hoveredElements = newChain;
    }

    // Throttle mousemove events to 30fps to reduce overhead
    const now = Date.now();
    if (element && now - this.lastMouseMoveTime >= this.mouseMoveThrottle) {
      this.lastMouseMoveTime = now;
      const moveEvent = new MouseEvent("mousemove", {
        bubbles: true,
        cancelable: true,
        clientX: x,
        clientY: y,
        view: window,
      });
      element.dispatchEvent(moveEvent);
    }
  }

  handleMouseEnter(element, x, y) {
    if (!element) return;

    const newChain = this.getDownstreamChain(element);

    // Add .hovered to element and all downstream elements
    if (this.enableHover) {
      for (const el of newChain) {
        el.classList.add("hovered");
      }
    }

    const event = new MouseEvent("mouseenter", {
      bubbles: false,
      cancelable: true,
      clientX: x,
      clientY: y,
      view: window,
    });

    element.dispatchEvent(event);
    this.lastHoverElement = element;
    this.hoveredElements = newChain;
  }

  handleMouseLeave(element, x, y) {
    if (!element) return;

    if (this.enableHover) {
      for (const el of this.hoveredElements) {
        el.classList.remove("hovered");
      }
    }

    const event = new MouseEvent("mouseleave", {
      bubbles: false,
      cancelable: true,
      clientX: x,
      clientY: y,
      view: window,
    });

    element.dispatchEvent(event);
    this.lastHoverElement = null;
    this.hoveredElements = [];
  }

  handleDrag(element, x, y, deltaX, deltaY) {
    if (!element) return;

    const event = new MouseEvent("drag", {
      bubbles: true,
      cancelable: true,
      clientX: x,
      clientY: y,
      view: window,
    });

    // Add delta properties (readonly, need defineProperty)
    Object.defineProperty(event, "deltaX", { value: deltaX });
    Object.defineProperty(event, "deltaY", { value: deltaY });

    element.dispatchEvent(event);
  }

  handleWheel(element, x, y, deltaY) {
    if (!element) return;

    if (!isFinite(deltaY)) {
      return;
    }

    // WheelEvent constructor doesn't accept clientX/clientY directly in CEF
    // Create event with proper delta values and deltaMode, then set coordinates
    const event = new WheelEvent("wheel", {
      bubbles: true,
      cancelable: true,
      deltaY: deltaY,
      deltaMode: WheelEvent.DOM_DELTA_PIXEL,
      view: window,
    });

    // Set coordinate properties (readonly, need defineProperty)
    Object.defineProperty(event, "clientX", { value: x });
    Object.defineProperty(event, "clientY", { value: y });

    element.dispatchEvent(event);

    // Synthetic events don't trigger default browser scrolling
    // Manually scroll the element or its scrollable parent

    if (!event.defaultPrevented) {
      let scrollTarget = element;
      while (scrollTarget && scrollTarget !== document.body) {
        const style = window.getComputedStyle(scrollTarget);
        const isScrollable =
          (style.overflowY === "scroll" || style.overflowY === "auto") &&
          scrollTarget.scrollHeight > scrollTarget.clientHeight;

        if (isScrollable) {
          scrollTarget.scrollTop += deltaY;
          break;
        }
        scrollTarget = scrollTarget.parentElement;
      }
    }
  }
}

// Global handler instance
let handler = null;

/**
 * Add display to the Screen with Input system
 * @param {number} width - Screen width in pixels
 * @param {number} height - Screen height in pixels
 * @param {string} [screenId] - Unique ID for the display
 * @param {Object} [options] - Configuration object
 * @param {boolean} [options.enableHover] - Enable hover class feature
 */
window.initScreenInput = function (width, height, screenId, options) {
  handler = new ScreenInputHandler(width, height, screenId);
  // Enable automatic hover class if enabled
  if (options && options.enableHover === true) {
    handler.enableHover = true;
  }
};

// Namespace for Lua-called functions
window.screenInput = {
  /**
   * Main entry point called from Lua
   * Receives coordinate events from BeamNG and dispatches them as DOM events
   */
  onInput: function (eventData) {
    const eventScreenId = eventData?.screenId;

    if (!handler) {
      if (eventScreenId) {
        return;
      }
      console.warn("screenInput: Handler not set up yet");
      return;
    }

    if (
      handler.screenId &&
      eventScreenId &&
      handler.screenId !== eventScreenId
    ) {
      return;
    }

    handler.handleEvent(eventData);
  },

  /**
   * Call a custom Lua function in the vehicle controller
   *
   * This allows HTML pages to invoke user-defined callbacks in vehicle Lua without
   * modifying the framework. Callbacks must be registered in the vehicle controller's
   * init() function using screenInput.registerLuaCallback().
   *
   * @param {string} functionName - The name of the registered callback function
   * @param {Object} args - Arguments object to pass to the Lua function
   *
   * @example
   * // In HTML - call with parameters
   * callVehicleLua("setVolume", { level: 80 });
   *
   * @example
   * // In vehicle Lua controller - register callbacks
   * local function init(jbeamData)
   *   if screenInput then
   *     screenInput.registerLuaCallback("setVolume", function(args)
   *       local level = args.level or 50
   *       -- Do something with volume
   *     end)
   *   end
   * end
   */
  callLua: function (functionName, args) {
    if (
      typeof beamng === "undefined" ||
      typeof beamng.sendEngineLua !== "function"
    ) {
      console.warn("beamng.sendEngineLua not available");
      return;
    }

    const argsJson = JSON.stringify(args || {});
    beamng.sendEngineLua(
      `screenService.callVehicleLua("${functionName}", jsonDecode('${argsJson}'))`
    );
  },

  /**
   * Called when cursor enters/leaves the screen trigger box
   * Rarely needed. Coordinate events handle most use cases
   */
  onHover: function (data) {},

  /**
   * Trigger event handler called from Lua
   * Dispatches custom events for physical triggers
   *
   * @param {Object} eventData - Trigger event data
   * @param {string} eventData.id - Trigger volume ID
   * @param {string} eventData.action - Action type
   * @param {number} [eventData.duration] - Hold duration in seconds
   * @param {number} [eventData.deltaX] - Drag delta X
   * @param {number} [eventData.deltaY] - Drag delta Y
   */
  onTrigger: function (eventData) {
    if (!eventData || !eventData.id) {
      return;
    }

    // Dispatch as custom event so HTML pages can use addEventListener
    const event = new CustomEvent("beamng:trigger", {
      detail: eventData,
      bubbles: true,
      cancelable: true,
    });
    document.dispatchEvent(event);

    // Also dispatch action-specific events for convenience
    if (eventData.action) {
      const actionEvent = new CustomEvent(
        `beamng:trigger:${eventData.action}`,
        {
          detail: eventData,
          bubbles: true,
          cancelable: true,
        }
      );
      document.dispatchEvent(actionEvent);
    }
  },
};

//------------------------------------------------------------------
// DATA SAVING API
//------------------------------------------------------------------
// The following four levels (defined as 'scopes') are included:
//   "factory"    - factory defaults
//   "global"     - defaults for the entire model
//   "identifier" - user account or vehicle
//   "user"       - driver profile within vehicle or account
//
//  "identifier" and "user" are branching levels - multiple can exist
//    within the same model. "factory" and "global" can only have one.
//
//  Hierarchy is mainly used to allow multiple setting profiles, but
//  actual use cases are examples and can be used creatively.
//
// The recursive merging was born from wanting to support multiple users,
// but also to facilitate the question of what happens when data isn't
// present in, say, a license plate folder but is in the global context.
// It's complex, but also simplifies downstream building by providing
// native logic and handling.
//------------------------------------------------------------------

/**
 * Save data to persistent storage
 *
 * @param {string} filename - JSON file name to save under
 * @param {object} data - Settings or data to persist
 * @param {string} [scope="global"] - Which scope to save to (see hierarchy above)
 * @param {string} [userId] - User identifier (for "user" scope)
 * @param {string} [identifier] - Custom identifier (defaults to license plate)
 *
 * @example
 * // Save model-wide preferences (all vehicles of this model share this)
 * persistSave("default_settings", { theme: "dark", volume: 80 });
 *
 * @example
 * // Save identifier-specific data (uses license plate by default)
 * persistSave("trip_computer", { totalMiles: 12500 }, "identifier");
 *
 * @example
 * // Save user-specific data (for login/profile systems)
 * persistSave("preferences", { seat: "memory1" }, "user", "john_doe");
 */
function persistSave(filename, data, scope, userId, identifier) {
  if (
    typeof beamng === "undefined" ||
    typeof beamng.sendEngineLua !== "function"
  ) {
    console.warn("beamng.sendEngineLua not available");
    return;
  }

  const jsonStr = JSON.stringify(data);
  const safeScope = scope || "global";
  const safeUserId = userId ? `"${userId}"` : "nil";
  const safeIdentifier = identifier ? `"${identifier}"` : "nil";

  beamng.sendEngineLua(
    `screenService.persistSave("${filename}", jsonDecode('${jsonStr}'), "${safeScope}", ${safeUserId}, ${safeIdentifier})`
  );
}

/**
 * Load data from persistent storage
 * Returns data via callback since Lua->JS is async
 *
 * @param {string} filename - JSON file name to load
 * @param {function} callback - Function to call with loaded data (or null if not found)
 * @param {string} [scope="global"] - Which scope to load from
 * @param {string} [userId] - User identifier (for "user" scope)
 * @param {string} [identifier] - Custom identifier (defaults to license plate)
 */
function persistLoad(filename, callback, scope, userId, identifier) {
  if (
    typeof beamng === "undefined" ||
    typeof beamng.sendEngineLua !== "function"
  ) {
    console.warn("beamng.sendEngineLua not available");
    if (callback) callback(null);
    return;
  }

  const safeScope = scope || "global";
  const safeUserId = userId ? `"${userId}"` : "nil";
  const safeIdentifier = identifier ? `"${identifier}"` : "nil";
  const callbackId =
    "_persistLoadCallback_" +
    Date.now() +
    "_" +
    Math.random().toString(36).substr(2, 9);

  // Create temporary callback with 30s timeout
  window[callbackId] = function (data) {
    delete window[callbackId];
    if (callback) callback(data);
  };

  // Cleanup after 30 seconds if callback never fires
  setTimeout(() => {
    if (window[callbackId]) {
      delete window[callbackId];
      console.warn(`Callback ${callbackId} timed out after 30s`);
      if (callback) callback(null);
    }
  }, 30000);

  beamng.sendEngineLua(
    `screenService.persistLoadAsync("${filename}", "${safeScope}", ${safeUserId}, ${safeIdentifier}, "${callbackId}")`
  );
}

/**
 * Check if a data file exists
 *
 * @param {string} filename - JSON file name to check
 * @param {function} callback - Function to call with boolean result
 * @param {string} [scope="global"] - Which scope to check
 * @param {string} [userId] - User identifier (for "user" scope)
 * @param {string} [identifier] - Custom identifier (defaults to license plate)
 */
function persistExists(filename, callback, scope, userId, identifier) {
  if (
    typeof beamng === "undefined" ||
    typeof beamng.sendEngineLua !== "function"
  ) {
    console.warn("beamng.sendEngineLua not available");
    if (callback) callback(false);
    return;
  }

  const safeScope = scope || "global";
  const safeUserId = userId ? `"${userId}"` : "nil";
  const safeIdentifier = identifier ? `"${identifier}"` : "nil";
  const callbackId =
    "_persistExistsCallback_" +
    Date.now() +
    "_" +
    Math.random().toString(36).substr(2, 9);

  window[callbackId] = function (exists) {
    delete window[callbackId];
    if (callback) callback(exists === true || exists === "true");
  };

  // Cleanup after 30 seconds if callback never fires
  setTimeout(() => {
    if (window[callbackId]) {
      delete window[callbackId];
      console.warn(`Callback ${callbackId} timed out after 30s`);
      if (callback) callback(false);
    }
  }, 30000);

  beamng.sendEngineLua(
    `screenService.persistExistsAsync("${filename}", "${safeScope}", ${safeUserId}, ${safeIdentifier}, "${callbackId}")`
  );
}

/**
 * Delete a data file
 *
 * @param {string} filename - JSON file name to delete
 * @param {string} [scope="global"] - Which scope to delete from
 * @param {string} [userId] - User identifier (for "user" scope)
 * @param {string} [identifier] - Custom identifier (defaults to license plate)
 */
function persistDelete(filename, scope, userId, identifier) {
  if (
    typeof beamng === "undefined" ||
    typeof beamng.sendEngineLua !== "function"
  ) {
    console.warn("beamng.sendEngineLua not available");
    return;
  }

  const safeScope = scope || "global";
  const safeUserId = userId ? `"${userId}"` : "nil";
  const safeIdentifier = identifier ? `"${identifier}"` : "nil";

  beamng.sendEngineLua(
    `screenService.persistDelete("${filename}", "${safeScope}", ${safeUserId}, ${safeIdentifier})`
  );
}

/**
 * Get the current vehicle's license plate
 *
 * @param {function} callback - Function to call with license plate string (or null)
 */
function getLicensePlate(callback) {
  if (
    typeof beamng === "undefined" ||
    typeof beamng.sendEngineLua !== "function"
  ) {
    console.warn("beamng.sendEngineLua not available");
    if (callback) callback(null);
    return;
  }

  const callbackId =
    "_cefPlateCallback_" +
    Date.now() +
    "_" +
    Math.random().toString(36).substr(2, 9);

  window[callbackId] = function (plate) {
    delete window[callbackId];
    if (callback) callback(plate);
  };

  // Cleanup after 30 seconds if callback never fires
  setTimeout(() => {
    if (window[callbackId]) {
      delete window[callbackId];
      console.warn(`Callback ${callbackId} timed out after 30s`);
      if (callback) callback(null);
    }
  }, 30000);

  beamng.sendEngineLua(`screenService.getLicensePlateAsync("${callbackId}")`);
}

/**
 * List all user IDs that have saved data for a specific file on this identifier
 *
 * @param {string} filename - JSON file name to check
 * @param {function} callback - Function to call with array of user IDs
 * @param {string} [identifier] - Custom identifier (defaults to license plate)
 */
function persistListUsers(filename, callback, identifier) {
  if (
    typeof beamng === "undefined" ||
    typeof beamng.sendEngineLua !== "function"
  ) {
    console.warn("beamng.sendEngineLua not available");
    if (callback) callback([]);
    return;
  }

  const safeIdentifier = identifier ? `"${identifier}"` : "nil";
  const callbackId =
    "_persistUsersCallback_" +
    Date.now() +
    "_" +
    Math.random().toString(36).substr(2, 9);

  window[callbackId] = function (users) {
    delete window[callbackId];
    if (callback) callback(users || []);
  };

  // Cleanup after 30 seconds if callback never fires
  setTimeout(() => {
    if (window[callbackId]) {
      delete window[callbackId];
      console.warn(`Callback ${callbackId} timed out after 30s`);
      if (callback) callback([]);
    }
  }, 30000);

  beamng.sendEngineLua(
    `screenService.persistListUsersAsync("${filename}", ${safeIdentifier}, "${callbackId}")`
  );
}

/**
 * Register factory defaults for a settings file
 * Factory defaults are immutable - they persist as the "reset to defaults" baseline
 *
 * @param {string} filename - JSON file name
 * @param {object} defaults - Default values object
 */
function persistRegisterDefaults(filename, defaults) {
  if (
    typeof beamng === "undefined" ||
    typeof beamng.sendEngineLua !== "function"
  ) {
    console.warn("beamng.sendEngineLua not available");
    return;
  }

  const jsonStr = JSON.stringify(defaults);
  beamng.sendEngineLua(
    `screenService.persistRegisterDefaults("${filename}", jsonDecode('${jsonStr}'))`
  );
}

/**
 * Create factory defaults file if it doesn't exist
 * Uses previously registered defaults or provided defaults
 *
 * @param {string} filename - JSON file name
 * @param {object} [defaults] - Optional defaults to use (overrides registered defaults)
 */
function persistInitDefaults(filename, defaults) {
  if (
    typeof beamng === "undefined" ||
    typeof beamng.sendEngineLua !== "function"
  ) {
    console.warn("beamng.sendEngineLua not available");
    return;
  }

  if (defaults) {
    const jsonStr = JSON.stringify(defaults);
    beamng.sendEngineLua(
      `screenService.persistInitDefaults("${filename}", jsonDecode('${jsonStr}'))`
    );
  } else {
    beamng.sendEngineLua(`screenService.persistInitDefaults("${filename}")`);
  }
}

/**
 * Reset settings at a specific scope back to factory defaults
 * Deletes the scope's file, causing it to fall back to lower-priority scopes
 *
 * @param {string} filename - JSON file name to reset
 * @param {string} [scope="global"] - Scope type to reset: "global", "identifier", or "user"
 * @param {string} [userId] - User identifier (required when scope is "user")
 * @param {string} [identifier] - Custom identifier (defaults to license plate)
 */
function persistResetToFactory(filename, scope, userId, identifier) {
  if (
    typeof beamng === "undefined" ||
    typeof beamng.sendEngineLua !== "function"
  ) {
    console.warn("beamng.sendEngineLua not available");
    return;
  }

  const safeScope = scope || "global";
  const safeUserId = userId ? `"${userId}"` : "nil";
  const safeIdentifier = identifier ? `"${identifier}"` : "nil";
  beamng.sendEngineLua(
    `screenService.persistResetToFactory("${filename}", "${safeScope}", ${safeUserId}, ${safeIdentifier})`
  );
}

/**
 * Load settings with recursive hierarchical merging
 * Merges: factory -> global -> identifier -> user
 * Can be treated as a load order: user loads last because the
 * settings the user set are more "important" than factory or others
 *
 * It is recommended to load settings using this function unless
 * a specific scope's data is required, rather than the most "important."
 *
 * @param {string} filename - Which JSON file to load
 * @param {function} callback - Function called with (mergedData, sources)
 *   - mergedData: The merged settings object
 *   - sources: Object mapping top-level keys to their source scope
 * @param {string} [userId] - User identifier (adds user scope to merge)
 * @param {string} [identifier] - Custom identifier (defaults to license plate)
 *
 * @example
 * // Load settings for current vehicle (no user profile)
 * persistLoadMerged("settings", (data, sources) => {
 *   console.log("Theme:", data.theme);
 *   console.log("Theme came from:", sources.theme); // "factory", "global", etc.
 * });
 *
 * @example
 * // Load settings for specific driver profile
 * persistLoadMerged("settings", (data, sources) => {
 *   // User John's preferences override vehicle defaults
 * }, "john_doe");
 */
function persistLoadMerged(filename, callback, userId, identifier) {
  if (
    typeof beamng === "undefined" ||
    typeof beamng.sendEngineLua !== "function"
  ) {
    console.warn("beamng.sendEngineLua not available");
    if (callback) callback(null, null);
    return;
  }

  const safeUserId = userId ? `"${userId}"` : "nil";
  const safeIdentifier = identifier ? `"${identifier}"` : "nil";
  const callbackId =
    "_persistMergedCallback_" +
    Date.now() +
    "_" +
    Math.random().toString(36).substr(2, 9);

  window[callbackId] = function (data, sources) {
    delete window[callbackId];
    if (callback) callback(data, sources);
  };

  // Cleanup after 30 seconds if callback never fires
  setTimeout(() => {
    if (window[callbackId]) {
      delete window[callbackId];
      console.warn(`Callback ${callbackId} timed out after 30s`);
      if (callback) callback(null, null);
    }
  }, 30000);

  beamng.sendEngineLua(
    `screenService.persistLoadMerged("${filename}", ${safeUserId}, ${safeIdentifier}, "${callbackId}")`
  );
}

/**
 * Get which scope a specific setting key came from
 *
 * @param {string} filename - JSON file name to check
 * @param {string} key - The setting key to check
 * @param {function} callback - Function called with scope string ("factory", "global", "identifier", "user", or null)
 * @param {string} [userId] - User identifier (includes user scope in search)
 * @param {string} [identifier] - Custom identifier (defaults to license plate)
 */
function persistGetSource(filename, key, callback, userId, identifier) {
  if (
    typeof beamng === "undefined" ||
    typeof beamng.sendEngineLua !== "function"
  ) {
    console.warn("beamng.sendEngineLua not available");
    if (callback) callback(null);
    return;
  }

  const safeUserId = userId ? `"${userId}"` : "nil";
  const safeIdentifier = identifier ? `"${identifier}"` : "nil";
  const callbackId =
    "_persistSourceCallback_" +
    Date.now() +
    "_" +
    Math.random().toString(36).substr(2, 9);

  window[callbackId] = function (source) {
    delete window[callbackId];
    if (callback) callback(source);
  };

  // Cleanup after 30 seconds if callback never fires
  setTimeout(() => {
    if (window[callbackId]) {
      delete window[callbackId];
      console.warn(`Callback ${callbackId} timed out after 30s`);
      if (callback) callback(null);
    }
  }, 30000);

  beamng.sendEngineLua(
    `screenService.persistGetSourceAsync("${filename}", "${key}", ${safeUserId}, ${safeIdentifier}, "${callbackId}")`
  );
}

// Handler for async callbacks from Lua via screenInput
window.persistCallback = function (callbackData) {
  const { type, callbackId, data, sources } = callbackData;

  if (window[callbackId]) {
    if (type === "loaded") {
      window[callbackId](data);
    } else if (type === "merged") {
      window[callbackId](data, sources);
    } else if (type === "exists") {
      window[callbackId](data);
    } else if (type === "plate") {
      window[callbackId](data);
    } else if (type === "users") {
      window[callbackId](data);
    } else if (type === "source") {
      window[callbackId](data);
    }
  }
};

// Export for global use
window.persistSave = persistSave;
window.persistLoad = persistLoad;
window.persistExists = persistExists;
window.persistDelete = persistDelete;
window.getLicensePlate = getLicensePlate;
window.persistListUsers = persistListUsers;
window.persistRegisterDefaults = persistRegisterDefaults;
window.persistInitDefaults = persistInitDefaults;
window.persistResetToFactory = persistResetToFactory;
window.persistLoadMerged = persistLoadMerged;
window.persistGetSource = persistGetSource;

/**
 * Call a custom Lua function registered in the vehicle controller
 *
 * @param {string} functionName - Name of the callback registered via screenInput.registerLuaCallback()
 * @param {Object} args - Arguments object passed to Lua function
 *
 * @example
 * callVehicleLua("playSound", { sound: "click", volume: 0.8 });
 */
window.callVehicleLua = function (functionName, args) {
  window.screenInput.callLua(functionName, args);
};

// Export for CommonJS/Node module systems
if (typeof module !== "undefined" && module.exports) {
  module.exports = { ScreenInputHandler };
}

// mrow~
