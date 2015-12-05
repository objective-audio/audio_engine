//
//  yas_audio_unit.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_unit.h"
#include "yas_cf_utils.h"

using namespace yas;

#pragma mark -

const OSType audio::unit::sub_type_default_io()
{
#if TARGET_OS_IPHONE
    return kAudioUnitSubType_RemoteIO;
#elif TARGET_OS_MAC
    return kAudioUnitSubType_HALOutput;
#endif
}

audio::unit::unit(std::nullptr_t) : super_class(nullptr)
{
}

audio::unit::unit(const AudioComponentDescription &acd) : super_class(std::make_shared<impl>())
{
    impl_ptr<impl>()->create_audio_unit(acd);
}

audio::unit::unit(const OSType &type, const OSType &sub_type)
    : unit({
          .componentType = type,
          .componentSubType = sub_type,
          .componentManufacturer = kAudioUnitManufacturer_Apple,
          .componentFlags = 0,
          .componentFlagsMask = 0,
      })
{
}

#pragma mark - accessor

CFStringRef audio::unit::name() const
{
    return to_cf_object(impl_ptr<impl>()->name());
}

OSType audio::unit::type() const
{
    return impl_ptr<impl>()->acd().componentType;
}

OSType audio::unit::sub_type() const
{
    return impl_ptr<impl>()->acd().componentSubType;
}

bool audio::unit::is_output_unit() const
{
    return impl_ptr<impl>()->acd().componentType == kAudioUnitType_Output;
}

AudioUnit audio::unit::audio_unit_instance() const
{
    return impl_ptr<impl>()->audio_unit_instance();
}

#pragma mark - render callback

void audio::unit::attach_render_callback(const UInt32 &bus_idx)
{
    impl_ptr<impl>()->attach_render_callback(bus_idx);
}

void audio::unit::detach_render_callback(const UInt32 &bus_idx)
{
    impl_ptr<impl>()->detach_render_callback(bus_idx);
}

void audio::unit::attach_render_notify()
{
    impl_ptr<impl>()->attach_render_notify();
}

void audio::unit::detach_render_notify()
{
    impl_ptr<impl>()->detach_render_notify();
}

void audio::unit::attach_input_callback()
{
    impl_ptr<impl>()->attach_input_callback();
}

void audio::unit::detach_input_callback()
{
    impl_ptr<impl>()->detach_input_callback();
}

void audio::unit::set_render_callback(const render_f &callback)
{
    impl_ptr<impl>()->set_render_callback(callback);
}

void audio::unit::set_notify_callback(const render_f &callback)
{
    impl_ptr<impl>()->set_notify_callback(callback);
}

void audio::unit::set_input_callback(const render_f &callback)
{
    impl_ptr<impl>()->set_input_callback(callback);
}

#pragma mark - property

void audio::unit::set_input_format(const AudioStreamBasicDescription &asbd, const UInt32 bus_idx)
{
    impl_ptr<impl>()->set_input_format(asbd, bus_idx);
}

void audio::unit::set_output_format(const AudioStreamBasicDescription &asbd, const UInt32 bus_idx)
{
    impl_ptr<impl>()->set_output_format(asbd, bus_idx);
}

AudioStreamBasicDescription audio::unit::input_format(const UInt32 bus_idx) const
{
    return impl_ptr<impl>()->input_format(bus_idx);
}

AudioStreamBasicDescription audio::unit::output_format(const UInt32 bus_idx) const
{
    return impl_ptr<impl>()->output_format(bus_idx);
}

void audio::unit::set_maximum_frames_per_slice(const UInt32 frames)
{
    impl_ptr<impl>()->set_maximum_frames_per_slice(frames);
}

UInt32 audio::unit::maximum_frames_per_slice() const
{
    return impl_ptr<impl>()->maximum_frames_per_slice();
}

bool audio::unit::is_initialized() const
{
    return impl_ptr<impl>()->is_initialized();
}

void audio::unit::set_element_count(const UInt32 &count, const AudioUnitScope &scope)
{
    impl_ptr<impl>()->set_element_count(count, scope);
}

UInt32 audio::unit::element_count(const AudioUnitScope &scope) const
{
    return impl_ptr<impl>()->element_count(scope);
}

#pragma mark - parameter

void audio::unit::set_parameter_value(const AudioUnitParameterValue value, const AudioUnitParameterID parameter_id,
                                      const AudioUnitScope scope, const AudioUnitElement element)
{
    impl_ptr<impl>()->set_parameter_value(value, parameter_id, scope, element);
}

