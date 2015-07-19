//
//  yas_audio_unit.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_unit.h"
#include "yas_audio_graph.h"
#include "YASAudioUtility.h"

using namespace yas;

const OSType audio_unit::sub_type_default_io()
{
#if TARGET_OS_IPHONE
    return kAudioUnitSubType_RemoteIO;
#elif TARGET_OS_MAC
    return kAudioUnitSubType_HALOutput;
#endif
}

class audio_unit::impl
{
   public:
    AudioComponentDescription acd;
    AudioUnit au_instance;
    CFStringRef name;
    bool initialized;
    std::experimental::optional<UInt8> graph_key;
    std::experimental::optional<UInt16> key;

    impl()
        : acd(),
          au_instance(nullptr),
          name(nullptr),
          initialized(false),
          graph_key(),
          key(),
          _render_callback(nullptr),
          _notify_callback(nullptr),
          _input_callback(nullptr),
          _mutex(){};

    void set_audio_unit(const AudioUnit au)
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        au_instance = au;
    }

    const AudioUnit audio_unit()
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        return au_instance;
    }

    void set_render_callback(const render_function &callback)
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        _render_callback = callback;
    }

    void set_notify_callback(const render_function &callback)
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        _notify_callback = callback;
    }

    void set_input_callback(const render_function &callback)
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        _input_callback = callback;
    }

    audio_unit::render_function render_callback() const
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        return _render_callback;
    }

    audio_unit::render_function notify_callback() const
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        return _notify_callback;
    }

    audio_unit::render_function input_callback() const
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        return _input_callback;
    }

#pragma mark - setup audio unit

    void create_audio_unit(const AudioComponentDescription &acd)
    {
        this->acd = acd;

        AudioComponent component = AudioComponentFindNext(nullptr, &acd);
        if (!component) {
            yas_raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - Can't create audio component.");
            return;
        }

        yas_raise_if_au_error(AudioComponentCopyName(component, &name));

        AudioUnit au = nullptr;
        yas_raise_if_au_error(AudioComponentInstanceNew(component, &au));
        set_audio_unit(au);
    }

    void dispose_audio_unit()
    {
        if (!au_instance) {
            return;
        }

        AudioUnit au = au_instance;
        set_audio_unit(nullptr);

        yas_raise_if_au_error(AudioComponentInstanceDispose(au));

        if (name) {
            CFRelease(name);
            name = nullptr;
        }
    }

   private:
    render_function _render_callback;
    render_function _notify_callback;
    render_function _input_callback;

    mutable std::recursive_mutex _mutex;
};

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

    audio_graph::audio_unit_render(renderParameters);

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
        YASAudioClearAudioBufferList(ioData);
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

#pragma mark -

audio_unit_ptr audio_unit::create(const AudioComponentDescription &acd)
{
    return audio_unit_ptr(new audio_unit(acd));
}

audio_unit_ptr audio_unit::create(const OSType &type, const OSType &subType)
{
    return audio_unit_ptr(new audio_unit(type, subType));
}

audio_unit::audio_unit(const AudioComponentDescription &acd) : _impl(std::make_unique<impl>())
{
    _impl->create_audio_unit(acd);
}

audio_unit::audio_unit(const OSType &type, const OSType &sub_type)
    : audio_unit({
          .componentType = type,
          .componentSubType = sub_type,
          .componentManufacturer = kAudioUnitManufacturer_Apple,
          .componentFlags = 0,
          .componentFlagsMask = 0,
      })
{
}

audio_unit::~audio_unit()
{
    uninitialize();
    _impl->dispose_audio_unit();
}

#pragma mark - accessor

OSType audio_unit::type() const
{
    return _impl->acd.componentType;
}

OSType audio_unit::sub_type() const
{
    return _impl->acd.componentSubType;
}

bool audio_unit::is_output_unit() const
{
    return _impl->acd.componentType == kAudioUnitType_Output;
}

AudioUnit audio_unit::audio_unit_instance() const
{
    return _impl->au_instance;
}

#pragma mark - render callback

void audio_unit::attach_render_callback(const UInt32 &bus)
{
    if (!_impl->graph_key || !_impl->key) {
        yas_raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - Key is not assigned. graphKey(" +
                              std::to_string(*_impl->graph_key) + ") unitKey(" + std::to_string(*_impl->key) + ")");
        return;
    }

    render_id render_id{.graph = *_impl->graph_key, .unit = *_impl->key};

    AURenderCallbackStruct callbackStruct{.inputProc = RenderCallback, .inputProcRefCon = render_id.v};

    yas_raise_if_au_error(AudioUnitSetProperty(_impl->au_instance, kAudioUnitProperty_SetRenderCallback,
                                               kAudioUnitScope_Input, bus, &callbackStruct,
                                               sizeof(AURenderCallbackStruct)));
}

