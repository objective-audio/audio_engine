//
//  yas_audio_unit_io_node_impl.cpp
//

#include "yas_audio_tap_node.h"
#include "yas_audio_time.h"
#include "yas_audio_unit.h"
#include "yas_audio_unit_io_node.h"
#include "yas_audio_unit_node.h"
#include "yas_result.h"

#if TARGET_OS_IPHONE
#import <AVFoundation/AVFoundation.h>
#elif TARGET_OS_MAC
#include "yas_audio_device.h"
#endif

using namespace yas;

namespace yas {
namespace audio {
    static AudioComponentDescription constexpr audio_unit_io_node_acd = {
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

struct audio::unit_io_node::impl::core {
    static uint32_t const channel_map_count = 2;

    audio::unit_node _unit_node;
    channel_map_t _channel_map[2];
    audio::unit_io_node::subject_t _subject;
    audio::unit_node::observer_t _connection_observer;

    core(args &&args)
        : _unit_node(
              {.acd = audio_unit_io_node_acd,
               .node_args = audio::node_args{.input_bus_count = static_cast<uint32_t>(args.enable_input ? 1 : 0),
                                             .output_bus_count = static_cast<uint32_t>(args.enable_output ? 1 : 0),
                                             .override_output_bus_idx = 1}}) {
        _unit_node.set_prepare_audio_unit_handler([args = std::move(args)](audio::unit & unit) {
            unit.set_enable_output(args.enable_input);
            unit.set_enable_input(args.enable_output);
            unit.set_maximum_frames_per_slice(4096);
        });
    }
};

#pragma mark - audio::unit_io_node::impl

audio::unit_io_node::impl::impl() : impl(args{}) {
}

audio::unit_io_node::impl::impl(args &&args) : _core(std::make_unique<core>(std::move(args))) {
}

audio::unit_io_node::impl::~impl() = default;

void audio::unit_io_node::impl::prepare(audio::unit_io_node &node) {
    _core->_connection_observer = unit_node().subject().make_observer(
        audio::unit_node::method::did_update_connections, [weak_node = to_weak(node)](auto const &) {
            if (auto node = weak_node.lock()) {
                node.impl_ptr<impl>()->update_unit_io_connections();
            }
        });
}

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

void audio::unit_io_node::impl::set_device(audio::device const &device) {
    if (!device) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    unit_node().audio_unit().set_current_device(device.audio_device_id());
}

audio::device audio::unit_io_node::impl::device() {
    return device::device_for_id(_core->_unit_node.audio_unit().current_device());
}

#endif

double audio::unit_io_node::impl::device_sample_rate() {
#if TARGET_OS_IPHONE
    return [AVAudioSession sharedInstance].sampleRate;
#elif TARGET_OS_MAC
    if (auto const &dev = device()) {
        return dev.nominal_sample_rate();
    }
    return 0;
#endif
}

uint32_t audio::unit_io_node::impl::output_device_channel_count() {
#if TARGET_OS_IPHONE
    return static_cast<uint32_t>([AVAudioSession sharedInstance].outputNumberOfChannels);
#elif TARGET_OS_MAC
    if (auto const &dev = device()) {
        return dev.output_channel_count();
    }
    return 0;
#endif
}

uint32_t audio::unit_io_node::impl::input_device_channel_count() {
#if TARGET_OS_IPHONE
    return static_cast<uint32_t>([AVAudioSession sharedInstance].inputNumberOfChannels);
#elif TARGET_OS_MAC
    if (auto const &dev = device()) {
        return dev.input_channel_count();
    }
    return 0;
#endif
}

void audio::unit_io_node::impl::set_channel_map(channel_map_t const &map, audio::direction const dir) {
    _core->_channel_map[to_uint32(dir)] = map;

    if (auto unit = unit_node().audio_unit()) {
        unit.set_channel_map(map, kAudioUnitScope_Output, to_uint32(dir));
    }
}

audio::channel_map_t const &audio::unit_io_node::impl::channel_map(audio::direction const dir) {
    return _core->_channel_map[to_uint32(dir)];
}

void audio::unit_io_node::impl::update_unit_io_connections() {
    auto unit = unit_node().audio_unit();

    auto update_channel_map = [](channel_map_t &map, format const &format, uint32_t const dev_ch_count) {
        if (map.size() > 0) {
            if (format) {
                uint32_t const ch_count = format.channel_count();
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

    auto const output_idx = to_uint32(direction::output);
    auto &output_map = _core->_channel_map[output_idx];
    update_channel_map(output_map, unit_node().node().input_format(output_idx), output_device_channel_count());

    auto const input_idx = to_uint32(direction::input);
    auto &input_map = _core->_channel_map[input_idx];
    update_channel_map(input_map, unit_node().node().output_format(input_idx), input_device_channel_count());

    unit.set_channel_map(output_map, kAudioUnitScope_Output, output_idx);
    unit.set_channel_map(input_map, kAudioUnitScope_Output, input_idx);

    if (subject().has_observer()) {
        subject().notify(audio::unit_io_node::method::did_update_connection, cast<audio::unit_io_node>());
    }
}

audio::unit_io_node::subject_t &audio::unit_io_node::impl::subject() {
    return _core->_subject;
}

audio::unit_node &audio::unit_io_node::impl::unit_node() {
    return _core->_unit_node;
}

#pragma mark - aduio_unit_output_node::impl

audio::unit_output_node::impl::impl() : _unit_io_node({.enable_output = false}) {
}

#pragma mark - aduio_unit_input_node::impl

struct audio::unit_input_node::impl::core {
    pcm_buffer input_buffer = nullptr;
    time render_time = nullptr;
    audio::unit_io_node::observer_t _connections_observer;
};

audio::unit_input_node::impl::impl() : _unit_io_node({.enable_input = false}), _core(std::make_unique<core>()) {
}

audio::unit_input_node::impl::~impl() = default;

void audio::unit_input_node::impl::prepare(audio::unit_input_node const &node) {
    _core->_connections_observer = _unit_io_node.subject().make_observer(
        audio::unit_io_node::method::did_update_connection, [weak_node = to_weak(node)](auto const &) {
            if (auto node = weak_node.lock()) {
                node.impl_ptr<impl>()->update_unit_input_connections();
            }
        });
}

void audio::unit_input_node::impl::update_unit_input_connections() {
    auto unit = _unit_io_node.unit_node().audio_unit();

    if (auto out_connection = _unit_io_node.unit_node().node().impl_ptr<audio::node::impl>()->output_connection(1)) {
        unit.attach_input_callback();

        pcm_buffer input_buffer(out_connection.format(), 4096);
        _core->input_buffer = input_buffer;

        auto weak_node = to_weak(cast<unit_input_node>());
        unit.set_input_callback([weak_node, input_buffer](render_parameters &render_parameters) mutable {
            auto input_node = weak_node.lock();
            if (input_node && render_parameters.in_number_frames <= input_buffer.frame_capacity()) {
                input_buffer.set_frame_length(render_parameters.in_number_frames);
                render_parameters.io_data = input_buffer.audio_buffer_list();

                if (auto const kernel =
                        input_node.unit_io_node().unit_node().node().impl_ptr<audio::node::impl>()->kernel_cast()) {
                    if (auto const connection = kernel.output_connection(1)) {
                        auto format = connection.format();
                        time time(*render_parameters.io_time_stamp, format.sample_rate());
                        input_node.unit_io_node().unit_node().node().set_render_time_on_render(time);

                        if (auto io_unit = input_node.unit_io_node().unit_node().audio_unit()) {
                            render_parameters.in_bus_number = 1;
                            io_unit.audio_unit_render(render_parameters);
                        }

                        auto destination_node = connection.destination_node();

                        if (destination_node.is_input_renderable()) {
                            destination_node.render(input_buffer, 0, time);
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
