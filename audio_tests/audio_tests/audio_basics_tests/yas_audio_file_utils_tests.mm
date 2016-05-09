//
//  yas_audio_file_utils_tests.m
//

#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_file_utils_tests : XCTestCase

@end

@implementation yas_audio_file_utils_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testWaveFileSettingsInt16 {
    const double sampleRate = 44100;
    const uint32_t channels = 2;
    const uint32_t bitDepth = 16;

    NSDictionary *settings = (__bridge NSDictionary *)audio::wave_file_settings(sampleRate, channels, bitDepth);

    XCTAssertEqualObjects(settings[AVFormatIDKey], @(kAudioFormatLinearPCM));
    XCTAssertEqualObjects(settings[AVSampleRateKey], @(sampleRate));
    XCTAssertEqualObjects(settings[AVNumberOfChannelsKey], @(channels));
    XCTAssertEqualObjects(settings[AVLinearPCMBitDepthKey], @(bitDepth));
    XCTAssertEqualObjects(settings[AVLinearPCMIsBigEndianKey], @(NO));
    XCTAssertEqualObjects(settings[AVLinearPCMIsFloatKey], @(NO));
    XCTAssertEqualObjects(settings[AVLinearPCMIsNonInterleaved], @(NO));
    XCTAssertNotNil(settings[AVChannelLayoutKey]);
}

- (void)testWaveFileSettingsFloat32 {
    const double sampleRate = 48000;
    const uint32_t channels = 4;
    const uint32_t bitDepth = 32;

    NSDictionary *settings = (__bridge NSDictionary *)audio::wave_file_settings(sampleRate, channels, bitDepth);

    XCTAssertEqualObjects(settings[AVFormatIDKey], @(kAudioFormatLinearPCM));
    XCTAssertEqualObjects(settings[AVSampleRateKey], @(sampleRate));
    XCTAssertEqualObjects(settings[AVNumberOfChannelsKey], @(channels));
    XCTAssertEqualObjects(settings[AVLinearPCMBitDepthKey], @(bitDepth));
    XCTAssertEqualObjects(settings[AVLinearPCMIsBigEndianKey], @(NO));
    XCTAssertEqualObjects(settings[AVLinearPCMIsFloatKey], @(YES));
    XCTAssertEqualObjects(settings[AVLinearPCMIsNonInterleaved], @(NO));
    XCTAssertNotNil(settings[AVChannelLayoutKey]);
}

- (void)testAIFFSettingsInt16 {
    const double sampleRate = 32000;
    const uint32_t channels = 2;
    const uint32_t bitDepth = 16;

    NSDictionary *settings = (__bridge NSDictionary *)audio::aiff_file_settings(sampleRate, channels, bitDepth);

    XCTAssertEqualObjects(settings[AVFormatIDKey], @(kAudioFormatLinearPCM));
    XCTAssertEqualObjects(settings[AVSampleRateKey], @(sampleRate));
    XCTAssertEqualObjects(settings[AVNumberOfChannelsKey], @(channels));
    XCTAssertEqualObjects(settings[AVLinearPCMBitDepthKey], @(bitDepth));
    XCTAssertEqualObjects(settings[AVLinearPCMIsBigEndianKey], @(YES));
    XCTAssertEqualObjects(settings[AVLinearPCMIsFloatKey], @(NO));
    XCTAssertEqualObjects(settings[AVLinearPCMIsNonInterleaved], @(NO));
    XCTAssertNotNil(settings[AVChannelLayoutKey]);
}

