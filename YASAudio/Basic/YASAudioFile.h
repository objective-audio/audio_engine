//
//  YASAudioFile.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioTypes.h"
#import <AVFoundation/AVFoundation.h>

extern NSString *const YASAudioFileType3GPP;
extern NSString *const YASAudioFileType3GPP2;
extern NSString *const YASAudioFileTypeAIFC;
extern NSString *const YASAudioFileTypeAIFF;
extern NSString *const YASAudioFileTypeAMR;
extern NSString *const YASAudioFileTypeAC3;
extern NSString *const YASAudioFileTypeMPEGLayer3;
extern NSString *const YASAudioFileTypeCoreAudioFormat;
extern NSString *const YASAudioFileTypeMPEG4;
extern NSString *const YASAudioFileTypeAppleM4A;
extern NSString *const YASAudioFileTypeWAVE;

@class YASAudioData, YASAudioFormat;

@interface YASAudioFile : NSObject

@property (nonatomic, strong, readonly) NSURL *url;
@property (nonatomic, strong, readonly) YASAudioFormat *fileFormat;
@property (nonatomic, strong) YASAudioFormat *processingFormat;
@property (nonatomic, readonly) SInt64 fileLength;
@property (nonatomic, readonly) SInt64 processingLength;
@property (nonatomic) UInt32 fileFramePosition;

@end

@interface YASAudioFileReader : YASAudioFile

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithURL:(NSURL *)fileURL error:(NSError **)outError;
- (instancetype)initWithURL:(NSURL *)fileURL
                  pcmFormat:(YASAudioPCMFormat)format
                interleaved:(BOOL)interleaved
                      error:(NSError **)outError;

- (BOOL)readIntoData:(YASAudioData *)data error:(NSError **)outError;
- (BOOL)readIntoData:(YASAudioData *)data frameLength:(UInt32)frameLength error:(NSError **)outError;

@end

@interface YASAudioFileWriter : YASAudioFile

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithURL:(NSURL *)fileURL
                   fileType:(NSString *)fileType
                   settings:(NSDictionary *)settings
                      error:(NSError **)outError;
- (instancetype)initWithURL:(NSURL *)fileURL
                   fileType:(NSString *)fileType
                   settings:(NSDictionary *)settings
                  pcmFormat:(YASAudioPCMFormat)format
                interleaved:(BOOL)interleaved
                      error:(NSError **)outError;

- (BOOL)writeSyncFromData:(YASAudioData *)data error:(NSError **)outError;
- (BOOL)writeAsyncFromData:(YASAudioData *)data error:(NSError **)outError;

@end

#pragma mark - NSDictionary Category

@interface NSDictionary (YASAudioFile)

+ (NSDictionary *)yas_waveFileSettingsWithSampleRate:(Float64)sampleRate
                                    numberOfChannels:(UInt32)channels
                                            bitDepth:(UInt32)bitDepth;

+ (NSDictionary *)yas_aiffFileSettingsWithSampleRate:(Float64)sampleRate
                                    numberOfChannels:(UInt32)channels
                                            bitDepth:(UInt32)bitDepth;

+ (NSDictionary *)yas_linearPCMSettingsWithSampleRate:(Float64)sampleRate
                                     numberOfChannels:(UInt32)channels
                                             bitDepth:(UInt32)bitDepth
                                          isBigEndian:(BOOL)isBigEndian
                                              isFloat:(BOOL)isFloat
                                     isNonInterleaved:(BOOL)isNonInterleaved;

+ (NSDictionary *)yas_aacSettingsWithSampleRate:(Float64)sampleRate
                               numberOfChannels:(UInt32)channels
                                       bitDepth:(UInt32)bitDepth
                                encoderQuallity:(AVAudioQuality)encoderQuality
                                 encoderBitRate:(UInt32)bitRate
                            encoderBitDepthHint:(UInt32)bitDepthHint
                     sampleRateConverterQuality:(AVAudioQuality)converterQuality;

@end
