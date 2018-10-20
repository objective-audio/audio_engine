//
//  yas_audio_unit.cpp
//

#include "yas_audio_unit.h"
#include <AudioToolbox/AudioToolbox.h>
#include <mutex>
#include <vector>
#include "yas_audio_exception.h"
#include "yas_audio_graph.h"
#include "yas_audio_pcm_buffer.h"
#include "yas_cf_utils.h"
#include "yas_result.h"

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

    audio::graph::unit_render(renderParameters);

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

#pragma mark - audio::unit::impl

struct audio::unit::impl : base::impl, manageable_unit::impl {
   public:
    AudioComponentDescription _acd = {0};
    bool _initialized = false;
    std::string _name;
    std::optional<uint8_t> _graph_key = std::nullopt;
    std::optional<uint16_t> _key = std::nullopt;

    virtual ~impl() final {
        this->uninitialize();
        this->dispose_raw_unit();
    }

    void create_raw_unit(AudioComponentDescription const &acd) {
        this->_acd = acd;

        AudioComponent component = AudioComponentFindNext(nullptr, &acd);
        if (!component) {
            raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - Can't create audio component.");
            return;
        }

        CFStringRef cf_name = nullptr;
        raise_if_raw_audio_error(AudioComponentCopyName(component, &cf_name));
        this->_name = to_string(cf_name);
        CFRelease(cf_name);

        AudioUnit au = nullptr;
        raise_if_raw_audio_error(AudioComponentInstanceNew(component, &au));
        this->set_raw_unit(au);
    }

    void dispose_raw_unit() {
        AudioUnit au = this->_core.raw_unit();

        if (!au) {
            return;
        }

        this->set_raw_unit(nullptr);

        raise_if_raw_audio_error(AudioComponentInstanceDispose(au));

        this->_name.clear();
    }

    void initialize() override {
        if (this->_initialized) {
            return;
        }

        auto au = this->_core.raw_unit();

        if (!au) {
            raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - AudioUnit is null.");
            return;
        }

        raise_if_raw_audio_error(AudioUnitInitialize(au));

        this->_initialized = true;
    }

    void uninitialize() override {
        if (!this->_initialized) {
            return;
        }

        auto au = this->_core.raw_unit();

        if (!au) {
            raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - AudioUnit is null.");
            return;
        }

        raise_if_raw_audio_error(AudioUnitUninitialize(au));

        this->_initialized = false;
    }

    void reset() {
        raise_if_raw_audio_error(AudioUnitReset(_core.raw_unit(), kAudioUnitScope_Global, 0));
    }

    void attach_render_callback(uint32_t const bus_idx) {
        if (!this->_graph_key || !this->_key) {
            raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - Key is not assigned. graphKey(" +
                              std::to_string(*this->_graph_key) + ") unitKey(" + std::to_string(*this->_key) + ")");
            return;
        }

        render_id render_id{.graph = *_graph_key, .unit = *_key};
        AURenderCallbackStruct callbackStruct{.inputProc = yas::render_callback, .inputProcRefCon = render_id.v};

        raise_if_raw_audio_error(AudioUnitSetProperty(this->_core.raw_unit(), kAudioUnitProperty_SetRenderCallback,
                                                      kAudioUnitScope_Input, bus_idx, &callbackStruct,
                                                      sizeof(AURenderCallbackStruct)));
    }

    void detach_render_callback(uint32_t const bus_idx) {
        AURenderCallbackStruct callbackStruct{.inputProc = clear_callback, .inputProcRefCon = nullptr};

        raise_if_raw_audio_error(AudioUnitSetProperty(this->_core.raw_unit(), kAudioUnitProperty_SetRenderCallback,
                                                      kAudioUnitScope_Input, bus_idx, &callbackStruct,
                                                      sizeof(AURenderCallbackStruct)));
    }

