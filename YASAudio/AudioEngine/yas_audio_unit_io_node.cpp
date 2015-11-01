//
//  yas_audio_unit_io_node.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_unit_io_node.h"

#if TARGET_OS_IPHONE
#elif TARGET_OS_MAC
#include "yas_audio_device.h"
#endif

namespace yas
{
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

using namespace yas;

#pragma mark - main

audio_unit_io_node::audio_unit_io_node(std::nullptr_t) : super_class(nullptr)
{
}

audio_unit_io_node::audio_unit_io_node() : audio_unit_io_node(std::make_shared<impl>(), audio_unit_io_node_acd)
{
}

audio_unit_io_node::audio_unit_io_node(const std::shared_ptr<impl> &impl, const AudioComponentDescription &acd)
    : super_class(impl, acd)
{
}

audio_unit_io_node::~audio_unit_io_node() = default;

void audio_unit_io_node::set_channel_map(const channel_map_t &map, const yas::direction dir)
{
    _impl_ptr()->set_channel_map(map, dir);
}

const channel_map_t &audio_unit_io_node::channel_map(const yas::direction dir) const
{
    return _impl_ptr()->channel_map(dir);
}

Float64 audio_unit_io_node::device_sample_rate() const
{
    return _impl_ptr()->device_sample_rate();
}

UInt32 audio_unit_io_node::output_device_channel_count() const
{
    return _impl_ptr()->output_device_channel_count();
}

UInt32 audio_unit_io_node::input_device_channel_count() const
{
    return _impl_ptr()->input_device_channel_count();
}

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

void audio_unit_io_node::set_device(const audio_device &device)
{
    _impl_ptr()->set_device(device);
}

audio_device audio_unit_io_node::device() const
{
    return _impl_ptr()->device();
}

#endif

std::shared_ptr<audio_unit_io_node::impl> audio_unit_io_node::_impl_ptr() const
{
    return impl_ptr<impl>();
}

#pragma mark - audio_unit_output_node

audio_unit_output_node::audio_unit_output_node(std::nullptr_t) : super_class()
{
}

audio_unit_output_node::audio_unit_output_node() : super_class(std::make_unique<impl>(), audio_unit_io_node_acd)
{
}

void audio_unit_output_node::set_channel_map(const channel_map_t &map)
{
    super_class::set_channel_map(map, yas::direction::output);
}

const channel_map_t &audio_unit_output_node::channel_map() const
{
    return super_class::channel_map(yas::direction::output);
}

#pragma mark - audio_unit_input_node

audio_unit_input_node::audio_unit_input_node(std::nullptr_t) : super_class(nullptr)
{
}

audio_unit_input_node::audio_unit_input_node() : super_class(std::make_unique<impl>(), audio_unit_io_node_acd)
{
}

void audio_unit_input_node::set_channel_map(const channel_map_t &map)
{
    super_class::set_channel_map(map, yas::direction::input);
}

const channel_map_t &audio_unit_input_node::channel_map() const
{
    return super_class::channel_map(yas::direction::input);
}

std::shared_ptr<audio_unit_input_node::impl> audio_unit_input_node::_impl_ptr() const
{
    return impl_ptr<impl>();
}
