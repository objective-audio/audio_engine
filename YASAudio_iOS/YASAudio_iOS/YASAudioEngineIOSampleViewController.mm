//
//  YASAudioEngineIOSampleViewController.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioEngineIOSampleViewController.h"
#import "yas_audio.h"
#import "YASAudioMath.h"
#import <Accelerate/Accelerate.h>

namespace yas
{
    namespace sample
    {
        class meter_input_tap_node;

        using meter_input_tap_node_ptr = std::shared_ptr<meter_input_tap_node>;

        class meter_input_tap_node : public audio_input_tap_node
        {
           public:
            enum class property_key {
                meter_level,
            };

            yas::property<property_key, Float32>::shared_ptr meter_level;

            using property_observer_ptr = yas::observer<yas::property_method, decltype(meter_level)>::shared_ptr;

            static meter_input_tap_node_ptr create()
            {
                auto node = meter_input_tap_node_ptr(new meter_input_tap_node);

                std::weak_ptr<meter_input_tap_node> weak_node = node;

                node->set_render_function([weak_node](const yas::pcm_buffer_sptr &buffer, const uint32_t bus_idx,
                                                      const yas::audio_time_sptr &when) {
                    if (auto node = weak_node.lock()) {
                        node->render_source(buffer, bus_idx, when);

                        Float32 current_max = 0;
                        yas::audio_frame_enumerator enumerator(buffer);
                        const auto *flex_ptr = enumerator.pointer();
                        while (flex_ptr->v) {
                            current_max =
                                MAX(current_max,
                                    fabsf(flex_ptr->f32[cblas_isamax((int)buffer->frame_length(), flex_ptr->f32, 1)]));
                            yas_audio_frame_enumerator_move_channel(enumerator);
                        }

                        const CFAbsoluteTime current_time = CFAbsoluteTimeGetCurrent();
                        const CFAbsoluteTime max_duration = node->_last_update_max_time_on_render > 0 ?
                                                                current_time - node->_last_update_max_time_on_render :
                                                                0.0f;
                        const Float32 reduced_level = MAX(0.0f, node->_last_max_on_render - max_duration * 1.0);
                        const Float32 level = MAX(reduced_level, MIN(1.0f, current_max));
                        node->_last_max_on_render = level;
                        node->_last_update_max_time_on_render = current_time;

                        const CFAbsoluteTime meter_duration = current_time - node->_last_update_meter_time_on_render;
                        if (meter_duration > 1.0 / 15.0f) {
                            auto update_function = [weak_node, level]() {
                                if (auto strong_node = weak_node.lock()) {
                                    strong_node->meter_level->set_value(level);
                                }
                            };
                            dispatch_async(dispatch_get_main_queue(), update_function);
                            node->_last_update_meter_time_on_render = current_time;
                        }
                    }
                });

                return node;
            }

            meter_input_tap_node()
                : meter_level(yas::make_property(property_key::meter_level, 0.0f)),
                  _last_max_on_render(0.0f),
                  _last_update_max_time_on_render(0.0),
                  _last_update_meter_time_on_render(0.0)
            {
            }

            virtual ~meter_input_tap_node()
            {
            }

           private:
            Float32 _last_max_on_render;
            CFAbsoluteTime _last_update_max_time_on_render;
            CFAbsoluteTime _last_update_meter_time_on_render;
        };
    }
}

@interface YASAudioEngineIOSampleViewController ()

@property (nonatomic, strong) IBOutlet UISlider *slider;
@property (nonatomic, strong) IBOutlet UIProgressView *progressView;

@end

@implementation YASAudioEngineIOSampleViewController {
    yas::audio_engine_sptr _audio_engine;
    yas::audio_unit_output_node_sptr _output_node;
    yas::audio_unit_mixer_node_sptr _mixer_node;
    yas::audio_unit_input_node_sptr _input_node;

    yas::audio_unit_input_node_sptr _meter_input_node;
    yas::sample::meter_input_tap_node_ptr _meter_tap_node;
    yas::sample::meter_input_tap_node::property_observer_ptr _meter_tap_observer;
    std::vector<yas::any> _observers;
}

- (void)dealloc
{
    YASRelease(_slider);
    YASRelease(_progressView);

    _slider = nil;
    _progressView = nil;

    YASSuperDealloc;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    if ([self setupAudioEngine]) {
        [self volumeSliderChanged:self.slider];
    } else {
        [self showErrorAlert];
    }
}

- (IBAction)volumeSliderChanged:(UISlider *)sender
{
    const Float32 value = sender.value;
    if (_mixer_node) {
        _mixer_node->set_input_volume(value, 0);
    }
}

- (BOOL)setupAudioEngine
{
    _audio_engine = nullptr;
    _output_node = nullptr;
    _mixer_node = nullptr;
    _input_node = nullptr;
    _meter_input_node = nullptr;
    _meter_tap_node = nullptr;

    AVAudioSession *audioSession = [AVAudioSession sharedInstance];

    NSError *error = nil;
    if (![audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:&error]) {
        NSLog(@"%@", error);
        return NO;
    }

    Float64 sample_rate = [audioSession sampleRate];

    _audio_engine = yas::audio_engine::create();
    _output_node = yas::audio_unit_output_node::create();
    _mixer_node = yas::audio_unit_mixer_node::create();
    _input_node = yas::audio_unit_input_node::create();
    _meter_input_node = yas::audio_unit_input_node::create();
    _meter_tap_node = yas::sample::meter_input_tap_node::create();

    auto weak_self = yas::objc_weak_container::create(self);

    auto meter_observer = yas::make_observer(_meter_tap_node->meter_level->subject());
    meter_observer->add_handler(_meter_tap_node->meter_level->subject(), yas::property_method::did_change,
                                [weak_self](const auto &, const auto &sender) {
                                    if (sender->key() == yas::sample::meter_input_tap_node::property_key::meter_level) {
                                        if (auto strong_self = weak_self->lock()) {
                                            YASAudioEngineIOSampleViewController *controller = strong_self.object();
                                            controller.progressView.progress = sender->value();
                                        }
                                    }
                                });
    _observers.push_back(meter_observer);

    auto format = yas::audio_format::create(sample_rate, 2);

    _audio_engine->connect(_mixer_node, _output_node, format);
    _audio_engine->connect(_input_node, _mixer_node, format);
    _audio_engine->connect(_meter_input_node, _meter_tap_node, format);

    if (!_audio_engine->start_render()) {
        NSLog(@"%s - audio_engine start error", __PRETTY_FUNCTION__);
        return NO;
    }

    return YES;
}

#pragma mark -

- (void)showErrorAlert
{
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"Error"
                                                                        message:@"Can't start audio engine."
                                                                 preferredStyle:UIAlertControllerStyleAlert];
    [controller addAction:[UIAlertAction actionWithTitle:@"OK"
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction *action) {
                                                     [self.navigationController popViewControllerAnimated:YES];
                                                 }]];
    [self presentViewController:controller animated:YES completion:NULL];
}

@end
