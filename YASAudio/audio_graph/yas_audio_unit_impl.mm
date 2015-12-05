//
//  yas_audio_unit_impl.mm
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_unit.h"
#include "yas_audio_graph.h"
#include "yas_audio_pcm_buffer.h"
#include "yas_cf_utils.h"

#if TARGET_OS_IPHONE
#import <AVFoundation/AVFoundation.h>
#endif

using namespace yas;

#pragma mark - c functions

static OSStatus CommonRenderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                                     const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames,
                                     AudioBufferList *ioData, yas::render_type renderType)
{
    yas::render_parameters renderParameters = {
        .in_render_type = renderType,
        .io_action_flags = ioActionFlags,
        .io_time_stamp = inTimeStamp,
        .in_bus_number = inBusNumber,
        .in_number_frames = inNumberFrames,
        .io_data = ioData,
        .render_id = (render_id){inRefCon},
    };

    audio::graph::audio_unit_render(renderParameters);

    return noErr;
}

static OSStatus RenderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames,
                               AudioBufferList *ioData)
{
    return CommonRenderCallback(inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData,
                                yas::render_type::normal);
}

static OSStatus ClearCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                              const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames,
                              AudioBufferList *ioData)
{
    if (ioData) {
        audio::clear(ioData);
    }
    return noErr;
}

static OSStatus EmptyCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                              const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames,
                              AudioBufferList *ioData)
{
    return noErr;
}

static OSStatus NotifyRenderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                                     const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames,
                                     AudioBufferList *ioData)
{
    return CommonRenderCallback(inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData,
                                yas::render_type::notify);
}

static OSStatus InputRenderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                                    const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames,
                                    AudioBufferList *ioData)
{
    return CommonRenderCallback(inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData,
                                yas::render_type::input);
}

#pragma mark - core

class audio_unit::impl::core
{
   public:
    AudioUnit au_instance;
    AudioComponentDescription acd;
    bool initialized;
    render_f render_callback;
    render_f notify_callback;
    render_f input_callback;
    std::string name;

    mutable std::recursive_mutex mutex;
};

#pragma mark - impl main

audio_unit::impl::impl() : _core(std::make_unique<core>()){};

audio_unit::impl::~impl()
{
    uninitialize();
    dispose_audio_unit();
}

#pragma mark - setup audio unit

void audio_unit::impl::create_audio_unit(const AudioComponentDescription &acd)
{
    _core->acd = acd;

    AudioComponent component = AudioComponentFindNext(nullptr, &acd);
    if (!component) {
        yas_raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - Can't create audio component.");
        return;
    }

    CFStringRef cf_name = nullptr;
    yas_raise_if_au_error(AudioComponentCopyName(component, &cf_name));
    _core->name = yas::to_string(cf_name);
    CFRelease(cf_name);

    AudioUnit au = nullptr;
    yas_raise_if_au_error(AudioComponentInstanceNew(component, &au));
    set_audio_unit_instance(au);
}

void audio_unit::impl::dispose_audio_unit()
{
    if (!_core->au_instance) {
        return;
    }

    AudioUnit au = _core->au_instance;
    set_audio_unit_instance(nullptr);

    yas_raise_if_au_error(AudioComponentInstanceDispose(au));

    _core->name.clear();
}

void audio_unit::impl::initialize()
{
    if (_core->initialized) {
        return;
    }

    if (!_core->au_instance) {
        yas_raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - AudioUnit is null.");
        return;
    }

    yas_raise_if_au_error(AudioUnitInitialize(_core->au_instance));

    _core->initialized = true;
}

void audio_unit::impl::uninitialize()
{
    if (!_core->initialized) {
        return;
    }

    if (!_core->au_instance) {
        yas_raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - AudioUnit is null.");
        return;
    }

    yas_raise_if_au_error(AudioUnitUninitialize(_core->au_instance));

    _core->initialized = false;
}

bool audio_unit::impl::is_initialized() const
{
    return _core->initialized;
}

