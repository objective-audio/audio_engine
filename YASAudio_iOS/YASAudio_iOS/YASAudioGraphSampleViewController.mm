//
//  YASAudioGraphSampleViewController.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioGraphSampleViewController.h"
#import "yas_audio.h"

@interface YASAudioGraphSampleViewController ()

@property (nonatomic, strong) IBOutlet UISlider *slider;

@end

namespace yas
{
    namespace sample
    {
        struct graph_vc_internal {
            yas::audio_graph graph = nullptr;
            yas::audio_unit io_unit = nullptr;
            yas::audio_unit mixer_unit = nullptr;

            graph_vc_internal()
            {
                AVAudioSession *audioSession = [AVAudioSession sharedInstance];
                [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
                const Float64 sample_rate = [audioSession sampleRate];

                auto format = yas::audio_format(sample_rate, 2);

                graph.prepare();

                io_unit = yas::audio_unit(kAudioUnitType_Output, yas::audio_unit::sub_type_default_io());
                io_unit.set_enable_input(true);
                io_unit.set_enable_output(true);
                io_unit.set_maximum_frames_per_slice(4096);

                graph.add_audio_unit(io_unit);

                io_unit.attach_render_callback(0);
                io_unit.set_input_format(format.stream_description(), 0);
                io_unit.set_output_format(format.stream_description(), 1);

                mixer_unit = yas::audio_unit(kAudioUnitType_Mixer, kAudioUnitSubType_MultiChannelMixer);
                mixer_unit.set_maximum_frames_per_slice(4096);

                graph.add_audio_unit(mixer_unit);

                mixer_unit.attach_render_callback(0);
                mixer_unit.set_element_count(1, kAudioUnitScope_Input);
                mixer_unit.set_output_format(format.stream_description(), 0);
                mixer_unit.set_input_format(format.stream_description(), 0);

                auto weak_mixer_unit = yas::weak<yas::audio_unit>(mixer_unit);

                io_unit.set_render_callback([weak_mixer_unit](yas::render_parameters &render_parameters) {
                    if (auto shared_mixer_unit = weak_mixer_unit.lock()) {
                        shared_mixer_unit.audio_unit_render(render_parameters);
                    }
                });

                auto weak_io_unit = yas::weak<yas::audio_unit>(io_unit);

                mixer_unit.set_render_callback([weak_io_unit](yas::render_parameters &render_parameters) {
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
    std::experimental::optional<yas::sample::graph_vc_internal> _internal;
}

- (void)dealloc
{
    YASRelease(_slider);

    _slider = nil;

    YASSuperDealloc;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    if (self.isMovingToParentViewController) {
        NSError *error = nil;
        if ([[AVAudioSession sharedInstance] setActive:YES error:&error]) {
            [self setupAudioGraph];
            [self volumeSliderChanged:self.slider];
        } else {
            [self _showErrorAlertWithMessage:error.description];
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    if (self.isMovingFromParentViewController) {
        _internal->graph.stop();

        [[AVAudioSession sharedInstance] setActive:NO error:nil];
    }
}

- (IBAction)volumeSliderChanged:(UISlider *)sender
{
    const AudioUnitParameterValue value = sender.value;
    _internal->mixer_unit.set_parameter_value(value, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0);
}

- (void)setupAudioGraph
{
    _internal = yas::sample::graph_vc_internal();
    _internal->graph.start();
}

#pragma mark -

- (void)_showErrorAlertWithMessage:(NSString *)message
{
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
