//
//  YASAudioUnit.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioUnit.h"
#import "YASAudioGraph.h"
#import "YASAudioUnitParameter.h"
#import "YASMacros.h"
#import "YASAudioUtility.h"
#import "NSException+YASAudio.h"

#if TARGET_OS_IPHONE
OSType const YASAudioUnitSubType_DefaultIO = kAudioUnitSubType_RemoteIO;
#elif TARGET_OS_MAC
OSType const YASAudioUnitSubType_DefaultIO = kAudioUnitSubType_HALOutput;
#endif

#pragma mark - C Functions

static unsigned long PackRenderID(UInt8 graphID, UInt16 unitID)
{
    return (graphID & 0xF) + ((unitID & 0xFF) << 8);
}

static void UnpackRenderID(unsigned long number, UInt8 *graphID, UInt16 *unitID)
{
    *graphID = number & 0xF;
    *unitID = (number >> 8) & 0xFF;
}

static OSStatus CommonRenderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                                     const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames,
                                     AudioBufferList *ioData, YASAudioUnitRenderType renderType)
{
    @autoreleasepool
    {
        UInt8 graphID;
        UInt16 unitID;
        unsigned long renderID = (unsigned long)inRefCon;
        UnpackRenderID(renderID, &graphID, &unitID);

        YASAudioUnitRenderParameters renderParameters = {
            .inRenderType = renderType,
            .ioActionFlags = ioActionFlags,
            .ioTimeStamp = inTimeStamp,
            .inBusNumber = inBusNumber,
            .inNumberFrames = inNumberFrames,
            .ioData = ioData,
        };

        [YASAudioGraph audioUnitRender:&renderParameters graphKey:@(graphID) unitKey:@(unitID)];
    }

    return noErr;
}

static OSStatus RenderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames,
                               AudioBufferList *ioData)
{
    return CommonRenderCallback(inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData,
                                YASAudioUnitRenderTypeNormal);
}

static OSStatus ClearCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                              const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames,
                              AudioBufferList *ioData)
{
    if (ioData) {
        YASAudioClearAudioBufferList(ioData);
    }
    return noErr;
}

static OSStatus EmptyCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                              const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames,
                              AudioBufferList *ioData)
{
    return noErr;
}

static OSStatus NotifyRenderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                                     const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames,
                                     AudioBufferList *ioData)
{
    return CommonRenderCallback(inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData,
                                YASAudioUnitRenderTypeNotify);
}

static OSStatus InputRenderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                                    const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames,
                                    AudioBufferList *ioData)
{
    return CommonRenderCallback(inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData,
                                YASAudioUnitRenderTypeInput);
}

#pragma mark -
#pragma mark - YASAudioUnit

@interface YASAudioUnit ()

@property (nonatomic, copy) NSNumber *graphKey;
@property (nonatomic, copy) NSNumber *key;
@property (nonatomic, assign, getter=isInitialized) BOOL initialized;

@end

@implementation YASAudioUnit {
    AudioComponentDescription _acd;
    AudioUnit _audioUnitInstance;
}

#pragma mark Memory Management

- (instancetype)initWithAudioComponentDescription:(const AudioComponentDescription *)acd
{
    self = [super init];
    if (self) {
        _acd = *acd;
        [self _createAudioUnit:acd];
    }
    return self;
}

- (instancetype)initWithType:(const OSType)type subType:(const OSType)subType
{
    const AudioComponentDescription acd = {
        .componentType = type,
        .componentSubType = subType,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        .componentFlags = 0,
        .componentFlagsMask = 0,
    };

    return [self initWithAudioComponentDescription:&acd];
}

- (void)dealloc
{
    [self uninitialize];
    [self _disposeAudioUnit];

    YASRelease(_renderCallbackBlock);
    YASRelease(_notifyCallbackBlock);
    YASRelease(_inputCallbackBlock);
    YASRelease(_key);
    YASRelease(_graphKey);
    YASRelease(_name);

    _renderCallbackBlock = nil;
    _notifyCallbackBlock = nil;
    _inputCallbackBlock = nil;
    _key = nil;
    _graphKey = nil;
    _name = nil;

    YASSuperDealloc;
}

