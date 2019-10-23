//
//  YASAudioEngineIOSampleViewController.m
//

#import "YASAudioEngineIOSampleViewController.h"
#import <Accelerate/Accelerate.h>
#import <audio/yas_audio_umbrella.h>
#import <cpp_utils/yas_objc_ptr.h>
#import <objc_utils/yas_objc_macros.h>
#import <objc_utils/yas_objc_unowned.h>

using namespace yas;

typedef NS_ENUM(NSUInteger, YASAudioDeviceRouteSampleSourceBus) {
    YASAudioDeviceRouteSampleSourceBusSine = 0,
    YASAudioDeviceRouteSampleSourceBusInput = 1,
    YASAudioDeviceRouteSampleSourceBusCount,
};

typedef NS_ENUM(NSUInteger, YASAudioDeviceRouteSampleInputType) {
    YASAudioDeviceRouteSampleInputTypeNone,
    YASAudioDeviceRouteSampleInputTypeSine,
    YASAudioDeviceRouteSampleInputTypeInput,
};

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
    return self.inputSelectIndex == YASAudioDeviceRouteSampleInputTypeNone;
}

- (BOOL)isSineSelected {
    return self.inputSelectIndex == YASAudioDeviceRouteSampleInputTypeSine;
}

- (BOOL)isInputSelected {
    return self.inputSelectIndex >= YASAudioDeviceRouteSampleInputTypeInput;
}

- (uint32_t)inputIndex {
    return self.inputSelectIndex - YASAudioDeviceRouteSampleInputTypeInput;
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
    if (self.index == YASAudioDeviceRouteSampleInputTypeNone) {
        return @"None";
    } else if (self.index == YASAudioDeviceRouteSampleInputTypeSine) {
        return @"Sine";
    } else {
        return [NSString stringWithFormat:@"Input Ch : %@", @(self.index - YASAudioDeviceRouteSampleInputTypeInput)];
    }
}

@end

@interface YASAudioEngineIOSampleViewController () <NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, strong) NSArray *deviceNames;
@property (nonatomic, assign) double nominalSampleRate;
@property (nonatomic, assign) NSUInteger selectedDeviceIndex;

@property (atomic, strong) NSMutableArray *outputRoutes;
@property (atomic, strong) NSMutableArray *inputRoutes;

@end

namespace yas::sample {
struct device_io_vc_internal {
    audio::engine::manager_ptr manager = nullptr;
    audio::engine::route_ptr route = nullptr;
    audio::engine::tap_ptr tap = nullptr;

    chaining::any_observer_ptr system_observer = nullptr;
    chaining::any_observer_ptr device_observer = nullptr;
};
}

@implementation YASAudioEngineIOSampleViewController {
    sample::device_io_vc_internal _internal;
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

    [self setupEngine];

    if (auto error = _internal.manager->start_render().error_opt()) {
        auto const error_str = to_string(*error);
        NSLog(@"audio engine start failed. error : %@", (__bridge NSString *)to_cf_object(error_str));
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
            _internal.route->remove_route_for_destination({0, data.outputIndex});
        } else if ([data isSineSelected]) {
            _internal.route->add_route({YASAudioDeviceRouteSampleSourceBusSine, data.outputIndex, 0, data.outputIndex});
        } else if ([data isInputSelected]) {
            _internal.route->add_route(
                {YASAudioDeviceRouteSampleSourceBusInput, [data inputIndex], 0, data.outputIndex});
        }

        [self _updateInputSelection];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)setupEngine {
    _internal.manager = audio::engine::manager::make_shared();
    _internal.manager->add_io();
    _internal.route = audio::engine::route::make_shared();
    _internal.tap = audio::engine::tap::make_shared();

    auto weak_tap = to_weak(_internal.tap);

    double next_phase = 0.0;

    auto render_handler = [next_phase, weak_tap](auto args) mutable {
        auto &buffer = args.buffer;

        buffer.clear();

        double const start_phase = next_phase;
        auto const frame_length = buffer.frame_length();
        double const phase_per_frame = 1000.0 / buffer.format().sample_rate() * audio::math::two_pi;
        auto each = audio::make_each_data<float>(buffer);
        while (yas_each_data_next_ch(each)) {
            auto *const ptr = yas_each_data_ptr(each);
            next_phase = audio::math::fill_sine(ptr, frame_length, start_phase, phase_per_frame);
            cblas_sscal(buffer.frame_length(), 0.2, ptr, 1);
        }
    };

    _internal.tap->set_render_handler(render_handler);

    auto unowned_self = objc_ptr_with_move_object([[YASUnownedObject alloc] initWithObject:self]);

    _internal.system_observer =
        audio::mac_device::system_chain(audio::mac_device::system_method::hardware_did_change)
            .perform([unowned_self](auto const &) { [[unowned_self.object() object] _updateDeviceNames]; })
            .end();

    [self _updateDeviceNames];

    if (auto const default_device = audio::mac_device::default_output_device()) {
        if (auto index = audio::mac_device::index_of_device(*default_device)) {
            self.selectedDeviceIndex = *index;
        }
    }
}

