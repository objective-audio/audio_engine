//
//  YASAudioEngineIOSampleViewController.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioEngineIOSampleViewController.h"
#import "YASAudioEngineIOSampleSelectionViewController.h"
#import "YASAudioSliderCell.h"
#import "yas_audio.h"

static UInt32 const YASAudioEngineIOSampleConnectionMaxChannels = 2;

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

namespace yas
{
    namespace sample
    {
        struct engine_io_vc_internal {
            yas::audio::engine engine;
            yas::audio::unit_mixer_node mixer_node;
            yas::audio::unit_io_node io_node;

            yas::base engine_observer = nullptr;
            yas::objc::container<yas::objc::weak> self_container;

            engine_io_vc_internal()
            {
                mixer_node.set_input_volume(1.0, 0);
            }

            yas::direction direction_for_section(const NSInteger section)
            {
                if (section - YASAudioEngineIOSampleSectionChannelMapOutput) {
                    return yas::direction::input;
                } else {
                    return yas::direction::output;
                }
            }

            UInt32 connection_channel_count_for_direction(const yas::direction dir)
            {
                switch (dir) {
                    case yas::direction::output:
                        return MIN(io_node.output_device_channel_count(), YASAudioEngineIOSampleConnectionMaxChannels);
                    case yas::direction::input:
                        return MIN(io_node.input_device_channel_count(), YASAudioEngineIOSampleConnectionMaxChannels);
                    default:
                        return 0;
                }
            }

            UInt32 device_channel_count_for_direction(const yas::direction dir)
            {
                switch (dir) {
                    case yas::direction::output:
                        return io_node.output_device_channel_count();
                    case yas::direction::input:
                        return io_node.input_device_channel_count();
                    default:
                        return 0;
                }
            }

            UInt32 device_channel_count_for_section(const NSInteger section)
            {
                switch (section) {
                    case YASAudioEngineIOSampleSectionChannelMapOutput:
                        return io_node.output_device_channel_count();
                    case YASAudioEngineIOSampleSectionChannelMapInput:
                        return io_node.input_device_channel_count();
                    default:
                        return 0;
                }
            }
        };
    }
}

@implementation YASAudioEngineIOSampleViewController {
    yas::sample::engine_io_vc_internal _internal;
}

