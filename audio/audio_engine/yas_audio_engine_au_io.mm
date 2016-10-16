//
//  yas_audio_au_io.cpp
//

#include "yas_audio_engine_tap.h"
#include "yas_audio_time.h"
#include "yas_audio_unit.h"
#include "yas_audio_engine_au_io.h"
#include "yas_audio_engine_au.h"
#include "yas_result.h"

#if TARGET_OS_IPHONE
#import <AVFoundation/AVFoundation.h>
#elif TARGET_OS_MAC
#include "yas_audio_device.h"
#endif

using namespace yas;

namespace yas {
namespace audio {
    static AudioComponentDescription constexpr audio_au_io_acd = {
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

#pragma mark - audio::engine::au_io::impl

struct yas::audio::engine::au_io::impl : base::impl {
    impl() : impl(args{}) {
    }

    impl(args &&args)
        : _au(
              {.acd = audio_au_io_acd,
               .node_args = audio::engine::node_args{.input_bus_count = static_cast<uint32_t>(args.enable_input ? 1 : 0),
                                             .output_bus_count = static_cast<uint32_t>(args.enable_output ? 1 : 0),
                                             .override_output_bus_idx = 1}}) {
        _au.set_prepare_unit_handler([args = std::move(args)](audio::unit & unit) {
            unit.set_enable_output(args.enable_input);
            unit.set_enable_input(args.enable_output);
            unit.set_maximum_frames_per_slice(4096);
        });
    }

    ~impl() = default;

    void prepare(audio::engine::au_io &au_io) {
        _connection_observer = au().subject().make_observer(
            audio::engine::au::method::did_update_connections, [weak_au_io = to_weak(au_io)](auto const &) {
                if (auto au_io = weak_au_io.lock()) {
                    au_io.impl_ptr<impl>()->update_unit_io_connections();
                }
            });
    }

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

    void set_device(audio::device const &device) {
        if (!device) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
        }

        au().unit().set_current_device(device.audio_device_id());
    }

    audio::device device() {
        return device::device_for_id(_au.unit().current_device());
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

        if (auto unit = au().unit()) {
            unit.set_channel_map(map, kAudioUnitScope_Output, to_uint32(dir));
        }
    }

    audio::channel_map_t const &channel_map(audio::direction const dir) {
        return _channel_map[to_uint32(dir)];
    }

    void update_unit_io_connections() {
        auto unit = au().unit();

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
        update_channel_map(output_map, au().node().input_format(output_idx), output_device_channel_count());

        auto const input_idx = to_uint32(direction::input);
        auto &input_map = _channel_map[input_idx];
        update_channel_map(input_map, au().node().output_format(input_idx), input_device_channel_count());

        unit.set_channel_map(output_map, kAudioUnitScope_Output, output_idx);
        unit.set_channel_map(input_map, kAudioUnitScope_Output, input_idx);

        subject().notify(audio::engine::au_io::method::did_update_connection, cast<audio::engine::au_io>());
    }

    audio::engine::au_io::subject_t &subject() {
        return _subject;
    }

    audio::engine::au &au() {
        return _au;
    }

    audio::engine::au _au;
    channel_map_t _channel_map[2];
    audio::engine::au_io::subject_t _subject;
    audio::engine::au::observer_t _connection_observer;
};

#pragma mark - audio::engine::au_io

audio::engine::au_io::au_io(std::nullptr_t) : base(nullptr) {
}

audio::engine::au_io::au_io() : au_io(args{}) {
}

audio::engine::au_io::au_io(args args) : base(std::make_shared<impl>(std::move(args))) {
    impl_ptr<impl>()->prepare(*this);
}

audio::engine::au_io::~au_io() = default;

void audio::engine::au_io::set_channel_map(channel_map_t const &map, direction const dir) {
    impl_ptr<impl>()->set_channel_map(map, dir);
}

audio::channel_map_t const &audio::engine::au_io::channel_map(direction const dir) const {
    return impl_ptr<impl>()->channel_map(dir);
}

double audio::engine::au_io::device_sample_rate() const {
    return impl_ptr<impl>()->device_sample_rate();
}

uint32_t audio::engine::au_io::output_device_channel_count() const {
    return impl_ptr<impl>()->output_device_channel_count();
}

uint32_t audio::engine::au_io::input_device_channel_count() const {
    return impl_ptr<impl>()->input_device_channel_count();
}

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

void audio::engine::au_io::set_device(audio::device const &device) {
    impl_ptr<impl>()->set_device(device);
}

audio::device audio::engine::au_io::device() const {
    return impl_ptr<impl>()->device();
}

#endif

audio::engine::au_io::subject_t &audio::engine::au_io::subject() {
    return impl_ptr<impl>()->subject();
}

audio::engine::au const &audio::engine::au_io::au() const {
    return impl_ptr<impl>()->au();
}

audio::engine::au &audio::engine::au_io::au() {
    return impl_ptr<impl>()->au();
}

#pragma mark - audio::engine::au_output::impl

struct yas::audio::engine::au_output::impl : base::impl {
    impl() : _au_io({.enable_output = false}) {
    }