    void attach_render_notify() {
        if (!this->_graph_key || !this->_key) {
            raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - Key is not assigned. graphKey(" +
                              std::to_string(*this->_graph_key) + ") unitKey(" + std::to_string(*this->_key) + ")");
            return;
        }

        render_id render_id{.graph = *_graph_key, .unit = *_key};

        raise_if_raw_audio_error(AudioUnitAddRenderNotify(this->_core.raw_unit(), notify_render_callback, render_id.v));
    }

    void detach_render_notify() {
        raise_if_raw_audio_error(AudioUnitRemoveRenderNotify(this->_core.raw_unit(), notify_render_callback, nullptr));
    }

    void attach_input_callback() {
        if (this->_acd.componentType != kAudioUnitType_Output) {
            raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - Not output unit.");
            return;
        }

        if (!this->_graph_key || !this->_key) {
            raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - Key is not assigned. graphKey(" +
                              std::to_string(*this->_graph_key) + ") unitKey(" + std::to_string(*this->_key) + ")");
            return;
        }

        render_id render_id{.graph = *_graph_key, .unit = *_key};

        AURenderCallbackStruct callbackStruct = {.inputProc = input_render_callback, .inputProcRefCon = render_id.v};

        raise_if_raw_audio_error(AudioUnitSetProperty(this->_core.raw_unit(), kAudioOutputUnitProperty_SetInputCallback,
                                                      kAudioUnitScope_Global, 0, &callbackStruct,
                                                      sizeof(AURenderCallbackStruct)));
    }

    void detach_input_callback() {
        if (this->_acd.componentType != kAudioUnitType_Output) {
            raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - Not output unit.");
            return;
        }

        AURenderCallbackStruct callbackStruct = {.inputProc = yas::empty_callback, .inputProcRefCon = NULL};

        raise_if_raw_audio_error(AudioUnitSetProperty(this->_core.raw_unit(), kAudioOutputUnitProperty_SetInputCallback,
                                                      kAudioUnitScope_Global, 0, &callbackStruct,
                                                      sizeof(AURenderCallbackStruct)));
    }

    void set_input_format(AudioStreamBasicDescription const &asbd, uint32_t const bus_idx) {
        raise_if_raw_audio_error(AudioUnitSetProperty(this->_core.raw_unit(), kAudioUnitProperty_StreamFormat,
                                                      kAudioUnitScope_Input, bus_idx, &asbd,
                                                      sizeof(AudioStreamBasicDescription)));
    }

    void set_output_format(AudioStreamBasicDescription const &asbd, uint32_t const bus_idx) {
        raise_if_raw_audio_error(AudioUnitSetProperty(this->_core.raw_unit(), kAudioUnitProperty_StreamFormat,
                                                      kAudioUnitScope_Output, bus_idx, &asbd,
                                                      sizeof(AudioStreamBasicDescription)));
    }

    AudioStreamBasicDescription input_format(uint32_t const bus_idx) {
        AudioStreamBasicDescription asbd = {0};
        UInt32 size = sizeof(AudioStreamBasicDescription);
        raise_if_raw_audio_error(AudioUnitGetProperty(this->_core.raw_unit(), kAudioUnitProperty_StreamFormat,
                                                      kAudioUnitScope_Input, bus_idx, &asbd, &size));
        return asbd;
    }

    AudioStreamBasicDescription output_format(uint32_t const bus_idx) {
        AudioStreamBasicDescription asbd = {0};
        UInt32 size = sizeof(AudioStreamBasicDescription);
        raise_if_raw_audio_error(AudioUnitGetProperty(this->_core.raw_unit(), kAudioUnitProperty_StreamFormat,
                                                      kAudioUnitScope_Output, bus_idx, &asbd, &size));
        return asbd;
    }

    void set_maximum_frames_per_slice(uint32_t const frames) {
        raise_if_raw_audio_error(AudioUnitSetProperty(this->_core.raw_unit(), kAudioUnitProperty_MaximumFramesPerSlice,
                                                      kAudioUnitScope_Global, 0, &frames, sizeof(uint32_t)));
    }

    uint32_t maximum_frames_per_slice() {
        UInt32 frames = 0;
        UInt32 size = sizeof(UInt32);
        raise_if_raw_audio_error(AudioUnitGetProperty(this->_core.raw_unit(), kAudioUnitProperty_MaximumFramesPerSlice,
                                                      kAudioUnitScope_Global, 0, &frames, &size));
        return frames;
    }

