//
//  YASAudioInputTapNodeSampleViewController.mm
//

#import <Accelerate/Accelerate.h>
#import "YASAudioInputTapNodeSampleViewController.h"
#import "yas_audio.h"

using namespace yas;

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

        audio::engine engine;
        audio::unit_input_node input_node;
        audio::input_tap_node input_tap_node;

        property<float, property_key> input_level{
            {.key = property_key::input_level, .value = audio::math::decibel_from_linear(0.0f)}};

        input_tap_node_vc_internal() = default;

        void prepare() {
            double const sample_rate = input_node.device_sample_rate();
            audio::format format{{.sample_rate = sample_rate, .channel_count = 2}};
            engine.connect(input_node, input_tap_node.node(), format);

            input_tap_node.set_render_function([input_level = input_level, sample_rate](
                audio::pcm_buffer & buffer, uint32_t const bus_idx, const audio::time &when) mutable {
                audio::frame_enumerator enumerator(buffer);
                auto const *flex_ptr = enumerator.pointer();
                int const frame_length = enumerator.frame_length();
                float level = 0;
                while (flex_ptr->v) {
                    level = MAX(fabsf(flex_ptr->f32[cblas_isamax(frame_length, flex_ptr->f32, 1)]), level);
                    yas_audio_frame_enumerator_move_channel(enumerator);
                }

                float prev_level = input_level.value() - frame_length / sample_rate * 30.0f;
                level = MAX(prev_level, audio::math::decibel_from_linear(level));
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
    sample::input_tap_node_vc_internal _internal;
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
            auto const error_string = to_string(start_result.error());
            errorMessage = (__bridge NSString *)to_cf_object(error_string);
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
    float value = _internal.input_level.value();

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