    audio::engine::au_io _au_io;
};

#pragma mark - audio::engine::au_output

audio::engine::au_output::au_output(std::nullptr_t) : base(nullptr) {
}

audio::engine::au_output::au_output() : base(std::make_unique<impl>()) {
}

audio::engine::au_output::~au_output() = default;

void audio::engine::au_output::set_channel_map(channel_map_t const &map) {
    au_io().set_channel_map(map, direction::output);
}

audio::channel_map_t const &audio::engine::au_output::channel_map() const {
    return au_io().channel_map(direction::output);
}

audio::engine::au_io const &audio::engine::au_output::au_io() const {
    return impl_ptr<impl>()->_au_io;
}

audio::engine::au_io &audio::engine::au_output::au_io() {
    return impl_ptr<impl>()->_au_io;
}

#pragma mark - audio::engine::au_input::impl

struct yas::audio::engine::au_input::impl : base::impl {
    impl() : _au_io({.enable_input = false}) {
    }

    ~impl() = default;

    void prepare(audio::engine::au_input const &au_input) {
        _connections_observer = _au_io.subject().make_observer(
            audio::engine::au_io::method::did_update_connection, [weak_au_input = to_weak(au_input)](auto const &) {
                if (auto au_input = weak_au_input.lock()) {
                    au_input.impl_ptr<impl>()->update_unit_input_connections();
                }
            });
    }

    void update_unit_input_connections() {
        auto unit = _au_io.au().unit();

        if (auto out_connection = _au_io.au().node().output_connection(1)) {
            unit.attach_input_callback();

            pcm_buffer input_buffer(out_connection.format(), 4096);
            _input_buffer = input_buffer;

            auto weak_au_input = to_weak(cast<au_input>());
            unit.set_input_handler([weak_au_input, input_buffer](render_parameters &render_parameters) mutable {
                auto au_input = weak_au_input.lock();
                if (au_input && render_parameters.in_number_frames <= input_buffer.frame_capacity()) {
                    input_buffer.set_frame_length(render_parameters.in_number_frames);
                    render_parameters.io_data = input_buffer.audio_buffer_list();

                    if (auto const kernel = au_input.au_io().au().node().kernel()) {
                        if (auto const connection = kernel.output_connection(1)) {
                            auto format = connection.format();
                            time time(*render_parameters.io_time_stamp, format.sample_rate());
                            au_input.au_io().au().node().set_render_time_on_render(time);

                            if (auto io_unit = au_input.au_io().au().unit()) {
                                render_parameters.in_bus_number = 1;
                                io_unit.raw_unit_render(render_parameters);
                            }

                            auto dst_node = connection.destination_node();

                            if (dst_node.is_input_renderable()) {
                                dst_node.render({.buffer = input_buffer, .bus_idx = 0, .when = time});
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

    audio::engine::au_io _au_io;

    pcm_buffer _input_buffer = nullptr;
    audio::engine::au_io::observer_t _connections_observer;
};

#pragma mark - audio::engine::au_input

audio::engine::au_input::au_input(std::nullptr_t) : base(nullptr) {
}

audio::engine::au_input::au_input() : base(std::make_unique<impl>()) {
    impl_ptr<impl>()->prepare(*this);
}

audio::engine::au_input::~au_input() = default;

void audio::engine::au_input::set_channel_map(channel_map_t const &map) {
    au_io().set_channel_map(map, direction::input);
}

audio::channel_map_t const &audio::engine::au_input::channel_map() const {
    return au_io().channel_map(direction::input);
}

audio::engine::au_io const &audio::engine::au_input::au_io() const {
    return impl_ptr<impl>()->_au_io;
}

audio::engine::au_io &audio::engine::au_input::au_io() {
    return impl_ptr<impl>()->_au_io;
}
