//
//  SettingsSearchIndex+Entries.swift
//  PVUI
//
//  The hand-maintained rows of the Settings search index. Kept as a data table, so long lines are fine.
//

import PVUIBase

extension SettingsSearchIndex {
    // MARK: Index data

    private static func entry(
        _ id: String,
        _ title: String,
        _ subtitle: String?,
        _ tab: SettingsTab,
        _ section: String,
        keywords: [String] = [],
        tvOS: Bool = true,
        iOS: Bool = true,
        hiddenInAppStore: Bool = false
    ) -> SettingsSearchEntry {
        SettingsSearchEntry(
            id: id, title: title, subtitle: subtitle, keywords: keywords, tab: tab, section: section,
            isAvailableOnTVOS: tvOS, isAvailableOnIOS: iOS, hiddenInAppStore: hiddenInAppStore
        )
    }

    static let entries: [SettingsSearchEntry] = general + emulation + controller + advanced + about

    // MARK: General

    private static let general: [SettingsSearchEntry] = [
        entry("app.systems", "Systems", "Information on system cores, their bioses, links and stats.",
              .general, SettingsSectionTitle.app, keywords: ["console", "bios", "platform", "core"]),
        entry("app.cores", "Cores", "Emulator cores provided by these projects.",
              .general, SettingsSectionTitle.app, keywords: ["emulator", "libretro", "project"]),
        entry("app.theme", "Theme", "Color palette of the app.",
              .general, SettingsSectionTitle.app, keywords: ["appearance", "color", "palette", "dark", "light", "style"]),
        entry("app.icon", "Change App Icon", nil,
              .general, SettingsSectionTitle.app, keywords: ["icon", "home screen", "logo"], tvOS: false),

        entry("library.appearance", "Appearance", "Visual options for Game Library",
              .general, SettingsSectionTitle.library, keywords: ["artwork", "grid", "list", "covers", "sort", "layout", "theme"]),
        entry("library.migration", "Import from Another Emulator", "Bring your games and saves over from another emulator app.",
              .general, SettingsSectionTitle.library, keywords: ["migrate", "migration", "delta", "retroarch", "transfer", "import"]),

        entry("libman.cloudsync", "Cloud Sync Settings", "Manage CloudKit and iCloud Drive sync settings.",
              .general, SettingsSectionTitle.libraryManagement, keywords: ["icloud", "sync", "cloudkit", "backup", "devices"]),
        entry("libman.backup", "Backup & Restore", "Manually back up and restore saves, database, and artwork.",
              .general, SettingsSectionTitle.libraryManagement, keywords: ["export", "import", "zip", "archive", "icloud"]),
        entry("libman.importsaves", "Import Saves", "Import a save bundle or battery save from a .zip, .sav, .srm, or .ram file.",
              .general, SettingsSectionTitle.libraryManagement, keywords: ["battery", "sram", "save file", "restore"]),
        entry("libman.artworkmatcher", "Batch Artwork Matcher", "Find and apply artwork for multiple games at once.",
              .general, SettingsSectionTitle.libraryManagement, keywords: ["cover", "box art", "images", "metadata"]),
        entry("libman.autonormalize", "Auto-Normalize Titles on Import", "Strip region/revision tags from ROM filenames (e.g. '(USA)', '[!]') when importing.",
              .general, SettingsSectionTitle.libraryManagement, keywords: ["rename", "clean", "region", "names"]),
        entry("libman.unsupportedcores", "Show Unsupported Cores", "Display experimental and unsupported cores.",
              .general, SettingsSectionTitle.libraryManagement, keywords: ["experimental", "beta", "hidden"]),
        entry("libman.normalizelibrary", "Normalize Existing Library", "Preview and clean up ROM annotation tags from current library titles.",
              .general, SettingsSectionTitle.libraryManagement, keywords: ["rename", "clean", "titles", "region"]),
        entry("libman.scanroms", "Scan ROM Directories", "Import new ROMs and update metadata without changing custom artwork or names.",
              .general, SettingsSectionTitle.libraryManagement, keywords: ["reimport", "rescan", "refresh", "games", "import"]),
        entry("libman.updatemetadata", "Update Game Metadata", "Re-fetch artwork and info from the database. Custom artwork and names are preserved.",
              .general, SettingsSectionTitle.libraryManagement, keywords: ["refresh", "artwork", "info", "database"]),
        entry("libman.cleararticache", "Clear Artwork Cache", "Delete cached artwork to free up space. Images re-download automatically.",
              .general, SettingsSectionTitle.libraryManagement, keywords: ["images", "storage", "space", "covers"]),
        entry("libman.reset", "Reset Library", "Delete all game data, settings, and custom artwork, then re-import from scratch.",
              .general, SettingsSectionTitle.libraryManagement, keywords: ["delete", "wipe", "erase", "factory"])
    ]

