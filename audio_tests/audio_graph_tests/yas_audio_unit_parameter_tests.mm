//
//  yas_audio_unit_parameter_tests.m
//

#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_unit_parameter_tests : XCTestCase

@end

@implementation yas_audio_unit_parameter_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_create {
    AudioUnitParameterInfo info{.unitName = CFSTR("unit_name"),
                                .clumpID = 3,
                                .cfNameString = CFSTR("cf_name_string"),
                                .unit = kAudioUnitParameterUnit_Seconds,
                                .minValue = 0.5f,
                                .maxValue = 100.0f,
                                .defaultValue = 1.0f,
                                .flags = kAudioUnitParameterFlag_HasClump};
    AudioUnitParameterID parameterID = 20;
    AudioUnitScope scope = kAudioUnitScope_Output;

    audio::unit::parameter parameter{info, parameterID, scope};

    XCTAssertEqual(parameter.parameter_id, 20);
    XCTAssertEqual(parameter.scope, kAudioUnitScope_Output);
    XCTAssertTrue(CFEqual(parameter.unit_name(), CFSTR("unit_name")));
    XCTAssertEqual(parameter.clump_id, 3);
    XCTAssertTrue(CFEqual(parameter.name(), CFSTR("cf_name_string")));
    XCTAssertEqual(parameter.unit, kAudioUnitParameterUnit_Seconds);
    XCTAssertEqual(parameter.min_value, 0.5f);
    XCTAssertEqual(parameter.max_value, 100.0f);
    XCTAssertEqual(parameter.default_value, 1.0f);
    XCTAssertEqual(parameter.has_clump, true);
}

- (void)test_will_change_chain {
    audio::unit::parameter parameter{AudioUnitParameterInfo{}, 0, 0};

    bool called = false;

    auto will_chain = parameter.chain(audio::unit::parameter::method::will_change)
                          .perform([self, &called](auto const &change_info) {
                              AudioUnitElement const element = change_info.element;
                              XCTAssertEqual(element, 2);
                              XCTAssertEqual(change_info.old_value, 0.0f);
                              XCTAssertEqual(change_info.new_value, 1.0f);
                              XCTAssertEqual(change_info.parameter.value(element), 0.0);
                              called = true;
                          })
                          .end();

    parameter.set_value(1.0f, 2);

    XCTAssertTrue(called);
}

- (void)test_did_change_chain {
    audio::unit::parameter parameter{AudioUnitParameterInfo{}, 0, 0};

    parameter.set_value(-1.0f, 10);

    bool called = false;

    auto did_chain = parameter.chain(audio::unit::parameter::method::did_change)
                         .perform([self, &called](auto const &change_info) {
                             AudioUnitElement const element = change_info.element;
                             XCTAssertEqual(element, 10);
                             XCTAssertEqual(change_info.old_value, -1.0f);
                             XCTAssertEqual(change_info.new_value, 3.5f);
                             XCTAssertEqual(change_info.parameter.value(element), 3.5f);
                             called = true;
                         })
                         .end();

    parameter.set_value(3.5f, 10);

    XCTAssertTrue(called);
}

- (void)test_values {
    audio::unit::parameter parameter{AudioUnitParameterInfo{}, 0, 0};

    parameter.set_value(1.0f, 1);
    parameter.set_value(2.0f, 2);
    parameter.set_value(3.0f, 3);

    XCTAssertGreaterThanOrEqual(parameter.values().count(1), 1);
    XCTAssertGreaterThanOrEqual(parameter.values().count(2), 1);
    XCTAssertGreaterThanOrEqual(parameter.values().count(3), 1);

    XCTAssertEqual(parameter.values().at(1), 1.0f);
    XCTAssertEqual(parameter.values().at(2), 2.0f);
    XCTAssertEqual(parameter.values().at(3), 3.0f);
}

- (void)test_method_to_string {
    XCTAssertEqual(to_string(audio::unit::parameter::method::will_change), "will_change");
    XCTAssertEqual(to_string(audio::unit::parameter::method::did_change), "did_change");
}

- (void)test_method_ostream {
    auto const values = {audio::unit::parameter::method::will_change, audio::unit::parameter::method::did_change};

    for (auto const &value : values) {
        std::ostringstream stream;
        stream << value;
        XCTAssertEqual(stream.str(), to_string(value));
    }
}

@end
