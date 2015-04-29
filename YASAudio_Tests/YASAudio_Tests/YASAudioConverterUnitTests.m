//
//  YASAudioConverterUnitTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "YASAudioTestUtils.h"

@interface YASAudioConverterUnitTests : XCTestCase

@end

@implementation YASAudioConverterUnitTests

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
    YASAudioUnit *converterUnit =
        [[YASAudioUnit alloc] initWithType:kAudioUnitType_FormatConverter subType:kAudioUnitSubType_AUConverter];

    const YASAudioPCMFormat pcmFormats[] = {YASAudioPCMFormatFloat32, YASAudioPCMFormatFloat64,
                                                 YASAudioPCMFormatInt16, YASAudioPCMFormatFixed824};
    const NSUInteger pcmFormatsCount = sizeof(pcmFormats) / sizeof(YASAudioPCMFormat);
    const Float64 sampleRates[] = {4000, 8000, 16000, 22050, 44100, 48000, 88100, 96000, 192000, 382000};
    const NSUInteger sampleRatesCount = sizeof(sampleRates) / sizeof(Float64);

    for (NSInteger pcmIdx = 0; pcmIdx < pcmFormatsCount; pcmIdx++) {
        for (NSInteger srIdx = 0; srIdx < sampleRatesCount; srIdx++) {
            for (NSInteger i = 0; i < 2; i++) {
                YASAudioFormat *format = [[YASAudioFormat alloc] initWithPCMFormat:pcmFormats[pcmIdx]
                                                                        sampleRate:sampleRates[srIdx]
                                                                          channels:2
                                                                       interleaved:i];

                XCTAssertNoThrow([converterUnit initialize]);

                XCTAssertNoThrow([converterUnit setOutputFormat:format.streamDescription busNumber:0]);
                XCTAssertNoThrow([converterUnit setInputFormat:format.streamDescription busNumber:0]);

                AudioStreamBasicDescription asbd = {0};
                XCTAssertNoThrow([converterUnit getOutputFormat:&asbd busNumber:0]);
                XCTAssertTrue(YASAudioIsEqualASBD(format.streamDescription, &asbd));

                memset(&asbd, 0, sizeof(AudioStreamBasicDescription));
                XCTAssertNoThrow([converterUnit getInputFormat:&asbd busNumber:0]);
                XCTAssertTrue(YASAudioIsEqualASBD(format.streamDescription, &asbd));

                XCTAssertNoThrow([converterUnit uninitialize]);

                YASRelease(format);
            }
        }
    }
}

@end
