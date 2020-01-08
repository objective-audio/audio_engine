//
//  YASAudioAVFConverterSampleViewController.mm
//

#import "YASAudioAVFConverterSampleViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <audio/yas_audio_umbrella.h>
#include <cpp_utils/yas_fast_each.h>
#import "YASViewControllerUtils.h"
#import "yas_audio_sample_kernel.h"

#include <iostream>

using namespace yas;

namespace yas::sample {
struct avf_converter_vc_cpp {
    audio::ios_session_ptr const session = audio::ios_session::shared();
    audio::ios_device_ptr const device = audio::ios_device::make_shared(this->session);
    audio::graph_ptr const graph;
    audio::graph_avf_au_ptr const converter;
    audio::graph_tap_ptr tap;
    chaining::observer_pool pool;
    audio::sample_kernel_ptr kernel;

    avf_converter_vc_cpp()
        : graph(audio::graph::make_shared()),
          converter(audio::graph_avf_au::make_shared(kAudioUnitType_FormatConverter, kAudioUnitSubType_AUConverter)),
          tap(audio::graph_tap::make_shared()) {
    }

    void setup() {
        auto const &io = this->graph->add_io(this->device);

        auto const output_format = this->device->output_format();
        double const output_sample_rate = output_format->sample_rate();
        double const input_sample_rate = output_sample_rate == 44100 ? 22050 : 44100;
        auto asbd = output_format->stream_description();
        asbd.mSampleRate = input_sample_rate;
        auto const input_format = audio::format{asbd};

        this->graph->connect(this->converter->node(), io->node(), *output_format);
        this->graph->connect(this->tap->node(), this->converter->node(), input_format);

        this->kernel = std::make_shared<audio::sample_kernel_t>();
        this->kernel->set_sine_volume(0.1);
        this->kernel->set_sine_frequency(1000.0);

        this->tap->set_render_handler([kernel = this->kernel](audio::graph_node::render_args args) {
            kernel->process(std::nullopt, args.buffer);
        });

        this->pool += this->converter->load_state_chain()
                          .perform([this](auto const &state) {
                              if (state == audio::avf_au::load_state::loaded) {
                                  this->graph->start_render();
                              }
                          })
                          .sync();
    }

    void dispose() {
        this->pool.invalidate();

        this->graph->remove_io();
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
        self->_cpp.session->set_category(audio::ios_session::category::playback);

        if (auto const result = self->_cpp.session->activate()) {
            self->_cpp.setup();
            self.volumeSlider.value = self->_cpp.kernel->sine_volume();
        } else {
            [YASViewControllerUtils showErrorAlertWithMessage:(__bridge NSString *)to_cf_object(result.error())
                                             toViewController:self];
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    if (self.isMovingFromParentViewController) {
        self->_cpp.dispose();

        self->_cpp.session->deactivate();
    }

    [super viewWillDisappear:animated];
}

- (IBAction)volumeChanged:(UISlider *)slider {
    self->_cpp.kernel->set_sine_volume(slider.value);
}

@end
