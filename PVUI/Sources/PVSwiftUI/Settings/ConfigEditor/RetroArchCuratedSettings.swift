import Foundation

// MARK: - Curated RetroArch Settings Catalog

/// A human-readable wrapper around a RetroArch config key
struct CuratedSetting: Identifiable {
    let key: String
    let title: String
    let description: String
    let category: CuratedSettingCategory
    let controlType: CuratedControlType
    let defaultValue: String

    var id: String { key }
}

enum CuratedSettingCategory: String, CaseIterable, Identifiable {
    case notifications = "Notifications"
    case video = "Video"
    case audio = "Audio"
    case midi = "MIDI"
    case performance = "Performance"
    case saves = "Saves"
    case debug = "Debug"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .notifications: return "bell"
        case .video: return "tv"
        case .audio: return "speaker.wave.2"
        case .midi: return "pianokeys"
        case .performance: return "gauge.with.needle"
        case .saves: return "square.and.arrow.down"
        case .debug: return "ladybug"
        }
    }
}

enum CuratedControlType {
    case toggle
    case slider(min: Double, max: Double, step: Double)
    case picker(options: [(label: String, value: String)])
}

// MARK: - Settings Catalog

enum RetroArchCuratedSettings {
    static let all: [CuratedSetting] = notifications + video + audio + midi + performance + saves + debug

    static func settings(for category: CuratedSettingCategory) -> [CuratedSetting] {
        all.filter { $0.category == category }
    }
}

// MARK: - Settings Catalog Data

extension RetroArchCuratedSettings {
    // MARK: - Notifications

    static let notifications: [CuratedSetting] = [
        CuratedSetting(
            key: "notification_show_fast_forward",
            title: "Fast Forward",
            description: "Show on-screen notification when fast forwarding",
            category: .notifications,
            controlType: .toggle,
            defaultValue: "true"
        ),
        CuratedSetting(
            key: "notification_show_save_state",
            title: "Save State",
            description: "Show notification when saving or loading a state",
            category: .notifications,
            controlType: .toggle,
            defaultValue: "true"
        ),
        CuratedSetting(
            key: "notification_show_screenshot",
            title: "Screenshot",
            description: "Show notification when taking a screenshot",
            category: .notifications,
            controlType: .toggle,
            defaultValue: "true"
        ),
        CuratedSetting(
            key: "notification_show_cheats_applied",
            title: "Cheats Applied",
            description: "Show notification when cheats are applied",
            category: .notifications,
            controlType: .toggle,
            defaultValue: "true"
        ),
        CuratedSetting(
            key: "notification_show_config_override_load",
            title: "Config Override",
            description: "Show notification when a config override loads",
            category: .notifications,
            controlType: .toggle,
            defaultValue: "true"
        ),
        CuratedSetting(
            key: "notification_show_remap_load",
            title: "Remap Load",
            description: "Show notification when input remaps are loaded",
            category: .notifications,
            controlType: .toggle,
            defaultValue: "true"
        ),
        CuratedSetting(
            key: "notification_show_refresh_rate",
            title: "Refresh Rate",
            description: "Show notification about display refresh rate changes",
            category: .notifications,
            controlType: .toggle,
            defaultValue: "true"
        ),
        CuratedSetting(
            key: "notification_show_disk_control",
            title: "Disk Control",
            description: "Show notification for disk insert/eject events",
            category: .notifications,
            controlType: .toggle,
            defaultValue: "true"
        ),
        CuratedSetting(
            key: "notification_show_patch_applied",
            title: "Patch Applied",
            description: "Show notification when a soft-patch is applied",
            category: .notifications,
            controlType: .toggle,
            defaultValue: "true"
        ),
        CuratedSetting(
            key: "notification_show_when_menu_is_alive",
            title: "In-Menu Notifications",
            description: "Show notifications while the RetroArch menu is open",
            category: .notifications,
            controlType: .toggle,
            defaultValue: "false"
        )
    ]

    // MARK: - Video

