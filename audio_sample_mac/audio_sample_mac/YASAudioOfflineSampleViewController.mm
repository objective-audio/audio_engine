//
//  YASAudioOfflineSampleViewController.m
//

#import "YASAudioOfflineSampleViewController.h"
#import <Accelerate/Accelerate.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <cpp_utils/yas_objc_ptr.h>
#import <cpp_utils/yas_thread.h>
#import <cpp_utils/yas_url.h>
#import <objc_utils/yas_objc_unowned.h>
#import <audio/yas_audio_umbrella.hpp>
#import <iostream>

using namespace yas;

namespace yas::offline_sample {
static double constexpr sample_rate = 44100.0;
}

namespace yas::offline_sample {
class sine;
using sine_ptr = std::shared_ptr<sine>;

struct sine {
    virtual ~sine() = default;

    void set_frequency(float const frequency) {
        this->_render_context->frequency = frequency;
    }

    float frequency() const {
        return this->_render_context->frequency;
    }

    void set_playing(bool const playing) {
        this->_render_context->playing = playing;
    }

    bool is_playing() const {
        return this->_render_context->playing;
    }

    audio::graph_tap &tap() {
        return *this->_tap;
    }

   private:
    struct render_context {
        std::atomic<float> frequency = 1000;
        std::atomic<bool> playing;

        double phase_on_render;
    };

    audio::graph_tap_ptr const _tap = audio::graph_tap::make_shared();

    std::shared_ptr<render_context> const _render_context = std::make_shared<render_context>();

    sine() {
        auto render_handler = [context = this->_render_context](audio::node_render_args const &args) {
            auto &buffer = args.buffer;

            buffer->clear();

            if (context->playing) {
                double const start_phase = context->phase_on_render;
                double const phase_per_frame = context->frequency / sample_rate * audio::math::two_pi;
                double next_phase = start_phase;
                uint32_t const frame_length = buffer->frame_length();

                if (frame_length > 0) {
                    auto each = audio::make_each_data<float>(*buffer);
                    while (yas_each_data_next_ch(each)) {
                        next_phase =
                            audio::math::fill_sine(yas_each_data_ptr(each), frame_length, start_phase, phase_per_frame);
                    }
                    context->phase_on_render = next_phase;
                }
            }
        };

        this->tap().set_render_handler(render_handler);
    }

   public:
    static sine_ptr make_shared() {
        return sine_ptr(new sine{});
    }
};
}

@interface YASAudioOfflineSampleViewController ()

@property (nonatomic, assign) float volume;
@property (nonatomic, assign) float frequency;
@property (nonatomic, assign) float length;

@property (nonatomic, assign) BOOL playing;
@property (nonatomic, assign, getter=isProcessing) BOOL processing;

@end

namespace yas::sample {
struct offline_vc_internal {
    audio::graph_ptr play_graph = audio::graph::make_shared();
    audio::graph_avf_au_mixer_ptr play_au_mixer = audio::graph_avf_au_mixer::make_shared();
    offline_sample::sine_ptr play_sine = offline_sample::sine::make_shared();

    audio::graph_ptr offline_graph = audio::graph::make_shared();
    audio::graph_avf_au_mixer_ptr offline_au_mixer = audio::graph_avf_au_mixer::make_shared();
    offline_sample::sine_ptr offline_sine = offline_sample::sine::make_shared();

    audio::format const file_format{{.sample_rate = offline_sample::sample_rate,
                                     .channel_count = 2,
                                     .pcm_format = audio::pcm_format::float32,
                                     .interleaved = false}};

    offline_vc_internal() {
        auto const &io = this->play_graph->add_io(audio::mac_device::renewable_default_output_device());

        this->play_au_mixer->raw_au->node->reset();
        this->play_au_mixer->set_input_pan(0.0f, 0);
        this->play_au_mixer->set_input_enabled(true, 0);
        this->play_au_mixer->set_output_volume(1.0f, 0);
        this->play_au_mixer->set_output_pan(0.0f, 0);

        this->_io_canceller = io->raw_io()
                                  ->observe_device([this](auto const &pair) {
                                      switch (pair.first) {
                                          case audio::io::device_method::updated:
                                              this->_update_connection();
                                              break;
                                          case audio::io::device_method::changed:
                                          case audio::io::device_method::initial:
                                              break;
                                      }
                                  })
                                  .end();

        this->offline_au_mixer->raw_au->node->reset();
        this->offline_au_mixer->set_input_pan(0.0f, 0);
        this->offline_au_mixer->set_input_enabled(true, 0);
        this->offline_au_mixer->set_output_volume(1.0f, 0);
        this->offline_au_mixer->set_output_pan(0.0f, 0);

        this->offline_graph->connect(this->offline_sine->tap().node, this->offline_au_mixer->raw_au->node,
                                     this->file_format);
    }

    void start_render() {
        auto const &io = this->play_graph->io();
        if (!io) {
            return;
        }

        auto const &io_value = io.value();
        auto const output_format = io_value->raw_io()->device().value()->output_format();

        if (!output_format.has_value()) {
            return;
        }

        this->play_graph->connect(this->play_au_mixer->raw_au->node, io_value->output_node, *output_format);
        this->play_graph->connect(this->play_sine->tap().node, this->play_au_mixer->raw_au->node, this->file_format);

        if (!this->play_graph->start_render()) {
            NSLog(@"%s error", __PRETTY_FUNCTION__);
        }
    }

