//
//  yas_audio_mixer_unit_tests.mm
//

#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_mixer_unit_tests : XCTestCase

@end

@implementation yas_audio_mixer_unit_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

/*
 MacはFloat32、iOSはFloat32とFixed8.24のみ
 NonInterleavedのみ
 initialize後は出力側のフォーマットの指定ができない
 */

- (void)test_set_format_success {
    auto mixer_unit = audio::unit::make_shared(kAudioUnitType_Mixer, kAudioUnitSubType_MultiChannelMixer);
    auto manageable_unit = mixer_unit->manageable();

    /*
     Float32
     NonInterleaved
     */

    auto format = audio::format(
        {.sample_rate = 48000.0, .channel_count = 2, .pcm_format = audio::pcm_format::float32, .interleaved = false});

    XCTAssertNoThrow(mixer_unit->set_output_format(format.stream_description(), 0));

    XCTAssertNoThrow(manageable_unit->initialize());

    XCTAssertNoThrow(mixer_unit->set_input_format(format.stream_description(), 0));

    AudioStreamBasicDescription asbd = {0};
    XCTAssertNoThrow(asbd = mixer_unit->output_format(0));
    XCTAssertTrue(is_equal(format.stream_description(), asbd));

    memset(&asbd, 0, sizeof(AudioStreamBasicDescription));
    XCTAssertNoThrow(asbd = mixer_unit->input_format(0));
    XCTAssertTrue(is_equal(format.stream_description(), asbd));

    XCTAssertNoThrow(manageable_unit->uninitialize());

#if TARGET_OS_IPHONE
    /*
     Fixed8.24
     */

    format = audio::format(
        {.sample_rate = 48000.0, .channel_count = 2, .pcm_format = audio::pcm_format::fixed824, .interleaved = false});

    XCTAssertNoThrow(mixer_unit->set_output_format(format.stream_description(), 0));

    XCTAssertNoThrow(manageable_unit->initialize());

    XCTAssertNoThrow(mixer_unit->set_input_format(format.stream_description(), 0));

    memset(&asbd, 0, sizeof(AudioStreamBasicDescription));
    XCTAssertNoThrow(asbd = mixer_unit->output_format(0));
    XCTAssertTrue(is_equal(format.stream_description(), asbd));

    memset(&asbd, 0, sizeof(AudioStreamBasicDescription));
    XCTAssertNoThrow(asbd = mixer_unit->input_format(0));
    XCTAssertTrue(is_equal(format.stream_description(), asbd));

    XCTAssertNoThrow(manageable_unit->uninitialize());
#endif
}

- (void)test_set_format_failed {
    auto mixer_unit = audio::unit::make_shared(kAudioUnitType_Mixer, kAudioUnitSubType_MultiChannelMixer);
    auto manageable_unit = mixer_unit->manageable();

    /*
     Initialized
     */

    auto format = audio::format({.sample_rate = 48000.0, 2, audio::pcm_format::float32, false});

    manageable_unit->initialize();
    XCTAssertThrows(mixer_unit->set_output_format(format.stream_description(), 0));
    manageable_unit->uninitialize();
    XCTAssertNoThrow(mixer_unit->set_output_format(format.stream_description(), 0));

    /*
     Float64
     */

    format = audio::format(
        {.sample_rate = 48000.0, .channel_count = 2, .pcm_format = audio::pcm_format::float64, .interleaved = false});
    XCTAssertThrows(mixer_unit->set_output_format(format.stream_description(), 0));

    /*
     Int16
     */

    format = audio::format(
        {.sample_rate = 48000.0, .channel_count = 2, .pcm_format = audio::pcm_format::int16, .interleaved = false});
    XCTAssertThrows(mixer_unit->set_output_format(format.stream_description(), 0));
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    /*
     Fixed8.24
     */

    format = audio::format(
        {.sample_rate = 48000.0, .channel_count = 2, .pcm_format = audio::pcm_format::fixed824, .interleaved = false});
    XCTAssertThrows(mixer_unit->set_output_format(format.stream_description(), 0));
#endif

    /*
     Interleaved
     */

    format = audio::format(
        {.sample_rate = 48000.0, .channel_count = 2, .pcm_format = audio::pcm_format::float32, .interleaved = true});
    XCTAssertThrows(mixer_unit->set_output_format(format.stream_description(), 0));
    XCTAssertThrows(mixer_unit->set_input_format(format.stream_description(), 0));
}

@end
