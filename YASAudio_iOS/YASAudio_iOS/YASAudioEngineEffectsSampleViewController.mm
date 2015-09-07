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

@implementation YASAudioEngineEffectsSampleViewController {
    std::vector<yas::audio_unit_sptr> _audio_units;
    std::experimental::optional<UInt32> _index;
    yas::audio_engine_sptr _engine;
    yas::audio_unit_output_node_sptr _output_node;
    yas::audio_unit_node_sptr _effect_node;
    yas::audio_connection_sptr _through_connection;
    yas::audio_tap_node_sptr _tap_node;
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
            auto start_result = _engine->start_render();
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
        if (_engine) {
            _engine->stop();
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
        [controller set_audio_unit_node:_effect_node];
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
                _audio_units.push_back(yas::audio_unit::create(acd));
            } else {
                break;
            }
        }
    }

    _engine = yas::audio_engine::create();
    _output_node = yas::audio_unit_output_node::create();
    _tap_node = yas::audio_tap_node::create();

    Float64 phase = 0;

    auto tap_render_function = [phase](const yas::audio_pcm_buffer_sptr &buffer, const UInt32 bus_idx,
                                       const yas::audio_time_sptr &when) mutable {
        buffer->clear();

        const Float64 start_phase = phase;
        const Float64 phase_per_frame = 1000.0 / buffer->format()->sample_rate() * yas::audio_math::two_pi;
        yas::audio_frame_enumerator enumerator(buffer);
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

    _tap_node->set_render_function(tap_render_function);

    [self replaceEffectNodeWithAudioComponentDescription:NULL];
}

- (void)replaceEffectNodeWithAudioComponentDescription:(const AudioComponentDescription *)acd
{
    if (!_engine) {
        [NSException raise:NSInternalInconsistencyException format:@"audio_engine is null."];
        return;
    }

    if (_effect_node) {
        _engine->disconnect(_effect_node);
        _effect_node = nullptr;
    }

    if (_through_connection) {
        _engine->disconnect(_through_connection);
        _through_connection = nullptr;
    }

    auto format = yas::audio_format::create([AVAudioSession sharedInstance].sampleRate, 2);

    if (acd) {
        _effect_node = yas::audio_unit_node::create(*acd);
        _engine->connect(_effect_node, _output_node, format);
        _engine->connect(_tap_node, _effect_node, format);
    } else {
        _through_connection = _engine->connect(_tap_node, _output_node, format);
    }
}

#pragma mark -

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (_engine) {
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
        const auto &name = audio_unit->name();
        CFStringRef cf_name = yas::to_cf_object(name);
        cell.textLabel.text = (__bridge NSString *)cf_name;
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
            _index = std::experimental::nullopt;
            [self replaceEffectNodeWithAudioComponentDescription:nullptr];
        } break;
        case YASAudioEngineEffectsSampleSectionEffects: {
            _index = static_cast<UInt32>(indexPath.row);
            AudioComponentDescription acd = baseAcd;
            const auto &audio_unit = _audio_units.at(indexPath.row);
            acd.componentSubType = audio_unit->sub_type();
            [self replaceEffectNodeWithAudioComponentDescription:&acd];
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
