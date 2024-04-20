//
//  YASAudioRouteSampleViewController.m
//

#define ACCELERATE_NEW_LAPACK

#import "YASAudioRouteSampleViewController.h"
#import <Accelerate/Accelerate.h>
#import <cpp-utils/yas_objc_ptr.h>
#import <objc-utils/yas_objc_macros.h>
#import <objc-utils/yas_objc_unowned.h>
#import <audio/yas_audio_umbrella.hpp>

using namespace yas;

namespace yas::sample {
struct graph_io_vc_cpp {
    enum class source_bus : uint32_t {
        sine,
        input,
    };

    enum class input_type : uint32_t {
        none,
        sine,
        input,
    };

    audio::graph_ptr const graph = audio::graph::make_shared();
    audio::graph_route_ptr const route = audio::graph_route::make_shared();
    audio::graph_tap_ptr const tap = audio::graph_tap::make_shared();

    std::optional<observing::cancellable_ptr> system_canceller = std::nullopt;
    std::optional<observing::cancellable_ptr> device_canceller = std::nullopt;

    graph_io_vc_cpp() {
        std::optional<audio::mac_device_ptr> device = std::nullopt;

        if (auto const output_device = audio::mac_device::default_output_device()) {
            device = output_device;
        } else if (auto const input_device = audio::mac_device::default_input_device()) {
            device = input_device;
        }

        this->graph->add_io(device);
    }
};
}  // namespace yas::sample

@interface YASAudioDeviceRouteSampleOutputData : NSObject

@property (nonatomic, assign) uint32_t outputIndex;
@property (nonatomic, assign) uint32_t inputSelectIndex;

+ (instancetype)data;

@end

@implementation YASAudioDeviceRouteSampleOutputData

+ (instancetype)data {
    return yas_autorelease([[self alloc] init]);
}

- (NSString *)indexTitle {
    return [NSString stringWithFormat:@"bus %@", @(self.outputIndex)];
}

- (BOOL)isNoneSelected {
    return self.inputSelectIndex == (uint32_t)sample::graph_io_vc_cpp::input_type::none;
}

- (BOOL)isSineSelected {
    return self.inputSelectIndex == (uint32_t)sample::graph_io_vc_cpp::input_type::sine;
}

- (BOOL)isInputSelected {
    return self.inputSelectIndex >= (uint32_t)sample::graph_io_vc_cpp::input_type::input;
}

- (uint32_t)inputIndex {
    return self.inputSelectIndex - (uint32_t)sample::graph_io_vc_cpp::input_type::input;
}

@end

@interface YASAudioDeviceRouteSampleInputData : NSObject

@property (nonatomic, assign) uint32_t index;

+ (instancetype)data;

@end

@implementation YASAudioDeviceRouteSampleInputData

+ (instancetype)data {
    return yas_autorelease([[self alloc] init]);
}

- (NSString *)indexTitle {
    if ((sample::graph_io_vc_cpp::input_type)self.index == sample::graph_io_vc_cpp::input_type::none) {
        return @"None";
    } else if ((sample::graph_io_vc_cpp::input_type)self.index == sample::graph_io_vc_cpp::input_type::sine) {
        return @"Sine";
    } else {
        return [NSString
            stringWithFormat:@"Input Ch : %@", @(self.index - (uint32_t)sample::graph_io_vc_cpp::input_type::input)];
    }
}

@end

@interface YASAudioRouteSampleViewController () <NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, strong) NSArray<NSString *> *deviceNames;
@property (nonatomic, assign) double nominalSampleRate;
@property (nonatomic, assign) NSUInteger selectedDeviceIndex;

@property (atomic, strong) NSMutableArray<YASAudioDeviceRouteSampleOutputData *> *outputRoutes;
@property (atomic, strong) NSMutableArray<YASAudioDeviceRouteSampleInputData *> *inputRoutes;

@end

@implementation YASAudioRouteSampleViewController {
    std::shared_ptr<sample::graph_io_vc_cpp> _cpp;
}

