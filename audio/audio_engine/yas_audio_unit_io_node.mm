//
//  yas_audio_unit_io_node.cpp
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

#pragma mark - audio::unit_io_node::impl

struct yas::audio::unit_io_node::impl : base::impl {
    impl() : impl(args{}) {
    }

    impl(args &&args)
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

    ~impl() = default;

    void prepare(audio::unit_io_node &node) {
        _connection_observer = unit_node().subject().make_observer(
            audio::unit_node::method::did_update_connections, [weak_node = to_weak(node)](auto const &) {
                if (auto node = weak_node.lock()) {
                    node.impl_ptr<impl>()->update_unit_io_connections();
                }
            });
    }

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

    void set_device(audio::device const &device) {
        if (!device) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
        }

        unit_node().audio_unit().set_current_device(device.audio_device_id());
    }

    audio::device device() {
        return device::device_for_id(_unit_node.audio_unit().current_device());
    }

#endif

    double device_sample_rate() {
#if TARGET_OS_IPHONE
        return [AVAudioSession sharedInstance].sampleRate;
#elif TARGET_OS_MAC
        if (auto const &dev = device()) {
            return dev.nominal_sample_rate();
        }
        return 0;
#endif
    }

    uint32_t output_device_channel_count() {
#if TARGET_OS_IPHONE
        return static_cast<uint32_t>([AVAudioSession sharedInstance].outputNumberOfChannels);
#elif TARGET_OS_MAC
        if (auto const &dev = device()) {
            return dev.output_channel_count();
        }
        return 0;
#endif
    }

    uint32_t input_device_channel_count() {
#if TARGET_OS_IPHONE
        return static_cast<uint32_t>([AVAudioSession sharedInstance].inputNumberOfChannels);
#elif TARGET_OS_MAC
        if (auto const &dev = device()) {
            return dev.input_channel_count();
        }
        return 0;
#endif
    }

    void set_channel_map(channel_map_t const &map, audio::direction const dir) {
        _channel_map[to_uint32(dir)] = map;

        if (auto unit = unit_node().audio_unit()) {
            unit.set_channel_map(map, kAudioUnitScope_Output, to_uint32(dir));
        }
    }

    audio::channel_map_t const &channel_map(audio::direction const dir) {
        return _channel_map[to_uint32(dir)];
    }

    void update_unit_io_connections() {
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
        auto &output_map = _channel_map[output_idx];
        update_channel_map(output_map, unit_node().node().input_format(output_idx), output_device_channel_count());

        auto const input_idx = to_uint32(direction::input);
        auto &input_map = _channel_map[input_idx];
        update_channel_map(input_map, unit_node().node().output_format(input_idx), input_device_channel_count());

        unit.set_channel_map(output_map, kAudioUnitScope_Output, output_idx);
        unit.set_channel_map(input_map, kAudioUnitScope_Output, input_idx);

        subject().notify(audio::unit_io_node::method::did_update_connection, cast<audio::unit_io_node>());
    }

    audio::unit_io_node::subject_t &subject() {
        return _subject;
    }

    audio::unit_node &unit_node() {
        return _unit_node;
    }

    audio::unit_node _unit_node;
    channel_map_t _channel_map[2];
    audio::unit_io_node::subject_t _subject;
    audio::unit_node::observer_t _connection_observer;
};

#pragma mark - audio::unit_io_node

audio::unit_io_node::unit_io_node(std::nullptr_t) : base(nullptr) {
}

audio::unit_io_node::unit_io_node() : unit_io_node(args{}) {
}

