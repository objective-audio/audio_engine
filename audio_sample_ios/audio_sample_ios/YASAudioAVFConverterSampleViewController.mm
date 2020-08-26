//
//  YASAudioAVFConverterSampleViewController.mm
//

#import "YASAudioAVFConverterSampleViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <audio/yas_audio_umbrella.h>
#include <cpp_utils/yas_fast_each.h>
#import "YASViewControllerUtils.h"
#import "yas_audio_sample_kernel.h"

using namespace yas;

namespace yas::sample {
struct avf_converter_vc_cpp {
    audio::ios_session_ptr const session;
    audio::ios_device_ptr const device;
    audio::graph_ptr const graph;
    audio::graph_avf_au_ptr const converter;
    audio::graph_tap_ptr tap;
    chaining::observer_pool pool;
    audio::sample::kernel_ptr const kernel;

    avf_converter_vc_cpp()
        : session(audio::ios_session::shared()),
          device(audio::ios_device::make_shared(this->session)),
          graph(audio::graph::make_shared()),
          converter(audio::graph_avf_au::make_shared(kAudioUnitType_FormatConverter, kAudioUnitSubType_AUConverter)),
          tap(audio::graph_tap::make_shared()),
          kernel(audio::sample::kernel::make_shared()) {
    }

    std::optional<std::string> setup() {
        this->session->set_category(audio::ios_session::category::playback);

        if (auto const result = this->session->activate(); !result) {
            return result.error();
        }

        auto const &io = this->graph->add_io(this->device);

        auto const output_format = this->device->output_format();
        double const output_sample_rate = output_format->sample_rate();
        double const input_sample_rate = output_sample_rate == 44100 ? 22050 : 44100;
        auto asbd = output_format->stream_description();
        asbd.mSampleRate = input_sample_rate;
        auto const input_format = audio::format{asbd};

        this->graph->connect(this->converter->node(), io->node(), *output_format);
        this->graph->connect(this->tap->node(), this->converter->node(), input_format);

        this->kernel->set_sine_volume(0.1);
        this->kernel->set_sine_frequency(1000.0);

        this->tap->set_render_handler([kernel = this->kernel](audio::graph_node::render_args args) {
            kernel->process(nullptr, args.buffer ? args.buffer.get() : nullptr);
        });

        this->converter->load_state_chain()
            .perform([this](auto const &state) {
                if (state == audio::avf_au::load_state::loaded) {
                    this->graph->start_render();
                }
            })
            .sync()
            ->add_to(this->pool);

        return std::nullopt;
    }

    void dispose() {
        this->pool.invalidate();

        this->graph->remove_io();

        this->session->deactivate();
    }
};
}

@interface YASAudioAVFConverterSampleViewController ()

@property (nonatomic, weak) IBOutlet UISlider *volumeSlider;

@end

@implementation YASAudioAVFConverterSampleViewController {
    sample::avf_converter_vc_cpp _cpp;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.volumeSlider.value = 0.0;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (self.isMovingToParentViewController) {
        if (auto const error_message = self->_cpp.setup(); !error_message.has_value()) {
            self.volumeSlider.value = self->_cpp.kernel->sine_volume();
        } else {
            [YASViewControllerUtils showErrorAlertWithMessage:(__bridge NSString *)to_cf_object(error_message.value())
                                             toViewController:self];
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    if (self.isMovingFromParentViewController) {
        self->_cpp.dispose();
    }

    [super viewWillDisappear:animated];
}

- (IBAction)volumeChanged:(UISlider *)slider {
    self->_cpp.kernel->set_sine_volume(slider.value);
}

@end
