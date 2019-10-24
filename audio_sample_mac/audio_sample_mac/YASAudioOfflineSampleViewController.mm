//
//  YASAudioOfflineSampleViewController.m
//

#import "YASAudioOfflineSampleViewController.h"
#import <Accelerate/Accelerate.h>
#import <audio/yas_audio_umbrella.h>
#import <cpp_utils/yas_objc_ptr.h>
#import <objc_utils/yas_objc_unowned.h>
#import <iostream>

using namespace yas;

namespace yas::offline_sample {
static double constexpr sample_rate = 44100.0;
}

namespace yas::offline_sample::engine {
class sine;
using sine_ptr = std::shared_ptr<sine>;

struct sine {
    virtual ~sine() = default;

    void set_frequency(float const frequency) {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        __frequency = frequency;
    }

    float frequency() const {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        return __frequency;
    }

    void set_playing(bool const playing) {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        __playing = playing;
    }

    bool is_playing() const {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        return __playing;
    }

    audio::engine::tap &tap() {
        return *this->_tap;
    }

   private:
    audio::engine::tap_ptr _tap = audio::engine::tap::make_shared();
    double _phase_on_render;

    mutable std::recursive_mutex _mutex;
    float __frequency;
    bool __playing;

    sine() = default;

    void _prepare(sine_ptr const &shared) {
        set_frequency(1000.0);

        auto weak_sine = to_weak(shared);

        auto render_handler = [weak_sine](auto args) {
            auto &buffer = args.buffer;

            buffer.clear();

            if (auto sine = weak_sine.lock()) {
                if (sine->is_playing()) {
                    double const start_phase = sine->_phase_on_render;
                    double const phase_per_frame = sine->frequency() / sample_rate * audio::math::two_pi;
                    double next_phase = start_phase;
                    uint32_t const frame_length = buffer.frame_length();

                    if (frame_length > 0) {
                        auto each = audio::make_each_data<float>(buffer);
                        while (yas_each_data_next_ch(each)) {
                            next_phase = audio::math::fill_sine(yas_each_data_ptr(each), frame_length, start_phase,
                                                                phase_per_frame);
                        }
                        sine->_phase_on_render = next_phase;
                    }
                }
            }
        };

        tap().set_render_handler(render_handler);
    }

