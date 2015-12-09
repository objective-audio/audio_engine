//
//  YASAudioInputTapNodeSampleViewController.mm
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioInputTapNodeSampleViewController.h"
#import "yas_audio.h"
#import <Accelerate/Accelerate.h>

@interface YASAudioInputTapNodeSampleViewController ()

@property (nonatomic, strong) IBOutlet UIProgressView *progressView;
@property (nonatomic, strong) IBOutlet UILabel *label;
@property (nonatomic, strong) CADisplayLink *displayLink;

@end

namespace yas {
namespace sample {
    struct input_tap_node_vc_internal {
        enum class property_key {
            input_level,
        };

        yas::audio::engine engine;
        yas::audio::unit_input_node input_node;
        yas::audio::input_tap_node input_tap_node;

        yas::property<Float32, property_key> input_level;

        input_tap_node_vc_internal()
            : input_level(property_key::input_level, yas::audio::math::decibel_from_linear(0.0)) {
        }

        void prepare() {
            const Float64 sample_rate = input_node.device_sample_rate();
            yas::audio::format format{sample_rate, 2};
            engine.connect(input_node, input_tap_node, format);

            input_tap_node.set_render_function([input_level = input_level, sample_rate](
                audio::pcm_buffer & buffer, const UInt32 bus_idx, const audio::time &when) mutable {
                yas::audio::frame_enumerator enumerator(buffer);
                const auto *flex_ptr = enumerator.pointer();
                const int frame_length = enumerator.frame_length();
                Float32 level = 0;
                while (flex_ptr->v) {
                    level = MAX(fabsf(flex_ptr->f32[cblas_isamax(frame_length, flex_ptr->f32, 1)]), level);
                    yas_audio_frame_enumerator_move_channel(enumerator);
                }

                Float32 prev_level = input_level.value() - frame_length / sample_rate * 30.0f;
                level = MAX(prev_level, yas::audio::math::decibel_from_linear(level));
                input_level.set_value(level);
            });
        }

        void stop() {
            engine.stop();

            [[AVAudioSession sharedInstance] setActive:NO error:nil];
        }
    };
}
}

@implementation YASAudioInputTapNodeSampleViewController {
    yas::sample::input_tap_node_vc_internal _internal;
    CFTimeInterval _lastLabelUpdatedTime;
}

- (void)dealloc {
    yas_release(_label);
    yas_release(_progressView);

    _label = nil;
    _progressView = nil;

    yas_super_dealloc();
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    BOOL success = NO;
    NSError *error = nil;
    NSString *errorMessage = nil;

    if ([[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&error]) {
        _internal.prepare();
        auto start_result = _internal.engine.start_render();
        if (start_result) {
            success = YES;
            self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateUI:)];
            [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        } else {
            const auto error_string = yas::to_string(start_result.error());
            errorMessage = (__bridge NSString *)yas::to_cf_object(error_string);
        }
    } else {
        errorMessage = error.description;
    }

    if (errorMessage) {
        [self _showErrorAlertWithMessage:errorMessage];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self.displayLink invalidate];
    self.displayLink = nil;

    _internal.engine.stop();
}

- (void)updateUI:(CADisplayLink *)sender {
    Float32 value = _internal.input_level.value();

    self.progressView.progress = MAX((value + 72.0f) / 72.0f, 0.0f);

    CFTimeInterval currentTime = CFAbsoluteTimeGetCurrent();
    if (currentTime - _lastLabelUpdatedTime > 0.1) {
        self.label.text = [NSString stringWithFormat:@"%.1f dB", value];
        _lastLabelUpdatedTime = currentTime;
    }
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
