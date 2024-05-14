//
//  graph_avf_au_tests.m
//

#import "../test_utils.h"

using namespace yas;

@interface graph_avf_au_tests : XCTestCase

@end

@implementation graph_avf_au_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_create {
    auto const au = audio::graph_avf_au::make_shared(kAudioUnitType_Effect, kAudioUnitSubType_Delay);

    XCTAssertTrue(au);
}

- (void)test_restore_parameters {
    auto graph = audio::graph::make_shared();

    audio::format format{{.sample_rate = 44100.0, .channel_count = 2}};
    auto const delay_au = audio::graph_avf_au::make_shared(kAudioUnitType_Effect, kAudioUnitSubType_Delay);
    auto const raw_au = delay_au->raw_au;

    auto const &global_parameters = raw_au->global_parameters();
    XCTAssertEqual(global_parameters.size(), 4);
    for (auto const &parameter : global_parameters) {
        XCTAssertEqual(parameter->default_value(), raw_au->global_parameter_value(stoi(parameter->identifier)));
    }

    auto *expectation1a = [self expectationWithDescription:@"First Render A"];
    expectation1a.assertForOverFulfill = NO;

    auto *expectation1b = [self expectationWithDescription:@"First Render B"];

    auto const device1 = audio::offline_device::make_shared(
        format,
        [&expectation1a](auto) {
            [expectation1a fulfill];
            return audio::continuation::keep;
        },
        [&expectation1b](bool const cancelled) { [expectation1b fulfill]; });
    auto const &offline_io1 = graph->add_io(device1);
    auto const connection = graph->connect(delay_au->node, offline_io1->output_node, format);

    auto start_result = graph->start_render();

    XCTAssertTrue(start_result);

    float const delay_time_value = 0.5f;
    float const feedback_value = -50.0f;
    float const lopass_cutoff_value = 100.0f;
    float const wet_dry_mix = 10.0f;

    raw_au->set_global_parameter_value(kDelayParam_DelayTime, delay_time_value);
    raw_au->set_global_parameter_value(kDelayParam_Feedback, feedback_value);
    raw_au->set_global_parameter_value(kDelayParam_LopassCutoff, lopass_cutoff_value);
    raw_au->set_global_parameter_value(kDelayParam_WetDryMix, wet_dry_mix);

    XCTAssertEqual(raw_au->global_parameter_value(kDelayParam_DelayTime), delay_time_value);
    XCTAssertEqual(raw_au->global_parameter_value(kDelayParam_Feedback), feedback_value);
    XCTAssertEqual(raw_au->global_parameter_value(kDelayParam_LopassCutoff), lopass_cutoff_value);
    XCTAssertEqual(raw_au->global_parameter_value(kDelayParam_WetDryMix), wet_dry_mix);

    [self waitForExpectations:@[expectation1a] timeout:10.0];

    graph->stop();

    [self waitForExpectations:@[expectation1b] timeout:10.0];

    graph->disconnect(connection);
    graph->remove_io();

    XCTestExpectation *expectation2a = [self expectationWithDescription:@"Second Render A"];
    expectation2a.assertForOverFulfill = NO;

    XCTestExpectation *expectation2b = [self expectationWithDescription:@"Second Render B"];

    auto const device2 = audio::offline_device::make_shared(
        format,
        [&expectation2a](auto) {
            [expectation2a fulfill];
            return audio::continuation::keep;
        },
        [&expectation2b](bool const cancelled) { [expectation2b fulfill]; });
    auto const &offline_io2 = graph->add_io(device2);
    graph->connect(delay_au->node, offline_io2->output_node, format);

    graph->start_render();

    XCTAssertEqual(raw_au->global_parameter_value(kDelayParam_DelayTime), delay_time_value);
    XCTAssertEqual(raw_au->global_parameter_value(kDelayParam_Feedback), feedback_value);
    XCTAssertEqual(raw_au->global_parameter_value(kDelayParam_LopassCutoff), lopass_cutoff_value);
    XCTAssertEqual(raw_au->global_parameter_value(kDelayParam_WetDryMix), wet_dry_mix);

    [self waitForExpectations:@[expectation2a] timeout:1.0];

    graph->stop();

    [self waitForExpectations:@[expectation2b] timeout:1.0];
}