- (void)dispose {
    _internal.manager->stop();

    _internal.route = nullptr;
    _internal.tap = nullptr;
    _internal.manager = nullptr;

    _internal.system_observer = nullptr;
    _internal.device_observer = nullptr;

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
        [titles addObject:(__bridge NSString *)device->name()];
    }

    [titles addObject:@"None"];

    self.deviceNames = titles;

    std::optional<NSUInteger> index = std::nullopt;
    if (auto const io_device = _internal.manager->io()->device()) {
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

    if (_internal.manager) {
        _internal.manager->disconnect(_internal.tap->node());
        _internal.manager->disconnect(_internal.route->node());
        _internal.route->clear_routes();

        if (auto const &device_opt = _internal.manager->io()->device()) {
            auto const &device = *device_opt;
            if (device->output_channel_count() > 0) {
                if (auto const output_format = device->output_format()) {
                    _internal.manager->connect(_internal.route->node(), _internal.manager->io()->node(),
                                               *output_format);
                    _internal.manager->connect(_internal.tap->node(), _internal.route->node(), 0,
                                               YASAudioDeviceRouteSampleSourceBusSine, *output_format);
                }
            }

            if (device->input_channel_count() > 0) {
                if (auto const input_format = device->input_format()) {
                    _internal.manager->connect(_internal.manager->io()->node(), _internal.route->node(), 0,
                                               YASAudioDeviceRouteSampleSourceBusInput, *input_format);
                }
            }
        }
    }

    if (auto const &io_device = _internal.manager->io()->device()) {
        auto const mac_device = std::dynamic_pointer_cast<audio::mac_device>(*io_device);
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
    if (!_internal.route) {
        return;
    }

    auto &routes = _internal.route->routes();
    for (YASAudioDeviceRouteSampleOutputData *data in self.outputRoutes) {
        uint32_t const dst_ch_idx = data.outputIndex;
        auto it = std::find_if(routes.begin(), routes.end(), [dst_ch_idx](const audio::route &route) {
            return route.destination.channel == dst_ch_idx;
        });

        uint32_t inputSelectIndex = 0;

        if (it != routes.end()) {
            auto const &route = *it;
            if (route.source.bus == YASAudioDeviceRouteSampleSourceBusSine) {
                inputSelectIndex = YASAudioDeviceRouteSampleInputTypeSine;
            } else if (route.source.bus == YASAudioDeviceRouteSampleSourceBusInput) {
                inputSelectIndex = route.source.channel + YASAudioDeviceRouteSampleInputTypeInput;
            } else {
                inputSelectIndex = YASAudioDeviceRouteSampleInputTypeNone;
            }
        } else {
            inputSelectIndex = YASAudioDeviceRouteSampleInputTypeNone;
        }

        if (data.inputSelectIndex != inputSelectIndex) {
            data.inputSelectIndex = inputSelectIndex;
        }
    }
}

#pragma mark - accessor

- (void)setSelectedDeviceIndex:(NSUInteger)selectedDeviceIndex {
    _selectedDeviceIndex = selectedDeviceIndex;

    auto const all_devices = audio::mac_device::all_devices();

    if (selectedDeviceIndex < all_devices.size()) {
        auto const &device = all_devices[selectedDeviceIndex];
        [self setDevice:device];
    } else {
        [self setDevice:nullptr];
    }
}

- (void)setDevice:(audio::mac_device_ptr const &)selected_device {
    _internal.device_observer = nullptr;

    if (!_internal.manager || !_internal.manager->io()) {
        return;
    }

    auto const all_devices = audio::mac_device::all_devices();

    if (selected_device && std::find(all_devices.begin(), all_devices.end(), selected_device) != all_devices.end()) {
        _internal.manager->io()->set_device(selected_device);

        auto unowned_self = objc_ptr_with_move_object([[YASUnownedObject alloc] initWithObject:self]);

        _internal.device_observer = selected_device->chain(audio::mac_device::method::device_did_change)
                                        .perform([selected_device, unowned_self](auto const &change_info) {
                                            auto const &infos = change_info.property_infos;
                                            if (change_info.property_infos.size() > 0) {
                                                auto const &device_id = infos.at(0).object_id;
                                                if (selected_device->audio_device_id() == device_id) {
                                                    [[unowned_self.object() object] _updateConnection];
                                                }
                                            }
                                        })
                                        .end();
    } else {
        _internal.manager->io()->set_device(std::nullopt);
    }

    [self _updateConnection];
}

@end