#pragma mark Accessor

- (OSType)type
{
    return _acd.componentType;
}

- (OSType)subType
{
    return _acd.componentSubType;
}

- (BOOL)isOutputUnit
{
    return _acd.componentType == kAudioUnitType_Output;
}

- (AudioUnit)audioUnitInstance
{
    return _audioUnitInstance;
}

- (void)setRenderCallback:(const UInt32)inputNumber
{
    NSNumber *graphKey = self.graphKey;
    NSNumber *unitKey = self.key;

    if (!graphKey || !unitKey) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - graph.key or unit.key is nil", __PRETTY_FUNCTION__]));
        return;
    }

    unsigned long renderID = PackRenderID(graphKey.unsignedCharValue, unitKey.unsignedShortValue);

    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = RenderCallback;
    callbackStruct.inputProcRefCon = (void *)renderID;
    YASRaiseIfAUError(AudioUnitSetProperty(_audioUnitInstance, kAudioUnitProperty_SetRenderCallback,
                                           kAudioUnitScope_Input, inputNumber, &callbackStruct,
                                           sizeof(AURenderCallbackStruct)));
}

- (void)removeRenderCallback:(const UInt32)inputNumber
{
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = ClearCallback;
    callbackStruct.inputProcRefCon = NULL;
    YASRaiseIfAUError(AudioUnitSetProperty(_audioUnitInstance, kAudioUnitProperty_SetRenderCallback,
                                           kAudioUnitScope_Input, inputNumber, &callbackStruct,
                                           sizeof(AURenderCallbackStruct)));
}

- (void)addRenderNotify
{
    NSNumber *graphKey = self.graphKey;
    NSNumber *unitKey = self.key;

    if (!graphKey || !unitKey) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - graph or unit key is nil", __PRETTY_FUNCTION__]));
        return;
    }

    unsigned long renderID = PackRenderID(graphKey.unsignedCharValue, unitKey.unsignedShortValue);

    YASRaiseIfAUError(AudioUnitAddRenderNotify(_audioUnitInstance, NotifyRenderCallback, (void *)renderID));
}

- (void)removeRenderNotify
{
    YASRaiseIfAUError(AudioUnitRemoveRenderNotify(_audioUnitInstance, NotifyRenderCallback, NULL));
}

- (void)setPropertyData:(NSData *)data
             propertyID:(AudioUnitPropertyID)propertyID
                  scope:(AudioUnitScope)scope
                element:(AudioUnitElement)element
{
    if (data.length == 0) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil.", __PRETTY_FUNCTION__]));
    }

    const UInt32 size = (UInt32)data.length;
    YASRaiseIfAUError(AudioUnitSetProperty(_audioUnitInstance, propertyID, scope, element, data.bytes, size));
}

- (NSData *)propertyDataWithPropertyID:(AudioUnitPropertyID)propertyID
                                 scope:(AudioUnitScope)scope
                               element:(AudioUnitElement)element
{
    NSMutableData *data = nil;

    UInt32 size = 0;
    YASRaiseIfAUError(AudioUnitGetPropertyInfo(_audioUnitInstance, propertyID, scope, element, &size, NULL));

    if (size > 0) {
        data = [NSMutableData dataWithLength:size];
        YASRaiseIfAUError(
            AudioUnitGetProperty(_audioUnitInstance, propertyID, scope, element, data.mutableBytes, &size));
    }

    return data;
}

- (void)setInputFormat:(const AudioStreamBasicDescription *)asbd busNumber:(const UInt32)bus
{
    if (!asbd) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil.", __PRETTY_FUNCTION__]));
    }

    YASRaiseIfAUError(AudioUnitSetProperty(_audioUnitInstance, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input,
                                           bus, asbd, sizeof(AudioStreamBasicDescription)));
}

