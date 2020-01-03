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
    audio::engine::manager_ptr const _manager;
    audio::engine::avf_au_ptr const _converter;
    audio::engine::tap_ptr _tap;
    chaining::observer_pool _pool;
    audio::sample_kernel_ptr _kernel;

    avf_converter_vc_cpp()
        : _manager(audio::engine::manager::make_shared()),
          _converter(audio::engine::avf_au::make_shared(kAudioUnitType_FormatConverter, kAudioUnitSubType_AUConverter)),
          _tap(audio::engine::tap::make_shared()) {
    }

    void setup() {
        auto const &io = this->_manager->add_io(this->device);

        auto const output_format = this->device->output_format();
        double const output_sample_rate = output_format->sample_rate();
        double const input_sample_rate = output_sample_rate == 44100 ? 22050 : 44100;
        auto asbd = output_format->stream_description();
        asbd.mSampleRate = input_sample_rate;
        auto const input_format = audio::format{asbd};

        this->_manager->connect(this->_converter->node(), io->node(), *output_format);
        this->_manager->connect(this->_tap->node(), this->_converter->node(), input_format);

        this->_kernel = std::make_shared<audio::sample_kernel_t>();
        this->_kernel->set_sine_volume(0.1);
        this->_kernel->set_sine_frequency(1000.0);

        this->_tap->set_render_handler([kernel = this->_kernel](audio::engine::node::render_args args) {
            kernel->process(std::nullopt, args.buffer);
        });

        this->_pool += this->_converter->load_state_chain()
                           .perform([this](auto const &state) {
                               if (state == audio::engine::avf_au::load_state::loaded) {
                                   this->_manager->start_render();
                               }
                           })
                           .sync();
    }

    void dispose() {
        this->_pool.invalidate();

        this->_manager->remove_io();
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
            self.volumeSlider.value = self->_cpp._kernel->sine_volume();
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
    self->_cpp._kernel->set_sine_volume(slider.value);
}

@end
