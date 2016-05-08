//
//  yas_audio_converter_unit_tests.mm
//

#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_converter_unit_tests : XCTestCase

@end

@implementation yas_audio_converter_unit_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testSetFormatSuccess {
    audio::unit converter_unit(kAudioUnitType_FormatConverter, kAudioUnitSubType_AUConverter);
    const audio::pcm_format pcm_formats[] = {audio::pcm_format::float32, audio::pcm_format::float64,
                                             audio::pcm_format::int16, audio::pcm_format::fixed824};
    const Float64 sample_rates[] = {4000, 8000, 16000, 22050, 44100, 48000, 88100, 96000, 192000, 382000};
    const bool interleaves[] = {false, true};

    for (const auto &pcm_format : pcm_formats) {
        for (const auto &sample_rate : sample_rates) {
            for (const auto &interleaved : interleaves) {
                const auto format = audio::format(sample_rate, 2, pcm_format, interleaved);
                XCTAssertNoThrow(converter_unit.manageable().initialize());
                XCTAssertNoThrow(converter_unit.set_output_format(format.stream_description(), 0));
                XCTAssertNoThrow(converter_unit.set_input_format(format.stream_description(), 0));

                AudioStreamBasicDescription asbd = {0};
                XCTAssertNoThrow(asbd = converter_unit.output_format(0));
                XCTAssertTrue(is_equal(format.stream_description(), asbd));

                memset(&asbd, 0, sizeof(AudioStreamBasicDescription));
                XCTAssertNoThrow(asbd = converter_unit.input_format(0));
                XCTAssertTrue(is_equal(format.stream_description(), asbd));

                XCTAssertNoThrow(converter_unit.manageable().uninitialize());
            }
        }
    }
}

@end
