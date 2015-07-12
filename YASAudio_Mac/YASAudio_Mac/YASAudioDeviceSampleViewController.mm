//
//  YASAudioDeviceSampleViewController.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioDeviceSampleViewController.h"
#import "YASMacros.h"
#import "YASWeakSupport.h"
#import "YASAudioMath.h"
#import "YASDecibelValueTransformer.h"
#import "YASFrequencyValueFormatter.h"
#import <Accelerate/Accelerate.h>
#import "yas_audio_graph.h"
#import "yas_audio_unit.h"
#import "yas_audio_device.h"
#import "yas_audio_device_io.h"
#import "yas_audio_data.h"
#import "yas_audio_enumerator.h"
#import "yas_audio_format.h"
#import "yas_audio_time.h"
#import "yas_observing.h"
#import "yas_objc_container.h"
#import <atomic>
#import <vector>

static const UInt32 kSineDataMaxCount = 4096;

namespace yas
{
    namespace audio_device_sample
    {
        class kernel
        {
           private:
            std::atomic<Float64> _through_volume;
            std::atomic<Float64> _sine_frequency;
            std::atomic<Float64> _sine_volume;

            Float64 _phase;
            std::vector<Float32> _sine_data;

           public:
            kernel() : _phase(0), _sine_data(kSineDataMaxCount)
            {
                _through_volume.store(0);
                _sine_frequency.store(1000.0);
                _sine_volume.store(0.0);
            }

            kernel(const kernel &) = delete;
            kernel(kernel &&) = delete;
            kernel &operator=(const kernel &) = delete;
            kernel &operator=(kernel &&) = delete;

            void set_througn_volume(Float64 value)
            {
                _through_volume.store(value);
            }

            Float64 through_volume() const
            {
                return _through_volume.load();
            }

            void set_sine_frequency(Float64 value)
            {
                _sine_frequency.store(value);
            }

            Float64 sine_frequency() const
            {
                return _sine_frequency.load();
            }

            void set_sine_volume(Float64 value)
            {
                _sine_volume.store(value);
            }

            Float64 sine_volume() const
            {
                return _sine_volume.load();
            }

            void process(const yas::audio_data_ptr &input_data, yas::audio_data_ptr &output_data)
            {
                if (!output_data) {
                    return;
                }

                const UInt32 frame_length = output_data->frame_length();

                if (frame_length == 0) {
                    return;
                }

                const yas::audio_format_ptr format = output_data->format();
                if (format->pcm_format() == yas::pcm_format::float32 && format->stride() == 1) {
                    yas::audio_frame_enumerator enumerator(output_data);
                    const yas::audio_pointer *pointer = enumerator.pointer();

                    if (input_data) {
                        if (input_data->frame_length() >= frame_length) {
                            yas::copy_data_flexibly(input_data, output_data);

                            const Float32 throughVol = through_volume();

                            while (pointer->v) {
                                cblas_sscal(frame_length, throughVol, pointer->f32, 1);
                                yas_audio_frame_enumerator_move_channel(enumerator);
                            }
                            yas_audio_frame_enumerator_reset(enumerator);
                        }
                    }

                    const Float64 sample_rate = format->sample_rate();
                    const Float64 start_phase = _phase;
                    const Float64 sine_vol = sine_volume();
                    const Float64 freq = sine_frequency();

                    if (frame_length < kSineDataMaxCount) {
                        _phase = YASAudioVectorSinef(&_sine_data[0], frame_length, start_phase,
                                                     freq / sample_rate * YAS_2_PI);

                        while (pointer->v) {
                            cblas_saxpy(frame_length, sine_vol, &_sine_data[0], 1, pointer->f32, 1);
                            yas_audio_frame_enumerator_move_channel(enumerator);
                        }
                        yas_audio_frame_enumerator_reset(enumerator);
                    }
                }
            }
        };
    }
}

typedef yas::audio_device_sample::kernel sample_kernel;
typedef std::shared_ptr<yas::audio_device_sample::kernel> sample_kernel_ptr;

@interface YASAudioDeviceSampleViewController ()

@property (nonatomic, strong) NSArray *deviceNames;
@property (nonatomic, assign) Float64 nominalSampleRate;
@property (nonatomic, assign) NSUInteger selectedDeviceIndex;
@property (nonatomic, copy) NSString *deviceInfo;
@property (nonatomic, strong) NSColor *ioThroughTextColor;
@property (nonatomic, strong) NSColor *sineTextColor;

@property (nonatomic, assign) Float64 throughVolume;
@property (nonatomic, assign) Float64 sineVolume;
@property (nonatomic, assign) Float64 sineFrequency;

@end

