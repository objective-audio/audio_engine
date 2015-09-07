//
//  YASAudioEngineSampleViewController.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioEngineDeviceIOSampleViewController.h"
#import "yas_audio.h"
#import <Accelerate/Accelerate.h>

@interface YASAudioDeviceRouteSampleData : NSObject

@property (nonatomic, assign) uint32_t index;
@property (atomic, assign) BOOL enabled;

+ (instancetype)data;

@end

@implementation YASAudioDeviceRouteSampleData

+ (instancetype)data
{
    return YASAutorelease([[self alloc] init]);
}

- (NSString *)indexTitle
{
    return [NSString stringWithFormat:@"bus %@", @(self.index)];
}

@end

@interface YASAudioEngineDeviceIOSampleViewController () <NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, strong) NSArray *deviceNames;
@property (nonatomic, assign) Float64 nominalSampleRate;
@property (nonatomic, assign) NSUInteger selectedDeviceIndex;

@property (atomic, strong) NSMutableArray *outputRoutes;
@property (atomic, strong) NSMutableArray *inputRoutes;

@end

@implementation YASAudioEngineDeviceIOSampleViewController {
    yas::audio_engine_sptr _engine;
    yas::audio_device_io_node_sptr _device_io_node;
    yas::audio_tap_node_sptr _tap_node;

    yas::any _system_observer;
    yas::any _device_observer;

    yas::objc_weak_container_sptr _self_container;
}

- (void)dealloc
{
    YASRelease(_deviceNames);
    YASRelease(_outputRoutes);
    YASRelease(_inputRoutes);

    _deviceNames = nil;
    _outputRoutes = nil;
    _inputRoutes = nil;

    if (_self_container) {
        _self_container->set_object(nil);
    }

    YASSuperDealloc;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)viewDidAppear
{
    [super viewDidAppear];

    [self setupEngine];

    if (!_engine->start_render()) {
        NSLog(@"audio engine start failed.");
    }
}

- (void)viewWillDisappear
{
    [self dispose];

    [super viewWillDisappear];
}

- (void)setupEngine
{
    _engine = yas::audio_engine::create();
    _device_io_node = yas::audio_device_io_node::create();
    _tap_node = yas::audio_tap_node::create();

    if (!_self_container) {
        _self_container = yas::objc_weak_container::create(self);
    }

    std::weak_ptr<yas::audio_tap_node> weak_node = _tap_node;

    Float64 next_phase = 0.0;

    auto render_function = [next_phase, weak_node, weak_container = _self_container](
        const yas::audio_pcm_buffer_sptr &buffer, const uint32_t bus_idx, const yas::audio_time_sptr &when) mutable
    {
        buffer->clear();

        auto strong_container = weak_container->lock();
        YASAudioEngineDeviceIOSampleViewController *controller = strong_container ? strong_container.object() : nil;
        NSArray *outputRoutes = controller.outputRoutes;
        const auto node = weak_node.lock();

        if (outputRoutes.count > 0 && node) {
            bool input_available = false;
            if (const auto connection = node->input_connection_on_render(0)) {
                if (const auto source_node = connection->source_node()) {
                    if (*buffer->format() == *connection->format()) {
                        source_node->render(buffer, 0, when);
                        input_available = true;
                    }
                }
            }

            yas::audio_frame_enumerator enumerator(buffer);
            const auto *flex_ptr = enumerator.pointer();
            const Float64 start_phase = next_phase;
            const Float64 phase_per_frame = 1000.0 / buffer->format()->sample_rate() * yas::audio_math::two_pi;
            uint32_t idx = 0;
            while (flex_ptr->v) {
                YASAudioDeviceRouteSampleData *data = outputRoutes[idx];
                if (data.enabled && !input_available) {
                    next_phase =
                        yas::audio_math::fill_sine(flex_ptr->f32, buffer->frame_length(), start_phase, phase_per_frame);
                    cblas_sscal(buffer->frame_length(), 0.2, flex_ptr->f32, 1);
                } else if (!data.enabled && input_available) {
                    memset(flex_ptr->f32, 0, buffer->frame_length() * buffer->format()->sample_byte_count());
                }
                yas_audio_frame_enumerator_move_channel(enumerator);
                ++idx;
            }
        }
    };

    _tap_node->set_render_function(render_function);

    auto system_observer = yas::make_observer(yas::audio_device::system_subject());
    system_observer->add_handler(yas::audio_device::system_subject(), yas::audio_device::method::hardware_did_change,
                                 [weak_container = _self_container](const auto &method, const auto &infos) {
                                     if (auto strong_container = weak_container->lock()) {
                                         YASAudioEngineDeviceIOSampleViewController *strongSelf =
                                             strong_container.object();
                                         [strongSelf _updateDeviceNames];
                                     }
                                 });
    _system_observer = yas::any(system_observer);

    [self _updateDeviceNames];

    auto default_device = yas::audio_device::default_output_device();
    if (auto index = yas::audio_device::index_of_device(default_device)) {
        self.selectedDeviceIndex = *index;
    }
}