- (void)dealloc
{
    YASRelease(_slider);

    _slider = nil;

    YASSuperDealloc;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    if (self.isMovingToParentViewController) {
        BOOL success = NO;
        NSString *errorMessage = nil;
        NSError *error = nil;

        if ([[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryMultiRoute error:&error]) {
            [self setupEngine];

            const auto start_result = _internal.engine.start_render();
            if (start_result) {
                [self.tableView reloadData];
                [self _updateSlider];
                success = YES;
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

        [[AVAudioSession sharedInstance] setActive:NO error:nil];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(UITableViewCell *)cell
{
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

- (IBAction)unwindForSegue:(UIStoryboardSegue *)segue
{
    id sourceViewController = segue.sourceViewController;
    if ([sourceViewController isKindOfClass:[YASAudioEngineIOSampleSelectionViewController class]]) {
        YASAudioEngineIOSampleSelectionViewController *controller = sourceViewController;
        NSIndexPath *indexPath = controller.fromCellIndexPath;
        auto dir = _internal.direction_for_section(indexPath.section);

        auto map = _internal.io_node.channel_map(dir);
        if (map.empty()) {
            auto channel_count = _internal.device_channel_count_for_direction(dir);
            map.resize(channel_count, -1);
        }

        auto &value = map.at(indexPath.row);
        value = controller.selectedValue;

        _internal.io_node.set_channel_map(map, dir);

        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:indexPath.section]
                      withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

- (IBAction)volumeSliderChanged:(UISlider *)sender
{
    const Float32 value = sender.value;
    if (_internal.mixer_node) {
        _internal.mixer_node.set_input_volume(value, 0);
    }
}

- (void)setupEngine
{
    _internal = yas::sample::engine_io_vc_internal();

    if (!_internal.self_container) {
        _internal.self_container.set_object(self);
    }

    _internal.engine_observer = _internal.engine.subject().make_observer(
        yas::audio_engine_method::configuration_change,
        [weak_container = _internal.self_container](const auto &method, const auto &sender) {
            if (auto strong_self = weak_container.lock()) {
                if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
                    YASAudioEngineIOSampleViewController *controller = strong_self.object();
                    [controller _updateEngine];
                }
            }
        });

    [self _connectNodes];
}

- (void)_updateEngine
{
    [self _disconnectNodes];
    [self _connectNodes];

    [self.tableView reloadData];
    [self _updateSlider];
}

- (void)_disconnectNodes
{
    _internal.engine.disconnect(_internal.mixer_node);
}

- (void)_connectNodes
{
    const Float64 sample_rate = _internal.io_node.device_sample_rate();

    const auto output_channel_count = _internal.connection_channel_count_for_direction(yas::direction::output);
    if (output_channel_count > 0) {
        auto output_format = yas::audio::format(sample_rate, output_channel_count);
        _internal.engine.connect(_internal.mixer_node, _internal.io_node, output_format);
    }

    const auto input_channel_count = _internal.connection_channel_count_for_direction(yas::direction::input);
    if (input_channel_count > 0) {
        auto input_format = yas::audio::format(sample_rate, input_channel_count);
        _internal.engine.connect(_internal.io_node, _internal.mixer_node, input_format);
    }
}

#pragma mark -

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (!_internal.engine) {
        return 0;
    }

    return YASAudioEngineIOSampleSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (!_internal.engine) {
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

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
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

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case YASAudioEngineIOSampleSectionInfo: {
            UITableViewCell *cell = [self _dequeueNormalCellWithIndexPath:indexPath];
            cell.textLabel.text =
                [NSString stringWithFormat:@"sr:%@ out:%@ in:%@", @(_internal.io_node.device_sample_rate()),
                                           @(_internal.io_node.output_device_channel_count()),
                                           @(_internal.io_node.input_device_channel_count())];
            return cell;
        } break;

        case YASAudioEngineIOSampleSectionSlider: {
            YASAudioSliderCell *cell = [self _dequeueSliderWithIndexPath:indexPath];
            cell.slider.value = _internal.mixer_node.input_volume(0);
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

            yas::direction dir = _internal.direction_for_section(indexPath.section);
            UInt32 map_size = _internal.device_channel_count_for_direction(dir);

            if (indexPath.row < map_size) {
                const auto &map = _internal.io_node.channel_map(dir);
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case YASAudioEngineIOSampleSectionNotify: {
            if (_internal.engine) {
                auto &engine = _internal.engine;
                engine.subject().notify(yas::audio_engine_method::configuration_change, engine);
            }
        } break;

        case YASAudioEngineIOSampleSectionChannelMapOutput:
        case YASAudioEngineIOSampleSectionChannelMapInput: {
            yas::direction dir = _internal.direction_for_section(indexPath.section);
            auto map = _internal.io_node.channel_map(dir);
            if (indexPath.row == _internal.device_channel_count_for_section(indexPath.section)) {
                map.clear();
                _internal.io_node.set_channel_map(map, dir);

                [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:indexPath.section]
                              withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        } break;

        case YASAudioEngineIOSampleSectionChannelRouteOutput: {
            AVAudioSessionPortDescription *port = [AVAudioSession sharedInstance].currentRoute.outputs[indexPath.row];
            auto map = yas::to_channel_map(port.channels, yas::direction::output);
            _internal.io_node.set_channel_map(map, yas::direction::output);

            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:YASAudioEngineIOSampleSectionChannelMapOutput]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
        } break;

        case YASAudioEngineIOSampleSectionChannelRouteInput: {
            AVAudioSessionPortDescription *port = [AVAudioSession sharedInstance].currentRoute.inputs[indexPath.row];
            auto map = yas::to_channel_map(port.channels, yas::direction::input);
            _internal.io_node.set_channel_map(map, yas::direction::input);

            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:YASAudioEngineIOSampleSectionChannelMapInput]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
        } break;
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark -

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

- (YASAudioSliderCell *)_dequeueSliderWithIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"SliderCell" forIndexPath:indexPath];
    cell.textLabel.text = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    return (YASAudioSliderCell *)cell;
}

- (UITableViewCell *)_dequeueNormalCellWithIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.textLabel.text = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    return cell;
}

- (UITableViewCell *)_dequeueChannelMapCellWithIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row < _internal.device_channel_count_for_section(indexPath.section)) {
        UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"PushCell" forIndexPath:indexPath];
        cell.textLabel.text = nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    } else {
        return [self _dequeueNormalCellWithIndexPath:indexPath];
    }
}

- (void)_updateSlider
{
    if (_internal.mixer_node) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:YASAudioEngineIOSampleSectionSlider];
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        if (cell) {
            for (UIView *view in cell.contentView.subviews) {
                if ([view isKindOfClass:[UISlider class]]) {
                    UISlider *slider = (UISlider *)view;
                    slider.value = _internal.mixer_node.input_volume(0);
                }
            }
        }
    }
}

@end
