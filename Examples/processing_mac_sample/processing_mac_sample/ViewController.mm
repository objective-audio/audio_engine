//
//  ViewController.mm
//

#import "ViewController.h"
#import <UniformTypeIdentifiers/UTCoreTypes.h>
#import <audio-engine/file/file.h>
#import <audio-engine/file/file_utils.h>
#import <audio-engine/format/format.h>
#import <audio-engine/pcm_buffer/pcm_buffer.h>
#import <cpp-utils/cf_utils.h>
#import <cpp-utils/fast_each.h>
#import <cpp-utils/result.h>
#import <objc-utils/macros.h>
#import <audio-processing/umbrella.hpp>
#import <iostream>

using namespace yas;
using namespace yas::proc;

typedef NS_ENUM(NSUInteger, SampleBits) {
    SampleBits16,
    SampleBits32,
};

@interface ViewController ()

@property (nonatomic, assign) IBOutlet NSSlider *bitsSlider;
@property (nonatomic, assign) IBOutlet NSSlider *sampleRateSlider;
@property (nonatomic, assign) IBOutlet NSSlider *freqSlider;
@property (nonatomic, assign) IBOutlet NSSlider *lengthSlider;
@property (nonatomic, assign) IBOutlet NSSlider *startGainSlider;
@property (nonatomic, assign) IBOutlet NSSlider *endGainSlider;
@property (nonatomic, assign) IBOutlet NSSlider *totalGainSlider;

@property (nonatomic, assign) IBOutlet NSTextField *bitsField;
@property (nonatomic, assign) IBOutlet NSTextField *sampleRateField;
@property (nonatomic, assign) IBOutlet NSTextField *freqField;
@property (nonatomic, assign) IBOutlet NSTextField *lengthField;
@property (nonatomic, assign) IBOutlet NSTextField *startGainField;
@property (nonatomic, assign) IBOutlet NSTextField *endGainField;
@property (nonatomic, assign) IBOutlet NSTextField *totalGainField;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.bitsSlider.integerValue = 0;
    self.sampleRateSlider.integerValue = 48000;
    self.freqSlider.integerValue = 1000;
    self.lengthSlider.integerValue = 1;
    self.startGainSlider.floatValue = 1.0f;
    self.endGainSlider.floatValue = 1.0f;
    self.totalGainSlider.floatValue = 0.1f;

    self.bitsField.integerValue = [self bitsValue];
    self.sampleRateField.integerValue = [self sampleRateValue];
    self.freqField.integerValue = [self freqValue];
    self.lengthField.integerValue = [self lengthValue];
    self.startGainField.floatValue = [self startGainValue];
    self.endGainField.floatValue = [self endGainValue];
    self.totalGainField.floatValue = [self totalGainValue];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
}

- (IBAction)bitsSliderValueChanged:(NSSlider *)sender {
    self.bitsField.integerValue = [self bitsValue];
}

- (IBAction)sampleRateSliderValueChanged:(NSSlider *)sender {
    self.sampleRateField.integerValue = [self sampleRateValue];
}

- (IBAction)freqSliderValueChanged:(NSSlider *)sender {
    self.freqField.integerValue = [self freqValue];
}

- (IBAction)lengthSliderValueChanged:(NSSlider *)sender {
    self.lengthField.integerValue = [self lengthValue];
}

- (IBAction)startGainSliderValueChanged:(NSSlider *)sender {
    self.startGainField.floatValue = [self startGainValue];
}

- (IBAction)endGainSliderValueChanged:(NSSlider *)sender {
    self.endGainField.floatValue = [self endGainValue];
}

- (IBAction)totalGainSliderValueChanged:(NSSlider *)sender {
    self.totalGainField.floatValue = [self totalGainValue];
}

- (IBAction)bitsFieldValueChanged:(NSTextField *)sender {
    [self updateSlider:self.bitsSlider
         fromTextField:sender
             formatter:^(NSString *stringValue) {
                 if (stringValue.doubleValue >= 32.0) {
                     return (double)SampleBits32;
                 }
                 return (double)SampleBits16;
             }];
    sender.integerValue = [self bitsValue];
}

- (IBAction)sampleRateFieldValueChanged:(NSTextField *)sender {
    [self updateSlider:self.sampleRateSlider fromTextField:sender];
    sender.integerValue = [self sampleRateValue];
}

- (IBAction)freqFieldValueChanged:(NSTextField *)sender {
    [self updateSlider:self.freqSlider fromTextField:sender];
    sender.integerValue = [self freqValue];
}