- (void)dealloc {
    yas_release(_deviceNames);
    yas_release(_outputRoutes);
    yas_release(_inputRoutes);

    _deviceNames = nil;
    _outputRoutes = nil;
    _inputRoutes = nil;

    yas_super_dealloc();
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewDidAppear {
    [super viewDidAppear];

    [self setup];

    if (auto error = _cpp->graph->start_render().error_opt()) {
        auto const error_str = to_string(*error);
        NSLog(@"audio graph start failed. error : %@", (__bridge NSString *)to_cf_object(error_str));
    }
}

- (void)viewWillDisappear {
    [self dispose];

    [super viewWillDisappear];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSString *, id> *)change
                       context:(void *)context {
    if ([object isKindOfClass:[YASAudioDeviceRouteSampleOutputData class]]) {
        YASAudioDeviceRouteSampleOutputData *data = object;
        if ([data isNoneSelected]) {
            _cpp->route->remove_route_for_destination({0, data.outputIndex});
        } else if ([data isSineSelected]) {
            _cpp->route->add_route(
                {(uint32_t)sample::graph_io_vc_cpp::source_bus::sine, data.outputIndex, 0, data.outputIndex});
        } else if ([data isInputSelected]) {
            _cpp->route->add_route(
                {(uint32_t)sample::graph_io_vc_cpp::source_bus::input, [data inputIndex], 0, data.outputIndex});
        }

        [self _updateInputSelection];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)setup {
    self->_cpp = std::make_shared<sample::graph_io_vc_cpp>();

    auto weak_tap = to_weak(_cpp->tap);

    double next_phase = 0.0;

    auto render_handler = [next_phase, weak_tap](auto args) mutable {
        auto &buffer = args.buffer;

        buffer->clear();

        double const start_phase = next_phase;
        auto const frame_length = buffer->frame_length();
        double const phase_per_frame = 1000.0 / buffer->format().sample_rate() * audio::math::two_pi;
        auto each = audio::make_each_data<float>(*buffer);
        while (yas_each_data_next_ch(each)) {
            auto *const ptr = yas_each_data_ptr(each);
            next_phase = audio::math::fill_sine(ptr, frame_length, start_phase, phase_per_frame);
            cblas_sscal(buffer->frame_length(), 0.1, ptr, 1);
        }
    };

    self->_cpp->tap->set_render_handler(render_handler);

    auto unowned_self = objc_ptr_with_move_object([[YASUnownedObject alloc] initWithObject:self]);

    self->_cpp->system_canceller = audio::mac_device::observe_system([unowned_self](auto const &) {
                                       [[unowned_self.object() object] _updateDeviceNames];
                                   }).end();

    [self _updateDeviceNames];

    if (auto const default_device = audio::mac_device::default_output_device()) {
        if (auto index = audio::mac_device::index_of_device(*default_device)) {
            self.selectedDeviceIndex = *index;
        }
    }
}

- (void)dispose {
    self->_cpp->graph->stop();
    self->_cpp = nullptr;

    self.selectedDeviceIndex = audio::mac_device::all_devices().size();

    [self _removeObservers];

    self.outputRoutes = nil;
    self.inputRoutes = nil;
}

#pragma mark - update

- (void)_updateDeviceNames {
    auto all_devices = audio::mac_device::all_devices();

    NSMutableArray *titles = [NSMutableArray arrayWithCapacity:all_devices.size()];

    for (auto &device : all_devices) {
        [titles addObject:(__bridge NSString *)to_cf_object(device->name())];
    }

    [titles addObject:@"None"];

    self.deviceNames = titles;

    std::optional<NSUInteger> index = std::nullopt;
    if (auto const io_device = _cpp->graph->io().value()->raw_io()->device()) {
        auto const mac_device = std::dynamic_pointer_cast<audio::mac_device>(*io_device);
        index = audio::mac_device::index_of_device(mac_device);
    }

    if (index) {
        self.selectedDeviceIndex = *index;
    } else {
        self.selectedDeviceIndex = all_devices.size();
    }
}

- (void)_updateConnection {
    [self _removeObservers];

    self.outputRoutes = nil;
    self.inputRoutes = nil;

    self->_cpp->graph->disconnect(_cpp->tap->node);
    self->_cpp->graph->disconnect(_cpp->route->node);
    self->_cpp->route->clear_routes();

    if (auto const &device_opt = _cpp->graph->io().value()->raw_io()->device()) {
        auto const &device = *device_opt;
        if (device->output_channel_count() > 0) {
            if (auto const output_format = device->output_format()) {
                _cpp->graph->connect(_cpp->route->node, _cpp->graph->io().value()->output_node, *output_format);
                _cpp->graph->connect(_cpp->tap->node, _cpp->route->node, 0,
                                     (uint32_t)sample::graph_io_vc_cpp::source_bus::sine, *output_format);
            }
        }

        if (device->input_channel_count() > 0) {
            if (auto const input_format = device->input_format()) {
                _cpp->graph->connect(_cpp->graph->io().value()->input_node, _cpp->route->node, 0,
                                     (uint32_t)sample::graph_io_vc_cpp::source_bus::input, *input_format);
            }
        }

        auto const mac_device = std::dynamic_pointer_cast<audio::mac_device>(device);

        uint32_t const output_channel_count = mac_device->output_channel_count();
        uint32_t const input_channel_count = mac_device->input_channel_count();
        NSMutableArray *outputRoutes = [NSMutableArray arrayWithCapacity:output_channel_count];
        NSMutableArray *inputRoutes = [NSMutableArray arrayWithCapacity:input_channel_count];

        for (uint32_t i = 0; i < output_channel_count; ++i) {
            YASAudioDeviceRouteSampleOutputData *data = [YASAudioDeviceRouteSampleOutputData data];
            data.outputIndex = i;
            [outputRoutes addObject:data];
        }

        for (uint32_t i = 0; i < input_channel_count + 2; ++i) {
            YASAudioDeviceRouteSampleInputData *data = [YASAudioDeviceRouteSampleInputData data];
            data.index = i;
            [inputRoutes addObject:data];
        }

        self.outputRoutes = outputRoutes;
        self.inputRoutes = inputRoutes;
        self.nominalSampleRate = mac_device->nominal_sample_rate();

        [self _updateInputSelection];
        [self _addObservers];
    } else {
        self.outputRoutes = nil;
        self.inputRoutes = nil;
        self.nominalSampleRate = 0.0;
    }
}

- (void)_addObservers {
    for (YASAudioDeviceRouteSampleOutputData *data in self.outputRoutes) {
        [data addObserver:self forKeyPath:@"inputSelectIndex" options:NSKeyValueObservingOptionNew context:nil];
    }
}

- (void)_removeObservers {
    for (YASAudioDeviceRouteSampleOutputData *data in self.outputRoutes) {
        [data removeObserver:self forKeyPath:@"inputSelectIndex"];
    }
}

- (void)_updateInputSelection {
    if (!self->_cpp->route) {
        return;
    }

    auto &routes = _cpp->route->routes();
    for (YASAudioDeviceRouteSampleOutputData *data in self.outputRoutes) {
        uint32_t const dst_ch_idx = data.outputIndex;
        auto it = std::find_if(routes.begin(), routes.end(), [dst_ch_idx](const audio::route &route) {
            return route.destination.channel == dst_ch_idx;
        });

        uint32_t inputSelectIndex = 0;

        if (it != routes.end()) {
            auto const &route = *it;
            if (route.source.bus == (uint32_t)sample::graph_io_vc_cpp::source_bus::sine) {
                inputSelectIndex = (uint32_t)sample::graph_io_vc_cpp::input_type::sine;
            } else if (route.source.bus == (uint32_t)sample::graph_io_vc_cpp::source_bus::input) {
                inputSelectIndex = route.source.channel + (uint32_t)sample::graph_io_vc_cpp::input_type::input;
            } else {
                inputSelectIndex = (uint32_t)sample::graph_io_vc_cpp::input_type::none;
            }
        } else {
            inputSelectIndex = (uint32_t)sample::graph_io_vc_cpp::input_type::none;
        }

        if (data.inputSelectIndex != inputSelectIndex) {
            data.inputSelectIndex = inputSelectIndex;
        }
    }
}

#pragma mark - accessor

- (void)setSelectedDeviceIndex:(NSUInteger)selectedDeviceIndex {
    self->_selectedDeviceIndex = selectedDeviceIndex;

    auto const all_devices = audio::mac_device::all_devices();

    if (selectedDeviceIndex < all_devices.size()) {
        auto const &device = all_devices[selectedDeviceIndex];
        [self setDevice:device];
    } else {
        [self setDevice:std::nullopt];
    }
}

- (void)setDevice:(std::optional<audio::mac_device_ptr> const &)selected_device {
    if (!self->_cpp) {
        return;
    }

    self->_cpp->device_canceller = std::nullopt;

    auto const all_devices = audio::mac_device::all_devices();

    self->_cpp->graph->io().value()->raw_io()->set_device(selected_device);

    if (selected_device && std::find(all_devices.begin(), all_devices.end(), selected_device) != all_devices.end()) {
        auto unowned_self = objc_ptr_with_move_object([[YASUnownedObject alloc] initWithObject:self]);

        self->_cpp->device_canceller = selected_device.value()
                                           ->observe_io_device([unowned_self](auto const &) {
                                               [[unowned_self.object() object] _updateConnection];
                                           })
                                           .end();
    }

    [self _updateConnection];
}

@end
