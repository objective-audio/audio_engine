//
//  YASAudioAVFConverterSampleViewController.mm
//

#import "YASAudioAVFConverterSampleViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <audio/yas_audio_umbrella.h>
#import "YASViewControllerUtils.h"
#import "yas_audio_sample_kernel.h"

#include <iostream>

using namespace yas;

namespace yas::sample {
struct avf_converter_vc_cpp {
    audio::engine::manager_ptr const _manager;
    audio::engine::avf_au_ptr const _converter;
    audio::engine::tap_ptr const _tap;
    chaining::observer_pool _pool;

    avf_converter_vc_cpp()
        : _manager(audio::engine::manager::make_shared()),
          _converter(audio::engine::avf_au::make_shared(kAudioUnitType_FormatConverter, kAudioUnitSubType_AUConverter)),
          _tap(audio::engine::tap::make_shared()) {
    }

    void setup() {
        auto const &io = this->_manager->add_io();

        auto const output_format = io->device().value()->output_format();
        double const output_sample_rate = output_format->sample_rate();
        double const input_sample_rate = output_sample_rate == 44100 ? 22050 : 44100;
        auto asbd = output_format->stream_description();
        asbd.mSampleRate = input_sample_rate;
        auto const input_format = audio::format{asbd};

        auto kernel = std::make_shared<audio::sample_kernel_t>();
        kernel->set_sine_volume(0.1);

        this->_tap->set_render_handler(
            [kernel](audio::engine::node::render_args args) { kernel->process(std::nullopt, args.buffer); });

        this->_manager->connect(this->_converter->node(), io->node(), *output_format);
        this->_manager->connect(this->_tap->node(), this->_converter->node(), input_format);

        this->_pool += this->_converter->load_state_chain()
                           .perform([this](auto const &state) {
                               std::cout << "load_state : " << to_string(state) << std::endl;
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

@end

@implementation YASAudioAVFConverterSampleViewController {
    sample::avf_converter_vc_cpp _cpp;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (self.isMovingToParentViewController) {
        NSError *error = nil;

        if ([[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error]) {
            [[AVAudioSession sharedInstance] setActive:YES error:&error];
        }

        if (!error) {
            self->_cpp.setup();
        } else {
            [YASViewControllerUtils showErrorAlertWithMessage:error.description toViewController:self];
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    if (self.isMovingFromParentViewController) {
        self->_cpp.dispose();

        [[AVAudioSession sharedInstance] setActive:NO error:nil];
    }

    [super viewWillDisappear:animated];
}

@end