void audio_unit::detach_render_callback(const UInt32 &bus)
{
    AURenderCallbackStruct callbackStruct{.inputProc = ClearCallback, .inputProcRefCon = nullptr};

    yas_raise_if_au_error(AudioUnitSetProperty(_impl->au_instance, kAudioUnitProperty_SetRenderCallback,
                                               kAudioUnitScope_Input, bus, &callbackStruct,
                                               sizeof(AURenderCallbackStruct)));
}

void audio_unit::attach_render_notify()
{
    if (!_impl->graph_key || !_impl->key) {
        yas_raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - Key is not assigned. graphKey(" +
                              std::to_string(*_impl->graph_key) + ") unitKey(" + std::to_string(*_impl->key) + ")");
        return;
    }

    render_id render_id{.graph = *_impl->graph_key, .unit = *_impl->key};

    yas_raise_if_au_error(AudioUnitAddRenderNotify(_impl->au_instance, NotifyRenderCallback, render_id.v));
}

void audio_unit::detach_render_notify()
{
    yas_raise_if_au_error(AudioUnitRemoveRenderNotify(_impl->au_instance, NotifyRenderCallback, nullptr));
}

void audio_unit::attach_input_callback()
{
    if (_impl->acd.componentType != kAudioUnitType_Output) {
        yas_raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - Not output unit.");
        return;
    }

    if (!_impl->graph_key || !_impl->key) {
        yas_raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - Key is not assigned. graphKey(" +
                              std::to_string(*_impl->graph_key) + ") unitKey(" + std::to_string(*_impl->key) + ")");
        return;
    }

    render_id render_id{.graph = *_impl->graph_key, .unit = *_impl->key};

    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = InputRenderCallback;
    callbackStruct.inputProcRefCon = render_id.v;

    yas_raise_if_au_error(AudioUnitSetProperty(_impl->au_instance, kAudioOutputUnitProperty_SetInputCallback,
                                               kAudioUnitScope_Global, 0, &callbackStruct,
                                               sizeof(AURenderCallbackStruct)));
}

void audio_unit::detach_input_callback()
{
    if (_impl->acd.componentType != kAudioUnitType_Output) {
        yas_raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - Not output unit.");
        return;
    }

    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = EmptyCallback;
    callbackStruct.inputProcRefCon = NULL;

    yas_raise_if_au_error(AudioUnitSetProperty(_impl->au_instance, kAudioOutputUnitProperty_SetInputCallback,
                                               kAudioUnitScope_Global, 0, &callbackStruct,
                                               sizeof(AURenderCallbackStruct)));
}

void audio_unit::set_render_callback(const render_function &callback)
{
    _impl->set_render_callback(callback);
}

void audio_unit::set_notify_callback(const render_function &callback)
{
    _impl->set_notify_callback(callback);
}

void audio_unit::set_input_callback(const render_function &callback)
{
    _impl->set_input_callback(callback);
}

#pragma mark - property

void audio_unit::set_input_format(const AudioStreamBasicDescription &asbd, const UInt32 bus)
{
    yas_raise_if_au_error(AudioUnitSetProperty(_impl->au_instance, kAudioUnitProperty_StreamFormat,
                                               kAudioUnitScope_Input, bus, &asbd, sizeof(AudioStreamBasicDescription)));
}

void audio_unit::set_output_format(const AudioStreamBasicDescription &asbd, const UInt32 bus)
{
    yas_raise_if_au_error(AudioUnitSetProperty(_impl->au_instance, kAudioUnitProperty_StreamFormat,
                                               kAudioUnitScope_Output, bus, &asbd,
                                               sizeof(AudioStreamBasicDescription)));
}

AudioStreamBasicDescription audio_unit::input_format(const UInt32 bus) const
{
    AudioStreamBasicDescription asbd = {0};
    UInt32 size = sizeof(AudioStreamBasicDescription);
    yas_raise_if_au_error(AudioUnitGetProperty(_impl->au_instance, kAudioUnitProperty_StreamFormat,
                                               kAudioUnitScope_Input, bus, &asbd, &size));
    return asbd;
}

AudioStreamBasicDescription audio_unit::output_format(const UInt32 bus) const
{
    AudioStreamBasicDescription asbd = {0};
    UInt32 size = sizeof(AudioStreamBasicDescription);
    yas_raise_if_au_error(AudioUnitGetProperty(_impl->au_instance, kAudioUnitProperty_StreamFormat,
                                               kAudioUnitScope_Output, bus, &asbd, &size));
    return asbd;
}

void audio_unit::set_maximum_frames_per_slice(const UInt32 frames)
{
    yas_raise_if_au_error(AudioUnitSetProperty(_impl->au_instance, kAudioUnitProperty_MaximumFramesPerSlice,
                                               kAudioUnitScope_Global, 0, &frames, sizeof(UInt32)));
}

