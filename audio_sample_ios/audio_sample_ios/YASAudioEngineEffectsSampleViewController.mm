//
//  YASAudioEngineEffectsSampleViewController.m
//

#import "YASAudioEngineEffectsSampleEditViewController.h"
#import "YASAudioEngineEffectsSampleViewController.h"
#import "yas_audio.h"

using namespace yas;

typedef NS_ENUM(NSUInteger, YASAudioEngineEffectsSampleSection) {
    YASAudioEngineEffectsSampleSectionNone,
    YASAudioEngineEffectsSampleSectionEffects,
    YASAudioEngineEffectsSampleSectionCount,
};

static const AudioComponentDescription baseAcd = {.componentType = kAudioUnitType_Effect,
                                                  .componentSubType = 0,
                                                  .componentManufacturer = kAudioUnitManufacturer_Apple,
                                                  .componentFlags = 0,
                                                  .componentFlagsMask = 0};

@interface YASAudioEngineEffectsSampleViewController ()

@end

namespace yas::sample {
struct effects_vc_internal {
    audio::engine::manager manager;
    audio::engine::au_output au_output;
    audio::engine::connection through_connection = nullptr;
    audio::engine::tap tap;
    audio::engine::au effect_au = nullptr;

    void replace_effect_au(const AudioComponentDescription *acd) {
        if (effect_au) {
            manager.disconnect(effect_au.node());
            effect_au = nullptr;
        }

        if (through_connection) {
            manager.disconnect(through_connection);
            through_connection = nullptr;
        }

        auto format = audio::format({.sample_rate = [AVAudioSession sharedInstance].sampleRate, .channel_count = 2});

        if (acd) {
            effect_au = audio::engine::au(*acd);
            manager.connect(effect_au.node(), au_output.au_io().au().node(), format);
            manager.connect(tap.node(), effect_au.node(), format);
        } else {
            through_connection = manager.connect(tap.node(), au_output.au_io().au().node(), format);
        }
    }
};
}

@implementation YASAudioEngineEffectsSampleViewController {
    std::vector<audio::unit> _units;
    std::experimental::optional<uint32_t> _index;
    sample::effects_vc_internal _internal;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (self.isMovingToParentViewController) {
        BOOL success = NO;
        NSString *errorMessage = nil;
        NSError *error = nil;

        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        if ([audioSession setCategory:AVAudioSessionCategoryPlayback error:&error]) {
            [self setupAudioEngine];
            auto start_result = _internal.manager.start_render();
            if (start_result) {
                success = YES;
                [self.tableView reloadData];
            } else {
                auto const error_string = to_string(start_result.error());
                errorMessage = (__bridge NSString *)to_cf_object(error_string);
            }
        } else {
            errorMessage = error.description;
        }

        if (!success) {
            [self _showErrorAlertWithMessage:errorMessage];
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    if (self.isMovingFromParentViewController) {
        if (_internal.manager) {
            _internal.manager.stop();
        }

        NSError *error = nil;
        if (![[AVAudioSession sharedInstance] setActive:NO error:&error]) {
            NSLog(@"error : %@", error);
        }
    }
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    if (!_index) {
        return NO;
    }
    return YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    id destinationViewController = segue.destinationViewController;
    if ([destinationViewController isKindOfClass:[YASAudioEngineEffectsSampleEditViewController class]]) {
        YASAudioEngineEffectsSampleEditViewController *controller = destinationViewController;
        [controller set_engine_au:_internal.effect_au];
    }
}

#pragma mark -

- (void)setupAudioEngine {
    if (_units.size() == 0) {
        AudioComponent component = NULL;

        while (true) {
            component = AudioComponentFindNext(component, &baseAcd);
            if (component != NULL) {
                AudioComponentDescription acd;
                raise_if_raw_audio_error(AudioComponentGetDescription(component, &acd));
                _units.push_back(audio::unit(acd));
            } else {
                break;
            }
        }
    }

    _internal = sample::effects_vc_internal();

    double phase = 0;

    auto tap_render_handler = [phase](auto args) mutable {
        auto &buffer = args.buffer;

        buffer.clear();

        double const start_phase = phase;
        double const phase_per_frame = 1000.0 / buffer.format().sample_rate() * audio::math::two_pi;

        auto each = audio::make_each_data<float>(buffer);
        auto const length = buffer.frame_length();

        while (yas_each_data_next_ch(each)) {
            if (yas_each_data_index(each) == 0) {
                phase = audio::math::fill_sine(yas_each_data_ptr(each), length, start_phase, phase_per_frame);
            }
        }
    };

    _internal.tap.set_render_handler(tap_render_handler);

    _internal.replace_effect_au(nullptr);
}

#pragma mark -

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (_internal.manager) {
        return YASAudioEngineEffectsSampleSectionCount;
    }
    return 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case YASAudioEngineEffectsSampleSectionNone:
            return 1;
        case YASAudioEngineEffectsSampleSectionEffects:
            return _units.size();
        default:
            return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case YASAudioEngineEffectsSampleSectionEffects:
            return @"Effects";
        default:
            break;
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self _dequeueCellWithIndexPath:indexPath];

    if (indexPath.section == YASAudioEngineEffectsSampleSectionNone) {
        cell.textLabel.text = @"None";
        if (!_index) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }
    } else if (indexPath.section == YASAudioEngineEffectsSampleSectionEffects) {
        auto const &unit = _units.at(indexPath.row);
        cell.textLabel.text = (__bridge NSString *)unit.name();
        if (_index && indexPath.row == *_index) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case YASAudioEngineEffectsSampleSectionNone: {
            _index = yas::nullopt;
            _internal.replace_effect_au(nullptr);
        } break;
        case YASAudioEngineEffectsSampleSectionEffects: {
            _index = static_cast<uint32_t>(indexPath.row);
            AudioComponentDescription acd = baseAcd;
            auto const &unit = _units.at(indexPath.row);
            acd.componentSubType = unit.sub_type();
            _internal.replace_effect_au(&acd);
        } break;
    }

    [tableView
          reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, YASAudioEngineEffectsSampleSectionCount)]
        withRowAnimation:UITableViewRowAnimationAutomatic];
}

#pragma mark - Private

- (void)_showErrorAlertWithMessage:(NSString *)message {
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"Error"
                                                                        message:message
                                                                 preferredStyle:UIAlertControllerStyleAlert];
    [controller addAction:[UIAlertAction actionWithTitle:@"OK"
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction *action) {
                                                     [self.navigationController popViewControllerAnimated:YES];
                                                 }]];
    [self presentViewController:controller animated:YES completion:NULL];
}

- (UITableViewCell *)_dequeueCellWithIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.textLabel.text = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    return cell;
}

@end
