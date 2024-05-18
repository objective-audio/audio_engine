//
//  ViewController.m
//

#import "ViewController.h"
#import <cpp-utils/objc_ptr.h>
#import <objc-utils/unowned.h>

using namespace yas;
using namespace yas::playing;

namespace yas::playing::sample {
struct view_controller_cpp {
    std::shared_ptr<sample::controller> const controller =
        sample::controller::make_shared(audio::mac_device::renewable_default_output_device());

    observing::value::holder_ptr<bool> const is_playing = observing::value::holder<bool>::make_shared(false);
    observing::value::holder_ptr<renderer_format> const config = observing::value::holder<renderer_format>::make_shared(
        renderer_format{.sample_rate = 0, .pcm_format = audio::pcm_format::other, .channel_count = 0});

    observing::canceller_pool pool;
};
}  // namespace yas::playing::sample

@interface ViewController ()

@property (nonatomic, weak) IBOutlet NSButton *playButton;
@property (nonatomic, weak) IBOutlet NSButton *resetButton;
@property (nonatomic, weak) IBOutlet NSButton *minusButton;
@property (nonatomic, weak) IBOutlet NSButton *plusButton;
@property (nonatomic, weak) IBOutlet NSStepper *chMappingStepper;
@property (nonatomic, weak) IBOutlet NSTextField *chMappingLabel;
@property (nonatomic, weak) IBOutlet NSSlider *frequencySlider;
@property (nonatomic, weak) IBOutlet NSTextField *playFrameLabel;
@property (nonatomic, weak) IBOutlet NSTextField *formatLabel;
@property (nonatomic, weak) IBOutlet NSTextField *stateLabel;
@property (nonatomic, weak) IBOutlet NSTextField *frequencyLabel;

@property (nonatomic) NSTimer *frameTimer;
@property (nonatomic) NSTimer *statusTimer;

@end

@implementation ViewController {
    sample::view_controller_cpp _cpp;
}

- (void)dealloc {
    [self.frameTimer invalidate];
    [self.statusTimer invalidate];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.minusButton setTitle:@"minus1s"];
    [self.plusButton setTitle:@"plus1s"];
    [self.resetButton setTitle:@"reset"];

    auto unowned_self = objc_ptr_with_move_object([[YASUnownedObject<ViewController *> alloc] initWithObject:self]);

    auto const &controller = self->_cpp.controller;
    auto &pool = self->_cpp.pool;

    self.frequencySlider.floatValue = controller->frequency->value();

    controller->coordinator
        ->observe_is_playing([unowned_self](auto const &is_playing) {
            auto *viewController = [unowned_self.object() object];
            viewController->_cpp.is_playing->set_value(is_playing);
        })
        .sync()
        ->add_to(pool);

    controller->coordinator
        ->observe_format([unowned_self](auto const &config) {
            auto *viewController = [unowned_self.object() object];
            viewController->_cpp.config->set_value(config);
        })
        .sync()
        ->add_to(pool);

    controller->frequency
        ->observe([unowned_self](float const &frequency) {
            ViewController *viewController = [unowned_self.object() object];
            [viewController _updateFrequencyLabel];
        })
        .sync()
        ->add_to(pool);

    controller->ch_mapping_idx
        ->observe([unowned_self](auto const &) {
            ViewController *viewController = [unowned_self.object() object];
            [viewController _updateChMappingLabel];
        })
        .sync()
        ->add_to(pool);

    self->_cpp.is_playing
        ->observe([unowned_self](bool const &is_playing) {
            NSString *title = is_playing ? @"Stop" : @"Play";
            ViewController *viewController = [unowned_self.object() object];
            [viewController.playButton setTitle:title];
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

    self.frameTimer = [NSTimer timerWithTimeInterval:1.0 / 30.0
                                              target:self
                                            selector:@selector(_updatePlayFrame:)
                                            userInfo:nil
                                             repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.frameTimer forMode:NSRunLoopCommonModes];

    self.statusTimer = [NSTimer timerWithTimeInterval:1.0 / 10.0
                                               target:self
                                             selector:@selector(_updateStateLabel:)
                                             userInfo:nil
                                              repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.statusTimer forMode:NSRunLoopCommonModes];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
}

- (IBAction)playButtonTapped:(NSButton *)sender {
    auto &coordinator = self->_cpp.controller->coordinator;
    coordinator->set_playing(!coordinator->is_playing());
}

- (IBAction)resetButtonTapped:(NSButton *)sender {
    self->_cpp.controller->seek_zero();
}

- (IBAction)minusButtonTapped:(NSButton *)sender {
    self->_cpp.controller->seek_minus_one_sec();
}

- (IBAction)plusButtonTapped:(NSButton *)sender {
    self->_cpp.controller->seek_plus_one_sec();
}

- (IBAction)freqencySliderChanged:(NSSlider *)sender {
    self->_cpp.controller->frequency->set_value(sender.floatValue);
}

- (IBAction)chMappingChanged:(NSStepper *)sender {
    self->_cpp.controller->ch_mapping_idx->set_value(sender.integerValue);
}

- (void)_updateFormatLabel {
    std::vector<std::string> texts;

    auto const &format = self->_cpp.controller->coordinator->format();
    texts.emplace_back("sample rate : " + std::to_string(format.sample_rate));
    texts.emplace_back("channel count : " + std::to_string(format.channel_count));
    texts.emplace_back("pcm format : " + to_string(format.pcm_format));

    std::string text = joined(texts, "\n");

    self.formatLabel.stringValue = (__bridge NSString *)to_cf_object(text);
}

- (void)_updateStateLabel:(NSTimer *)timer {
    std::vector<std::string> ch_texts;
    self.stateLabel.stringValue = (__bridge NSString *)to_cf_object(joined(ch_texts, "\n"));
}

- (void)_updatePlayFrame:(NSTimer *)timer {
    std::string const play_frame_str =
        "play_frame : " + std::to_string(self->_cpp.controller->coordinator->current_frame());
    self.playFrameLabel.stringValue = (__bridge NSString *)to_cf_object(play_frame_str);
}

- (void)_updateFrequencyLabel {
    self.frequencyLabel.stringValue = [NSString stringWithFormat:@"%.1fHz", self->_cpp.controller->frequency->value()];
}

- (void)_updateChMappingLabel {
    self.chMappingLabel.stringValue =
        [NSString stringWithFormat:@"%@", @(self->_cpp.controller->ch_mapping_idx->value())];
}

@end
