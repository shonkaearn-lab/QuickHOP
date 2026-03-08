# QuickHoP

Hand of Protection targeting addon for WoW 1.12 / TurtleWoW.

## Installation

**Via Git Addons Manager:**
1. Add `https://github.com/shonkaearn-lab/QuickHoP` and install.

**Manual:**
1. Extract the `QuickHoP` folder into `Interface/AddOns/`.
2. Restart WoW.

---

## For Paladins

### Setup
- **Right-click** the button to set your current target as your HoP target.
- **Left-click** to cast HoP on that target instantly, regardless of what you have targeted.
- The button shows your saved target name, spell icon, and live cooldown.
- Drag the button anywhere to reposition it.

### Controls
| Action | Result |
|---|---|
| Left-click | Cast HoP |
| Right-click | Set current target |
| Alt + Right-click | Clear target |
| Shift + Right-click | Hide UI |
| Ctrl + Left-click | Open options |

### Slash Commands
```
/qhop set       Set current target
/qhop clear     Clear saved target
/qhop cast      Cast HoP
/qhop show      Toggle UI visibility
/qhop status    Print current target to chat
/qhop options   Open options menu
/qhop help      List all commands
```

### Keybinds
**Key Bindings → QuickHoP:**
- Set HoP Target
- Clear HoP Target
- Cast HoP on Target

---

## For Casters (non-Paladins)

When a Paladin saves you as their HoP target, a small button appears on your screen showing the HoP spell icon and cooldown. Click it (or use `/hoprequest`) to signal your Paladin to cast HoP on you.

- **Click** — Send HoP request
- **Ctrl + Click** — Open options
- **Drag** — Reposition
- **Keybind** — Key Bindings → QuickHoP → Request HoP

The button only appears when a Paladin in your group has assigned you as their target. The cooldown shown reflects the Paladin's actual remaining cooldown (accounting for talents/spec).

---

## HoP Request Notifications (Paladins)

When your assigned caster sends a request, you receive one or more alerts. Configure which ones fire in the options menu (`/qhop options`).

| Notification | Default | Description |
|---|---|---|
| Screen Flash | ON | Blue pulse on all four screen edges |
| Center Icon | ON | HoP icon appears center-screen, pulses, draggable |
| Sound | OFF | Plays a raid warning sound |
| Chat Message | OFF | Prints a message to chat |

The center icon auto-dismisses after 5 seconds or when HoP is successfully cast.

---

## Options Menu

Open with `/qhop options` or Ctrl + Left-click either button.

- **HoP Assignments** — See which Paladins in your group are using QuickHoP and who they're protecting.
- **Paladin UI Scale** — Resize the Paladin button (0.5–2.0×).
- **Alert Icon Size** — Resize the center notification icon (0.5–3.0×).
- **Caster Button Size** — Resize the caster request button (0.5–2.0×).
- **Announce HoP** — Optionally post a chat message when HoP is cast. Customisable message (`<n>` = target name), party or raid channel.
- **Notifications** — Toggle screen flash, center icon, sound, and chat message individually.

---

## Party / Raid Sync

Paladins with QuickHoP broadcast their saved target to the group automatically. This is how the options panel shows the full assignment list, and how casters know when to show their request button. No configuration needed — it's always on.

---

## Notes

- Always casts the highest rank of Hand of Protection you have learned.
- Casts on your saved target even if you have something else targeted; restores your previous target after.
- Works solo (no group required) — sync features simply don't activate.
- UI auto-hides for non-Paladins; caster button auto-hides for Paladins.
- Compatible with WoW 1.12, TurtleWoW, and any 1.12-based server.
