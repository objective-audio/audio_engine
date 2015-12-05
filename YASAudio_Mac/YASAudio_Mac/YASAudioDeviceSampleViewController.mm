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

            void process(const yas::audio::pcm_buffer &input_buffer, yas::audio::pcm_buffer &output_buffer)
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
                    yas::audio::frame_enumerator enumerator(output_buffer);
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

namespace yas
{
    namespace sample
    {
        struct device_vc_internal {
            yas::audio_graph audio_graph = nullptr;
            yas::audio::device_io audio_device_io = nullptr;
            yas::base system_observer = nullptr;
            yas::base device_observer = nullptr;
            sample_kernel_sptr kernel;
            yas::objc::container<yas::objc::weak> self_container;

            ~device_vc_internal()
            {
                self_container.set_object(nil);
            }
        };
    }
}

@implementation YASAudioDeviceSampleViewController {
    yas::sample::device_vc_internal _internal;
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

    if (!_internal.self_container) {
        _internal.self_container.set_object(self);
    }

    _internal.audio_graph = yas::audio_graph();
    _internal.audio_device_io = yas::audio::device_io{yas::audio::device(nullptr)};
    _internal.audio_graph.add_audio_device_io(_internal.audio_device_io);

    _internal.kernel = std::make_shared<sample_kernel_t>();

    self.throughVolume = _internal.kernel->through_volume();
    self.sineVolume = _internal.kernel->sine_volume();
    self.sineFrequency = _internal.kernel->sine_frequency();

    _internal.system_observer = yas::audio::device::system_subject().make_observer(
        yas::audio::device::hardware_did_change_key,
        [weak_container = _internal.self_container](const auto &, const auto &) {
            if (auto strong_container = weak_container.lock()) {
                YASAudioDeviceSampleViewController *strongSelf = strong_container.object();
                [strongSelf _updateDeviceNames];
            }
        });

    auto weak_device_io = yas::to_weak(_internal.audio_device_io);
    _internal.audio_device_io.set_render_callback([weak_device_io, kernel = _internal.kernel](
        yas::audio::pcm_buffer & output_buffer, const yas::audio::time &when) {
        if (auto device_io = weak_device_io.lock()) {
            kernel->process(device_io.input_buffer_on_render(), output_buffer);
        }
    });

    [self _updateDeviceNames];

    auto default_device = yas::audio::device::default_output_device();
    if (auto index = yas::audio::device::index_of_device(default_device)) {
        self.selectedDeviceIndex = *index;
    }
}

- (void)dispose
{
    _internal.audio_graph = nullptr;
    _internal.audio_device_io = nullptr;
    _internal.system_observer = nullptr;
    _internal.device_observer = nullptr;
    _internal.kernel = nullptr;
}

- (void)viewDidAppear
{
    [super viewDidAppear];

    [self setup];

    if (_internal.audio_graph) {
        _internal.audio_graph.start();
    }
}

- (void)viewWillDisappear
{
    [super viewWillDisappear];

    if (_internal.audio_graph) {
        _internal.audio_graph.stop();
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
    if (_internal.self_container) {
        _internal.self_container.set_object(nil);
    }
    YASSuperDealloc;
}

#pragma mark -

- (void)setThroughVolume:(Float64)throughVolume
{
    _throughVolume = throughVolume;
    _internal.kernel->set_througn_volume(throughVolume);
}

- (void)setSineFrequency:(Float64)sineFrequency
{
    _sineFrequency = sineFrequency;
    _internal.kernel->set_sine_frequency(sineFrequency);
}

- (void)setSineVolume:(Float64)sineVolume
{
    _sineVolume = sineVolume;
    _internal.kernel->set_sine_volume(sineVolume);
}

- (void)setSelectedDeviceIndex:(NSUInteger)selectedDeviceIndex
{
    if (_selectedDeviceIndex != selectedDeviceIndex) {
        _selectedDeviceIndex = selectedDeviceIndex;

        auto all_devices = yas::audio::device::all_devices();

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
    auto all_devices = yas::audio::device::all_devices();

    NSMutableArray *titles = [NSMutableArray arrayWithCapacity:all_devices.size()];

    for (auto &device : all_devices) {
        [titles addObject:(NSString *)device.name()];
    }

    [titles addObject:@"None"];

    self.deviceNames = titles;

    auto device = _internal.audio_device_io.device();
    auto index = yas::audio::device::index_of_device(device);
    if (index) {
        self.selectedDeviceIndex = *index;
    } else {
        self.selectedDeviceIndex = all_devices.size();
    }
}

- (void)setDevice:(const yas::audio::device &)selected_device
{
    if (auto prev_audio_device = _internal.audio_device_io.device()) {
        _internal.device_observer = nullptr;
    }

    auto all_devices = yas::audio::device::all_devices();

    if (selected_device && std::find(all_devices.begin(), all_devices.end(), selected_device) != all_devices.end()) {
        _internal.audio_device_io.set_device(selected_device);

        _internal.device_observer = selected_device.subject().make_observer(
            yas::audio::device::device_did_change_key, [selected_device, weak_container = _internal.self_container](
                                                           const std::string &method, const auto &change_info) {
                const auto &infos = change_info.property_infos;
                if (infos.size() > 0) {
                    auto &device_id = infos.at(0).object_id;
                    if (selected_device.audio_device_id() == device_id) {
                        if (auto strong_container = weak_container.lock()) {
                            YASAudioDeviceSampleViewController *strongSelf = strong_container.object();
                            [strongSelf _updateDeviceInfo];
                        }
                    }
                }
            });
    } else {
        _internal.audio_device_io.set_device(nullptr);
    }

    [self _updateDeviceInfo];
}

- (void)_updateDeviceInfo
{
    auto const device = _internal.audio_device_io.device();
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