- (IBAction)lengthFieldValueChanged:(NSTextField *)sender {
    [self updateSlider:self.lengthSlider fromTextField:sender];
    sender.integerValue = [self lengthValue];
}

- (IBAction)startGainFieldValueChanged:(NSTextField *)sender {
    [self updateSlider:self.startGainSlider fromTextField:sender];
    sender.floatValue = [self startGainValue];
}

- (IBAction)endGainFieldValueChanged:(NSTextField *)sender {
    [self updateSlider:self.endGainSlider fromTextField:sender];
    sender.floatValue = [self endGainValue];
}

- (IBAction)totalGainFieldValueChanged:(NSTextField *)sender {
    [self updateSlider:self.totalGainSlider fromTextField:sender];
    sender.floatValue = [self totalGainValue];
}

- (IBAction)makeAudioFile:(id)sender {
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.allowedContentTypes = @[UTTypeAudio];
    panel.canCreateDirectories = YES;

    if ([panel runModal] == NSModalResponseOK) {
        uint32_t const bits = [self bitsValue];
        sample_rate_t const sample_rate = [self sampleRateValue];
        NSInteger const freqValue = [self freqValue];
        length_t const lengthValue = [self lengthValue];
        float const startGainValue = [self startGainValue];
        float const endGainValue = [self endGainValue];
        float const totalGainValue = [self totalGainValue];

        time::range process_range{0, sample_rate * lengthValue};

        auto const path = to_string((__bridge CFStringRef)panel.URL.absoluteString);
        auto wave_settings = audio::wave_file_settings(double(sample_rate), 1, bits);
        auto create_result = audio::file::make_created(
            {.file_path = path, .file_type = audio::file_type::wave, .settings = wave_settings});

        if (!create_result) {
            std::cout << __PRETTY_FUNCTION__ << " - error:" << to_string(create_result.error()) << std::endl;
            return;
        }

        audio::file_ptr const &file = create_result.value();

        track_index_t trk_idx = 0;

        timeline_ptr timeline = timeline::make_shared();

        if (auto second_track = proc::track::make_shared(); true) {
            timeline->insert_track(trk_idx++, second_track);
            auto second_module = make_signal_module<float>(generator::kind::second, 0);
            second_module->connect_output(to_connector_index(generator::output::value), 0);
            second_track->push_back_module(std::move(second_module), process_range);
        }

        if (auto floor_track = proc::track::make_shared(); true) {
            timeline->insert_track(trk_idx++, floor_track);
            auto floor_module = make_signal_module<float>(math1::kind::floor);
            floor_module->connect_input(to_connector_index(math1::input::parameter), 0);
            floor_module->connect_output(to_connector_index(math1::output::result), 1);
            floor_track->push_back_module(std::move(floor_module), process_range);
        }

        if (auto minus_track = proc::track::make_shared(); true) {
            timeline->insert_track(trk_idx++, minus_track);
            auto minus_module = make_signal_module<float>(math2::kind::minus);
            minus_module->connect_input(to_connector_index(math2::input::left), 0);
            minus_module->connect_input(to_connector_index(math2::input::right), 1);
            minus_module->connect_output(to_connector_index(math2::output::result), 0);
            minus_track->push_back_module(std::move(minus_module), process_range);
        }

        if (auto pi_track = proc::track::make_shared(); true) {
            timeline->insert_track(trk_idx++, pi_track);
            auto pi_module = make_signal_module<float>(2.0f * M_PI * freqValue);
            pi_module->connect_output(to_connector_index(constant::output::value), 1);
            pi_track->push_back_module(std::move(pi_module), process_range);
        }

        if (auto multiply_track = proc::track::make_shared(); true) {
            timeline->insert_track(trk_idx++, multiply_track);
            auto multiply_module = make_signal_module<float>(math2::kind::multiply);
            multiply_module->connect_input(to_connector_index(math2::input::left), 0);
            multiply_module->connect_input(to_connector_index(math2::input::right), 1);
            multiply_module->connect_output(to_connector_index(math2::output::result), 0);
            multiply_track->push_back_module(std::move(multiply_module), process_range);
        }

        if (auto sine_track = proc::track::make_shared(); true) {
            timeline->insert_track(trk_idx++, sine_track);
            auto sine_module = make_signal_module<float>(math1::kind::sin);
            sine_module->connect_input(to_connector_index(math1::input::parameter), 0);
            sine_module->connect_output(to_connector_index(math1::output::result), 0);
            sine_track->push_back_module(std::move(sine_module), process_range);
        }

        if (auto env_track = proc::track::make_shared(); true) {
            timeline->insert_track(trk_idx++, env_track);
            envelope::anchors_t<float> anchors{{0, startGainValue}, {process_range.length, endGainValue}};
            auto env_module = envelope::make_signal_module(std::move(anchors), 0);
            connect(env_module, envelope::output::value, 1);
            env_track->push_back_module(std::move(env_module), process_range);
        }

        if (auto gain_track = proc::track::make_shared(); true) {
            timeline->insert_track(trk_idx++, gain_track);
            auto gain_module = make_signal_module<float>(math2::kind::multiply);
            gain_module->connect_input(to_connector_index(math2::input::left), 0);
            gain_module->connect_input(to_connector_index(math2::input::right), 1);
            gain_module->connect_output(to_connector_index(math2::output::result), 0);
            gain_track->push_back_module(std::move(gain_module), process_range);
        }

        if (auto level_track = proc::track::make_shared(); true) {
            timeline->insert_track(trk_idx++, level_track);
            auto level_module = make_signal_module<float>(totalGainValue);
            level_module->connect_output(to_connector_index(constant::output::value), 1);
            level_track->push_back_module(std::move(level_module), process_range);
        }

        if (auto gain_track = proc::track::make_shared(); true) {
            timeline->insert_track(trk_idx++, gain_track);
            auto gain_module = make_signal_module<float>(math2::kind::multiply);
            gain_module->connect_input(to_connector_index(math2::input::left), 0);
            gain_module->connect_input(to_connector_index(math2::input::right), 1);
            gain_module->connect_output(to_connector_index(math2::output::result), 0);
            gain_track->push_back_module(std::move(gain_module), process_range);
        }

        length_t const slice_length = 1024;

        audio::pcm_buffer buffer{file->processing_format(), slice_length};

        bool write_failed = false;

        timeline->process(
            process_range, sync_source{sample_rate, slice_length},
            [&file, &buffer, &write_failed](time::range const &current_range, stream const &stream) mutable {
                auto const &channel = stream.channel(0);
                auto const &events = channel.filtered_events<float, signal_event>();
                if (events.size() > 0) {
                    buffer.reset_buffer();
                    buffer.set_frame_length(static_cast<uint32_t>(current_range.length));

                    float *buffer_data = buffer.data_ptr_at_channel<float>(0);

                    auto const &signal = events.begin()->second;
                    float const *stream_data = signal->data<float>();

                    memcpy(buffer_data, stream_data, signal->byte_size());

                    auto write_result = file->write_from_buffer(buffer);
                    if (!write_result) {
                        write_failed = true;
                        return continuation::abort;
                    }
                }
                return continuation::keep;
            });

        if (write_failed) {
            NSLog(@"write to file failed.");
        }

        file->close();
    }
}