    // MARK: Emulation

    private static let emulation: [SettingsSearchEntry] = [
        entry("core.language", "Core Language", "Language used by emulator cores. Default follows device locale.",
              .emulation, SettingsSectionTitle.coreOptions, keywords: ["locale", "translation"]),
        entry("core.options", "Core Options", "Configure emulator core settings.",
              .emulation, SettingsSectionTitle.coreOptions, keywords: ["core settings", "per core", "options"]),

        entry("saves.autosave", "Auto Save", "Auto-save game state on close. Must be playing for 30 seconds more.",
              .emulation, SettingsSectionTitle.saves, keywords: ["autosave", "save state", "automatic"]),
        entry("saves.autoload", "Auto Load Saves", "Automatically load the last save of a game if one exists. Disables the load prompt.",
              .emulation, SettingsSectionTitle.saves, keywords: ["autoload", "resume", "save state"]),
        entry("saves.asktoload", "Ask to Load Saves", "Prompt to load last save if one exists. Off always boots from BIOS unless auto load saves is active.",
              .emulation, SettingsSectionTitle.saves, keywords: ["prompt", "resume", "load state"]),
        entry("saves.timed", "Timed Auto Saves", "Periodically create save states while you play.",
              .emulation, SettingsSectionTitle.saves, keywords: ["autosave", "interval", "periodic", "save state"]),
        entry("saves.interval", "Auto-save Time", "Minutes between timed auto saves.",
              .emulation, SettingsSectionTitle.saves, keywords: ["autosave", "interval", "minutes", "timer"], tvOS: false),

        entry("audio.headphones", "Pause on Headphones Disconnect", "Auto-pause emulation when AirPods or Bluetooth headphones disconnect.",
              .emulation, SettingsSectionTitle.audio, keywords: ["airpods", "bluetooth", "unplug", "pause"]),
        entry("audio.silent", "Respect Silent Mode", "Disable game audio when system ringer is muted.",
              .emulation, SettingsSectionTitle.audio, keywords: ["mute", "ringer", "switch", "sound"], tvOS: false),
        entry("audio.volume", "Volume", "Game audio volume.",
              .emulation, SettingsSectionTitle.audio, keywords: ["loud", "sound", "level"], tvOS: false),
        entry("audio.engine", "Audio Engine", "Configure audio engine, buffer and latency settings.",
              .emulation, SettingsSectionTitle.audio, keywords: ["buffer", "latency", "crackle", "stutter", "sample rate"]),

        entry("video.vsync", "V-Sync", "Synchronizes the rendering frame rate with the monitor refresh rate.",
              .emulation, SettingsSectionTitle.video, keywords: ["vsync", "tearing", "refresh", "fps", "frame rate"]),
        entry("video.multithreaded", "Multi-threaded Rendering", "Improves performance but may cause graphical glitches.",
              .emulation, SettingsSectionTitle.video, keywords: ["opengl", "performance", "threads", "gl"]),
        entry("video.multisampling", "4X Multisampling GL", "Smoother graphics at the cost of performance.",
              .emulation, SettingsSectionTitle.video, keywords: ["msaa", "anti-aliasing", "antialiasing", "jaggies"]),
        entry("video.scaling", "Scaling Mode", nil,
              .emulation, SettingsSectionTitle.video, keywords: ["aspect ratio", "stretch", "integer", "fill", "fit", "4:3", "resize", "zoom"]),
        entry("video.region", "System Region", "Force a console region for region-aware cores (Sega Saturn).",
              .emulation, SettingsSectionTitle.video, keywords: ["japan", "usa", "europe", "ntsc", "pal"]),
        entry("video.smoothing", "Image Smoothing", "Smooth scaled graphics. Off for sharp pixels.",
              .emulation, SettingsSectionTitle.video, keywords: ["bilinear", "nearest", "pixel", "sharp", "blur", "filter"]),
        entry("video.fps", "FPS Counter", "Show frames per second counter.",
              .emulation, SettingsSectionTitle.video, keywords: ["fps", "frame rate", "performance", "overlay"]),
        entry("video.filters", "Display Filters", "Configure CRT and LCD filter effects.",
              .emulation, SettingsSectionTitle.video, keywords: ["crt", "lcd", "shader", "filter", "scanlines", "scanline"]),
        entry("video.externaldisplay", "External Display", "Configure how the game appears on a connected TV or monitor.",
              .emulation, SettingsSectionTitle.video, keywords: ["airplay", "hdmi", "tv", "monitor", "second screen"], tvOS: false),

        entry("recording.settings", "Recording & Streaming", "Configure microphone, auto-save, HUD button, and clip duration.",
              .emulation, SettingsSectionTitle.recording, keywords: ["record", "screen recording", "clip", "microphone", "stream", "video capture"], tvOS: false),

        entry("cheevos.settings", "RetroAchievements", "Log in and manage RetroAchievements.",
              .emulation, SettingsSectionTitle.retroAchievements, keywords: ["cheevos", "achievements", "trophies", "hardcore", "login", "ra"])
    ]