void audio_unit::impl::reset()
{
    yas_raise_if_au_error(AudioUnitReset(_core->au_instance, kAudioUnitScope_Global, 0));
}

#pragma mark - accessor

const AudioComponentDescription &audio_unit::impl::acd() const
{
    return _core->acd;
}

const std::string &audio_unit::impl::name() const
{
    return _core->name;
}

void audio_unit::impl::attach_render_callback(const UInt32 &bus_idx)
{
    if (!graph_key || !key) {
        yas_raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - Key is not assigned. graphKey(" +
                              std::to_string(*graph_key) + ") unitKey(" + std::to_string(*key) + ")");
        return;
    }

    render_id render_id{.graph = *graph_key, .unit = *key};

    AURenderCallbackStruct callbackStruct{.inputProc = RenderCallback, .inputProcRefCon = render_id.v};

    yas_raise_if_au_error(AudioUnitSetProperty(_core->au_instance, kAudioUnitProperty_SetRenderCallback,
                                               kAudioUnitScope_Input, bus_idx, &callbackStruct,
                                               sizeof(AURenderCallbackStruct)));
}

void audio_unit::impl::detach_render_callback(const UInt32 &bus_idx)
{
    AURenderCallbackStruct callbackStruct{.inputProc = ClearCallback, .inputProcRefCon = nullptr};

    yas_raise_if_au_error(AudioUnitSetProperty(_core->au_instance, kAudioUnitProperty_SetRenderCallback,
                                               kAudioUnitScope_Input, bus_idx, &callbackStruct,
                                               sizeof(AURenderCallbackStruct)));
}

void audio_unit::impl::attach_render_notify()
{
    if (!graph_key || !key) {
        yas_raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - Key is not assigned. graphKey(" +
                              std::to_string(*graph_key) + ") unitKey(" + std::to_string(*key) + ")");
        return;
    }

    render_id render_id{.graph = *graph_key, .unit = *key};

    yas_raise_if_au_error(AudioUnitAddRenderNotify(_core->au_instance, NotifyRenderCallback, render_id.v));
}

void audio_unit::impl::detach_render_notify()
{
    yas_raise_if_au_error(AudioUnitRemoveRenderNotify(_core->au_instance, NotifyRenderCallback, nullptr));
}

void audio_unit::impl::attach_input_callback()
{
    if (acd().componentType != kAudioUnitType_Output) {
        yas_raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - Not output unit.");
        return;
    }

    if (!graph_key || !key) {
        yas_raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - Key is not assigned. graphKey(" +
                              std::to_string(*graph_key) + ") unitKey(" + std::to_string(*key) + ")");
        return;
    }

    render_id render_id{.graph = *graph_key, .unit = *key};

    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = InputRenderCallback;
    callbackStruct.inputProcRefCon = render_id.v;

    yas_raise_if_au_error(AudioUnitSetProperty(_core->au_instance, kAudioOutputUnitProperty_SetInputCallback,
                                               kAudioUnitScope_Global, 0, &callbackStruct,
                                               sizeof(AURenderCallbackStruct)));
}

void audio_unit::impl::detach_input_callback()
{
    if (acd().componentType != kAudioUnitType_Output) {
        yas_raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - Not output unit.");
        return;
    }

    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = EmptyCallback;
    callbackStruct.inputProcRefCon = NULL;

    yas_raise_if_au_error(AudioUnitSetProperty(_core->au_instance, kAudioOutputUnitProperty_SetInputCallback,
                                               kAudioUnitScope_Global, 0, &callbackStruct,
                                               sizeof(AURenderCallbackStruct)));
}

void audio_unit::impl::set_render_callback(const render_f &callback)
{
    std::lock_guard<std::recursive_mutex> lock(_core->mutex);
    _core->render_callback = callback;
}

void audio_unit::impl::set_notify_callback(const render_f &callback)
{
    std::lock_guard<std::recursive_mutex> lock(_core->mutex);
    _core->notify_callback = callback;
}

