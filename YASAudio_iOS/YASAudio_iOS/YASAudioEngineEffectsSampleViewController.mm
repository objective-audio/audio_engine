//
//  YASAudioEngineEffectsSampleViewController.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioEngineEffectsSampleViewController.h"
#import "YASAudioEngineEffectsSampleEditViewController.h"
#import "yas_audio.h"

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

namespace yas
{
    namespace sample
    {
        struct effects_vc_internal {
            yas::audio_engine engine;
            yas::audio_unit_output_node output_node;
            yas::audio_connection through_connection = nullptr;
            yas::audio_tap_node tap_node;
            yas::audio_unit_node effect_node = nullptr;

            void replace_effect_node(const AudioComponentDescription *acd)
            {
                if (effect_node) {
                    engine.disconnect(effect_node);
                    effect_node = nullptr;
                }

                if (through_connection) {
                    engine.disconnect(through_connection);
                    through_connection = nullptr;
                }

                auto format = yas::audio_format([AVAudioSession sharedInstance].sampleRate, 2);

                if (acd) {
                    effect_node = yas::audio_unit_node(*acd);
                    engine.connect(effect_node, output_node, format);
                    engine.connect(tap_node, effect_node, format);
                } else {
                    through_connection = engine.connect(tap_node, output_node, format);
                }
            }
        };
    }
}

@implementation YASAudioEngineEffectsSampleViewController {
    std::vector<yas::audio_unit> _audio_units;
    std::experimental::optional<UInt32> _index;
    yas::sample::effects_vc_internal _internal;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    if (self.isMovingToParentViewController) {
        BOOL success = NO;
        NSString *errorMessage = nil;
        NSError *error = nil;

        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        if ([audioSession setCategory:AVAudioSessionCategoryPlayback error:&error]) {
            [self setupAudioEngine];
            auto start_result = _internal.engine.start_render();
            if (start_result) {
                success = YES;
                [self.tableView reloadData];
            } else {
                const auto error_string = yas::to_string(start_result.error());
                errorMessage = (__bridge NSString *)yas::to_cf_object(error_string);
            }
        } else {
            errorMessage = error.description;
        }

        if (!success) {
            [self _showErrorAlertWithMessage:errorMessage];
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    if (self.isMovingFromParentViewController) {
        if (_internal.engine) {
            _internal.engine.stop();
        }

        NSError *error = nil;
        if (![[AVAudioSession sharedInstance] setActive:NO error:&error]) {
            NSLog(@"error : %@", error);
        }
    }
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    if (!_index) {
        return NO;
    }
    return YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    id destinationViewController = segue.destinationViewController;
    if ([destinationViewController isKindOfClass:[YASAudioEngineEffectsSampleEditViewController class]]) {
        YASAudioEngineEffectsSampleEditViewController *controller = destinationViewController;
        [controller set_audio_unit_node:_internal.effect_node];
    }
}

#pragma mark -

- (void)setupAudioEngine
{
    if (_audio_units.size() == 0) {
        AudioComponent component = NULL;

        while (true) {
            component = AudioComponentFindNext(component, &baseAcd);
            if (component != NULL) {
                AudioComponentDescription acd;
                yas_raise_if_au_error(AudioComponentGetDescription(component, &acd));
                _audio_units.push_back(yas::audio_unit(acd));
            } else {
                break;
            }
        }
    }

    _internal = yas::sample::effects_vc_internal();

    Float64 phase = 0;

    auto tap_render_function =
        [phase](yas::audio_pcm_buffer &buffer, const UInt32 bus_idx, const yas::audio_time &when) mutable {
            buffer.clear();

            const Float64 start_phase = phase;
            const Float64 phase_per_frame = 1000.0 / buffer.format().sample_rate() * yas::audio_math::two_pi;
            yas::audio::frame_enumerator enumerator(buffer);
            const auto *flex_ptr = enumerator.pointer();
            const UInt32 length = enumerator.frame_length();

            UInt32 idx = 0;
            while (flex_ptr->v) {
                if (idx == 0) {
                    phase = yas::audio_math::fill_sine(flex_ptr->f32, length, start_phase, phase_per_frame);
                }
                idx++;
                yas_audio_frame_enumerator_move_channel(enumerator);
            }
        };

    _internal.tap_node.set_render_function(tap_render_function);

    _internal.replace_effect_node(nullptr);
}

#pragma mark -

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (_internal.engine) {
        return YASAudioEngineEffectsSampleSectionCount;
    }
    return 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case YASAudioEngineEffectsSampleSectionNone:
            return 1;
        case YASAudioEngineEffectsSampleSectionEffects:
            return _audio_units.size();
        default:
            return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case YASAudioEngineEffectsSampleSectionEffects:
            return @"Effects";
        default:
            break;
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [self _dequeueCellWithIndexPath:indexPath];

    if (indexPath.section == YASAudioEngineEffectsSampleSectionNone) {
        cell.textLabel.text = @"None";
        if (!_index) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }
    } else if (indexPath.section == YASAudioEngineEffectsSampleSectionEffects) {
        const auto &audio_unit = _audio_units.at(indexPath.row);
        cell.textLabel.text = (__bridge NSString *)audio_unit.name();
        if (_index && indexPath.row == *_index) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case YASAudioEngineEffectsSampleSectionNone: {
            _index = yas::nullopt;
            _internal.replace_effect_node(nullptr);
        } break;
        case YASAudioEngineEffectsSampleSectionEffects: {
            _index = static_cast<UInt32>(indexPath.row);
            AudioComponentDescription acd = baseAcd;
            const auto &audio_unit = _audio_units.at(indexPath.row);
            acd.componentSubType = audio_unit.sub_type();
            _internal.replace_effect_node(&acd);
        } break;
    }

    [tableView
          reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, YASAudioEngineEffectsSampleSectionCount)]
        withRowAnimation:UITableViewRowAnimationAutomatic];
}

#pragma mark - Private

- (void)_showErrorAlertWithMessage:(NSString *)message
{
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

- (UITableViewCell *)_dequeueCellWithIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.textLabel.text = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    return cell;
}

@end
