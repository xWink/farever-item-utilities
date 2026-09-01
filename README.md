# Farever Item Utilities

An extensible collection of inventory, bank, and equipment quality-of-life tools for Farever.

## Current features

- Adds a **Deposit Crafting Materials** button while the bank is open.
- Deposits every `CraftingComponent` item from the character inventory, including inherited material types such as Ore, Leather, and Cloth.
- Uses Farever's normal server-validated transfer requests and processes transfers sequentially.
- Stops safely if the bank is full or a transfer is rejected.
- Includes settings to enable the mod or hide the deposit button.

## Installation

1. Install [HLX Core](https://github.com/hlx-framework/hlx-core).
2. Install the Farever ImGui plugin required by HLX mods with settings menus.
3. Download the latest build artifact. Install the ZIP with Vortex, or extract it directly into the Farever game directory; the archive already contains `hlx/mods/item-utilities/`.
4. Open a bank to use the bank-only utility panel. Press `F9` to open the settings menu.

The settings hotkey can be changed from inside the menu.

## Building (developers)

Install Haxe 4.3.7, HLX Runtime, and `hl-imgui`, then run:

```sh
haxe compile.hxml
```

The compiled mod is written to `build/item-utilities/item-utilities.hl`.

