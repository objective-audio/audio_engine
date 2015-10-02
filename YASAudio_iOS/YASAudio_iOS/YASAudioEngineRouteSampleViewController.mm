//
//  YASAudioEngineRouteSampleViewController.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioEngineRouteSampleViewController.h"
#import "YASAudioEngineRouteSampleSelectionViewController.h"
#import "YASAudioSliderCell.h"
#import "yas_audio.h"

static UInt32 const YASAudioEngineRouteSampleDestinationChannelCount = 2;

typedef NS_ENUM(NSUInteger, YASAudioEngineRouteSampleSection) {
    YASAudioEngineRouteSampleSectionSlider,
    YASAudioEngineRouteSampleSectionDestinations,
    YASAudioEngineRouteSampleSectionCount,
};

typedef NS_ENUM(NSUInteger, YASAudioEngineRouteSampleSourceIndex) {
    YASAudioEngineRouteSampleSourceIndexSine,
    YASAudioEngineRouteSampleSourceIndexInput,
    YASAudioEngineRouteSampleSourceIndexCount,
};

@interface YASAudioEngineRouteSampleViewController ()

@property (nonatomic, strong) IBOutlet UISlider *slider;

@end

@implementation YASAudioEngineRouteSampleViewController {
    yas::audio_engine_sptr _engine;
    yas::audio_unit_io_node_sptr _io_node;
    yas::audio_unit_mixer_node_sptr _mixer_node;
    yas::audio_route_node_sptr _route_node;
    yas::audio_tap_node_sptr _sine_node;

    yas::observer_sptr _engine_observer;

    std::shared_ptr<yas::objc_weak_container> _self_container;
}

