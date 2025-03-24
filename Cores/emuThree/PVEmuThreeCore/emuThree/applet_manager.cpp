// Copyright 2018 Citra Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

// Local Changes: Check for isInitalized/IsReloaded

#include "common/settings.h"
#include "core/core.h"
#include "core/frontend/input.h"
#include "core/hle/applets/applet.h"
#include "core/hle/service/am/am.h"
#include "core/hle/service/apt/applet_manager.h"
#include "core/hle/service/apt/errors.h"
#include "core/hle/service/apt/ns.h"
#include "core/hle/service/cfg/cfg.h"
#include "core/hle/service/gsp/gsp_gpu.h"
#include "video_core/utils.h"

SERVICE_CONSTRUCT_IMPL(Service::APT::AppletManager)

namespace Service::APT {

/// The interval at which the home button update callback will be called, 16.6ms
static constexpr u64 home_button_update_interval_us = 16666;

struct AppletTitleData {
    // There are two possible applet ids for each applet.
    std::array<AppletId, 2> applet_ids;

    // There's a specific TitleId per region for each applet.
    static constexpr std::size_t NumRegions = 7;
    std::array<u64, NumRegions> title_ids;
    std::array<u64, NumRegions> n3ds_title_ids = {0, 0, 0, 0, 0, 0, 0};
};

static constexpr std::size_t NumApplets = 29;
static constexpr std::array<AppletTitleData, NumApplets> applet_titleids = {{
    {{AppletId::HomeMenu, AppletId::None},
     {0x4003000008202, 0x4003000008F02, 0x4003000009802, 0x4003000008202, 0x400300000A102,
      0x400300000A902, 0x400300000B102}},
    {{AppletId::AlternateMenu, AppletId::None},
     {0x4003000008102, 0x4003000008102, 0x4003000008102, 0x4003000008102, 0x4003000008102,
      0x4003000008102, 0x4003000008102}},
    {{AppletId::Camera, AppletId::None},
     {0x4003000008402, 0x4003000009002, 0x4003000009902, 0x4003000008402, 0x400300000A202,
      0x400300000AA02, 0x400300000B202}},
    {{AppletId::FriendList, AppletId::None},
     {0x4003000008D02, 0x4003000009602, 0x4003000009F02, 0x4003000008D02, 0x400300000A702,
      0x400300000AF02, 0x400300000B702}},
    {{AppletId::GameNotes, AppletId::None},
     {0x4003000008702, 0x4003000009302, 0x4003000009C02, 0x4003000008702, 0x400300000A502,
      0x400300000AD02, 0x400300000B502}},
    {{AppletId::InternetBrowser, AppletId::None},
     {0x4003000008802, 0x4003000009402, 0x4003000009D02, 0x4003000008802, 0x400300000A602,
      0x400300000AE02, 0x400300000B602},
     {0x4003020008802, 0x4003020009402, 0x4003020009D02, 0x4003020008802, 0, 0x400302000AE02, 0}},
    {{AppletId::InstructionManual, AppletId::None},
     {0x4003000008602, 0x4003000009202, 0x4003000009B02, 0x4003000008602, 0x400300000A402,
      0x400300000AC02, 0x400300000B402}},
    {{AppletId::Notifications, AppletId::None},
     {0x4003000008E02, 0x4003000009702, 0x400300000A002, 0x4003000008E02, 0x400300000A802,
      0x400300000B002, 0x400300000B802}},
    {{AppletId::Miiverse, AppletId::None},
     {0x400300000BC02, 0x400300000BD02, 0x400300000BE02, 0x400300000BC02, 0x4003000009E02,
      0x4003000009502, 0x400300000B902}},
    // These values obtained from an older NS dump firmware 4.5
    {{AppletId::MiiversePost, AppletId::None},
     {0x400300000BA02, 0x400300000BA02, 0x400300000BA02, 0x400300000BA02, 0x400300000BA02,
      0x400300000BA02, 0x400300000BA02}},
    // {AppletId::MiiversePost, AppletId::None, 0x4003000008302, 0x4003000008B02, 0x400300000BA02,
    //  0x4003000008302, 0x0, 0x0, 0x0},
    {{AppletId::AmiiboSettings, AppletId::None},
     {0x4003000009502, 0x4003000009E02, 0x400300000B902, 0x4003000009502, 0x0, 0x4003000008C02,
      0x400300000BF02}},
    {{AppletId::SoftwareKeyboard1, AppletId::SoftwareKeyboard2},
     {0x400300000C002, 0x400300000C802, 0x400300000D002, 0x400300000C002, 0x400300000D802,
      0x400300000DE02, 0x400300000E402}},
    {{AppletId::Ed1, AppletId::Ed2},
     {0x400300000C102, 0x400300000C902, 0x400300000D102, 0x400300000C102, 0x400300000D902,
      0x400300000DF02, 0x400300000E502}},
    {{AppletId::PnoteApp, AppletId::PnoteApp2},
     {0x400300000C302, 0x400300000CB02, 0x400300000D302, 0x400300000C302, 0x400300000DB02,
      0x400300000E102, 0x400300000E702}},
    {{AppletId::SnoteApp, AppletId::SnoteApp2},
     {0x400300000C402, 0x400300000CC02, 0x400300000D402, 0x400300000C402, 0x400300000DC02,
      0x400300000E202, 0x400300000E802}},
    {{AppletId::Error, AppletId::Error2},
     {0x400300000C502, 0x400300000C502, 0x400300000C502, 0x400300000C502, 0x400300000CF02,
      0x400300000CF02, 0x400300000CF02}},
    {{AppletId::Mint, AppletId::Mint2},
     {0x400300000C602, 0x400300000CE02, 0x400300000D602, 0x400300000C602, 0x400300000DD02,
      0x400300000E302, 0x400300000E902}},
    {{AppletId::Extrapad, AppletId::Extrapad2},
     {0x400300000CD02, 0x400300000CD02, 0x400300000CD02, 0x400300000CD02, 0x400300000D502,
      0x400300000D502, 0x400300000D502}},
    {{AppletId::Memolib, AppletId::Memolib2},
     {0x400300000F602, 0x400300000F602, 0x400300000F602, 0x400300000F602, 0x400300000F602,
      0x400300000F602, 0x400300000F602}},
    // TODO(Subv): Fill in the rest of the titleids
}};

static u64 GetTitleIdForApplet(AppletId id, u32 region_value) {
    ASSERT_MSG(id != AppletId::None, "Invalid applet id");

    auto itr = std::find_if(applet_titleids.begin(), applet_titleids.end(),
                            [id](const AppletTitleData& data) {
                                return data.applet_ids[0] == id || data.applet_ids[1] == id;
                            });

    ASSERT_MSG(itr != applet_titleids.end(), "Unknown applet id 0x{:#05X}", id);

    auto n3ds_title_id = itr->n3ds_title_ids[region_value];
    if (n3ds_title_id != 0 && Settings::values.is_new_3ds.GetValue()) {
        return n3ds_title_id;
    }
    return itr->title_ids[region_value];
}

static bool IsSystemAppletId(AppletId applet_id) {
    return (static_cast<u32>(applet_id) & static_cast<u32>(AppletId::AnySystemApplet)) != 0;
}

static bool IsApplicationAppletId(AppletId applet_id) {
    return (static_cast<u32>(applet_id) & static_cast<u32>(AppletId::Application)) != 0;
}

AppletManager::AppletSlot AppletManager::GetAppletSlotFromId(AppletId id) {
    if (id == AppletId::Application) {
        if (GetAppletSlot(AppletSlot::Application)->applet_id != AppletId::None)
            return AppletSlot::Application;

        return AppletSlot::Error;
    }

    if (id == AppletId::AnySystemApplet) {
        if (GetAppletSlot(AppletSlot::SystemApplet)->applet_id != AppletId::None)
            return AppletSlot::SystemApplet;

        // The Home Menu is also a system applet, but it lives in its own slot to be able to run
        // concurrently with other system applets.
        if (GetAppletSlot(AppletSlot::HomeMenu)->applet_id != AppletId::None)
            return AppletSlot::HomeMenu;

        return AppletSlot::Error;
    }

    if (id == AppletId::AnyLibraryApplet || id == AppletId::AnySysLibraryApplet) {
        auto slot_data = GetAppletSlot(AppletSlot::LibraryApplet);
        if (slot_data->applet_id == AppletId::None)
            return AppletSlot::Error;

        auto applet_pos = slot_data->attributes.applet_pos.Value();
        if ((id == AppletId::AnyLibraryApplet && applet_pos == AppletPos::Library) ||
            (id == AppletId::AnySysLibraryApplet && applet_pos == AppletPos::SysLibrary))
            return AppletSlot::LibraryApplet;

        return AppletSlot::Error;
    }

    if (id == AppletId::HomeMenu || id == AppletId::AlternateMenu) {
        if (GetAppletSlot(AppletSlot::HomeMenu)->applet_id != AppletId::None)
            return AppletSlot::HomeMenu;

        return AppletSlot::Error;
    }

    for (std::size_t slot = 0; slot < applet_slots.size(); ++slot) {
        if (applet_slots[slot].applet_id == id) {
            return static_cast<AppletSlot>(slot);
        }
    }

    return AppletSlot::Error;
}

AppletManager::AppletSlot AppletManager::GetAppletSlotFromAttributes(AppletAttributes attributes) {
    // Mapping from AppletPos to AppletSlot
    static constexpr std::array<AppletSlot, 6> applet_position_slots = {
        AppletSlot::Application,   AppletSlot::LibraryApplet, AppletSlot::SystemApplet,
        AppletSlot::LibraryApplet, AppletSlot::Error,         AppletSlot::LibraryApplet};

    auto applet_pos_value = static_cast<u32>(attributes.applet_pos.Value());
    if (applet_pos_value >= applet_position_slots.size())
        return AppletSlot::Error;

    auto slot = applet_position_slots[applet_pos_value];
    if (slot == AppletSlot::Error)
        return AppletSlot::Error;

    // The Home Menu is a system applet, however, it has its own applet slot so that it can run
    // concurrently with other system applets.
    if (slot == AppletSlot::SystemApplet && attributes.is_home_menu)
        return AppletSlot::HomeMenu;

    return slot;
}

AppletManager::AppletSlot AppletManager::GetAppletSlotFromPos(AppletPos pos) {
    AppletId applet_id;
    switch (pos) {
    case AppletPos::Application:
        applet_id = AppletId::Application;
        break;
    case AppletPos::Library:
        applet_id = AppletId::AnyLibraryApplet;
        break;
    case AppletPos::System:
        applet_id = AppletId::AnySystemApplet;
        break;
    case AppletPos::SysLibrary:
        applet_id = AppletId::AnySysLibraryApplet;
        break;
    default:
        return AppletSlot::Error;
    }
    return GetAppletSlotFromId(applet_id);
}

void AppletManager::CancelAndSendParameter(const MessageParameter& parameter) {
    LOG_DEBUG(
        Service_APT, "Sending parameter from {:03X} to {:03X} with signal {:08X} and size {:08X}",
        parameter.sender_id, parameter.destination_id, parameter.signal, parameter.buffer.size());

    // If the applet is being HLEd, send directly to the applet.
    if (auto dest_applet = HLE::Applets::Applet::Get(parameter.destination_id)) {
        dest_applet->ReceiveParameter(parameter);
    } else {
        // Otherwise, send the parameter the LLE way.
        next_parameter = parameter;

        if (parameter.signal == SignalType::RequestForSysApplet) {
            // APT handles RequestForSysApplet messages itself.
            LOG_DEBUG(Service_APT, "Replying to RequestForSysApplet from {:03X}",
                      parameter.sender_id);

            if (parameter.buffer.size() >= sizeof(CaptureBufferInfo)) {
                SendCaptureBufferInfo(parameter.buffer);
                CaptureFrameBuffers();
            }

            next_parameter->sender_id = parameter.destination_id;
            next_parameter->destination_id = parameter.sender_id;
            next_parameter->signal = SignalType::Response;
            next_parameter->buffer.clear();
            next_parameter->object = nullptr;
        } else if (IsSystemAppletId(parameter.sender_id) &&
                   IsApplicationAppletId(parameter.destination_id) && parameter.object) {
            // When a message is sent from a system applet to an application, APT
            // replaces its object with the zero handle.
            next_parameter->object = nullptr;
        }

        // Signal the event to let the receiver know that a new parameter is ready to be read
        auto slot = GetAppletSlotFromId(next_parameter->destination_id);
        if (slot != AppletSlot::Error) {
            GetAppletSlot(slot)->parameter_event->Signal();
        } else {
            LOG_DEBUG(Service_APT, "No applet was registered with ID {:03X}",
                      next_parameter->destination_id);
        }
    }
}

ResultCode AppletManager::SendParameter(const MessageParameter& parameter) {
    // A new parameter can not be sent if the previous one hasn't been consumed yet
    if (next_parameter) {
        LOG_WARNING(Service_APT, "Parameter from {:03X} to {:03X} blocked by pending parameter.",
                    parameter.sender_id, parameter.destination_id);
        return {ErrCodes::ParameterPresent, ErrorModule::Applet, ErrorSummary::InvalidState,
                ErrorLevel::Status};
    }

    CancelAndSendParameter(parameter);
    return RESULT_SUCCESS;
}

ResultVal<MessageParameter> AppletManager::GlanceParameter(AppletId app_id) {
    if (!next_parameter) {
        return ResultCode(ErrorDescription::NoData, ErrorModule::Applet, ErrorSummary::InvalidState,
                          ErrorLevel::Status);
    }

    if (next_parameter->destination_id != app_id) {
        return ResultCode(ErrorDescription::NotFound, ErrorModule::Applet, ErrorSummary::NotFound,
                          ErrorLevel::Status);
    }

    auto parameter = *next_parameter;

    // Note: The NS module always clears the DSPSleep and DSPWakeup signals even in GlanceParameter.
    if (next_parameter->signal == SignalType::DspSleep ||
        next_parameter->signal == SignalType::DspWakeup) {
        next_parameter = {};
    }

    return MakeResult<MessageParameter>(std::move(parameter));
}

ResultVal<MessageParameter> AppletManager::ReceiveParameter(AppletId app_id) {
    auto result = GlanceParameter(app_id);
    if (result.Succeeded()) {
        LOG_DEBUG(Service_APT,
                  "Received parameter from {:03X} to {:03X} with signal {:08X} and size {:08X}",
                  result->sender_id, result->destination_id, result->signal, result->buffer.size());

        // Clear the parameter
        next_parameter = {};
    }
    return result;
}

bool AppletManager::CancelParameter(bool check_sender, AppletId sender_appid, bool check_receiver,
                                    AppletId receiver_appid) {
    auto cancellation_success =
        next_parameter && (!check_sender || next_parameter->sender_id == sender_appid) &&
        (!check_receiver || next_parameter->destination_id == receiver_appid);

    if (cancellation_success)
        next_parameter = {};

    return cancellation_success;
}

ResultVal<AppletManager::GetLockHandleResult> AppletManager::GetLockHandle(
    AppletAttributes attributes) {
    auto corrected_attributes = attributes;
    if (attributes.applet_pos == AppletPos::Library ||
        attributes.applet_pos == AppletPos::SysLibrary ||
        attributes.applet_pos == AppletPos::AutoLibrary) {
        auto corrected_pos = last_library_launcher_slot == AppletSlot::Application
                                 ? AppletPos::Library
                                 : AppletPos::SysLibrary;
        corrected_attributes.applet_pos.Assign(corrected_pos);
        LOG_DEBUG(Service_APT, "Corrected applet attributes from {:08X} to {:08X}", attributes.raw,
                  corrected_attributes.raw);
    }

    return MakeResult<AppletManager::GetLockHandleResult>({corrected_attributes, 0, lock});
}

ResultVal<AppletManager::InitializeResult> AppletManager::Initialize(AppletId app_id,
                                                                     AppletAttributes attributes) {
    auto slot = GetAppletSlotFromAttributes(attributes);
    // Note: The real NS service does not check if the attributes value is valid before accessing
    // the data in the array
    ASSERT_MSG(slot != AppletSlot::Error, "Invalid application attributes");

    auto slot_data = GetAppletSlot(slot);
    if (slot_data->registered) {
        LOG_WARNING(Service_APT, "Applet attempted to register in occupied slot {:02X}", slot);
        return ResultCode(ErrorDescription::AlreadyExists, ErrorModule::Applet,
                          ErrorSummary::InvalidState, ErrorLevel::Status);
    }

    LOG_DEBUG(Service_APT, "Initializing applet with ID {:03X} and attributes {:08X}.", app_id,
              attributes.raw);
    slot_data->applet_id = static_cast<AppletId>(app_id);
    // Note: In the real console the title id of a given applet slot is set by the APT module when
    // calling StartApplication.
    slot_data->title_id = system.Kernel().GetCurrentProcess()->codeset->program_id;
    slot_data->attributes.raw = attributes.raw;

    // Applications need to receive a Wakeup signal to actually start up, this signal is usually
    // sent by the Home Menu after starting the app by way of APT::WakeupApplication. However,
    // if nothing is running yet the signal should be sent by APT::Initialize itself.
    if (active_slot == AppletSlot::Error) {
        active_slot = slot;

        // Wake up the application.
        SendParameter({
            .sender_id = AppletId::None,
            .destination_id = app_id,
            .signal = SignalType::Wakeup,
        });
    }

    return MakeResult<InitializeResult>(
        {slot_data->notification_event, slot_data->parameter_event});
}

ResultCode AppletManager::Enable(AppletAttributes attributes) {
    auto slot = GetAppletSlotFromAttributes(attributes);
    if (slot == AppletSlot::Error) {
        LOG_WARNING(Service_APT,
                    "Attempted to register with attributes {:08X}, but could not find slot.",
                    attributes.raw);
        return {ErrCodes::InvalidAppletSlot, ErrorModule::Applet, ErrorSummary::InvalidState,
                ErrorLevel::Status};
    }

    LOG_DEBUG(Service_APT, "Registering applet with attributes {:08X}.", attributes.raw);
    auto slot_data = GetAppletSlot(slot);
    slot_data->registered = true;

    if (slot_data->attributes.applet_pos == AppletPos::System &&
        slot_data->attributes.is_home_menu) {
        slot_data->attributes.raw |= attributes.raw;
        LOG_DEBUG(Service_APT, "Updated home menu attributes to {:08X}.",
                  slot_data->attributes.raw);
    }

    // Send any outstanding parameters to the newly-registered application
    if (delayed_parameter && delayed_parameter->destination_id == slot_data->applet_id) {
        // TODO: Real APT would loop trying to send the parameter until it succeeds,
        // essentially waiting for existing parameters to be delivered.
        CancelAndSendParameter(*delayed_parameter);
        delayed_parameter.reset();
    }

    return RESULT_SUCCESS;
}

bool AppletManager::IsRegistered(AppletId app_id) {
    auto slot = GetAppletSlotFromId(app_id);
    return slot != AppletSlot::Error && GetAppletSlot(slot)->registered;
}

ResultVal<Notification> AppletManager::InquireNotification(AppletId app_id) {
    auto slot = GetAppletSlotFromId(app_id);
    if (slot != AppletSlot::Error) {
        auto slot_data = GetAppletSlot(slot);
        if (slot_data->registered) {
            auto notification = slot_data->notification;
            slot_data->notification = Notification::None;
            return MakeResult<Notification>(notification);
        }
    }

    return ResultCode(ErrorDescription::NotFound, ErrorModule::Applet, ErrorSummary::NotFound,
                      ErrorLevel::Status);
}

ResultCode AppletManager::SendNotification(Notification notification) {
    if (active_slot != AppletSlot::Error) {
        const auto slot_data = GetAppletSlot(active_slot);
        if (slot_data->registered) {
            slot_data->notification = notification;
            slot_data->notification_event->Signal();
            return RESULT_SUCCESS;
        }
    }

    return {ErrorDescription::NotFound, ErrorModule::Applet, ErrorSummary::NotFound,
            ErrorLevel::Status};
}

ResultCode AppletManager::PrepareToStartLibraryApplet(AppletId applet_id) {
    // The real APT service returns an error if there's a pending APT parameter when this function
    // is called.
    if (next_parameter) {
        return {ErrCodes::ParameterPresent, ErrorModule::Applet, ErrorSummary::InvalidState,
                ErrorLevel::Status};
    }

    if (GetAppletSlot(AppletSlot::LibraryApplet)->registered) {
        return {ErrorDescription::AlreadyExists, ErrorModule::Applet, ErrorSummary::InvalidState,
                ErrorLevel::Status};
    }

    last_library_launcher_slot = active_slot;
    last_prepared_library_applet = applet_id;

    auto cfg = Service::CFG::GetModule(system);
    auto process =
        NS::LaunchTitle(FS::MediaType::NAND, GetTitleIdForApplet(applet_id, cfg->GetRegionValue()));
    if (process) {
        return RESULT_SUCCESS;
    }

    // If we weren't able to load the native applet title, try to fallback to an HLE implementation.
    auto applet = HLE::Applets::Applet::Get(applet_id);
    if (applet) {
        LOG_WARNING(Service_APT, "applet has already been started id={:03X}", applet_id);
        return RESULT_SUCCESS;
    } else {
        auto parent = GetAppletSlotId(last_library_launcher_slot);
        LOG_DEBUG(Service_APT, "Creating HLE applet {:03X} with parent {:03X}", applet_id, parent);
        return HLE::Applets::Applet::Create(applet_id, parent, false, shared_from_this());
    }
}

ResultCode AppletManager::PreloadLibraryApplet(AppletId applet_id) {
    if (GetAppletSlot(AppletSlot::LibraryApplet)->registered) {
        return {ErrorDescription::AlreadyExists, ErrorModule::Applet, ErrorSummary::InvalidState,
                ErrorLevel::Status};
    }

    last_library_launcher_slot = active_slot;
    last_prepared_library_applet = applet_id;

    auto cfg = Service::CFG::GetModule(system);
    auto process =
        NS::LaunchTitle(FS::MediaType::NAND, GetTitleIdForApplet(applet_id, cfg->GetRegionValue()));
    if (process) {
        return RESULT_SUCCESS;
    }

    // If we weren't able to load the native applet title, try to fallback to an HLE implementation.
    auto applet = HLE::Applets::Applet::Get(applet_id);
    if (applet) {
        LOG_WARNING(Service_APT, "applet has already been started id={:08X}", applet_id);
        return RESULT_SUCCESS;
    } else {
        auto parent = GetAppletSlotId(last_library_launcher_slot);
        LOG_DEBUG(Service_APT, "Creating HLE applet {:03X} with parent {:03X}", applet_id, parent);
        return HLE::Applets::Applet::Create(applet_id, parent, true, shared_from_this());
    }
}

ResultCode AppletManager::FinishPreloadingLibraryApplet(AppletId applet_id) {
    // TODO(Subv): This function should fail depending on the applet preparation state.
    GetAppletSlot(AppletSlot::LibraryApplet)->loaded = true;
    return RESULT_SUCCESS;
}

ResultCode AppletManager::StartLibraryApplet(AppletId applet_id,
                                             std::shared_ptr<Kernel::Object> object,
                                             const std::vector<u8>& buffer) {
    active_slot = AppletSlot::LibraryApplet;

    auto send_res = SendParameter({
        .sender_id = GetAppletSlotId(last_library_launcher_slot),
        .destination_id = applet_id,
        .signal = SignalType::Wakeup,
        .object = std::move(object),
        .buffer = buffer,
    });
    if (send_res.IsError()) {
        active_slot = last_library_launcher_slot;
        return send_res;
    }

    return RESULT_SUCCESS;
}

ResultCode AppletManager::PrepareToCloseLibraryApplet(bool not_pause, bool exiting,
                                                      bool jump_home) {
    if (next_parameter) {
        return {ErrCodes::ParameterPresent, ErrorModule::Applet, ErrorSummary::InvalidState,
                ErrorLevel::Status};
    }

    if (!not_pause)
        library_applet_closing_command = SignalType::WakeupByPause;
    else if (jump_home)
        library_applet_closing_command = SignalType::WakeupToJumpHome;
    else if (exiting)
        library_applet_closing_command = SignalType::WakeupByCancel;
    else
        library_applet_closing_command = SignalType::WakeupByExit;

    return RESULT_SUCCESS;
}

ResultCode AppletManager::CloseLibraryApplet(std::shared_ptr<Kernel::Object> object,
                                             const std::vector<u8>& buffer) {
    auto slot = GetAppletSlot(AppletSlot::LibraryApplet);
    auto destination_id = GetAppletSlotId(last_library_launcher_slot);

    active_slot = last_library_launcher_slot;

    MessageParameter param = {
        .sender_id = slot->applet_id,
        .destination_id = destination_id,
        .signal = library_applet_closing_command,
        .object = std::move(object),
        .buffer = buffer,
    };

    if (library_applet_closing_command != SignalType::WakeupByPause) {
        CancelAndSendParameter(param);
        // TODO: Terminate the running applet title
        slot->Reset();
    } else {
        SendParameter(param);
    }

    return RESULT_SUCCESS;
}

ResultCode AppletManager::CancelLibraryApplet(bool app_exiting) {
    if (next_parameter) {
        return {ErrCodes::ParameterPresent, ErrorModule::Applet, ErrorSummary::InvalidState,
                ErrorLevel::Status};
    }

    auto slot = GetAppletSlot(AppletSlot::LibraryApplet);
    if (!slot->registered) {
        return {ErrCodes::InvalidAppletSlot, ErrorModule::Applet, ErrorSummary::InvalidState,
                ErrorLevel::Status};
    }

    return SendParameter({
        .sender_id = GetAppletSlotId(last_library_launcher_slot),
        .destination_id = slot->applet_id,
        .signal = SignalType::WakeupByCancel,
    });
}

ResultCode AppletManager::PrepareToStartSystemApplet(AppletId applet_id) {
    // The real APT service returns an error if there's a pending APT parameter when this function
    // is called.
    if (next_parameter) {
        return {ErrCodes::ParameterPresent, ErrorModule::Applet, ErrorSummary::InvalidState,
                ErrorLevel::Status};
    }

    last_system_launcher_slot = active_slot;
    return RESULT_SUCCESS;
}

ResultCode AppletManager::StartSystemApplet(AppletId applet_id,
                                            std::shared_ptr<Kernel::Object> object,
                                            const std::vector<u8>& buffer) {
    auto source_applet_id = AppletId::None;
    if (last_system_launcher_slot != AppletSlot::Error) {
        const auto slot_data = GetAppletSlot(last_system_launcher_slot);
        source_applet_id = slot_data->applet_id;

        // If a system applet is launching another system applet, reset the slot to avoid conflicts.
        // This is needed because system applets won't necessarily call CloseSystemApplet before
        // exiting.
        if (last_system_launcher_slot == AppletSlot::SystemApplet) {
            slot_data->Reset();
        }
    }

    // If a system applet is not already registered, it is started by APT.
    const auto slot_id =
        applet_id == AppletId::HomeMenu ? AppletSlot::HomeMenu : AppletSlot::SystemApplet;
    if (!GetAppletSlot(slot_id)->registered) {
        auto cfg = Service::CFG::GetModule(system);
        auto process = NS::LaunchTitle(FS::MediaType::NAND,
                                       GetTitleIdForApplet(applet_id, cfg->GetRegionValue()));
        if (!process) {
            // TODO: Find the right error code.
            return {ErrorDescription::NotFound, ErrorModule::Applet, ErrorSummary::NotSupported,
                    ErrorLevel::Permanent};
        }
    }

    active_slot = slot_id;

    SendApplicationParameterAfterRegistration({
        .sender_id = source_applet_id,
        .destination_id = applet_id,
        .signal = SignalType::Wakeup,
        .object = std::move(object),
        .buffer = buffer,
    });

    return RESULT_SUCCESS;
}

ResultCode AppletManager::PrepareToCloseSystemApplet() {
    if (next_parameter) {
        return {ErrCodes::ParameterPresent, ErrorModule::Applet, ErrorSummary::InvalidState,
                ErrorLevel::Status};
    }

    return RESULT_SUCCESS;
}

ResultCode AppletManager::CloseSystemApplet(std::shared_ptr<Kernel::Object> object,
                                            const std::vector<u8>& buffer) {
    ASSERT_MSG(active_slot == AppletSlot::HomeMenu || active_slot == AppletSlot::SystemApplet,
               "Attempting to close a system applet from a non-system applet.");

    auto slot = GetAppletSlot(active_slot);
    auto closed_applet_id = slot->applet_id;

    active_slot = last_system_launcher_slot;
    slot->Reset();

    if (ordered_to_close_sys_applet) {
        ordered_to_close_sys_applet = false;

        active_slot = AppletSlot::Application;
        CancelAndSendParameter({
            .sender_id = closed_applet_id,
            .destination_id = AppletId::Application,
            .signal = SignalType::WakeupByExit,
            .object = std::move(object),
            .buffer = buffer,
        });
    }

    // TODO: Terminate the running applet title
    return RESULT_SUCCESS;
}

ResultCode AppletManager::OrderToCloseSystemApplet() {
    if (active_slot == AppletSlot::Error) {
        return {ErrCodes::InvalidAppletSlot, ErrorModule::Applet, ErrorSummary::InvalidState,
                ErrorLevel::Status};
    }

    auto active_slot_data = GetAppletSlot(active_slot);
    if (active_slot_data->applet_id == AppletId::None ||
        active_slot_data->attributes.applet_pos != AppletPos::Application) {
        return {ErrCodes::InvalidAppletSlot, ErrorModule::Applet, ErrorSummary::InvalidState,
                ErrorLevel::Status};
    }

    auto system_slot = GetAppletSlotFromPos(AppletPos::System);
    if (system_slot == AppletSlot::Error) {
        return {ErrorDescription::NotFound, ErrorModule::Applet, ErrorSummary::NotFound,
                ErrorLevel::Status};
    }

    auto system_slot_data = GetAppletSlot(system_slot);
    if (!system_slot_data->registered) {
        return {ErrorDescription::NotFound, ErrorModule::Applet, ErrorSummary::NotFound,
                ErrorLevel::Status};
    }

    ordered_to_close_sys_applet = true;
    active_slot = system_slot;

    SendParameter({
        .sender_id = AppletId::Application,
        .destination_id = system_slot_data->applet_id,
        .signal = SignalType::WakeupByCancel,
    });

    return RESULT_SUCCESS;
}

ResultCode AppletManager::PrepareToJumpToHomeMenu() {
    if (next_parameter) {
        return {ErrCodes::ParameterPresent, ErrorModule::Applet, ErrorSummary::InvalidState,
                ErrorLevel::Status};
    }

    last_jump_to_home_slot = active_slot;
    if (last_jump_to_home_slot == AppletSlot::Application) {
        EnsureHomeMenuLoaded();
    }

    return RESULT_SUCCESS;
}

ResultCode AppletManager::JumpToHomeMenu(std::shared_ptr<Kernel::Object> object,
                                         const std::vector<u8>& buffer) {
    if (last_jump_to_home_slot != AppletSlot::Error) {
        auto slot_data = GetAppletSlot(last_jump_to_home_slot);
        if (slot_data->applet_id != AppletId::None) {
            MessageParameter param;
            param.object = std::move(object);
            param.buffer = buffer;

            switch (slot_data->attributes.applet_pos) {
            case AppletPos::Application:
                active_slot = AppletSlot::HomeMenu;

                param.destination_id = AppletId::HomeMenu;
                param.sender_id = AppletId::Application;
                param.signal = SignalType::WakeupByPause;
                SendParameter(param);
                break;
            case AppletPos::Library:
                param.destination_id = slot_data->applet_id;
                param.sender_id = slot_data->applet_id;
                param.signal = SignalType::WakeupByCancel;
                SendParameter(param);
                break;
            case AppletPos::System:
                if (slot_data->attributes.is_home_menu) {
                    param.destination_id = slot_data->applet_id;
                    param.sender_id = slot_data->applet_id;
                    param.signal = SignalType::WakeupToJumpHome;
                    SendParameter(param);
                }
                break;
            case AppletPos::SysLibrary: {
                const auto system_slot_data = GetAppletSlot(AppletSlot::SystemApplet);
                param.destination_id = slot_data->applet_id;
                param.sender_id = slot_data->applet_id;
                param.signal = system_slot_data->registered ? SignalType::WakeupByCancel
                                                            : SignalType::WakeupToJumpHome;
                SendParameter(param);
                break;
            }
            default:
                break;
            }
        }
    }

    return RESULT_SUCCESS;
}

ResultCode AppletManager::PrepareToLeaveHomeMenu() {
    if (!GetAppletSlot(AppletSlot::Application)->registered) {
        return {ErrCodes::InvalidAppletSlot, ErrorModule::Applet, ErrorSummary::InvalidState,
                ErrorLevel::Status};
    }

    if (next_parameter) {
        return {ErrCodes::ParameterPresent, ErrorModule::Applet, ErrorSummary::InvalidState,
                ErrorLevel::Status};
    }

    return RESULT_SUCCESS;
}

ResultCode AppletManager::LeaveHomeMenu(std::shared_ptr<Kernel::Object> object,
                                        const std::vector<u8>& buffer) {
    active_slot = AppletSlot::Application;

    SendParameter({
        .sender_id = AppletId::HomeMenu,
        .destination_id = AppletId::Application,
        .signal = SignalType::WakeupByPause,
        .object = std::move(object),
        .buffer = buffer,
    });

    return RESULT_SUCCESS;
}

ResultCode AppletManager::OrderToCloseApplication() {
    if (active_slot == AppletSlot::Error) {
        return {ErrCodes::InvalidAppletSlot, ErrorModule::Applet, ErrorSummary::InvalidState,
                ErrorLevel::Status};
    }

    auto active_slot_data = GetAppletSlot(active_slot);
    if (active_slot_data->applet_id == AppletId::None ||
        active_slot_data->attributes.applet_pos != AppletPos::System) {
        return {ErrCodes::InvalidAppletSlot, ErrorModule::Applet, ErrorSummary::InvalidState,
                ErrorLevel::Status};
    }

    ordered_to_close_application = true;
    active_slot = AppletSlot::Application;

    SendParameter({
        .sender_id = AppletId::HomeMenu,
        .destination_id = AppletId::Application,
        .signal = SignalType::WakeupByCancel,
    });

    return RESULT_SUCCESS;
}

ResultCode AppletManager::PrepareToCloseApplication(bool return_to_sys) {
    if (active_slot == AppletSlot::Error) {
        return {ErrCodes::InvalidAppletSlot, ErrorModule::Applet, ErrorSummary::InvalidState,
                ErrorLevel::Status};
    }

    auto active_slot_data = GetAppletSlot(active_slot);
    if (active_slot_data->applet_id == AppletId::None ||
        active_slot_data->attributes.applet_pos != AppletPos::Application) {
        return {ErrCodes::InvalidAppletSlot, ErrorModule::Applet, ErrorSummary::InvalidState,
                ErrorLevel::Status};
    }

    auto system_slot_data = GetAppletSlot(AppletSlot::SystemApplet);
    auto home_menu_slot_data = GetAppletSlot(AppletSlot::HomeMenu);

    if (!application_cancelled && return_to_sys) {
        // TODO: Left side of the OR also includes "&& !power_button_clicked", but this isn't
        // implemented yet.
        if (!ordered_to_close_application || !system_slot_data->registered) {
            application_close_target = AppletSlot::HomeMenu;
        } else {
            application_close_target = AppletSlot::SystemApplet;
        }
    } else {
        application_close_target = AppletSlot::Error;
    }

    if (application_close_target != AppletSlot::HomeMenu && !system_slot_data->registered &&
        !home_menu_slot_data->registered) {
        return {ErrCodes::InvalidAppletSlot, ErrorModule::Applet, ErrorSummary::InvalidState,
                ErrorLevel::Status};
    }

    if (next_parameter) {
        return {ErrCodes::ParameterPresent, ErrorModule::Applet, ErrorSummary::InvalidState,
                ErrorLevel::Status};
    }

    if (application_close_target == AppletSlot::HomeMenu) {
        // Real APT would make sure home menu is loaded here. However, this is only really
        // needed if the home menu wasn't loaded in the first place. Since we want to
        // preserve normal behavior when the user loaded the game directly without going
        // through home menu, we skip this. Then, later we just close to the game list
        // when the application finishes closing.
        // EnsureHomeMenuLoaded();
    }

    return RESULT_SUCCESS;
}

ResultCode AppletManager::CloseApplication(std::shared_ptr<Kernel::Object> object,
                                           const std::vector<u8>& buffer) {
    ordered_to_close_application = false;
    application_cancelled = false;

    GetAppletSlot(AppletSlot::Application)->Reset();

    if (application_close_target != AppletSlot::Error) {
        // If exiting to the home menu and it is not loaded, exit to game list.
        if (application_close_target == AppletSlot::HomeMenu &&
            !GetAppletSlot(application_close_target)->registered) {
            system.RequestShutdown();
        } else {
            active_slot = application_close_target;

            CancelAndSendParameter({
                .sender_id = AppletId::Application,
                .destination_id = GetAppletSlot(application_close_target)->applet_id,
                .signal = SignalType::WakeupByExit,
                .object = std::move(object),
                .buffer = buffer,
            });
        }
    }

    // TODO: Terminate the application process.
    return RESULT_SUCCESS;
}

ResultVal<AppletManager::AppletManInfo> AppletManager::GetAppletManInfo(
    AppletPos requested_applet_pos) {
    auto active_applet_pos = AppletPos::Invalid;
    auto active_applet_id = AppletId::None;
    if (active_slot != AppletSlot::Error) {
        auto active_slot_data = GetAppletSlot(active_slot);
        if (active_slot_data->applet_id != AppletId::None) {
            active_applet_pos = active_slot_data->attributes.applet_pos;
            active_applet_id = active_slot_data->applet_id;
        }
    }

    auto requested_applet_id = AppletId::None;
    auto requested_slot = GetAppletSlotFromPos(requested_applet_pos);
    if (requested_slot != AppletSlot::Error) {
        auto requested_slot_data = GetAppletSlot(requested_slot);
        if (requested_slot_data->registered) {
            requested_applet_id = requested_slot_data->applet_id;
        }
    }

    return MakeResult<AppletManInfo>({
        .active_applet_pos = active_applet_pos,
        .requested_applet_id = requested_applet_id,
        .home_menu_applet_id = AppletId::HomeMenu,
        .active_applet_id = active_applet_id,
    });
}

ResultVal<AppletManager::AppletInfo> AppletManager::GetAppletInfo(AppletId app_id) {
    auto slot = GetAppletSlotFromId(app_id);
    if (slot == AppletSlot::Error) {
        return ResultCode(ErrorDescription::NotFound, ErrorModule::Applet, ErrorSummary::NotFound,
                          ErrorLevel::Status);
    }

    auto slot_data = GetAppletSlot(slot);
    if (!slot_data->registered) {
        return ResultCode(ErrorDescription::NotFound, ErrorModule::Applet, ErrorSummary::NotFound,
                          ErrorLevel::Status);
    }

    // TODO: Basic heuristic to guess media type, needs proper implementation.
    auto media_type = ((slot_data->title_id >> 32) & 0xFFFFFFFF) == 0x00040000
                          ? Service::FS::MediaType::SDMC
                          : Service::FS::MediaType::NAND;
    return MakeResult<AppletInfo>({slot_data->title_id, media_type, slot_data->registered,
                                   slot_data->loaded, slot_data->attributes.raw});
}

ResultCode AppletManager::PrepareToDoApplicationJump(u64 title_id, FS::MediaType media_type,
                                                     ApplicationJumpFlags flags) {
    // A running application can not launch another application directly because the applet state
    // for the Application slot is already in use. The way this is implemented in hardware is to
    // launch the Home Menu and tell it to launch our desired application.

    ASSERT_MSG(flags != ApplicationJumpFlags::UseStoredParameters,
               "Unimplemented application jump flags 1");

    // Save the title data to send it to the Home Menu when DoApplicationJump is called.
    auto application_slot_data = GetAppletSlot(AppletSlot::Application);
    app_jump_parameters.current_title_id = application_slot_data->title_id;
    // TODO(Subv): Retrieve the correct media type of the currently-running application. For now
    // just assume NAND.
    app_jump_parameters.current_media_type = FS::MediaType::NAND;
    app_jump_parameters.next_title_id = flags == ApplicationJumpFlags::UseCurrentParameters
                                            ? application_slot_data->title_id
                                            : title_id;
    app_jump_parameters.next_media_type = media_type;
    app_jump_parameters.flags = flags;

    // Note: The real console uses the Home Menu to perform the application jump, therefore the menu
    // needs to be running. The real APT module starts the Home Menu here if it's not already
    // running, we don't have to do this. See `EnsureHomeMenuLoaded` for launching the Home Menu.
    return RESULT_SUCCESS;
}

ResultCode AppletManager::DoApplicationJump(const DeliverArg& arg) {
    // Note: The real console uses the Home Menu to perform the application jump, it goes
    // OldApplication->Home Menu->NewApplication. We do not need to use the Home Menu to do this so
    // we launch the new application directly. In the real APT service, the Home Menu must be
    // running to do this, otherwise error 0xC8A0CFF0 is returned.

    auto application_slot_data = GetAppletSlot(AppletSlot::Application);
    auto title_id = application_slot_data->title_id;
    application_slot_data->Reset();

    // Set the delivery parameters.
    deliver_arg = arg;
    if (app_jump_parameters.flags != ApplicationJumpFlags::UseCurrentParameters) {
        // The source program ID is not updated when using flags 0x2.
        deliver_arg->source_program_id = title_id;
    }

    // TODO(Subv): Terminate the current Application.

    // Note: The real console sends signal 17 (WakeupToLaunchApplication) to the Home Menu, this
    // prompts it to call GetProgramIdOnApplicationJump and
    // PrepareToStartApplication/StartApplication on the title to launch.
    active_slot = AppletSlot::Application;

    // Perform a soft-reset if we're trying to relaunch the same title.
    // TODO(Subv): Note that this reboots the entire emulated system, a better way would be to
    // simply re-launch the title without closing all services, but this would only work for
    // installed titles since we have no way of getting the file path of an arbitrary game dump
    // based only on the title id.

    auto new_path = Service::AM::GetTitleContentPath(app_jump_parameters.next_media_type,
                                                     app_jump_parameters.next_title_id);
    if (new_path.empty() || !FileUtil::Exists(new_path)) {
        LOG_CRITICAL(
            Service_APT,
            "Failed to find title during application jump: {} Resetting current title instead.",
            new_path);
        new_path.clear();
    }

    system.RequestReset(new_path);
    return RESULT_SUCCESS;

    // Launch the title directly.
    // The emulator does not suport terminating old processes, would require a lot of cleanup
    // This code is left commented for when this is implemented, for now we cannot use NS
    // as the old process resources would interfere with the new ones
    /*
    auto process =
        NS::LaunchTitle(app_jump_parameters.next_media_type, app_jump_parameters.next_title_id);
    if (!process) {
        LOG_CRITICAL(Service_APT, "Failed to launch title during application jump, exiting.");
        system.RequestShutdown();
    }
    return RESULT_SUCCESS;
    */
}

ResultCode AppletManager::PrepareToStartApplication(u64 title_id, FS::MediaType media_type) {
    if (active_slot == AppletSlot::Error ||
        GetAppletSlot(active_slot)->attributes.applet_pos != AppletPos::System) {
        return {ErrCodes::InvalidAppletSlot, ErrorModule::Applet, ErrorSummary::InvalidState,
                ErrorLevel::Status};
    }

    // TODO(Subv): This should return 0xc8a0cff0 if the applet preparation state is already set

    if (GetAppletSlot(AppletSlot::Application)->registered) {
        return {ErrorDescription::AlreadyExists, ErrorModule::Applet, ErrorSummary::InvalidState,
                ErrorLevel::Status};
    }

    ASSERT_MSG(!app_start_parameters,
               "Trying to prepare an application when another is already prepared");

    app_start_parameters.emplace();
    app_start_parameters->next_title_id = title_id;
    app_start_parameters->next_media_type = media_type;

    return RESULT_SUCCESS;
}

ResultCode AppletManager::StartApplication(const std::vector<u8>& parameter,
                                           const std::vector<u8>& hmac, bool paused) {
    // The delivery argument is always unconditionally set.
    deliver_arg.emplace(DeliverArg{parameter, hmac});

    // Note: APT first checks if we can launch the application via AM::CheckDemoLaunchRights and
    // returns 0xc8a12403 if we can't. We intentionally do not implement that check.

    // TODO(Subv): The APT service performs several checks here related to the exheader flags of the
    // process we're launching and other things like title id blacklists. We do not yet implement
    // any of that.

    // TODO(Subv): The real APT service doesn't seem to check whether the titleid to launch is set
    // or not, it either launches NATIVE_FIRM if some internal state is set, or fails when calling
    // PM::LaunchTitle. We should research more about that.
    ASSERT_MSG(app_start_parameters, "Trying to start an application without preparing it first.");

    active_slot = AppletSlot::Application;

    // Launch the title directly.
    auto process =
        NS::LaunchTitle(app_start_parameters->next_media_type, app_start_parameters->next_title_id);
    if (!process) {
        LOG_CRITICAL(Service_APT, "Failed to launch title during application start, exiting.");
        system.RequestShutdown();
    }

    app_start_parameters.reset();

    if (!paused) {
        return WakeupApplication();
    }

    return RESULT_SUCCESS;
}

ResultCode AppletManager::WakeupApplication() {
    // Send a Wakeup signal via the apt parameter to the application once it registers itself.
    // The real APT service does this by spin waiting on another thread until the application is
    // registered.
    SendApplicationParameterAfterRegistration({
        .sender_id = AppletId::HomeMenu,
        .destination_id = AppletId::Application,
        .signal = SignalType::Wakeup,
    });

    return RESULT_SUCCESS;
}

ResultCode AppletManager::CancelApplication() {
    auto application_slot_data = GetAppletSlot(AppletSlot::Application);
    if (application_slot_data->applet_id == AppletId::None) {
        return {ErrCodes::InvalidAppletSlot, ErrorModule::Applet, ErrorSummary::InvalidState,
                ErrorLevel::Status};
    }

    application_cancelled = true;

    SendApplicationParameterAfterRegistration({
        .sender_id = active_slot != AppletSlot::Error ? GetAppletSlot(active_slot)->applet_id
                                                      : AppletId::None,
        .destination_id = AppletId::Application,
        .signal = SignalType::WakeupByCancel,
    });

    return RESULT_SUCCESS;
}

void AppletManager::SendApplicationParameterAfterRegistration(const MessageParameter& parameter) {
    auto slot = GetAppletSlotFromId(parameter.destination_id);

    // If the application is already registered, immediately send the parameter
    if (slot != AppletSlot::Error && GetAppletSlot(slot)->registered) {
        CancelAndSendParameter(parameter);
        return;
    }

    // Otherwise queue it until the Application calls APT::Enable
    delayed_parameter = parameter;
}

void AppletManager::EnsureHomeMenuLoaded() {
    // TODO(Subv): The real APT service sends signal 12 (WakeupByCancel) to the currently running
    // System applet, waits for it to finish, and then launches the Home Menu.
    ASSERT_MSG(!GetAppletSlot(AppletSlot::SystemApplet)->registered,
               "A system applet is already running");

    if (GetAppletSlot(AppletSlot::HomeMenu)->registered) {
        // The Home Menu is already running.
        return;
    }

    auto cfg = Service::CFG::GetModule(system);
    ASSERT_MSG(cfg, "CFG Module missing!");

    auto menu_title_id = GetTitleIdForApplet(AppletId::HomeMenu, cfg->GetRegionValue());
    auto process = NS::LaunchTitle(FS::MediaType::NAND, menu_title_id);
    if (!process) {
        LOG_WARNING(Service_APT,
                    "The Home Menu failed to launch, application jumping will not work.");
    }
}

static void CaptureFrameBuffer(Core::System& system, u32 capture_offset, VAddr src, u32 height,
                               u32 format) {
    static constexpr auto screen_capture_base_vaddr = static_cast<VAddr>(0x1F500000);
    static constexpr auto screen_width = 240;
    static constexpr auto screen_width_pow2 = 256;
    const auto bpp = format < 2 ? 3 : 2;

    Memory::RasterizerFlushVirtualRegion(src, screen_width * height * bpp,
                                         Memory::FlushMode::Flush);

    auto dst_vaddr = screen_capture_base_vaddr + capture_offset;
    auto dst_ptr = system.Memory().GetPointer(dst_vaddr);
    const auto src_ptr = system.Memory().GetPointer(src);
    for (u32 y = 0; y < height; y++) {
        for (u32 x = 0; x < screen_width; x++) {
            auto dst_offset =
                VideoCore::GetMortonOffset(x, y, bpp) + (y & ~7) * screen_width_pow2 * bpp;
            auto src_offset = bpp * (screen_width * y + x);
            std::memcpy(dst_ptr + dst_offset, src_ptr + src_offset, bpp);
        }
    }

    Memory::RasterizerFlushVirtualRegion(dst_vaddr, screen_width_pow2 * height * bpp,
                                         Memory::FlushMode::Invalidate);
}

void AppletManager::CaptureFrameBuffers() {
    auto gsp =
        Core::System::GetInstance().ServiceManager().GetService<Service::GSP::GSP_GPU>("gsp::Gpu");
    auto active_thread_id = gsp->GetActiveThreadId();
    auto top_screen = gsp->GetFrameBufferInfo(active_thread_id, 0);
    auto bottom_screen = gsp->GetFrameBufferInfo(active_thread_id, 1);

    auto top_fb = top_screen->framebuffer_info[top_screen->index];
    auto bottom_fb = bottom_screen->framebuffer_info[bottom_screen->index];

    CaptureFrameBuffer(system, capture_info->bottom_screen_left_offset, bottom_fb.address_left, 320,
                       capture_info->bottom_screen_format);
    CaptureFrameBuffer(system, capture_info->top_screen_left_offset, top_fb.address_left, 400,
                       capture_info->top_screen_format);
    if (capture_info->is_3d) {
        CaptureFrameBuffer(system, capture_info->top_screen_right_offset, top_fb.address_right, 400,
                           capture_info->top_screen_format);
    }
}

void AppletManager::LoadInputDevices() {
    if (Settings::values.home_button_initialized || Settings::values.skip_home_button) {
        return;
    } else {
        Settings::values.home_button = Input::CreateDevice<Input::ButtonDevice>(
            Settings::values.current_input_profile.buttons[Settings::NativeButton::Home]);
        Settings::values.home_button_initialized = true;
    }
}

void AppletManager::HomeButtonUpdateEvent(std::uintptr_t user_data, s64 cycles_late) {
    if (Settings::values.isReloading || Settings::values.skip_home_button)
        return;
    
    if (is_device_reload_pending.exchange(false)) {
        LoadInputDevices();
    }

    const bool state = Settings::values.home_button->GetStatus();
    // NOTE: We technically do support loading and jumping to home menu even if it isn't
    // initially registered. However since the home menu suspend is not bug-free, we don't
    // want normal users who didn't launch the home menu accidentally pressing the home
    // button binding and freezing their game, so for now, gate it to only environments
    // where the home menu was already loaded by the user (last condition).
    if (state && !last_home_button_state && GetAppletSlot(AppletSlot::HomeMenu)->registered) {
        SendNotification(Notification::HomeButtonSingle);
    }
    last_home_button_state = state;

    // Reschedule recurrent event
    Core::System::GetInstance().CoreTiming().ScheduleEvent(
        usToCycles(home_button_update_interval_us) - cycles_late, home_button_update_event);
}

AppletManager::AppletManager(Core::System& system) : system(system) {
    LoadInputDevices();
    lock = system.Kernel().CreateMutex(false, "APT_U:Lock");
    for (std::size_t slot = 0; slot < applet_slots.size(); ++slot) {
        auto& slot_data = applet_slots[slot];
        slot_data.slot = static_cast<AppletSlot>(slot);
        slot_data.applet_id = AppletId::None;
        slot_data.attributes.raw = 0;
        slot_data.registered = false;
        slot_data.loaded = false;
        slot_data.notification_event =
            system.Kernel().CreateEvent(Kernel::ResetType::OneShot, "APT:Notification");
        slot_data.parameter_event =
            system.Kernel().CreateEvent(Kernel::ResetType::OneShot, "APT:Parameter");
    }
    HLE::Applets::Init();
    home_button_update_event = Core::System::GetInstance().CoreTiming().RegisterEvent(
        "Home Button Update Event", [this](std::uintptr_t user_data, s64 cycles_late) {
            HomeButtonUpdateEvent(user_data, cycles_late);
        });
    Core::System::GetInstance().CoreTiming().ScheduleEvent(
        usToCycles(home_button_update_interval_us), home_button_update_event);
}

AppletManager::~AppletManager() {
    HLE::Applets::Shutdown();
}

void AppletManager::ReloadInputDevices() {
    is_device_reload_pending.store(true);
}

} // namespace Service::APT