- (void)setOutputFormat:(const AudioStreamBasicDescription *)asbd busNumber:(const UInt32)bus
{
    if (!asbd) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil.", __PRETTY_FUNCTION__]));
    }

    YASRaiseIfAUError(AudioUnitSetProperty(_audioUnitInstance, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output,
                                           bus, asbd, sizeof(AudioStreamBasicDescription)));
}

- (void)getInputFormat:(AudioStreamBasicDescription *)asbd busNumber:(const UInt32)bus
{
    if (!asbd) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil.", __PRETTY_FUNCTION__]));
    }

    UInt32 size = sizeof(AudioStreamBasicDescription);
    YASRaiseIfAUError(AudioUnitGetProperty(_audioUnitInstance, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input,
                                           bus, asbd, &size));
}

- (void)getOutputFormat:(AudioStreamBasicDescription *)asbd busNumber:(const UInt32)bus
{
    if (!asbd) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil.", __PRETTY_FUNCTION__]));
    }

    UInt32 size = sizeof(AudioStreamBasicDescription);
    YASRaiseIfAUError(AudioUnitGetProperty(_audioUnitInstance, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output,
                                           bus, asbd, &size));
}

- (void)setMaximumFramesPerSlice:(const UInt32)frames
{
    YASRaiseIfAUError(AudioUnitSetProperty(_audioUnitInstance, kAudioUnitProperty_MaximumFramesPerSlice,
                                           kAudioUnitScope_Global, 0, &frames, sizeof(UInt32)));
}

- (UInt32)maximumFramesPerSlice
{
    UInt32 frames = 0;
    UInt32 size = sizeof(UInt32);
    YASRaiseIfAUError(AudioUnitGetProperty(_audioUnitInstance, kAudioUnitProperty_MaximumFramesPerSlice,
                                           kAudioUnitScope_Global, 0, &frames, &size));
    return frames;
}

- (void)setParameter:(const AudioUnitParameterID)parameterID
               value:(const AudioUnitParameterValue)val
               scope:(const AudioUnitScope)scope
             element:(const AudioUnitElement)element
{
    YASRaiseIfAUError(AudioUnitSetParameter(_audioUnitInstance, parameterID, scope, element, val, 0));
}

- (AudioUnitParameterValue)getParameter:(const AudioUnitParameterID)parameterID
                                  scope:(const AudioUnitScope)scope
                                element:(const AudioUnitElement)element
{
    AudioUnitParameterValue result = 0;
    YASRaiseIfAUError(AudioUnitGetParameter(_audioUnitInstance, parameterID, scope, element, &result));
    return result;
}

- (NSDictionary *)getParameterInfosWithScope:(const AudioUnitScope)scope
{
    NSData *propertyData = [self propertyDataWithPropertyID:kAudioUnitProperty_ParameterList scope:scope element:0];

    if (propertyData.length > 0) {
        NSInteger count = propertyData.length / sizeof(AudioUnitParameterID);
        if (count > 0) {
            const AudioUnitParameterID *ids = propertyData.bytes;
            NSMutableDictionary *infos = [[NSMutableDictionary alloc] initWithCapacity:count];
            for (NSInteger i = 0; i < count; i++) {
                YASAudioUnitParameter *info = [self parameterInfo:ids[i] scope:scope];
                if (info) {
                    infos[@(info.parameterID)] = info;
                }
            }
            NSDictionary *resultInfos = YASAutorelease([infos copy]);
            YASRelease(infos);
            return resultInfos;
        }
    }

    return nil;
}