    void set_parameter_value(AudioUnitParameterValue const value, AudioUnitParameterID const parameter_id,
                             AudioUnitScope const scope, AudioUnitElement const element) {
        raise_if_raw_audio_error(AudioUnitSetParameter(this->_core.raw_unit(), parameter_id, scope, element, value, 0));
    }

    AudioUnitParameterValue parameter_value(AudioUnitParameterID const parameter_id, AudioUnitScope const scope,
                                            AudioUnitElement const element) {
        AudioUnitParameterValue value = 0;
        raise_if_raw_audio_error(AudioUnitGetParameter(this->_core.raw_unit(), parameter_id, scope, element, &value));
        return value;
    }

    void set_element_count(uint32_t const count, AudioUnitScope const scope) {
        raise_if_raw_audio_error(AudioUnitSetProperty(this->_core.raw_unit(), kAudioUnitProperty_ElementCount, scope, 0,
                                                      &count, sizeof(uint32_t)));
    }

    uint32_t element_count(AudioUnitScope const scope) {
        UInt32 count = 0;
        UInt32 size = sizeof(UInt32);
        raise_if_raw_audio_error(
            AudioUnitGetProperty(this->_core.raw_unit(), kAudioUnitProperty_ElementCount, scope, 0, &count, &size));
        return count;
    }

    void set_enable_output(bool const enable_output) {
        if (!has_output()) {
            return;
        }

        if (is_enable_output() == enable_output) {
            return;
        }

        if (_initialized) {
            raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - AudioUnit is initialized.");
            return;
        }

        uint32_t enableIO = enable_output ? 1 : 0;
        raise_if_raw_audio_error(AudioUnitSetProperty(this->_core.raw_unit(), kAudioOutputUnitProperty_EnableIO,
                                                      kAudioUnitScope_Output, 0, &enableIO, sizeof(uint32_t)));
    }

    bool is_enable_output() {
        UInt32 enableIO = 0;
        UInt32 size = sizeof(UInt32);
        raise_if_raw_audio_error(AudioUnitGetProperty(this->_core.raw_unit(), kAudioOutputUnitProperty_EnableIO,
                                                      kAudioUnitScope_Output, 0, &enableIO, &size));
        return enableIO;
    }

    void set_enable_input(bool const enable_input) {
        if (!has_input()) {
            return;
        }

        if (is_enable_input() == enable_input) {
            return;
        }

        if (_initialized) {
            raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - AudioUnit is initialized.");
            return;
        }

        uint32_t enableIO = enable_input ? 1 : 0;
        raise_if_raw_audio_error(AudioUnitSetProperty(this->_core.raw_unit(), kAudioOutputUnitProperty_EnableIO,
                                                      kAudioUnitScope_Input, 1, &enableIO, sizeof(uint32_t)));
    }

    bool is_enable_input() {
        UInt32 enableIO = 0;
        UInt32 size = sizeof(UInt32);
        raise_if_raw_audio_error(AudioUnitGetProperty(this->_core.raw_unit(), kAudioOutputUnitProperty_EnableIO,
                                                      kAudioUnitScope_Input, 1, &enableIO, &size));
        return enableIO;
    }

    bool has_output() {
#if TARGET_OS_IPHONE
        return true;
#elif TARGET_OS_MAC
        UInt32 has_io = 0;
        UInt32 size = sizeof(UInt32);
        raise_if_raw_audio_error(AudioUnitGetProperty(this->_core.raw_unit(), kAudioOutputUnitProperty_HasIO,
                                                      kAudioUnitScope_Output, 0, &has_io, &size));
        return has_io;
#endif
    }