void audio_unit::impl::set_input_callback(const render_f &callback)
{
    std::lock_guard<std::recursive_mutex> lock(_core->mutex);
    _core->input_callback = callback;
}

void audio_unit::impl::set_input_format(const AudioStreamBasicDescription &asbd, const UInt32 bus_idx)
{
    yas_raise_if_au_error(AudioUnitSetProperty(_core->au_instance, kAudioUnitProperty_StreamFormat,
                                               kAudioUnitScope_Input, bus_idx, &asbd,
                                               sizeof(AudioStreamBasicDescription)));
}

void audio_unit::impl::set_output_format(const AudioStreamBasicDescription &asbd, const UInt32 bus_idx)
{
    yas_raise_if_au_error(AudioUnitSetProperty(_core->au_instance, kAudioUnitProperty_StreamFormat,
                                               kAudioUnitScope_Output, bus_idx, &asbd,
                                               sizeof(AudioStreamBasicDescription)));
}

AudioStreamBasicDescription audio_unit::impl::input_format(const UInt32 bus_idx) const
{
    AudioStreamBasicDescription asbd = {0};
    UInt32 size = sizeof(AudioStreamBasicDescription);
    yas_raise_if_au_error(AudioUnitGetProperty(_core->au_instance, kAudioUnitProperty_StreamFormat,
                                               kAudioUnitScope_Input, bus_idx, &asbd, &size));
    return asbd;
}

AudioStreamBasicDescription audio_unit::impl::output_format(const UInt32 bus_idx) const
{
    AudioStreamBasicDescription asbd = {0};
    UInt32 size = sizeof(AudioStreamBasicDescription);
    yas_raise_if_au_error(AudioUnitGetProperty(_core->au_instance, kAudioUnitProperty_StreamFormat,
                                               kAudioUnitScope_Output, bus_idx, &asbd, &size));
    return asbd;
}

void audio_unit::impl::set_maximum_frames_per_slice(const UInt32 frames)
{
    yas_raise_if_au_error(AudioUnitSetProperty(_core->au_instance, kAudioUnitProperty_MaximumFramesPerSlice,
                                               kAudioUnitScope_Global, 0, &frames, sizeof(UInt32)));
}

UInt32 audio_unit::impl::maximum_frames_per_slice() const
{
    UInt32 frames = 0;
    UInt32 size = sizeof(UInt32);
    yas_raise_if_au_error(AudioUnitGetProperty(_core->au_instance, kAudioUnitProperty_MaximumFramesPerSlice,
                                               kAudioUnitScope_Global, 0, &frames, &size));
    return frames;
}

void audio_unit::impl::set_parameter_value(const AudioUnitParameterValue value, const AudioUnitParameterID parameter_id,
                                           const AudioUnitScope scope, const AudioUnitElement element)
{
    yas_raise_if_au_error(AudioUnitSetParameter(_core->au_instance, parameter_id, scope, element, value, 0));
}

AudioUnitParameterValue audio_unit::impl::parameter_value(const AudioUnitParameterID parameter_id,
                                                          const AudioUnitScope scope, const AudioUnitElement element)
{
    AudioUnitParameterValue value = 0;
    yas_raise_if_au_error(AudioUnitGetParameter(_core->au_instance, parameter_id, scope, element, &value));
    return value;
}

void audio_unit::impl::set_element_count(const UInt32 &count, const AudioUnitScope &scope)
{
    yas_raise_if_au_error(
        AudioUnitSetProperty(_core->au_instance, kAudioUnitProperty_ElementCount, scope, 0, &count, sizeof(UInt32)));
}

UInt32 audio_unit::impl::element_count(const AudioUnitScope &scope) const
{
    UInt32 count = 0;
    UInt32 size = sizeof(UInt32);
    yas_raise_if_au_error(
        AudioUnitGetProperty(_core->au_instance, kAudioUnitProperty_ElementCount, scope, 0, &count, &size));
    return count;
}