@implementation YASAudioDeviceSampleViewController {
    yas::audio_graph_ptr _audio_graph;
    yas::audio_device_io_ptr _audio_device_io;
    yas::audio_device_observer_ptr _audio_device_observer;
    sample_kernel_ptr _kernel;
    yas::objc_container_ptr _self_container;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)setup
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        YASDecibelValueTransformer *decibelValueFormatter = YASAutorelease([[YASDecibelValueTransformer alloc] init]);
        [NSValueTransformer setValueTransformer:decibelValueFormatter
                                        forName:NSStringFromClass([YASDecibelValueTransformer class])];

        YASFrequencyValueFormatter *freqValueFormatter = YASAutorelease([[YASFrequencyValueFormatter alloc] init]);
        [NSValueTransformer setValueTransformer:freqValueFormatter
                                        forName:NSStringFromClass([YASFrequencyValueFormatter class])];
    });

    if (!_self_container) {
        _self_container = yas::objc_container::create(self);
    }

    _audio_graph = yas::audio_graph::create();
    _audio_device_io = yas::audio_device_io::create();
    _audio_graph->add_audio_device_io(_audio_device_io);

    _kernel = std::make_shared<sample_kernel>();

    self.throughVolume = _kernel->through_volume();
    self.sineVolume = _kernel->sine_volume();
    self.sineFrequency = _kernel->sine_frequency();

    _audio_device_observer = yas::audio_device_observer::create();
    _audio_device_observer->add_handler(
        yas::audio_device::system_subject(), yas::audio_device::method::hardware_did_change,
        [&self_container = _self_container](const auto &, const auto &) {
            YASAudioDeviceSampleViewController *strongSelf = self_container->retained_object();
            [strongSelf updateDeviceNames];
            YASRelease(strongSelf);
        });

    std::weak_ptr<yas::audio_device_io> weak_device_io = _audio_device_io;
    _audio_device_io->set_render_callback([weak_device_io, kernel = _kernel](yas::audio_data_ptr & out_data,
                                                                             yas::audio_time_ptr & when) {
        if (auto device_io = weak_device_io.lock()) {
            kernel->process(device_io->input_data_on_render(), out_data);
        }
    });

    [self updateDeviceNames];

    auto default_device = yas::audio_device::default_output_device();
    auto index = yas::audio_device::index_of_device(default_device);
    if (index) {
        self.selectedDeviceIndex = *index;
    }
}

- (void)dispose
{
    _audio_graph = nullptr;
    _audio_device_io = nullptr;
    _audio_device_observer = nullptr;
    _kernel = nullptr;
}

- (void)viewDidAppear
{
    [super viewDidAppear];

    [self setup];

    if (_audio_graph) {
        _audio_graph->start();
    }
}

- (void)viewWillDisappear
{
    [super viewWillDisappear];

    if (_audio_graph) {
        _audio_graph->stop();
    }

    [self dispose];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    YASRelease(_deviceNames);
    YASRelease(_deviceInfo);
    YASRelease(_ioThroughTextColor);
    YASRelease(_sineTextColor);
    if (_self_container) {
        _self_container->set_object(nil);
    }
    YASSuperDealloc;
}

#pragma mark -

- (void)setThroughVolume:(Float64)throughVolume
{
    _throughVolume = throughVolume;
    _kernel->set_througn_volume(throughVolume);
}

- (void)setSineFrequency:(Float64)sineFrequency
{
    _sineFrequency = sineFrequency;
    _kernel->set_sine_frequency(sineFrequency);
}

- (void)setSineVolume:(Float64)sineVolume
{
    _sineVolume = sineVolume;
    _kernel->set_sine_volume(sineVolume);
}

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

- (void)updateDeviceNames
{
    auto all_devices = yas::audio_device::all_devices();

    NSMutableArray *titles = [NSMutableArray arrayWithCapacity:all_devices.size()];

    for (auto &device : all_devices) {
        CFStringRef name = device->name();
        [titles addObject:(NSString *)name];
    }

    [titles addObject:@"None"];

    self.deviceNames = titles;

    auto device = _audio_device_io->audio_device();
    auto index = yas::audio_device::index_of_device(device);
    if (index) {
        self.selectedDeviceIndex = *index;
    } else {
        self.selectedDeviceIndex = all_devices.size();
    }
}

- (void)setDevice:(yas::audio_device_ptr)selected_device
{
    if (auto prev_audio_device = _audio_device_io->audio_device()) {
        _audio_device_observer->remove_handler(prev_audio_device->property_subject(),
                                               yas::audio_device::method::device_did_change);
    }

    auto all_devices = yas::audio_device::all_devices();

    if (selected_device && std::find(all_devices.begin(), all_devices.end(), selected_device) != all_devices.end()) {
        _audio_device_io->set_audio_device(selected_device);

        _audio_device_observer->add_handler(
            selected_device->property_subject(), yas::audio_device::method::device_did_change,
            [selected_device, self_container = _self_container](const auto &method, const auto &infos) {
                if (infos.size() > 0) {
                    auto &device_id = infos[0].object_id;
                    if (selected_device->audio_device_id() == device_id) {
                        YASAudioDeviceSampleViewController *strongSelf = self_container->retained_object();
                        [strongSelf updateDeviceInfo];
                        YASRelease(strongSelf);
                    }
                }
            });
    } else {
        _audio_device_io->set_audio_device(nullptr);
    }

    [self updateDeviceInfo];
}

- (void)updateDeviceInfo
{
    auto const device = _audio_device_io->audio_device();
    NSColor *onColor = [NSColor blackColor];
    NSColor *offColor = [NSColor lightGrayColor];
    if (device) {
        self.deviceInfo = [NSString stringWithFormat:@"name = %@\nnominal samplerate = %@", (NSString *)device->name(),
                                                     @(device->nominal_sample_rate())];
        ;
        self.nominalSampleRate = device->nominal_sample_rate();
        self.ioThroughTextColor = (device->input_format() && device->output_format()) ? onColor : offColor;
        self.sineTextColor = device->output_format() ? onColor : offColor;
    } else {
        self.deviceInfo = nil;
        self.nominalSampleRate = 0;
        self.ioThroughTextColor = offColor;
        self.sineTextColor = offColor;
    }
}

@end