    bool has_input() {
#if TARGET_IPHONE_SIMULATOR
        return true;
#elif TARGET_OS_IPHONE
        return [AVAudioSession sharedInstance].isInputAvailable;
#elif TARGET_OS_MAC
        UInt32 has_io = 0;
        UInt32 size = sizeof(UInt32);
        raise_if_raw_audio_error(AudioUnitGetProperty(this->_core.raw_unit(), kAudioOutputUnitProperty_HasIO,
                                                      kAudioUnitScope_Input, 1, &has_io, &size));
        return has_io;
#endif
    }

    bool is_running() {
        UInt32 is_running = 0;
        UInt32 size = sizeof(UInt32);
        raise_if_raw_audio_error(AudioUnitGetProperty(this->_core.raw_unit(), kAudioOutputUnitProperty_IsRunning,
                                                      kAudioUnitScope_Global, 0, &is_running, &size));
        return is_running != 0;
    }

    void set_channel_map(channel_map_t const &map, AudioUnitScope const scope, AudioUnitElement const element) {
        if (this->_acd.componentType != kAudioUnitType_Output) {
            throw std::runtime_error(std::string(__PRETTY_FUNCTION__) +
                                     " : invalid component type. (not kAudioUnitType_Output)");
        }

        set_property_data(map, kAudioOutputUnitProperty_ChannelMap, scope, element);
    }

    audio::channel_map_t channel_map(AudioUnitScope const scope, AudioUnitElement const element) {
        if (this->_acd.componentType != kAudioUnitType_Output) {
            throw std::runtime_error(std::string(__PRETTY_FUNCTION__) +
                                     " : invalid component type. (not kAudioUnitType_Output)");
        }

        return property_data<uint32_t>(kAudioOutputUnitProperty_ChannelMap, scope, element);
    }

    uint32_t channel_map_count(AudioUnitScope const scope, AudioUnitElement const element) {
        UInt32 byte_size = 0;
        raise_if_raw_audio_error(AudioUnitGetPropertyInfo(this->_core.raw_unit(), kAudioOutputUnitProperty_ChannelMap,
                                                          scope, element, &byte_size, nullptr));

        if (byte_size) {
            return byte_size / sizeof(uint32_t);
        }
        return 0;
    }

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    void set_current_device(AudioDeviceID const device) {
        raise_if_raw_audio_error(AudioUnitSetProperty(this->_core.raw_unit(), kAudioOutputUnitProperty_CurrentDevice,
                                                      kAudioUnitScope_Global, 0, &device, sizeof(AudioDeviceID)));
    }

    AudioDeviceID current_device() {
        AudioDeviceID device = 0;
        UInt32 size = sizeof(AudioDeviceID);
        raise_if_raw_audio_error(AudioUnitGetProperty(this->_core.raw_unit(), kAudioOutputUnitProperty_CurrentDevice,
                                                      kAudioUnitScope_Global, 0, &device, &size));
        return device;
    }
#endif

    void start() {
        if (this->_acd.componentType != kAudioUnitType_Output) {
            raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - Not output unit.");
            return;
        }

        if (!this->is_running()) {
            raise_if_raw_audio_error(AudioOutputUnitStart(this->_core.raw_unit()));
        }
    }

    void stop() {
        if (this->_acd.componentType != kAudioUnitType_Output) {
            raise_with_reason(std::string(__PRETTY_FUNCTION__) + " - Not output unit.");
            return;
        }

        if (this->is_running()) {
            raise_if_raw_audio_error(AudioOutputUnitStop(_core.raw_unit()));
        }
    }

    template <typename T>
    void set_property_data(std::vector<T> const &data, AudioUnitPropertyID const property_id,
                           AudioUnitScope const scope, AudioUnitElement const element) {
        uint32_t const size = static_cast<uint32_t>(data.size());
        const void *const raw_data = size > 0 ? data.data() : nullptr;

        raise_if_raw_audio_error(
            AudioUnitSetProperty(raw_unit(), property_id, scope, element, raw_data, size * sizeof(T)));
    }

