//
//  yas_audio_unit_node_tests.m
//

#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_unit_node_tests : XCTestCase

@end

@implementation yas_audio_unit_node_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_create {
    audio::engine::unit_node node(kAudioUnitType_Effect, kAudioUnitSubType_Delay);

    XCTAssertTrue(node);

    XCTAssertTrue(node.manageable());
}

- (void)test_create_null {
    audio::engine::unit_node node{nullptr};

    XCTAssertFalse(node);
}

- (void)test_restore_parameters {
    audio::engine::manager manager;
    manager.add_offline_output_node();

    auto format = audio::format({.sample_rate = 44100.0, .channel_count = 2});
    audio::engine::offline_output_node &output_node = manager.offline_output_node();
    audio::engine::unit_node delay_node(kAudioUnitType_Effect, kAudioUnitSubType_Delay);

    auto const &parameters = delay_node.parameters();
    XCTAssertGreaterThanOrEqual(parameters.count(kAudioUnitScope_Global), 1);
    auto const &global_parameters = parameters.at(kAudioUnitScope_Global);
    XCTAssertEqual(global_parameters.size(), 4);
    for (auto &pair : global_parameters) {
        auto &parameter = pair.second;
        XCTAssertEqual(parameter.default_value(), delay_node.global_parameter_value(parameter.parameter_id()));
    }

    auto connection = manager.connect(delay_node.node(), output_node.node(), format);

    XCTestExpectation *expectation = [self expectationWithDescription:@"First Render"];

    auto start_result =
        manager.start_offline_render(nullptr, [expectation](bool const cancelled) { [expectation fulfill]; });

    XCTAssertTrue(start_result);

    float const delay_time_value = 0.5f;
    float const feedback_value = -50.0f;
    float const lopass_cutoff_value = 100.0f;
    float const wet_dry_mix = 10.0f;

    delay_node.set_global_parameter_value(kDelayParam_DelayTime, delay_time_value);
    delay_node.set_global_parameter_value(kDelayParam_Feedback, feedback_value);
    delay_node.set_global_parameter_value(kDelayParam_LopassCutoff, lopass_cutoff_value);
    delay_node.set_global_parameter_value(kDelayParam_WetDryMix, wet_dry_mix);

    XCTAssertEqual(delay_node.global_parameter_value(kDelayParam_DelayTime), delay_time_value);
    XCTAssertEqual(delay_node.global_parameter_value(kDelayParam_Feedback), feedback_value);
    XCTAssertEqual(delay_node.global_parameter_value(kDelayParam_LopassCutoff), lopass_cutoff_value);
    XCTAssertEqual(delay_node.global_parameter_value(kDelayParam_WetDryMix), wet_dry_mix);

    manager.stop();

    [self waitForExpectationsWithTimeout:10.0
                                 handler:^(NSError *error){

                                 }];

    manager.disconnect(connection);

    delay_node.manageable().reload_audio_unit();

    manager.connect(delay_node.node(), output_node.node(), format);

    expectation = [self expectationWithDescription:@"Second Render"];

    manager.start_offline_render(nullptr, [expectation](bool const cancelled) { [expectation fulfill]; });

    XCTAssertEqual(delay_node.global_parameter_value(kDelayParam_DelayTime), delay_time_value);
    XCTAssertEqual(delay_node.global_parameter_value(kDelayParam_Feedback), feedback_value);
    XCTAssertEqual(delay_node.global_parameter_value(kDelayParam_LopassCutoff), lopass_cutoff_value);
    XCTAssertEqual(delay_node.global_parameter_value(kDelayParam_WetDryMix), wet_dry_mix);

    manager.stop();

    [self waitForExpectationsWithTimeout:10.0
                                 handler:^(NSError *error){

                                 }];
}

- (void)test_get_parameters {
    audio::engine::unit_node delay_node(kAudioUnitType_Effect, kAudioUnitSubType_Delay);

    auto const &global_parameters = delay_node.global_parameters();
    auto const &output_parameters = delay_node.output_parameters();
    auto const &input_parameters = delay_node.input_parameters();

    XCTAssertGreaterThan(global_parameters.size(), 0);
    XCTAssertEqual(output_parameters.size(), 0);
    XCTAssertEqual(input_parameters.size(), 0);

    auto &wet_dry_mix = global_parameters.at(kDelayParam_WetDryMix);
    XCTAssertEqual(wet_dry_mix.parameter_id(), kDelayParam_WetDryMix);

    auto &delay_time = global_parameters.at(kDelayParam_DelayTime);
    XCTAssertEqual(delay_time.parameter_id(), kDelayParam_DelayTime);

    auto &feedback = global_parameters.at(kDelayParam_Feedback);
    XCTAssertEqual(feedback.parameter_id(), kDelayParam_Feedback);

    auto &lopass = global_parameters.at(kDelayParam_LopassCutoff);
    XCTAssertEqual(lopass.parameter_id(), kDelayParam_LopassCutoff);
}

- (void)test_reset_parameters {
    audio::engine::unit_node delay_node(kAudioUnitType_Effect, kAudioUnitSubType_Delay);

    float const delay_time_value = 0.5f;
    float const feedback_value = -50.0f;
    float const lopass_cutoff_value = 100.0f;
    float const wet_dry_mix = 10.0f;

    XCTAssertNotEqual(delay_node.global_parameter_value(kDelayParam_DelayTime), delay_time_value);
    XCTAssertNotEqual(delay_node.global_parameter_value(kDelayParam_Feedback), feedback_value);
    XCTAssertNotEqual(delay_node.global_parameter_value(kDelayParam_LopassCutoff), lopass_cutoff_value);
    XCTAssertNotEqual(delay_node.global_parameter_value(kDelayParam_WetDryMix), wet_dry_mix);

    delay_node.set_global_parameter_value(kDelayParam_DelayTime, delay_time_value);
    delay_node.set_global_parameter_value(kDelayParam_Feedback, feedback_value);
    delay_node.set_global_parameter_value(kDelayParam_LopassCutoff, lopass_cutoff_value);
    delay_node.set_global_parameter_value(kDelayParam_WetDryMix, wet_dry_mix);

    XCTAssertEqual(delay_node.global_parameter_value(kDelayParam_DelayTime), delay_time_value);
    XCTAssertEqual(delay_node.global_parameter_value(kDelayParam_Feedback), feedback_value);
    XCTAssertEqual(delay_node.global_parameter_value(kDelayParam_LopassCutoff), lopass_cutoff_value);
    XCTAssertEqual(delay_node.global_parameter_value(kDelayParam_WetDryMix), wet_dry_mix);

    delay_node.node().reset();

    XCTAssertNotEqual(delay_node.global_parameter_value(kDelayParam_DelayTime), delay_time_value);
    XCTAssertNotEqual(delay_node.global_parameter_value(kDelayParam_Feedback), feedback_value);
    XCTAssertNotEqual(delay_node.global_parameter_value(kDelayParam_LopassCutoff), lopass_cutoff_value);
    XCTAssertNotEqual(delay_node.global_parameter_value(kDelayParam_WetDryMix), wet_dry_mix);
}

@end
