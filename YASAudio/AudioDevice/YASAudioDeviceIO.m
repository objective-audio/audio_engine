//
//  YASAudioDeviceIO.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <TargetConditionals.h>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#import "YASAudioDeviceIO.h"
#import "YASAudioDevice.h"
#import "YASAudioData.h"
#import "YASAudioFormat.h"
#import "YASAudioUtility.h"
#import "YASMacros.h"
#import "NSException+YASAudio.h"
#import <AVFoundation/AVFoundation.h>

static UInt32 YASAudioDeviceIOFrameCapacity = 4096;

@class YASAudioData;

@interface YASAudioDeviceIOCore : NSObject

@property (nonatomic, strong) YASAudioData *inputData;
@property (nonatomic, strong) YASAudioData *outputData;

@end

@implementation YASAudioDeviceIOCore

- (void)dealloc
{
    YASRelease(_inputData);
    YASRelease(_outputData);

    _inputData = nil;
    _outputData = nil;

    YASSuperDealloc;
}

- (void)clearData
{
    [_inputData clear];
    [_outputData clear];
}

@end

@interface YASAudioDeviceIO ()

@property (nonatomic, assign) AudioDeviceIOProcID ioProcID;
@property (nonatomic, strong) YASAudioData *inputData;
@property (nonatomic, strong) AVAudioTime *inputTime;
@property (atomic, strong) YASAudioDeviceIOCore *core;

@end

@implementation YASAudioDeviceIO

- (instancetype)init
{
    return [self initWithAudioDevice:nil];
}

- (instancetype)initWithAudioDevice:(YASAudioDevice *)device
{
    self = [super init];
    if (self) {
        self.audioDevice = device;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(audioHardwareDidChange:)
                                                     name:YASAudioHardwareDidChangeNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc
{
    @autoreleasepool
    {
        [self uninitialize];
    }

    [[NSNotificationCenter defaultCenter] removeObserver:self];

    YASRelease(_renderCallbackBlock);
    YASRelease(_audioDevice);
    YASRelease(_inputData);
    YASRelease(_inputTime);
    YASRelease(_core);

    _renderCallbackBlock = nil;
    _audioDevice = nil;
    _inputData = nil;
    _inputTime = nil;
    _core = nil;

    YASSuperDealloc;
}

- (void)initialize
{
    if (!_audioDevice || _ioProcID) {
        return;
    }

    if (!_audioDevice.inputFormat && !_audioDevice.outputFormat) {
        YASLog(@"%s - Audio device do not have io.", __PRETTY_FUNCTION__);
        return;
    }

    YASWeakContainer *container = self.weakContainer;

    YASRaiseIfAUError(AudioDeviceCreateIOProcIDWithBlock(
        &_ioProcID, self.audioDevice.audioDeviceID, NULL,
        ^(const AudioTimeStamp *inNow, const AudioBufferList *inInputData, const AudioTimeStamp *inInputTime,
          AudioBufferList *outOutputData, const AudioTimeStamp *inOutputTime) {
            YASAudioClearAudioBufferList(outOutputData);

            YASAudioDeviceIO *deviceIO = [container retainedObject];

            YASAudioDeviceIOCore *core = deviceIO.core;
            if (core) {
                [core clearData];

                YASAudioData *inputData = core.inputData;
                [inputData copyFlexiblyFromAudioBufferList:inInputData];

                const UInt32 inputFrameLength = inputData.frameLength;
                if (inputFrameLength > 0) {
                    deviceIO.inputData = inputData;
                    AVAudioTime *inputTime =
                        [[AVAudioTime alloc] initWithAudioTimeStamp:inInputTime sampleRate:inputData.format.sampleRate];
                    deviceIO.inputTime = inputTime;
                    YASRelease(inputTime);
                }

                YASAudioDeviceIOCallbackBlock renderCallbackBlock = deviceIO.renderCallbackBlock;
                if (renderCallbackBlock) {
                    YASAudioData *outputData = core.outputData;
                    if (outputData) {
                        const UInt32 frameLength =
                            YASAudioGetFrameLengthFromAudioBufferList(outOutputData, outputData.format.sampleByteCount);
                        if (frameLength > 0) {
                            outputData.frameLength = frameLength;
                            AVAudioTime *time =
                                [[AVAudioTime alloc] initWithAudioTimeStamp:inOutputTime
                                                                 sampleRate:outputData.format.sampleRate];
                            renderCallbackBlock(outputData, time);
                            YASRelease(time);
                            [outputData copyFlexiblyToAudioBufferList:outOutputData];
                        }
                    } else if (deviceIO.inputData) {
                        renderCallbackBlock(NULL, NULL);
                    }
                }
            }

            deviceIO.inputData = nil;
            deviceIO.inputTime = nil;
            YASRelease(deviceIO);
        }));

    [self _updateCore];
}

- (void)uninitialize
{
    [self stop];

    if (!_audioDevice || !_ioProcID) {
        return;
    }

    YASRaiseIfAUError(AudioDeviceDestroyIOProcID(self.audioDevice.audioDeviceID, _ioProcID));

    _ioProcID = NULL;

    [self _updateCore];
}

- (void)start
{
    _isRunning = YES;

    if (!_audioDevice || !_ioProcID) {
        return;
    }

    YASRaiseIfAUError(AudioDeviceStart(self.audioDevice.audioDeviceID, _ioProcID));
}

- (void)stop
{
    if (!_isRunning) {
        return;
    }

    _isRunning = NO;

    if (!_audioDevice || !_ioProcID) {
        return;
    }

    YASRaiseIfAUError(AudioDeviceStop(self.audioDevice.audioDeviceID, _ioProcID));
}

- (void)setAudioDevice:(YASAudioDevice *)audioDevice
{
    if (![self.audioDevice isEqualToAudioDevice:audioDevice]) {
        BOOL isRunning = _isRunning;

        [self uninitialize];

        if (_audioDevice) {
            [[NSNotificationCenter defaultCenter] removeObserver:self
                                                            name:YASAudioDeviceDidChangeNotification
                                                          object:_audioDevice];
        }

        YASRelease(_audioDevice);
        _audioDevice = YASRetain(audioDevice);

        if (audioDevice) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(audioDeviceDidChange:)
                                                         name:YASAudioDeviceDidChangeNotification
                                                       object:audioDevice];
        }

        [self initialize];

        if (isRunning) {
            [self start];
        }
    }
}

