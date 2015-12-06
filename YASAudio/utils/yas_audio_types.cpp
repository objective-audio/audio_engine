//
//  yas_audio_types.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_types.h"
#import <AudioToolbox/AudioToolbox.h>

using namespace yas;

UInt32 yas::to_uint32(const audio::direction &dir) {
    return static_cast<UInt32>(dir);
}

std::string yas::to_string(const audio::direction &dir) {
    switch (dir) {
        case audio::direction::output:
            return "output";
        case audio::direction::input:
            return "input";
    }
}

std::string yas::to_string(const AudioUnitScope scope) {
    switch (scope) {
        case kAudioUnitScope_Global:
            return "global";
        case kAudioUnitScope_Input:
            return "input";
        case kAudioUnitScope_Output:
            return "output";
        case kAudioUnitScope_Group:
            return "group";
        case kAudioUnitScope_Part:
            return "part";
        case kAudioUnitScope_Note:
            return "note";
        case kAudioUnitScope_Layer:
            return "layer";
        case kAudioUnitScope_LayerItem:
            return "layer_item";
    }

    return "unknown";
}

std::string yas::to_string(const audio::render_type &type) {
    switch (type) {
        case audio::render_type::normal:
            return "normal";
        case audio::render_type::notify:
            return "notify";
        case audio::render_type::input:
            return "input";
        case audio::render_type::unknown:
            return "unknown";
    }
}

std::string yas::to_string(const OSStatus err) {
    switch (err) {
        case noErr:
            return "noErr";
        case kAudioUnitErr_InvalidProperty:
            return "InvalidProperty";
        case kAudioUnitErr_InvalidParameter:
            return "InvalidParameter";
        case kAudioUnitErr_InvalidElement:
            return "InvalidElement";
        case kAudioUnitErr_NoConnection:
            return "NoConnection";
        case kAudioUnitErr_FailedInitialization:
            return "FailedInitialization";
        case kAudioUnitErr_TooManyFramesToProcess:
            return "TooManyFramesToProcess";
        case kAudioUnitErr_InvalidFile:
            return "InvalidFile";
        case kAudioUnitErr_FormatNotSupported:
            return "FormatNotSupported";
        case kAudioUnitErr_Uninitialized:
            return "Uninitialized";
        case kAudioUnitErr_InvalidScope:
            return "InvalidScope";
        case kAudioUnitErr_PropertyNotWritable:
            return "PropertyNotWritable";
        case kAudioUnitErr_CannotDoInCurrentContext:
            return "CannotDoInCurrentContext";
        case kAudioUnitErr_InvalidPropertyValue:
            return "InvalidPropertyValue";
        case kAudioUnitErr_PropertyNotInUse:
            return "PropertyNotInUse";
        case kAudioUnitErr_Initialized:
            return "Initialized";
        case kAudioUnitErr_InvalidOfflineRender:
            return "InvalidOfflineRender";
        case kAudioUnitErr_Unauthorized:
            return "Unauthorized";
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
        case kAudioHardwareNotRunningError:
            return "HardwareNotRunning";
        case kAudioHardwareUnspecifiedError:
            return "HardwareUnspecifiedError";
        case kAudioHardwareUnknownPropertyError:
            return "HardwareUnknownPropertyError";
        case kAudioHardwareBadPropertySizeError:
            return "HardwareBadPropertySizeError";
        case kAudioHardwareIllegalOperationError:
            return "HardwareIllegalOperationError";
        case kAudioHardwareBadObjectError:
            return "HardwareBadObjectError";
        case kAudioHardwareBadDeviceError:
            return "HardwareBadDeviceError";
        case kAudioHardwareBadStreamError:
            return "HardwareBadStreamError";
        case kAudioHardwareUnsupportedOperationError:
            return "HardwareUnsupportedOperationError";
        case kAudioDeviceUnsupportedFormatError:
            return "DeviceUnsupportedFormatError";
        case kAudioDevicePermissionsError:
            return "DevicePermissionsError";
#endif
        default:
            return "Unknown";
    }
}
