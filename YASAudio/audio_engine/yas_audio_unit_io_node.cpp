//
//  yas_audio_unit_io_node.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_unit_io_node.h"

#if TARGET_OS_IPHONE
#elif TARGET_OS_MAC
#include "yas_audio_device.h"
#endif

namespace yas {
namespace audio {
    constexpr AudioComponentDescription audio_unit_io_node_acd = {
        .componentType = kAudioUnitType_Output,
#if TARGET_OS_IPHONE
        .componentSubType = kAudioUnitSubType_RemoteIO,
#elif TARGET_OS_MAC
        .componentSubType = kAudioUnitSubType_HALOutput,
#endif
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        .componentFlags = 0,
        .componentFlagsMask = 0,
    };
}
}

using namespace yas;

#pragma mark - main

audio::unit_io_node::unit_io_node(std::nullptr_t) : super_class(nullptr) {
}

audio::unit_io_node::unit_io_node() : unit_io_node(std::make_shared<impl>(), audio_unit_io_node_acd) {
}

audio::unit_io_node::unit_io_node(const std::shared_ptr<impl> &impl, const AudioComponentDescription &acd)
    : super_class(impl, acd) {
}

audio::unit_io_node::~unit_io_node() = default;

void audio::unit_io_node::set_channel_map(const channel_map_t &map, const direction dir) {
    impl_ptr<impl>()->set_channel_map(map, dir);
}

const audio::channel_map_t &audio::unit_io_node::channel_map(const direction dir) const {
    return impl_ptr<impl>()->channel_map(dir);
}

Float64 audio::unit_io_node::device_sample_rate() const {
    return impl_ptr<impl>()->device_sample_rate();
}

UInt32 audio::unit_io_node::output_device_channel_count() const {
    return impl_ptr<impl>()->output_device_channel_count();
}

UInt32 audio::unit_io_node::input_device_channel_count() const {
    return impl_ptr<impl>()->input_device_channel_count();
}

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

void audio::unit_io_node::set_device(const audio::device &device) {
    impl_ptr<impl>()->set_device(device);
}

audio::device audio::unit_io_node::device() const {
    return impl_ptr<impl>()->device();
}

#endif

#pragma mark - audio_unit_output_node

audio::unit_output_node::unit_output_node(std::nullptr_t) : super_class() {
}

audio::unit_output_node::unit_output_node() : super_class(std::make_unique<impl>(), audio_unit_io_node_acd) {
}

void audio::unit_output_node::set_channel_map(const channel_map_t &map) {
    super_class::set_channel_map(map, direction::output);
}

const audio::channel_map_t &audio::unit_output_node::channel_map() const {
    return super_class::channel_map(direction::output);
}

#pragma mark - audio_unit_input_node

audio::unit_input_node::unit_input_node(std::nullptr_t) : super_class(nullptr) {
}

audio::unit_input_node::unit_input_node() : super_class(std::make_unique<impl>(), audio_unit_io_node_acd) {
}

void audio::unit_input_node::set_channel_map(const channel_map_t &map) {
    super_class::set_channel_map(map, direction::input);
}

const audio::channel_map_t &audio::unit_input_node::channel_map() const {
    return super_class::channel_map(direction::input);
}
