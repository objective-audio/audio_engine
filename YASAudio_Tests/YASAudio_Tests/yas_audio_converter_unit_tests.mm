//
//  yas_audio_converter_unit_tests.mm
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "yas_audio.h"

@interface yas_audio_converter_unit_tests : XCTestCase

@end

@implementation yas_audio_converter_unit_tests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testSetFormatSuccess
{
    const auto converter_unit = yas::audio_unit::create(kAudioUnitType_FormatConverter, kAudioUnitSubType_AUConverter);
    const yas::pcm_format pcm_formats[] = {yas::pcm_format::float32, yas::pcm_format::float64, yas::pcm_format::int16,
                                           yas::pcm_format::fixed824};
    const Float64 sample_rates[] = {4000, 8000, 16000, 22050, 44100, 48000, 88100, 96000, 192000, 382000};
    const bool interleaves[] = {false, true};

    for (const auto &pcm_format : pcm_formats) {
        for (const auto &sample_rate : sample_rates) {
            for (const auto &interleaved : interleaves) {
                const auto format = yas::audio_format::create(sample_rate, 2, pcm_format, interleaved);
                XCTAssertNoThrow(yas::audio_unit::private_access::initialize(converter_unit));
                XCTAssertNoThrow(converter_unit->set_output_format(format->stream_description(), 0));
                XCTAssertNoThrow(converter_unit->set_input_format(format->stream_description(), 0));

                AudioStreamBasicDescription asbd = {0};
                XCTAssertNoThrow(asbd = converter_unit->output_format(0));
                XCTAssertTrue(yas::is_equal(format->stream_description(), asbd));

                memset(&asbd, 0, sizeof(AudioStreamBasicDescription));
                XCTAssertNoThrow(asbd = converter_unit->input_format(0));
                XCTAssertTrue(yas::is_equal(format->stream_description(), asbd));

                XCTAssertNoThrow(yas::audio_unit::private_access::uninitialize(converter_unit));
            }
        }
    }
}

@end