- (SampleBits)bitsSliderValue {
    return (SampleBits)self.bitsSlider.integerValue;
}

- (uint32_t)bitsValue {
    switch ([self bitsSliderValue]) {
        case SampleBits16:
            return 16;

        case SampleBits32:
            return 32;
    }
}

- (sample_rate_t)sampleRateValue {
    return (sample_rate_t)self.sampleRateSlider.integerValue;
}

- (NSInteger)freqValue {
    return self.freqSlider.integerValue;
}

- (length_t)lengthValue {
    return (length_t)self.lengthSlider.integerValue;
}

- (float)startGainValue {
    return self.startGainSlider.floatValue;
}

- (float)endGainValue {
    return self.endGainSlider.floatValue;
}

- (float)totalGainValue {
    return self.totalGainSlider.floatValue;
}

#pragma mark -

- (void)updateSlider:(NSSlider *)slider fromTextField:(NSTextField *)textField {
    [self updateSlider:slider fromTextField:textField formatter:NULL];
}

- (void)updateSlider:(NSSlider *)slider
       fromTextField:(NSTextField *)textField
           formatter:(double (^)(NSString *))formatter {
    double const doubleValue = formatter ? formatter(textField.stringValue) : textField.doubleValue;
    if (doubleValue < slider.minValue) {
        slider.doubleValue = slider.minValue;
    } else if (slider.maxValue < doubleValue) {
        slider.doubleValue = slider.maxValue;
    } else {
        slider.doubleValue = doubleValue;
    }
}

@end
