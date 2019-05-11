//
//  YASAudioOfflineSampleViewController.m
//

#import "YASAudioOfflineSampleViewController.h"
#import <Accelerate/Accelerate.h>
#import <audio/yas_audio_umbrella.h>
#import <objc_utils/yas_objc_unowned.h>
#import <iostream>

using namespace yas;

namespace yas::offline_sample {
static double constexpr sample_rate = 44100.0;
}

namespace yas::offline_sample::engine {
struct sine : base {
    struct impl : base::impl {
        audio::engine::tap _tap;
        double phase_on_render;

        void set_frequency(float const frequency) {
            std::lock_guard<std::recursive_mutex> lock(_mutex);
            _frequency = frequency;
        }

        float frequency() const {
            std::lock_guard<std::recursive_mutex> lock(_mutex);
            return _frequency;
        }

        void set_playing(bool const playing) {
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

    sine() : base(std::make_unique<impl>()) {
        set_frequency(1000.0);

        auto weak_sine = to_weak(*this);

        auto render_handler = [weak_sine](auto args) {
            auto &buffer = args.buffer;

            buffer.clear();

            if (auto sine = weak_sine.lock()) {
                if (sine.is_playing()) {
                    double const start_phase = sine.impl_ptr<impl>()->phase_on_render;
                    double const phase_per_frame = sine.frequency() / sample_rate * audio::math::two_pi;
                    double next_phase = start_phase;
                    uint32_t const frame_length = buffer.frame_length();

                    if (frame_length > 0) {
                        auto each = audio::make_each_data<float>(buffer);
                        while (yas_each_data_next_ch(each)) {
                            next_phase = audio::math::fill_sine(yas_each_data_ptr(each), frame_length, start_phase,
                                                                phase_per_frame);
                        }
                        sine.impl_ptr<impl>()->phase_on_render = next_phase;
                    }
                }
            }
        };

        tap().set_render_handler(render_handler);
    }

    sine(std::nullptr_t) : base(nullptr) {
    }

    virtual ~sine() = default;

    void set_frequency(float const frequency) {
        impl_ptr<impl>()->set_frequency(frequency);
    }

    float frequency() const {
        return impl_ptr<impl>()->frequency();
    }

    void set_playing(bool const playing) {
        impl_ptr<impl>()->set_playing(playing);
    }

    bool is_playing() const {
        return impl_ptr<impl>()->is_playing();
    }

    audio::engine::tap &tap() {
        return impl_ptr<impl>()->_tap;
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
    audio::engine::manager play_manager;
    audio::engine::au_output play_au_output;
    audio::engine::au_mixer play_au_mixer;
    offline_sample::engine::sine play_sine;

    audio::engine::manager offline_manager;
    audio::engine::au_mixer offline_au_mixer;
    offline_sample::engine::sine offline_sine;

    chaining::any_observer engine_observer = nullptr;

    offline_vc_internal() {
        auto format = audio::format({.sample_rate = offline_sample::sample_rate,
                                     .channel_count = 2,
                                     .pcm_format = audio::pcm_format::float32,
                                     .interleaved = false});

        play_au_mixer.au().node().reset();
        play_au_mixer.set_input_pan(0.0f, 0);
        play_au_mixer.set_input_enabled(true, 0);
        play_au_mixer.set_output_volume(1.0f, 0);
        play_au_mixer.set_output_pan(0.0f, 0);

        play_manager.connect(play_au_mixer.au().node(), play_au_output.au_io().au().node(), format);
        play_manager.connect(play_sine.tap().node(), play_au_mixer.au().node(), format);

        offline_manager.add_offline_output();
        audio::engine::offline_output &offline_output = offline_manager.offline_output();

        offline_au_mixer.au().node().reset();
        offline_au_mixer.set_input_pan(0.0f, 0);
        offline_au_mixer.set_input_enabled(true, 0);
        offline_au_mixer.set_output_volume(1.0f, 0);
        offline_au_mixer.set_output_pan(0.0f, 0);

        offline_manager.connect(offline_au_mixer.au().node(), offline_output.node(), format);
        offline_manager.connect(offline_sine.tap().node(), offline_au_mixer.au().node(), format);

        this->engine_observer = this->play_manager.chain(audio::engine::manager::method::configuration_change)
                                    .perform([weak_play_au_output = to_weak(play_au_output)](auto const &) {
                                        if (auto play_au_output = weak_play_au_output.lock()) {
                                            play_au_output.au_io().set_device(audio::device::default_output_device());
                                        }
                                    })
                                    .end();
    }
};
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

    if (_internal.play_manager && !_internal.play_manager.start_render()) {
        NSLog(@"%s error", __PRETTY_FUNCTION__);
    }
}

- (void)viewWillDisappear {
    [super viewWillDisappear];

    _internal.play_manager.stop();
}

- (void)setVolume:(float)volume {
    _internal.play_au_mixer.set_input_volume(volume, 0);
}

- (float)volume {
    return _internal.play_au_mixer.input_volume(0);
}

- (void)setFrequency:(float)frequency {
    _internal.play_sine.set_frequency(frequency);
}

- (float)frequency {
    return _internal.play_sine.frequency();
}

- (void)setPlaying:(BOOL)playing {
    _internal.play_sine.set_playing(playing);
}

- (BOOL)playing {
    return _internal.play_sine.is_playing();
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
    auto create_result = file_writer.create({.file_url = yas::url{to_string((__bridge CFStringRef)url.path)},
                                             .file_type = audio::file_type::wave,
                                             .settings = wave_settings});

    if (!create_result) {
        std::cout << __PRETTY_FUNCTION__ << " - error:" << to_string(create_result.error()) << std::endl;
        return;
    }

    _internal.offline_sine.set_frequency(_internal.play_sine.frequency());
    _internal.offline_sine.set_playing(true);
    _internal.offline_au_mixer.set_input_volume(self.volume, 0);

    self.processing = YES;

    uint32_t remain = self.length * offline_sample::sample_rate;

    auto unowned_self = make_objc_ptr([[YASUnownedObject<YASAudioOfflineSampleViewController *> alloc] init]);
    [unowned_self.object() setObject:self];

    auto start_result = _internal.offline_manager.start_offline_render(
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
                return false;
            }

            return true;
        },
        [unowned_self](bool const cancelled) { [unowned_self.object() object].processing = NO; });

    if (!start_result) {
        self.processing = NO;
        NSLog(@"%s start offline render error %@", __PRETTY_FUNCTION__, to_cf_object(to_string(start_result.error())));
    }
}

@end
