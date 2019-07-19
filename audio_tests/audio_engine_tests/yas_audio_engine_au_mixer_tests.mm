//
//  yas_audio_au_mixer_tests.m
//

#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_au_mixer_tests : XCTestCase

@end

@implementation yas_audio_au_mixer_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_parameter_exists {
    auto au_mixer = audio::engine::make_au_mixer();

    auto const &paramters = au_mixer->au().parameters();
    auto const &input_parameters = paramters.at(kAudioUnitScope_Input);
    auto const &output_parameters = paramters.at(kAudioUnitScope_Output);

    XCTAssertGreaterThanOrEqual(input_parameters.size(), 1);
    XCTAssertGreaterThanOrEqual(output_parameters.size(), 1);

    auto input_parameter_ids = {kMultiChannelMixerParam_Volume,
                                kMultiChannelMixerParam_Enable,
                                kMultiChannelMixerParam_Pan,
                                kMultiChannelMixerParam_PreAveragePower,
                                kMultiChannelMixerParam_PrePeakHoldLevel,
                                kMultiChannelMixerParam_PostAveragePower,
                                kMultiChannelMixerParam_PostPeakHoldLevel};

    for (auto &key : input_parameter_ids) {
        XCTAssertGreaterThanOrEqual(input_parameters.count(key), 1);
    }

    auto output_parameter_ids = {kMultiChannelMixerParam_Volume, kMultiChannelMixerParam_Pan};

    for (auto &key : output_parameter_ids) {
        XCTAssertGreaterThanOrEqual(output_parameters.count(key), 1);
    }
}

- (void)test_element {
    auto au_mixer = audio::engine::make_au_mixer();
    uint32_t const default_element_count = au_mixer->au().input_element_count();

    XCTAssertGreaterThanOrEqual(default_element_count, 1);
    XCTAssertNoThrow(au_mixer->set_input_volume(0.5f, 0));
    XCTAssertThrows(au_mixer->set_input_volume(0.5f, default_element_count));

    uint32_t const element_count = default_element_count + 8;
    XCTAssertNoThrow(au_mixer->au().unit()->set_element_count(element_count, kAudioUnitScope_Input));

    XCTAssertGreaterThanOrEqual(au_mixer->au().input_element_count(), element_count);
    XCTAssertNoThrow(au_mixer->set_input_volume(0.5f, element_count - 1));
    XCTAssertThrows(au_mixer->set_input_volume(0.5f, element_count));
}

- (void)test_restore_parameters {
    auto au_mixer = audio::engine::make_au_mixer();

    uint32_t const bus_idx = 0;
    float const input_volume = 0.5f;
    float const input_pan = 0.75f;
    bool const enabled = false;
    float const output_volume = 0.25f;
    float const output_pan = 0.1f;

    au_mixer->set_input_volume(input_volume, bus_idx);
    au_mixer->set_input_pan(input_pan, bus_idx);
    au_mixer->set_input_enabled(enabled, bus_idx);
    au_mixer->set_output_volume(output_volume, bus_idx);
    au_mixer->set_output_pan(output_pan, bus_idx);

    XCTAssertEqual(au_mixer->input_volume(bus_idx), input_volume);
    XCTAssertEqual(au_mixer->input_pan(bus_idx), input_pan);
    XCTAssertEqual(au_mixer->input_enabled(bus_idx), enabled);
    XCTAssertEqual(au_mixer->output_volume(bus_idx), output_volume);
    XCTAssertEqual(au_mixer->output_pan(bus_idx), output_pan);

    au_mixer->au().manageable()->reload_unit();

    XCTAssertNotEqual(au_mixer->input_volume(bus_idx), input_volume);
    XCTAssertNotEqual(au_mixer->input_pan(bus_idx), input_pan);
    XCTAssertNotEqual(au_mixer->input_enabled(bus_idx), enabled);
    XCTAssertNotEqual(au_mixer->output_volume(bus_idx), output_volume);
    XCTAssertNotEqual(au_mixer->output_pan(bus_idx), output_pan);

    au_mixer->au().manageable()->prepare_parameters();

    XCTAssertEqual(au_mixer->input_volume(bus_idx), input_volume);
    XCTAssertEqual(au_mixer->input_pan(bus_idx), input_pan);
    XCTAssertEqual(au_mixer->input_enabled(bus_idx), enabled);
    XCTAssertEqual(au_mixer->output_volume(bus_idx), output_volume);
    XCTAssertEqual(au_mixer->output_pan(bus_idx), output_pan);
}

@end
