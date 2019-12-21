//
//  YASAudioOfflineSampleViewController.m
//

#import "YASAudioOfflineSampleViewController.h"
#import <Accelerate/Accelerate.h>
#import <audio/yas_audio_umbrella.h>
#import <cpp_utils/yas_objc_ptr.h>
#import <cpp_utils/yas_thread.h>
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

            buffer->clear();

            if (auto sine = weak_sine.lock()) {
                if (sine->is_playing()) {
                    double const start_phase = sine->_phase_on_render;
                    double const phase_per_frame = sine->frequency() / sample_rate * audio::math::two_pi;
                    double next_phase = start_phase;
                    uint32_t const frame_length = buffer->frame_length();

                    if (frame_length > 0) {
                        auto each = audio::make_each_data<float>(*buffer);
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
    audio::engine::avf_au_mixer_ptr play_au_mixer = audio::engine::avf_au_mixer::make_shared();
    offline_sample::engine::sine_ptr play_sine = offline_sample::engine::sine::make_shared();

    audio::engine::manager_ptr offline_manager = audio::engine::manager::make_shared();
    audio::engine::avf_au_mixer_ptr offline_au_mixer = audio::engine::avf_au_mixer::make_shared();
    offline_sample::engine::sine_ptr offline_sine = offline_sample::engine::sine::make_shared();

    offline_vc_internal() {
        auto const &io = this->play_manager->add_io();

        if (auto const device = audio::mac_device::default_output_device()) {
            this->_set_device(device.value());
        }

        this->play_au_mixer->au()->node()->reset();
        this->play_au_mixer->set_input_pan(0.0f, 0);
        this->play_au_mixer->set_input_enabled(true, 0);
        this->play_au_mixer->set_output_volume(1.0f, 0);
        this->play_au_mixer->set_output_pan(0.0f, 0);

        this->_io_observer = io->io_device_chain()
                                 .perform([this](auto const &method) {
                                     switch (method) {
                                         case audio::io_device::method::updated:
                                             this->_update_connection();
                                             break;
                                         case audio::io_device::method::lost:
                                             break;
                                     }
                                 })
                                 .end();

        this->_system_observer = audio::mac_device::system_chain(audio::mac_device::system_method::hardware_did_change)
                                     .perform([this](auto const &) { this->_update_device_if_default_changed(); })
                                     .end();

        this->offline_manager->add_offline_output();
        auto const &offline_output = this->offline_manager->offline_output().value();

        this->offline_au_mixer->au()->node()->reset();
        this->offline_au_mixer->set_input_pan(0.0f, 0);
        this->offline_au_mixer->set_input_enabled(true, 0);
        this->offline_au_mixer->set_output_volume(1.0f, 0);
        this->offline_au_mixer->set_output_pan(0.0f, 0);

        this->offline_manager->connect(this->offline_au_mixer->au()->node(), offline_output->node(),
                                       this->_file_format);
        this->offline_manager->connect(this->offline_sine->tap().node(), this->offline_au_mixer->au()->node(),
                                       this->_file_format);
    }

    void start_render() {
        auto const &io = this->play_manager->io();
        if (!io) {
            return;
        }

        auto const &io_value = io.value();
        auto const output_format = io_value->device().value()->output_format();

        if (!output_format.has_value()) {
            return;
        }

        this->play_manager->connect(this->play_au_mixer->au()->node(), io_value->node(), *output_format);
        this->play_manager->connect(this->play_sine->tap().node(), this->play_au_mixer->au()->node(),
                                    this->_file_format);

        if (!this->play_manager->start_render()) {
            NSLog(@"%s error", __PRETTY_FUNCTION__);
        }
    }

    void stop_render() {
        this->play_manager->stop();
        this->play_manager->disconnect(this->play_au_mixer->au()->node());
    }

   private:
    std::optional<audio::mac_device_ptr> _device = std::nullopt;

    audio::format const _file_format{{.sample_rate = offline_sample::sample_rate,
                                      .channel_count = 2,
                                      .pcm_format = audio::pcm_format::float32,
                                      .interleaved = false}};

    chaining::any_observer_ptr _io_observer = nullptr;
    chaining::any_observer_ptr _system_observer = nullptr;

    void _update_connection() {
        if (auto const &io = this->play_manager->io()) {
            auto const &io_value = io.value();
            if (auto const output_format = io_value->device().value()->output_format()) {
                this->play_manager->disconnect(io_value->node());

                this->play_manager->connect(this->play_au_mixer->au()->node(), io_value->node(), *output_format);
            }
        }
    }

    void _set_device(audio::mac_device_ptr const &device) {
        if (auto const &io = this->play_manager->io()) {
            io.value()->set_device(device);
            this->_device = device;
        }
    }

    void _update_device_if_default_changed() {
        auto default_device = audio::mac_device::default_output_device();
        if (default_device && this->_device && default_device.value() != this->_device.value()) {
            this->stop_render();

            this->_set_device(default_device.value());

            this->start_render();
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

    self->_internal.value()->offline_sine->set_frequency(_internal.value()->play_sine->frequency());
    self->_internal.value()->offline_sine->set_playing(true);
    self->_internal.value()->offline_au_mixer->set_input_volume(self.volume, 0);

    self.processing = YES;

    uint32_t remain = self.length * offline_sample::sample_rate;

    auto unowned_self =
        objc_ptr_with_move_object([[YASUnownedObject<YASAudioOfflineSampleViewController *> alloc] init]);
    [unowned_self.object() setObject:self];

    auto start_result = self->_internal.value()->offline_manager->start_offline_render(
        [remain, file_writer = std::move(file_writer)](auto args) mutable {
            auto &buffer = args.buffer;

            auto format = audio::format(buffer->format().stream_description());
            audio::pcm_buffer pcm_buffer(format, buffer->audio_buffer_list());
            pcm_buffer.set_frame_length(buffer->frame_length());

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
