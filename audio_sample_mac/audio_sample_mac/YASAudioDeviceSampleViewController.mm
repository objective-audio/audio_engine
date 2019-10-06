//
//  YASAudioDeviceSampleViewController.m
//

#import "YASAudioDeviceSampleViewController.h"
#import <Accelerate/Accelerate.h>
#import <audio/yas_audio_umbrella.h>
#import <cpp_utils/yas_objc_ptr.h>
#import <objc_utils/yas_objc_macros.h>
#import <objc_utils/yas_objc_unowned.h>
#import <atomic>
#import "YASDecibelValueTransformer.h"
#import "YASFrequencyValueFormatter.h"

using namespace yas;

static uint32_t const kSineDataMaxCount = 4096;

namespace yas::audio_device_sample {
class kernel {
   private:
    std::atomic<double> _through_volume;
    std::atomic<double> _sine_frequency;
    std::atomic<double> _sine_volume;

    double _phase;
    std::vector<float> _sine_data;

   public:
    kernel() : _phase(0), _sine_data(kSineDataMaxCount) {
        _through_volume.store(0);
        _sine_frequency.store(1000.0);
        _sine_volume.store(0.0);
    }

    kernel(const kernel &) = delete;
    kernel(kernel &&) = delete;
    kernel &operator=(const kernel &) = delete;
    kernel &operator=(kernel &&) = delete;

    void set_througn_volume(double value) {
        _through_volume.store(value);
    }

    double through_volume() const {
        return _through_volume.load();
    }

    void set_sine_frequency(double value) {
        _sine_frequency.store(value);
    }

    double sine_frequency() const {
        return _sine_frequency.load();
    }

    void set_sine_volume(double value) {
        _sine_volume.store(value);
    }

    double sine_volume() const {
        return _sine_volume.load();
    }

    void process(audio::pcm_buffer_ptr const &input_buffer, audio::pcm_buffer_ptr const &output_buffer) {
        if (!output_buffer) {
            return;
        }

        uint32_t const frame_length = output_buffer->frame_length();

        if (frame_length == 0) {
            return;
        }

        auto const &format = output_buffer->format();
        if (format.pcm_format() == audio::pcm_format::float32 && format.stride() == 1) {
            if (input_buffer) {
                if (input_buffer->frame_length() >= frame_length) {
                    output_buffer->copy_from(*input_buffer);

                    float const throughVol = through_volume();

                    auto each = audio::make_each_data<float>(*output_buffer);
                    while (yas_each_data_next_ch(each)) {
                        cblas_sscal(frame_length, throughVol, yas_each_data_ptr(each), 1);
                    }
                }
            }

            double const sample_rate = format.sample_rate();
            double const start_phase = _phase;
            double const sine_vol = sine_volume();
            double const freq = sine_frequency();

            if (frame_length < kSineDataMaxCount) {
                _phase = audio::math::fill_sine(&_sine_data[0], frame_length, start_phase,
                                                freq / sample_rate * audio::math::two_pi);

                auto each = audio::make_each_data<float>(*output_buffer);
                while (yas_each_data_next_ch(each)) {
                    cblas_saxpy(frame_length, sine_vol, &_sine_data[0], 1, yas_each_data_ptr(each), 1);
                }
            }
        }
    }
};
}

using sample_kernel_t = audio_device_sample::kernel;
using sample_kernel_ptr = std::shared_ptr<sample_kernel_t>;

@interface YASAudioDeviceSampleViewController ()

@property (nonatomic, strong) NSArray *deviceNames;
@property (nonatomic, assign) double nominalSampleRate;
@property (nonatomic, assign) NSUInteger selectedDeviceIndex;
@property (nonatomic, copy) NSString *deviceInfo;
@property (nonatomic, strong) NSColor *ioThroughTextColor;
@property (nonatomic, strong) NSColor *sineTextColor;

@property (nonatomic, assign) double throughVolume;
@property (nonatomic, assign) double sineVolume;
@property (nonatomic, assign) double sineFrequency;

@end

namespace yas::sample {
struct device_vc_internal {
    audio::graph_ptr graph = nullptr;
    audio::device_io_ptr device_io = nullptr;
    chaining::any_observer_ptr system_observer = nullptr;
    chaining::any_observer_ptr device_observer = nullptr;
    sample_kernel_ptr kernel;
};
}