- (YASAudioUnitParameter *)parameterInfo:(const AudioUnitParameterID)parameterID scope:(const AudioUnitScope)scope
{
    AudioUnitParameterInfo info = {0};
    UInt32 size = sizeof(AudioUnitParameterInfo);

    OSStatus err = noErr;
    YASRaiseIfAUError(err = AudioUnitGetProperty(_audioUnitInstance, kAudioUnitProperty_ParameterInfo, scope,
                                                 parameterID, &info, &size));
    if (err != noErr) {
        return nil;
    }

    YASAudioUnitParameter *parameterInfo =
        [[YASAudioUnitParameter alloc] initWithAudioUnitParameterInfo:&info parameterID:parameterID scope:scope];

    if (info.flags & kAudioUnitParameterFlag_CFNameRelease) {
        if (info.flags & kAudioUnitParameterFlag_HasCFNameString && info.cfNameString != NULL) {
            CFRelease(info.cfNameString);
        }
        if (info.unit == kAudioUnitParameterUnit_CustomUnit && info.unitName != NULL) {
            CFRelease(info.unitName);
        }
    }

    return YASAutorelease(parameterInfo);
}

#pragma mark for Mixer

- (void)setElementCount:(const UInt32)count scope:(const AudioUnitScope)scope
{
    YASRaiseIfAUError(
        AudioUnitSetProperty(_audioUnitInstance, kAudioUnitProperty_ElementCount, scope, 0, &count, sizeof(UInt32)));
}

- (UInt32)elementCountForScope:(const AudioUnitScope)scope
{
    UInt32 count = 0;
    UInt32 size = sizeof(UInt32);
    YASRaiseIfAUError(
        AudioUnitGetProperty(_audioUnitInstance, kAudioUnitProperty_ElementCount, scope, 0, &count, &size));

    return count;
}

#pragma mark for IO

- (BOOL)isEnableOutput
{
    UInt32 enableIO = 0;
    UInt32 size = sizeof(UInt32);
    YASRaiseIfAUError(AudioUnitGetProperty(self.audioUnitInstance, kAudioOutputUnitProperty_EnableIO,
                                           kAudioUnitScope_Output, 0, &enableIO, &size));

    return enableIO;
}

- (BOOL)isEnableInput
{
    UInt32 enableIO = 0;
    UInt32 size = sizeof(UInt32);
    YASRaiseIfAUError(AudioUnitGetProperty(self.audioUnitInstance, kAudioOutputUnitProperty_EnableIO,
                                           kAudioUnitScope_Input, 1, &enableIO, &size));

    return enableIO;
}

- (void)setEnableOutput:(BOOL)b
{
    if (!self.hasOutput) {
        return;
    }

    if (self.isEnableOutput == b) {
        return;
    }

    if (self.isInitialized) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - AudioUnit is initialized.", __PRETTY_FUNCTION__]));
        return;
    }

    UInt32 enableIO = b ? 1 : 0;
    YASRaiseIfAUError(AudioUnitSetProperty(self.audioUnitInstance, kAudioOutputUnitProperty_EnableIO,
                                           kAudioUnitScope_Output, 0, &enableIO, sizeof(UInt32)));
}

- (void)setEnableInput:(BOOL)b
{
    if (!self.hasInput) {
        return;
    }

    if (self.isEnableInput == b) {
        return;
    }

    if (self.isInitialized) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - AudioUnit is initialized.", __PRETTY_FUNCTION__]));
        return;
    }

    UInt32 enableIO = b ? 1 : 0;
    YASRaiseIfAUError(AudioUnitSetProperty(self.audioUnitInstance, kAudioOutputUnitProperty_EnableIO,
                                           kAudioUnitScope_Input, 1, &enableIO, sizeof(UInt32)));
}

- (BOOL)hasOutput
{
#if TARGET_OS_IPHONE
    return YES;
#elif TARGET_OS_MAC
    UInt32 hasIO = 0;
    UInt32 size = sizeof(UInt32);
    YASRaiseIfAUError(AudioUnitGetProperty(self.audioUnitInstance, kAudioOutputUnitProperty_HasIO,
                                           kAudioUnitScope_Output, 0, &hasIO, &size));
    return hasIO;
#endif
}