    template <typename T>
    std::vector<T> property_data(AudioUnitPropertyID const property_id, AudioUnitScope const scope,
                                 AudioUnitElement const element) {
        AudioUnit au = this->raw_unit();

        UInt32 byte_size = 0;
        raise_if_raw_audio_error(AudioUnitGetPropertyInfo(au, property_id, scope, element, &byte_size, nullptr));
        uint32_t vector_size = byte_size / sizeof(T);

        auto data = std::vector<T>(vector_size);

        if (vector_size > 0) {
            byte_size = vector_size * sizeof(T);
            raise_if_raw_audio_error(AudioUnitGetProperty(au, property_id, scope, element, data.data(), &byte_size));
        }

        return data;
    }

    void set_graph_key(std::optional<uint8_t> const &key) override {
        this->_graph_key = key;
    }

    std::optional<uint8_t> const &graph_key() const override {
        return this->_graph_key;
    }

    void set_key(std::optional<uint16_t> const &key) override {
        this->_key = key;
    }

    std::optional<uint16_t> const &key() const override {
        return this->_key;
    }

    void set_render_handler(render_f &&callback) {
        this->_core.set_render_handler(std::move(callback));
    }

    void set_notify_handler(render_f &&callback) {
        this->_core.set_notify_handler(std::move(callback));
    }

    void set_input_handler(render_f &&callback) {
        this->_core.set_input_handler(std::move(callback));
    }

    void set_raw_unit(AudioUnit const au) {
        this->_core.set_raw_unit(au);
    }

    AudioUnit raw_unit() {
        return this->_core.raw_unit();
    }

#pragma mark - render

    void callback_render(render_parameters &render_parameters) {
        raise_if_main_thread();

        render_f handler = nullptr;

        switch (render_parameters.in_render_type) {
            case render_type::normal:
                handler = this->_core.render_handler();
                break;
            case render_type::notify:
                handler = this->_core.notify_handler();
                break;
            case render_type::input:
                handler = this->_core.input_handler();
                break;
            default:
                break;
        }

        if (handler) {
            handler(render_parameters);
        }
    }

    audio::unit::raw_unit_result_t raw_unit_render(render_parameters &render_parameters) {
        raise_if_main_thread();

        if (AudioUnit au = raw_unit()) {
            return to_result(AudioUnitRender(au, render_parameters.io_action_flags, render_parameters.io_time_stamp,
                                             render_parameters.in_bus_number, render_parameters.in_number_frames,
                                             render_parameters.io_data));
        }

        return unit::raw_unit_result_t(nullptr);
    }

   private:
    struct core {
        void set_render_handler(render_f &&callback) {
            std::lock_guard<std::recursive_mutex> lock(this->_mutex);
            this->_render_handler = std::move(callback);
        }

        audio::unit::render_f render_handler() {
            std::lock_guard<std::recursive_mutex> lock(this->_mutex);
            return this->_render_handler;
        }

        void set_notify_handler(render_f &&callback) {
            std::lock_guard<std::recursive_mutex> lock(this->_mutex);
            this->_notify_handler = std::move(callback);
        }

        audio::unit::render_f notify_handler() {
            std::lock_guard<std::recursive_mutex> lock(this->_mutex);
            return this->_notify_handler;
        }

        void set_input_handler(render_f &&callback) {
            std::lock_guard<std::recursive_mutex> lock(this->_mutex);
            this->_input_handler = std::move(callback);
        }

        audio::unit::render_f input_handler() {
            std::lock_guard<std::recursive_mutex> lock(this->_mutex);
            return this->_input_handler;
        }

        void set_raw_unit(AudioUnit const au) {
            std::lock_guard<std::recursive_mutex> lock(this->_mutex);
            this->_au_instance = au;
        }

        AudioUnit raw_unit() {
            std::lock_guard<std::recursive_mutex> lock(this->_mutex);
            return this->_au_instance;
        }

       private:
        AudioUnit _au_instance;
        render_f _render_handler;
        render_f _notify_handler;
        render_f _input_handler;
        mutable std::recursive_mutex _mutex;
    };

    core _core;
};

#pragma mark - audio::unit

OSType audio::unit::sub_type_default_io() {
#if TARGET_OS_IPHONE
    return kAudioUnitSubType_RemoteIO;
#elif TARGET_OS_MAC
    return kAudioUnitSubType_HALOutput;
#endif
}

