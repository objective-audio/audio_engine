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
#import "yas_audio_sample_kernel.h"

using namespace yas;

using sample_kernel_t = audio::sample::kernel;
using sample_kernel_ptr = std::shared_ptr<sample_kernel_t>;

@interface YASAudioDeviceSampleViewController ()

@property (nonatomic, strong) NSArray *deviceNames;
@property (nonatomic, assign) double nominalSampleRate;
@property (nonatomic, assign) NSUInteger selectedDeviceIndex;
@property (nonatomic, copy) NSAttributedString *deviceInfo;
@property (nonatomic, strong) NSColor *ioThroughTextColor;
@property (nonatomic, strong) NSColor *sineTextColor;

@property (nonatomic, assign) double throughVolume;
@property (nonatomic, assign) double sineVolume;
@property (nonatomic, assign) double sineFrequency;

@end

namespace yas::sample {
struct device_vc_cpp {
    audio::io_ptr const io = audio::io::make_shared(std::nullopt);
    sample_kernel_ptr const kernel = std::make_shared<sample_kernel_t>();
    std::optional<chaining::any_observer_ptr> system_observer = std::nullopt;
    std::optional<chaining::any_observer_ptr> device_observer = std::nullopt;
};
}

@implementation YASAudioDeviceSampleViewController {
    std::shared_ptr<sample::device_vc_cpp> _cpp;
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

    self->_cpp = std::make_shared<sample::device_vc_cpp>();
    self.throughVolume = _cpp->kernel->through_volume();
    self.sineVolume = _cpp->kernel->sine_volume();
    self.sineFrequency = _cpp->kernel->sine_frequency();

    auto unowned_self = objc_ptr_with_move_object([[YASUnownedObject alloc] initWithObject:self]);

    self->_cpp->system_observer =
        audio::mac_device::system_chain()
            .perform([unowned_self](auto const &) { [[unowned_self.object() object] _updateDeviceNames]; })
            .end();

    auto weak_io = to_weak(self->_cpp->io);
    self->_cpp->io->set_render_handler([weak_io, kernel = self->_cpp->kernel](auto args) {
        if (auto io = weak_io.lock()) {
            kernel->process(io->input_buffer_on_render(), args.output_buffer);
        }
    });

    [self _updateDeviceNames];

    if (auto const default_device = audio::mac_device::default_output_device()) {
        if (auto index = audio::mac_device::index_of_device(*default_device)) {
            self.selectedDeviceIndex = *index;
        }
    }
}

- (void)dispose {
    self->_cpp = nullptr;
}

- (void)viewDidAppear {
    [super viewDidAppear];

    [self setup];

    self->_cpp->io->start();
}

- (void)viewWillDisappear {
    [super viewWillDisappear];

    self->_cpp->io->stop();

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
    self->_throughVolume = throughVolume;
    self->_cpp->kernel->set_througn_volume(throughVolume);
}

- (void)setSineFrequency:(double)sineFrequency {
    self->_sineFrequency = sineFrequency;
    self->_cpp->kernel->set_sine_frequency(sineFrequency);
}

- (void)setSineVolume:(double)sineVolume {
    self->_sineVolume = sineVolume;
    self->_cpp->kernel->set_sine_volume(sineVolume);
}

- (void)setSelectedDeviceIndex:(NSUInteger)selectedDeviceIndex {
    if (_selectedDeviceIndex != selectedDeviceIndex) {
        _selectedDeviceIndex = selectedDeviceIndex;

        auto const all_devices = audio::mac_device::all_devices();

        if (selectedDeviceIndex < all_devices.size()) {
            auto const &device = all_devices[selectedDeviceIndex];
            [self setDevice:device];
        } else {
            [self setDevice:std::nullopt];
        }
    }
}

- (void)_updateDeviceNames {
    auto all_devices = audio::mac_device::all_devices();

    NSMutableArray *titles = [NSMutableArray arrayWithCapacity:all_devices.size()];

    for (auto &device : all_devices) {
        [titles addObject:(__bridge NSString *)to_cf_object(device->name())];
    }

    [titles addObject:@"None"];

    self.deviceNames = titles;

    std::optional<NSUInteger> index = std::nullopt;

    if (auto const &device_opt = _cpp->io->device()) {
        if (auto const device = std::dynamic_pointer_cast<audio::mac_device>(device_opt.value())) {
            index = audio::mac_device::index_of_device(device);
        }
    }

    if (index) {
        self.selectedDeviceIndex = *index;
    } else {
        self.selectedDeviceIndex = all_devices.size();
    }
}

- (void)setDevice:(std::optional<audio::mac_device_ptr> const &)selected_device {
    self->_cpp->device_observer = std::nullopt;

    auto all_devices = audio::mac_device::all_devices();

    self->_cpp->io->set_device(selected_device);

    if (selected_device && std::find(all_devices.begin(), all_devices.end(), selected_device) != all_devices.end()) {
        auto unowned_self = objc_ptr_with_move_object([[YASUnownedObject alloc] initWithObject:self]);

        auto const &device = *selected_device;

        self->_cpp->device_observer = device->chain()
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

        if (!self->_cpp->io->is_running()) {
            self->_cpp->io->start();
        }
    }

    [self _updateDeviceInfo];
}

- (void)_updateDeviceInfo {
    auto const &device_opt = self->_cpp->io->device();
    NSColor *onColor = [NSColor labelColor];
    NSColor *offColor = [NSColor quaternaryLabelColor];
    if (device_opt) {
        if (auto const &device = std::dynamic_pointer_cast<audio::mac_device>(*device_opt)) {
            NSString *string = [NSString
                stringWithFormat:@"name = %@\nnominal samplerate = %@\noutput channels = %@\ninput channels = %@",
                                 to_cf_object(device->name()), @(device->nominal_sample_rate()),
                                 @(device->output_channel_count()), @(device->input_channel_count())];
            auto attributed_string = objc_ptr_with_move_object([[NSAttributedString alloc]
                initWithString:string
                    attributes:@{NSForegroundColorAttributeName: [NSColor labelColor]}]);
            self.deviceInfo = attributed_string.object();

            self.nominalSampleRate = device->nominal_sample_rate();
            self.ioThroughTextColor = (device->input_format() && device->output_format()) ? onColor : offColor;
            self.sineTextColor = device->output_format() ? onColor : offColor;

            return;
        }
    }
    self.deviceInfo = nil;
    self.nominalSampleRate = 0;
    self.ioThroughTextColor = offColor;
    self.sineTextColor = offColor;
}

@end
