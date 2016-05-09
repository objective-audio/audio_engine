//
//  yas_audio_unit_impl.mm
//

#include "yas_audio_graph.h"
#include "yas_audio_pcm_buffer.h"
#include "yas_audio_unit.h"
#include "yas_cf_utils.h"

#if TARGET_OS_IPHONE
#import <AVFoundation/AVFoundation.h>
#endif

using namespace yas;

#pragma mark - c functions

namespace yas {
static OSStatus common_render_callback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                                       const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames,
                                       AudioBufferList *ioData, audio::render_type renderType) {
    audio::render_id render_id{.v = inRefCon};
    audio::render_parameters renderParameters = {
        .in_render_type = renderType,
        .io_action_flags = ioActionFlags,
        .io_time_stamp = inTimeStamp,
        .in_bus_number = inBusNumber,
        .in_number_frames = inNumberFrames,
        .io_data = ioData,
        .render_id = render_id,
    };

    audio::graph::audio_unit_render(renderParameters);

    return noErr;
};

static OSStatus render_callback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                                const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames,
                                AudioBufferList *ioData) {
    return common_render_callback(inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData,
                                  audio::render_type::normal);
};

static OSStatus clear_callback(void *, AudioUnitRenderActionFlags *, const AudioTimeStamp *, UInt32, UInt32,
                               AudioBufferList *ioData) {
    if (ioData) {
        audio::clear(ioData);
    }
    return noErr;
};

static OSStatus empty_callback(void *, AudioUnitRenderActionFlags *, const AudioTimeStamp *, UInt32, UInt32,
                               AudioBufferList *) {
    return noErr;
};
}

static OSStatus notify_render_callback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                                       const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames,
                                       AudioBufferList *ioData) {
    return common_render_callback(inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData,
                                  audio::render_type::notify);
};

static OSStatus input_render_callback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                                      const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames,
                                      AudioBufferList *ioData) {
    return common_render_callback(inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData,
                                  audio::render_type::input);
};

#pragma mark - core