@implementation YASAudioDeviceSampleViewController {
    sample::device_vc_internal _internal;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)setup {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        YASDecibelValueTransformer *decibelValueFormatter = yas_autorelease([[YASDecibelValueTransformer alloc] init]);
        [NSValueTransformer setValueTransformer:decibelValueFormatter
                                        forName:NSStringFromClass([YASDecibelValueTransformer class])];

        YASFrequencyValueFormatter *freqValueFormatter = yas_autorelease([[YASFrequencyValueFormatter alloc] init]);
        [NSValueTransformer setValueTransformer:freqValueFormatter
                                        forName:NSStringFromClass([YASFrequencyValueFormatter class])];
    });

    _internal.graph = audio::graph::make_shared();
    _internal.device_io = audio::device_io::make_shared(std::nullopt);
    _internal.graph->add_audio_device_io(_internal.device_io);

    _internal.kernel = std::make_shared<sample_kernel_t>();

    self.throughVolume = _internal.kernel->through_volume();
    self.sineVolume = _internal.kernel->sine_volume();
    self.sineFrequency = _internal.kernel->sine_frequency();

    auto unowned_self = objc_ptr_with_move_object([[YASUnownedObject alloc] initWithObject:self]);

    _internal.system_observer =
        audio::device::system_chain(audio::device::system_method::hardware_did_change)
            .perform([unowned_self](auto const &) { [[unowned_self.object() object] _updateDeviceNames]; })
            .end();

    auto weak_device_io = to_weak(_internal.device_io);
    _internal.device_io->set_render_handler([weak_device_io, kernel = _internal.kernel](auto args) {
        if (auto device_io = weak_device_io.lock()) {
            kernel->process(device_io->input_buffer_on_render(), args.output_buffer);
        }
    });

    [self _updateDeviceNames];

    if (auto const default_device = audio::device::default_output_device()) {
        if (auto index = audio::device::index_of_device(*default_device)) {
            self.selectedDeviceIndex = *index;
        }
    }
}

- (void)dispose {
    _internal.graph = nullptr;
    _internal.device_io = nullptr;
    _internal.system_observer = nullptr;
    _internal.device_observer = nullptr;
    _internal.kernel = nullptr;
}

- (void)viewDidAppear {
    [super viewDidAppear];

    [self setup];

    if (_internal.graph) {
        _internal.graph->start();
    }
}

- (void)viewWillDisappear {
    [super viewWillDisappear];

    if (_internal.graph) {
        _internal.graph->stop();
    }

    [self dispose];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    yas_release(_deviceNames);
    yas_release(_deviceInfo);
    yas_release(_ioThroughTextColor);
    yas_release(_sineTextColor);

    yas_super_dealloc();
}

#pragma mark -

- (void)setThroughVolume:(double)throughVolume {
    _throughVolume = throughVolume;
    _internal.kernel->set_througn_volume(throughVolume);
}

- (void)setSineFrequency:(double)sineFrequency {
    _sineFrequency = sineFrequency;
    _internal.kernel->set_sine_frequency(sineFrequency);
}

- (void)setSineVolume:(double)sineVolume {
    _sineVolume = sineVolume;
    _internal.kernel->set_sine_volume(sineVolume);
}

- (void)setSelectedDeviceIndex:(NSUInteger)selectedDeviceIndex {
    if (_selectedDeviceIndex != selectedDeviceIndex) {
        _selectedDeviceIndex = selectedDeviceIndex;

        auto const all_devices = audio::device::all_devices();

        if (selectedDeviceIndex < all_devices.size()) {
            auto const &device = all_devices[selectedDeviceIndex];
            [self setDevice:device];
        } else {
            [self setDevice:std::nullopt];
        }
    }
}

- (void)_updateDeviceNames {
    auto all_devices = audio::device::all_devices();

    NSMutableArray *titles = [NSMutableArray arrayWithCapacity:all_devices.size()];

    for (auto &device : all_devices) {
        [titles addObject:(NSString *)device->name()];
    }

    [titles addObject:@"None"];

    self.deviceNames = titles;

    std::optional<NSUInteger> index = std::nullopt;

    if (auto const &device_opt = _internal.device_io->device()) {
        index = audio::device::index_of_device(*device_opt);
    }

    if (index) {
        self.selectedDeviceIndex = *index;
    } else {
        self.selectedDeviceIndex = all_devices.size();
    }
}

- (void)setDevice:(std::optional<audio::device_ptr> const &)selected_device {
    if (auto prev_audio_device = _internal.device_io->device()) {
        _internal.device_observer = nullptr;
    }

    auto all_devices = audio::device::all_devices();

    _internal.device_io->set_device(selected_device);

    if (selected_device && std::find(all_devices.begin(), all_devices.end(), selected_device) != all_devices.end()) {
        auto unowned_self = objc_ptr_with_move_object([[YASUnownedObject alloc] initWithObject:self]);

        auto const &device = *selected_device;

        _internal.device_observer = device->chain(audio::device::method::device_did_change)
                                        .perform([device, unowned_self](auto const &change_info) {
                                            auto const &infos = change_info.property_infos;
                                            if (infos.size() > 0) {
                                                auto &device_id = infos.at(0).object_id;
                                                if (device->audio_device_id() == device_id) {
                                                    [[unowned_self.object() object] _updateDeviceInfo];
                                                }
                                            }
                                        })
                                        .end();
    }

    [self _updateDeviceInfo];
}

- (void)_updateDeviceInfo {
    auto const &device_opt = _internal.device_io->device();
    NSColor *onColor = [NSColor blackColor];
    NSColor *offColor = [NSColor lightGrayColor];
    if (device_opt) {
        auto const &device = *device_opt;
        self.deviceInfo = [NSString
            stringWithFormat:@"name = %@\nnominal samplerate = %@", device->name(), @(device->nominal_sample_rate())];
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
