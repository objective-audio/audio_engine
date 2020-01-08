//
//  yas_audio_graph_avf_au_mixer_tests.m
//

#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_graph_avf_au_mixer_tests : XCTestCase

@end

@implementation yas_audio_graph_avf_au_mixer_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_parameter_exists {
    auto au_mixer = audio::graph_avf_au_mixer::make_shared();

    auto const &input_parameters = au_mixer->raw_au()->raw_au()->input_parameters();
    auto const &output_parameters = au_mixer->raw_au()->raw_au()->output_parameters();

    XCTAssertGreaterThanOrEqual(input_parameters.size(), 7);
    XCTAssertGreaterThanOrEqual(output_parameters.size(), 2);

    auto const &raw_au = au_mixer->raw_au()->raw_au();

    auto const input_parameter_ids = {kMultiChannelMixerParam_Volume,
                                      kMultiChannelMixerParam_Enable,
                                      kMultiChannelMixerParam_Pan,
                                      kMultiChannelMixerParam_PreAveragePower,
                                      kMultiChannelMixerParam_PrePeakHoldLevel,
                                      kMultiChannelMixerParam_PostAveragePower,
                                      kMultiChannelMixerParam_PostPeakHoldLevel};

    for (auto const &parameter_id : input_parameter_ids) {
        for (AudioUnitElement idx; idx < raw_au->input_bus_count(); ++idx) {
            auto const parameter = raw_au->parameter(parameter_id, audio::avf_au_parameter_scope::input, idx);
            XCTAssertTrue(parameter.has_value());
        }
    }

    auto output_parameter_ids = {kMultiChannelMixerParam_Volume, kMultiChannelMixerParam_Pan};

    for (auto const &parameter_id : output_parameter_ids) {
        for (AudioUnitElement idx; idx < raw_au->output_bus_count(); ++idx) {
            auto const parameter = raw_au->parameter(parameter_id, audio::avf_au_parameter_scope::output, idx);
            XCTAssertTrue(parameter.has_value());
        }
    }
}

- (void)test_bus {
    auto au_mixer = audio::graph_avf_au_mixer::make_shared();
    uint32_t const default_bus_count = au_mixer->raw_au()->raw_au()->input_bus_count();

    XCTAssertGreaterThanOrEqual(default_bus_count, 1);
    XCTAssertNoThrow(au_mixer->set_input_volume(0.5f, 0));
    XCTAssertThrows(au_mixer->set_input_volume(0.5f, default_bus_count));

    uint32_t const bus_count = default_bus_count + 8;
    XCTAssertNoThrow(au_mixer->raw_au()->raw_au()->set_input_bus_count(bus_count));

    XCTAssertGreaterThanOrEqual(au_mixer->raw_au()->raw_au()->input_bus_count(), bus_count);
    XCTAssertNoThrow(au_mixer->set_input_volume(0.5f, bus_count - 1));
    XCTAssertThrows(au_mixer->set_input_volume(0.5f, bus_count));
}

@end
