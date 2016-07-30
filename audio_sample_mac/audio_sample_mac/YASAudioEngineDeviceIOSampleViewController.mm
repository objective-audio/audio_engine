//
//  YASAudioEngineSampleViewController.m
//

#import <Accelerate/Accelerate.h>
#import "YASAudioEngineDeviceIOSampleViewController.h"
#import "yas_audio.h"
#import "yas_objc_unowned.h"

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

@interface YASAudioEngineDeviceIOSampleViewController () <NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, strong) NSArray *deviceNames;
@property (nonatomic, assign) double nominalSampleRate;
@property (nonatomic, assign) NSUInteger selectedDeviceIndex;

@property (atomic, strong) NSMutableArray *outputRoutes;
@property (atomic, strong) NSMutableArray *inputRoutes;

@end

namespace yas {
namespace sample {
    struct device_io_vc_internal {
        audio::engine engine = nullptr;
        audio::device_io_node device_io_node = nullptr;
        audio::route_node route_node = nullptr;
        audio::tap_node tap_node = nullptr;

        base system_observer = nullptr;
        base device_observer = nullptr;
    };
}
}

@implementation YASAudioEngineDeviceIOSampleViewController {
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

    if (auto error = _internal.engine.start_render().error_opt()) {
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
            _internal.route_node.remove_route_for_destination({0, data.outputIndex});
        } else if ([data isSineSelected]) {
            _internal.route_node.add_route(
                {YASAudioDeviceRouteSampleSourceBusSine, data.outputIndex, 0, data.outputIndex});
        } else if ([data isInputSelected]) {
            _internal.route_node.add_route(
                {YASAudioDeviceRouteSampleSourceBusInput, [data inputIndex], 0, data.outputIndex});
        }

        [self _updateInputSelection];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)setupEngine {
    _internal.engine = audio::engine{};
    _internal.device_io_node = audio::device_io_node{};
    _internal.route_node = audio::route_node{};
    _internal.tap_node = audio::tap_node{};

    auto weak_node = to_weak(_internal.tap_node);

    double next_phase = 0.0;

    auto render_function = [next_phase, weak_node](audio::pcm_buffer &buffer, uint32_t const bus_idx,
                                                   const audio::time &when) mutable {
        buffer.clear();

        audio::frame_enumerator enumerator(buffer);
        auto const *flex_ptr = enumerator.pointer();
        double const start_phase = next_phase;
        double const phase_per_frame = 1000.0 / buffer.format().sample_rate() * audio::math::two_pi;
        while (flex_ptr->v) {
            next_phase = audio::math::fill_sine(flex_ptr->f32, buffer.frame_length(), start_phase, phase_per_frame);
            cblas_sscal(buffer.frame_length(), 0.2, flex_ptr->f32, 1);
            yas_audio_frame_enumerator_move_channel(enumerator);
        }
    };

    _internal.tap_node.set_render_function(render_function);

    auto unowned_self = make_objc_ptr([[YASUnownedObject alloc] init]);
    [unowned_self.object() setObject:self];

    _internal.system_observer = audio::device::system_subject().make_observer(
        audio::device::method::hardware_did_change,
        [unowned_self](auto const &context) { [[unowned_self.object() object] _updateDeviceNames]; });

    [self _updateDeviceNames];

    auto default_device = audio::device::default_output_device();
    if (auto index = audio::device::index_of_device(default_device)) {
        self.selectedDeviceIndex = *index;
    }
}

- (void)dispose {
    _internal.engine.stop();

    _internal.device_io_node = nullptr;
    _internal.route_node = nullptr;
    _internal.tap_node = nullptr;
    _internal.engine = nullptr;

    _internal.system_observer = nullptr;
    _internal.device_observer = nullptr;

    self.selectedDeviceIndex = audio::device::all_devices().size();

    [self _removeObservers];

    self.outputRoutes = nil;
    self.inputRoutes = nil;
}

#pragma mark - update

- (void)_updateDeviceNames {
    auto all_devices = audio::device::all_devices();

    NSMutableArray *titles = [NSMutableArray arrayWithCapacity:all_devices.size()];

    for (auto &device : all_devices) {
        [titles addObject:(__bridge NSString *)device.name()];
    }

    [titles addObject:@"None"];

    self.deviceNames = titles;

    auto device = _internal.device_io_node.device();
    auto index = audio::device::index_of_device(device);
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

    if (_internal.engine) {
        _internal.engine.disconnect(_internal.tap_node);
        _internal.engine.disconnect(_internal.route_node);
        _internal.route_node.clear_routes();

        if (auto const &device = _internal.device_io_node.device()) {
            if (device.output_channel_count() > 0) {
                auto const output_format = device.output_format();
                _internal.engine.connect(_internal.route_node, _internal.device_io_node.node(), output_format);
                _internal.engine.connect(_internal.tap_node, _internal.route_node, 0,
                                         YASAudioDeviceRouteSampleSourceBusSine, output_format);
            }

            if (device.input_channel_count() > 0) {
                _internal.engine.connect(_internal.device_io_node.node(), _internal.route_node, 0,
                                         YASAudioDeviceRouteSampleSourceBusInput, device.input_format());
            }
        }
    }

    if (auto const device = _internal.device_io_node.device()) {
        uint32_t const output_channel_count = device.output_channel_count();
        uint32_t const input_channel_count = device.input_channel_count();
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
        self.nominalSampleRate = device.nominal_sample_rate();

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
    if (!_internal.route_node) {
        return;
    }

    auto &routes = _internal.route_node.routes();
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

    auto all_devices = audio::device::all_devices();

    if (selectedDeviceIndex < all_devices.size()) {
        auto device = all_devices[selectedDeviceIndex];
        [self setDevice:device];
    } else {
        [self setDevice:nullptr];
    }
}

- (void)setDevice:(const audio::device &)selected_device {
    _internal.device_observer = nullptr;

    if (!_internal.device_io_node) {
        return;
    }

    auto const all_devices = audio::device::all_devices();

    if (selected_device && std::find(all_devices.begin(), all_devices.end(), selected_device) != all_devices.end()) {
        _internal.device_io_node.set_device(selected_device);

        auto unowned_self = make_objc_ptr([[YASUnownedObject alloc] init]);
        [unowned_self.object() setObject:self];

        _internal.device_observer = selected_device.subject().make_observer(
            audio::device::method::device_did_change, [selected_device, unowned_self](auto const &context) {
                auto const &change_info = context.value;
                auto const &infos = change_info.property_infos;
                if (change_info.property_infos.size() > 0) {
                    auto const &device_id = infos.at(0).object_id;
                    if (selected_device.audio_device_id() == device_id) {
                        [[unowned_self.object() object] _updateConnection];
                    }
                }
            });
    } else {
        _internal.device_io_node.set_device(nullptr);
    }

    [self _updateConnection];
}

@end
