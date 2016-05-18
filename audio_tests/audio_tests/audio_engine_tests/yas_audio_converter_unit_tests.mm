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
    audio::pcm_format const pcm_formats[] = {audio::pcm_format::float32, audio::pcm_format::float64,
                                             audio::pcm_format::int16, audio::pcm_format::fixed824};
    double const sample_rates[] = {4000, 8000, 16000, 22050, 44100, 48000, 88100, 96000, 192000, 382000};
    bool const interleaves[] = {false, true};

    for (auto const &pcm_format : pcm_formats) {
        for (auto const &sample_rate : sample_rates) {
            for (auto const &interleaved : interleaves) {
                auto const format = audio::format({.sample_rate = sample_rate,
                                                   .channel_count = 2,
                                                   .pcm_format = pcm_format,
                                                   .interleaved = interleaved});
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