   public:
    static sine_ptr make_shared() {
        auto shared = sine_ptr(new sine{});
        shared->_prepare(shared);
        return shared;
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
    audio::engine::manager_ptr play_manager = audio::engine::manager::make_shared();
    audio::engine::au_mixer_ptr play_au_mixer = audio::engine::au_mixer::make_shared();
    offline_sample::engine::sine_ptr play_sine = offline_sample::engine::sine::make_shared();

    audio::engine::manager_ptr offline_manager = audio::engine::manager::make_shared();
    audio::engine::au_mixer_ptr offline_au_mixer = audio::engine::au_mixer::make_shared();
    offline_sample::engine::sine_ptr offline_sine = offline_sample::engine::sine::make_shared();

    chaining::any_observer_ptr engine_observer = nullptr;

    offline_vc_internal() {
        this->play_manager->add_io();

        auto const &io = this->play_manager->io();

        auto format = audio::format({.sample_rate = offline_sample::sample_rate,
                                     .channel_count = 2,
                                     .pcm_format = audio::pcm_format::float32,
                                     .interleaved = false});

        this->play_au_mixer->au().node()->reset();
        this->play_au_mixer->set_input_pan(0.0f, 0);
        this->play_au_mixer->set_input_enabled(true, 0);
        this->play_au_mixer->set_output_volume(1.0f, 0);
        this->play_au_mixer->set_output_pan(0.0f, 0);

        this->play_manager->connect(this->play_au_mixer->au().node(), io->node(), format);
        this->play_manager->connect(this->play_sine->tap().node(), this->play_au_mixer->au().node(), format);

        this->offline_manager->add_offline_output();
        audio::engine::offline_output_ptr const &offline_output = this->offline_manager->offline_output();

        this->offline_au_mixer->au().node()->reset();
        this->offline_au_mixer->set_input_pan(0.0f, 0);
        this->offline_au_mixer->set_input_enabled(true, 0);
        this->offline_au_mixer->set_output_volume(1.0f, 0);
        this->offline_au_mixer->set_output_pan(0.0f, 0);

        this->offline_manager->connect(this->offline_au_mixer->au().node(), offline_output->node(), format);
        this->offline_manager->connect(this->offline_sine->tap().node(), this->offline_au_mixer->au().node(), format);

        this->engine_observer = this->play_manager->chain(audio::engine::manager::method::configuration_change)
                                    .perform([weak_io = to_weak(io)](auto const &) {
                                        if (auto io = weak_io.lock()) {
                                            if (auto const device = audio::mac_device::default_output_device()) {
                                                io->set_device(*device);
                                            }
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

    if (_internal.play_manager && !_internal.play_manager->start_render()) {
        NSLog(@"%s error", __PRETTY_FUNCTION__);
    }
}

- (void)viewWillDisappear {
    [super viewWillDisappear];

    _internal.play_manager->stop();
}

- (void)setVolume:(float)volume {
    _internal.play_au_mixer->set_input_volume(volume, 0);
}

- (float)volume {
    return _internal.play_au_mixer->input_volume(0);
}

- (void)setFrequency:(float)frequency {
    _internal.play_sine->set_frequency(frequency);
}

- (float)frequency {
    return _internal.play_sine->frequency();
}

- (void)setPlaying:(BOOL)playing {
    _internal.play_sine->set_playing(playing);
}

- (BOOL)playing {
    return _internal.play_sine->is_playing();
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
    if ([panel runModal] == NSModalResponseOK) {
        [self startOfflineFileWritingWithURL:panel.URL];
    }
}

- (void)startOfflineFileWritingWithURL:(NSURL *)url {
    auto wave_settings = audio::wave_file_settings(offline_sample::sample_rate, 2, 16);
    auto file_writer = audio::file::make_shared();
    auto create_result = file_writer->create({.file_url = yas::url{to_string((__bridge CFStringRef)url.path)},
                                              .file_type = audio::file_type::wave,
                                              .settings = wave_settings});

    if (!create_result) {
        std::cout << __PRETTY_FUNCTION__ << " - error:" << to_string(create_result.error()) << std::endl;
        return;
    }

    _internal.offline_sine->set_frequency(_internal.play_sine->frequency());
    _internal.offline_sine->set_playing(true);
    _internal.offline_au_mixer->set_input_volume(self.volume, 0);

    self.processing = YES;

    uint32_t remain = self.length * offline_sample::sample_rate;

    auto unowned_self =
        objc_ptr_with_move_object([[YASUnownedObject<YASAudioOfflineSampleViewController *> alloc] init]);
    [unowned_self.object() setObject:self];

    auto start_result = _internal.offline_manager->start_offline_render(
        [remain, file_writer = std::move(file_writer)](auto args) mutable {
            auto &buffer = args.buffer;

            auto format = audio::format(buffer.format().stream_description());
            audio::pcm_buffer pcm_buffer(format, buffer.audio_buffer_list());
            pcm_buffer.set_frame_length(buffer.frame_length());

            uint32_t frame_length = MIN(remain, pcm_buffer.frame_length());
            if (frame_length > 0) {
                pcm_buffer.set_frame_length(frame_length);
                auto write_result = file_writer->write_from_buffer(pcm_buffer);
                if (!write_result) {
                    std::cout << __PRETTY_FUNCTION__ << " - error:" << to_string(write_result.error()) << std::endl;
                }
            }

            remain -= frame_length;
            if (remain == 0) {
                file_writer->close();
                return audio::continuation::abort;
            }

            return audio::continuation::keep;
        },
        [unowned_self](bool const cancelled) { [unowned_self.object() object].processing = NO; });

    if (!start_result) {
        self.processing = NO;
        NSLog(@"%s start offline render error %@", __PRETTY_FUNCTION__, to_cf_object(to_string(start_result.error())));
    }
}

@end