UInt32 audio_unit::maximum_frames_per_slice() const
{
    UInt32 frames = 0;
    UInt32 size = sizeof(UInt32);
    yas_raise_if_au_error(AudioUnitGetProperty(_impl->au_instance, kAudioUnitProperty_MaximumFramesPerSlice,
                                               kAudioUnitScope_Global, 0, &frames, &size));
    return frames;
}

bool audio_unit::is_initialized()
{
    return _impl->initialized;
}

void audio_unit::set_element_count(const UInt32 &count, const AudioUnitScope &scope)
{
    yas_raise_if_au_error(
        AudioUnitSetProperty(_impl->au_instance, kAudioUnitProperty_ElementCount, scope, 0, &count, sizeof(UInt32)));
}

UInt32 audio_unit::element_count(const AudioUnitScope &scope) const
{
    UInt32 count = 0;
    UInt32 size = sizeof(UInt32);
    yas_raise_if_au_error(
        AudioUnitGetProperty(_impl->au_instance, kAudioUnitProperty_ElementCount, scope, 0, &count, &size));
    return count;
}

#pragma mark - parameter

void audio_unit::set_parameter_value(const AudioUnitParameterValue value, const AudioUnitParameterID parameter_id,
                                     const AudioUnitScope scope, const AudioUnitElement element)
{
    yas_raise_if_au_error(AudioUnitSetParameter(_impl->au_instance, parameter_id, scope, element, value, 0));
}

AudioUnitParameterValue audio_unit::parameter_value(const AudioUnitParameterID parameter_id, const AudioUnitScope scope,
                                                    const AudioUnitElement element)
{
    AudioUnitParameterValue value = 0;
    yas_raise_if_au_error(AudioUnitGetParameter(_impl->au_instance, parameter_id, scope, element, &value));
    return value;
}

std::map<AudioUnitParameterID, audio_unit_parameter> audio_unit::create_parameters(const AudioUnitScope &scope)
{
    auto parameter_list = audio_unit::property_data<AudioUnitParameterID>(kAudioUnitProperty_ParameterList, scope, 0);

    if (parameter_list->size() > 0) {
        auto parameters = std::map<AudioUnitParameterID, audio_unit_parameter>();
        for (const AudioUnitParameterID &parameter_id : *parameter_list) {
            auto parameter = audio_unit::create_parameter(parameter_id, scope);
            parameters.insert(std::make_pair(parameter_id, std::move(parameter)));
        }
        return parameters;
    }

    return std::map<AudioUnitParameterID, audio_unit_parameter>();
}

audio_unit_parameter audio_unit::create_parameter(const AudioUnitParameterID &parameter_id, const AudioUnitScope &scope)
{
    AudioUnitParameterInfo info = {0};
    UInt32 size = sizeof(AudioUnitParameterInfo);
    OSStatus err = noErr;

    yas_raise_if_au_error(err = AudioUnitGetProperty(_impl->au_instance, kAudioUnitProperty_ParameterInfo, scope,
                                                     parameter_id, &info, &size));

    audio_unit_parameter parameter(info, parameter_id, scope);

    if (info.flags & kAudioUnitParameterFlag_CFNameRelease) {
        if (info.flags & kAudioUnitParameterFlag_HasCFNameString && info.cfNameString) {
            CFRelease(info.cfNameString);
        }
        if (info.unit == kAudioUnitParameterUnit_CustomUnit && info.unitName) {
            CFRelease(info.unitName);
        }
    }

    return parameter;
}

#pragma mark - io

void audio_unit::set_enable_output(const bool enable_output)
{
    if (!has_output()) {
        return;
    }

    if (is_enable_output() == enable_output) {
        return;
    }

    if (_impl->initialized) {
        yas_raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - AudioUnit is initialized.");
        return;
    }

    UInt32 enableIO = enable_output ? 1 : 0;
    yas_raise_if_au_error(AudioUnitSetProperty(_impl->au_instance, kAudioOutputUnitProperty_EnableIO,
                                               kAudioUnitScope_Output, 0, &enableIO, sizeof(UInt32)));
}

bool audio_unit::is_enable_output() const
{
    UInt32 enableIO = 0;
    UInt32 size = sizeof(UInt32);
    yas_raise_if_au_error(AudioUnitGetProperty(_impl->au_instance, kAudioOutputUnitProperty_EnableIO,
                                               kAudioUnitScope_Output, 0, &enableIO, &size));
    return enableIO;
}

void audio_unit::set_enable_input(const bool enable_input)
{
    if (!has_input()) {
        return;
    }

    if (is_enable_input() == enable_input) {
        return;
    }

    if (_impl->initialized) {
        yas_raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - AudioUnit is initialized.");
        return;
    }

    UInt32 enableIO = enable_input ? 1 : 0;
    yas_raise_if_au_error(AudioUnitSetProperty(_impl->au_instance, kAudioOutputUnitProperty_EnableIO,
                                               kAudioUnitScope_Input, 1, &enableIO, sizeof(UInt32)));
}