- (void)dispose
{
    _engine->stop();

    _device_io_node = nullptr;
    _engine = nullptr;
}

#pragma mark - update

- (void)_updateDeviceNames
{
    auto all_devices = yas::audio_device::all_devices();

    NSMutableArray *titles = [NSMutableArray arrayWithCapacity:all_devices.size()];

    for (auto &device : all_devices) {
        [titles addObject:(__bridge NSString *)device->cf_name()];
    }

    [titles addObject:@"None"];

    self.deviceNames = titles;

    auto device = _device_io_node->device();
    auto index = yas::audio_device::index_of_device(device);
    if (index) {
        self.selectedDeviceIndex = *index;
    } else {
        self.selectedDeviceIndex = all_devices.size();
    }
}

- (void)_updateConnection
{
    self.outputRoutes = nil;
    self.inputRoutes = nil;

    if (_engine) {
        _engine->disconnect(_tap_node);

        if (const auto &device = _device_io_node->device()) {
            if (device->output_channel_count() > 0) {
                _engine->connect(_tap_node, _device_io_node, device->output_format());
            }

            if (device->input_channel_count() > 0) {
                _engine->connect(_device_io_node, _tap_node, device->input_format());
            }
        }
    }

    if (auto const device = _device_io_node->device()) {
        NSLog(@"device name = %@ - samplerate = %@", device->cf_name(), @(device->nominal_sample_rate()));

        const uint32_t output_channel_count = device->output_channel_count();
        const uint32_t input_channel_count = device->input_channel_count();
        NSMutableArray *outputRoutes = [NSMutableArray arrayWithCapacity:output_channel_count];
        NSMutableArray *inputRoutes = [NSMutableArray arrayWithCapacity:input_channel_count];

        for (uint32_t i = 0; i < output_channel_count; ++i) {
            YASAudioDeviceRouteSampleData *data = [YASAudioDeviceRouteSampleData data];
            data.index = i;
            data.enabled = NO;
            [outputRoutes addObject:data];
        }

        for (uint32_t i = 0; i < input_channel_count; ++i) {
            YASAudioDeviceRouteSampleData *data = [YASAudioDeviceRouteSampleData data];
            data.index = i;
            data.enabled = NO;
            [inputRoutes addObject:data];
        }

        self.outputRoutes = outputRoutes;
        self.inputRoutes = inputRoutes;
        self.nominalSampleRate = device->nominal_sample_rate();
    } else {
        self.outputRoutes = nil;
        self.inputRoutes = nil;
        self.nominalSampleRate = 0.0;
    }
}

#pragma mark - accessor

- (void)setSelectedDeviceIndex:(NSUInteger)selectedDeviceIndex
{
    if (_selectedDeviceIndex != selectedDeviceIndex) {
        _selectedDeviceIndex = selectedDeviceIndex;

        auto all_devices = yas::audio_device::all_devices();

        if (selectedDeviceIndex < all_devices.size()) {
            auto device = all_devices[selectedDeviceIndex];
            [self setDevice:device];
        } else {
            [self setDevice:nullptr];
        }
    }
}

- (void)setDevice:(const yas::audio_device_sptr &)selected_device
{
    _device_observer = nullptr;

    const auto all_devices = yas::audio_device::all_devices();

    if (selected_device && std::find(all_devices.begin(), all_devices.end(), selected_device) != all_devices.end()) {
        _device_io_node->set_device(selected_device);

        const auto device_observer = yas::make_observer(selected_device->property_subject());
        device_observer->add_handler(
            selected_device->property_subject(), yas::audio_device::method::device_did_change,
            [selected_device, weak_container = _self_container](const auto &method, const auto &infos) {
                if (infos.size() > 0) {
                    const auto &device_id = infos[0].object_id;
                    if (selected_device->audio_device_id() == device_id) {
                        if (const auto strong_container = weak_container->lock()) {
                            YASAudioEngineDeviceIOSampleViewController *controller = strong_container.object();
                            [controller _updateConnection];
                        }
                    }
                }
            });
        _device_observer = device_observer;
    } else {
        _device_io_node->set_device(nullptr);
    }

    [self _updateConnection];
}

@end
