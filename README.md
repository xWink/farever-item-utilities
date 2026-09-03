# Farever Item Utilities

A collection of inventory, bank, equipment, and item-safety quality-of-life tools for Farever.

## Features

### Bank deposit shortcuts

Adds six deposit buttons beside the bank's Sort button:

- **Deposit all**
- **Deposit crafting materials**
- **Deposit food**
- **Deposit consumables**
- **Deposit demon enchantments**
- **Deposit miscellaneous items**

Deposits use Farever's normal server-validated transfer requests and run sequentially. Locked items are skipped, rejected transfers do not stop the rest of a batch, and processing stops safely when the bank is full.

The deposit buttons can be hidden from the mod settings.

### Item locking

Adds an item-locking mode beside the character inventory's Sort button. Enable edit mode and select inventory items to lock or unlock them.

Locked items are marked with a small metallic padlock and are protected from:

- Selling
- Dropping or discarding
- Depositing into the bank
- Dragging or transferring into the Spark Recycler
- Right-click transfers into the Spark Recycler

Locks follow items as they move between inventory and equipment. They are persisted separately for each character using Farever's unique character ID, with item identity and location tracking to avoid transferring a lock to the wrong identical item.

Locking visuals can be hidden without disabling or deleting saved locks. The settings menu also includes a separately confirmed **Delete all saved locks** action.

An optional **Sorting preserves order of locked items** setting keeps locked items in their existing relative order while sorting and compacting the inventory. This works best when locked items are placed first.

### Weapon presets

Adds three weapon preset buttons and a **Set** button beside **Appearance** on the Character Profile page.

- Preset 1 is selected by default for a new character.
- Select a preset and press **Set** to save the currently equipped weapons.
- Pressing a configured preset immediately equips its saved weapons from the character inventory.
- Activating an unset preset does nothing.
- If one or more saved weapons are missing, available weapons are still equipped and missing entries are skipped safely.
- Presets and the currently selected preset are persisted separately for each character.

Each preset can also be assigned its own configurable keyboard shortcut, including Ctrl, Shift, Alt, or Windows-key combinations. Preset hotkeys work without opening the Character Profile page.

### Settings

Press **F9** to open the settings menu. The settings hotkey is configurable.

Available settings include:

- Enable or disable Item Utilities
- Show or hide bank deposit buttons
- Show or hide item-locking visuals
- Preserve the relative order of locked items while sorting
- Delete all saved locks
- Configure or clear hotkeys for weapon presets 1–3
- Change the settings-menu hotkey

## Requirements

- [HLX Core](https://github.com/hlx-framework/hlx-core)
- The Farever ImGui plugin used by HLX mods with overlay interfaces

## Installation

1. Install HLX Core.
2. Install the Farever ImGui plugin.
3. Download the latest release or successful build artifact.
4. Install the ZIP with Vortex, or extract it directly into the Farever game directory. The archive already contains:
   `hlx/mods/item-utilities/`
5. Launch Farever and press **F9** to configure the mod.

## Building for development

Install Haxe 4.3.7, HLX Runtime, and `hl-imgui`, then run:

```sh
haxe compile.hxml
```

The compiled mod is written to:

```text
build/item-utilities/item-utilities.hl
```