    // MARK: Controller

    private static let controller: [SettingsSearchEntry] = [
        entry("ctrl.guide", "Controller Guide", "Supported controllers, pairing steps, and platform notes.",
              .controller, SettingsSectionTitle.controller, keywords: ["pair", "bluetooth", "gamepad", "help"]),
        entry("ctrl.selection", "Controller Selection", "Configure external controller mappings.",
              .controller, SettingsSectionTitle.controller, keywords: ["gamepad", "remap", "mapping", "buttons", "player"]),
        entry("ctrl.icade", "iCade / 8Bitdo", "Configure iCade and 8Bitdo controller settings.",
              .controller, SettingsSectionTitle.controller, keywords: ["arcade", "cabinet"]),
        entry("ctrl.m30", "Use 8BitDo M30 Mapping", "For use with Sega Genesis/Mega Drive, Sega/Mega CD, 32X, Saturn and the PC Engine",
              .controller, SettingsSectionTitle.controller, keywords: ["8bitdo", "genesis", "saturn", "pc engine", "mapping"]),
        entry("ctrl.pausebutton", "Pause/Menu button opens pause menu", "If on, the start/menu button on the controller will open the pause menu in addition to pausing the game",
              .controller, SettingsSectionTitle.controller, keywords: ["start", "menu", "home", "pause"]),
        entry("ctrl.stylenav", "Controller-Style Navigation", "Use the TV-style, keyboard/controller-driven library UI when a hardware keyboard is connected.",
              .controller, SettingsSectionTitle.controller, keywords: ["keyboard", "tv", "library", "navigation"], tvOS: false),
        entry("ctrl.mouse", "Mouse Input", "Configure input source and sensitivity for mouse emulation",
              .controller, SettingsSectionTitle.controller, keywords: ["light gun", "lightgun", "trackball", "touchpad", "sensitivity", "cursor"]),
        entry("ctrl.keyboardmapping", "Keyboard Mapping", "Remap keyboard keys to controller buttons.",
              .controller, SettingsSectionTitle.controller, keywords: ["keys", "remap", "hardware keyboard"], tvOS: false),

        entry("haptics.feedback", "Haptic Feedback", "Vibrate when pressing on-screen buttons.",
              .controller, SettingsSectionTitle.hapticsRumble, keywords: ["vibration", "vibrate", "taptic", "touch"], tvOS: false),
        entry("haptics.rumble", "Game Rumble", "Master on/off for all in-game rumble events from emulator cores.",
              .controller, SettingsSectionTitle.hapticsRumble, keywords: ["rumble", "vibration", "force feedback", "motors"]),
        entry("haptics.device", "Device Taptic Engine", "Use the iPhone/iPad Taptic Engine for in-game rumble when no controller is connected.",
              .controller, SettingsSectionTitle.hapticsRumble, keywords: ["rumble", "vibration", "iphone", "ipad"], tvOS: false),
        entry("haptics.motors", "Controller Motors", "Fire rumble motors on DualSense, Xbox, Switch Pro, and DualShock 4 controllers.",
              .controller, SettingsSectionTitle.hapticsRumble, keywords: ["rumble", "vibration", "xbox", "playstation", "switch pro"]),
        entry("haptics.triggers", "DualSense Adaptive Triggers", "Apply per-system trigger resistance profiles on PS5 DualSense controllers.",
              .controller, SettingsSectionTitle.hapticsRumble, keywords: ["ps5", "trigger", "resistance", "playstation"]),
        entry("haptics.intensity", "Controller Rumble Intensity", "Motor strength for DualSense, Xbox, Switch, and DualShock 4 controllers.",
              .controller, SettingsSectionTitle.hapticsRumble, keywords: ["rumble", "vibration", "strength", "slider"]),
        entry("haptics.profiles", "Rumble Profiles", "Customize per-system and per-controller haptic profiles.",
              .controller, SettingsSectionTitle.hapticsRumble, keywords: ["rumble", "vibration", "haptic"]),
        entry("haptics.test", "Test Rumble", "Fire a short test rumble on connected controllers.",
              .controller, SettingsSectionTitle.hapticsRumble, keywords: ["rumble", "vibration", "try"]),

        entry("dualsense.lightbar", "Controller Light Bar", "Show a per-system color on the DualSense / DS4 light bar.",
              .controller, SettingsSectionTitle.dualSense, keywords: ["led", "ds4", "dualshock", "color", "playstation"]),
        entry("dualsense.mic", "Mic Button Action", "Action performed when the DualSense microphone button is pressed.",
              .controller, SettingsSectionTitle.dualSense, keywords: ["microphone", "mute", "ps5"]),

        entry("onscreen.opacity", "Controller Opacity", "On-screen controller transparency.",
              .controller, SettingsSectionTitle.onScreenControls, keywords: ["transparency", "touch controls", "skin"], tvOS: false),
        entry("onscreen.scale", "Controller Scale", "Scales on-screen controls and adjusts the game viewport so nothing clips or overlaps.",
              .controller, SettingsSectionTitle.onScreenControls, keywords: ["size", "touch controls", "zoom"], tvOS: false),
        entry("onscreen.autohide", "Auto-Hide with Controller", "Hide on-screen controls when a physical game controller is connected.",
              .controller, SettingsSectionTitle.onScreenControls, keywords: ["gamepad", "touch controls", "hide"], tvOS: false),
        entry("onscreen.colors", "Button Colors", "Show colored buttons matching original hardware.",
              .controller, SettingsSectionTitle.onScreenControls, keywords: ["tint", "touch controls"], tvOS: false),
        entry("onscreen.rightshoulders", "All Right Shoulder Buttons", "Show all shoulder buttons on the right side.",
              .controller, SettingsSectionTitle.onScreenControls, keywords: ["l1", "r1", "l2", "r2", "bumpers", "triggers"], tvOS: false),
        entry("onscreen.vibration", "Haptic Feedback", "Vibrate when pressing on-screen buttons.",
              .controller, SettingsSectionTitle.onScreenControls, keywords: ["vibration", "vibrate", "touch controls", "taptic"], tvOS: false),
        entry("onscreen.missingbuttons", "Missing Buttons Always On", "Always show buttons not present on original hardware.",
              .controller, SettingsSectionTitle.onScreenControls, keywords: ["touch controls", "extra buttons"], tvOS: false),
        entry("onscreen.joystick", "On-Screen Joystick", "Show a touch Joystick pad on supported systems.",
              .controller, SettingsSectionTitle.onScreenControls, keywords: ["analog", "stick", "touch controls", "joypad"], tvOS: false),
        entry("onscreen.joystickkeyboard", "On-Screen Joypad with keyboard", "Show a touch Joystick pad on supported systems when the P1 controller is 'Keyboard'.",
              .controller, SettingsSectionTitle.onScreenControls, keywords: ["analog", "stick", "ipad", "n64", "psx"], tvOS: false),
        entry("onscreen.movable", "Movable Buttons", "Allow player to move on screen controller buttons. Tap with 3-fingers 3 times to toggle.",
              .controller, SettingsSectionTitle.onScreenControls, keywords: ["reposition", "drag", "layout", "touch controls"], tvOS: false),
        entry("onscreen.sticky", "Sticky Buttons", "Double-tap a button to lock it held down. Double-tap again to release.",
              .controller, SettingsSectionTitle.onScreenControls, keywords: ["hold", "lock", "auto-run", "touch controls"], tvOS: false),

        entry("deadzone.universal", "Universal Deadzone", "Dead region at center of analog sticks (0 = off). Applied on top of hardware deadzoning.",
              .controller, SettingsSectionTitle.analogDeadzone, keywords: ["deadzone", "dead zone", "analog", "stick", "drift"]),
        entry("deadzone.mode", "Core Deadzone Mode", "Auto, Universal, or Core-Managed.",
              .controller, SettingsSectionTitle.analogDeadzone, keywords: ["deadzone", "dead zone", "analog", "stick", "drift"]),
        entry("deadzone.compat", "Core Compatibility", "Which cores coordinate with the universal deadzone.",
              .controller, SettingsSectionTitle.analogDeadzone, keywords: ["deadzone", "dead zone", "support"]),

        entry("skins.mode", "Skin Mode", nil,
              .controller, SettingsSectionTitle.deltaSkins, keywords: ["delta skin", "theme", "overlay", "controller skin"], tvOS: false),
        entry("skins.select", "Select Controller Skins", "Choose controller skins for each system and orientation.",
              .controller, SettingsSectionTitle.deltaSkins, keywords: ["delta skin", "theme", "portrait", "landscape", "skin"], tvOS: false),
        entry("skins.manage", "Manage Controller Skins", "View, import, and delete controller skins.",
              .controller, SettingsSectionTitle.deltaSkins, keywords: ["delta skin", "import", "delete", "skin"], tvOS: false),
        entry("skins.browser", "Skin Browser", "Browse and download skins from the community catalog.",
              .controller, SettingsSectionTitle.deltaSkins, keywords: ["delta skin", "download", "catalog", "skin", "deltastyles"], tvOS: false),
        entry("skins.docs", "Skin Documentation", "Learn how to create and install controller skins.",
              .controller, SettingsSectionTitle.deltaSkins, keywords: ["delta skin", "guide", "create", "help", "skin"], tvOS: false),
        entry("skins.sound", "Button Sound Effect", nil,
              .controller, SettingsSectionTitle.deltaSkins, keywords: ["click", "audio", "touch controls", "skin"], tvOS: false),
        entry("skins.effect", "Button Effect Style", nil,
              .controller, SettingsSectionTitle.deltaSkins, keywords: ["press", "animation", "touch controls", "skin"], tvOS: false),
        entry("skins.deltastyles", "Visit DeltaStyles.com", "Download more skins from the DeltaStyles website.",
              .controller, SettingsSectionTitle.deltaSkins, keywords: ["delta skin", "download", "skin", "web"], tvOS: false)
    ]