bool audio_unit::is_enable_input() const
{
    UInt32 enableIO = 0;
    UInt32 size = sizeof(UInt32);
    yas_raise_if_au_error(AudioUnitGetProperty(_impl->au_instance, kAudioOutputUnitProperty_EnableIO,
                                               kAudioUnitScope_Input, 1, &enableIO, &size));
    return enableIO;
}

bool audio_unit::has_output() const
{
#if TARGET_OS_IPHONE
    return true;
#elif TARGET_OS_MAC
    UInt32 has_io = 0;
    UInt32 size = sizeof(UInt32);
    yas_raise_if_au_error(AudioUnitGetProperty(_impl->au_instance, kAudioOutputUnitProperty_HasIO,
                                               kAudioUnitScope_Output, 0, &has_io, &size));
    return has_io;
#endif
}

bool audio_unit::has_input() const
{
#if TARGET_IPHONE_SIMULATOR
    return true;
#elif TARGET_OS_IPHONE
    return [AVAudioSession sharedInstance].isInputAvailable;
#elif TARGET_OS_MAC
    UInt32 has_io = 0;
    UInt32 size = sizeof(UInt32);
    yas_raise_if_au_error(AudioUnitGetProperty(_impl->au_instance, kAudioOutputUnitProperty_HasIO,
                                               kAudioUnitScope_Input, 1, &has_io, &size));
    return has_io;
#endif
}

bool audio_unit::is_running() const
{
    UInt32 is_running = 0;
    UInt32 size = sizeof(UInt32);
    yas_raise_if_au_error(AudioUnitGetProperty(_impl->au_instance, kAudioOutputUnitProperty_IsRunning,
                                               kAudioUnitScope_Global, 0, &is_running, &size));
    return is_running != 0;
}

void audio_unit::start()
{
    if (_impl->acd.componentType != kAudioUnitType_Output) {
        yas_raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - Not output unit.");
        return;
    }

    if (!is_running()) {
        yas_raise_if_au_error(AudioOutputUnitStart(_impl->au_instance));
    }
}

void audio_unit::stop()
{
    if (_impl->acd.componentType != kAudioUnitType_Output) {
        yas_raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - Not output unit.");
        return;
    }

    if (is_running()) {
        yas_raise_if_au_error(AudioOutputUnitStop(_impl->au_instance));
    }
}

void audio_unit::reset()
{
    yas_raise_if_au_error(AudioUnitReset(_impl->au_instance, kAudioUnitScope_Global, 0));
}

#pragma mark - render thread

void audio_unit::callback_render(yas::render_parameters &render_parameters)
{
    yas_raise_if_main_thread;

    render_function function = nullptr;

    switch (render_parameters.in_render_type) {
        case render_type::normal:
            function = _impl->render_callback();
            break;
        case render_type::notify:
            function = _impl->notify_callback();
            break;
        case render_type::input:
            function = _impl->input_callback();
            break;
        default:
            break;
    }

    if (function) {
        function(render_parameters);
    }
}

void audio_unit::audio_unit_render(yas::render_parameters &render_parameters)
{
    yas_raise_if_main_thread;

    AudioUnit au = _impl->audio_unit();
    if (au) {
        yas_raise_if_au_error(AudioUnitRender(au, render_parameters.io_action_flags, render_parameters.io_time_stamp,
                                              render_parameters.in_bus_number, render_parameters.in_number_frames,
                                              render_parameters.io_data));
    }
}

#pragma mark - internal function

void audio_unit::initialize()
{
    if (_impl->initialized) {
        return;
    }

    if (!_impl->au_instance) {
        yas_raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - AudioUnit is null.");
        return;
    }

    yas_raise_if_au_error(AudioUnitInitialize(_impl->au_instance));

    _impl->initialized = true;
}

void audio_unit::uninitialize()
{
    if (!_impl->initialized) {
        return;
    }

    if (!_impl->au_instance) {
        yas_raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - AudioUnit is null.");
        return;
    }

    yas_raise_if_au_error(AudioUnitUninitialize(_impl->au_instance));

    _impl->initialized = false;
}

void audio_unit::set_graph_key(const std::experimental::optional<UInt8> &key)
{
    _impl->graph_key = key;
}

const std::experimental::optional<UInt8> &audio_unit::graph_key() const
{
    return _impl->graph_key;
}

void audio_unit::set_key(const std::experimental::optional<UInt16> &key)
{
    _impl->key = key;
}

const std::experimental::optional<UInt16> &audio_unit::key() const
{
    return _impl->key;
}
