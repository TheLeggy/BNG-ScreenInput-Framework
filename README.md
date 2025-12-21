# ScreenInput Framework - Interactive HTML Displays for BeamNG

**A framework for creating interactive vehicle displays with mouse input**

Making HTML screens in BeamNG actually usable by translating 3D raycasts into standard DOM events. The system effectively allows your HTML displays to behave as if they were running on a tablet, but also provides the flexibility to handle more complex interactions when needed.

---

## The Origin Story

This framework evolved from DaddelZeit's CCF interactive screen system. The original implementation was groundbreaking but had limitations - no rotation support, tedious trigger placement, and each trigger represented a single button that had to be manually positioned. Also, proprietary and with an explicit no use license.

The breakthrough came when I realized coordinate hell could be solved with reference planes. Instead of this:

```json
{
  "pos": { "x": 0.197, "y": -0.185, "z": 0.8 },
  "size": { "x": 0.03, "y": 0.0001, "z": 0.03 },
  "rot": { "x": -18, "y": 0, "z": 6 },
  "id": 8,
  "type": "default"
}
```

You get the idea - absolute positioning for every single trigger. Reference planes changed this to relative coordinates:

```json
{
  "pos": { "x": -0.0825, "y": 0.0, "z": 0.0 },
  "size": { "x": 0.014, "y": 0.0001, "z": 0.0125 },
  "rot": { "x": 90, "y": 0, "z": 0 },
  "id": 1
}
```

Much cleaner. From there, the system evolved to translate 3D raycasts directly into DOM events, effectively turning your HTML into a touchscreen interface. The current version adds data persistence for user profiles, triggers closer to the original implementation for physical buttons, and proper debugging visualization.

---

## What Does This Do?

**Screen Input** provides three main capabilities:

### 1. Interactive HTML Displays

Your HTML displays receive standard browser events (click, mousemove, mouseenter, etc.) from 3D raycasts. Build interfaces like you would for a web browser, and they just work in BeamNG.

### 2. Reference Planes & Coordinate Systems

Define coordinate origins and rotations for your trigger boxes. Instead of manually calculating absolute positions for every trigger, you set up a reference plane and use relative coordinates. This is largely redundant for single-screen use cases, but becomes a massive time saver the moment you have more than one screen or additional trigger volumes.

### 3. Multi-Scope Data Persistence

Save and load data with hierarchical scoping (factory → global → identifier → user). The system effectively allows you to manage settings for different user profiles and contexts, with automatic merging across scopes. It's complex, but also simplifies downstream building by providing native logic and handling.

---

## Features

- **Plug-and-play integration** - Unlike the original system, this is near plug-and-play
- **JSONC support** - Use comments in your configuration files
- **Reference planes** - Relative coordinate positioning with rotation support
- **Trigger boxes** - Screen interaction areas with automatic coordinate translation
- **Trigger volumes** - Physical 3D triggers for buttons, switches, handles
- **Visual debugging** - Reference plane axes and trigger box visualization in-game
- **Data persistence** - Multi-scope settings system with recursive merging
- **Rotation support** - Full 3-axis rotation for screens and triggers

---

## Quick Start

### 1. Add Controllers to Your Vehicle

In your vehicle's jbeam file:

```json
"controller": [
  ["fileName"],
  ["screenInput"],
  ["newScreen", { "name": "your_screen_material" }]
]
"your_screen_material": {
  "materialName": "@your_screen_material",
  "htmlPath": "local://local/vehicles/yourcar/screens/infotainment.html",
  "displayWidth": 1920,
  "displayHeight": 1080
}
```

Note: link `@your_screen_material` to the material that you wish to render the HTML texture on.

### 2. Create Configuration Files

In `vehicles/yourcar/interactive_screen/`, create:

**referencePlane.jsonc** - Your coordinate origin

```jsonc
{
  "$configType": "referencePlane",
  "planes": [
    {
      "id": "0",
      "pos": { "x": 0.25, "y": -0.15, "z": 0.85 },
      "rot": { "x": -15, "y": 0, "z": 0 }
    }
  ]
}
```

**jsScreens.jsonc** - Screen interaction areas

```jsonc
{
  "$configType": "triggerBoxes",
  "boxes": [
    {
      "id": "main_screen",
      "screenId": "your_screen_material",
      "pos": { "x": 0.0, "y": 0.0, "z": 0.0 },
      "scale": 0.2,
      "refPlane": "0"
    }
  ]
}
```

**screenConfigs.jsonc** - Resolution mapping

```jsonc
{
  "$configType": "screenConfig",
  "your_screen_material": {
    "width": 1920,
    "height": 1080
  }
}
```

### 3. Add JavaScript to Your HTML Display

// Add this to your HTML display

```javascript
window.initScreenInput(1920, 1080, "your_screen_material");
```

Now your DOM elements receive standard browser events, such as:

```javascript
document.getElementById("myButton").addEventListener("click", function (e) {});
```

That's it. Your screen now responds to mouse input.

---

## Documentation

See [USER_MANUAL.md](USER_MANUAL.md) for detailed documentation including:

- Configuration file reference
- API documentation
- Advanced features (triggers, data persistence)
- Coordinate system explanation
- Examples and best practices

Complimentary JSDoc included.

---

## Examples

- **Vivace** - Working example in `vehicles/vivace/vivace_infotainment/`

---

## Credits

Built on the concepts from DaddelZeit's CCF interactive screen system.

---

## License

This framework can be used creatively in your BeamNG mods. Attribution appreciated but not required.

---

**mrow~**
