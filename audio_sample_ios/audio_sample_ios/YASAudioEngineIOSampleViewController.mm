//
//  YASAudioEngineIOSampleViewController.m
//

#import "YASAudioEngineIOSampleViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <audio/audio.h>
#import <cpp_utils/yas_objc_ptr.h>
#import <objc_utils/yas_objc_unowned.h>
#import "YASAudioEngineIOSampleSelectionViewController.h"
#import "YASAudioSliderCell.h"
#import "YASViewControllerUtils.h"

using namespace yas;

static uint32_t const YASAudioEngineIOSampleConnectionMaxChannels = 2;

typedef NS_ENUM(NSUInteger, YASAudioEngineIOSampleSection) {
    YASAudioEngineIOSampleSectionInfo,
    YASAudioEngineIOSampleSectionSlider,
    YASAudioEngineIOSampleSectionNotify,
    YASAudioEngineIOSampleSectionChannelMapOutput,
    YASAudioEngineIOSampleSectionChannelMapInput,
    YASAudioEngineIOSampleSectionChannelRouteOutput,
    YASAudioEngineIOSampleSectionChannelRouteInput,
    YASAudioEngineIOSampleSectionCount,
};

@interface YASAudioEngineIOSampleViewController ()

@property (nonatomic, strong) IBOutlet UISlider *slider;

@end

namespace yas::sample {
struct engine_io_vc_internal {
    audio::engine::manager_ptr manager = audio::engine::manager::make_shared();
    audio::engine::au_mixer_ptr au_mixer = audio::engine::au_mixer::make_shared();
    audio::engine::au_io_ptr au_io = audio::engine::au_io::make_shared();

    chaining::any_observer_ptr engine_observer = nullptr;

    engine_io_vc_internal() {
        this->au_mixer->set_input_volume(1.0, 0);
    }

    audio::direction direction_for_section(const NSInteger section) {
        if (section - YASAudioEngineIOSampleSectionChannelMapOutput) {
            return audio::direction::input;
        } else {
            return audio::direction::output;
        }
    }

    uint32_t connection_channel_count_for_direction(const audio::direction dir) {
        switch (dir) {
            case audio::direction::output:
                return MIN(this->au_io->output_device_channel_count(), YASAudioEngineIOSampleConnectionMaxChannels);
            case audio::direction::input:
                return MIN(this->au_io->input_device_channel_count(), YASAudioEngineIOSampleConnectionMaxChannels);
            default:
                return 0;
        }
    }

    uint32_t device_channel_count_for_direction(const audio::direction dir) {
        switch (dir) {
            case audio::direction::output:
                return this->au_io->output_device_channel_count();
            case audio::direction::input:
                return this->au_io->input_device_channel_count();
            default:
                return 0;
        }
    }

    uint32_t device_channel_count_for_section(const NSInteger section) {
        switch (section) {
            case YASAudioEngineIOSampleSectionChannelMapOutput:
                return this->au_io->output_device_channel_count();
            case YASAudioEngineIOSampleSectionChannelMapInput:
                return this->au_io->input_device_channel_count();
            default:
                return 0;
        }
    }
};
}

@implementation YASAudioEngineIOSampleViewController {
    sample::engine_io_vc_internal _internal;
}

