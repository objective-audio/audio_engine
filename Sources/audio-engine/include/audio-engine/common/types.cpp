//
//  types.cpp
//

#include "types.h"

#import <AudioToolbox/AudioToolbox.h>

using namespace yas;
using namespace yas::audio;

uint32_t yas::to_uint32(direction const &dir) {
    return static_cast<uint32_t>(dir);
}

std::string yas::to_string(pcm_format const &pcm_format) {
    switch (pcm_format) {
        case pcm_format::float32:
            return "Float32";
        case pcm_format::float64:
            return "Float64";
        case pcm_format::int16:
            return "Int16";
        case pcm_format::fixed824:
            return "Fixed8.24";
        case pcm_format::other:
            return "Other";
    }
}

std::type_info const &yas::to_sample_type(pcm_format const &pcm_format) {
    switch (pcm_format) {
        case pcm_format::float32:
            return typeid(float);
        case pcm_format::float64:
            return typeid(double);
        case pcm_format::int16:
            return typeid(int16_t);
        case pcm_format::fixed824:
            return typeid(int32_t);
        case pcm_format::other:
            return typeid(std::nullptr_t);
    }
}

uint32_t yas::to_bit_depth(audio::pcm_format const &pcm_format) {
    switch (pcm_format) {
        case pcm_format::float32:
            return 32;
        case pcm_format::float64:
            return 64;
        case pcm_format::int16:
            return 16;
        case pcm_format::fixed824:
            return 32;
        case pcm_format::other:
            return 0;
    }
}

std::string yas::to_string(audio::direction const &dir) {
    switch (dir) {
        case audio::direction::output:
            return "output";
        case audio::direction::input:
            return "input";
    }
}

std::string yas::to_string(AudioUnitScope const scope) {
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

std::string yas::to_string(audio::render_type const &type) {
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

std::string yas::to_string(OSStatus const err) {
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

std::ostream &operator<<(std::ostream &os, yas::audio::pcm_format const &value) {
    os << to_string(value);
    return os;
}

std::ostream &operator<<(std::ostream &os, yas::audio::direction const &value) {
    os << to_string(value);
    return os;
}

std::ostream &operator<<(std::ostream &os, yas::audio::render_type const &value) {
    os << to_string(value);
    return os;
}
