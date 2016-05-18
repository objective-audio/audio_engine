//
//  YASAudioGraphSampleViewController.m
//

#import <iostream>
#import "YASAudioGraphSampleViewController.h"
#import "yas_audio.h"

using namespace yas;

@interface YASAudioGraphSampleViewController ()

@property (nonatomic, strong) IBOutlet UISlider *slider;

@end

namespace yas {
namespace sample {
    struct graph_vc_internal {
        audio::graph graph = nullptr;
        audio::unit io_unit = nullptr;
        audio::unit mixer_unit = nullptr;

        graph_vc_internal() {
            AVAudioSession *audioSession = [AVAudioSession sharedInstance];
            [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
            double const sample_rate = [audioSession sampleRate];

            auto format = audio::format({.sample_rate = sample_rate, .channel_count = 2});

            graph = audio::graph{};

            io_unit = audio::unit(kAudioUnitType_Output, audio::unit::sub_type_default_io());
            io_unit.set_enable_input(true);
            io_unit.set_enable_output(true);
            io_unit.set_maximum_frames_per_slice(4096);

            graph.add_audio_unit(io_unit);

            io_unit.attach_render_callback(0);
            io_unit.set_input_format(format.stream_description(), 0);
            io_unit.set_output_format(format.stream_description(), 1);

            mixer_unit = audio::unit(kAudioUnitType_Mixer, kAudioUnitSubType_MultiChannelMixer);
            mixer_unit.set_maximum_frames_per_slice(4096);

            graph.add_audio_unit(mixer_unit);

            mixer_unit.attach_render_callback(0);
            mixer_unit.set_element_count(1, kAudioUnitScope_Input);
            mixer_unit.set_output_format(format.stream_description(), 0);
            mixer_unit.set_input_format(format.stream_description(), 0);

            auto weak_mixer_unit = weak<audio::unit>(mixer_unit);

            io_unit.set_render_callback([weak_mixer_unit](audio::render_parameters &render_parameters) {
                if (auto shared_mixer_unit = weak_mixer_unit.lock()) {
                    shared_mixer_unit.audio_unit_render(render_parameters);
                }
            });

            auto weak_io_unit = weak<audio::unit>(io_unit);

            mixer_unit.set_render_callback([weak_io_unit](audio::render_parameters &render_parameters) {
                if (auto shared_io_unit = weak_io_unit.lock()) {
                    render_parameters.in_bus_number = 1;
                    try {
                        shared_io_unit.audio_unit_render(render_parameters);
                    } catch (std::runtime_error e) {
                        std::cout << e.what() << std::endl;
                    }
                }
            });
        }
    };
}
}

@implementation YASAudioGraphSampleViewController {
    sample::graph_vc_internal _internal;
}

- (void)dealloc {
    yas_release(_slider);

    _slider = nil;

    yas_super_dealloc();
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (self.isMovingToParentViewController) {
        NSError *error = nil;
        if ([[AVAudioSession sharedInstance] setActive:YES error:&error]) {
            _internal.graph.start();
            [self volumeSliderChanged:self.slider];
        } else {
            [self _showErrorAlertWithMessage:error.description];
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    if (self.isMovingFromParentViewController) {
        _internal.graph.stop();

        [[AVAudioSession sharedInstance] setActive:NO error:nil];
    }
}

- (IBAction)volumeSliderChanged:(UISlider *)sender {
    const AudioUnitParameterValue value = sender.value;
    _internal.mixer_unit.set_parameter_value(value, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0);
}

#pragma mark -

- (void)_showErrorAlertWithMessage:(NSString *)message {
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"Error"
                                                                        message:message
                                                                 preferredStyle:UIAlertControllerStyleAlert];
    [controller addAction:[UIAlertAction actionWithTitle:@"OK"
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction *action) {
                                                     [self.navigationController popViewControllerAnimated:YES];
                                                 }]];
    [self presentViewController:controller animated:YES completion:NULL];
}

@end