- (BOOL)hasInput
{
#if TARGET_IPHONE_SIMULATOR
    return YES;
#elif TARGET_OS_IPHONE
    return [AVAudioSession sharedInstance].isInputAvailable;
#elif TARGET_OS_MAC
    UInt32 hasIO = 0;
    UInt32 size = sizeof(UInt32);
    YASRaiseIfAUError(AudioUnitGetProperty(self.audioUnitInstance, kAudioOutputUnitProperty_HasIO,
                                           kAudioUnitScope_Input, 1, &hasIO, &size));
    return hasIO;
#endif
}

- (BOOL)isRunning
{
    UInt32 isRunning = 0;
    UInt32 size = sizeof(UInt32);
    YASRaiseIfAUError(AudioUnitGetProperty(self.audioUnitInstance, kAudioOutputUnitProperty_IsRunning,
                                           kAudioUnitScope_Global, 0, &isRunning, &size));

    return isRunning != 0;
}

- (void)setInputCallback
{
    if (_acd.componentType != kAudioUnitType_Output) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Not Output Unit", __PRETTY_FUNCTION__]));
        return;
    }

    NSNumber *graphKey = self.graphKey;
    NSNumber *unitKey = self.key;

    if (!graphKey || !unitKey) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - graph.key or unit.key is nil", __PRETTY_FUNCTION__]));
        return;
    }

    unsigned long renderID = PackRenderID(graphKey.unsignedCharValue, unitKey.unsignedShortValue);

    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = InputRenderCallback;
    callbackStruct.inputProcRefCon = (void *)renderID;

    YASRaiseIfAUError(AudioUnitSetProperty(self.audioUnitInstance, kAudioOutputUnitProperty_SetInputCallback,
                                           kAudioUnitScope_Global, 0, &callbackStruct, sizeof(AURenderCallbackStruct)));
}

- (void)removeInputCallback
{
    if (_acd.componentType != kAudioUnitType_Output) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Not Output Unit", __PRETTY_FUNCTION__]));
        return;
    }

    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = EmptyCallback;
    callbackStruct.inputProcRefCon = NULL;

    YASRaiseIfAUError(AudioUnitSetProperty(self.audioUnitInstance, kAudioOutputUnitProperty_SetInputCallback,
                                           kAudioUnitScope_Global, 0, &callbackStruct, sizeof(AURenderCallbackStruct)));
}

- (void)setChannelMap:(NSData *)mapData scope:(AudioUnitScope)scope
{
    if (_acd.componentType != kAudioUnitType_Output) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Not Output Unit", __PRETTY_FUNCTION__]));
        return;
    }

    const UInt32 *map = mapData.bytes;
    UInt32 size = (UInt32)mapData.length;
    YASRaiseIfAUError(
        AudioUnitSetProperty(self.audioUnitInstance, kAudioOutputUnitProperty_ChannelMap, scope, 0, map, size));
}

- (NSData *)channelMapForScope:(AudioUnitScope)scope
{
    if (_acd.componentType != kAudioUnitType_Output) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Not Output Unit", __PRETTY_FUNCTION__]));
        return nil;
    }

    AudioUnit audioUnit = self.audioUnitInstance;
    UInt32 size = 0;

    YASRaiseIfAUError(AudioUnitGetPropertyInfo(audioUnit, kAudioOutputUnitProperty_ChannelMap, scope, 0, &size, NULL));

    if (size > 0) {
        NSMutableData *mapData = [NSMutableData dataWithLength:size];
        UInt32 *map = mapData.mutableBytes;
        YASRaiseIfAUError(AudioUnitGetProperty(audioUnit, kAudioOutputUnitProperty_ChannelMap, scope, 0, map, &size));
        return mapData;
    } else {
        return nil;
    }
}

