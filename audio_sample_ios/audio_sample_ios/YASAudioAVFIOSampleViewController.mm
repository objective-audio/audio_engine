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
    std::optional<audio::sample::kernel_ptr> kernel = std::nullopt;

    objc_ptr<NSNumberFormatter *> formatter = objc_ptr_with_move_object([[NSNumberFormatter alloc] init]);

    avf_io_vc_cpp() {
        this->formatter.object().numberStyle = NSNumberFormatterDecimalStyle;
        this->formatter.object().minimumFractionDigits = 1;
        this->formatter.object().maximumFractionDigits = 1;
    }

    std::optional<std::string> setup() {
        this->session->set_category(audio::ios_session::category::play_and_record);

        if (auto const result = this->session->activate(); !result) {
            return result.error();
        }

        auto const io = audio::io::make_shared(this->device);
        auto const kernel = audio::sample::kernel::make_shared();

        this->io = io;
        this->kernel = kernel;

        auto weak_io = to_weak(io);
        io->set_render_handler([weak_io, kernel](audio::io_render_args args) {
            if (auto shared_io = weak_io.lock()) {
                kernel->process(shared_io->input_buffer_on_render(),
                                args.output_buffer ? args.output_buffer.value().get() : nullptr);
            }
        });

        io->start();

        return std::nullopt;
    }

    void dispose() {
        if (auto const &io = this->io) {
            io.value()->stop();
        }

        this->io = std::nullopt;
        this->kernel = std::nullopt;

        this->session->deactivate();
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

    if (auto const error_message = self->_cpp.setup()) {
        [YASViewControllerUtils showErrorAlertWithMessage:(__bridge NSString *)to_cf_object(*error_message)
                                         toViewController:self];
        return;
    }

    if (auto const &kernel = self->_cpp.kernel) {
        self.throughVolumeSlider.value = kernel.value()->through_volume();
        self.sineVolumeSlider.value = kernel.value()->sine_volume();
        self.sineFrequencySlider.value = kernel.value()->sine_frequency();
        [self updateThroughVolumeLabel];
        [self updateSineVolumeLabel];
        [self updateSineFrequencyLabel];
    }
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
        self->_cpp.dispose();
    }
}

- (IBAction)throughVolumeValueChanged:(UISlider *)sender {
    if (auto const &kernel = self->_cpp.kernel) {
        kernel.value()->set_througn_volume(sender.value);
        [self updateThroughVolumeLabel];
    }
}

- (IBAction)sineVolumeValueChanged:(UISlider *)sender {
    if (auto const &kernel = self->_cpp.kernel) {
        kernel.value()->set_sine_volume(sender.value);
        [self updateSineVolumeLabel];
    }
}

- (IBAction)sineFrequencyValueChanged:(UISlider *)sender {
    if (auto const &kernel = self->_cpp.kernel) {
        kernel.value()->set_sine_frequency(sender.value);
        [self updateSineFrequencyLabel];
    }
}

- (void)updateThroughVolumeLabel {
    if (auto const &kernel = self->_cpp.kernel) {
        NSString *string = [self->_cpp.formatter.object()
            stringFromNumber:@(audio::math::decibel_from_linear(kernel.value()->through_volume()))];
        self.throughVolumeLabel.text = [NSString stringWithFormat:@"%@ dB", string];
    }
}

- (void)updateSineVolumeLabel {
    if (auto const &kernel = self->_cpp.kernel) {
        NSString *string = [self->_cpp.formatter.object()
            stringFromNumber:@(audio::math::decibel_from_linear(kernel.value()->sine_volume()))];
        self.sineVolumeLabel.text = [NSString stringWithFormat:@"%@ dB", string];
    }
}

- (void)updateSineFrequencyLabel {
    if (auto const &kernel = self->_cpp.kernel) {
        NSString *string = [self->_cpp.formatter.object() stringFromNumber:@(kernel.value()->sine_frequency())];
        self.sineFrequencyLabel.text = [NSString stringWithFormat:@"%@ Hz", string];
    }
}

@end