- (void)dealloc {
    yas_release(_slider);

    _slider = nil;

    yas_super_dealloc();
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (self.isMovingToParentViewController) {
        BOOL success = NO;
        NSString *errorMessage = nil;
        NSError *error = nil;

        if ([[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryMultiRoute error:&error]) {
            [[AVAudioSession sharedInstance] setActive:YES error:&error];
        }

        if (!error) {
            [self setupEngine];

            auto const start_result = _internal.manager->start_render();
            if (start_result) {
                [self.tableView reloadData];
                [self _updateSlider];
                success = YES;
            } else {
                auto const error_string = to_string(start_result.error());
                errorMessage = (__bridge NSString *)to_cf_object(error_string);
            }
        } else {
            errorMessage = error.description;
        }

        if (!success) {
            [YASViewControllerUtils showErrorAlertWithMessage:errorMessage toViewController:self];
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    if (self.isMovingFromParentViewController) {
        if (_internal.manager) {
            _internal.manager->stop();
        }

        [[AVAudioSession sharedInstance] setActive:NO error:nil];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(UITableViewCell *)cell {
    id destinationViewController = segue.destinationViewController;
    if ([destinationViewController isKindOfClass:[YASAudioEngineIOSampleSelectionViewController class]]) {
        YASAudioEngineIOSampleSelectionViewController *controller = destinationViewController;
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        controller.fromCellIndexPath = indexPath;
        switch (indexPath.section) {
            case YASAudioEngineIOSampleSectionChannelMapOutput:
            case YASAudioEngineIOSampleSectionChannelMapInput: {
                auto dir = _internal.direction_for_section(indexPath.section);
                controller.channelCount = _internal.connection_channel_count_for_direction(dir);
            }

            break;
            default:
                break;
        }
    }
}

- (IBAction)unwindForSegue:(UIStoryboardSegue *)segue {
    id sourceViewController = segue.sourceViewController;
    if ([sourceViewController isKindOfClass:[YASAudioEngineIOSampleSelectionViewController class]]) {
        YASAudioEngineIOSampleSelectionViewController *controller = sourceViewController;
        NSIndexPath *indexPath = controller.fromCellIndexPath;
        auto dir = _internal.direction_for_section(indexPath.section);

        auto map = _internal.au_io->channel_map(dir);
        if (map.empty()) {
            auto channel_count = _internal.device_channel_count_for_direction(dir);
            map.resize(channel_count, -1);
        }

        auto &value = map.at(indexPath.row);
        value = controller.selectedValue;

        _internal.au_io->set_channel_map(map, dir);

        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:indexPath.section]
                      withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

- (IBAction)volumeSliderChanged:(UISlider *)sender {
    float const value = sender.value;
    if (_internal.au_mixer) {
        _internal.au_mixer->set_input_volume(value, 0);
    }
}

- (void)setupEngine {
    _internal = sample::engine_io_vc_internal();

    auto unowned_self = objc_ptr_with_move_object([[YASUnownedObject alloc] initWithObject:self]);

    _internal.engine_observer =
        _internal.manager->chain(audio::engine::manager::method::configuration_change)
            .perform([unowned_self](auto const &) {
                if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
                    [[unowned_self.object() object] _updateEngine];
                }
            })
            .end();

    [self _connectNodes];
}

- (void)_updateEngine {
    [self _disconnectNodes];
    [self _connectNodes];

    [self.tableView reloadData];
    [self _updateSlider];
}

- (void)_disconnectNodes {
    _internal.manager->disconnect(_internal.au_mixer->au().node());
}

- (void)_connectNodes {
    double const sample_rate = 44100;

    auto const output_channel_count = _internal.connection_channel_count_for_direction(audio::direction::output);
    if (output_channel_count > 0) {
        auto output_format = audio::format({.sample_rate = sample_rate, .channel_count = output_channel_count});
        _internal.manager->connect(_internal.au_mixer->au().node(), _internal.au_io->au().node(), output_format);
    }

    auto const input_channel_count = _internal.connection_channel_count_for_direction(audio::direction::input);
    if (input_channel_count > 0) {
        auto input_format = audio::format({.sample_rate = sample_rate, .channel_count = input_channel_count});
        _internal.manager->connect(_internal.au_io->au().node(), _internal.au_mixer->au().node(), input_format);
    }
}

#pragma mark -

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (!_internal.manager) {
        return 0;
    }

    return YASAudioEngineIOSampleSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (!_internal.manager) {
        return 0;
    }

    switch (section) {
        case YASAudioEngineIOSampleSectionInfo:
        case YASAudioEngineIOSampleSectionSlider:
        case YASAudioEngineIOSampleSectionNotify:
            return 1;
        case YASAudioEngineIOSampleSectionChannelMapOutput:
        case YASAudioEngineIOSampleSectionChannelMapInput:
            return _internal.device_channel_count_for_section(section) + 1;
        case YASAudioEngineIOSampleSectionChannelRouteOutput:
            return [AVAudioSession sharedInstance].currentRoute.outputs.count;
        case YASAudioEngineIOSampleSectionChannelRouteInput:
            return [AVAudioSession sharedInstance].currentRoute.inputs.count;
    }
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case YASAudioEngineIOSampleSectionInfo:
        case YASAudioEngineIOSampleSectionSlider:
        case YASAudioEngineIOSampleSectionNotify:
            return nil;
        case YASAudioEngineIOSampleSectionChannelMapOutput:
            return @"Output Channel Map";
        case YASAudioEngineIOSampleSectionChannelMapInput:
            return @"Input Channel Map";
        case YASAudioEngineIOSampleSectionChannelRouteOutput:
            return @"Output Channel Routes";
        case YASAudioEngineIOSampleSectionChannelRouteInput:
            return @"Input Channel Routes";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case YASAudioEngineIOSampleSectionInfo: {
            UITableViewCell *cell = [self _dequeueNormalCellWithIndexPath:indexPath];
            cell.textLabel.text =
                [NSString stringWithFormat:@"sr:%@ out:%@ in:%@", @(_internal.au_io->device_sample_rate()),
                                           @(_internal.au_io->output_device_channel_count()),
                                           @(_internal.au_io->input_device_channel_count())];
            return cell;
        } break;

        case YASAudioEngineIOSampleSectionSlider: {
            YASAudioSliderCell *cell = [self _dequeueSliderWithIndexPath:indexPath];
            cell.slider.value = _internal.au_mixer->input_volume(0);
            return cell;
        } break;

        case YASAudioEngineIOSampleSectionNotify: {
            UITableViewCell *cell = [self _dequeueNormalCellWithIndexPath:indexPath];
            cell.textLabel.text = @"Send Notify";
            return cell;
        } break;

        case YASAudioEngineIOSampleSectionChannelMapOutput:
        case YASAudioEngineIOSampleSectionChannelMapInput: {
            UITableViewCell *cell = [self _dequeueChannelMapCellWithIndexPath:indexPath];

            audio::direction dir = _internal.direction_for_section(indexPath.section);
            uint32_t map_size = _internal.device_channel_count_for_direction(dir);

            if (indexPath.row < map_size) {
                auto const &map = _internal.au_io->channel_map(dir);
                NSString *selected = nil;
                if (map.empty()) {
                    selected = @"empty";
                } else {
                    selected = [NSString stringWithFormat:@"%@", @(map.at(indexPath.row))];
                }
                cell.textLabel.text = [NSString stringWithFormat:@"%@ - %@", @(indexPath.row), selected];
            } else {
                cell.textLabel.text = @"Clear";
            }

            return cell;
        } break;

        case YASAudioEngineIOSampleSectionChannelRouteOutput: {
            AVAudioSessionPortDescription *port = [AVAudioSession sharedInstance].currentRoute.outputs[indexPath.row];
            UITableViewCell *cell = [self _dequeueNormalCellWithIndexPath:indexPath];
            cell.textLabel.text =
                [NSString stringWithFormat:@"name:%@ channels:%@", port.portName, @(port.channels.count)];
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            return cell;
        } break;

        case YASAudioEngineIOSampleSectionChannelRouteInput: {
            AVAudioSessionPortDescription *port = [AVAudioSession sharedInstance].currentRoute.inputs[indexPath.row];
            UITableViewCell *cell = [self _dequeueNormalCellWithIndexPath:indexPath];
            cell.textLabel.text =
                [NSString stringWithFormat:@"name:%@ channels:%@", port.portName, @(port.channels.count)];
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            return cell;
        } break;
    }

    return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case YASAudioEngineIOSampleSectionNotify: {
            if (_internal.manager) {
                auto const &manager = _internal.manager;
                manager->notifier()->notify(
                    std::make_pair(audio::engine::manager::method::configuration_change, manager));
            }
        } break;

        case YASAudioEngineIOSampleSectionChannelMapOutput:
        case YASAudioEngineIOSampleSectionChannelMapInput: {
            audio::direction dir = _internal.direction_for_section(indexPath.section);
            auto map = _internal.au_io->channel_map(dir);
            if (indexPath.row == _internal.device_channel_count_for_section(indexPath.section)) {
                map.clear();
                _internal.au_io->set_channel_map(map, dir);

                [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:indexPath.section]
                              withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        } break;

        case YASAudioEngineIOSampleSectionChannelRouteOutput: {
            AVAudioSessionPortDescription *port = [AVAudioSession sharedInstance].currentRoute.outputs[indexPath.row];
            auto map = to_channel_map(port.channels, audio::direction::output);
            _internal.au_io->set_channel_map(map, audio::direction::output);

            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:YASAudioEngineIOSampleSectionChannelMapOutput]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
        } break;

        case YASAudioEngineIOSampleSectionChannelRouteInput: {
            AVAudioSessionPortDescription *port = [AVAudioSession sharedInstance].currentRoute.inputs[indexPath.row];
            auto map = to_channel_map(port.channels, audio::direction::input);
            _internal.au_io->set_channel_map(map, audio::direction::input);

            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:YASAudioEngineIOSampleSectionChannelMapInput]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
        } break;
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark -

- (YASAudioSliderCell *)_dequeueSliderWithIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"SliderCell" forIndexPath:indexPath];
    cell.textLabel.text = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    return (YASAudioSliderCell *)cell;
}

- (UITableViewCell *)_dequeueNormalCellWithIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.textLabel.text = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    return cell;
}

- (UITableViewCell *)_dequeueChannelMapCellWithIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < _internal.device_channel_count_for_section(indexPath.section)) {
        UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"PushCell" forIndexPath:indexPath];
        cell.textLabel.text = nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    } else {
        return [self _dequeueNormalCellWithIndexPath:indexPath];
    }
}

- (void)_updateSlider {
    if (_internal.au_mixer) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:YASAudioEngineIOSampleSectionSlider];
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        if (cell) {
            for (UIView *view in cell.contentView.subviews) {
                if ([view isKindOfClass:[UISlider class]]) {
                    UISlider *slider = (UISlider *)view;
                    slider.value = _internal.au_mixer->input_volume(0);
                }
            }
        }
    }
}

@end