    static let video: [CuratedSetting] = [
        CuratedSetting(
            key: "video_smooth",
            title: "Bilinear Filtering",
            description: "Smooth the image (off = sharp pixels, on = blurred)",
            category: .video,
            controlType: .toggle,
            defaultValue: "false"
        ),
        CuratedSetting(
            key: "video_vsync",
            title: "VSync",
            description: "Synchronize to display refresh rate to prevent tearing",
            category: .video,
            controlType: .toggle,
            defaultValue: "true"
        ),
        CuratedSetting(
            key: "video_threaded",
            title: "Threaded Rendering",
            description: "Run video on a separate thread (may improve performance but adds latency)",
            category: .video,
            controlType: .toggle,
            defaultValue: "false"
        ),
        CuratedSetting(
            key: "video_scale_integer",
            title: "Integer Scaling",
            description: "Scale video to exact integer multiples for pixel-perfect output",
            category: .video,
            controlType: .toggle,
            defaultValue: "false"
        ),
        CuratedSetting(
            key: "video_aspect_ratio_auto",
            title: "Auto Aspect Ratio",
            description: "Use the core-reported aspect ratio automatically",
            category: .video,
            controlType: .toggle,
            defaultValue: "false"
        ),
        CuratedSetting(
            key: "video_crop_overscan",
            title: "Crop Overscan",
            description: "Remove the border area that old CRT TVs would hide",
            category: .video,
            controlType: .toggle,
            defaultValue: "true"
        ),
        CuratedSetting(
            key: "video_shader_enable",
            title: "Enable Shaders",
            description: "Apply GPU shader effects (CRT filters, scanlines, etc.)",
            category: .video,
            controlType: .toggle,
            defaultValue: "false"
        ),
        CuratedSetting(
            key: "video_frame_delay",
            title: "Frame Delay",
            description: "Delay in ms before running the frame (reduces latency, 0 = off)",
            category: .video,
            controlType: .slider(min: 0, max: 16, step: 1),
            defaultValue: "0"
        ),
        CuratedSetting(
            key: "video_frame_delay_auto",
            title: "Auto Frame Delay",
            description: "Automatically determine safe frame delay for lower latency",
            category: .video,
            controlType: .toggle,
            defaultValue: "false"
        ),
        CuratedSetting(
            key: "video_rotation",
            title: "Screen Rotation",
            description: "Rotate the video output",
            category: .video,
            controlType: .picker(options: [
                (label: "Normal", value: "0"),
                (label: "90\u{00B0}", value: "1"),
                (label: "180\u{00B0}", value: "2"),
                (label: "270\u{00B0}", value: "3")
            ]),
            defaultValue: "0"
        )
    ]

    // MARK: - Audio

    static let audio: [CuratedSetting] = [
        CuratedSetting(
            key: "audio_enable",
            title: "Audio Enabled",
            description: "Enable audio output",
            category: .audio,
            controlType: .toggle,
            defaultValue: "true"
        ),
        CuratedSetting(
            key: "audio_sync",
            title: "Audio Sync",
            description: "Synchronize audio to prevent crackling (recommended on)",
            category: .audio,
            controlType: .toggle,
            defaultValue: "true"
        ),
        CuratedSetting(
            key: "audio_latency",
            title: "Audio Latency",
            description: "Audio buffer size in ms (lower = less delay, higher = fewer glitches)",
            category: .audio,
            controlType: .slider(min: 8, max: 256, step: 8),
            defaultValue: "64"
        ),
        CuratedSetting(
            key: "audio_volume",
            title: "Volume (dB)",
            description: "Audio output volume in decibels",
            category: .audio,
            controlType: .slider(min: -10, max: 10, step: 0.5),
            defaultValue: "1.000000"
        ),
        CuratedSetting(
            key: "audio_rate_control",
            title: "Dynamic Rate Control",
            description: "Dynamically adjust audio rate to prevent buffer under/overflows",
            category: .audio,
            controlType: .toggle,
            defaultValue: "true"
        ),
        CuratedSetting(
            key: "audio_mute_enable",
            title: "Mute",
            description: "Mute all audio output",
            category: .audio,
            controlType: .toggle,
            defaultValue: "false"
        ),
        CuratedSetting(
            key: "audio_fastforward_mute",
            title: "Mute During Fast Forward",
            description: "Silence audio while fast forwarding",
            category: .audio,
            controlType: .toggle,
            defaultValue: "false"
        )
    ]

    // MARK: - MIDI

