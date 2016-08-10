//
//  YASAudioOfflineSampleViewController.m
//

#import <Accelerate/Accelerate.h>
#import <iostream>
#import "YASAudioOfflineSampleViewController.h"
#import "yas_audio.h"
#import "yas_objc_unowned.h"

using namespace yas;

namespace yas {
namespace offline_sample {
    static double constexpr sample_rate = 44100.0;

    struct sine_node : base {
        struct impl : base::impl {
            audio::tap_node _tap_node;
            double phase_on_render;

            void set_frequency(float const frequency) {
                std::lock_guard<std::recursive_mutex> lock(_mutex);
                _frequency = frequency;
            }

            float frequency() const {
                std::lock_guard<std::recursive_mutex> lock(_mutex);
                return _frequency;
            }

            void set_playing(const bool playing) {
                std::lock_guard<std::recursive_mutex> lock(_mutex);
                _playing = playing;
            }

            bool is_playing() const {
                std::lock_guard<std::recursive_mutex> lock(_mutex);
                return _playing;
            }

           private:
            float _frequency;
            bool _playing;
            mutable std::recursive_mutex _mutex;
        };

        sine_node() : base(std::make_unique<impl>()) {
            set_frequency(1000.0);

            auto weak_node = to_weak(*this);

            auto render_handler = [weak_node](auto args) {
                auto &buffer = args.buffer;

                buffer.clear();

                if (auto node = weak_node.lock()) {
                    if (node.is_playing()) {
                        double const start_phase = node.impl_ptr<impl>()->phase_on_render;
                        double const phase_per_frame = node.frequency() / sample_rate * audio::math::two_pi;
                        double next_phase = start_phase;
                        uint32_t const frame_length = buffer.frame_length();

                        if (frame_length > 0) {
                            audio::frame_enumerator enumerator(buffer);
                            auto const *flex_ptr = enumerator.pointer();
                            while (flex_ptr->v) {
                                next_phase =
                                    audio::math::fill_sine(flex_ptr->f32, frame_length, start_phase, phase_per_frame);
                                yas_audio_frame_enumerator_move_channel(enumerator);
                            }

                            node.impl_ptr<impl>()->phase_on_render = next_phase;
                        }
                    }
                }
            };

            tap_node().set_render_handler(render_handler);
        }

        sine_node(std::nullptr_t) : base(nullptr) {
        }

        virtual ~sine_node() = default;

        void set_frequency(float const frequency) {
            impl_ptr<impl>()->set_frequency(frequency);
        }

        float frequency() const {
            return impl_ptr<impl>()->frequency();
        }

        void set_playing(const bool playing) {
            impl_ptr<impl>()->set_playing(playing);
        }

        bool is_playing() const {
            return impl_ptr<impl>()->is_playing();
        }

        audio::tap_node &tap_node() {
            return impl_ptr<impl>()->_tap_node;
        }
    };
}
}

@interface YASAudioOfflineSampleViewController ()

@property (nonatomic, assign) float volume;
@property (nonatomic, assign) float frequency;
@property (nonatomic, assign) float length;

@property (nonatomic, assign) BOOL playing;
@property (nonatomic, assign, getter=isProcessing) BOOL processing;

@end

namespace yas {
namespace sample {
    struct offline_vc_internal {
        audio::engine play_engine;
        audio::unit_output_node play_output_node;
        audio::unit_mixer_node play_mixer_node;
        offline_sample::sine_node play_sine_node;

        audio::engine offline_engine;
        audio::unit_mixer_node offline_mixer_node;
        offline_sample::sine_node offline_sine_node;

        base engine_observer = nullptr;

