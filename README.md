# QuickHoP - Quick Hand of Protection Targeting

A standalone World of Warcraft addon for quickly casting Hand of Protection on a pre-set target.

## Features

- **Set a HoP Target**: Save a specific player as your Hand of Protection target
- **Quick Cast**: Cast HoP on your saved target with a single keybind or button click
- **Visual Feedback**: On-screen messages and UI window to show current target
- **Cooldown Tracking**: Real-time cooldown display showing when HoP is ready
- **Cast Counter**: Track how many times you've cast HoP this session
- **Multi-language Support**: English, German, and French localization
- **Works in Parties and Raids**: Automatically finds your target whether solo, in a party, or raid
- **Interactive UI**: 
  - **Left-click button**: Cast HoP on saved target
  - **Right-click button**: Set current target as HoP target
  - **Shift+Right-click button**: Clear saved target
  - **Hover**: See detailed tooltip with instructions and cooldown

## Installation

1. Download the QuickHoP folder
2. Place it in your `World of Warcraft/Interface/AddOns/` directory
3. Restart WoW or reload UI (`/reload`)

## Usage

### UI Window

The QuickHoP window displays:
- **HoP Icon**: The actual spell icon from your spellbook
- **Target Name**: Shows who you'll cast HoP on (green when set, red when not set)
- **Cooldown Timer**: Real-time countdown showing when HoP is ready
- **Cast Count**: How many times you've used HoP this session

**Button Interactions**:
- **Left-click**: Cast HoP on your saved target
- **Right-click**: Set your current target as the HoP target
- **Shift+Right-click**: Clear the saved HoP target
- **Hover**: View tooltip with full instructions and current status

### Slash Commands

- `/qhop help` - Show all available commands
- `/qhop set` - Set your current target as the HoP target
- `/qhop clear` - Clear the saved HoP target
- `/qhop cast` - Cast Hand of Protection on your saved target
- `/qhop status` - Show who your current HoP target is
- `/qhop toggle` - Show/hide the QuickHoP UI window

### Keybindings

For fastest usage, bind keys in:
**ESC > Key Bindings > QuickHoP**

Available keybinds:
- **Set HoP Target** - Set current target as HoP target
- **Clear HoP Target** - Clear the saved target
- **Cast HoP on Target** - Cast HoP on saved target

### Typical Workflow

1. Target the player you want to protect (usually a clothie, healer, or someone who pulls aggro)
2. Press your "Set HoP Target" keybind or type `/qhop set`
3. During combat, press your "Cast HoP on Target" keybind to instantly cast HoP on them
4. No need to retarget - keeps your current target!

## Examples

**Example 1: Using the UI Window**
1. Open the QuickHoP window (`/qhop toggle` or it opens by default)
2. Target the player you want to protect
3. Right-click the HoP button (target name turns green)
4. During combat, left-click the button to instantly cast HoP on them

**Example 2: Protecting Your Main Tank with Keybinds**
```
/target Maintankname
/qhop set
```
Now you can spam your cast HoP keybind whenever the tank is in trouble.

**Example 3: Protecting a Healer in Raid**
1. Target your healer
2. Right-click the QuickHoP button
3. Watch the cooldown timer
4. When healer pulls aggro, left-click to save them instantly

## Error Messages

The addon will warn you if:
- No HoP target is set
- Your target is out of range
- Your target is not in the raid/party
- Hand of Protection is not in your spellbook

## Credits

Extracted from **PallyPower** by Relar for TurtleWoW

This functionality was originally part of the full PallyPower addon and has been isolated into a standalone addon for players who only want the Hand of Protection targeting feature.

## Version

**Version 1.2**

### Changelog
- **v1.2**: Complete UI overhaul with cooldown tracking, cast counter, and interactive button (left-click to cast, right-click to set target, shift+right-click to clear)
- **v1.1.1**: Fixed OnUpdate error spam (elapsed time parameter handling for WoW 1.12)
- **v1.1**: Fixed self-casting bug - HoP will never cast on yourself unless you explicitly set yourself as the target
- **v1.0**: Initial release

## Compatibility

- **Interface:** 11200 (WoW 1.12 / Vanilla / TurtleWoW)
- **Class:** Paladin only

## License

Free to use and modify. Credit to original PallyPower addon.
