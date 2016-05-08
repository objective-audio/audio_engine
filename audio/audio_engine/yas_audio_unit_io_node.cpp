//
//  yas_audio_unit_io_node.cpp
//

#include "yas_audio_unit_io_node.h"

#if TARGET_OS_IPHONE
#elif TARGET_OS_MAC
#include "yas_audio_device.h"
#endif

namespace yas {
namespace audio {
    AudioComponentDescription constexpr audio_unit_io_node_acd = {
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

audio::unit_io_node::unit_io_node(std::nullptr_t) : unit_node(nullptr) {
}

audio::unit_io_node::unit_io_node() : unit_io_node(std::make_shared<impl>(), audio_unit_io_node_acd) {
}

audio::unit_io_node::unit_io_node(std::shared_ptr<impl> const &impl, AudioComponentDescription const &acd)
    : unit_node(impl, acd) {
}

audio::unit_io_node::~unit_io_node() = default;

void audio::unit_io_node::set_channel_map(channel_map_t const &map, direction const dir) {
    impl_ptr<impl>()->set_channel_map(map, dir);
}

audio::channel_map_t const &audio::unit_io_node::channel_map(direction const dir) const {
    return impl_ptr<impl>()->channel_map(dir);
}

double audio::unit_io_node::device_sample_rate() const {
    return impl_ptr<impl>()->device_sample_rate();
}

uint32_t audio::unit_io_node::output_device_channel_count() const {
    return impl_ptr<impl>()->output_device_channel_count();
}

uint32_t audio::unit_io_node::input_device_channel_count() const {
    return impl_ptr<impl>()->input_device_channel_count();
}

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

void audio::unit_io_node::set_device(audio::device const &device) {
    impl_ptr<impl>()->set_device(device);
}

audio::device audio::unit_io_node::device() const {
    return impl_ptr<impl>()->device();
}

#endif

#pragma mark - audio_unit_output_node

audio::unit_output_node::unit_output_node(std::nullptr_t) : unit_io_node() {
}

audio::unit_output_node::unit_output_node() : unit_io_node(std::make_unique<impl>(), audio_unit_io_node_acd) {
}

void audio::unit_output_node::set_channel_map(channel_map_t const &map) {
    unit_io_node::set_channel_map(map, direction::output);
}

audio::channel_map_t const &audio::unit_output_node::channel_map() const {
    return unit_io_node::channel_map(direction::output);
}

#pragma mark - audio_unit_input_node

audio::unit_input_node::unit_input_node(std::nullptr_t) : unit_io_node(nullptr) {
}

audio::unit_input_node::unit_input_node() : unit_io_node(std::make_unique<impl>(), audio_unit_io_node_acd) {
}

void audio::unit_input_node::set_channel_map(channel_map_t const &map) {
    unit_io_node::set_channel_map(map, direction::input);
}

audio::channel_map_t const &audio::unit_input_node::channel_map() const {
    return unit_io_node::channel_map(direction::input);
}
