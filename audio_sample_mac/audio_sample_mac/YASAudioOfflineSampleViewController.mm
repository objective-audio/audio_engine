//
//  YASAudioOfflineSampleViewController.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioOfflineSampleViewController.h"
#import "yas_audio.h"
#import <Accelerate/Accelerate.h>

namespace yas {
namespace offline_sample {
    static Float64 sample_rate = 44100.0;

    class sine_node : public audio::tap_node {
       public:
        using super_class = audio::tap_node;

        class impl : public super_class::impl {
           public:
            Float64 phase_on_render;

            void set_frequency(const Float32 frequency) {
                std::lock_guard<std::recursive_mutex> lock(_mutex);
                _frequency = frequency;
            }

            Float32 frequency() const {
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
            Float32 _frequency;
            bool _playing;
            mutable std::recursive_mutex _mutex;
        };

       public:
        sine_node() : super_class(std::make_unique<impl>()) {
            set_frequency(1000.0);

            auto weak_node = yas::to_weak(*this);

            auto render_function =
                [weak_node](audio::pcm_buffer &buffer, const UInt32 bus_idx, const audio::time &when) {
                    buffer.clear();

                    if (auto node = weak_node.lock()) {
                        if (node.is_playing()) {
                            const Float64 start_phase = node.impl_ptr<impl>()->phase_on_render;
                            const Float64 phase_per_frame = node.frequency() / sample_rate * yas::audio::math::two_pi;
                            Float64 next_phase = start_phase;
                            const UInt32 frame_length = buffer.frame_length();

                            if (frame_length > 0) {
                                yas::audio::frame_enumerator enumerator(buffer);
                                const auto *flex_ptr = enumerator.pointer();
                                while (flex_ptr->v) {
                                    next_phase = yas::audio::math::fill_sine(flex_ptr->f32, frame_length, start_phase,
                                                                            phase_per_frame);
                                    yas_audio_frame_enumerator_move_channel(enumerator);
                                }

                                node.impl_ptr<impl>()->phase_on_render = next_phase;
                            }
                        }
                    }
                };

            set_render_function(render_function);
        }

        sine_node(std::nullptr_t) : super_class(nullptr) {
        }

        virtual ~sine_node() = default;

        void set_frequency(const Float32 frequency) {
            impl_ptr<impl>()->set_frequency(frequency);
        }

        Float32 frequency() const {
            return impl_ptr<impl>()->frequency();
        }

        void set_playing(const bool playing) {
            impl_ptr<impl>()->set_playing(playing);
        }

        bool is_playing() const {
            return impl_ptr<impl>()->is_playing();
        }
    };
}
}

@interface YASAudioOfflineSampleViewController ()

@property (nonatomic, assign) Float32 volume;
@property (nonatomic, assign) Float32 frequency;
@property (nonatomic, assign) Float32 length;

@property (nonatomic, assign) BOOL playing;
@property (nonatomic, assign, getter=isProcessing) BOOL processing;

@end

namespace yas {
namespace sample {
    struct offline_vc_internal {
        yas::audio::engine play_engine;
        yas::audio::unit_mixer_node play_mixer_node;
        yas::offline_sample::sine_node play_sine_node;

        yas::audio::engine offline_engine;
        yas::audio::unit_mixer_node offline_mixer_node;
        yas::offline_sample::sine_node offline_sine_node;

        yas::base engine_observer = nullptr;

        yas::objc::container<yas::objc::weak> self_container;

        offline_vc_internal() {
            auto format =
                yas::audio::format(yas::offline_sample::sample_rate, 2, yas::audio::pcm_format::float32, false);

            yas::audio::unit_output_node play_output_node;

            play_mixer_node.reset();
            play_mixer_node.set_input_pan(0.0f, 0);
            play_mixer_node.set_input_enabled(true, 0);
            play_mixer_node.set_output_volume(1.0f, 0);
            play_mixer_node.set_output_pan(0.0f, 0);

            play_engine.connect(play_mixer_node, play_output_node, format);
            play_engine.connect(play_sine_node, play_mixer_node, format);

            yas::audio::offline_output_node offline_output_node;

            offline_mixer_node.reset();
            offline_mixer_node.set_input_pan(0.0f, 0);
            offline_mixer_node.set_input_enabled(true, 0);
            offline_mixer_node.set_output_volume(1.0f, 0);
            offline_mixer_node.set_output_pan(0.0f, 0);

            offline_engine.connect(offline_mixer_node, offline_output_node, format);
            offline_engine.connect(offline_sine_node, offline_mixer_node, format);

            engine_observer = play_engine.subject().make_observer(
                yas::audio::engine::configuration_change_key,
                [weak_play_output_node = to_weak(play_output_node)](const auto &, const auto &) {
                    if (auto play_output_node = weak_play_output_node.lock()) {
                        play_output_node.set_device(yas::audio::device::default_output_device());
                    }
                });
        }
    };
}
}

@implementation YASAudioOfflineSampleViewController {
    yas::sample::offline_vc_internal _internal;
}

- (void)dealloc {
    if (_internal.self_container) {
        _internal.self_container.set_object(nil);
    }

    yas_super_dealloc();
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

- (void)setVolume:(Float32)volume {
    _internal.play_mixer_node.set_input_volume(volume, 0);
}

- (Float32)volume {
    return _internal.play_mixer_node.input_volume(0);
}

- (void)setFrequency:(Float32)frequency {
    _internal.play_sine_node.set_frequency(frequency);
}

- (Float32)frequency {
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
    auto wave_settings = yas::audio::wave_file_settings(yas::offline_sample::sample_rate, 2, 16);
    yas::audio::file file_writer;
    auto create_result = file_writer.create((__bridge CFURLRef)url, yas::audio::file_type::wave, wave_settings);

    if (!create_result) {
        std::cout << __PRETTY_FUNCTION__ << " - error:" << yas::to_string(create_result.error()) << std::endl;
        return;
    }

    _internal.offline_sine_node.set_frequency(_internal.play_sine_node.frequency());
    _internal.offline_sine_node.set_playing(true);
    _internal.offline_mixer_node.set_input_volume(self.volume, 0);

    self.processing = YES;

    if (!_internal.self_container) {
        _internal.self_container.set_object(self);
    }

    UInt32 remain = self.length * yas::offline_sample::sample_rate;

    auto start_result = _internal.offline_engine.start_offline_render(
        [remain, file_writer = std::move(file_writer)](yas::audio::pcm_buffer & buffer, const auto &when,
                                                       bool &stop) mutable {
            auto format = yas::audio::format(buffer.format().stream_description());
            yas::audio::pcm_buffer pcm_buffer(format, buffer.audio_buffer_list());
            pcm_buffer.set_frame_length(buffer.frame_length());

            UInt32 frame_length = MIN(remain, pcm_buffer.frame_length());
            if (frame_length > 0) {
                pcm_buffer.set_frame_length(frame_length);
                auto write_result = file_writer.write_from_buffer(pcm_buffer);
                if (!write_result) {
                    std::cout << __PRETTY_FUNCTION__ << " - error:" << yas::to_string(write_result.error())
                              << std::endl;
                }
            }

            remain -= frame_length;
            if (remain == 0) {
                file_writer.close();
                stop = YES;
            }
        },
        [weak_container = _internal.self_container](const bool cancelled) {
            if (auto strong_container = weak_container.lock()) {
                YASAudioOfflineSampleViewController *controller = strong_container.object();
                controller.processing = NO;
            }
        });

    if (!start_result) {
        self.processing = NO;
        NSLog(@"%s start offline render error", __PRETTY_FUNCTION__);
    }
}

@end