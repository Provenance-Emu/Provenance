### Fixed
- **Scaling mode for Dolphin, PPSSPP and the RetroArch wrapper** — These cores draw into their own view, so the Scaling picker had no effect on them. Stretch now maps to Dolphin's "Stretch to Window" (when its Aspect Ratio option is Auto), to PPSSPP's stretch and integer-scale display flags, and to RetroArch's full-viewport aspect and integer scale; changes apply mid-game
- **Dolphin Aspect Ratio option** — "Force 4:3" and "Force 16:9" were swapped; each now selects the ratio it names