        offline_vc_internal() {
            auto format = audio::format({.sample_rate = offline_sample::sample_rate,
                                         .channel_count = 2,
                                         .pcm_format = audio::pcm_format::float32,
                                         .interleaved = false});

            play_mixer_node.unit_node().node().reset();
            play_mixer_node.set_input_pan(0.0f, 0);
            play_mixer_node.set_input_enabled(true, 0);
            play_mixer_node.set_output_volume(1.0f, 0);
            play_mixer_node.set_output_pan(0.0f, 0);

            play_engine.connect(play_mixer_node.unit_node().node(), play_output_node.unit_io_node().unit_node().node(),
                                format);
            play_engine.connect(play_sine_node.tap_node().node(), play_mixer_node.unit_node().node(), format);

            offline_engine.add_offline_output_node();
            audio::offline_output_node &offline_output_node = offline_engine.offline_output_node();

            offline_mixer_node.unit_node().node().reset();
            offline_mixer_node.set_input_pan(0.0f, 0);
            offline_mixer_node.set_input_enabled(true, 0);
            offline_mixer_node.set_output_volume(1.0f, 0);
            offline_mixer_node.set_output_pan(0.0f, 0);

            offline_engine.connect(offline_mixer_node.unit_node().node(), offline_output_node.node(), format);
            offline_engine.connect(offline_sine_node.tap_node().node(), offline_mixer_node.unit_node().node(), format);

            engine_observer = play_engine.subject().make_observer(
                audio::engine::method::configuration_change,
                [weak_play_output_node = to_weak(play_output_node)](auto const &) {
                    if (auto play_output_node = weak_play_output_node.lock()) {
                        play_output_node.unit_io_node().set_device(audio::device::default_output_device());
                    }
                });
        }
    };
}
}

@implementation YASAudioOfflineSampleViewController {
    sample::offline_vc_internal _internal;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.volume = 0.5;
    self.frequency = 1000.0;
    self.length = 1.0;
    self.playing = NO;
}

- (void)viewDidAppear {
    [super viewDidAppear];

    if (_internal.play_engine && !_internal.play_engine.start_render()) {
        NSLog(@"%s error", __PRETTY_FUNCTION__);
    }
}

- (void)viewWillDisappear {
    [super viewWillDisappear];

    _internal.play_engine.stop();
}

- (void)setVolume:(float)volume {
    _internal.play_mixer_node.set_input_volume(volume, 0);
}

- (float)volume {
    return _internal.play_mixer_node.input_volume(0);
}

- (void)setFrequency:(float)frequency {
    _internal.play_sine_node.set_frequency(frequency);
}

- (float)frequency {
    return _internal.play_sine_node.frequency();
}

- (void)setPlaying:(BOOL)playing {
    _internal.play_sine_node.set_playing(playing);
}

- (BOOL)playing {
    return _internal.play_sine_node.is_playing();
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
    panel.allowedFileTypes = @[@"wav"];
    panel.extensionHidden = NO;
    if ([panel runModal] == NSFileHandlingPanelOKButton) {
        [self startOfflineFileWritingWithURL:panel.URL];
    }
}

- (void)startOfflineFileWritingWithURL:(NSURL *)url {
    auto wave_settings = audio::wave_file_settings(offline_sample::sample_rate, 2, 16);
    audio::file file_writer;
    auto create_result = file_writer.create(
        {.file_url = (__bridge CFURLRef)url, .file_type = audio::file_type::wave, .settings = wave_settings});

    if (!create_result) {
        std::cout << __PRETTY_FUNCTION__ << " - error:" << to_string(create_result.error()) << std::endl;
        return;
    }

    _internal.offline_sine_node.set_frequency(_internal.play_sine_node.frequency());
    _internal.offline_sine_node.set_playing(true);
    _internal.offline_mixer_node.set_input_volume(self.volume, 0);

    self.processing = YES;

    uint32_t remain = self.length * offline_sample::sample_rate;

    auto unowned_self = make_objc_ptr([[YASUnownedObject<YASAudioOfflineSampleViewController *> alloc] init]);
    [unowned_self.object() setObject:self];

    auto start_result = _internal.offline_engine.start_offline_render(
        [remain, file_writer = std::move(file_writer)](auto args) mutable {
            auto &buffer = args.buffer;

            auto format = audio::format(buffer.format().stream_description());
            audio::pcm_buffer pcm_buffer(format, buffer.audio_buffer_list());
            pcm_buffer.set_frame_length(buffer.frame_length());

            uint32_t frame_length = MIN(remain, pcm_buffer.frame_length());
            if (frame_length > 0) {
                pcm_buffer.set_frame_length(frame_length);
                auto write_result = file_writer.write_from_buffer(pcm_buffer);
                if (!write_result) {
                    std::cout << __PRETTY_FUNCTION__ << " - error:" << to_string(write_result.error()) << std::endl;
                }
            }

            remain -= frame_length;
            if (remain == 0) {
                file_writer.close();
                args.out_stop = YES;
            }
        },
        [unowned_self](const bool cancelled) { [unowned_self.object() object].processing = NO; });

    if (!start_result) {
        self.processing = NO;
        NSLog(@"%s start offline render error %@", __PRETTY_FUNCTION__, to_cf_object(to_string(start_result.error())));
    }
}

@end
