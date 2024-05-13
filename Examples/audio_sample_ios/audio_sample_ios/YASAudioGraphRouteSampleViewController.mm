//
//  YASAudioGraphRouteSampleViewController.m
//

#import "YASAudioGraphRouteSampleViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <audio-engine/umbrella.h>
#import <cpp-utils/objc_ptr.h>
#import <objc-utils/unowned.h>
#import "YASAudioGraphRouteSampleSelectionViewController.h"
#import "YASAudioSliderCell.h"
#import "YASViewControllerUtils.h"

using namespace yas;

namespace yas::route_sample {
enum class section : uint32_t {
    slider,
    destinations,
};
static std::size_t constexpr section_count = 2;

enum class source : uint32_t {
    sine,
    input,
};
}  // namespace yas::route_sample

@interface YASAudioGraphRouteSampleViewController ()

@property (nonatomic, strong) IBOutlet UISlider *slider;

@end

namespace yas::sample {
struct route_vc_cpp {
    audio::ios_session_ptr const session = audio::ios_session::shared();
    audio::ios_device_ptr const device = audio::ios_device::make_shared(this->session);
    audio::graph_ptr const graph = audio::graph::make_shared();
    audio::graph_avf_au_mixer_ptr const au_mixer = audio::graph_avf_au_mixer::make_shared();
    std::shared_ptr<audio::graph_route> const route = audio::graph_route::make_shared();
    audio::graph_tap_ptr const sine_tap = audio::graph_tap::make_shared();

    observing::cancellable_ptr device_canceller = nullptr;

    bool is_setup() {
        return this->graph->io().has_value();
    }

    void dispose() {
        this->graph->stop();
        this->session->deactivate();
    }

    void disconnectNodes() {
        graph->disconnect(this->au_mixer->raw_au->node);
        graph->disconnect(this->route->node);
        graph->disconnect(this->sine_tap->node);
        graph->disconnect(this->graph->io().value()->output_node);
        graph->disconnect(this->graph->io().value()->input_node);
    }

    void connect_nodes() {
        if (auto const format = this->device->output_format()) {
            graph->connect(this->au_mixer->raw_au->node, this->graph->io().value()->output_node, *format);
            graph->connect(this->route->node, au_mixer->raw_au->node, *format);
            graph->connect(this->sine_tap->node, route->node, 0, uint32_t(route_sample::source::sine), *format);
        }
        if (auto const format = this->device->input_format()) {
            graph->connect(this->graph->io().value()->input_node, this->route->node, 0,
                           uint32_t(route_sample::source::input), *format);
        }
    }
};
}  // namespace yas::sample

@implementation YASAudioGraphRouteSampleViewController {
    sample::route_vc_cpp _cpp;
}

