//
//  YASAudioInputTapNodeSampleViewController.mm
//

#import "YASAudioInputTapNodeSampleViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>
#import <audio/yas_audio_umbrella.h>
#import <objc_utils/yas_objc_macros.h>

using namespace yas;

@interface YASAudioInputTapNodeSampleViewController ()

@property (nonatomic, strong) IBOutlet UIProgressView *progressView;
@property (nonatomic, strong) IBOutlet UILabel *label;
@property (nonatomic, strong) CADisplayLink *displayLink;

@end

namespace yas::sample {
struct input_tap_vc_internal {
    audio::engine::manager_ptr manager = audio::engine::manager::make_shared();
    audio::engine::tap_ptr input_tap = audio::engine::tap::make_shared({.is_input = true});

    chaining::value::holder_ptr<float> input_level =
        chaining::value::holder<float>::make_shared(audio::math::decibel_from_linear(0.0f));

    input_tap_vc_internal() {
        this->manager->add_io();
    }

    void prepare() {
        auto const &io = this->manager->io().value();
        audio::avf_device_ptr const device = std::dynamic_pointer_cast<audio::avf_device>(io->device().value());

        double const sample_rate = device->sample_rate();
        uint32_t const ch_count = device->input_channel_count();
        audio::format format{{.sample_rate = sample_rate, .channel_count = ch_count}};
        manager->connect(io->node(), input_tap->node(), format);

        input_tap->set_render_handler([input_level = input_level, sample_rate](auto args) mutable {
            audio::pcm_buffer &buffer = args.buffer;

            auto each = audio::make_each_data<float>(buffer);
            int const frame_length = buffer.frame_length();
            float level = 0;

            while (yas_each_data_next_ch(each)) {
                auto const *const ptr = yas_each_data_ptr(each);
                level = std::max(fabsf(ptr[cblas_isamax(frame_length, ptr, 1)]), level);
            }

            float prev_level = input_level->raw() - frame_length / sample_rate * 30.0f;
            level = std::max(prev_level, audio::math::decibel_from_linear(level));
            input_level->set_value(level);
        });
    }

    void stop() {
        manager->stop();

        [[AVAudioSession sharedInstance] setActive:NO error:nil];
    }
};
}

@implementation YASAudioInputTapNodeSampleViewController {
    sample::input_tap_vc_internal _internal;
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

    if (self.isMovingToParentViewController) {
        NSError *error = nil;

        if ([[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&error]) {
            [[AVAudioSession sharedInstance] setActive:YES error:&error];
        }

        if (!error) {
            [self setup];
        } else {
            [self _showErrorAlertWithMessage:error.description];
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    if (self.isMovingFromParentViewController) {
        [self dispose];

        [[AVAudioSession sharedInstance] setActive:NO error:nil];
    }
}

- (void)updateUI:(CADisplayLink *)sender {
    float value = _internal.input_level->raw();

    self.progressView.progress = std::max((value + 72.0f) / 72.0f, 0.0f);

    CFTimeInterval currentTime = CFAbsoluteTimeGetCurrent();
    if (currentTime - _lastLabelUpdatedTime > 0.1) {
        self.label.text = [NSString stringWithFormat:@"%.1f dB", value];
        _lastLabelUpdatedTime = currentTime;
    }
}

#pragma mark -

- (void)setup {
    _internal.prepare();

    auto start_result = _internal.manager->start_render();

    if (start_result) {
        self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateUI:)];
        [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    } else {
        auto const error_string = to_string(start_result.error());
        NSString *errorMessage = (__bridge NSString *)to_cf_object(error_string);
        [self _showErrorAlertWithMessage:errorMessage];
    }
}

- (void)dispose {
    [self.displayLink invalidate];
    self.displayLink = nil;

    _internal.manager->stop();
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