    // MARK: Advanced

    private static let advanced: [SettingsSearchEntry] = [
        entry("adv.autojit", "Auto JIT", "Automatically enable JIT when available.",
              .advanced, SettingsSectionTitle.advanced, keywords: ["jit", "just in time", "dynarec", "performance", "debugger"], hiddenInAppStore: true),
        entry("adv.autolock", "Disable Auto Lock", "Prevent device from auto-locking during gameplay.",
              .advanced, SettingsSectionTitle.advanced, keywords: ["sleep", "screen timeout", "idle", "display"]),
        entry("adv.icloudsync", "iCloud Sync", "Sync save states and settings across devices.",
              .advanced, SettingsSectionTitle.advanced, keywords: ["icloud", "sync", "backup", "cloudkit", "devices"], hiddenInAppStore: true),
        entry("adv.opengl", "OpenGL Renderer", "Use OpenGL instead of Metal renderer for legacy graphics filters. Not all cores are supported.",
              .advanced, SettingsSectionTitle.advanced, keywords: ["metal", "gl", "graphics", "shader", "filter"]),
        entry("adv.uimode", "UI Mode", "Choose between different UI modes.",
              .advanced, SettingsSectionTitle.advanced, keywords: ["interface", "layout", "library", "home"]),
        entry("adv.modernwebserver", "Use Modern Web Server", "Opt in to the native Swift Hummingbird HTTP / WebDAV server.",
              .advanced, SettingsSectionTitle.advanced, keywords: ["webdav", "http", "wifi", "transfer", "import", "gcdwebserver"]),
        entry("adv.sram", "SRAM Import / Export", "Show explicit battery-save import and export actions in the game context menu.",
              .advanced, SettingsSectionTitle.advanced, keywords: ["battery", "save", "backup", "srm"], tvOS: false),
        entry("adv.casecompanion", "Case Companion Skins", "Auto-load phone-case companion DeltaSkins when a known case controller is connected.",
              .advanced, SettingsSectionTitle.advanced, keywords: ["backbone", "kishi", "pockettaco", "soolra", "skin", "delta skin"], tvOS: false),
        entry("adv.livebroadcast", "Live Broadcast", "ReplayKit Go Live button in the pause menu. Cast gameplay to Twitch / Facebook / other services.",
              .advanced, SettingsSectionTitle.advanced, keywords: ["stream", "twitch", "replaykit", "go live", "record"]),
        entry("adv.netplay", "Netplay", "Host and join netplay rooms from the pause menu.",
              .advanced, SettingsSectionTitle.advanced, keywords: ["multiplayer", "online", "link cable", "mgba", "lobby"]),
        entry("adv.transferpak", "N64 Transfer Pak", "Assign a Game Boy ROM to a Mupen64Plus controller port for Pokémon Stadium / Mario Golf integration.",
              .advanced, SettingsSectionTitle.advanced, keywords: ["n64", "game boy", "pokemon", "mupen"]),
        entry("adv.taptoremap", "Tap to Remap (Beta)", "In-development tap-to-remap controller UI.",
              .advanced, SettingsSectionTitle.advanced, keywords: ["remap", "buttons", "controller", "experimental"]),
        entry("adv.companion", "Companion Controller (Beta)", "Show a companion-controller overlay (trackball / numpad / DSU peripherals) in the pause menu.",
              .advanced, SettingsSectionTitle.advanced, keywords: ["trackball", "numpad", "dsu", "experimental"]),
        entry("adv.crosshair", "Light Gun Crosshair", "Show an on-screen crosshair overlay for light-gun-capable cores.",
              .advanced, SettingsSectionTitle.advanced, keywords: ["lightgun", "light gun", "aim", "reticle"]),
        entry("adv.skinreposition", "Reposition Skin Buttons (Beta)", "Drag-to-reposition on-screen skin buttons in a layout editor.",
              .advanced, SettingsSectionTitle.advanced, keywords: ["skin", "delta skin", "layout", "drag", "experimental"], tvOS: false),
        entry("adv.airplay", "AirPlay Audio Menu", "Show an AirPlay audio route-picker button in the pause menu.",
              .advanced, SettingsSectionTitle.advanced, keywords: ["audio", "route", "speaker", "bluetooth"]),
        entry("adv.appgroupfiles", "App Group File Browser", "Browse files in the app group container for debugging.",
              .advanced, SettingsSectionTitle.advanced, keywords: ["files", "debug", "container", "storage"]),
        entry("adv.spotlight", "Spotlight Debug", "View and manage Spotlight indexing for games and save states.",
              .advanced, SettingsSectionTitle.advanced, keywords: ["search", "index", "debug"], tvOS: false),
        entry("adv.logs", "Logs", "View, search, and export app logs.",
              .advanced, SettingsSectionTitle.advanced, keywords: ["log", "debug", "diagnostics", "export", "console"]),
        entry("adv.sessionlogs", "Session Logs", "View and manage file-based session log archives.",
              .advanced, SettingsSectionTitle.advanced, keywords: ["log", "debug", "archive"]),
        entry("adv.topshelflog", "TopShelf Log", "View logs from the TopShelf extension.",
              .advanced, SettingsSectionTitle.advanced, keywords: ["log", "debug", "apple tv"], iOS: false)
    ]

