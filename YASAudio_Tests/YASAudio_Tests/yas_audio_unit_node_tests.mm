//
//  yas_audio_unit_node_tests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "yas_audio_test_utils.h"

@interface yas_audio_unit_node_tests : XCTestCase

@end

@implementation yas_audio_unit_node_tests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)test_restore_parameters
{
    yas::audio::engine engine;

    auto format = yas::audio::format(44100.0, 2);
    yas::audio::offline_output_node output_node;
    yas::audio::unit_node delay_node(kAudioUnitType_Effect, kAudioUnitSubType_Delay);

    const auto &parameters = delay_node.parameters();
    XCTAssertGreaterThanOrEqual(parameters.count(kAudioUnitScope_Global), 1);
    const auto &global_parameters = parameters.at(kAudioUnitScope_Global);
    XCTAssertEqual(global_parameters.size(), 4);
    for (auto &pair : global_parameters) {
        auto &parameter = pair.second;
        XCTAssertEqual(parameter.default_value(), delay_node.global_parameter_value(parameter.parameter_id()));
    }

    auto connection = engine.connect(delay_node, output_node, format);

    XCTestExpectation *expectation = [self expectationWithDescription:@"First Render"];

    auto start_result =
        engine.start_offline_render(nullptr, [expectation](const bool cancelled) { [expectation fulfill]; });

    XCTAssertTrue(start_result);

    const float delay_time_value = 0.5f;
    const float feedback_value = -50.0f;
    const float lopass_cutoff_value = 100.0f;
    const float wet_dry_mix = 10.0f;

    delay_node.set_global_parameter_value(kDelayParam_DelayTime, delay_time_value);
    delay_node.set_global_parameter_value(kDelayParam_Feedback, feedback_value);
    delay_node.set_global_parameter_value(kDelayParam_LopassCutoff, lopass_cutoff_value);
    delay_node.set_global_parameter_value(kDelayParam_WetDryMix, wet_dry_mix);

    XCTAssertEqual(delay_node.global_parameter_value(kDelayParam_DelayTime), delay_time_value);
    XCTAssertEqual(delay_node.global_parameter_value(kDelayParam_Feedback), feedback_value);
    XCTAssertEqual(delay_node.global_parameter_value(kDelayParam_LopassCutoff), lopass_cutoff_value);
    XCTAssertEqual(delay_node.global_parameter_value(kDelayParam_WetDryMix), wet_dry_mix);

    engine.stop();

    [self waitForExpectationsWithTimeout:10.0
                                 handler:^(NSError *error){

                                 }];

    engine.disconnect(connection);

    yas::audio::unit_node::private_access::reload_audio_unit(delay_node);

    engine.connect(delay_node, output_node, format);

    expectation = [self expectationWithDescription:@"Second Render"];

    engine.start_offline_render(nullptr, [expectation](const bool cancelled) { [expectation fulfill]; });

    XCTAssertEqual(delay_node.global_parameter_value(kDelayParam_DelayTime), delay_time_value);
    XCTAssertEqual(delay_node.global_parameter_value(kDelayParam_Feedback), feedback_value);
    XCTAssertEqual(delay_node.global_parameter_value(kDelayParam_LopassCutoff), lopass_cutoff_value);
    XCTAssertEqual(delay_node.global_parameter_value(kDelayParam_WetDryMix), wet_dry_mix);

    engine.stop();

    [self waitForExpectationsWithTimeout:10.0
                                 handler:^(NSError *error){

                                 }];
}

- (void)test_get_parameters
{
    yas::audio::unit_node delay_node(kAudioUnitType_Effect, kAudioUnitSubType_Delay);

    const auto &global_parameters = delay_node.global_parameters();
    const auto &output_parameters = delay_node.output_parameters();
    const auto &input_parameters = delay_node.input_parameters();

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

- (void)test_reset_parameters
{
    yas::audio::unit_node delay_node(kAudioUnitType_Effect, kAudioUnitSubType_Delay);

    const float delay_time_value = 0.5f;
    const float feedback_value = -50.0f;
    const float lopass_cutoff_value = 100.0f;
    const float wet_dry_mix = 10.0f;

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

    delay_node.reset();

    XCTAssertNotEqual(delay_node.global_parameter_value(kDelayParam_DelayTime), delay_time_value);
    XCTAssertNotEqual(delay_node.global_parameter_value(kDelayParam_Feedback), feedback_value);
    XCTAssertNotEqual(delay_node.global_parameter_value(kDelayParam_LopassCutoff), lopass_cutoff_value);
    XCTAssertNotEqual(delay_node.global_parameter_value(kDelayParam_WetDryMix), wet_dry_mix);
}

@end
