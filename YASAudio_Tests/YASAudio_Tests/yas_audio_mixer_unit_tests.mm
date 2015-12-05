//
//  yas_audio_mixer_unit_tests.mm
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "yas_audio_test_utils.h"

@interface YASAudioMixerUnitTests : XCTestCase

@end

@implementation YASAudioMixerUnitTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

/*
 MacはFloat32、iOSはFloat32とFixed8.24のみ
 NonInterleavedのみ
 initialize後は出力側のフォーマットの指定ができない
 */

- (void)test_set_format_success
{
    yas::audio::unit mixer_unit(kAudioUnitType_Mixer, kAudioUnitSubType_MultiChannelMixer);

    /*
     Float32
     NonInterleaved
     */

    auto format = yas::audio::format(48000.0, 2, yas::pcm_format::float32, false);

    XCTAssertNoThrow(mixer_unit.set_output_format(format.stream_description(), 0));

    XCTAssertNoThrow(yas::audio::unit::private_access::initialize(mixer_unit));

    XCTAssertNoThrow(mixer_unit.set_input_format(format.stream_description(), 0));

    AudioStreamBasicDescription asbd = {0};
    XCTAssertNoThrow(asbd = mixer_unit.output_format(0));
    XCTAssertTrue(yas::is_equal(format.stream_description(), asbd));

    memset(&asbd, 0, sizeof(AudioStreamBasicDescription));
    XCTAssertNoThrow(asbd = mixer_unit.input_format(0));
    XCTAssertTrue(yas::is_equal(format.stream_description(), asbd));

    XCTAssertNoThrow(yas::audio::unit::private_access::uninitialize(mixer_unit));

#if TARGET_OS_IPHONE
    /*
     Fixed8.24
     */

    format = yas::audio::format(48000.0, 2, yas::pcm_format::fixed824, false);

    XCTAssertNoThrow(mixer_unit.set_output_format(format.stream_description(), 0));

    XCTAssertNoThrow(yas::audio::unit::private_access::initialize(mixer_unit));

    XCTAssertNoThrow(mixer_unit.set_input_format(format.stream_description(), 0));

    memset(&asbd, 0, sizeof(AudioStreamBasicDescription));
    XCTAssertNoThrow(asbd = mixer_unit.output_format(0));
    XCTAssertTrue(yas::is_equal(format.stream_description(), asbd));

    memset(&asbd, 0, sizeof(AudioStreamBasicDescription));
    XCTAssertNoThrow(asbd = mixer_unit.input_format(0));
    XCTAssertTrue(yas::is_equal(format.stream_description(), asbd));

    XCTAssertNoThrow(yas::audio::unit::private_access::uninitialize(mixer_unit));
#endif
}

- (void)test_set_format_failed
{
    yas::audio::unit mixer_unit(kAudioUnitType_Mixer, kAudioUnitSubType_MultiChannelMixer);

    /*
     Initialized
     */

    auto format = yas::audio::format(48000.0, 2, yas::pcm_format::float32, false);

    yas::audio::unit::private_access::initialize(mixer_unit);
    XCTAssertThrows(mixer_unit.set_output_format(format.stream_description(), 0));
    yas::audio::unit::private_access::uninitialize(mixer_unit);
    XCTAssertNoThrow(mixer_unit.set_output_format(format.stream_description(), 0));

    /*
     Float64
     */

    format = yas::audio::format(48000.0, 2, yas::pcm_format::float64, false);
    XCTAssertThrows(mixer_unit.set_output_format(format.stream_description(), 0));

    /*
     Int16
     */

    format = yas::audio::format(48000.0, 2, yas::pcm_format::int16, false);
    XCTAssertThrows(mixer_unit.set_output_format(format.stream_description(), 0));

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    /*
     Fixed8.24
     */

    format = yas::audio::format(48000.0, 2, yas::pcm_format::fixed824, false);
    XCTAssertThrows(mixer_unit.set_output_format(format.stream_description(), 0));
#endif

    /*
     Interleaved
     */

    format = yas::audio::format(48000.0, 2, yas::pcm_format::float32, true);
    XCTAssertThrows(mixer_unit.set_output_format(format.stream_description(), 0));
    XCTAssertThrows(mixer_unit.set_input_format(format.stream_description(), 0));
}

@end
