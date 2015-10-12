//
//  YASAudioDeviceSampleViewController.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioDeviceSampleViewController.h"
#import "YASDecibelValueTransformer.h"
#import "YASFrequencyValueFormatter.h"
#import "yas_audio.h"
#import <atomic>
#import <Accelerate/Accelerate.h>

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

            void process(const yas::audio_pcm_buffer &input_buffer, yas::audio_pcm_buffer &output_buffer)
            {
                if (!output_buffer) {
                    return;
                }

                const UInt32 frame_length = output_buffer.frame_length();

                if (frame_length == 0) {
                    return;
                }

                const auto &format = output_buffer.format();
                if (format.pcm_format() == yas::pcm_format::float32 && format.stride() == 1) {
                    yas::audio_frame_enumerator enumerator(output_buffer);
                    auto pointer = enumerator.pointer();

                    if (input_buffer) {
                        if (input_buffer.frame_length() >= frame_length) {
                            output_buffer.copy_from(input_buffer);

                            const Float32 throughVol = through_volume();

                            while (pointer->v) {
                                cblas_sscal(frame_length, throughVol, pointer->f32, 1);
                                yas_audio_frame_enumerator_move_channel(enumerator);
                            }
                            yas_audio_frame_enumerator_reset(enumerator);
                        }
                    }

                    const Float64 sample_rate = format.sample_rate();
                    const Float64 start_phase = _phase;
                    const Float64 sine_vol = sine_volume();
                    const Float64 freq = sine_frequency();

                    if (frame_length < kSineDataMaxCount) {
                        _phase = yas::audio_math::fill_sine(&_sine_data[0], frame_length, start_phase,
                                                            freq / sample_rate * yas::audio_math::two_pi);

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

using sample_kernel_t = yas::audio_device_sample::kernel;
using sample_kernel_sptr = std::shared_ptr<sample_kernel_t>;

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
    yas::audio_graph _audio_graph;
    yas::audio_device_io _audio_device_io;
    yas::observer _audio_device_observer;
    sample_kernel_sptr _kernel;
    yas::objc::container<yas::objc::weak> _self_container;
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
        _self_container.set_object(self);
    }

    _audio_graph.prepare();
    _audio_device_io.prepare();
    _audio_graph.add_audio_device_io(_audio_device_io);

    _kernel = std::make_shared<sample_kernel_t>();

    self.throughVolume = _kernel->through_volume();
    self.sineVolume = _kernel->sine_volume();
    self.sineFrequency = _kernel->sine_frequency();

    _audio_device_observer.clear();
    _audio_device_observer.add_handler(
        yas::audio_device::system_subject(), yas::audio_device_method::hardware_did_change,
        [weak_container = _self_container](const auto &, const auto &) {
            if (auto strong_container = weak_container.lock()) {
                YASAudioDeviceSampleViewController *strongSelf = strong_container.object();
                [strongSelf _updateDeviceNames];
            }
        });

    yas::audio_device_io::weak weak_device_io(_audio_device_io);
    _audio_device_io.set_render_callback([weak_device_io, kernel = _kernel](yas::audio_pcm_buffer & output_buffer,
                                                                            const yas::audio_time &when) {
        if (auto device_io = weak_device_io.lock()) {
            kernel->process(device_io.input_buffer_on_render(), output_buffer);
        }
    });

    [self _updateDeviceNames];

    auto default_device = yas::audio_device::default_output_device();
    if (auto index = yas::audio_device::index_of_device(default_device)) {
        self.selectedDeviceIndex = *index;
    }
}

- (void)dispose
{
    _audio_graph = nullptr;
    _audio_device_io = nullptr;
    _audio_device_observer.clear();
    _kernel = nullptr;
}

- (void)viewDidAppear
{
    [super viewDidAppear];

    [self setup];

    if (_audio_graph) {
        _audio_graph.start();
    }
}

- (void)viewWillDisappear
{
    [super viewWillDisappear];

    if (_audio_graph) {
        _audio_graph.stop();
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
        _self_container.set_object(nil);
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

- (void)_updateDeviceNames
{
    auto all_devices = yas::audio_device::all_devices();

    NSMutableArray *titles = [NSMutableArray arrayWithCapacity:all_devices.size()];

    for (auto &device : all_devices) {
        [titles addObject:(NSString *)device.name()];
    }

    [titles addObject:@"None"];

    self.deviceNames = titles;

    auto device = _audio_device_io.device();
    auto index = yas::audio_device::index_of_device(device);
    if (index) {
        self.selectedDeviceIndex = *index;
    } else {
        self.selectedDeviceIndex = all_devices.size();
    }
}

- (void)setDevice:(const yas::audio_device &)selected_device
{
    if (auto prev_audio_device = _audio_device_io.device()) {
        _audio_device_observer.remove_handler(prev_audio_device.property_subject(),
                                              yas::audio_device_method::device_did_change);
    }

    auto all_devices = yas::audio_device::all_devices();

    if (selected_device && std::find(all_devices.begin(), all_devices.end(), selected_device) != all_devices.end()) {
        _audio_device_io.set_device(selected_device);

        _audio_device_observer.add_handler(
            selected_device.property_subject(), yas::audio_device_method::device_did_change,
            [selected_device, weak_container = _self_container](const std::string &method, const yas::any &sender) {
                const auto &infos = sender.get<yas::audio_device::property_infos_sptr>();
                if (infos->size() > 0) {
                    auto &device_id = infos->at(0).object_id;
                    if (selected_device.audio_device_id() == device_id) {
                        if (auto strong_container = weak_container.lock()) {
                            YASAudioDeviceSampleViewController *strongSelf = strong_container.object();
                            [strongSelf _updateDeviceInfo];
                        }
                    }
                }
            });
    } else {
        _audio_device_io.set_device(nullptr);
    }

    [self _updateDeviceInfo];
}

- (void)_updateDeviceInfo
{
    auto const device = _audio_device_io.device();
    NSColor *onColor = [NSColor blackColor];
    NSColor *offColor = [NSColor lightGrayColor];
    if (device) {
        self.deviceInfo = [NSString
            stringWithFormat:@"name = %@\nnominal samplerate = %@", device.name(), @(device.nominal_sample_rate())];
        ;
        self.nominalSampleRate = device.nominal_sample_rate();
        self.ioThroughTextColor = (device.input_format() && device.output_format()) ? onColor : offColor;
        self.sineTextColor = device.output_format() ? onColor : offColor;
    } else {
        self.deviceInfo = nil;
        self.nominalSampleRate = 0;
        self.ioThroughTextColor = offColor;
        self.sineTextColor = offColor;
    }
}

@end
