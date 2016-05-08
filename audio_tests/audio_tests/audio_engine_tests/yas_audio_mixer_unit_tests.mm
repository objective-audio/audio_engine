//
//  yas_audio_mixer_unit_tests.mm
//

#import "yas_audio_test_utils.h"

using namespace yas;

@interface YASAudioMixerUnitTests : XCTestCase

@end

@implementation YASAudioMixerUnitTests

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
    audio::unit mixer_unit(kAudioUnitType_Mixer, kAudioUnitSubType_MultiChannelMixer);

    /*
     Float32
     NonInterleaved
     */

    auto format = audio::format(48000.0, 2, audio::pcm_format::float32, false);

    XCTAssertNoThrow(mixer_unit.set_output_format(format.stream_description(), 0));

    XCTAssertNoThrow(mixer_unit.manageable().initialize());

    XCTAssertNoThrow(mixer_unit.set_input_format(format.stream_description(), 0));

    AudioStreamBasicDescription asbd = {0};
    XCTAssertNoThrow(asbd = mixer_unit.output_format(0));
    XCTAssertTrue(is_equal(format.stream_description(), asbd));

    memset(&asbd, 0, sizeof(AudioStreamBasicDescription));
    XCTAssertNoThrow(asbd = mixer_unit.input_format(0));
    XCTAssertTrue(is_equal(format.stream_description(), asbd));

    XCTAssertNoThrow(mixer_unit.manageable().uninitialize());

#if TARGET_OS_IPHONE
    /*
     Fixed8.24
     */

    format = audio::format(48000.0, 2, audio::pcm_format::fixed824, false);

    XCTAssertNoThrow(mixer_unit.set_output_format(format.stream_description(), 0));

    XCTAssertNoThrow(mixer_unit.manageable().initialize());

    XCTAssertNoThrow(mixer_unit.set_input_format(format.stream_description(), 0));

    memset(&asbd, 0, sizeof(AudioStreamBasicDescription));
    XCTAssertNoThrow(asbd = mixer_unit.output_format(0));
    XCTAssertTrue(is_equal(format.stream_description(), asbd));

    memset(&asbd, 0, sizeof(AudioStreamBasicDescription));
    XCTAssertNoThrow(asbd = mixer_unit.input_format(0));
    XCTAssertTrue(is_equal(format.stream_description(), asbd));

    XCTAssertNoThrow(mixer_unit.manageable().uninitialize());
#endif
}

- (void)test_set_format_failed {
    audio::unit mixer_unit(kAudioUnitType_Mixer, kAudioUnitSubType_MultiChannelMixer);

    /*
     Initialized
     */

    auto format = audio::format(48000.0, 2, audio::pcm_format::float32, false);

    mixer_unit.manageable().initialize();
    XCTAssertThrows(mixer_unit.set_output_format(format.stream_description(), 0));
    mixer_unit.manageable().uninitialize();
    XCTAssertNoThrow(mixer_unit.set_output_format(format.stream_description(), 0));

    /*
     Float64
     */

    format = audio::format(48000.0, 2, audio::pcm_format::float64, false);
    XCTAssertThrows(mixer_unit.set_output_format(format.stream_description(), 0));

    /*
     Int16
     */

    format = audio::format(48000.0, 2, audio::pcm_format::int16, false);
    XCTAssertThrows(mixer_unit.set_output_format(format.stream_description(), 0));

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    /*
     Fixed8.24
     */

    format = audio::format(48000.0, 2, audio::pcm_format::fixed824, false);
    XCTAssertThrows(mixer_unit.set_output_format(format.stream_description(), 0));
#endif

    /*
     Interleaved
     */

    format = audio::format(48000.0, 2, audio::pcm_format::float32, true);
    XCTAssertThrows(mixer_unit.set_output_format(format.stream_description(), 0));
    XCTAssertThrows(mixer_unit.set_input_format(format.stream_description(), 0));
}

@end