audio::unit_io_node::unit_io_node(args args) : base(std::make_shared<impl>(std::move(args))) {
    impl_ptr<impl>()->prepare(*this);
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

audio::unit_io_node::subject_t &audio::unit_io_node::subject() {
    return impl_ptr<impl>()->subject();
}

audio::unit_node const &audio::unit_io_node::unit_node() const {
    return impl_ptr<impl>()->unit_node();
}

audio::unit_node &audio::unit_io_node::unit_node() {
    return impl_ptr<impl>()->unit_node();
}

#pragma mark - audio::unit_output_node::impl

struct yas::audio::unit_output_node::impl : base::impl {
    impl() : _unit_io_node({.enable_output = false}) {
    }

    audio::unit_io_node _unit_io_node;
};

#pragma mark - audio::unit_output_node

audio::unit_output_node::unit_output_node(std::nullptr_t) : base(nullptr) {
}

audio::unit_output_node::unit_output_node() : base(std::make_unique<impl>()) {
}

audio::unit_output_node::~unit_output_node() = default;

void audio::unit_output_node::set_channel_map(channel_map_t const &map) {
    unit_io_node().set_channel_map(map, direction::output);
}

audio::channel_map_t const &audio::unit_output_node::channel_map() const {
    return unit_io_node().channel_map(direction::output);
}

audio::unit_io_node const &audio::unit_output_node::unit_io_node() const {
    return impl_ptr<impl>()->_unit_io_node;
}

audio::unit_io_node &audio::unit_output_node::unit_io_node() {
    return impl_ptr<impl>()->_unit_io_node;
}

#pragma mark - audio::unit_input_node::impl

struct yas::audio::unit_input_node::impl : base::impl {
    impl() : _unit_io_node({.enable_input = false}) {
    }

    ~impl() = default;

    void prepare(audio::unit_input_node const &node) {
        _connections_observer = _unit_io_node.subject().make_observer(
            audio::unit_io_node::method::did_update_connection, [weak_node = to_weak(node)](auto const &) {
                if (auto node = weak_node.lock()) {
                    node.impl_ptr<impl>()->update_unit_input_connections();
                }
            });
    }

    void update_unit_input_connections() {
        auto unit = _unit_io_node.unit_node().audio_unit();

        if (auto out_connection = _unit_io_node.unit_node().node().output_connection(1)) {
            unit.attach_input_callback();

            pcm_buffer input_buffer(out_connection.format(), 4096);
            _input_buffer = input_buffer;

            auto weak_node = to_weak(cast<unit_input_node>());
            unit.set_input_handler([weak_node, input_buffer](render_parameters &render_parameters) mutable {
                auto input_node = weak_node.lock();
                if (input_node && render_parameters.in_number_frames <= input_buffer.frame_capacity()) {
                    input_buffer.set_frame_length(render_parameters.in_number_frames);
                    render_parameters.io_data = input_buffer.audio_buffer_list();

                    if (auto const kernel = input_node.unit_io_node().unit_node().node().kernel()) {
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
                                destination_node.render({.buffer = input_buffer, .bus_idx = 0, .when = time});
                            }
                        }
                    }
                }
            });
        } else {
            unit.detach_input_callback();
            unit.set_input_handler(nullptr);
            _input_buffer = nullptr;
        }
    }

    audio::unit_io_node _unit_io_node;

    pcm_buffer _input_buffer = nullptr;
    audio::unit_io_node::observer_t _connections_observer;
};

#pragma mark - audio::unit_input_node

audio::unit_input_node::unit_input_node(std::nullptr_t) : base(nullptr) {
}

audio::unit_input_node::unit_input_node() : base(std::make_unique<impl>()) {
    impl_ptr<impl>()->prepare(*this);
}

audio::unit_input_node::~unit_input_node() = default;

void audio::unit_input_node::set_channel_map(channel_map_t const &map) {
    unit_io_node().set_channel_map(map, direction::input);
}

audio::channel_map_t const &audio::unit_input_node::channel_map() const {
    return unit_io_node().channel_map(direction::input);
}

audio::unit_io_node const &audio::unit_input_node::unit_io_node() const {
    return impl_ptr<impl>()->_unit_io_node;
}

audio::unit_io_node &audio::unit_input_node::unit_io_node() {
    return impl_ptr<impl>()->_unit_io_node;
}
