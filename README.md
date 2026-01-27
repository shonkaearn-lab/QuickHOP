# QuickHoP

Quick Hand of Protection targeting addon for World of Warcraft 1.12 (Vanilla) and TurtleWoW.

## Features

- **One-Click HoP Casting**: Set a target once, cast HoP instantly with a single click
- **Visual UI**: Compact, draggable interface showing your target and cooldown
- **Highest Rank Detection**: Always casts the highest rank of Hand of Protection you have
- **Keybindings**: Bind keys for setting target, clearing target, and casting
- **Party/Raid Sync**: See what other paladins with QuickHoP are protecting
- **Macro Support**: Use `/qhop` commands in macros for advanced functionality

## Installation

### Via Git Addons Manager (Recommended)
1. Install [Git Addons Manager](https://github.com/beholder-rpa/git-addons-manager) for TurtleWoW
2. Add addon: `https://github.com/shonkaearn-lab/QuickHoP`
3. Click Install
4. Restart WoW

### Manual Installation
1. Download the latest release
2. Extract the `QuickHoP` folder to `Interface/AddOns/`
3. Restart WoW

## Usage

### Main UI Controls

The main UI shows your HoP target, the spell icon, and cooldown timer.

- **Left-click**: Cast HoP on your saved target
- **Right-click**: Set current target as HoP target
- **Alt+Right-click**: Clear saved target
- **Shift+Right-click**: Hide UI
- **Ctrl+Left-click**: Open options menu
- **Drag**: Click and drag anywhere on the UI to move it

### Slash Commands

- `/qhop set` - Set your current target as HoP target
- `/qhop clear` - Clear your saved HoP target
- `/qhop cast` - Cast HoP on your saved target
- `/qhop show` - Toggle UI visibility
- `/qhop options` - Open options menu
- `/qhop help` - Show help

### Keybindings

Go to **Key Bindings > QuickHoP** to set up hotkeys:
- Set HoP Target
- Clear HoP Target
- Cast HoP on Target

## How It Works

1. **Set a target**: Right-click the UI (or use `/qhop set`) while targeting someone
2. **Cast HoP**: Left-click the UI (or use `/qhop cast`) to instantly cast HoP on that person
3. **No target needed**: The addon finds and casts on your saved target even if you're targeting something else

## Party/Raid Sync

If multiple paladins in your party/raid use QuickHoP:
- Each paladin's HoP target is shared automatically
- Open the options menu to see who is protecting whom

## Target Finding

You can set anyone as your HoP target and the addon will find them as long as they're:
- Friendly
- Alive+
- Within 30 yards

## FAQ

**Q: Can I cast on myself?**  
A: Yes! Target yourself and right-click to set, or left-click when you have yourself targeted.

**Q: Does it work outside of party/raid?**  
A: Yes! You can set anyone as your target, even if they're not in your group.

**Q: Which rank does it cast?**  
A: Always the highest rank you have learned.

**Q: Can I see other paladins' targets?**  
A: Yes, if they also use QuickHoP. Open the options menu to see the party/raid list.

**Q: How do I hide the UI?**  
A: Shift+Right-click the UI, or use `/qhop show`

**Q: The UI is too big/small**  
A: Ctrl+Left-click to open options, then adjust the UI Scale slider.

## Compatibility

- **Client**: WoW 1.12 (Vanilla)
- **Server**: TurtleWoW, any 1.12 server
- **Class**: Paladin only (UI auto-hides for other classes)

