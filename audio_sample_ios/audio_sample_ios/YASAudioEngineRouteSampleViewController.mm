//
//  YASAudioEngineRouteSampleViewController.m
//

#import "YASAudioEngineRouteSampleSelectionViewController.h"
#import "YASAudioEngineRouteSampleViewController.h"
#import "YASAudioSliderCell.h"
#import "yas_audio.h"
#import "yas_objc_unowned.h"

using namespace yas;

static uint32_t const YASAudioEngineRouteSampleDestinationChannelCount = 2;

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

namespace yas {
namespace sample {
    struct route_vc_internal {
        audio::engine::manager manager;
        audio::engine::au_io au_io;
        audio::engine::au_mixer au_mixer;
        audio::engine::route route;
        audio::engine::tap sine_tap;

        base engine_observer = nullptr;

        void disconnectNodes() {
            manager.disconnect(au_mixer.au().node());
            manager.disconnect(route.node());
            manager.disconnect(sine_tap.node());
            manager.disconnect(au_io.au().node());
        }

        void connect_nodes() {
            auto const sample_rate = au_io.device_sample_rate();

            auto const format = audio::format({.sample_rate = sample_rate, .channel_count = 2});

            manager.connect(au_mixer.au().node(), au_io.au().node(), format);
            manager.connect(route.node(), au_mixer.au().node(), format);
            manager.connect(sine_tap.node(), route.node(), 0, YASAudioEngineRouteSampleSourceIndexSine, format);
            manager.connect(au_io.au().node(), route.node(), 1, YASAudioEngineRouteSampleSourceIndexInput, format);
        }
    };
}
}

@implementation YASAudioEngineRouteSampleViewController {
    sample::route_vc_internal _internal;
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

        if ([[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&error]) {
            [self setupEngine];

            auto const start_result = _internal.manager.start_render();
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

        [[AVAudioSession sharedInstance] setActive:NO error:nil];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(UITableViewCell *)cell {
    id destinationViewController = segue.destinationViewController;
    if ([destinationViewController isKindOfClass:[YASAudioEngineRouteSampleSelectionViewController class]]) {
        YASAudioEngineRouteSampleSelectionViewController *controller = destinationViewController;
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        controller.fromCellIndexPath = indexPath;
    }
}

- (IBAction)unwindForSegue:(UIStoryboardSegue *)segue {
    id sourceViewController = segue.sourceViewController;
    if ([sourceViewController isKindOfClass:[YASAudioEngineRouteSampleSelectionViewController class]]) {
        YASAudioEngineRouteSampleSelectionViewController *controller = sourceViewController;
        NSIndexPath *fromIndexPath = controller.fromCellIndexPath;
        NSIndexPath *selectedIndexPath = controller.selectedIndexPath;

        if (selectedIndexPath) {
            auto const dst_bus_idx = 0;
            auto const dst_ch_idx = static_cast<uint32_t>(fromIndexPath.row);
            uint32_t src_bus_idx = -1;
            uint32_t src_ch_idx = -1;

            if (selectedIndexPath.section == YASAudioEngineRouteSampleSelectionSectionSine) {
                src_bus_idx = YASAudioEngineRouteSampleSourceIndexSine;
                src_ch_idx = static_cast<uint32_t>(selectedIndexPath.row);
            } else if (selectedIndexPath.section == YASAudioEngineRouteSampleSelectionSectionInput) {
                src_bus_idx = YASAudioEngineRouteSampleSourceIndexInput;
                src_ch_idx = static_cast<uint32_t>(selectedIndexPath.row);
            }

            if (src_bus_idx == -1 || src_ch_idx == -1) {
                _internal.route.remove_route_for_destination({dst_bus_idx, dst_ch_idx});
            } else {
                _internal.route.add_route({src_bus_idx, src_ch_idx, dst_bus_idx, dst_ch_idx});
            }

            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:fromIndexPath.section]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (!_internal.manager) {
        return 0;
    }

    return YASAudioEngineRouteSampleSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (!_internal.manager) {
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

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case YASAudioEngineRouteSampleSectionSlider: {
            YASAudioSliderCell *cell =
                [tableView dequeueReusableCellWithIdentifier:@"SliderCell" forIndexPath:indexPath];
            return cell;
        }

        case YASAudioEngineRouteSampleSectionDestinations: {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
            auto const &routes = _internal.route.routes();
            audio::route::point dst_point{0, static_cast<uint32_t>(indexPath.row)};
            auto it = std::find_if(routes.begin(), routes.end(),
                                   [dst_point = std::move(dst_point)](const audio::route &route) {
                                       return route.destination == dst_point;
                                   });
            NSString *sourceIndexText = nil;
            if (it != routes.end()) {
                auto const &route = *it;
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

- (IBAction)volumeSliderChanged:(UISlider *)sender {
    float const value = sender.value;
    if (_internal.au_mixer) {
        _internal.au_mixer.set_input_volume(value, 0);
    }
}

#pragma mark -

- (void)setupEngine {
    _internal = sample::route_vc_internal();

    _internal.au_mixer.set_input_volume(1.0, 0);
    _internal.route.set_routes({{0, 0, 0, 0}, {0, 1, 0, 1}});

    double phase = 0;

    auto tap_render_handler = [phase](auto args) mutable {
        auto &buffer = args.buffer;

        buffer.clear();

        double const start_phase = phase;
        double const phase_per_frame = 1000.0 / buffer.format().sample_rate() * audio::math::two_pi;

        auto each = audio::make_each_data<float>(buffer);
        auto const length = buffer.frame_length();

        while (yas_each_data_next_ch(each)) {
            phase = audio::math::fill_sine(yas_each_data_ptr(each), length, start_phase, phase_per_frame);
        }
    };

    _internal.sine_tap.set_render_handler(tap_render_handler);

    auto unowned_self = make_objc_ptr([[YASUnownedObject alloc] initWithObject:self]);

    _internal.engine_observer = _internal.manager.subject().make_observer(
        audio::engine::manager::method::configuration_change, [unowned_self](auto const &context) {
            if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
                [[unowned_self.object() object] _updateEngine];
            }
        });

    _internal.connect_nodes();
}

- (void)_updateEngine {
    _internal.disconnectNodes();
    _internal.connect_nodes();

    [self.tableView reloadData];
    [self _updateSlider];
}

#pragma mark -

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

- (void)_updateSlider {
    if (_internal.au_mixer) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:YASAudioEngineRouteSampleSectionSlider];
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        if (cell) {
            for (UIView *view in cell.contentView.subviews) {
                if ([view isKindOfClass:[UISlider class]]) {
                    UISlider *slider = (UISlider *)view;
                    slider.value = _internal.au_mixer.input_volume(0);
                }
            }
        }
    }
}

@end
