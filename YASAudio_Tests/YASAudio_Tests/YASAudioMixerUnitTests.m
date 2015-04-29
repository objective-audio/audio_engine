//
//  YASAudioMixerUnitTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "YASAudioTestUtils.h"
#import "YASAudioUnit+Internal.h"

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

- (void)testSetFormatSuccess
{
    YASAudioUnit *mixerUnit =
        [[YASAudioUnit alloc] initWithType:kAudioUnitType_Mixer subType:kAudioUnitSubType_MultiChannelMixer];

    /*
     Float32
     NonInterleaved
     */
    YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatFloat32
                                                                 sampleRate:48000
                                                                   channels:2
                                                                interleaved:NO];
    XCTAssertNoThrow([mixerUnit setOutputFormat:format.streamDescription busNumber:0]);

    XCTAssertNoThrow([mixerUnit initialize]);

    XCTAssertNoThrow([mixerUnit setInputFormat:format.streamDescription busNumber:0]);

    AudioStreamBasicDescription asbd = {0};
    XCTAssertNoThrow([mixerUnit getOutputFormat:&asbd busNumber:0]);
    XCTAssertTrue(YASAudioIsEqualASBD(format.streamDescription, &asbd));

    memset(&asbd, 0, sizeof(AudioStreamBasicDescription));
    XCTAssertNoThrow([mixerUnit getInputFormat:&asbd busNumber:0]);
    XCTAssertTrue(YASAudioIsEqualASBD(format.streamDescription, &asbd));

    XCTAssertNoThrow([mixerUnit uninitialize]);

    YASRelease(format);

#if TARGET_OS_IPHONE
    /*
     Fixed8.24
     */

    format = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatFixed824
                                                 sampleRate:48000
                                                   channels:2
                                                interleaved:NO];

    XCTAssertNoThrow([mixerUnit setOutputFormat:format.streamDescription busNumber:0]);
    
    XCTAssertNoThrow([mixerUnit initialize]);
    
    XCTAssertNoThrow([mixerUnit setInputFormat:format.streamDescription busNumber:0]);

    memset(&asbd, 0, sizeof(AudioStreamBasicDescription));
    XCTAssertNoThrow([mixerUnit getOutputFormat:&asbd busNumber:0]);
    XCTAssertTrue(YASAudioIsEqualASBD(format.streamDescription, &asbd));

    memset(&asbd, 0, sizeof(AudioStreamBasicDescription));
    XCTAssertNoThrow([mixerUnit getInputFormat:&asbd busNumber:0]);
    XCTAssertTrue(YASAudioIsEqualASBD(format.streamDescription, &asbd));
    
    XCTAssertNoThrow([mixerUnit uninitialize]);

    YASRelease(format);
#endif

    YASRelease(mixerUnit);
}

- (void)testSetFormatFailed
{
    YASAudioUnit *mixerUnit =
        [[YASAudioUnit alloc] initWithType:kAudioUnitType_Mixer subType:kAudioUnitSubType_MultiChannelMixer];

    YASAudioFormat *format = nil;

    /*
     Initialized
     */

    format = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatFloat32
                                                 sampleRate:48000
                                                   channels:2
                                                interleaved:NO];
    [mixerUnit initialize];
    XCTAssertThrows([mixerUnit setOutputFormat:format.streamDescription busNumber:0]);
    [mixerUnit uninitialize];
    XCTAssertNoThrow([mixerUnit setOutputFormat:format.streamDescription busNumber:0]);
    YASRelease(format);

    /*
     Float64
     */

    format = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatFloat64
                                                 sampleRate:48000
                                                   channels:2
                                                interleaved:NO];
    XCTAssertThrows([mixerUnit setOutputFormat:format.streamDescription busNumber:0]);
    YASRelease(format);

    /*
     Int16
     */

    format = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatInt16
                                                 sampleRate:48000
                                                   channels:2
                                                interleaved:NO];
    XCTAssertThrows([mixerUnit setOutputFormat:format.streamDescription busNumber:0]);
    YASRelease(format);

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    /*
     Fixed8.24
     */

    format = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatFixed824
                                                 sampleRate:48000
                                                   channels:2
                                                interleaved:NO];

    XCTAssertThrows([mixerUnit setOutputFormat:format.streamDescription busNumber:0]);
    YASRelease(format);
#endif

    /*
     Interleaved
     */

    format = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatFloat32
                                                 sampleRate:48000
                                                   channels:2
                                                interleaved:YES];
    XCTAssertThrows([mixerUnit setOutputFormat:format.streamDescription busNumber:0]);
    XCTAssertThrows([mixerUnit setInputFormat:format.streamDescription busNumber:0]);
    YASRelease(format);

    YASRelease(mixerUnit);
}

@end