- (void)dealloc {
    yas_release(_slider);

    _slider = nil;

    yas_super_dealloc();
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (self.isMovingToParentViewController) {
        [self setup];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    if (self.isMovingFromParentViewController) {
        self->_cpp.dispose();
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(UITableViewCell *)cell {
    id destinationViewController = segue.destinationViewController;
    if ([destinationViewController isKindOfClass:[YASAudioGraphRouteSampleSelectionViewController class]]) {
        YASAudioGraphRouteSampleSelectionViewController *controller = destinationViewController;
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        controller.outputChannelCount = self->_cpp.device->output_channel_count();
        controller.inputChannelCount = self->_cpp.device->input_channel_count();
        controller.fromCellIndexPath = indexPath;
    }
}

- (IBAction)unwindForSegue:(UIStoryboardSegue *)segue {
    id sourceViewController = segue.sourceViewController;
    if ([sourceViewController isKindOfClass:[YASAudioGraphRouteSampleSelectionViewController class]]) {
        YASAudioGraphRouteSampleSelectionViewController *controller = sourceViewController;
        NSIndexPath *fromIndexPath = controller.fromCellIndexPath;
        NSIndexPath *selectedIndexPath = controller.selectedIndexPath;

        if (selectedIndexPath) {
            auto const dst_bus_idx = 0;
            auto const dst_ch_idx = uint32_t(fromIndexPath.row);
            uint32_t src_bus_idx = -1;
            uint32_t src_ch_idx = -1;

            switch (route_sample::selection_section(selectedIndexPath.section)) {
                case route_sample::selection_section::sine:
                    src_bus_idx = uint32_t(route_sample::source::sine);
                    src_ch_idx = uint32_t(selectedIndexPath.row);
                    break;
                case route_sample::selection_section::input:
                    src_bus_idx = uint32_t(route_sample::source::input);
                    src_ch_idx = uint32_t(selectedIndexPath.row);
                    break;
                case route_sample::selection_section::none:
                    break;
            }

            if (src_bus_idx == -1 || src_ch_idx == -1) {
                self->_cpp.route->remove_route_for_destination({dst_bus_idx, dst_ch_idx});
            } else {
                self->_cpp.route->add_route({src_bus_idx, src_ch_idx, dst_bus_idx, dst_ch_idx});
            }

            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:fromIndexPath.section]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (self->_cpp.is_setup()) {
        return route_sample::section_count;
    } else {
        return 0;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (route_sample::section(section)) {
        case route_sample::section::slider:
            return 1;
        case route_sample::section::destinations:
            return self->_cpp.device->output_channel_count();
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (route_sample::section(indexPath.section)) {
        case route_sample::section::slider: {
            YASAudioSliderCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SliderCell"
                                                                       forIndexPath:indexPath];
            return cell;
        }

        case route_sample::section::destinations: {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
            auto const &routes = self->_cpp.route->routes();
            audio::route::point dst_point{0, uint32_t(indexPath.row)};
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
    if (self->_cpp.au_mixer) {
        self->_cpp.au_mixer->set_input_volume(value, 0);
    }
}

#pragma mark -

- (void)setup {
    self->_cpp.session->set_category(audio::ios_session::category::play_and_record);

    if (auto const result = self->_cpp.session->activate(); !result) {
        NSString *errorMessage = (__bridge NSString *)to_cf_object(result.error());
        [YASViewControllerUtils showErrorAlertWithMessage:errorMessage toViewController:self];
        return;
    }

    self->_cpp.graph->add_io(self->_cpp.device);

    self->_cpp.au_mixer->set_input_volume(0.1, 0);
    self->_cpp.route->set_routes({{0, 0, 0, 0}, {0, 1, 0, 1}});

    double phase = 0;

    auto tap_render_handler = [phase](audio::node_render_args const &args) mutable {
        auto &buffer = args.buffer;

        buffer->clear();

        double const start_phase = phase;
        double const phase_per_frame = 1000.0 / buffer->format().sample_rate() * audio::math::two_pi;

        auto each = audio::make_each_data<float>(*buffer);
        auto const length = buffer->frame_length();

        while (yas_each_data_next_ch(each)) {
            phase = audio::math::fill_sine(yas_each_data_ptr(each), length, start_phase, phase_per_frame);
        }
    };

    self->_cpp.sine_tap->set_render_handler(tap_render_handler);

    auto unowned_self = objc_ptr_with_move_object([[YASUnownedObject alloc] initWithObject:self]);

    self->_cpp.device_canceller =
        self->_cpp.device
            ->observe_io_device([unowned_self](auto const &) {
                if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
                    [[unowned_self.object() object] _updateEngine];
                }
            })
            .end();

    self->_cpp.connect_nodes();

    if (auto const start_result = self->_cpp.graph->start_render()) {
        [self.tableView reloadData];
        [self _updateSlider];
    } else {
        auto const error_string = to_string(start_result.error());
        NSString *errorMessage = (__bridge NSString *)to_cf_object(error_string);
        [YASViewControllerUtils showErrorAlertWithMessage:errorMessage toViewController:self];
    }
}

- (void)_updateEngine {
    self->_cpp.device_canceller = nullptr;
    self->_cpp.disconnectNodes();
    self->_cpp.connect_nodes();

    [self.tableView reloadData];
    [self _updateSlider];
}

#pragma mark -

- (void)_updateSlider {
    if (self->_cpp.au_mixer) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:NSUInteger(route_sample::section::slider)];
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        if (cell) {
            for (UIView *view in cell.contentView.subviews) {
                if ([view isKindOfClass:[UISlider class]]) {
                    UISlider *slider = (UISlider *)view;
                    slider.value = self->_cpp.au_mixer->input_volume(0);
                }
            }
        }
    }
}

@end