#pragma mark Notification

- (void)audioHardwareDidChange:(NSNotification *)notification
{
    if (_audioDevice && ![YASAudioDevice deviceForID:_audioDevice.audioDeviceID]) {
        self.audioDevice = nil;
    }
}

- (void)audioDeviceDidChange:(NSNotification *)notification
{
    [self _updateCore];
}

#pragma mark Private

- (void)_updateCore
{
    self.core = nil;

    if (!_audioDevice || !_ioProcID) {
        return;
    }

    YASAudioDeviceIOCore *core = [[YASAudioDeviceIOCore alloc] init];
    YASAudioFormat *inputFormat = self.audioDevice.inputFormat;
    YASAudioFormat *outputFormat = self.audioDevice.outputFormat;

    if (inputFormat) {
        YASAudioData *inputData =
            [[YASAudioData alloc] initWithFormat:inputFormat frameCapacity:YASAudioDeviceIOFrameCapacity];
        core.inputData = inputData;
        YASRelease(inputData);
    }

    if (outputFormat) {
        YASAudioData *outputData =
            [[YASAudioData alloc] initWithFormat:outputFormat frameCapacity:YASAudioDeviceIOFrameCapacity];
        core.outputData = outputData;
        YASRelease(outputData);
    }

    self.core = core;
    YASRelease(core);
}

#pragma mark Render thread

- (YASAudioData *)inputDataOnRender
{
    return self.inputData;
}

- (AVAudioTime *)inputTimeOnRender
{
    return self.inputTime;
}

@end

#endif