- (UInt32)channelMapCountForScope:(AudioUnitScope)scope
{
    if (_acd.componentType != kAudioUnitType_Output) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Not Output Unit", __PRETTY_FUNCTION__]));
        return 0;
    }

    UInt32 size = 0;

    YASRaiseIfAUError(
        AudioUnitGetPropertyInfo(self.audioUnitInstance, kAudioOutputUnitProperty_ChannelMap, scope, 0, &size, NULL));

    return size / sizeof(UInt32);
}

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
- (void)setCurrentDevice:(const AudioDeviceID)currentDevice
{
    YASRaiseIfAUError(AudioUnitSetProperty(self.audioUnitInstance, kAudioOutputUnitProperty_CurrentDevice,
                                           kAudioUnitScope_Global, 0, &currentDevice, sizeof(AudioDeviceID)));
}

- (AudioDeviceID)currentDevice
{
    AudioDeviceID currentDevice = 0;
    UInt32 size = sizeof(AudioDeviceID);

    YASRaiseIfAUError(AudioUnitGetProperty(self.audioUnitInstance, kAudioOutputUnitProperty_CurrentDevice,
                                           kAudioUnitScope_Global, 0, &currentDevice, &size));

    return currentDevice;
}
#endif

- (void)start
{
    if (_acd.componentType != kAudioUnitType_Output) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Not Output Unit", __PRETTY_FUNCTION__]));
        return;
    }

    if (!self.isRunning) {
        YASRaiseIfAUError(AudioOutputUnitStart(self.audioUnitInstance));
    }
}

- (void)stop
{
    if (_acd.componentType != kAudioUnitType_Output) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Not Output Unit", __PRETTY_FUNCTION__]));
        return;
    }

    if (self.isRunning) {
        YASRaiseIfAUError(AudioOutputUnitStop(self.audioUnitInstance));
    }
}

#pragma mark Setup Audio Unit

- (void)_createAudioUnit:(const AudioComponentDescription *)acd
{
    AudioComponent component = AudioComponentFindNext(NULL, acd);
    if (!component) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s Can't create audio component.", __PRETTY_FUNCTION__]));
    }

    CFStringRef nameRef = NULL;
    YASRaiseIfAUError(AudioComponentCopyName(component, &nameRef));
    _name = (__bridge NSString *)nameRef;

    YASRaiseIfAUError(AudioComponentInstanceNew(component, &_audioUnitInstance));
}

- (void)_disposeAudioUnit
{
    if (!_audioUnitInstance) {
        return;
    }

    YASRaiseIfAUError(AudioComponentInstanceDispose(_audioUnitInstance));

    _audioUnitInstance = NULL;
}

- (void)initialize
{
    if (_initialized) {
        return;
    }

    if (!_audioUnitInstance) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s AudioUnit is null.", __PRETTY_FUNCTION__]));
    }

    YASRaiseIfAUError(AudioUnitInitialize(_audioUnitInstance));

    _initialized = YES;
}

- (void)uninitialize
{
    if (!_initialized) {
        return;
    }

    if (!_audioUnitInstance) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s AudioUnit is null.", __PRETTY_FUNCTION__]));
    }

    YASRaiseIfAUError(AudioUnitUninitialize(_audioUnitInstance));

    _initialized = NO;
}

#pragma mark Render thread

- (void)renderCallbackBlock:(YASAudioUnitRenderParameters *)renderParameters
{
    YASRaiseIfMainThread;

    YASAudioUnitCallbackBlock block = NULL;

    switch (renderParameters->inRenderType) {
        case YASAudioUnitRenderTypeNormal:
            block = self.renderCallbackBlock;
            break;
        case YASAudioUnitRenderTypeNotify:
            block = self.notifyCallbackBlock;
            break;
        case YASAudioUnitRenderTypeInput:
            block = self.inputCallbackBlock;
            break;

        default:
            break;
    }

    if (block) {
        block(renderParameters);
    }
}

- (void)audioUnitRender:(YASAudioUnitRenderParameters *)renderParameters
{
    YASRaiseIfMainThread;

    YASRaiseIfAUError(AudioUnitRender(_audioUnitInstance, renderParameters->ioActionFlags,
                                      renderParameters->ioTimeStamp, renderParameters->inBusNumber,
                                      renderParameters->inNumberFrames, renderParameters->ioData));
}

@end
