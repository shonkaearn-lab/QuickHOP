# QuickHoP Installation Guide

## Quick Start

1. **Download all files** from this folder
2. **Create a folder** named `QuickHoP` in your WoW addons directory:
   - Path: `World of Warcraft/Interface/AddOns/QuickHoP/`
3. **Place all files** into the QuickHoP folder
4. **Restart** World of Warcraft or type `/reload` in-game

## File Structure

Your folder should look like this:
```
World of Warcraft/
└── Interface/
    └── AddOns/
        └── QuickHoP/
            ├── QuickHoP.toc
            ├── QuickHoP.lua
            ├── QuickHoP.xml
            ├── Bindings.xml
            ├── localization.lua
            └── README.md
```

## First Time Setup

1. **In-game**, you should see a message: "QuickHoP version 1.0 loaded successfully!"

2. **Set up keybindings:**
   - Press `ESC`
   - Click "Key Bindings"
   - Scroll down to find "QuickHoP"
   - Bind keys for:
     - "Set HoP Target" (e.g., `CTRL+F1`)
     - "Cast HoP on Target" (e.g., `CTRL+F2`)
     - "Clear HoP Target" (optional)

3. **Test it out:**
   - Target a friendly player
   - Press your "Set HoP Target" keybind
   - You should see: "HoP target set to: [PlayerName]"
   - Press your "Cast HoP on Target" keybind to cast HoP on them

## Commands

- `/qhop help` - List all commands
- `/qhop toggle` - Show/hide UI window
- `/qhop set` - Set target
- `/qhop clear` - Clear target
- `/qhop cast` - Cast HoP
- `/qhop status` - Check current target

## Troubleshooting

**Addon doesn't load:**
- Make sure the folder is named exactly `QuickHoP`
- Check that all files are in the folder
- Try `/reload` in-game

**Can't find keybindings:**
- Make sure you're logged in as a Paladin
- Check the "QuickHoP" section in Key Bindings menu

**HoP won't cast:**
- Make sure you have Hand of Protection in your spellbook
- Check your target is in range and in your party/raid
- Verify you've set a target with `/qhop set`

## For TurtleWoW Players

This addon is specifically updated for TurtleWoW and should work perfectly with patch 1.17.2+.

Enjoy protecting your allies! 🛡️