struct audio::unit::impl::core {
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

audio::unit::impl::impl() : _core(std::make_unique<core>()){};

audio::unit::impl::~impl() {
    uninitialize();
    dispose_audio_unit();
}

#pragma mark - setup audio unit

void audio::unit::impl::create_audio_unit(AudioComponentDescription const &acd) {
    _core->acd = acd;

    AudioComponent component = AudioComponentFindNext(nullptr, &acd);
    if (!component) {
        raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - Can't create audio component.");
        return;
    }

    CFStringRef cf_name = nullptr;
    raise_if_au_error(AudioComponentCopyName(component, &cf_name));
    _core->name = to_string(cf_name);
    CFRelease(cf_name);

    AudioUnit au = nullptr;
    raise_if_au_error(AudioComponentInstanceNew(component, &au));
    set_audio_unit_instance(au);
}

void audio::unit::impl::dispose_audio_unit() {
    if (!_core->au_instance) {
        return;
    }

    AudioUnit au = _core->au_instance;
    set_audio_unit_instance(nullptr);

    raise_if_au_error(AudioComponentInstanceDispose(au));

    _core->name.clear();
}

void audio::unit::impl::initialize() {
    if (_core->initialized) {
        return;
    }

    if (!_core->au_instance) {
        raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - AudioUnit is null.");
        return;
    }

    raise_if_au_error(AudioUnitInitialize(_core->au_instance));

    _core->initialized = true;
}

void audio::unit::impl::uninitialize() {
    if (!_core->initialized) {
        return;
    }

    if (!_core->au_instance) {
        raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - AudioUnit is null.");
        return;
    }

    raise_if_au_error(AudioUnitUninitialize(_core->au_instance));

    _core->initialized = false;
}

bool audio::unit::impl::is_initialized() const {
    return _core->initialized;
}

void audio::unit::impl::reset() {
    raise_if_au_error(AudioUnitReset(_core->au_instance, kAudioUnitScope_Global, 0));
}

#pragma mark - accessor

AudioComponentDescription const &audio::unit::impl::acd() const {
    return _core->acd;
}

std::string const &audio::unit::impl::name() const {
    return _core->name;
}

void audio::unit::impl::attach_render_callback(uint32_t const bus_idx) {
    if (!_graph_key || !_key) {
        raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - Key is not assigned. graphKey(" +
                          std::to_string(*_graph_key) + ") unitKey(" + std::to_string(*_key) + ")");
        return;
    }

    render_id render_id{.graph = *_graph_key, .unit = *_key};
    AURenderCallbackStruct callbackStruct{.inputProc = yas::render_callback, .inputProcRefCon = render_id.v};

    raise_if_au_error(AudioUnitSetProperty(_core->au_instance, kAudioUnitProperty_SetRenderCallback,
                                           kAudioUnitScope_Input, bus_idx, &callbackStruct,
                                           sizeof(AURenderCallbackStruct)));
}

void audio::unit::impl::detach_render_callback(uint32_t const bus_idx) {
    AURenderCallbackStruct callbackStruct{.inputProc = clear_callback, .inputProcRefCon = nullptr};

    raise_if_au_error(AudioUnitSetProperty(_core->au_instance, kAudioUnitProperty_SetRenderCallback,
                                           kAudioUnitScope_Input, bus_idx, &callbackStruct,
                                           sizeof(AURenderCallbackStruct)));
}

void audio::unit::impl::attach_render_notify() {
    if (!_graph_key || !_key) {
        raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - Key is not assigned. graphKey(" +
                          std::to_string(*_graph_key) + ") unitKey(" + std::to_string(*_key) + ")");
        return;
    }

    render_id render_id{.graph = *_graph_key, .unit = *_key};

    raise_if_au_error(AudioUnitAddRenderNotify(_core->au_instance, notify_render_callback, render_id.v));
}

void audio::unit::impl::detach_render_notify() {
    raise_if_au_error(AudioUnitRemoveRenderNotify(_core->au_instance, notify_render_callback, nullptr));
}

void audio::unit::impl::attach_input_callback() {
    if (acd().componentType != kAudioUnitType_Output) {
        raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - Not output unit.");
        return;
    }

    if (!_graph_key || !_key) {
        raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - Key is not assigned. graphKey(" +
                          std::to_string(*_graph_key) + ") unitKey(" + std::to_string(*_key) + ")");
        return;
    }

    render_id render_id{.graph = *_graph_key, .unit = *_key};

    AURenderCallbackStruct callbackStruct = {.inputProc = input_render_callback, .inputProcRefCon = render_id.v};

    raise_if_au_error(AudioUnitSetProperty(_core->au_instance, kAudioOutputUnitProperty_SetInputCallback,
                                           kAudioUnitScope_Global, 0, &callbackStruct, sizeof(AURenderCallbackStruct)));
}

void audio::unit::impl::detach_input_callback() {
    if (acd().componentType != kAudioUnitType_Output) {
        raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - Not output unit.");
        return;
    }

    AURenderCallbackStruct callbackStruct = {.inputProc = yas::empty_callback, .inputProcRefCon = NULL};

    raise_if_au_error(AudioUnitSetProperty(_core->au_instance, kAudioOutputUnitProperty_SetInputCallback,
                                           kAudioUnitScope_Global, 0, &callbackStruct, sizeof(AURenderCallbackStruct)));
}

void audio::unit::impl::set_render_callback(render_f &&callback) {
    std::lock_guard<std::recursive_mutex> lock(_core->mutex);
    _core->render_callback = std::move(callback);
}

void audio::unit::impl::set_notify_callback(render_f &&callback) {
    std::lock_guard<std::recursive_mutex> lock(_core->mutex);
    _core->notify_callback = std::move(callback);
}

void audio::unit::impl::set_input_callback(render_f &&callback) {
    std::lock_guard<std::recursive_mutex> lock(_core->mutex);
    _core->input_callback = std::move(callback);
}

void audio::unit::impl::set_input_format(AudioStreamBasicDescription const &asbd, uint32_t const bus_idx) {
    raise_if_au_error(AudioUnitSetProperty(_core->au_instance, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input,
                                           bus_idx, &asbd, sizeof(AudioStreamBasicDescription)));
}

void audio::unit::impl::set_output_format(AudioStreamBasicDescription const &asbd, uint32_t const bus_idx) {
    raise_if_au_error(AudioUnitSetProperty(_core->au_instance, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output,
                                           bus_idx, &asbd, sizeof(AudioStreamBasicDescription)));
}

AudioStreamBasicDescription audio::unit::impl::input_format(uint32_t const bus_idx) const {
    AudioStreamBasicDescription asbd = {0};
    UInt32 size = sizeof(AudioStreamBasicDescription);
    raise_if_au_error(AudioUnitGetProperty(_core->au_instance, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input,
                                           bus_idx, &asbd, &size));
    return asbd;
}

AudioStreamBasicDescription audio::unit::impl::output_format(uint32_t const bus_idx) const {
    AudioStreamBasicDescription asbd = {0};
    UInt32 size = sizeof(AudioStreamBasicDescription);
    raise_if_au_error(AudioUnitGetProperty(_core->au_instance, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output,
                                           bus_idx, &asbd, &size));
    return asbd;
}

void audio::unit::impl::set_maximum_frames_per_slice(uint32_t const frames) {
    raise_if_au_error(AudioUnitSetProperty(_core->au_instance, kAudioUnitProperty_MaximumFramesPerSlice,
                                           kAudioUnitScope_Global, 0, &frames, sizeof(uint32_t)));
}

uint32_t audio::unit::impl::maximum_frames_per_slice() const {
    UInt32 frames = 0;
    UInt32 size = sizeof(UInt32);
    raise_if_au_error(AudioUnitGetProperty(_core->au_instance, kAudioUnitProperty_MaximumFramesPerSlice,
                                           kAudioUnitScope_Global, 0, &frames, &size));
    return frames;
}

void audio::unit::impl::set_parameter_value(AudioUnitParameterValue const value,
                                            AudioUnitParameterID const parameter_id, AudioUnitScope const scope,
                                            AudioUnitElement const element) {
    raise_if_au_error(AudioUnitSetParameter(_core->au_instance, parameter_id, scope, element, value, 0));
}

AudioUnitParameterValue audio::unit::impl::parameter_value(AudioUnitParameterID const parameter_id,
                                                           AudioUnitScope const scope, AudioUnitElement const element) {
    AudioUnitParameterValue value = 0;
    raise_if_au_error(AudioUnitGetParameter(_core->au_instance, parameter_id, scope, element, &value));
    return value;
}

void audio::unit::impl::set_element_count(uint32_t const count, AudioUnitScope const scope) {
    raise_if_au_error(
        AudioUnitSetProperty(_core->au_instance, kAudioUnitProperty_ElementCount, scope, 0, &count, sizeof(uint32_t)));
}

uint32_t audio::unit::impl::element_count(AudioUnitScope const scope) const {
    UInt32 count = 0;
    UInt32 size = sizeof(UInt32);
    raise_if_au_error(
        AudioUnitGetProperty(_core->au_instance, kAudioUnitProperty_ElementCount, scope, 0, &count, &size));
    return count;
}

void audio::unit::impl::set_enable_output(bool const enable_output) {
    if (!has_output()) {
        return;
    }

    if (is_enable_output() == enable_output) {
        return;
    }

    if (_core->initialized) {
        raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - AudioUnit is initialized.");
        return;
    }

    uint32_t enableIO = enable_output ? 1 : 0;
    raise_if_au_error(AudioUnitSetProperty(_core->au_instance, kAudioOutputUnitProperty_EnableIO,
                                           kAudioUnitScope_Output, 0, &enableIO, sizeof(uint32_t)));
}

bool audio::unit::impl::is_enable_output() const {
    UInt32 enableIO = 0;
    UInt32 size = sizeof(UInt32);
    raise_if_au_error(AudioUnitGetProperty(_core->au_instance, kAudioOutputUnitProperty_EnableIO,
                                           kAudioUnitScope_Output, 0, &enableIO, &size));
    return enableIO;
}

void audio::unit::impl::set_enable_input(bool const enable_input) {
    if (!has_input()) {
        return;
    }

    if (is_enable_input() == enable_input) {
        return;
    }

    if (_core->initialized) {
        raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - AudioUnit is initialized.");
        return;
    }

    uint32_t enableIO = enable_input ? 1 : 0;
    raise_if_au_error(AudioUnitSetProperty(_core->au_instance, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input,
                                           1, &enableIO, sizeof(uint32_t)));
}

bool audio::unit::impl::is_enable_input() const {
    UInt32 enableIO = 0;
    UInt32 size = sizeof(UInt32);
    raise_if_au_error(AudioUnitGetProperty(_core->au_instance, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input,
                                           1, &enableIO, &size));
    return enableIO;
}

bool audio::unit::impl::has_output() const {
#if TARGET_OS_IPHONE
    return true;
#elif TARGET_OS_MAC
    UInt32 has_io = 0;
    UInt32 size = sizeof(UInt32);
    raise_if_au_error(AudioUnitGetProperty(_core->au_instance, kAudioOutputUnitProperty_HasIO, kAudioUnitScope_Output,
                                           0, &has_io, &size));
    return has_io;
#endif
}

bool audio::unit::impl::has_input() const {
#if TARGET_IPHONE_SIMULATOR
    return true;
#elif TARGET_OS_IPHONE
    return [AVAudioSession sharedInstance].isInputAvailable;
#elif TARGET_OS_MAC
    UInt32 has_io = 0;
    UInt32 size = sizeof(UInt32);
    raise_if_au_error(AudioUnitGetProperty(_core->au_instance, kAudioOutputUnitProperty_HasIO, kAudioUnitScope_Input, 1,
                                           &has_io, &size));
    return has_io;
#endif
}

bool audio::unit::impl::is_running() const {
    UInt32 is_running = 0;
    UInt32 size = sizeof(UInt32);
    raise_if_au_error(AudioUnitGetProperty(_core->au_instance, kAudioOutputUnitProperty_IsRunning,
                                           kAudioUnitScope_Global, 0, &is_running, &size));
    return is_running != 0;
}

void audio::unit::impl::set_channel_map(channel_map_t const &map, AudioUnitScope const scope,
                                        AudioUnitElement const element) {
    if (acd().componentType != kAudioUnitType_Output) {
        throw std::runtime_error(std::string(__PRETTY_FUNCTION__) +
                                 " : invalid component type. (not kAudioUnitType_Output)");
    }

    set_property_data(map, kAudioOutputUnitProperty_ChannelMap, scope, element);
}

audio::channel_map_t audio::unit::impl::channel_map(AudioUnitScope const scope, AudioUnitElement const element) const {
    if (acd().componentType != kAudioUnitType_Output) {
        throw std::runtime_error(std::string(__PRETTY_FUNCTION__) +
                                 " : invalid component type. (not kAudioUnitType_Output)");
    }

    return property_data<uint32_t>(kAudioOutputUnitProperty_ChannelMap, scope, element);
}

uint32_t audio::unit::impl::channel_map_count(AudioUnitScope const scope, AudioUnitElement const element) const {
    UInt32 byte_size = 0;
    raise_if_au_error(AudioUnitGetPropertyInfo(_core->au_instance, kAudioOutputUnitProperty_ChannelMap, scope, element,
                                               &byte_size, nullptr));

    if (byte_size) {
        return byte_size / sizeof(uint32_t);
    }
    return 0;
}

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
void audio::unit::impl::set_current_device(AudioDeviceID const device) {
    raise_if_au_error(AudioUnitSetProperty(_core->au_instance, kAudioOutputUnitProperty_CurrentDevice,
                                           kAudioUnitScope_Global, 0, &device, sizeof(AudioDeviceID)));
}

AudioDeviceID audio::unit::impl::current_device() const {
    AudioDeviceID device = 0;
    UInt32 size = sizeof(AudioDeviceID);
    raise_if_au_error(AudioUnitGetProperty(_core->au_instance, kAudioOutputUnitProperty_CurrentDevice,
                                           kAudioUnitScope_Global, 0, &device, &size));
    return device;
}
#endif

void audio::unit::impl::start() {
    if (acd().componentType != kAudioUnitType_Output) {
        raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - Not output unit.");
        return;
    }

    if (!is_running()) {
        raise_if_au_error(AudioOutputUnitStart(_core->au_instance));
    }
}

void audio::unit::impl::stop() {
    if (acd().componentType != kAudioUnitType_Output) {
        raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - Not output unit.");
        return;
    }

    if (is_running()) {
        raise_if_au_error(AudioOutputUnitStop(_core->au_instance));
    }
}

void audio::unit::impl::set_graph_key(std::experimental::optional<uint8_t> const &key) {
    _graph_key = key;
}

std::experimental::optional<uint8_t> const &audio::unit::impl::graph_key() const {
    return _graph_key;
}

void audio::unit::impl::set_key(std::experimental::optional<uint16_t> const &key) {
    _key = key;
}

std::experimental::optional<uint16_t> const &audio::unit::impl::key() const {
    return _key;
}

#pragma mark - atomic

audio::unit::render_f audio::unit::impl::render_callback() const {
    std::lock_guard<std::recursive_mutex> lock(_core->mutex);
    return _core->render_callback;
}

audio::unit::render_f audio::unit::impl::notify_callback() const {
    std::lock_guard<std::recursive_mutex> lock(_core->mutex);
    return _core->notify_callback;
}

audio::unit::render_f audio::unit::impl::input_callback() const {
    std::lock_guard<std::recursive_mutex> lock(_core->mutex);
    return _core->input_callback;
}

void audio::unit::impl::set_audio_unit_instance(AudioUnit const au) {
    std::lock_guard<std::recursive_mutex> lock(_core->mutex);
    _core->au_instance = au;
}

AudioUnit audio::unit::impl::audio_unit_instance() const {
    std::lock_guard<std::recursive_mutex> lock(_core->mutex);
    return _core->au_instance;
}

#pragma mark - render thread

void audio::unit::impl::callback_render(render_parameters &render_parameters) {
    raise_if_main_thread();

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

audio::unit::au_result_t audio::unit::impl::audio_unit_render(render_parameters &render_parameters) {
    raise_if_main_thread();

    AudioUnit au = audio_unit_instance();
    if (au) {
        return to_result(AudioUnitRender(au, render_parameters.io_action_flags, render_parameters.io_time_stamp,
                                         render_parameters.in_bus_number, render_parameters.in_number_frames,
                                         render_parameters.io_data));
    }

    return unit::au_result_t(nullptr);
}