void audio_unit::impl::set_enable_output(const bool enable_output)
{
    if (!has_output()) {
        return;
    }

    if (is_enable_output() == enable_output) {
        return;
    }

    if (_core->initialized) {
        yas_raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - AudioUnit is initialized.");
        return;
    }

    UInt32 enableIO = enable_output ? 1 : 0;
    yas_raise_if_au_error(AudioUnitSetProperty(_core->au_instance, kAudioOutputUnitProperty_EnableIO,
                                               kAudioUnitScope_Output, 0, &enableIO, sizeof(UInt32)));
}

bool audio_unit::impl::is_enable_output() const
{
    UInt32 enableIO = 0;
    UInt32 size = sizeof(UInt32);
    yas_raise_if_au_error(AudioUnitGetProperty(_core->au_instance, kAudioOutputUnitProperty_EnableIO,
                                               kAudioUnitScope_Output, 0, &enableIO, &size));
    return enableIO;
}

void audio_unit::impl::set_enable_input(const bool enable_input)
{
    if (!has_input()) {
        return;
    }

    if (is_enable_input() == enable_input) {
        return;
    }

    if (_core->initialized) {
        yas_raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - AudioUnit is initialized.");
        return;
    }

    UInt32 enableIO = enable_input ? 1 : 0;
    yas_raise_if_au_error(AudioUnitSetProperty(_core->au_instance, kAudioOutputUnitProperty_EnableIO,
                                               kAudioUnitScope_Input, 1, &enableIO, sizeof(UInt32)));
}

bool audio_unit::impl::is_enable_input() const
{
    UInt32 enableIO = 0;
    UInt32 size = sizeof(UInt32);
    yas_raise_if_au_error(AudioUnitGetProperty(_core->au_instance, kAudioOutputUnitProperty_EnableIO,
                                               kAudioUnitScope_Input, 1, &enableIO, &size));
    return enableIO;
}

bool audio_unit::impl::has_output() const
{
#if TARGET_OS_IPHONE
    return true;
#elif TARGET_OS_MAC
    UInt32 has_io = 0;
    UInt32 size = sizeof(UInt32);
    yas_raise_if_au_error(AudioUnitGetProperty(_core->au_instance, kAudioOutputUnitProperty_HasIO,
                                               kAudioUnitScope_Output, 0, &has_io, &size));
    return has_io;
#endif
}

bool audio_unit::impl::has_input() const
{
#if TARGET_IPHONE_SIMULATOR
    return true;
#elif TARGET_OS_IPHONE
    return [AVAudioSession sharedInstance].isInputAvailable;
#elif TARGET_OS_MAC
    UInt32 has_io = 0;
    UInt32 size = sizeof(UInt32);
    yas_raise_if_au_error(AudioUnitGetProperty(_core->au_instance, kAudioOutputUnitProperty_HasIO,
                                               kAudioUnitScope_Input, 1, &has_io, &size));
    return has_io;
#endif
}

bool audio_unit::impl::is_running() const
{
    UInt32 is_running = 0;
    UInt32 size = sizeof(UInt32);
    yas_raise_if_au_error(AudioUnitGetProperty(_core->au_instance, kAudioOutputUnitProperty_IsRunning,
                                               kAudioUnitScope_Global, 0, &is_running, &size));
    return is_running != 0;
}

void audio_unit::impl::set_channel_map(const channel_map_t &map, const AudioUnitScope scope,
                                       const AudioUnitElement element)
{
    if (acd().componentType != kAudioUnitType_Output) {
        throw std::runtime_error(std::string(__PRETTY_FUNCTION__) +
                                 " : invalid component type. (not kAudioUnitType_Output)");
    }

    set_property_data(map, kAudioOutputUnitProperty_ChannelMap, scope, element);
}