audio::unit::unit(std::nullptr_t) : base(nullptr) {
}

audio::unit::unit(AudioComponentDescription const &acd) : base(std::make_shared<impl>()) {
    impl_ptr<impl>()->create_raw_unit(acd);
}

audio::unit::unit(OSType const type, OSType const sub_type)
    : unit({
          .componentType = type,
          .componentSubType = sub_type,
          .componentManufacturer = kAudioUnitManufacturer_Apple,
          .componentFlags = 0,
          .componentFlagsMask = 0,
      }) {
}

audio::unit::~unit() = default;

#pragma mark - accessor

CFStringRef audio::unit::name() const {
    return to_cf_object(impl_ptr<impl>()->_name);
}

OSType audio::unit::type() const {
    return impl_ptr<impl>()->_acd.componentType;
}

OSType audio::unit::sub_type() const {
    return impl_ptr<impl>()->_acd.componentSubType;
}

bool audio::unit::is_output_unit() const {
    return impl_ptr<impl>()->_acd.componentType == kAudioUnitType_Output;
}

AudioUnit audio::unit::raw_unit() const {
    return impl_ptr<impl>()->raw_unit();
}

#pragma mark - render callback

void audio::unit::attach_render_callback(uint32_t const bus_idx) {
    impl_ptr<impl>()->attach_render_callback(bus_idx);
}

void audio::unit::detach_render_callback(uint32_t const bus_idx) {
    impl_ptr<impl>()->detach_render_callback(bus_idx);
}

void audio::unit::attach_render_notify() {
    impl_ptr<impl>()->attach_render_notify();
}

void audio::unit::detach_render_notify() {
    impl_ptr<impl>()->detach_render_notify();
}

void audio::unit::attach_input_callback() {
    impl_ptr<impl>()->attach_input_callback();
}

void audio::unit::detach_input_callback() {
    impl_ptr<impl>()->detach_input_callback();
}

void audio::unit::set_render_handler(render_f callback) {
    impl_ptr<impl>()->set_render_handler(std::move(callback));
}

void audio::unit::set_notify_handler(render_f callback) {
    impl_ptr<impl>()->set_notify_handler(std::move(callback));
}

void audio::unit::set_input_handler(render_f callback) {
    impl_ptr<impl>()->set_input_handler(std::move(callback));
}

#pragma mark - property

void audio::unit::set_input_format(AudioStreamBasicDescription const &asbd, uint32_t const bus_idx) {
    impl_ptr<impl>()->set_input_format(asbd, bus_idx);
}

void audio::unit::set_output_format(AudioStreamBasicDescription const &asbd, uint32_t const bus_idx) {
    impl_ptr<impl>()->set_output_format(asbd, bus_idx);
}

AudioStreamBasicDescription audio::unit::input_format(uint32_t const bus_idx) const {
    return impl_ptr<impl>()->input_format(bus_idx);
}

AudioStreamBasicDescription audio::unit::output_format(uint32_t const bus_idx) const {
    return impl_ptr<impl>()->output_format(bus_idx);
}

void audio::unit::set_maximum_frames_per_slice(uint32_t const frames) {
    impl_ptr<impl>()->set_maximum_frames_per_slice(frames);
}

uint32_t audio::unit::maximum_frames_per_slice() const {
    return impl_ptr<impl>()->maximum_frames_per_slice();
}

bool audio::unit::is_initialized() const {
    return impl_ptr<impl>()->_initialized;
}

void audio::unit::set_element_count(uint32_t const count, AudioUnitScope const scope) {
    impl_ptr<impl>()->set_element_count(count, scope);
}

uint32_t audio::unit::element_count(AudioUnitScope const scope) const {
    return impl_ptr<impl>()->element_count(scope);
}

#pragma mark - parameter

void audio::unit::set_parameter_value(AudioUnitParameterValue const value, AudioUnitParameterID const parameter_id,
                                      AudioUnitScope const scope, AudioUnitElement const element) {
    impl_ptr<impl>()->set_parameter_value(value, parameter_id, scope, element);
}

