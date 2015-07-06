//
//  yas_audio_file_utils_tests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "yas_audio_file_utils.h"

@interface yas_audio_file_utils_tests : XCTestCase

@end

@implementation yas_audio_file_utils_tests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testWaveFileSettingsInt16
{
    const Float64 sampleRate = 44100;
    const UInt32 channels = 2;
    const UInt32 bitDepth = 16;

    NSDictionary *settings = (__bridge NSDictionary *)yas::wave_file_settings(sampleRate, channels, bitDepth);

    XCTAssertEqualObjects(settings[AVFormatIDKey], @(kAudioFormatLinearPCM));
    XCTAssertEqualObjects(settings[AVSampleRateKey], @(sampleRate));
    XCTAssertEqualObjects(settings[AVNumberOfChannelsKey], @(channels));
    XCTAssertEqualObjects(settings[AVLinearPCMBitDepthKey], @(bitDepth));
    XCTAssertEqualObjects(settings[AVLinearPCMIsBigEndianKey], @(NO));
    XCTAssertEqualObjects(settings[AVLinearPCMIsFloatKey], @(NO));
    XCTAssertEqualObjects(settings[AVLinearPCMIsNonInterleaved], @(NO));
    XCTAssertNotNil(settings[AVChannelLayoutKey]);
}

- (void)testWaveFileSettingsFloat32
{
    const Float64 sampleRate = 48000;
    const UInt32 channels = 4;
    const UInt32 bitDepth = 32;

    NSDictionary *settings = (__bridge NSDictionary *)yas::wave_file_settings(sampleRate, channels, bitDepth);

    XCTAssertEqualObjects(settings[AVFormatIDKey], @(kAudioFormatLinearPCM));
    XCTAssertEqualObjects(settings[AVSampleRateKey], @(sampleRate));
    XCTAssertEqualObjects(settings[AVNumberOfChannelsKey], @(channels));
    XCTAssertEqualObjects(settings[AVLinearPCMBitDepthKey], @(bitDepth));
    XCTAssertEqualObjects(settings[AVLinearPCMIsBigEndianKey], @(NO));
    XCTAssertEqualObjects(settings[AVLinearPCMIsFloatKey], @(YES));
    XCTAssertEqualObjects(settings[AVLinearPCMIsNonInterleaved], @(NO));
    XCTAssertNotNil(settings[AVChannelLayoutKey]);
}

- (void)testAIFFSettingsInt16
{
    const Float64 sampleRate = 32000;
    const UInt32 channels = 2;
    const UInt32 bitDepth = 16;

    NSDictionary *settings = (__bridge NSDictionary *)yas::aiff_file_settings(sampleRate, channels, bitDepth);

    XCTAssertEqualObjects(settings[AVFormatIDKey], @(kAudioFormatLinearPCM));
    XCTAssertEqualObjects(settings[AVSampleRateKey], @(sampleRate));
    XCTAssertEqualObjects(settings[AVNumberOfChannelsKey], @(channels));
    XCTAssertEqualObjects(settings[AVLinearPCMBitDepthKey], @(bitDepth));
    XCTAssertEqualObjects(settings[AVLinearPCMIsBigEndianKey], @(YES));
    XCTAssertEqualObjects(settings[AVLinearPCMIsFloatKey], @(NO));
    XCTAssertEqualObjects(settings[AVLinearPCMIsNonInterleaved], @(NO));
    XCTAssertNotNil(settings[AVChannelLayoutKey]);
}

- (void)testAIFFSettingsFloat32
{
    const Float64 sampleRate = 96000;
    const UInt32 channels = 3;
    const UInt32 bitDepth = 32;

    NSDictionary *settings = (__bridge NSDictionary *)yas::aiff_file_settings(sampleRate, channels, bitDepth);

    XCTAssertEqualObjects(settings[AVFormatIDKey], @(kAudioFormatLinearPCM));
    XCTAssertEqualObjects(settings[AVSampleRateKey], @(sampleRate));
    XCTAssertEqualObjects(settings[AVNumberOfChannelsKey], @(channels));
    XCTAssertEqualObjects(settings[AVLinearPCMBitDepthKey], @(bitDepth));
    XCTAssertEqualObjects(settings[AVLinearPCMIsBigEndianKey], @(YES));
    XCTAssertEqualObjects(settings[AVLinearPCMIsFloatKey], @(YES));
    XCTAssertEqualObjects(settings[AVLinearPCMIsNonInterleaved], @(NO));
    XCTAssertNotNil(settings[AVChannelLayoutKey]);
}

