//
//  YASAudioAVFIOSampleViewController.mm
//

#import "YASAudioAVFIOSampleViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <cpp_utils/yas_objc_ptr.h>
#import "YASViewControllerUtils.h"
#import "yas_audio_sample_kernel.h"

using namespace yas;

namespace yas::sample {
struct avf_io_vc_cpp {
    audio::ios_session_ptr const session = audio::ios_session::shared();
    audio::ios_device_ptr const device = audio::ios_device::make_shared(this->session);
    std::optional<audio::io_ptr> io = std::nullopt;
    std::optional<audio::sample_kernel_ptr> kernel = std::nullopt;

    objc_ptr<NSNumberFormatter *> formatter = objc_ptr_with_move_object([[NSNumberFormatter alloc] init]);

    avf_io_vc_cpp() {
        this->formatter.object().numberStyle = NSNumberFormatterDecimalStyle;
        this->formatter.object().minimumFractionDigits = 1;
        this->formatter.object().maximumFractionDigits = 1;
    }
};
}

@interface YASAudioAVFIOSampleViewController ()

@property (nonatomic, assign) IBOutlet UISlider *throughVolumeSlider;
@property (nonatomic, assign) IBOutlet UISlider *sineVolumeSlider;
@property (nonatomic, assign) IBOutlet UISlider *sineFrequencySlider;
@property (nonatomic, assign) IBOutlet UILabel *throughVolumeLabel;
@property (nonatomic, assign) IBOutlet UILabel *sineVolumeLabel;
@property (nonatomic, assign) IBOutlet UILabel *sineFrequencyLabel;

@end

@implementation YASAudioAVFIOSampleViewController {
    sample::avf_io_vc_cpp _cpp;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)setup {
    self->_cpp.session->set_category(audio::ios_session::category::play_and_record);

    if (auto const result = self->_cpp.session->activate(); !result) {
        [YASViewControllerUtils showErrorAlertWithMessage:(__bridge NSString *)to_cf_object(result.error())
                                         toViewController:self];
        return;
    }

    auto const io = audio::io::make_shared(self->_cpp.device);
    auto const kernel = std::make_shared<audio::sample_kernel_t>();

    self->_cpp.io = io;
    self->_cpp.kernel = kernel;

    auto weak_io = to_weak(io);
    io->set_render_handler([weak_io, kernel](auto args) {
        if (auto shared_io = weak_io.lock()) {
            kernel->process(shared_io->input_buffer_on_render(), args.output_buffer);
        }
    });

    io->start();

    self.throughVolumeSlider.value = kernel->through_volume();
    self.sineVolumeSlider.value = kernel->sine_volume();
    self.sineFrequencySlider.value = kernel->sine_frequency();
    [self updateThroughVolumeLabel];
    [self updateSineVolumeLabel];
    [self updateSineFrequencyLabel];
}

- (void)dispose {
    if (auto const &io = self->_cpp.io) {
        io.value()->stop();
    }

    self->_cpp.io = std::nullopt;
    self->_cpp.kernel = std::nullopt;

    self->_cpp.session->deactivate();
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

- (IBAction)throughVolumeValueChanged:(UISlider *)sender {
    self->_cpp.kernel.value()->set_througn_volume(sender.value);
    [self updateThroughVolumeLabel];
}

- (IBAction)sineVolumeValueChanged:(UISlider *)sender {
    self->_cpp.kernel.value()->set_sine_volume(sender.value);
    [self updateSineVolumeLabel];
}

- (IBAction)sineFrequencyValueChanged:(UISlider *)sender {
    self->_cpp.kernel.value()->set_sine_frequency(sender.value);
    [self updateSineFrequencyLabel];
}

- (void)updateThroughVolumeLabel {
    NSString *string = [self->_cpp.formatter.object()
        stringFromNumber:@(audio::math::decibel_from_linear(self->_cpp.kernel.value()->through_volume()))];
    self.throughVolumeLabel.text = [NSString stringWithFormat:@"%@ dB", string];
}

- (void)updateSineVolumeLabel {
    NSString *string = [self->_cpp.formatter.object()
        stringFromNumber:@(audio::math::decibel_from_linear(self->_cpp.kernel.value()->sine_volume()))];
    self.sineVolumeLabel.text = [NSString stringWithFormat:@"%@ dB", string];
}

- (void)updateSineFrequencyLabel {
    NSString *string = [self->_cpp.formatter.object() stringFromNumber:@(self->_cpp.kernel.value()->sine_frequency())];
    self.sineFrequencyLabel.text = [NSString stringWithFormat:@"%@ Hz", string];
}

@end
