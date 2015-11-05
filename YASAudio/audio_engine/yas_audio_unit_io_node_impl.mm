//
//  yas_audio_unit_io_node_impl.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_unit_io_node.h"
#include "yas_audio_tap_node.h"
#include "yas_audio_unit.h"
#include "yas_audio_time.h"

#if TARGET_OS_IPHONE
#import <AVFoundation/AVFoundation.h>
#elif TARGET_OS_MAC
#include "yas_audio_device.h"
#endif

using namespace yas;

class audio_unit_io_node::impl::core
{
   public:
    static const UInt32 channel_map_count = 2;
    channel_map_t channel_map[2];
};

#pragma mark - audio_unit_io_node::impl

audio_unit_io_node::impl::impl() : super_class::impl(), _core(std::make_unique<audio_unit_io_node::impl::core>())
{
}

audio_unit_io_node::impl::~impl() = default;

void audio_unit_io_node::impl::reset()
{
    super_class::reset();
}

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

void audio_unit_io_node::impl::set_device(const audio_device &device)
{
    if (!device) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    au().set_current_device(device.audio_device_id());
}

audio_device audio_unit_io_node::impl::device() const
{
    return audio_device::device_for_id(au().current_device());
}

#endif

Float64 audio_unit_io_node::impl::device_sample_rate() const
{
#if TARGET_OS_IPHONE
    return [AVAudioSession sharedInstance].sampleRate;
#elif TARGET_OS_MAC
    if (const auto &dev = device()) {
        return dev.nominal_sample_rate();
    }
    return 0;
#endif
}

UInt32 audio_unit_io_node::impl::output_device_channel_count() const
{
#if TARGET_OS_IPHONE
    return static_cast<UInt32>([AVAudioSession sharedInstance].outputNumberOfChannels);
#elif TARGET_OS_MAC
    if (const auto &dev = device()) {
        return dev.output_channel_count();
    }
    return 0;
#endif
}

UInt32 audio_unit_io_node::impl::input_device_channel_count() const
{
#if TARGET_OS_IPHONE
    return static_cast<UInt32>([AVAudioSession sharedInstance].inputNumberOfChannels);
#elif TARGET_OS_MAC
    if (const auto &dev = device()) {
        return dev.input_channel_count();
    }
    return 0;
#endif
}

void audio_unit_io_node::impl::set_channel_map(const channel_map_t &map, const yas::direction dir)
{
    _core->channel_map[yas::to_uint32(dir)] = map;

    if (auto unit = au()) {
        unit.set_channel_map(map, kAudioUnitScope_Output, yas::to_uint32(dir));
    }
}

const channel_map_t &audio_unit_io_node::impl::channel_map(const yas::direction dir) const
{
    return _core->channel_map[yas::to_uint32(dir)];
}

bus_result_t audio_unit_io_node::impl::next_available_output_bus() const
{
    auto result = super_class::next_available_output_bus();
    if (result && *result == 0) {
        return 1;
    }
    return result;
}

bool audio_unit_io_node::impl::is_available_output_bus(const UInt32 bus_idx) const
{
    if (bus_idx == 1) {
        return super_class::is_available_output_bus(0);
    }
    return false;
}

void audio_unit_io_node::impl::update_connections()
{
    super_class::update_connections();

    auto unit = au();

    auto update_channel_map = [](channel_map_t &map, const yas::audio_format &format, const UInt32 dev_ch_count) {
        if (map.size() > 0) {
            if (format) {
                const UInt32 ch_count = format.channel_count();
                if (map.size() != ch_count) {
                    map.resize(ch_count, -1);
                }
                for (auto &value : map) {
                    if (value >= dev_ch_count) {
                        value = -1;
                    }
                }
            }
        }
    };

    const auto output_idx = yas::to_uint32(yas::direction::output);
    auto &output_map = _core->channel_map[output_idx];
    update_channel_map(output_map, input_format(output_idx), output_device_channel_count());

    const auto input_idx = yas::to_uint32(yas::direction::input);
    auto &input_map = _core->channel_map[input_idx];
    update_channel_map(input_map, output_format(input_idx), input_device_channel_count());

    unit.set_channel_map(output_map, kAudioUnitScope_Output, output_idx);
    unit.set_channel_map(input_map, kAudioUnitScope_Output, input_idx);
}

void audio_unit_io_node::impl::prepare_audio_unit()
{
    auto unit = au();
    unit.set_enable_output(true);
    unit.set_enable_input(true);
    unit.set_maximum_frames_per_slice(4096);
}

#pragma mark - aduio_unit_output_node::impl

UInt32 audio_unit_output_node::impl::input_bus_count() const
{
    return 1;
}

UInt32 audio_unit_output_node::impl::output_bus_count() const
{
    return 0;
}

void audio_unit_output_node::impl::prepare_audio_unit()
{
    auto unit = au();
    unit.set_enable_output(true);
    unit.set_enable_input(false);
    unit.set_maximum_frames_per_slice(4096);
}

#pragma mark - aduio_unit_input_node::impl

class audio_unit_input_node::impl::core
{
   public:
    audio_pcm_buffer input_buffer;
    audio_time render_time;
};

audio_unit_input_node::impl::impl()
    : audio_unit_io_node::impl(), _core(std::make_unique<audio_unit_input_node::impl::core>())
{
}

audio_unit_input_node::impl::~impl() = default;

UInt32 audio_unit_input_node::impl::input_bus_count() const
{
    return 0;
}

UInt32 audio_unit_input_node::impl::output_bus_count() const
{
    return 1;
}

void audio_unit_input_node::impl::update_connections()
{
    super_class::update_connections();

    auto unit = au();

    if (auto out_connection = output_connection(1)) {
        unit.attach_input_callback();

        audio_pcm_buffer input_buffer(out_connection.format(), 4096);
        _core->input_buffer = input_buffer;

        unit.set_input_callback([weak_node = weak_node(), input_buffer](render_parameters & render_parameters) mutable {
            auto input_node = weak_node.lock();
            if (input_node && render_parameters.in_number_frames <= input_buffer.frame_capacity()) {
                input_buffer.set_frame_length(render_parameters.in_number_frames);
                render_parameters.io_data = input_buffer.audio_buffer_list();

                if (const auto kernel = input_node.impl_ptr<impl>()->kernel_cast()) {
                    if (const auto connection = kernel->output_connection(1)) {
                        auto format = connection.format();
                        audio_time time(*render_parameters.io_time_stamp, format.sample_rate());
                        input_node.set_render_time_on_render(time);

                        if (auto io_unit = input_node.audio_unit()) {
                            render_parameters.in_bus_number = 1;
                            io_unit.audio_unit_render(render_parameters);
                        }

                        auto destination_node = connection.destination_node();

                        if (auto input_tap_node = destination_node.cast<audio_input_tap_node>()) {
                            input_tap_node.render(input_buffer, 0, time);
                        }
                    }
                }
            }
        });
    } else {
        unit.detach_input_callback();
        unit.set_input_callback(nullptr);
        _core->input_buffer = nullptr;
    }
}

void audio_unit_input_node::impl::prepare_audio_unit()
{
    auto unit = au();
    unit.set_enable_output(false);
    unit.set_enable_input(true);
    unit.set_maximum_frames_per_slice(4096);
}

weak<audio_unit_input_node> audio_unit_input_node::impl::weak_node() const
{
    return node().cast<audio_unit_input_node>();
}