    static let midi: [CuratedSetting] = [
        CuratedSetting(
            key: "midi_enable",
            title: "MIDI Enabled",
            description: "Enable MIDI input/output support in RetroArch",
            category: .midi,
            controlType: .toggle,
            defaultValue: "true"
        ),
        CuratedSetting(
            key: "midi_driver",
            title: "MIDI Driver",
            description: "Backend driver used for MIDI I/O",
            category: .midi,
            controlType: .picker(options: [
                (label: "CoreMIDI", value: "coremidi"),
                (label: "None", value: "null")
            ]),
            defaultValue: "coremidi"
        ),
        CuratedSetting(
            key: "midi_volume",
            title: "MIDI Volume",
            description: "Volume for MIDI synthesizer output (0–100%)",
            category: .midi,
            controlType: .slider(min: 0, max: 100, step: 1),
            defaultValue: "100"
        )
    ]

    // MARK: - Performance

    static let performance: [CuratedSetting] = [
        CuratedSetting(
            key: "rewind_enable",
            title: "Rewind",
            description: "Enable rewind support (uses extra memory and CPU)",
            category: .performance,
            controlType: .toggle,
            defaultValue: "false"
        ),
        CuratedSetting(
            key: "rewind_buffer_size",
            title: "Rewind Buffer (MB)",
            description: "Memory allocated for rewind history (value in bytes, shown in MB)",
            category: .performance,
            controlType: .slider(min: 1, max: 100, step: 1),
            defaultValue: "20971520"
        ),
        CuratedSetting(
            key: "run_ahead_enabled",
            title: "Run-Ahead",
            description: "Run frames ahead and skip to reduce input latency (CPU intensive)",
            category: .performance,
            controlType: .toggle,
            defaultValue: "false"
        ),
        CuratedSetting(
            key: "run_ahead_frames",
            title: "Run-Ahead Frames",
            description: "Number of frames to run ahead (more = less latency, more CPU)",
            category: .performance,
            controlType: .slider(min: 1, max: 6, step: 1),
            defaultValue: "1"
        ),
        CuratedSetting(
            key: "fastforward_ratio",
            title: "Fast Forward Speed",
            description: "Maximum fast forward multiplier (0 = unlimited)",
            category: .performance,
            controlType: .slider(min: 0, max: 10, step: 0.5),
            defaultValue: "0.000000"
        ),
        CuratedSetting(
            key: "fastforward_frameskip",
            title: "Skip Frames When Fast Forwarding",
            description: "Skip rendering frames during fast forward for higher speed",
            category: .performance,
            controlType: .toggle,
            defaultValue: "true"
        )
    ]

    // MARK: - Saves

    static let saves: [CuratedSetting] = [
        CuratedSetting(
            key: "savestate_auto_save",
            title: "Auto-Save State on Exit",
            description: "Automatically create a save state when closing content",
            category: .saves,
            controlType: .toggle,
            defaultValue: "false"
        ),
        CuratedSetting(
            key: "savestate_auto_load",
            title: "Auto-Load State on Start",
            description: "Automatically load the last save state when launching content",
            category: .saves,
            controlType: .toggle,
            defaultValue: "false"
        ),
        CuratedSetting(
            key: "savestate_file_compression",
            title: "Compress Save States",
            description: "Compress save state files to save storage space",
            category: .saves,
            controlType: .toggle,
            defaultValue: "true"
        ),
        CuratedSetting(
            key: "config_save_on_exit",
            title: "Save Config on Exit",
            description: "Automatically save the RetroArch config when closing",
            category: .saves,
            controlType: .toggle,
            defaultValue: "true"
        ),
        CuratedSetting(
            key: "autosave_interval",
            title: "SRAM Autosave Interval (sec)",
            description: "How often to auto-save SRAM to disk (0 = only on exit)",
            category: .saves,
            controlType: .slider(min: 0, max: 600, step: 10),
            defaultValue: "10"
        )
    ]

    // MARK: - Debug

    static let debug: [CuratedSetting] = [
        CuratedSetting(
            key: "log_verbosity",
            title: "Verbose Logging",
            description: "Enable detailed logging output (useful for troubleshooting)",
            category: .debug,
            controlType: .toggle,
            defaultValue: "false"
        ),
        CuratedSetting(
            key: "fps_show",
            title: "Show FPS Counter",
            description: "Display frames per second on screen",
            category: .debug,
            controlType: .toggle,
            defaultValue: "false"
        )
    ]
}