AudioUnitParameterValue audio::unit::parameter_value(AudioUnitParameterID const parameter_id,
                                                     AudioUnitScope const scope, AudioUnitElement const element) const {
    return impl_ptr<impl>()->parameter_value(parameter_id, scope, element);
}

audio::unit::parameter_map_t audio::unit::create_parameters(AudioUnitScope const scope) const {
    auto parameter_list =
        impl_ptr<impl>()->property_data<AudioUnitParameterID>(kAudioUnitProperty_ParameterList, scope, 0);
    auto parameters = parameter_map_t{};

    if (parameter_list.size() > 0) {
        for (AudioUnitParameterID const &parameter_id : parameter_list) {
            auto parameter = create_parameter(parameter_id, scope);
            parameters.insert(std::make_pair(parameter_id, std::move(parameter)));
        }
    }

    return parameters;
}

audio::unit::parameter audio::unit::create_parameter(AudioUnitParameterID const parameter_id,
                                                     AudioUnitScope const scope) const {
    AudioUnitParameterInfo info = {0};
    UInt32 size = sizeof(AudioUnitParameterInfo);
    OSStatus err = noErr;

    raise_if_raw_audio_error(err = AudioUnitGetProperty(impl_ptr<impl>()->raw_unit(), kAudioUnitProperty_ParameterInfo,
                                                        scope, parameter_id, &info, &size));

    parameter parameter(info, parameter_id, scope);

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

void audio::unit::set_enable_output(bool const enable_output) {
    impl_ptr<impl>()->set_enable_output(enable_output);
}

bool audio::unit::is_enable_output() const {
    return impl_ptr<impl>()->is_enable_input();
}

void audio::unit::set_enable_input(bool const enable_input) {
    impl_ptr<impl>()->set_enable_input(enable_input);
}

bool audio::unit::is_enable_input() const {
    return impl_ptr<impl>()->is_enable_input();
}

bool audio::unit::has_output() const {
    return impl_ptr<impl>()->has_output();
}

bool audio::unit::has_input() const {
    return impl_ptr<impl>()->has_input();
}

bool audio::unit::is_running() const {
    return impl_ptr<impl>()->is_running();
}

void audio::unit::set_channel_map(channel_map_t const &map, AudioUnitScope const scope,
                                  AudioUnitElement const element) {
    impl_ptr<impl>()->set_channel_map(map, scope, element);
}

audio::channel_map_t audio::unit::channel_map(AudioUnitScope const scope, AudioUnitElement const element) const {
    return impl_ptr<impl>()->channel_map(scope, element);
}

uint32_t audio::unit::channel_map_count(AudioUnitScope const scope, AudioUnitElement const element) const {
    return impl_ptr<impl>()->channel_map_count(scope, element);
}

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
void audio::unit::set_current_device(AudioDeviceID const device) {
    impl_ptr<impl>()->set_current_device(device);
}

AudioDeviceID const audio::unit::current_device() const {
    return impl_ptr<impl>()->current_device();
}
#endif

void audio::unit::start() {
    impl_ptr<impl>()->start();
}

void audio::unit::stop() {
    impl_ptr<impl>()->stop();
}

void audio::unit::reset() {
    impl_ptr<impl>()->reset();
}

audio::manageable_unit &audio::unit::manageable() {
    if (!_manageable) {
        _manageable = audio::manageable_unit{impl_ptr<manageable_unit::impl>()};
    }
    return _manageable;
}

#pragma mark - render thread

void audio::unit::callback_render(render_parameters &render_parameters) {
    impl_ptr<impl>()->callback_render(render_parameters);
}

audio::unit::raw_unit_result_t audio::unit::raw_unit_render(render_parameters &render_parameters) {
    return impl_ptr<impl>()->raw_unit_render(render_parameters);
}

#pragma mark - global

audio::unit::raw_unit_result_t yas::to_result(OSStatus const err) {
    if (err == noErr) {
        return audio::unit::raw_unit_result_t(nullptr);
    } else {
        return audio::unit::raw_unit_result_t(err);
    }
}
