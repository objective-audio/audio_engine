//
//  yas_audio_each_data_tests.mm
//

#import <XCTest/XCTest.h>
#import <audio/yas_audio_umbrella.h>

using namespace yas;

@interface yas_audio_each_data_tests : XCTestCase

@end

@implementation yas_audio_each_data_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_interleaved {
    audio::format format(
        {.sample_rate = 48000.0, .channel_count = 2, .pcm_format = audio::pcm_format::int16, .interleaved = true});
    audio::pcm_buffer buffer(format, 4);

    auto each_data = audio::make_each_data<int16_t>(buffer);
    while (yas_each_data_next(each_data)) {
        yas_each_data_value(each_data) = yas_each_data_index(each_data);
    }

    auto const ptr = buffer.data_ptr_at_channel<int16_t>(0);

    XCTAssertEqual(ptr[0], 0);
    XCTAssertEqual(ptr[1], 1);
    XCTAssertEqual(ptr[2], 2);
    XCTAssertEqual(ptr[3], 3);
    XCTAssertEqual(ptr[4], 4);
    XCTAssertEqual(ptr[5], 5);
    XCTAssertEqual(ptr[6], 6);
    XCTAssertEqual(ptr[7], 7);
}

- (void)test_non_interleaved {
    audio::format format(
        {.sample_rate = 48000.0, .channel_count = 2, .pcm_format = audio::pcm_format::int16, .interleaved = false});
    audio::pcm_buffer buffer(format, 4);

    auto each_data = audio::make_each_data<int16_t>(buffer);
    while (yas_each_data_next(each_data)) {
        yas_each_data_value(each_data) = yas_each_data_index(each_data);
    }

    auto const ch0_ptr = buffer.data_ptr_at_channel<int16_t>(0);
    auto const ch1_ptr = buffer.data_ptr_at_channel<int16_t>(1);

    XCTAssertEqual(ch0_ptr[0], 0);
    XCTAssertEqual(ch1_ptr[0], 1);
    XCTAssertEqual(ch0_ptr[1], 2);
    XCTAssertEqual(ch1_ptr[1], 3);
    XCTAssertEqual(ch0_ptr[2], 4);
    XCTAssertEqual(ch1_ptr[2], 5);
    XCTAssertEqual(ch0_ptr[3], 6);
    XCTAssertEqual(ch1_ptr[3], 7);
}

@end
