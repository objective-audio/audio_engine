//
//  YASAudioOfflineSampleViewController.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioOfflineSampleViewController.h"
#import "yas_audio.h"
#import <Accelerate/Accelerate.h>

namespace yas
{
    namespace offline_sample
    {
        static Float64 sample_rate = 44100.0;

        class sine_node;

        using sine_node_sptr = std::shared_ptr<sine_node>;
        using sine_node_wptr = std::weak_ptr<sine_node>;

        class sine_node : public audio_tap_node
        {
           public:
            static sine_node_sptr create()
            {
                auto node = sine_node_sptr(new sine_node());
                node->_frequency = 1000.0;

                sine_node_wptr weak_node = node;

                auto render_function = [weak_node](audio_pcm_buffer &buffer, const UInt32 bus_idx,
                                                   const audio_time &when) {
                    buffer.clear();

                    if (auto node = weak_node.lock()) {
                        if (node->is_playing()) {
                            const Float64 start_phase = node->_phase_on_render;
                            const Float64 phase_per_frame = node->frequency() / sample_rate * yas::audio_math::two_pi;
                            Float64 next_phase = start_phase;
                            const UInt32 frame_length = buffer.frame_length();

                            if (frame_length > 0) {
                                yas::audio_frame_enumerator enumerator(buffer);
                                const auto *flex_ptr = enumerator.pointer();
                                while (flex_ptr->v) {
                                    next_phase = yas::audio_math::fill_sine(flex_ptr->f32, frame_length, start_phase,
                                                                            phase_per_frame);
                                    yas_audio_frame_enumerator_move_channel(enumerator);
                                }

                                node->_phase_on_render = next_phase;
                            }
                        }
                    }
                };

                node->set_render_function(render_function);

                return node;
            }

            void set_frequency(const Float32 frequency)
            {
                std::lock_guard<std::recursive_mutex> lock(_mutex);
                _frequency = frequency;
            }

            Float32 frequency() const
            {
                std::lock_guard<std::recursive_mutex> lock(_mutex);
                return _frequency;
            }

            void set_playing(const bool playing)
            {
                std::lock_guard<std::recursive_mutex> lock(_mutex);
                _playing = playing;
            }

            bool is_playing() const
            {
                std::lock_guard<std::recursive_mutex> lock(_mutex);
                return _playing;
            }