- (void)dealloc
{
    YASRelease(_slider);

    _slider = nil;

    if (_self_container) {
        _self_container->set_object(nil);
    }

    YASSuperDealloc;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    if (self.isMovingToParentViewController) {
        BOOL success = NO;
        NSString *errorMessage = nil;
        NSError *error = nil;

        if ([[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&error]) {
            [self setupEngine];

            const auto start_result = _engine->start_render();
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
        if (_engine) {
            _engine->stop();
        }

        [[AVAudioSession sharedInstance] setActive:NO error:nil];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(UITableViewCell *)cell
{
    id destinationViewController = segue.destinationViewController;
    if ([destinationViewController isKindOfClass:[YASAudioEngineRouteSampleSelectionViewController class]]) {
        YASAudioEngineRouteSampleSelectionViewController *controller = destinationViewController;
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        controller.fromCellIndexPath = indexPath;
    }
}

- (IBAction)unwindForSegue:(UIStoryboardSegue *)segue
{
    id sourceViewController = segue.sourceViewController;
    if ([sourceViewController isKindOfClass:[YASAudioEngineRouteSampleSelectionViewController class]]) {
        YASAudioEngineRouteSampleSelectionViewController *controller = sourceViewController;
        NSIndexPath *fromIndexPath = controller.fromCellIndexPath;
        NSIndexPath *selectedIndexPath = controller.selectedIndexPath;

        if (selectedIndexPath) {
            const auto dst_bus_idx = 0;
            const auto dst_ch_idx = static_cast<UInt32>(fromIndexPath.row);
            UInt32 src_bus_idx = -1;
            UInt32 src_ch_idx = -1;

            if (selectedIndexPath.section == YASAudioEngineRouteSampleSelectionSectionSine) {
                src_bus_idx = YASAudioEngineRouteSampleSourceIndexSine;
                src_ch_idx = static_cast<UInt32>(selectedIndexPath.row);
            } else if (selectedIndexPath.section == YASAudioEngineRouteSampleSelectionSectionInput) {
                src_bus_idx = YASAudioEngineRouteSampleSourceIndexInput;
                src_ch_idx = static_cast<UInt32>(selectedIndexPath.row);
            }

            if (src_bus_idx == -1 || src_ch_idx == -1) {
                _route_node->remove_route_for_destination({dst_bus_idx, dst_ch_idx});
            } else {
                _route_node->add_route({src_bus_idx, src_ch_idx, dst_bus_idx, dst_ch_idx});
            }

            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:fromIndexPath.section]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (!_engine) {
        return 0;
    }

    return YASAudioEngineRouteSampleSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (!_engine) {
        return 0;
    }

    switch (section) {
        case YASAudioEngineRouteSampleSectionSlider:
            return 1;
        case YASAudioEngineRouteSampleSectionDestinations:
            return YASAudioEngineRouteSampleDestinationChannelCount;
        default:
            break;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case YASAudioEngineRouteSampleSectionSlider: {
            YASAudioSliderCell *cell =
                [tableView dequeueReusableCellWithIdentifier:@"SliderCell" forIndexPath:indexPath];
            return cell;
        }

        case YASAudioEngineRouteSampleSectionDestinations: {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
            const auto &routes = _route_node->routes();
            yas::audio_route::point dst_point{0, static_cast<UInt32>(indexPath.row)};
            auto it = std::find_if(routes.begin(), routes.end(),
                                   [dst_point = std::move(dst_point)](const yas::audio_route &route) {
                                       return route.destination == dst_point;
                                   });
            NSString *sourceIndexText = nil;
            if (it != routes.end()) {
                const auto &route = *it;
                sourceIndexText =
                    [NSString stringWithFormat:@"bus=%@ ch=%@", @(route.source.bus), @(route.source.channel)];
            } else {
                sourceIndexText = @"None";
            }
            cell.textLabel.text =
                [NSString stringWithFormat:@"Destination : %@ - Source : %@", @(indexPath.row), sourceIndexText];
            return cell;
        }
    }

    return nil;
}

#pragma mark -

- (IBAction)volumeSliderChanged:(UISlider *)sender
{
    const Float32 value = sender.value;
    if (_mixer_node) {
        _mixer_node->set_input_volume(value, 0);
    }
}

#pragma mark -

- (void)setupEngine
{
    _engine = yas::audio_engine::create();
    _io_node = yas::audio_unit_io_node::create();
    _mixer_node = yas::audio_unit_mixer_node::create();
    _route_node = yas::audio_route_node::create();
    _sine_node = yas::audio_tap_node::create();

    _mixer_node->set_input_volume(1.0, 0);
    _route_node->set_routes({{0, 0, 0, 0}, {0, 1, 0, 1}});

    Float64 phase = 0;

    auto tap_render_function =
        [phase](const yas::audio_pcm_buffer_sptr &buffer, const UInt32 bus_idx, const yas::audio_time &when) mutable {
            buffer->clear();

            const Float64 start_phase = phase;
            const Float64 phase_per_frame = 1000.0 / buffer->format().sample_rate() * yas::audio_math::two_pi;
            yas::audio_frame_enumerator enumerator(buffer);
            const auto *flex_ptr = enumerator.pointer();
            const UInt32 length = enumerator.frame_length();

            while (flex_ptr->v) {
                phase = yas::audio_math::fill_sine(flex_ptr->f32, length, start_phase, phase_per_frame);
                yas_audio_frame_enumerator_move_channel(enumerator);
            }
        };

    _sine_node->set_render_function(tap_render_function);

    if (!_self_container) {
        _self_container = std::make_shared<yas::objc_weak_container>(self);
    }

    _engine_observer = yas::observer::create();
    _engine_observer->add_handler(
        _engine->subject(), yas::audio_engine_method::configuration_change,
        [weak_container = _self_container](const auto &method, const auto &sender) {
            if (auto strong_self = weak_container->lock()) {
                if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
                    YASAudioEngineRouteSampleViewController *controller = strong_self.object();
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
    _engine->disconnect(_mixer_node);
    _engine->disconnect(_route_node);
    _engine->disconnect(_sine_node);
    _engine->disconnect(_io_node);
}

- (void)_connectNodes
{
    const Float64 sample_rate = _io_node->device_sample_rate();

    const auto format = yas::audio_format(sample_rate, 2);

    _engine->connect(_mixer_node, _io_node, format);
    _engine->connect(_route_node, _mixer_node, format);
    _engine->connect(_sine_node, _route_node, 0, YASAudioEngineRouteSampleSourceIndexSine, format);
    _engine->connect(_io_node, _route_node, 1, YASAudioEngineRouteSampleSourceIndexInput, format);
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

- (void)_updateSlider
{
    if (_mixer_node) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:YASAudioEngineRouteSampleSectionSlider];
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        if (cell) {
            for (UIView *view in cell.contentView.subviews) {
                if ([view isKindOfClass:[UISlider class]]) {
                    UISlider *slider = (UISlider *)view;
                    slider.value = _mixer_node->input_volume(0);
                }
            }
        }
    }
}

@end
