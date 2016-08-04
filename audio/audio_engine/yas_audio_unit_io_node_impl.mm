//
//  yas_audio_unit_io_node_impl.cpp
//

#include "yas_audio_tap_node.h"
#include "yas_audio_time.h"
#include "yas_audio_unit.h"
#include "yas_audio_unit_io_node.h"
#include "yas_result.h"

#if TARGET_OS_IPHONE
#import <AVFoundation/AVFoundation.h>
#elif TARGET_OS_MAC
#include "yas_audio_device.h"
#endif

using namespace yas;

struct audio::unit_io_node::impl::core {
    static uint32_t const channel_map_count = 2;

    channel_map_t _channel_map[2];
    audio::unit_io_node::subject_t _subject;
    audio::unit_node::observer_t _connection_observer;
};

#pragma mark - audio::unit_io_node::impl

audio::unit_io_node::impl::impl() : impl(1, 1) {
}

#warning todo bus_countはunit_nodeのデフォルト値を使うか、argsでoverride_output_busも渡したい
audio::unit_io_node::impl::impl(uint32_t const input_bus_count, uint32_t const output_bus_count)
    : unit_node::impl(input_bus_count, output_bus_count), _core(std::make_unique<core>()) {
    node().impl_ptr<audio::node::impl>()->override_output_bus(1);
}

audio::unit_io_node::impl::~impl() = default;

void audio::unit_io_node::impl::prepare(audio::unit_io_node &node) {
    _core->_connection_observer = audio::unit_node::impl::subject().make_observer(
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

    au().set_current_device(device.audio_device_id());
}

audio::device audio::unit_io_node::impl::device() const {
    return device::device_for_id(au().current_device());
}

#endif

double audio::unit_io_node::impl::device_sample_rate() const {
#if TARGET_OS_IPHONE
    return [AVAudioSession sharedInstance].sampleRate;
#elif TARGET_OS_MAC
    if (auto const &dev = device()) {
        return dev.nominal_sample_rate();
    }
    return 0;
#endif
}

uint32_t audio::unit_io_node::impl::output_device_channel_count() const {
#if TARGET_OS_IPHONE
    return static_cast<uint32_t>([AVAudioSession sharedInstance].outputNumberOfChannels);
#elif TARGET_OS_MAC
    if (auto const &dev = device()) {
        return dev.output_channel_count();
    }
    return 0;
#endif
}

uint32_t audio::unit_io_node::impl::input_device_channel_count() const {
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

    if (auto unit = au()) {
        unit.set_channel_map(map, kAudioUnitScope_Output, to_uint32(dir));
    }
}

audio::channel_map_t const &audio::unit_io_node::impl::channel_map(audio::direction const dir) const {
    return _core->_channel_map[to_uint32(dir)];
}

void audio::unit_io_node::impl::update_unit_io_connections() {
    auto unit = au();

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
    update_channel_map(output_map, node().input_format(output_idx), output_device_channel_count());

    auto const input_idx = to_uint32(direction::input);
    auto &input_map = _core->_channel_map[input_idx];
    update_channel_map(input_map, node().output_format(input_idx), input_device_channel_count());

    unit.set_channel_map(output_map, kAudioUnitScope_Output, output_idx);
    unit.set_channel_map(input_map, kAudioUnitScope_Output, input_idx);

    if (subject().has_observer()) {
        subject().notify(audio::unit_io_node::method::did_update_connection, cast<audio::unit_io_node>());
    }
}

void audio::unit_io_node::impl::prepare_audio_unit() {
    auto unit = au();
    unit.set_enable_output(true);
    unit.set_enable_input(true);
    unit.set_maximum_frames_per_slice(4096);
}

audio::unit_io_node::subject_t &audio::unit_io_node::impl::subject() {
    return _core->_subject;
}

#pragma mark - aduio_unit_output_node::impl

audio::unit_output_node::impl::impl() : unit_io_node::impl(1, 0) {
}

void audio::unit_output_node::impl::prepare_audio_unit() {
    auto unit = au();
    unit.set_enable_output(true);
    unit.set_enable_input(false);
    unit.set_maximum_frames_per_slice(4096);
}

#pragma mark - aduio_unit_input_node::impl

struct audio::unit_input_node::impl::core {
    pcm_buffer input_buffer = nullptr;
    time render_time = nullptr;
    audio::unit_io_node::observer_t _connections_observer;
};

audio::unit_input_node::impl::impl() : unit_io_node::impl(0, 1), _core(std::make_unique<core>()) {
}

audio::unit_input_node::impl::~impl() = default;

void audio::unit_input_node::impl::prepare(audio::unit_input_node const &node) {
    _core->_connections_observer = audio::unit_io_node::impl::subject().make_observer(
        audio::unit_io_node::method::did_update_connection, [weak_node = to_weak(node)](auto const &) {
            if (auto node = weak_node.lock()) {
                node.impl_ptr<impl>()->update_unit_input_connections();
            }
        });
}

void audio::unit_input_node::impl::update_unit_input_connections() {
    auto unit = au();

    if (auto out_connection = node().impl_ptr<audio::node::impl>()->output_connection(1)) {
        unit.attach_input_callback();

        pcm_buffer input_buffer(out_connection.format(), 4096);
        _core->input_buffer = input_buffer;

        auto weak_node = to_weak(cast<unit_input_node>());
        unit.set_input_callback([weak_node, input_buffer](render_parameters &render_parameters) mutable {
            auto input_node = weak_node.lock();
            if (input_node && render_parameters.in_number_frames <= input_buffer.frame_capacity()) {
                input_buffer.set_frame_length(render_parameters.in_number_frames);
                render_parameters.io_data = input_buffer.audio_buffer_list();

                if (auto const kernel = input_node.node().impl_ptr<audio::node::impl>()->kernel_cast()) {
                    if (auto const connection = kernel.output_connection(1)) {
                        auto format = connection.format();
                        time time(*render_parameters.io_time_stamp, format.sample_rate());
                        input_node.node().set_render_time_on_render(time);

                        if (auto io_unit = input_node.audio_unit()) {
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

void audio::unit_input_node::impl::prepare_audio_unit() {
    auto unit = au();
    unit.set_enable_output(false);
    unit.set_enable_input(true);
    unit.set_maximum_frames_per_slice(4096);
}
