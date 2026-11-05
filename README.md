# ⬡ KingCrystal Client v1.0.0

**Professional Crystal PvP Client for Minecraft Java 1.21.1 · Fabric**

---

## Requirements

| Tool | Version |
|------|---------|
| Java | 21+ |
| Gradle | 8.x (wrapper included) |
| Minecraft | 1.21.1 |
| Fabric Loader | ≥ 0.16.14 |
| Fabric API | 0.102.0+1.21.1 |

---

## Build Instructions

```bash
# Clone or extract the project folder
cd kingcrystal

# Generate Gradle wrapper (first time only)
gradle wrapper

# Build the mod
./gradlew build
```

Output JAR: `build/libs/kingcrystal-1.0.0.jar`

---

## Install

1. Install [Fabric Loader 0.16.14](https://fabricmc.net/use/installer/) for Minecraft 1.21.1
2. Install [Fabric API 0.102.0+1.21.1](https://modrinth.com/mod/fabric-api)
3. Drop `kingcrystal-1.0.0.jar` into `.minecraft/mods/`
4. Launch Minecraft with the Fabric profile

---

## Controls

| Key | Action |
|-----|--------|
| `Right Shift` | Open / Close ClickGUI |
| `C` (in GUI) | Cycle accent color themes |
| `ESC` (in GUI) | Close GUI |
| Mouse Left | Toggle module |
| Mouse Right | Expand settings |
| Scroll | Scroll module list |

---

## ClickGUI Features

- **Dark Pro** theme: black background, Neon Purple + Crystal Blue accents
- Category tabs: HUD · Combat · Visual · Misc
- Live module search
- Right-click any module to expand its settings panel
- Sliders, toggles, dropdowns, color swatches
- Real-time FPS + Ping + MC version in header
- Smooth easeOutQuart open animation
- 4 built-in accent color themes (press `C` to cycle)

---

## Modules

### HUD
| Module | Description |
|--------|-------------|
| Crystal Counter | Live End Crystal count in world |
| Crystal HUD | Full Crystal PvP panel (crystals, obsidian, totems) |
| Target HUD | Nearest player: health bar, HP, distance |
| Totem Counter | Totem count with pop flash notification |
| Armor HUD | Armor items with durability bars |
| Inventory HUD | Hotbar / full inventory overlay |
| CPS Counter | Left + Right clicks per second |
| FPS Display | Current FPS with color coding |
| Ping Display | Server latency with color coding |
| Keybind HUD | Active module keybinds overlay |

### Visual
| Module | Description |
|--------|-------------|
| Custom Crosshair | Cross / Dot / Circle / Plus styles, configurable size, color |
| Crystal Visuals | ESP boxes + tracers on End Crystals |
| Damage Indicator | Floating damage numbers on hit |

---

## Config

Saved automatically to:
```
.minecraft/config/kingcrystal/modules.json
```

Reloaded on next game launch.

---

## Project Structure

```
src/main/java/dev/kingcrystal/
├── KingCrystalClient.java       # Mod entrypoint
├── config/
│   └── ConfigManager.java       # JSON save/load
├── event/
│   ├── EventBus.java            # Annotation-based event dispatcher
│   ├── Event.java
│   ├── EventHandler.java
│   ├── Cancellable.java
│   └── events/
│       ├── TickEvent.java
│       ├── RenderHudEvent.java
│       └── RenderWorldEvent.java
├── gui/
│   └── ClickGUI.java            # Full ClickGUI screen
├── mixin/
│   ├── InGameHudMixin.java      # HUD render hook
│   ├── GameRendererMixin.java   # World render hook
│   └── MinecraftClientMixin.java # Save-on-close hook
├── modules/
│   ├── Module.java              # Base module class
│   ├── ModuleManager.java       # Registry + tick dispatcher
│   ├── settings/
│   │   ├── Setting.java
│   │   ├── BooleanSetting.java
│   │   ├── SliderSetting.java
│   │   ├── ModeSetting.java
│   │   └── ColorSetting.java
│   └── hud/
│       ├── CrystalCounterModule.java
│       ├── CrystalHudModule.java
│       ├── TargetHudModule.java
│       ├── TotemCounterModule.java
│       ├── ArmorHudModule.java
│       ├── InventoryHudModule.java
│       ├── CpsCounterModule.java
│       ├── FpsDisplayModule.java
│       ├── PingDisplayModule.java
│       ├── KeybindHudModule.java
│       ├── CustomCrosshairModule.java
│       ├── CrystalVisualsModule.java
│       └── DamageIndicatorModule.java
└── util/
    ├── RenderUtil.java          # 2D draw helpers
    └── RenderUtil3D.java        # 3D box / tracer rendering
```

---

## Extending

Add a new module in 3 steps:

1. Create `src/.../modules/hud/MyModule.java` extending `Module`
2. Register it in `ModuleManager.registerModules()`
3. Add `@EventHandler` methods for `RenderHudEvent`, `TickEvent`, etc.

---

Built by Olivia — https://discord.gg/ojailbreaks