- (void)testAACSettings
{
    const Float64 sampleRate = 48000;
    const UInt32 channels = 2;
    const UInt32 bitDepth = 16;
    const AVAudioQuality encoderQuality = AVAudioQualityMedium;
    const UInt32 bitRate = 128000;
    const UInt32 bitDepthHint = 16;
    const AVAudioQuality converterQuality = AVAudioQualityMax;

    NSDictionary *settings = (__bridge NSDictionary *)yas::aac_settings(sampleRate, channels, bitDepth, encoderQuality,
                                                                        bitRate, bitDepthHint, converterQuality);

    XCTAssertEqualObjects(settings[AVFormatIDKey], @(kAudioFormatMPEG4AAC));
    XCTAssertEqualObjects(settings[AVSampleRateKey], @(sampleRate));

    XCTAssertEqualObjects(settings[AVNumberOfChannelsKey], @(channels));
    XCTAssertEqualObjects(settings[AVLinearPCMBitDepthKey], @(bitDepth));
    XCTAssertEqualObjects(settings[AVLinearPCMIsBigEndianKey], @(NO));
    XCTAssertEqualObjects(settings[AVLinearPCMIsFloatKey], @(NO));
    XCTAssertEqualObjects(settings[AVEncoderAudioQualityKey], @(encoderQuality));
    XCTAssertEqualObjects(settings[AVEncoderBitRateKey], @(bitRate));
    XCTAssertEqualObjects(settings[AVEncoderBitDepthHintKey], @(bitDepthHint));
    XCTAssertEqualObjects(settings[AVSampleRateConverterAudioQualityKey], @(converterQuality));
}

- (void)testAudioFileTypeIDFromFileType
{
    XCTAssertEqual(yas::to_audio_file_type_id(yas::audio_file_type::three_gpp), kAudioFile3GPType);
    XCTAssertEqual(yas::to_audio_file_type_id(yas::audio_file_type::three_gpp2), kAudioFile3GP2Type);
    XCTAssertEqual(yas::to_audio_file_type_id(yas::audio_file_type::aifc), kAudioFileAIFCType);
    XCTAssertEqual(yas::to_audio_file_type_id(yas::audio_file_type::aiff), kAudioFileAIFFType);
    XCTAssertEqual(yas::to_audio_file_type_id(yas::audio_file_type::amr), kAudioFileAMRType);
    XCTAssertEqual(yas::to_audio_file_type_id(yas::audio_file_type::ac3), kAudioFileAC3Type);
    XCTAssertEqual(yas::to_audio_file_type_id(yas::audio_file_type::mpeg_layer3), kAudioFileMP3Type);
    XCTAssertEqual(yas::to_audio_file_type_id(yas::audio_file_type::core_audio_format), kAudioFileCAFType);
    XCTAssertEqual(yas::to_audio_file_type_id(yas::audio_file_type::mpeg4), kAudioFileMPEG4Type);
    XCTAssertEqual(yas::to_audio_file_type_id(yas::audio_file_type::apple_m4a), kAudioFileM4AType);
    XCTAssertEqual(yas::to_audio_file_type_id(yas::audio_file_type::wave), kAudioFileWAVEType);
}

- (void)testFileTypeFromAudioFileTypeID
{
    XCTAssertEqual(yas::to_audio_file_type(kAudioFile3GPType), yas::audio_file_type::three_gpp);
    XCTAssertEqual(yas::to_audio_file_type(kAudioFile3GP2Type), yas::audio_file_type::three_gpp2);
    XCTAssertEqual(yas::to_audio_file_type(kAudioFileAIFCType), yas::audio_file_type::aifc);
    XCTAssertEqual(yas::to_audio_file_type(kAudioFileAIFFType), yas::audio_file_type::aiff);
    XCTAssertEqual(yas::to_audio_file_type(kAudioFileAMRType), yas::audio_file_type::amr);
    XCTAssertEqual(yas::to_audio_file_type(kAudioFileAC3Type), yas::audio_file_type::ac3);
    XCTAssertEqual(yas::to_audio_file_type(kAudioFileMP3Type), yas::audio_file_type::mpeg_layer3);
    XCTAssertEqual(yas::to_audio_file_type(kAudioFileCAFType), yas::audio_file_type::core_audio_format);
    XCTAssertEqual(yas::to_audio_file_type(kAudioFileMPEG4Type), yas::audio_file_type::mpeg4);
    XCTAssertEqual(yas::to_audio_file_type(kAudioFileM4AType), yas::audio_file_type::apple_m4a);
    XCTAssertEqual(yas::to_audio_file_type(kAudioFileWAVEType), yas::audio_file_type::wave);

    XCTAssert(!yas::to_audio_file_type(0));
}

@end
