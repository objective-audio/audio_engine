//
//  YASAudioGraphSampleViewController.m
//

#import "YASAudioGraphSampleViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <audio/yas_audio_umbrella.h>
#import <objc_utils/yas_objc_macros.h>
#import <iostream>

using namespace yas;

@interface YASAudioGraphSampleViewController ()

@property (nonatomic, strong) IBOutlet UISlider *slider;

@end

namespace yas::sample {
struct graph_vc_internal {
    audio::graph graph = nullptr;
    std::shared_ptr<audio::unit> io_unit = nullptr;
    std::shared_ptr<audio::unit> mixer_unit = nullptr;

    void setup_graph() {
        double const sample_rate = [[AVAudioSession sharedInstance] sampleRate];

        auto format = audio::format({.sample_rate = sample_rate, .channel_count = 2});

        graph = audio::graph{};

        io_unit = std::make_shared<audio::unit>(kAudioUnitType_Output, audio::unit::sub_type_default_io());
        io_unit->set_enable_input(true);
        io_unit->set_enable_output(true);
        io_unit->set_maximum_frames_per_slice(4096);

        graph.add_unit(io_unit);

        io_unit->attach_render_callback(0);
        io_unit->set_input_format(format.stream_description(), 0);
        io_unit->set_output_format(format.stream_description(), 1);

        mixer_unit = std::make_shared<audio::unit>(kAudioUnitType_Mixer, kAudioUnitSubType_MultiChannelMixer);
        mixer_unit->set_maximum_frames_per_slice(4096);

        graph.add_unit(mixer_unit);

        mixer_unit->attach_render_callback(0);
        mixer_unit->set_element_count(1, kAudioUnitScope_Input);
        mixer_unit->set_input_format(format.stream_description(), 0);
        mixer_unit->set_output_format(format.stream_description(), 0);

        auto weak_mixer_unit = to_weak(mixer_unit);

        io_unit->set_render_handler([weak_mixer_unit](audio::render_parameters &render_parameters) {
            if (auto mixer_unit = weak_mixer_unit.lock()) {
                mixer_unit->raw_unit_render(render_parameters);
            }
        });

        auto weak_io_unit = to_weak(io_unit);

        mixer_unit->set_render_handler([weak_io_unit](audio::render_parameters &render_parameters) {
            if (auto io_unit = weak_io_unit.lock()) {
                render_parameters.in_bus_number = 1;
                try {
                    io_unit->raw_unit_render(render_parameters);
                } catch (std::runtime_error e) {
                    std::cout << e.what() << std::endl;
                }
            }
        });

        this->graph.start();
    }
};
}

@implementation YASAudioGraphSampleViewController {
    sample::graph_vc_internal _internal;
}

- (void)dealloc {
    yas_release(self->_slider);

    self->_slider = nil;

    yas_super_dealloc();
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (self.isMovingToParentViewController) {
        NSError *error = nil;

        if ([[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&error]) {
            [[AVAudioSession sharedInstance] setActive:YES error:&error];
        }

        if (!error) {
            self->_internal.setup_graph();
            [self volumeSliderChanged:self.slider];
        } else {
            [self _showErrorAlertWithMessage:error.description];
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    if (self.isMovingFromParentViewController) {
        self->_internal.graph.stop();

        [[AVAudioSession sharedInstance] setActive:NO error:nil];
    }
}

- (IBAction)volumeSliderChanged:(UISlider *)sender {
    const AudioUnitParameterValue value = sender.value;
    self->_internal.mixer_unit->set_parameter_value(value, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0);
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