channel_map_t audio_unit::impl::channel_map(const AudioUnitScope scope, const AudioUnitElement element) const
{
    if (acd().componentType != kAudioUnitType_Output) {
        throw std::runtime_error(std::string(__PRETTY_FUNCTION__) +
                                 " : invalid component type. (not kAudioUnitType_Output)");
    }

    return property_data<UInt32>(kAudioOutputUnitProperty_ChannelMap, scope, element);
}

UInt32 audio_unit::impl::channel_map_count(const AudioUnitScope scope, const AudioUnitElement element) const
{
    UInt32 byte_size = 0;
    yas_raise_if_au_error(AudioUnitGetPropertyInfo(_core->au_instance, kAudioOutputUnitProperty_ChannelMap, scope,
                                                   element, &byte_size, nullptr));

    if (byte_size) {
        return byte_size / sizeof(UInt32);
    }
    return 0;
}

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
void audio_unit::impl::set_current_device(const AudioDeviceID &device)
{
    yas_raise_if_au_error(AudioUnitSetProperty(_core->au_instance, kAudioOutputUnitProperty_CurrentDevice,
                                               kAudioUnitScope_Global, 0, &device, sizeof(AudioDeviceID)));
}

const AudioDeviceID audio_unit::impl::current_device() const
{
    AudioDeviceID device = 0;
    UInt32 size = sizeof(AudioDeviceID);
    yas_raise_if_au_error(AudioUnitGetProperty(_core->au_instance, kAudioOutputUnitProperty_CurrentDevice,
                                               kAudioUnitScope_Global, 0, &device, &size));
    return device;
}
#endif

void audio_unit::impl::start()
{
    if (acd().componentType != kAudioUnitType_Output) {
        yas_raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - Not output unit.");
        return;
    }

    if (!is_running()) {
        yas_raise_if_au_error(AudioOutputUnitStart(_core->au_instance));
    }
}

void audio_unit::impl::stop()
{
    if (acd().componentType != kAudioUnitType_Output) {
        yas_raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - Not output unit.");
        return;
    }

    if (is_running()) {
        yas_raise_if_au_error(AudioOutputUnitStop(_core->au_instance));
    }
}

#pragma mark - atomic

audio_unit::render_f audio_unit::impl::render_callback() const
{
    std::lock_guard<std::recursive_mutex> lock(_core->mutex);
    return _core->render_callback;
}

audio_unit::render_f audio_unit::impl::notify_callback() const
{
    std::lock_guard<std::recursive_mutex> lock(_core->mutex);
    return _core->notify_callback;
}

audio_unit::render_f audio_unit::impl::input_callback() const
{
    std::lock_guard<std::recursive_mutex> lock(_core->mutex);
    return _core->input_callback;
}

void audio_unit::impl::set_audio_unit_instance(const AudioUnit au)
{
    std::lock_guard<std::recursive_mutex> lock(_core->mutex);
    _core->au_instance = au;
}

const AudioUnit audio_unit::impl::audio_unit_instance() const
{
    std::lock_guard<std::recursive_mutex> lock(_core->mutex);
    return _core->au_instance;
}

#pragma mark - render thread

void audio_unit::impl::callback_render(yas::render_parameters &render_parameters)
{
    yas_raise_if_main_thread;

    render_f function = nullptr;

    switch (render_parameters.in_render_type) {
        case render_type::normal:
            function = render_callback();
            break;
        case render_type::notify:
            function = notify_callback();
            break;
        case render_type::input:
            function = input_callback();
            break;
        default:
            break;
    }

    if (function) {
        function(render_parameters);
    }
}

audio_unit::au_result_t audio_unit::impl::audio_unit_render(yas::render_parameters &render_parameters)
{
    yas_raise_if_main_thread;

    AudioUnit au = audio_unit_instance();
    if (au) {
        return to_result(AudioUnitRender(au, render_parameters.io_action_flags, render_parameters.io_time_stamp,
                                         render_parameters.in_bus_number, render_parameters.in_number_frames,
                                         render_parameters.io_data));
    }

    return audio_unit::au_result_t(nullptr);
}
