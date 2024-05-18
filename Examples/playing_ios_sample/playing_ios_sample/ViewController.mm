//
//  ViewController.m
//

#import "ViewController.h"
#import <cpp-utils/objc_ptr.h>
#import <objc-utils/unowned.h>
#import "yas_playing_sample_controller.hpp"

using namespace yas;
using namespace yas::playing;

namespace yas::playing::sample {
struct view_controller_cpp {
    audio::io_device_ptr device;
    std::shared_ptr<sample::controller> controller{nullptr};

    observing::value::holder_ptr<bool> const is_playing = observing::value::holder<bool>::make_shared(false);
    observing::value::holder_ptr<renderer_format> const config = observing::value::holder<renderer_format>::make_shared(
        renderer_format{.sample_rate = 0, .pcm_format = audio::pcm_format::other, .channel_count = 0});

    observing::canceller_pool pool;

    view_controller_cpp() {
        auto const session = audio::ios_session::shared();
        this->device = audio::ios_device::make_renewable_device(session);
        auto result = session->activate();
        this->controller = sample::controller::make_shared(this->device);
    }
};
}  // namespace yas::playing::sample

@interface ViewController ()

@property (nonatomic, weak) IBOutlet UIButton *playButton;
@property (nonatomic, weak) IBOutlet UIButton *resetButton;
@property (nonatomic, weak) IBOutlet UIButton *minusButton;
@property (nonatomic, weak) IBOutlet UIButton *plusButton;
@property (nonatomic, weak) IBOutlet UIStepper *chMappingStepper;
@property (nonatomic, weak) IBOutlet UILabel *chMappingLabel;
@property (nonatomic, weak) IBOutlet UISlider *frequencySlider;
@property (nonatomic, weak) IBOutlet UILabel *playFrameLabel;
@property (nonatomic, weak) IBOutlet UILabel *formatLabel;
@property (nonatomic, weak) IBOutlet UILabel *stateLabel;
@property (nonatomic, weak) IBOutlet UILabel *frequencyLabel;

@property (nonatomic) CADisplayLink *frameDisplayLink;
@property (nonatomic) CADisplayLink *statusDisplayLink;

@end

@implementation ViewController {
    sample::view_controller_cpp _cpp;
}

- (void)dealloc {
    [self.frameDisplayLink invalidate];
    [self.statusDisplayLink invalidate];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.minusButton setTitle:@"minus1s" forState:UIControlStateNormal];
    [self.plusButton setTitle:@"plus1s" forState:UIControlStateNormal];
    [self.resetButton setTitle:@"reset" forState:UIControlStateNormal];

    auto unowned_self = objc_ptr_with_move_object([[YASUnownedObject<ViewController *> alloc] initWithObject:self]);

    auto const &controller = self->_cpp.controller;
    auto &pool = self->_cpp.pool;

    self.frequencySlider.value = controller->frequency->value();

    controller->coordinator
        ->observe_is_playing([unowned_self](auto const &is_playing) {
            ViewController *viewController = [unowned_self.object() object];
            viewController->_cpp.is_playing->set_value(is_playing);
        })
        .sync()
        ->add_to(pool);

    controller->coordinator
        ->observe_format([unowned_self](auto const &config) {
            ViewController *viewController = [unowned_self.object() object];
            viewController->_cpp.config->set_value(config);
        })
        .sync()
        ->add_to(pool);

    controller->frequency
        ->observe([unowned_self](float const &) {
            ViewController *viewController = [unowned_self.object() object];
            [viewController _updateFrequencyLabel];
        })
        .sync()
        ->add_to(pool);

    controller->ch_mapping_idx
        ->observe([unowned_self](channel_index_t const &) {
            ViewController *viewController = [unowned_self.object() object];
            [viewController _updateChMappingLabel];
        })
        .sync()
        ->add_to(pool);

    self->_cpp.is_playing
        ->observe([unowned_self](bool const &is_playing) {
            NSString *title = is_playing ? @"Stop" : @"Play";
            ViewController *viewController = [unowned_self.object() object];
            [viewController.playButton setTitle:title forState:UIControlStateNormal];
        })
        .sync()
        ->add_to(pool);

    self->_cpp.config
        ->observe([unowned_self](auto const &) {
            ViewController *viewController = [unowned_self.object() object];
            [viewController _updateFormatLabel];
        })
        .sync()
        ->add_to(pool);

    self.frameDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(_updatePlayFrame:)];
    self.frameDisplayLink.preferredFramesPerSecond = 30;
    [self.frameDisplayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];

    self.statusDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(_updateStateLabel:)];
    self.statusDisplayLink.preferredFramesPerSecond = 10;
    [self.statusDisplayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}

- (IBAction)playButtonTapped:(UIButton *)sender {
    auto &coordinator = self->_cpp.controller->coordinator;
    coordinator->set_playing(!coordinator->is_playing());
}

- (IBAction)resetButtonTapped:(UIButton *)sender {
    self->_cpp.controller->seek_zero();
}

- (IBAction)minusButtonTapped:(UIButton *)sender {
    self->_cpp.controller->seek_minus_one_sec();
}

- (IBAction)plusButtonTapped:(UIButton *)sender {
    self->_cpp.controller->seek_plus_one_sec();
}

- (IBAction)frequencyChanged:(UISlider *)sender {
    self->_cpp.controller->frequency->set_value(std::round(sender.value));
}

- (IBAction)chMappingChanged:(UIStepper *)sender {
    self->_cpp.controller->ch_mapping_idx->set_value(static_cast<channel_index_t>(sender.value));
}

- (void)_updateFormatLabel {
    std::vector<std::string> texts;

    auto const &coordinator = self->_cpp.controller->coordinator;
    texts.emplace_back("sample rate : " + std::to_string(coordinator->format().sample_rate));
    texts.emplace_back("channel count : " + std::to_string(coordinator->format().channel_count));
    texts.emplace_back("pcm format : " + to_string(coordinator->format().pcm_format));

    std::string text = joined(texts, "\n");

    self.formatLabel.text = (__bridge NSString *)to_cf_object(text);
}

- (void)_updateStateLabel:(CADisplayLink *)displayLink {
    std::vector<std::string> ch_texts;
    self.stateLabel.text = (__bridge NSString *)to_cf_object(joined(ch_texts, "\n"));
}

- (void)_updatePlayFrame:(CADisplayLink *)displayLink {
    std::string const play_frame_str =
        "play_frame : " + std::to_string(self->_cpp.controller->coordinator->current_frame());
    self.playFrameLabel.text = (__bridge NSString *)to_cf_object(play_frame_str);
}

- (void)_updateFrequencyLabel {
    self.frequencyLabel.text = [NSString stringWithFormat:@"%.1fHz", self->_cpp.controller->frequency->value()];
}

- (void)_updateChMappingLabel {
    self.chMappingLabel.text = [NSString stringWithFormat:@"%@", @(self->_cpp.controller->ch_mapping_idx->value())];
}

@end