- (void)testAIFFSettingsFloat32 {
    const double sampleRate = 96000;
    const uint32_t channels = 3;
    const uint32_t bitDepth = 32;

    NSDictionary *settings = (__bridge NSDictionary *)audio::aiff_file_settings(sampleRate, channels, bitDepth);

    XCTAssertEqualObjects(settings[AVFormatIDKey], @(kAudioFormatLinearPCM));
    XCTAssertEqualObjects(settings[AVSampleRateKey], @(sampleRate));
    XCTAssertEqualObjects(settings[AVNumberOfChannelsKey], @(channels));
    XCTAssertEqualObjects(settings[AVLinearPCMBitDepthKey], @(bitDepth));
    XCTAssertEqualObjects(settings[AVLinearPCMIsBigEndianKey], @(YES));
    XCTAssertEqualObjects(settings[AVLinearPCMIsFloatKey], @(YES));
    XCTAssertEqualObjects(settings[AVLinearPCMIsNonInterleaved], @(NO));
    XCTAssertNotNil(settings[AVChannelLayoutKey]);
}

- (void)testAACSettings {
    const double sampleRate = 48000;
    const uint32_t channels = 2;
    const uint32_t bitDepth = 16;
    const AVAudioQuality encoderQuality = AVAudioQualityMedium;
    const uint32_t bitRate = 128000;
    const uint32_t bitDepthHint = 16;
    const AVAudioQuality converterQuality = AVAudioQualityMax;

    NSDictionary *settings = (__bridge NSDictionary *)audio::aac_settings(
        sampleRate, channels, bitDepth, encoderQuality, bitRate, bitDepthHint, converterQuality);

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

- (void)testAudioFileTypeIDFromFileType {
    XCTAssertEqual(audio::to_audio_file_type_id(audio::file_type::three_gpp), kAudioFile3GPType);
    XCTAssertEqual(audio::to_audio_file_type_id(audio::file_type::three_gpp2), kAudioFile3GP2Type);
    XCTAssertEqual(audio::to_audio_file_type_id(audio::file_type::aifc), kAudioFileAIFCType);
    XCTAssertEqual(audio::to_audio_file_type_id(audio::file_type::aiff), kAudioFileAIFFType);
    XCTAssertEqual(audio::to_audio_file_type_id(audio::file_type::amr), kAudioFileAMRType);
    XCTAssertEqual(audio::to_audio_file_type_id(audio::file_type::ac3), kAudioFileAC3Type);
    XCTAssertEqual(audio::to_audio_file_type_id(audio::file_type::mpeg_layer3), kAudioFileMP3Type);
    XCTAssertEqual(audio::to_audio_file_type_id(audio::file_type::core_audio_format), kAudioFileCAFType);
    XCTAssertEqual(audio::to_audio_file_type_id(audio::file_type::mpeg4), kAudioFileMPEG4Type);
    XCTAssertEqual(audio::to_audio_file_type_id(audio::file_type::apple_m4a), kAudioFileM4AType);
    XCTAssertEqual(audio::to_audio_file_type_id(audio::file_type::wave), kAudioFileWAVEType);
}

- (void)testFileTypeFromAudioFileTypeID {
    XCTAssertEqual(audio::to_file_type(kAudioFile3GPType), audio::file_type::three_gpp);
    XCTAssertEqual(audio::to_file_type(kAudioFile3GP2Type), audio::file_type::three_gpp2);
    XCTAssertEqual(audio::to_file_type(kAudioFileAIFCType), audio::file_type::aifc);
    XCTAssertEqual(audio::to_file_type(kAudioFileAIFFType), audio::file_type::aiff);
    XCTAssertEqual(audio::to_file_type(kAudioFileAMRType), audio::file_type::amr);
    XCTAssertEqual(audio::to_file_type(kAudioFileAC3Type), audio::file_type::ac3);
    XCTAssertEqual(audio::to_file_type(kAudioFileMP3Type), audio::file_type::mpeg_layer3);
    XCTAssertEqual(audio::to_file_type(kAudioFileCAFType), audio::file_type::core_audio_format);
    XCTAssertEqual(audio::to_file_type(kAudioFileMPEG4Type), audio::file_type::mpeg4);
    XCTAssertEqual(audio::to_file_type(kAudioFileM4AType), audio::file_type::apple_m4a);
    XCTAssertEqual(audio::to_file_type(kAudioFileWAVEType), audio::file_type::wave);

    XCTAssert(!audio::to_file_type(0));
}

@end
