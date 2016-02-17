//
//  yas_audio_unit_mixer_node_tests.m
//

#import "yas_audio_test_utils.h"

@interface yas_audio_unit_mixer_node_tests : XCTestCase

@end

@implementation yas_audio_unit_mixer_node_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_parameter_exists {
    yas::audio::unit_mixer_node mixer_node;

    const auto &paramters = mixer_node.parameters();
    const auto &input_parameters = paramters.at(kAudioUnitScope_Input);
    const auto &output_parameters = paramters.at(kAudioUnitScope_Output);

    XCTAssertGreaterThanOrEqual(input_parameters.size(), 1);
    XCTAssertGreaterThanOrEqual(output_parameters.size(), 1);

    auto input_parameter_ids = {kMultiChannelMixerParam_Volume, kMultiChannelMixerParam_Enable,
                                kMultiChannelMixerParam_Pan, kMultiChannelMixerParam_PreAveragePower,
                                kMultiChannelMixerParam_PrePeakHoldLevel, kMultiChannelMixerParam_PostAveragePower,
                                kMultiChannelMixerParam_PostPeakHoldLevel};

    for (auto &key : input_parameter_ids) {
        XCTAssertGreaterThanOrEqual(input_parameters.count(key), 1);
    }

    auto output_parameter_ids = {kMultiChannelMixerParam_Volume, kMultiChannelMixerParam_Pan};

    for (auto &key : output_parameter_ids) {
        XCTAssertGreaterThanOrEqual(output_parameters.count(key), 1);
    }
}

- (void)testElement {
    yas::audio::unit_mixer_node mixer_node;
    const UInt32 default_element_count = mixer_node.input_element_count();

    XCTAssertGreaterThanOrEqual(default_element_count, 1);
    XCTAssertNoThrow(mixer_node.set_input_volume(0.5f, 0));
    XCTAssertThrows(mixer_node.set_input_volume(0.5f, default_element_count));

    const UInt32 element_count = default_element_count + 8;
    XCTAssertNoThrow(mixer_node.audio_unit().set_element_count(element_count, kAudioUnitScope_Input));

    XCTAssertGreaterThanOrEqual(mixer_node.input_element_count(), element_count);
    XCTAssertNoThrow(mixer_node.set_input_volume(0.5f, element_count - 1));
    XCTAssertThrows(mixer_node.set_input_volume(0.5f, element_count));
}

- (void)testRestoreParamters {
    yas::audio::unit_mixer_node mixer_node;

    const UInt32 bus_idx = 0;
    const Float32 input_volume = 0.5f;
    const Float32 input_pan = 0.75f;
    const bool enabled = false;
    const Float32 output_volume = 0.25f;
    const Float32 output_pan = 0.1f;

    mixer_node.set_input_volume(input_volume, bus_idx);
    mixer_node.set_input_pan(input_pan, bus_idx);
    mixer_node.set_input_enabled(enabled, bus_idx);
    mixer_node.set_output_volume(output_volume, bus_idx);
    mixer_node.set_output_pan(output_pan, bus_idx);

    XCTAssertEqual(mixer_node.input_volume(bus_idx), input_volume);
    XCTAssertEqual(mixer_node.input_pan(bus_idx), input_pan);
    XCTAssertEqual(mixer_node.input_enabled(bus_idx), enabled);
    XCTAssertEqual(mixer_node.output_volume(bus_idx), output_volume);
    XCTAssertEqual(mixer_node.output_pan(bus_idx), output_pan);

    yas::audio::unit_node::private_access::reload_audio_unit(mixer_node);

    XCTAssertNotEqual(mixer_node.input_volume(bus_idx), input_volume);
    XCTAssertNotEqual(mixer_node.input_pan(bus_idx), input_pan);
    XCTAssertNotEqual(mixer_node.input_enabled(bus_idx), enabled);
    XCTAssertNotEqual(mixer_node.output_volume(bus_idx), output_volume);
    XCTAssertNotEqual(mixer_node.output_pan(bus_idx), output_pan);

    yas::audio::unit_node::private_access::prepare_parameters(mixer_node);

    XCTAssertEqual(mixer_node.input_volume(bus_idx), input_volume);
    XCTAssertEqual(mixer_node.input_pan(bus_idx), input_pan);
    XCTAssertEqual(mixer_node.input_enabled(bus_idx), enabled);
    XCTAssertEqual(mixer_node.output_volume(bus_idx), output_volume);
    XCTAssertEqual(mixer_node.output_pan(bus_idx), output_pan);
}

@end
