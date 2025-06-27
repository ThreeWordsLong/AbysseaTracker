# AbysseaTracker

An Ashita v4 addon to help track Yellow, Blue, and Red stagger procs on Notorious Monsters (NMs) in Abyssea zones.

---

##  Overview

**AbysseaTracker** is designed to monitor and manage proc tracking during Abyssea fights. It identifies Notorious Monsters (NMs) in the area and tracks actions made against them, filtering possible Yellow (magic), Blue (physical WS), and Red (elemental WS) stagger triggers as the fight progresses.

---

##  How It Works

The addon begins tracking an NM when **any** of the following conditions are met:

1. **Incoming proc message** in which the NM is the actor (`0x2A` packet).
2. **Claim ID** from `0x0E`, in which the Claim ID belongs to a party member.
3. **Any combat actions** to or from party members are registered agaisnt the NM.

Once a mob is tracked, the addon initializes a full list of eligible:

- **Spells** for Yellow stagger  
- **Physical weapon skills** for Blue stagger  
- **Elemental weapon skills** for Red stagger

As actions are performed or hints are received, the addon dynamically filters out invalid options, narrowing the list of potential procs.

---

##  Logic Summary

- **Pull time** is assumed as the moment a mob begins tracking.
- Eligible procs are pulled from internal data tables (based on spell IDs, WS IDs, and their element/skill mappings).
- Possibilities are eliminated when:
  - An action is performed and does **not** result in a proc.
  - A system message provides a hint (e.g., element or skill type).
- UI components display the remaining possible actions, helping to guide proc attempts.

---

##  Acknowledgements

Special thanks to:

- **Thorny** – for general development help and DAT processing  
- **atom0s** – for the Ashita platform, dev support,  
- **Team HXUI** – for inspiration and utility patterns used in parts of the code  

---
