//
//  yas_audio_unit.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_unit.h"
#include "yas_cf_utils.h"

using namespace yas;

#pragma mark -

const OSType audio_unit::sub_type_default_io()
{
#if TARGET_OS_IPHONE
    return kAudioUnitSubType_RemoteIO;
#elif TARGET_OS_MAC
    return kAudioUnitSubType_HALOutput;
#endif
}

audio_unit::audio_unit(std::nullptr_t) : super_class(nullptr)
{
}

audio_unit::audio_unit(const AudioComponentDescription &acd) : super_class(std::make_shared<impl>())
{
    _impl_ptr()->create_audio_unit(acd);
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

#pragma mark - accessor

CFStringRef audio_unit::name() const
{
    return to_cf_object(_impl_ptr()->name());
}

OSType audio_unit::type() const
{
    return _impl_ptr()->acd().componentType;
}

OSType audio_unit::sub_type() const
{
    return _impl_ptr()->acd().componentSubType;
}

bool audio_unit::is_output_unit() const
{
    return _impl_ptr()->acd().componentType == kAudioUnitType_Output;
}

AudioUnit audio_unit::audio_unit_instance() const
{
    return _impl_ptr()->audio_unit_instance();
}

#pragma mark - render callback

void audio_unit::attach_render_callback(const UInt32 &bus_idx)
{
    _impl_ptr()->attach_render_callback(bus_idx);
}

void audio_unit::detach_render_callback(const UInt32 &bus_idx)
{
    _impl_ptr()->detach_render_callback(bus_idx);
}

void audio_unit::attach_render_notify()
{
    _impl_ptr()->attach_render_notify();
}

void audio_unit::detach_render_notify()
{
    _impl_ptr()->detach_render_notify();
}

void audio_unit::attach_input_callback()
{
    _impl_ptr()->attach_input_callback();
}

void audio_unit::detach_input_callback()
{
    _impl_ptr()->detach_input_callback();
}

void audio_unit::set_render_callback(const render_f &callback)
{
    _impl_ptr()->set_render_callback(callback);
}

void audio_unit::set_notify_callback(const render_f &callback)
{
    _impl_ptr()->set_notify_callback(callback);
}

void audio_unit::set_input_callback(const render_f &callback)
{
    _impl_ptr()->set_input_callback(callback);
}

#pragma mark - property

void audio_unit::set_input_format(const AudioStreamBasicDescription &asbd, const UInt32 bus_idx)
{
    _impl_ptr()->set_input_format(asbd, bus_idx);
}

void audio_unit::set_output_format(const AudioStreamBasicDescription &asbd, const UInt32 bus_idx)
{
    _impl_ptr()->set_output_format(asbd, bus_idx);
}

AudioStreamBasicDescription audio_unit::input_format(const UInt32 bus_idx) const
{
    return _impl_ptr()->input_format(bus_idx);
}

AudioStreamBasicDescription audio_unit::output_format(const UInt32 bus_idx) const
{
    return _impl_ptr()->output_format(bus_idx);
}

void audio_unit::set_maximum_frames_per_slice(const UInt32 frames)
{
    _impl_ptr()->set_maximum_frames_per_slice(frames);
}

UInt32 audio_unit::maximum_frames_per_slice() const
{
    return _impl_ptr()->maximum_frames_per_slice();
}

bool audio_unit::is_initialized()
{
    return _impl_ptr()->is_initialized();
}

void audio_unit::set_element_count(const UInt32 &count, const AudioUnitScope &scope)
{
    _impl_ptr()->set_element_count(count, scope);
}

UInt32 audio_unit::element_count(const AudioUnitScope &scope) const
{
    return _impl_ptr()->element_count(scope);
}

#pragma mark - parameter

void audio_unit::set_parameter_value(const AudioUnitParameterValue value, const AudioUnitParameterID parameter_id,
                                     const AudioUnitScope scope, const AudioUnitElement element)
{
    _impl_ptr()->set_parameter_value(value, parameter_id, scope, element);
}

AudioUnitParameterValue audio_unit::parameter_value(const AudioUnitParameterID parameter_id, const AudioUnitScope scope,
                                                    const AudioUnitElement element)
{
    return _impl_ptr()->parameter_value(parameter_id, scope, element);
}

audio_unit_parameter_map_t audio_unit::create_parameters(const AudioUnitScope scope) const
{
    auto parameter_list = _impl_ptr()->property_data<AudioUnitParameterID>(kAudioUnitProperty_ParameterList, scope, 0);
    auto parameters = audio_unit_parameter_map_t();

    if (parameter_list.size() > 0) {
        for (const AudioUnitParameterID &parameter_id : parameter_list) {
            auto parameter = audio_unit::create_parameter(parameter_id, scope);
            parameters.insert(std::make_pair(parameter_id, std::move(parameter)));
        }
    }

    return parameters;
}

audio_unit_parameter audio_unit::create_parameter(const AudioUnitParameterID &parameter_id,
                                                  const AudioUnitScope scope) const
{
    AudioUnitParameterInfo info = {0};
    UInt32 size = sizeof(AudioUnitParameterInfo);
    OSStatus err = noErr;

    yas_raise_if_au_error(err =
                              AudioUnitGetProperty(_impl_ptr()->audio_unit_instance(), kAudioUnitProperty_ParameterInfo,
                                                   scope, parameter_id, &info, &size));

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
    _impl_ptr()->set_enable_output(enable_output);
}

bool audio_unit::is_enable_output() const
{
    return _impl_ptr()->is_enable_input();
}

void audio_unit::set_enable_input(const bool enable_input)
{
    _impl_ptr()->set_enable_input(enable_input);
}

bool audio_unit::is_enable_input() const
{
    return _impl_ptr()->is_enable_input();
}

bool audio_unit::has_output() const
{
    return _impl_ptr()->has_output();
}

bool audio_unit::has_input() const
{
    return _impl_ptr()->has_input();
}

bool audio_unit::is_running() const
{
    return _impl_ptr()->is_running();
}

void audio_unit::set_channel_map(const channel_map_t &map, const AudioUnitScope scope, const AudioUnitElement element)
{
    _impl_ptr()->set_channel_map(map, scope, element);
}

channel_map_t audio_unit::channel_map(const AudioUnitScope scope, const AudioUnitElement element) const
{
    return _impl_ptr()->channel_map(scope, element);
}

UInt32 audio_unit::channel_map_count(const AudioUnitScope scope, const AudioUnitElement element) const
{
    return _impl_ptr()->channel_map_count(scope, element);
}

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
void audio_unit::set_current_device(const AudioDeviceID &device)
{
    _impl_ptr()->set_current_device(device);
}

const AudioDeviceID audio_unit::current_device() const
{
    return _impl_ptr()->current_device();
}
#endif

void audio_unit::start()
{
    _impl_ptr()->start();
}

void audio_unit::stop()
{
    _impl_ptr()->stop();
}

void audio_unit::reset()
{
    _impl_ptr()->reset();
}

#pragma mark - render thread

void audio_unit::callback_render(yas::render_parameters &render_parameters)
{
    _impl_ptr()->callback_render(render_parameters);
}

void audio_unit::audio_unit_render(yas::render_parameters &render_parameters)
{
    _impl_ptr()->audio_unit_render(render_parameters);
}

#pragma mark - private function

std::shared_ptr<audio_unit::impl> audio_unit::_impl_ptr() const
{
    return impl_ptr<impl>();
}

void audio_unit::_initialize()
{
    _impl_ptr()->initialize();
}

void audio_unit::_uninitialize()
{
    _impl_ptr()->uninitialize();
}

void audio_unit::_set_graph_key(const std::experimental::optional<UInt8> &key)
{
    _impl_ptr()->graph_key = key;
}

const std::experimental::optional<UInt8> &audio_unit::_graph_key() const
{
    return _impl_ptr()->graph_key;
}

void audio_unit::_set_key(const std::experimental::optional<UInt16> &key)
{
    _impl_ptr()->key = key;
}

const std::experimental::optional<UInt16> &audio_unit::_key() const
{
    return _impl_ptr()->key;
}