           private:
            Float64 _phase_on_render;
            Float32 _frequency;
            bool _playing;
            mutable std::recursive_mutex _mutex;
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

@implementation YASAudioOfflineSampleViewController {
    yas::audio_engine _play_engine;
    yas::audio_unit_mixer_node_sptr _play_mixer_node;
    yas::offline_sample::sine_node_sptr _play_sine_node;

    yas::audio_engine _offline_engine;
    yas::audio_unit_mixer_node_sptr _offline_mixer_node;
    yas::offline_sample::sine_node_sptr _offline_sine_node;

    yas::observer _engine_observer;

    yas::objc::container<yas::objc::weak> _self_container;
}

- (void)dealloc
{
    if (_self_container) {
        _self_container.set_object(nil);
    }

    YASSuperDealloc;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    auto format = yas::audio_format(yas::offline_sample::sample_rate, 2, yas::pcm_format::float32, false);

    /*
     play engine
     */

    _play_engine.prepare();

    auto play_output_node = yas::audio_unit_output_node::create();

    _play_mixer_node = yas::audio_unit_mixer_node::create();
    _play_mixer_node->set_input_pan(0.0f, 0);
    _play_mixer_node->set_input_enabled(true, 0);
    _play_mixer_node->set_output_volume(1.0f, 0);
    _play_mixer_node->set_output_pan(0.0f, 0);

    _play_sine_node = yas::offline_sample::sine_node::create();

    _play_engine.connect(_play_mixer_node, play_output_node, format);
    _play_engine.connect(_play_sine_node, _play_mixer_node, format);

    /*
     offline engine
     */

    _offline_engine.prepare();

    auto offline_output_node = yas::audio_offline_output_node::create();

    _offline_mixer_node = yas::audio_unit_mixer_node::create();
    _offline_mixer_node->set_input_pan(0.0f, 0);
    _offline_mixer_node->set_input_enabled(true, 0);
    _offline_mixer_node->set_output_volume(1.0f, 0);
    _offline_mixer_node->set_output_pan(0.0f, 0);

    _offline_sine_node = yas::offline_sample::sine_node::create();

    _offline_engine.connect(_offline_mixer_node, offline_output_node, format);
    _offline_engine.connect(_offline_sine_node, _offline_mixer_node, format);

    std::weak_ptr<yas::audio_unit_output_node> weak_play_output_node = play_output_node;

    _engine_observer.clear();
    _engine_observer.add_handler(_play_engine.subject(), yas::audio_engine_method::configuration_change,
                                 [weak_play_output_node](const auto &, const auto &) {
                                     if (auto play_output_node = weak_play_output_node.lock()) {
                                         play_output_node->set_device(yas::audio_device::default_output_device());
                                     }
                                 });

    self.volume = 0.5;
    self.frequency = 1000.0;
    self.length = 1.0;
    self.playing = NO;
}

- (void)viewDidAppear
{
    [super viewDidAppear];

    if (_play_engine && !_play_engine.start_render()) {
        NSLog(@"%s error", __PRETTY_FUNCTION__);
    }
}

- (void)viewWillDisappear
{
    [super viewWillDisappear];

    if (_play_engine) {
        _play_engine.stop();
    }
}

- (void)setVolume:(Float32)volume
{
    if (_play_mixer_node) {
        _play_mixer_node->set_input_volume(volume, 0);
    }
}

- (Float32)volume
{
    if (_play_mixer_node) {
        return _play_mixer_node->input_volume(0);
    }
    return 0.0f;
}

- (void)setFrequency:(Float32)frequency
{
    if (_play_sine_node) {
        _play_sine_node->set_frequency(frequency);
    }
}

- (Float32)frequency
{
    if (_play_sine_node) {
        return _play_sine_node->frequency();
    }
    return 0.0f;
}

- (void)setPlaying:(BOOL)playing
{
    if (_play_sine_node) {
        _play_sine_node->set_playing(playing);
    }
}

- (BOOL)playing
{
    if (_play_sine_node) {
        return _play_sine_node->is_playing();
    }
    return NO;
}

- (IBAction)playButtonTapped:(id)sender
{
    self.playing = YES;
}

- (IBAction)stopButtonTapped:(id)sender
{
    self.playing = NO;
}

- (IBAction)exportButtonTapped:(id)sender
{
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

- (void)startOfflineFileWritingWithURL:(NSURL *)url
{
    if (!_offline_engine || !_offline_sine_node || !_offline_mixer_node || !_play_sine_node) {
        return;
    }

    auto wave_settings = yas::wave_file_settings(yas::offline_sample::sample_rate, 2, 16);
    yas::audio_file file_writer;
    auto create_result = file_writer.create((__bridge CFURLRef)url, yas::audio_file_type::wave, wave_settings);

    if (!create_result) {
        std::cout << __PRETTY_FUNCTION__ << " - error:" << yas::to_string(create_result.error()) << std::endl;
        return;
    }

    _offline_sine_node->set_frequency(_play_sine_node->frequency());
    _offline_sine_node->set_playing(true);
    _offline_mixer_node->set_input_volume(self.volume, 0);

    self.processing = YES;

    if (!_self_container) {
        _self_container.set_object(self);
    }

    UInt32 remain = self.length * yas::offline_sample::sample_rate;

    auto start_result = _offline_engine.start_offline_render(
        [remain, file_writer = std::move(file_writer)](yas::audio_pcm_buffer & buffer, const auto &when,
                                                       bool &stop) mutable {
            auto format = yas::audio_format(buffer.format().stream_description());
            yas::audio_pcm_buffer pcm_buffer(format, buffer.audio_buffer_list());
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
        [weak_container = _self_container](const bool cancelled) {
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