    void stop_render() {
        this->play_graph->stop();
        this->play_graph->disconnect(this->play_au_mixer->raw_au->node);
    }

   private:
    observing::cancellable_ptr _io_canceller = nullptr;

    void _update_connection() {
        if (auto const &io = this->play_graph->io()) {
            auto const &io_value = io.value();
            if (auto const output_format = io_value->raw_io()->device().value()->output_format()) {
                this->play_graph->disconnect(io_value->output_node);

                this->play_graph->connect(this->play_au_mixer->raw_au->node, io_value->output_node, *output_format);
            }
        }
    }
};
}

@implementation YASAudioOfflineSampleViewController {
    std::optional<std::shared_ptr<sample::offline_vc_internal>> _internal;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewDidAppear {
    [super viewDidAppear];

    self->_internal = std::make_shared<sample::offline_vc_internal>();

    self.volume = 0.1;
    self.frequency = 1000.0;
    self.length = 1.0;
    self.playing = NO;

    self->_internal.value()->start_render();
}

- (void)viewWillDisappear {
    [super viewWillDisappear];

    self->_internal.value()->stop_render();
    self->_internal = std::nullopt;
}

- (void)setVolume:(float)volume {
    self->_internal.value()->play_au_mixer->set_input_volume(volume, 0);
}

- (float)volume {
    if (_internal) {
        return self->_internal.value()->play_au_mixer->input_volume(0);
    }
    return 0.0;
}

- (void)setFrequency:(float)frequency {
    self->_internal.value()->play_sine->set_frequency(frequency);
}

- (float)frequency {
    if (_internal) {
        return self->_internal.value()->play_sine->frequency();
    }
    return 0.0;
}

- (void)setPlaying:(BOOL)playing {
    self->_internal.value()->play_sine->set_playing(playing);
}

- (BOOL)playing {
    if (_internal) {
        return self->_internal.value()->play_sine->is_playing();
    }
    return NO;
}

- (IBAction)playButtonTapped:(id)sender {
    self.playing = YES;
}

- (IBAction)stopButtonTapped:(id)sender {
    self.playing = NO;
}

- (IBAction)exportButtonTapped:(id)sender {
    if (self.processing) {
        return;
    }

    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.allowedContentTypes = @[UTTypeAudio];
    panel.extensionHidden = NO;
    if ([panel runModal] == NSModalResponseOK) {
        [self startOfflineFileWritingWithURL:panel.URL];
    }
}

- (void)startOfflineFileWritingWithURL:(NSURL *)url {
    auto wave_settings = audio::wave_file_settings(offline_sample::sample_rate, 2, 16);
    auto file_writer = audio::file::make_shared();
    auto create_result = file_writer->create({.file_path = to_string((__bridge CFStringRef)url.path),
                                              .file_type = audio::file_type::wave,
                                              .settings = wave_settings});

    if (!create_result) {
        std::cout << __PRETTY_FUNCTION__ << " - error:" << to_string(create_result.error()) << std::endl;
        return;
    }

    self->_internal.value()->offline_sine->set_frequency(_internal.value()->play_sine->frequency());
    self->_internal.value()->offline_sine->set_playing(true);
    self->_internal.value()->offline_au_mixer->set_input_volume(self.volume, 0);

    self.processing = YES;

    auto const remain = std::make_shared<uint32_t>(self.length * offline_sample::sample_rate);

    auto unowned_self =
        objc_ptr_with_move_object([[YASUnownedObject<YASAudioOfflineSampleViewController *> alloc] init]);
    [unowned_self.object() setObject:self];
    auto &internal = self->_internal.value();

    auto const &offline_graph = internal->offline_graph;

    auto const device = audio::offline_device::make_shared(
        internal->file_format,
        [remain, file_writer = std::move(file_writer)](auto args) mutable {
            auto &buffer = args.output_buffer;

            auto format = audio::format(buffer->format().stream_description());
            audio::pcm_buffer pcm_buffer(format, buffer->audio_buffer_list());
            pcm_buffer.set_frame_length(buffer->frame_length());

            uint32_t const frame_length = MIN(*remain, pcm_buffer.frame_length());
            if (frame_length > 0) {
                pcm_buffer.set_frame_length(frame_length);
                auto write_result = file_writer->write_from_buffer(pcm_buffer);
                if (!write_result) {
                    std::cout << __PRETTY_FUNCTION__ << " - error:" << to_string(write_result.error()) << std::endl;
                }
            }

            *remain -= frame_length;
            if (*remain == 0) {
                file_writer->close();
                return audio::continuation::abort;
            }

            return audio::continuation::keep;
        },
        [unowned_self, weak_internal = to_weak(internal)](bool const cancelled) {
            if (auto const internal = weak_internal.lock()) {
                internal->offline_graph->remove_io();
            }
            [unowned_self.object() object].processing = NO;
        });

    auto const &offline_io = offline_graph->add_io(device);

    offline_graph->connect(internal->offline_au_mixer->raw_au->node, offline_io->output_node, internal->file_format);

    auto start_result = offline_graph->start_render();

    if (!start_result) {
        self.processing = NO;
        NSLog(@"%s start offline render error %@", __PRETTY_FUNCTION__, to_cf_object(to_string(start_result.error())));
    }
}

@end
