//
//  yas_audio_objc_utils_tests.mm
//

#import <XCTest/XCTest.h>
#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_objc_utils_tests : XCTestCase

@end

@implementation yas_audio_objc_utils_tests

- (void)test_to_common_format {
    XCTAssertEqual(to_common_format(audio::pcm_format::float64), AVAudioPCMFormatFloat64);
    XCTAssertEqual(to_common_format(audio::pcm_format::float32), AVAudioPCMFormatFloat32);
    XCTAssertEqual(to_common_format(audio::pcm_format::fixed824), AVAudioPCMFormatInt32);
    XCTAssertEqual(to_common_format(audio::pcm_format::int16), AVAudioPCMFormatInt16);
}

- (void)test_to_object_object_from_format {
    {
        audio::format format{{.sample_rate = 44100.0,
                              .channel_count = 2,
                              .pcm_format = audio::pcm_format::float32,
                              .interleaved = false}};

        auto objc_format = to_objc_object(format);

        XCTAssertEqual(objc_format.object().commonFormat, AVAudioPCMFormatFloat32);
        XCTAssertEqual(objc_format.object().sampleRate, 44100.0);
        XCTAssertEqual(objc_format.object().channelCount, 2);
        XCTAssertEqual(objc_format.object().interleaved, false);
    }

    {
        audio::format format{
            {.sample_rate = 96000.0, .channel_count = 3, .pcm_format = audio::pcm_format::int16, .interleaved = true}};

        auto objc_format = to_objc_object(format);

        XCTAssertEqual(objc_format.object().commonFormat, AVAudioPCMFormatInt16);
        XCTAssertEqual(objc_format.object().sampleRate, 96000.0);
        XCTAssertEqual(objc_format.object().channelCount, 3);
        XCTAssertEqual(objc_format.object().interleaved, true);
    }
}

@end
