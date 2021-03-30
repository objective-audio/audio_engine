//
//  YASAudioInputTapNodeSampleViewController.mm
//

#import "YASAudioInputTapNodeSampleViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>
#import <audio/yas_audio_umbrella.h>
#import <objc_utils/yas_objc_macros.h>
#import "YASViewControllerUtils.h"

using namespace yas;

@interface YASAudioInputTapNodeSampleViewController ()

@property (nonatomic, strong) IBOutlet UIProgressView *progressView;
@property (nonatomic, strong) IBOutlet UILabel *label;
@property (nonatomic, strong) CADisplayLink *displayLink;

@end

namespace yas::sample {
struct input_tap_vc_cpp {
    audio::ios_session_ptr const session = audio::ios_session::shared();
    audio::io_device_ptr const device = audio::ios_device::make_renewable_device(this->session);
    audio::graph_ptr const graph = audio::graph::make_shared();
    audio::graph_input_tap_ptr const input_tap = audio::graph_input_tap::make_shared();

    observing::value::holder_ptr<float> const input_level =
        observing::value::holder<float>::make_shared(audio::math::decibel_from_linear(0.0f));

    void setup() {
        this->graph->add_io(this->device);
        this->reconnect();

        input_tap->set_render_handler([input_level = input_level](audio::node_input_render_args const &args) mutable {
            auto const &buffer = args.buffer;

            auto each = audio::make_each_data<float>(*buffer);
            int const frame_length = buffer->frame_length();
            float level = 0;

            while (yas_each_data_next_ch(each)) {
                auto const *const ptr = yas_each_data_ptr(each);
                level = std::max(fabsf(ptr[cblas_isamax(frame_length, ptr, 1)]), level);
            }

            double const sample_rate = buffer->format().sample_rate();
            float prev_level = input_level->value() - frame_length / sample_rate * 30.0f;
            level = std::max(prev_level, audio::math::decibel_from_linear(level));
            input_level->set_value(level);
        });

        this->session
            ->observe_device([this](auto const &method) {
                if (method == audio::ios_device_session::device_method::route_change) {
                    this->reconnect();
                }
            })
            .end()
            ->add_to(this->_pool);
    }

    void dispose() {
        this->graph->stop();
        this->session->deactivate();
    }

    void reconnect() {
        auto const &io = this->graph->io();
        if (!io) {
            return;
        }

        graph->disconnect(io.value()->input_node);

        auto const input_format = this->device->input_format();
        if (!input_format || input_format->is_broken()) {
            return;
        }

        audio::format format{
            {.sample_rate = input_format->sample_rate(), .channel_count = input_format->channel_count()}};
        graph->connect(io.value()->input_node, input_tap->node, format);
    }

   private:
    observing::canceller_pool _pool;
};
}

@implementation YASAudioInputTapNodeSampleViewController {
    sample::input_tap_vc_cpp _cpp;
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
        [self setup];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    if (self.isMovingFromParentViewController) {
        [self dispose];
    }
}

- (void)updateUI:(CADisplayLink *)sender {
    float value = self->_cpp.input_level->value();

    self.progressView.progress = std::max((value + 72.0f) / 72.0f, 0.0f);

    CFTimeInterval currentTime = CFAbsoluteTimeGetCurrent();
    if (currentTime - _lastLabelUpdatedTime > 0.1) {
        self.label.text = [NSString stringWithFormat:@"%.1f dB", value];
        _lastLabelUpdatedTime = currentTime;
    }
}

#pragma mark -

- (void)setup {
    self->_cpp.session->set_category(audio::ios_session::category::record);

    if (auto const result = self->_cpp.session->activate(); !result) {
        [YASViewControllerUtils showErrorAlertWithMessage:(__bridge NSString *)to_cf_object(result.error())
                                         toViewController:self];
        return;
    }

    self->_cpp.setup();

    if (auto start_result = self->_cpp.graph->start_render()) {
        self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateUI:)];
        [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    } else {
        auto const error_string = to_string(start_result.error());
        NSString *errorMessage = (__bridge NSString *)to_cf_object(error_string);
        [YASViewControllerUtils showErrorAlertWithMessage:errorMessage toViewController:self];
    }
}

- (void)dispose {
    [self.displayLink invalidate];
    self.displayLink = nil;

    self->_cpp.dispose();
}

@end
