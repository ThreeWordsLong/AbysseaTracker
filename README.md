# AbysseaTracker

An **Ashita v4 addon** to assist with **tracking and identifying Yellow, Blue, and Red stagger procs** for Notorious Monsters (NMs) in Abyssea zones.

---

## Overview

**AbysseaTracker** helps players efficiently identify stagger triggers during Abyssea NM fights by:

- Automatically detecting relevant Notorious Monsters (NMs).
- Tracking player and mob actions to refine the set of valid stagger options.
- Visually displaying remaining proc possibilities and hints via an ImGui interface.

---

## Installation & Usage

### Installation

1. Download or clone the `AbysseaTracker` folder into your **Ashita v4 `addons` directory**:  
   Example path: `/path/to/Ashita/addons/AbysseaTracker`

### Loading the Addon

1. Start **Ashita v4** and log into the game.
2. In-game, use the command `/addon load abysseatracker`
3. Once loaded, the addon will automatically begin tracking NMs when in Abyssea Zones.

- The GUI window will automatically hide/show depending on if an NM is targeted or has enmity towards the party.

---


##  TODO / Known Limitations

- [ ] **Handle NM being immune during casting/readies**  
  When an NM is actively casting or readying an ability, it's often immune to proc triggers. The addon should delay or ignore proc checks during these states.

- [ ] **Improve proc window accuracy on addon reloads**  
  If the addon is reloaded after a mob is already pulled, the timestamp resets, potentially leading to an incorrect proc window being assumed (e.g., wrong day/hour filters).

- [ ] **Retroactive hint validation by logging all actions**  
  To address the above, track all spells/abilities used even if filtered out at the time. If a hint later revalidates the category, we can retroactively check if a valid action was already taken.

---

## How It Works

The addon begins tracking an NM when **any** of the following occurs:

1. A **Rest Message** packet (`0x2A`) is received that maps to a known Abyssea proc message.
2. The **Claim ID** of an NM (from `0x0E` packet) matches a party member.
3. The NM **acts on** or is **acted upon by** a party member (`0x28` Action packet).

Upon tracking, the plugin initializes the mob's stagger pool based on:

- **Yellow Procs** – spells tied to the current and adjacent Vana'diel days.
- **Blue Procs** – physical weapon skills determined by in-game time (blunt, slashing, piercing).
- **Red Procs** – fixed set of elemental weapon skills.

The candidate sets are filtered as actions are performed or system hint messages are received.

---

## Logic Summary

- **Claim Time** is used to seed proc pools (using Vana’diel time and day).
- Spells and WS IDs are mapped from internal lookup tables in `StaggerTables.lua`.
- As combat events occur:
  - Invalid procs are **eliminated** when no stagger is triggered.
  - Hints from system messages **narrow** the proc pool (e.g., “The fiend appears vulnerable to wind magic”).
  - Successful staggers **lock in** the correct action and remove all others of that type.

---

## GUI Features

- Each tracked NM appears as a **tab** in the UI.
- Within each NM tab:
  - Remaining possible spells and WSs are shown.
  - Skill categories and elemental colors are **color-coded**.
  - Time and day of pull (real-time and Vana’diel) are shown to provide context.
  - Helpful summaries of eligible categories for Blue WS are displayed (e.g., “Slashing: Sword, Great Sword”).

---

## Architecture

The addon is modular for clarity and extensibility:

- `AbysseaTracker.lua`: Main entrypoint and event registration.
- `Logger.lua`: Custom debug/info logging with Ashita chat formatting.
- `ZoneManager.lua`: Loads NM names and proc messages from zone DATs.
- `MobManager.lua`: Tracks individual NM status, filters proc pools, and applies hints.
- `PacketManager.lua`: Parses incoming packets (0x0E, 0x28, 0x2A, etc.) and routes them.
- `UIManager.lua`: Renders the ImGui interface.
- `StaggerTables.lua`: Central data mapping for procs (spells, WSs, hints).
- `MessageDat.lua`: Parses localized system messages from DATs for each zone.
- `Helpers.lua`: Time and zone utilities, plus lookup tables.

---

## Commands

| Command         | Description                  |
|-----------------|------------------------------|
| `/at`           | Toggle tracking on/off       |
| `/at help`      | List available commands      |
| `/at debug`     | Toggle debug log level       |

---

## Acknowledgements

Special thanks to:

- **Thorny** – for packet decoding, DAT parsing, and architecture guidance.
- **atom0s** – for Ashita and dev support.
- **Team HXUI** (Tirem, Shuu, colorglut, RheaCloud) – for UI and logic inspiration.
- **cariboulou** – for UI style/color inspiration.

---

## License

GNU GPLv3 – Feel free to modify, distribute, and improve under the terms of the license.
