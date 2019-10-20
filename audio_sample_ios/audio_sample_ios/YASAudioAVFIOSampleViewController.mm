//
//  YASAudioAVFIOSampleViewController.mm
//

#import "YASAudioAVFIOSampleViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <cpp_utils/yas_objc_ptr.h>
#import "YASViewControllerUtils.h"
#import "yas_audio_sample_kernel.h"

using namespace yas;

using sample_kernel_t = audio::sample::kernel;
using sample_kernel_ptr = std::shared_ptr<sample_kernel_t>;

namespace yas::sample {
struct avf_io_vc_internal {
    audio::graph_ptr graph = nullptr;
    audio::io_ptr avf_io = nullptr;
    sample_kernel_ptr kernel = nullptr;
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
    sample::avf_io_vc_internal _internal;
    objc_ptr<NSNumberFormatter *> _formatter;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self->_formatter = objc_ptr_with_move_object([[NSNumberFormatter alloc] init]);
    self->_formatter.object().numberStyle = NSNumberFormatterDecimalStyle;
    self->_formatter.object().minimumFractionDigits = 1;
    self->_formatter.object().maximumFractionDigits = 1;
}

- (void)setup {
    self->_internal.graph = audio::graph::make_shared();
    self->_internal.avf_io = audio::io::make_shared(audio::avf_device::make_shared());
    self->_internal.graph->add_io(self->_internal.avf_io);

    self->_internal.kernel = std::make_shared<sample_kernel_t>();

    auto weak_io = to_weak(self->_internal.avf_io);
    self->_internal.avf_io->set_render_handler([weak_io, kernel = self->_internal.kernel](auto args) {
        if (auto avf_io = weak_io.lock()) {
            kernel->process(avf_io->input_buffer_on_render(), args.output_buffer);
        }
    });

    if (self->_internal.graph) {
        self->_internal.graph->start();
    }

    self.throughVolumeSlider.value = self->_internal.kernel->through_volume();
    self.sineVolumeSlider.value = self->_internal.kernel->sine_volume();
    self.sineFrequencySlider.value = self->_internal.kernel->sine_frequency();
    [self updateThroughVolumeLabel];
    [self updateSineVolumeLabel];
    [self updateSineFrequencyLabel];
}

- (void)dispose {
    self->_internal.graph = nullptr;
    self->_internal.avf_io = nullptr;
    self->_internal.kernel = nullptr;
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
            [YASViewControllerUtils showErrorAlertWithMessage:error.description toViewController:self];
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    if (self.isMovingFromParentViewController) {
        if (self->_internal.graph) {
            self->_internal.graph->stop();
        }

        [self dispose];

        [[AVAudioSession sharedInstance] setActive:NO error:nil];
    }
}

- (IBAction)throughVolumeValueChanged:(UISlider *)sender {
    self->_internal.kernel->set_througn_volume(sender.value);
    [self updateThroughVolumeLabel];
}

- (IBAction)sineVolumeValueChanged:(UISlider *)sender {
    self->_internal.kernel->set_sine_volume(sender.value);
    [self updateSineVolumeLabel];
}

- (IBAction)sineFrequencyValueChanged:(UISlider *)sender {
    self->_internal.kernel->set_sine_frequency(sender.value);
    [self updateSineFrequencyLabel];
}

- (void)updateThroughVolumeLabel {
    NSString *string = [self->_formatter.object()
        stringFromNumber:@(audio::math::decibel_from_linear(self->_internal.kernel->through_volume()))];
    self.throughVolumeLabel.text = [NSString stringWithFormat:@"%@ dB", string];
}

- (void)updateSineVolumeLabel {
    NSString *string = [self->_formatter.object()
        stringFromNumber:@(audio::math::decibel_from_linear(self->_internal.kernel->sine_volume()))];
    self.sineVolumeLabel.text = [NSString stringWithFormat:@"%@ dB", string];
}

- (void)updateSineFrequencyLabel {
    NSString *string = [self->_formatter.object() stringFromNumber:@(self->_internal.kernel->sine_frequency())];
    self.sineFrequencyLabel.text = [NSString stringWithFormat:@"%@ Hz", string];
}

@end