AudioUnitParameterValue audio::unit::parameter_value(const AudioUnitParameterID parameter_id,
                                                     const AudioUnitScope scope, const AudioUnitElement element) const
{
    return impl_ptr<impl>()->parameter_value(parameter_id, scope, element);
}

audio::unit::parameter_map_t audio::unit::create_parameters(const AudioUnitScope scope) const
{
    auto parameter_list =
        impl_ptr<impl>()->property_data<AudioUnitParameterID>(kAudioUnitProperty_ParameterList, scope, 0);
    auto parameters = audio::unit::parameter_map_t{};

    if (parameter_list.size() > 0) {
        for (const AudioUnitParameterID &parameter_id : parameter_list) {
            auto parameter = audio::unit::create_parameter(parameter_id, scope);
            parameters.insert(std::make_pair(parameter_id, std::move(parameter)));
        }
    }

    return parameters;
}

audio::unit::parameter audio::unit::create_parameter(const AudioUnitParameterID &parameter_id,
                                                     const AudioUnitScope scope) const
{
    AudioUnitParameterInfo info = {0};
    UInt32 size = sizeof(AudioUnitParameterInfo);
    OSStatus err = noErr;

    yas_raise_if_au_error(err = AudioUnitGetProperty(impl_ptr<impl>()->audio_unit_instance(),
                                                     kAudioUnitProperty_ParameterInfo, scope, parameter_id, &info,
                                                     &size));

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

void audio::unit::set_enable_output(const bool enable_output)
{
    impl_ptr<impl>()->set_enable_output(enable_output);
}

bool audio::unit::is_enable_output() const
{
    return impl_ptr<impl>()->is_enable_input();
}

void audio::unit::set_enable_input(const bool enable_input)
{
    impl_ptr<impl>()->set_enable_input(enable_input);
}

bool audio::unit::is_enable_input() const
{
    return impl_ptr<impl>()->is_enable_input();
}

bool audio::unit::has_output() const
{
    return impl_ptr<impl>()->has_output();
}

bool audio::unit::has_input() const
{
    return impl_ptr<impl>()->has_input();
}

bool audio::unit::is_running() const
{
    return impl_ptr<impl>()->is_running();
}

void audio::unit::set_channel_map(const channel_map_t &map, const AudioUnitScope scope, const AudioUnitElement element)
{
    impl_ptr<impl>()->set_channel_map(map, scope, element);
}

channel_map_t audio::unit::channel_map(const AudioUnitScope scope, const AudioUnitElement element) const
{
    return impl_ptr<impl>()->channel_map(scope, element);
}

UInt32 audio::unit::channel_map_count(const AudioUnitScope scope, const AudioUnitElement element) const
{
    return impl_ptr<impl>()->channel_map_count(scope, element);
}

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
void audio::unit::set_current_device(const AudioDeviceID &device)
{
    impl_ptr<impl>()->set_current_device(device);
}

const AudioDeviceID audio::unit::current_device() const
{
    return impl_ptr<impl>()->current_device();
}
#endif

void audio::unit::start()
{
    impl_ptr<impl>()->start();
}

void audio::unit::stop()
{
    impl_ptr<impl>()->stop();
}

void audio::unit::reset()
{
    impl_ptr<impl>()->reset();
}

#pragma mark - render thread

void audio::unit::callback_render(yas::render_parameters &render_parameters)
{
    impl_ptr<impl>()->callback_render(render_parameters);
}

audio::unit::au_result_t audio::unit::audio_unit_render(yas::render_parameters &render_parameters)
{
    return impl_ptr<impl>()->audio_unit_render(render_parameters);
}

#pragma mark - private function

void audio::unit::_initialize()
{
    impl_ptr<impl>()->initialize();
}

void audio::unit::_uninitialize()
{
    impl_ptr<impl>()->uninitialize();
}

void audio::unit::_set_graph_key(const std::experimental::optional<UInt8> &key)
{
    impl_ptr<impl>()->graph_key = key;
}

const std::experimental::optional<UInt8> &audio::unit::_graph_key() const
{
    return impl_ptr<impl>()->graph_key;
}

void audio::unit::_set_key(const std::experimental::optional<UInt16> &key)
{
    impl_ptr<impl>()->key = key;
}

const std::experimental::optional<UInt16> &audio::unit::_key() const
{
    return impl_ptr<impl>()->key;
}

#pragma mark - global

audio::unit::au_result_t yas::to_result(const OSStatus err)
{
    if (err == noErr) {
        return audio::unit::au_result_t(nullptr);
    } else {
        return audio::unit::au_result_t(err);
    }
}
