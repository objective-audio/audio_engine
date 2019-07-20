//
//  yas_audio_au_io.cpp
//

#include "yas_audio_engine_au_io.h"
#include <cpp_utils/yas_result.h>
#include "yas_audio_engine_au.h"
#include "yas_audio_engine_tap.h"
#include "yas_audio_time.h"
#include "yas_audio_unit.h"

#if TARGET_OS_IPHONE
#import <AVFoundation/AVFoundation.h>
#elif TARGET_OS_MAC
#include "yas_audio_device.h"
#endif

using namespace yas;

namespace yas::audio {
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

#pragma mark - audio::engine::au_io

audio::engine::au_io::au_io(args args)
    : _au(make_au(
          {.acd = audio_au_io_acd,
           .node_args = audio::engine::node_args{.input_bus_count = static_cast<uint32_t>(args.enable_input ? 1 : 0),
                                                 .output_bus_count = static_cast<uint32_t>(args.enable_output ? 1 : 0),
                                                 .override_output_bus_idx = 1}})) {
    this->_au->set_prepare_unit_handler([args = std::move(args)](audio::unit &unit) {
        unit.set_enable_output(args.enable_input);
        unit.set_enable_input(args.enable_output);
        unit.set_maximum_frames_per_slice(4096);
    });
}

audio::engine::au_io::~au_io() = default;

void audio::engine::au_io::set_channel_map(channel_map_t const &map, direction const dir) {
    this->_channel_map[to_uint32(dir)] = map;

    if (auto unit = _au->unit()) {
        unit->set_channel_map(map, kAudioUnitScope_Output, to_uint32(dir));
    }
}

audio::channel_map_t const &audio::engine::au_io::channel_map(direction const dir) const {
    return this->_channel_map[to_uint32(dir)];
}

double audio::engine::au_io::device_sample_rate() const {
#if TARGET_OS_IPHONE
    return [AVAudioSession sharedInstance].sampleRate;
#elif TARGET_OS_MAC
    if (auto const &dev = device()) {
        return dev->nominal_sample_rate();
    }
    return 0;
#endif
}

uint32_t audio::engine::au_io::output_device_channel_count() const {
#if TARGET_OS_IPHONE
    return static_cast<uint32_t>([AVAudioSession sharedInstance].outputNumberOfChannels);
#elif TARGET_OS_MAC
    if (auto const &dev = device()) {
        return dev->output_channel_count();
    }
    return 0;
#endif
}

uint32_t audio::engine::au_io::input_device_channel_count() const {
#if TARGET_OS_IPHONE
    return static_cast<uint32_t>([AVAudioSession sharedInstance].inputNumberOfChannels);
#elif TARGET_OS_MAC
    if (auto const &dev = device()) {
        return dev->input_channel_count();
    }
    return 0;
#endif
}

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

void audio::engine::au_io::set_device(audio::device const &device) {
    this->_au->unit()->set_current_device(device.audio_device_id());
}

std::shared_ptr<audio::device> audio::engine::au_io::device() const {
    return device::device_for_id(this->_au->unit()->current_device());
}

#endif

chaining::chain_unsync_t<audio::engine::au_io::chaining_pair_t> audio::engine::au_io::chain() const {
    return this->_notifier.chain();
}

chaining::chain_relayed_unsync_t<std::shared_ptr<audio::engine::au_io>, audio::engine::au_io::chaining_pair_t>
audio::engine::au_io::chain(method const method) const {
    return this->_notifier.chain()
        .guard([method](auto const &pair) { return pair.first == method; })
        .to([](chaining_pair_t const &pair) { return pair.second; });
}

audio::engine::au const &audio::engine::au_io::au() const {
    return *this->_au;
}

audio::engine::au &audio::engine::au_io::au() {
    return *this->_au;
}

void audio::engine::au_io::prepare() {
    this->_connections_observer = this->_au->chain(au::method::did_update_connections)
                                      .perform([weak_au_io = to_weak(shared_from_this())](auto const &) {
                                          if (auto au_io = weak_au_io.lock()) {
                                              au_io->update_unit_io_connections();
                                          }
                                      })
                                      .end();
}

void audio::engine::au_io::update_unit_io_connections() {
    auto unit = this->_au->unit();

    auto update_channel_map = [](channel_map_t &map, std::optional<format> const &format, uint32_t const dev_ch_count) {
        if (map.size() > 0) {
            if (format) {
                uint32_t const ch_count = format->channel_count();
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
    auto &output_map = this->_channel_map[output_idx];
    update_channel_map(output_map, _au->node().input_format(output_idx), this->output_device_channel_count());

    auto const input_idx = to_uint32(direction::input);
    auto &input_map = this->_channel_map[input_idx];
    update_channel_map(input_map, this->_au->node().output_format(input_idx), this->input_device_channel_count());

    unit->set_channel_map(output_map, kAudioUnitScope_Output, output_idx);
    unit->set_channel_map(input_map, kAudioUnitScope_Output, input_idx);

    this->_notifier.notify(std::make_pair(au_io::method::did_update_connection, shared_from_this()));
}

namespace yas::audio::engine {
struct au_io_factory : au_io {
    au_io_factory(au_io::args &&args) : au_io(std::move(args)) {
    }

    void prepare() {
        this->au_io::prepare();
    }
};
}

std::shared_ptr<audio::engine::au_io> audio::engine::make_au_io() {
    return make_au_io(au_io::args{});
}

std::shared_ptr<audio::engine::au_io> audio::engine::make_au_io(au_io::args args) {
    auto shared = std::make_shared<au_io_factory>(std::move(args));
    shared->prepare();
    return shared;
}

#pragma mark - audio::engine::au_output

audio::engine::au_output::au_output() : _au_io(make_au_io({.enable_output = false})) {
}

void audio::engine::au_output::set_channel_map(channel_map_t const &map) {
    this->_au_io->set_channel_map(map, direction::output);
}

audio::channel_map_t const &audio::engine::au_output::channel_map() const {
    return this->_au_io->channel_map(direction::output);
}

audio::engine::au_io const &audio::engine::au_output::au_io() const {
    return *this->_au_io;
}

audio::engine::au_io &audio::engine::au_output::au_io() {
    return *this->_au_io;
}

namespace yas::audio::engine {
struct au_output_factory : au_output {};
}

std::shared_ptr<audio::engine::au_output> audio::engine::make_au_output() {
    return std::make_shared<au_output_factory>();
}

#pragma mark - audio::engine::au_input

audio::engine::au_input::au_input() : _au_io(make_au_io({.enable_input = false})) {
}

void audio::engine::au_input::set_channel_map(channel_map_t const &map) {
    this->_au_io->set_channel_map(map, direction::input);
}

audio::channel_map_t const &audio::engine::au_input::channel_map() const {
    return this->_au_io->channel_map(direction::input);
}

audio::engine::au_io const &audio::engine::au_input::au_io() const {
    return *this->_au_io;
}

audio::engine::au_io &audio::engine::au_input::au_io() {
    return *this->_au_io;
}

void audio::engine::au_input::prepare() {
    this->_connections_observer = this->_au_io->chain(au_io::method::did_update_connection)
                                      .perform([weak_au_input = to_weak(shared_from_this())](auto const &) {
                                          if (auto au_input = weak_au_input.lock()) {
                                              au_input->update_unit_input_connections();
                                          }
                                      })
                                      .end();
}

void audio::engine::au_input::update_unit_input_connections() {
    auto unit = this->_au_io->au().unit();

    if (auto out_connection = _au_io->au().node().output_connection(1)) {
        unit->attach_input_callback();

        this->_input_buffer = std::make_shared<pcm_buffer>(out_connection->format, 4096);

        auto weak_au_input = to_weak(shared_from_this());
        unit->set_input_handler(
            [weak_au_input, input_buffer = this->_input_buffer](render_parameters &render_parameters) mutable {
                auto au_input = weak_au_input.lock();
                if (au_input && render_parameters.in_number_frames <= input_buffer->frame_capacity()) {
                    input_buffer->set_frame_length(render_parameters.in_number_frames);
                    render_parameters.io_data = input_buffer->audio_buffer_list();

                    if (auto const kernel = au_input->au_io().au().node().kernel()) {
                        if (auto const connection = kernel->output_connection(1)) {
                            auto format = connection->format;
                            time time(*render_parameters.io_time_stamp, format.sample_rate());
                            au_input->au_io().au().node().set_render_time_on_render(time);

                            if (auto io_unit = au_input->au_io().au().unit()) {
                                render_parameters.in_bus_number = 1;
                                io_unit->raw_unit_render(render_parameters);
                            }

                            auto dst_node = connection->destination_node();

                            if (dst_node->is_input_renderable()) {
                                dst_node->render({.buffer = *input_buffer, .bus_idx = 0, .when = time});
                            }
                        }
                    }
                }
            });
    } else {
        unit->detach_input_callback();
        unit->set_input_handler(nullptr);
        this->_input_buffer = nullptr;
    }
}

namespace yas::audio::engine {
struct au_input_factory : au_input {
    void prepare() {
        this->au_input::prepare();
    }
};
}

std::shared_ptr<audio::engine::au_input> audio::engine::make_au_input() {
    auto shared = std::make_shared<au_input_factory>();
    shared->prepare();
    return shared;
}
