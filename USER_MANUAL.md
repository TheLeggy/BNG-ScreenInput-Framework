# Screen Input - User Manual

**Complete reference for building interactive vehicle displays**

This manual covers everything you need to know about using the Screen Input framework, from basic setup to advanced features like data persistence and coordinate systems.

---

## Table of Contents

1. [Setup & Integration](#setup--integration)
2. [Configuration Files](#configuration-files)
3. [JavaScript API](#javascript-api)
4. [Data Persistence API](#data-persistence-api)
5. [Coordinate Systems](#coordinate-systems)
6. [Best Practices](#best-practices)
7. [Advanced Features](#advanced-features)
8. [Troubleshooting](#troubleshooting)

---

## Setup & Integration

### Vehicle Controller Setup

Add the controllers to your vehicle's jbeam file:

```json
"controller": [
  ["fileName"],
  ["screenInput", {
    "triggerConfigPath": "vehicles/yourcar/screen_configs/",
    "drawBoxes": false
  }],
  ["newScreen", { "name": "your_screen_material" }]
]
```

- `triggerConfigPath` - Path to configuration files (defaults to `vehicles/{model}/interactive_screen/`)
- `drawBoxes` - Enable visualization of trigger boxes and reference planes (defaults to `false`)
- `name` - Identifier for the screen controller

In the same jbeam part, add the screen configuration:

```json
"your_screen_material": {
  "materialName": "@your_screen_material",
  "htmlPath": "local://local/vehicles/yourcar/interactive_screen/infotainment.html",
  "displayWidth": 1920,
  "displayHeight": 1080
}
```

- `materialName` - Material name with `@` prefix added in front
- `htmlPath` - Path to HTML display
- `displayWidth` / `displayHeight` - Screen resolution in pixels
  The configuration name should match the `"name"` property.

For material configuration, refer to the game documentation or the `main.materials.json` file.

### HTML Display Setup

In your HTML file, add the screen input handler and initialize it inside the `setup()` callback:

```html
<script src="/ui/modules/screenInput.js"></script>
<script>
  window.setup = function (config) {
    window.initScreenInput(
      config.displayWidth,
      config.displayHeight,
      "your_screen_material",
      { enableHover: true }
    );
  };
  window.updateData = function (data) {};
  window.updateMode = function (data) {};
</script>
```

By initializing inside `setup()`, your display receives the jbeam configuration which includes the screen dimensions. The fourth parameter is an optional setting where you can enable optional features.

After calling `initScreenInput()`, you're done with BeamNG setup. Your display receives browser events and standard web development applies from here. Use vanilla JavaScript, React, Vue, whatever and build it like you would for a tablet interface.

The `screenId` parameter (third argument) should match your material name without the `@` symbol. This filters events so only raycasts hitting this specific screen trigger the display. Note that the material name in your jbeam configuration uses `@your_screen_material` with an `@`, but everywhere else (screenId in trigger boxes, JavaScript, screen configs) you use just `your_screen_material` without `@`.

---

## Configuration Files

All configuration files are located in your `triggerConfigPath` directory and use JSONC format. JSONC supports comments for ease of use, though standard JSON files are read too. Each file type is identified by its `$configType` property, which the system uses to discover and load the correct files. You are free to name the configuration files as you see fit.

### Reference Planes (`"$configType": "referencePlane"`)

Reference planes define coordinate origins for your trigger boxes and volumes. This is largely redundant for single-screen use cases, but becomes a massive time saver the moment you have more than one screen or additional trigger volumes.

**Header:** `"$configType": "referencePlane"`

**Single Plane Format:**

```jsonc
{
  "$configType": "referencePlane",
  "pos": { "x": 0.25, "y": -0.15, "z": 0.85 },
  "rot": { "x": -15, "y": 0, "z": 0 }
}
```

**Multiple Planes Format:**

```jsonc
{
  "$configType": "referencePlane",
  "planes": [
    {
      "id": "0",
      "pos": { "x": 0.25, "y": -0.15, "z": 0.85 },
      "rot": { "x": -15, "y": 0, "z": 0 }
    },
    {
      "id": "console",
      "pos": { "x": 0.15, "y": -0.2, "z": 0.75 },
      "rot": { "x": 0, "y": 0, "z": 0 }
    }
  ]
}
```

**Properties:**

- `id` - Unique identifier (defaults to "0" for single plane, or sequential numbers for arrays)
- `pos` - Position relative to vehicle origin (meters)
  - `x` - Left/right (positive = right)
  - `y` - Forward/back (positive = forward)
  - `z` - Up/down (positive = up)
- `rot` - Rotation in degrees (applied as extrinsic rotations)
  - `x` - Pitch (rotation around X axis)
  - `y` - Yaw (rotation around Y axis)
  - `z` - Roll (rotation around Z axis)

**When to use reference planes:**

I personally would put it where the infotainment screen is OR the main plane (for example, where the center console buttons are). It is all up to you, but it may save time later.
Plus, the reference plane is what provides the absolute axes, relative axes, and rotation axes as a handy visual when debugging.

### Trigger Boxes (`"$configType": "triggerBoxes"`)

Trigger boxes are the screen interaction areas that translate 3D raycasts into DOM events. Each box represents a clickable region that forwards input to your HTML display.

**Header:** `"$configType": "triggerBoxes"`

```jsonc
{
  "$configType": "triggerBoxes",
  "boxes": [
    {
      "id": "main_screen",
      "screenId": "your_screen_material",
      "pos": { "x": 0.0, "y": 0.0, "z": 0.0 },
      "scale": 0.2,
      "depth": 0.0005,
      "rot": { "x": 0, "y": 0, "z": 0 },
      "refPlane": "0"
    }
  ]
}
```

**Properties:**

- `id` - Unique identifier for this trigger box (optional, mainly for debugging)
- `screenId` - Material name (without `@`) that this box controls
- `pos` - Position relative to reference plane (or vehicle origin if no refPlane)
- `scale` - Width of the trigger box in meters
- `depth` - Thickness of the trigger box (defaults to 0.0005m if not specified, though there is no reason to add your own. Anything greater than 0 works, and as low as 0.0001 has been tested.)
- `rot` - Rotation relative to reference plane (optional, defaults to 0,0,0)
- `refPlane` - ID of reference plane to use (optional, uses absolute coordinates if omitted)

**How sizing works:**

The `scale` property sets the width, and the height is calculated automatically from your screen's aspect ratio (from jbeam `displayWidth`/`displayHeight`). For example, if your screen is 1920x1080 (16:9 aspect ratio) and scale is 0.2m, the box will be 0.2m wide and ~0.1125m tall.

### Trigger Volumes (`"$configType": "triggers"`)

Trigger volumes are physical 3D spaces that detect interaction events (press, click, hold, drag). Unlike trigger boxes which forward coordinates to HTML, trigger volumes send discrete events to JavaScript that you can handle however you want.

**Header:** `"$configType": "triggers"`

```jsonc
{
  "$configType": "triggers",
  "triggers": [
    {
      "id": "start_button",
      "pos": { "x": 0.05, "y": -0.02, "z": -0.08 },
      "size": { "x": 0.02, "y": 0.01, "z": 0.02 },
      "rot": { "x": 0, "y": 0, "z": 0 },
      "refPlane": "console"
    }
  ]
}
```

**Properties:**

- `id` - Unique identifier (sent with trigger events)
- `pos` - Position relative to reference plane
- `size` - Dimensions in meters (x = width, y = depth, z = height)
- `rot` - Rotation relative to reference plane (optional)
- `refPlane` - ID of reference plane to use (optional)

**Event types:**

- `press` - Mouse button pressed down
- `click` - Quick press and release (< 0.5 seconds)
- `hold` - Long press (≥ 0.5 seconds, includes duration)
- `drag` - Mouse moved while pressed (includes deltaX/deltaY)

**Handling trigger events:**

```javascript
document.addEventListener("beamng:trigger", function (event) {
  const { id, action, duration, deltaX, deltaY } = event.detail;

  if (id === "start_button" && action === "click") {
    console.log("Start button clicked!");
  }
});
```

You can also listen for specific action types:

```javascript
document.addEventListener("beamng:trigger:click", function (event) {
  if (event.detail.id === "start_button") {
    console.log("Start button clicked!");
  }
});
```

---

### Receiving Vehicle Data

To get vehicle data (like speed, RPM, gear, etc.) into your HTML display, you use the standard BeamNG `displayData` pattern. This works the same way as any other HTML screen in BeamNG.

**In your jbeam screen configuration, add displayData:**

```json
"your_screen_material": {
  "materialName": "@your_screen_material",
  "htmlPath": "local://local/vehicles/yourcar/interactive_screen//ns/infotainment.html",
  "displayWidth": 1920,
  "displayHeight": 1080,
  "displayData": [
    ["electrics", "values"],
    ["customModules", "environmentData"],
    ["powertrain", "deviceData"]
  ]
}
```

The `displayData` array specifies which data streams to send to your HTML. Common options include:

- `["electrics", "values"]` - Electrics values
- `["customModules", "environmentData"]` - Data from environmentData module
- `["powertrain", "deviceData"]` - Values from the deviceData module

**In your HTML, implement the callback functions:**

```javascript
// Called once with setup data
window.setup = (setupData) => {};

// Called continuously with live vehicle data
window.updateData = (data) => {
  // Access the data streams you requested
  const speed = data.electrics.wheelspeed;
  const rpm = data.electrics.rpm;
  const gear = data.electrics.gear;
  const temp = data.customModules.environmentData.temperatureEnv;

  // Update your display
  document.getElementById("speed").textContent = Math.round(speed);
  document.getElementById("rpm").textContent = Math.round(rpm);
};
```

**Important note:** This is standard BeamNG functionality and is not limited to the framework

---

## JavaScript API

### Screen Input Events

Your HTML display receives standard browser events from the Screen Input system. Build interfaces like you would for a web browser, and they just work in BeamNG.

**Supported Events:**

- `click` - Mouse click on element
- `mousedown` / `mouseup` - Mouse button press/release
- `mousemove` - Mouse movement, triggers automatic mouseenter/mouseleave
- `mouseenter` / `mouseleave` - Element hover state (with optional automatic `hovered` class)
- `wheel` - Mouse wheel scroll
- `drag` - Drag events with deltaX/deltaY

**Example:**

```javascript
document.getElementById("myButton").addEventListener("click", function (e) {
  console.log("Clicked at:", e.clientX, e.clientY);
  // Handle button click
});
```

**Hover States:**

CSS `:hover` doesn't work with synthesized events because browsers only activate it from their internal cursor tracking. The framework provides two approaches:

1. **Automatic:** Enable `enableHover: true` in your `initScreenInput` call. A `hovered` class will be added on/removed from elements as the cursor moves over them:

```css
.my-button.hovered {
  background: #777;
}
```

2. **Manual:** Use `mouseenter`/`mouseleave` events if you need custom logic:

```javascript
document
  .querySelector(".menu-item")
  .addEventListener("mouseenter", function (e) {
    this.classList.add("hovered");
  });
document
  .querySelector(".menu-item")
  .addEventListener("mouseleave", function (e) {
    this.classList.remove("hovered");
  });
```

**Event Properties:**

All events include standard browser properties:

- `clientX` / `clientY` - Pixel coordinates within the screen
- `button` - Mouse button (0 = left, 1 = middle, 2 = right)
- `target` - DOM element that received the event

### Adding Your Display

```javascript
window.initScreenInput(width, height, screenId, options);
```

**Parameters:**

- `width` - Screen width in pixels (use `config.displayWidth` from jbeam)
- `height` - Screen height in pixels (use `config.displayHeight` from jbeam)
- `screenId` - Unique ID for the display (optional, filters events for this screen only)
- `options` - Configuration object (optional)
  - `enableHover` - Enable automatic `hovered` class toggling (default: false)

**When to use screenId:**

If you have multiple HTML displays in the same vehicle, use `screenId` to ensure each display only receives events meant for it. The ID should match your screen material name (without the `@` symbol).

**Example with options:**

```javascript
window.setup = function (config) {
  window.initScreenInput(
    config.displayWidth,
    config.displayHeight,
    "my_screen",
    { enableHover: true }
  );
};
```

### Calling Vehicle Lua Functions

```javascript
callVehicleLua(functionName, args);
```

Call custom functions you've set up in your vehicle controller. This lets your HTML talk to the vehicle side when you need to trigger something beyond the screen.

**Parameters:**

- `functionName` - Name you registered with `screenInput.registerLuaCallback()`
- `args` - Object with whatever data you want to pass

**Example (HTML):**

```javascript
// Button click sends data to vehicle
document.getElementById("myButton").addEventListener("click", function () {
  callVehicleLua("updateSetting", { value: 42 });
});
```

**Example (Vehicle Lua controller):**

```lua
local function init(jbeamData)
  if screenInput then
    screenInput.registerLuaCallback("updateSetting", function(args)
      -- Do something with args.value
      print("Received value: " .. tostring(args.value))
    end)
  end
end
```

See `vehicles/vivace/lua/controller/triggerExample.lua` for a working example.

### Trigger Events

Trigger volumes fire events when the player interacts with them. Use standard event listeners to handle them:

```javascript
document.addEventListener("beamng:trigger", function (event) {
  const { id, action, duration, deltaX, deltaY } = event.detail;

  if (id === "myTrigger" && action === "click") {
    // Handle the click
  }
});
```

**Event Properties:**

- `id` - Trigger volume identifier
- `action` - Event type ("press", "click", "hold", "drag")
- `duration` - Hold duration in seconds (for "hold" events)
- `deltaX` / `deltaY` - Drag distance (for "drag" events)

**Action-Specific Events:**

Listen for specific action types if you only care about one:

- `beamng:trigger:press` - Fired when trigger is first pressed
- `beamng:trigger:click` - Quick press/release (< 0.5 seconds)
- `beamng:trigger:hold` - Long press (≥ 0.5 seconds, includes duration)
- `beamng:trigger:drag` - Mouse moved while pressed (includes deltaX/deltaY)

**Example:**

```javascript
document.addEventListener("beamng:trigger:click", function (event) {
  if (event.detail.id === "naviButton") {
    openNaviMenu();
  }
});
```

---

## Data Persistence API

The data persistence system effectively allows you to save and manage settings for different user profiles and contexts. It uses hierarchical scoping with automatic merging across levels.

### The Four Scopes

The following four levels (defined as 'scopes') are included:

- `factory` - Factory defaults (immutable baseline)
- `global` - Defaults for the entire model (shared across all vehicles)
- `identifier` - User account or vehicle (defaults to license plate, can be custom)
- `user` - Driver profile within vehicle or account

`identifier` and `user` are branching levels - multiple can exist within the same model. `factory` and `global` can only have one.

The hierarchy is mainly used to allow multiple setting profiles, but actual use cases are examples and can be used creatively.

### Saving Data

```javascript
persistSave(filename, data, scope, userId, identifier);
```

**Parameters:**

- `filename` - JSON file name to save under (without .json extension)
- `data` - Settings object to persist
- `scope` - Which scope to save to (defaults to "global")
- `userId` - User identifier (required for "user" scope)
- `identifier` - Custom identifier (overrides license plate for identifier/user scopes)

**Examples:**

```javascript
// Save model-wide preferences (shared across all vehicles of this model)
persistSave("default_settings", { theme: "dark", volume: 80 });

// Save identifier-specific data (uses license plate by default)
persistSave("trip_computer", { totalMiles: 12500 }, "identifier");

// Save user-specific data (for login/profile systems)
persistSave("preferences", { seat: "memory1" }, "user", "john_doe");
```

### Loading Data

```javascript
persistLoad(filename, callback, scope, userId, identifier);
```

Returns data via callback since Lua -> JS communication is asynchronous.

**Example:**

```javascript
persistLoad(
  "default_settings",
  function (data) {
    if (data) {
      applySettings(data);
    }
  },
  "global"
);
```

### Loading with Hierarchical Merging

```javascript
persistLoadMerged(filename, callback, userId, identifier);
```

Loads and merges data from all scopes: factory -> global -> identifier -> user. This is the recommended way to load settings unless a specific scope's data is required, rather than the most "important."

The callback receives two arguments:

- `data` - The merged settings object
- `sources` - Object mapping top-level keys to their source scope

**Example:**

```javascript
persistLoadMerged(
  "settings",
  function (data, sources) {
    // Apply the merged settings
    applyTheme(data.theme);
    setVolume(data.volume);

    // Show which settings are user-customized
    if (sources.theme === "user") {
      document.getElementById("theme-reset").style.display = "block";
    }
  },
  "john_doe"
);
```

### Checking for Data

```javascript
persistExists(filename, callback, scope, userId, identifier);
```

Checks if a data file exists in the specified scope.

```javascript
persistExists(
  "trip_computer",
  function (exists) {
    if (!exists) {
      // Create default trip data
    }
  },
  "identifier"
);
```

### Deleting Data

```javascript
persistDelete(filename, scope, userId, identifier);
```

Deletes a data file from the specified scope. When a scope's file is deleted, the system falls back to lower-priority scopes.

### Factory Defaults

```javascript
persistRegisterDefaults(filename, defaults);
persistInitDefaults(filename);
```

Register and create factory default files. Factory defaults are immutable - they persist as the "reset to defaults" baseline.

**Example:**

```javascript
// Register factory defaults (in memory)
persistRegisterDefaults("settings", {
  theme: "light",
  volume: 50,
  units: "metric",
});

// Create factory file from registered defaults (if it doesn't exist)
persistInitDefaults("settings");
```

### Resetting to Factory

```javascript
persistResetToFactory(filename, scope, userId, identifier);
```

Resets settings at a specific scope back to factory defaults by deleting the scope's file.

### Getting License Plate

```javascript
getLicensePlate(function (plate) {
  console.log("Vehicle plate:", plate);
});
```

Retrieves the current vehicle's license plate (used as default identifier).

### Listing User Profiles

```javascript
persistListUsers(
  filename,
  function (users) {
    console.log("Available users:", users);
  },
  identifier
);
```

Lists all user IDs that have saved data for a specific file on this identifier.

### Finding Where Settings Come From

```javascript
persistGetSource(filename, key, callback, userId, identifier);
```

Identifies which scope a specific setting key came from in the merged hierarchy. Useful when you need to know whether a value is from factory defaults, global settings, or user customization.

**Example:**

```javascript
persistGetSource(
  "settings",
  "theme",
  function (source) {
    console.log("Theme setting came from:", source); // "factory", "global", "identifier", or "user"
  },
  "john_doe"
);
```

### Calling Vehicle Lua Functions

```javascript
callVehicleLua(functionName, args);
```

Call custom Lua functions you've registered in your vehicle controller. This effectively allows your HTML display to trigger vehicle-side logic without going through the persistence system.

**Example:**

```javascript
// In your HTML
callVehicleLua("playClickSound", { volume: 0.8 });

// In your vehicle Lua controller
screenInput.registerLuaCallback("playClickSound", function(args)
  -- Play sound with args.volume
end)
```

---

## Coordinate Systems

Understanding the coordinate system is key to positioning trigger boxes and volumes correctly.

### Vehicle Coordinates

BeamNG uses the following coordinates (according to the gridmap, assuming default forward is forward):

- **X axis** - Left/right (positive = left)
- **Y axis** - Backward/forward (positive = backward)
- **Z axis** - Up/down (positive = up)

### Absolute vs Relative Coordinates

**Absolute coordinates** are relative to the vehicle's origin (which is usually in the ground below the vehicle).

**Relative coordinates** are relative to a reference plane's position and rotation. This is where reference planes save massive amounts of time, so instead of finding absolute positions for every trigger, you set up a reference plane and use relative coordinates from there.

### Reference Plane Visualization

When debug visualization is enabled (`"drawBoxes": true` in jbeam), reference planes display:

**Position axes (solid lines)** - Where the reference plane is located

- Red = X axis (left/right)
- Green = Y axis (forward/back)
- Blue = Z axis (up/down)
- White rectangle = The reference plane itself

**Movement axes (dashed lines)** - The axes that triggers use when positioned relative to this plane

- Dashed red = X movement direction
- Dashed green = Y movement direction
- Dashed blue = Z movement direction
- This is what XYZ coordinates mean for triggers referencing this plane

**Rotation arcs**

- Cyan = RX (pitch)
- Yellow = RY (yaw)
- Magenta = RZ (roll)

Best way to understand this: enable the visualization and move triggers around while watching how the axes align.

### Rotation Usage

Honestly, rotation is one of those things that just works if you follow the visualization. Enable debug mode and check the arrow direction of the colored arcs, which will show you which way each rotation goes. If something looks wrong, adjust the numbers and see what happens.

---

## Best Practices

### Configuration Organization

**Do:**

- Use `.JSONC` format with comments explaining each trigger's purpose
- Group related triggers in the same file
- Use descriptive IDs for trigger boxes and volumes
- Set up reference planes for anything more complex than a single screen

**Don't:**

- Use `.JSON` alone. It's easy to get lost and confused.
- Mix trigger boxes and trigger volumes in the same array (use separate files)
- Forget the `$configType` property (the system won't find your files without it)
- Use absolute coordinates when reference planes would simplify things

### HTML Development

**Do:**

- Build your interface like a normal web page
- Use standard DOM events (click, mouseenter, etc.)
- Test in a browser first before integrating
- Use `console.log` for debugging (visible in BeamNG console)

**Don't:**

- Mix up screenId between your config files and HTML (they must match exactly)
- Skip browser testing - develop and test your HTML standalone first
- Hardcode pixel positions when CSS layouts can handle responsiveness
- Expect instant results from persistence functions (they're asynchronous, use callbacks)
- Forget to call `initScreenInput()` to register your display

### Data Persistence

**Do:**

- Use `persistLoadMerged()` for settings that support user customization
- Register factory defaults for settings that need reset capability
- Use meaningful scope names that match your use case
- Vary parameter descriptions by function context (not generic "filename" everywhere)

**Don't:**

- Store large data objects (keep it to settings and state)
- Assume identifier is always license plate (it can be custom)
- Mix different data types in the same persistence file

### Debugging Visualizations

The framework includes visual debugging for trigger boxes and reference planes. Enable it by setting `"drawBoxes": true` in the screenInput controller configuration. When enabled, you'll see:

**Colored boxes:**

- Orange = Screen trigger boxes (where clicks get detected)
- Purple = 3D trigger volumes (for physical buttons)
- White rectangle = Reference plane origin

**Axes and rotation arcs:**

- Solid colored lines = Position axes showing where the plane is
- Dashed colored lines = Movement axes showing how XYZ coordinates work
- Curved arcs = Rotation indicators (cyan/yellow/magenta for RX/RY/RZ)

This visualization is invaluable when positioning triggers. You can see exactly where your boxes are and how they're oriented.

---

## Advanced Features

### Multiple Screens

You can have multiple interactive screens in the same vehicle. Each screen needs:

1. Its own `newScreen` controller with unique name and material
2. Trigger boxes with matching `screenId` properties (use controller name)
3. HTML displays that call `initScreenInput()` with matching screen IDs

**Example:**

```json
// Two screen controllers
"controller": [
  ["newScreen", {
    "configuration": {
      "materialName": "@main_screen",
      "htmlPath": "local://local/vehicles/yourcar/displays/infotainment/index.html",
      "displayWidth": 1920,
      "displayHeight": 1080
    }
  }],
  ["newScreen", {
    "configuration": {
      "materialName": "@gauge_cluster",
      "htmlPath": "local://local/vehicles/yourcar/displays/cluster/index.html",
      "displayWidth": 1280,
      "displayHeight": 480
    }
  }]
]
```

### Custom Event Handling

For advanced interactions, you can handle events differently based on context:

```javascript
document.addEventListener("click", function (e) {
  // Check which element was clicked
  if (e.target.classList.contains("nav-button")) {
    handleNavigation(e.target.dataset.page);
  } else if (e.target.classList.contains("slider")) {
    handleSliderClick(e);
  }
});
```

### Dynamic Content

Your HTML display can update dynamically using standard web technologies:

```javascript
// Update from vehicle data
function updateData(data) {
  document.getElementById("speed").textContent = Math.round(
    data.electrics.wheelspeed * 3.6
  );
  document.getElementById("gear").textContent = data.electrics.gear;
}

// Animate transitions
function showPage(pageId) {
  const pages = document.querySelectorAll(".page");
  pages.forEach((p) => p.classList.remove("active"));
  document.getElementById(pageId).classList.add("active");
}
```

---

## Troubleshooting

### Screen not responding to clicks

**Check:**

- Is `initScreenInput()` called in your HTML?
- Does `screenId` match your material name (without `@`)?
- Is the trigger box positioned correctly (enable debug visualization)?
- Is the HTML display actually loading (check BeamNG console)?

### Display looks stretched or cut off

This is almost always a UV mapping issue on your 3D model, not the HTML, CEF, or this framework. HTML materials in BeamNG use UV coordinates to map the texture onto the mesh, so if your UVs are wonky, the display will also look wonky.

**Quick diagnostic:**

Create a simple test in your HTML with a perfect square:

```html
<div
  style="width: 200px; height: 200px; background: red; position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%);"
></div>
```

If that square looks stretched, rectangular, or cut off, your UV map needs fixing. Go back to your 3D modeling software and check that the UV islands for your screen material are properly unwrapped and aligned. The UVs should form a clean rectangle with correct aspect ratio matching your screen resolution.

**What to look for in your UV map:**

- UV island should match the shape of your screen
- Proportions should match your screen aspect ratio
- Overlapping UVs
- UVs should fill the 0-1 texture space

### Trigger boxes in wrong position

**Check:**

- Reference plane position and rotation
- Whether you're using absolute vs relative coordinates
- Rotation order (remember: extrinsic rotations RX -> RY -> RZ)
- Enable debug visualization to see actual box positions

### Configuration files not loading

**Check:**

- Files have `.jsonc` or `.json` extension
- Each file has correct `$configType` property
- `triggerConfigPath` points to the right directory
- No JSON syntax errors (commas, brackets, quotes)

### Data persistence not working

**Check:**

- Calling persistence functions after page loads
- Callback functions are defined properly
- Scope matches what you're trying to load/save
- License plate exists (for identifier scope)

### Rotation looks wrong

Welcome to the club. Rotation is hard. Try:

- Using reference planes to simplify local rotations
- Enabling debug visualization to see actual axes
- Following the arrows that the visualization shows
- Testing with simple rotations first (90°, 45°, etc.)

### Events not firing or wrong screen receiving them

**Check:**

- Does your `screenId` in `initScreenInput()` match the material name?
  - In jbeam: `"materialName": "@my_screen"`
  - In JavaScript: `initScreenInput(1920, 1080, "my_screen")` (no `@`)
- If you have multiple screens, each needs a unique screenId
- Make sure the trigger box's `screenId` matches your screen's material name
- Verify the trigger box is actually positioned over the screen (use debug visualization)

---

## Examples

### Basic Interactive Screen (Vivace)

See `vehicles/vivace/vivace_infotainment/` for a complete working example with:

- Single reference plane for coordinate origin
- Trigger box for the main screen
- Multiple trigger volumes for physical buttons
- Test menu HTML demonstrating the API

This example covers all the core concepts and can be adapted for more complex implementations including multiple screens, additional reference planes, and advanced coordinate transformations.

---

## License

This project is licensed under the MIT License with additional attribution and compatibility requirements. Redistributions or substantial portions of the Framework must include the original copyright notice and attribution to the project's source (https://github.com/TheLeggy/BNG-ScreenInput-Framework/). Modified distributions must take reasonable steps to avoid conflicts with the official distribution and clearly identify that they are modified.

See the `LICENSE` file for the full license text and exact requirements.

---

**Questions or issues?** The code includes extensive comments explaining the "why" behind design decisions. If something seems weird, there's probably a comment explaining that I don't know why it works either.

**mrow~**
