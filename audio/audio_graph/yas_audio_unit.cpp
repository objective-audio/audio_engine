//
//  yas_audio_unit.cpp
//

#include "yas_audio_unit.h"
#include "yas_cf_utils.h"
#include "yas_result.h"

using namespace yas;

#pragma mark -

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
    impl_ptr<impl>()->create_audio_unit(acd);
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

#pragma mark - accessor

CFStringRef audio::unit::name() const {
    return to_cf_object(impl_ptr<impl>()->name());
}

OSType audio::unit::type() const {
    return impl_ptr<impl>()->acd().componentType;
}

OSType audio::unit::sub_type() const {
    return impl_ptr<impl>()->acd().componentSubType;
}

bool audio::unit::is_output_unit() const {
    return impl_ptr<impl>()->acd().componentType == kAudioUnitType_Output;
}

AudioUnit audio::unit::audio_unit_instance() const {
    return impl_ptr<impl>()->audio_unit_instance();
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

void audio::unit::set_render_callback(render_f callback) {
    impl_ptr<impl>()->set_render_callback(std::move(callback));
}

void audio::unit::set_notify_callback(render_f callback) {
    impl_ptr<impl>()->set_notify_callback(std::move(callback));
}

void audio::unit::set_input_callback(render_f callback) {
    impl_ptr<impl>()->set_input_callback(std::move(callback));
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
    return impl_ptr<impl>()->is_initialized();
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

    raise_if_au_error(err = AudioUnitGetProperty(impl_ptr<impl>()->audio_unit_instance(),
                                                 kAudioUnitProperty_ParameterInfo, scope, parameter_id, &info, &size));

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

audio::manageable_unit audio::unit::manageable() {
    return audio::manageable_unit{impl_ptr<manageable_unit::impl>()};
}

#pragma mark - render thread

void audio::unit::callback_render(render_parameters &render_parameters) {
    impl_ptr<impl>()->callback_render(render_parameters);
}

audio::unit::au_result_t audio::unit::audio_unit_render(render_parameters &render_parameters) {
    return impl_ptr<impl>()->audio_unit_render(render_parameters);
}

#pragma mark - global

audio::unit::au_result_t yas::to_result(OSStatus const err) {
    if (err == noErr) {
        return audio::unit::au_result_t(nullptr);
    } else {
        return audio::unit::au_result_t(err);
    }
}
