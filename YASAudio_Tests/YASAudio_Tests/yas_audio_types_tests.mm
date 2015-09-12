//
//  yas_audio_types_tests.mm
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "yas_audio_test_utils.h"

@interface yas_audio_types_tests : XCTestCase

@end

@implementation yas_audio_types_tests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)test_to_uint32_direction
{
    XCTAssertEqual(yas::to_uint32(yas::direction::output), 0);
    XCTAssertEqual(yas::to_uint32(yas::direction::input), 1);
}

- (void)test_to_string_direction
{
    XCTAssertEqual(yas::to_string(yas::direction::output), "output");
    XCTAssertEqual(yas::to_string(yas::direction::input), "input");
}

- (void)test_to_string_scope
{
    XCTAssertEqual(yas::to_string(kAudioUnitScope_Global), "global");
    XCTAssertEqual(yas::to_string(kAudioUnitScope_Input), "input");
    XCTAssertEqual(yas::to_string(kAudioUnitScope_Output), "output");
    XCTAssertEqual(yas::to_string(kAudioUnitScope_Group), "group");
    XCTAssertEqual(yas::to_string(kAudioUnitScope_Part), "part");
    XCTAssertEqual(yas::to_string(kAudioUnitScope_Note), "note");
    XCTAssertEqual(yas::to_string(kAudioUnitScope_Layer), "layer");
    XCTAssertEqual(yas::to_string(kAudioUnitScope_LayerItem), "layer_item");
    XCTAssertEqual(yas::to_string((AudioUnitScope)-1), "unknown");
}

@end
