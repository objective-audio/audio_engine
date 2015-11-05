//
//  yas_exception.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_exception.h"
#include <exception>
#include <CoreFoundation/CoreFoundation.h>

using namespace yas;

static std::string _au_error_description(const OSStatus &err)
{
    switch (err) {
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

void yas::raise_with_reason(const std::string &reason)
{
    throw std::runtime_error(reason);
}

void yas::raise_if_main_thread()
{
    if (CFEqual(CFRunLoopGetCurrent(), CFRunLoopGetMain())) {
        throw std::runtime_error("invalid call on main thread.");
    }
}

void yas::raise_if_sub_thread()
{
    if (!CFEqual(CFRunLoopGetCurrent(), CFRunLoopGetMain())) {
        throw std::runtime_error("invalid call on sub thread.");
    }
}

void yas::raise_if_audio_unit_error(const OSStatus &err)
{
    if (err != noErr) {
        throw std::runtime_error("audio unit error : " + std::to_string(err) + " - " + _au_error_description(err));
    }
}