- (void)test_get_parameters {
    auto const delay_au = audio::graph_avf_au::make_shared(kAudioUnitType_Effect, kAudioUnitSubType_Delay);

    [self _load_au:delay_au];

    auto const raw_au = delay_au->raw_au;

    auto const &global_parameters = raw_au->global_parameters();
    auto const &output_parameters = raw_au->output_parameters();
    auto const &input_parameters = raw_au->input_parameters();

    XCTAssertGreaterThan(global_parameters.size(), 0);
    XCTAssertEqual(output_parameters.size(), 0);
    XCTAssertEqual(input_parameters.size(), 0);

    auto const wet_dry_mix = raw_au->parameter(kDelayParam_WetDryMix, audio::avf_au_parameter_scope::global, 0);
    XCTAssertEqual(stoi(wet_dry_mix.value()->identifier), kDelayParam_WetDryMix);

    auto const delay_time = raw_au->parameter(kDelayParam_DelayTime, audio::avf_au_parameter_scope::global, 0);
    XCTAssertEqual(stoi(delay_time.value()->identifier), kDelayParam_DelayTime);

    auto const feedback = raw_au->parameter(kDelayParam_Feedback, audio::avf_au_parameter_scope::global, 0);
    XCTAssertEqual(stoi(feedback.value()->identifier), kDelayParam_Feedback);

    auto const lopass = raw_au->parameter(kDelayParam_LopassCutoff, audio::avf_au_parameter_scope::global, 0);
    XCTAssertEqual(stoi(lopass.value()->identifier), kDelayParam_LopassCutoff);
}

- (void)test_reset_parameters {
    auto const delay_au = audio::graph_avf_au::make_shared(kAudioUnitType_Effect, kAudioUnitSubType_Delay);

    [self _load_au:delay_au];

    float const delay_time_value = 0.5f;
    float const feedback_value = -50.0f;
    float const lopass_cutoff_value = 100.0f;
    float const wet_dry_mix = 10.0f;

    auto const raw_au = delay_au->raw_au;

    XCTAssertNotEqual(raw_au->global_parameter_value(kDelayParam_DelayTime), delay_time_value);
    XCTAssertNotEqual(raw_au->global_parameter_value(kDelayParam_Feedback), feedback_value);
    XCTAssertNotEqual(raw_au->global_parameter_value(kDelayParam_LopassCutoff), lopass_cutoff_value);
    XCTAssertNotEqual(raw_au->global_parameter_value(kDelayParam_WetDryMix), wet_dry_mix);

    raw_au->set_global_parameter_value(kDelayParam_DelayTime, delay_time_value);
    raw_au->set_global_parameter_value(kDelayParam_Feedback, feedback_value);
    raw_au->set_global_parameter_value(kDelayParam_LopassCutoff, lopass_cutoff_value);
    raw_au->set_global_parameter_value(kDelayParam_WetDryMix, wet_dry_mix);

    XCTAssertEqual(raw_au->global_parameter_value(kDelayParam_DelayTime), delay_time_value);
    XCTAssertEqual(raw_au->global_parameter_value(kDelayParam_Feedback), feedback_value);
    XCTAssertEqual(raw_au->global_parameter_value(kDelayParam_LopassCutoff), lopass_cutoff_value);
    XCTAssertEqual(raw_au->global_parameter_value(kDelayParam_WetDryMix), wet_dry_mix);

    delay_au->node->reset();

    XCTAssertNotEqual(raw_au->global_parameter_value(kDelayParam_DelayTime), delay_time_value);
    XCTAssertNotEqual(raw_au->global_parameter_value(kDelayParam_Feedback), feedback_value);
    XCTAssertNotEqual(raw_au->global_parameter_value(kDelayParam_LopassCutoff), lopass_cutoff_value);
    XCTAssertNotEqual(raw_au->global_parameter_value(kDelayParam_WetDryMix), wet_dry_mix);
}

- (void)test_load_state_to_string {
    XCTAssertEqual(to_string(audio::graph_avf_au::load_state::unload), "unload");
    XCTAssertEqual(to_string(audio::graph_avf_au::load_state::loaded), "loaded");
    XCTAssertEqual(to_string(audio::graph_avf_au::load_state::failed), "failed");
}

- (void)_load_au:(audio::graph_avf_au_ptr const &)au {
    auto exp = [self expectationWithDescription:@"load"];

    auto canceller = au->raw_au
                         ->observe_load_state([exp](auto const &state) {
                             if (state == audio::avf_au::load_state::loaded) {
                                 [exp fulfill];
                             }
                         })
                         .sync();

    [self waitForExpectations:@[exp] timeout:1.0];

    canceller->cancel();
}

@end