    // MARK: About

    private static let about: [SettingsSearchEntry] = [
        entry("social.patreon", "Patreon", "Support us on Patreon.",
              .about, SettingsSectionTitle.socialLinks, keywords: ["donate", "support", "subscription"], tvOS: false, hiddenInAppStore: true),
        entry("social.discord", "Discord", "Join our Discord server for help and community chat.",
              .about, SettingsSectionTitle.socialLinks, keywords: ["chat", "community", "help", "support"], tvOS: false),
        entry("social.x", "X", "Follow us on X for release and other announcements.",
              .about, SettingsSectionTitle.socialLinks, keywords: ["twitter", "social", "news"], tvOS: false),
        entry("social.youtube", "YouTube", "Help tutorial videos and new feature previews.",
              .about, SettingsSectionTitle.socialLinks, keywords: ["video", "tutorial", "social"], tvOS: false, hiddenInAppStore: true),
        entry("social.github", "GitHub", "Check out GitHub for code, reporting bugs and contributing.",
              .about, SettingsSectionTitle.socialLinks, keywords: ["source", "bug", "issue", "report", "code", "open source"], tvOS: false),

        entry("docs.wiki", "Help & Wiki", "Browse the Provenance wiki for guides, FAQs, and tips.",
              .about, SettingsSectionTitle.documentation, keywords: ["guide", "faq", "manual", "documentation"], tvOS: false),
        entry("docs.blog", "Blog", "Release announcements and full changelogs and screenshots posted to our blog.",
              .about, SettingsSectionTitle.documentation, keywords: ["changelog", "release notes", "news", "whats new"], tvOS: false),

        entry("roadmap.full", "View Full Roadmap", "What is planned for upcoming releases.",
              .about, SettingsSectionTitle.roadmap, keywords: ["plans", "upcoming", "features", "future"], tvOS: false),

        entry("build.version", "Version", "Current app version.",
              .about, SettingsSectionTitle.build, keywords: ["release", "app version"]),
        entry("build.build", "Build", "Internal build number.",
              .about, SettingsSectionTitle.build, keywords: ["number"]),
        entry("build.git", "Git Revision", "Source code version.",
              .about, SettingsSectionTitle.build, keywords: ["commit", "sha", "hash"]),
        entry("build.builtby", "Built By", "Developer who built this version.",
              .about, SettingsSectionTitle.build, keywords: ["developer", "author"]),
        entry("build.date", "Build Date", "When this version was compiled.",
              .about, SettingsSectionTitle.build, keywords: ["compiled", "time"]),

        entry("legal.licenses", "Licenses", "Open-source libraries Provenance uses and their respective licenses.",
              .about, SettingsSectionTitle.extraInfo, keywords: ["open source", "legal", "third party", "credits"]),
        entry("legal.privacy", "Privacy Policy", nil,
              .about, SettingsSectionTitle.extraInfo, keywords: ["legal", "data"]),
        entry("legal.eula", "End User License Agreement (EULA)", nil,
              .about, SettingsSectionTitle.extraInfo, keywords: ["legal", "terms", "agreement"])
    ]
}
