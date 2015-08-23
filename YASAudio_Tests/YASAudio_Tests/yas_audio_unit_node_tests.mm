//
//  yas_audio_unit_node_tests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "yas_audio.h"

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
    auto engine = yas::audio_engine::create();
    auto format = yas::audio_format::create(44100.0, 2);
    auto output_node = yas::audio_offline_output_node::create();
    auto delay_node = yas::audio_unit_node::create(kAudioUnitType_Effect, kAudioUnitSubType_Delay);

    const auto &parameters = delay_node->parameters();
    XCTAssertGreaterThanOrEqual(parameters.count(kAudioUnitScope_Global), 1);
    const auto &global_parameters = parameters.at(kAudioUnitScope_Global);
    XCTAssertEqual(global_parameters.size(), 4);
    for (auto &pair : global_parameters) {
        auto &parameter = pair.second;
        XCTAssertEqual(parameter.default_value(), delay_node->global_parameter_value(parameter.parameter_id()));
    }

    auto connection = engine->connect(delay_node, output_node, format);

    XCTestExpectation *expectation = [self expectationWithDescription:@"First Render"];

    auto start_result =
        engine->start_offline_render(nullptr, [expectation](const bool cancelled) { [expectation fulfill]; });

    XCTAssertTrue(start_result);

    float delay_time_value = 0.5f;
    float feedback_value = -50.0f;
    float lopass_cutoff_value = 100.0f;
    float wet_dry_mix = 10.0f;

    delay_node->set_global_parameter_value(kDelayParam_DelayTime, delay_time_value);
    delay_node->set_global_parameter_value(kDelayParam_Feedback, feedback_value);
    delay_node->set_global_parameter_value(kDelayParam_LopassCutoff, lopass_cutoff_value);
    delay_node->set_global_parameter_value(kDelayParam_WetDryMix, wet_dry_mix);

    XCTAssertEqual(delay_node->global_parameter_value(kDelayParam_DelayTime), delay_time_value);
    XCTAssertEqual(delay_node->global_parameter_value(kDelayParam_Feedback), feedback_value);
    XCTAssertEqual(delay_node->global_parameter_value(kDelayParam_LopassCutoff), lopass_cutoff_value);
    XCTAssertEqual(delay_node->global_parameter_value(kDelayParam_WetDryMix), wet_dry_mix);

    engine->stop();

    [self waitForExpectationsWithTimeout:10.0
                                 handler:^(NSError *error){

                                 }];

    engine->disconnect(connection);

    yas::audio_unit_node::private_access::reload_audio_unit(delay_node);

    engine->connect(delay_node, output_node, format);

    expectation = [self expectationWithDescription:@"Second Render"];

    engine->start_offline_render(nullptr, [expectation](const bool cancelled) { [expectation fulfill]; });

    XCTAssertEqual(delay_node->global_parameter_value(kDelayParam_DelayTime), delay_time_value);
    XCTAssertEqual(delay_node->global_parameter_value(kDelayParam_Feedback), feedback_value);
    XCTAssertEqual(delay_node->global_parameter_value(kDelayParam_LopassCutoff), lopass_cutoff_value);
    XCTAssertEqual(delay_node->global_parameter_value(kDelayParam_WetDryMix), wet_dry_mix);

    engine->stop();

    [self waitForExpectationsWithTimeout:10.0
                                 handler:^(NSError *error){

                                 }];
}

@end
