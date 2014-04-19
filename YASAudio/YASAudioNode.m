
/**
 *
 *  YASAudioNode.m
 *
 *  Created by Yuki Yasoshima
 *
 */

#import "YASAudioNode.h"
#import "YASAudioGraph.h"
#import "YASAudioNodeRenderInfo.h"
#import "YASAudioUtilities.h"

@interface YASAudioNode()
@property (nonatomic, strong) NSArray *outputChannelMapArray;
@end

@implementation YASAudioNode

#pragma mark - コールバック

static OSStatus CommonRenderCallback(void *							inRefCon,
                                     AudioUnitRenderActionFlags *	ioActionFlags,
                                     const AudioTimeStamp *			inTimeStamp,
                                     UInt32							inBusNumber,
                                     UInt32							inNumberFrames,
                                     AudioBufferList *				ioData,
                                     enum YASAudioNodeRenderType      renderType)
{
    OSStatus err = noErr;
    
    @autoreleasepool {
        
        YASAudioNodeRenderInfo *renderInfo = (__bridge YASAudioNodeRenderInfo *)inRefCon;
        
        renderInfo.ioActionFlags = ioActionFlags;
        renderInfo.inTimeStamp = inTimeStamp;
        renderInfo.inBusNumber = inBusNumber;
        renderInfo.inNumberFrames = inNumberFrames;
        renderInfo.ioData = ioData;
        renderInfo.renderType = renderType;
        
        [YASAudioGraph audioNodeRender:renderInfo];
        
    }
    
    return err;
}

static OSStatus RenderCallback(void *							inRefCon,
                                     AudioUnitRenderActionFlags *	ioActionFlags,
                                     const AudioTimeStamp *			inTimeStamp,
                                     UInt32							inBusNumber,
                                     UInt32							inNumberFrames,
                                     AudioBufferList *				ioData)
{
    return CommonRenderCallback(inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData, YASAudioNodeRenderTypeNormal);
}

static OSStatus NotifyRenderCallback(void *							inRefCon,
                                     AudioUnitRenderActionFlags *	ioActionFlags,
                                     const AudioTimeStamp *			inTimeStamp,
                                     UInt32							inBusNumber,
                                     UInt32							inNumberFrames,
                                     AudioBufferList *				ioData)
{
    return CommonRenderCallback(inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData, YASAudioNodeRenderTypeNotify);
}

- (void)render:(YASAudioNodeRenderInfo *)renderInfo
{
    YASAudioNodeRenderCallbackBlock block = NULL;
    
    switch (renderInfo.renderType) {
        case YASAudioNodeRenderTypeNormal:
            block = self.renderCallbackBlock;
            break;
        case YASAudioNodeRenderTypeNotify:
            block = self.notifyRenderCallbackBlock;
            break;
            
        default:
            break;
    }
    
    if (block) {
        block(renderInfo);
    }
}

#pragma mark - メモリ管理

+ (NSString *)uniqueStringWithGraph:(YASAudioGraph *)graph
{
    NSString *result = nil;
    
    while (YES) {
        
        result = [[NSProcessInfo processInfo] globallyUniqueString];
        
        if (![YASAudioGraph containsAudioNodeRenderInfoWithGraphKey:graph.identifier nodeKey:result]) {
            break;
        }
        
    }
    
    return result;
}

- (id)initWithGraph:(YASAudioGraph *)graph acd:(AudioComponentDescription *)acd
{
    self = [super init];
    if (self) {
        
        _graph = graph;
        _identifier = [YASAudioNode uniqueStringWithGraph:graph];
        YASAudioRetain(_identifier);
        
        OSStatus err = noErr;
        err = AUGraphAddNode(graph.auGraph, acd, &_node);
        YAS_Require_NoErr(err, bail);
        
        err = AUGraphNodeInfo(graph.auGraph, _node, NULL, &_audioUnit);
        YAS_Require_NoErr(err, bail);
        
    bail:
        if (err) {
            YASAudioRelease(self);
            self = nil;
        }
    }
    return self;
}

- (void)remove
{
    OSStatus err = noErr;
    if (_node && _graph) {
        err = AUGraphRemoveNode(_graph.auGraph, _node);
    }
    _node = 0;
    YAS_Verify_NoErr(err);
}

- (void)_releaseVariables
{
    YASAudioRelease(_renderCallbackBlock);
    YASAudioRelease(_notifyRenderCallbackBlock);
    YASAudioRelease(_outputChannelMapArray);
    YASAudioRelease(_identifier);
    _renderCallbackBlock = nil;
    _notifyRenderCallbackBlock = nil;
    _outputChannelMapArray = nil;
    _identifier = nil;
}

- (void)dealloc {
    [self remove];
    [self _releaseVariables];
    YASAudioSuperDealloc;
}

#pragma mark - AudioUnit全般

- (void)setRenderCallback:(UInt32)inputNumber
{
    OSStatus err = noErr;
    
    YASAudioNodeRenderInfo *renderInfo = [YASAudioGraph audioNodeRenderInfoWithGraphKey:_graph.identifier nodeKey:_identifier];
    
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = RenderCallback;
    callbackStruct.inputProcRefCon = (__bridge void *)(renderInfo);
    err = AUGraphSetNodeInputCallback(_graph.auGraph, _node, inputNumber, &callbackStruct);
    YAS_Verify_NoErr(err);
}

- (void)removeRenderCallback:(UInt32)inputNumber
{
    OSStatus err = noErr;
    
    err = AUGraphDisconnectNodeInput(_graph.auGraph, _node, inputNumber);
    YAS_Verify_NoErr(err);
}

- (void)addRenderNotify
{
    OSStatus err = noErr;
    
    YASAudioNodeRenderInfo *renderInfo = [YASAudioGraph audioNodeRenderInfoWithGraphKey:_graph.identifier nodeKey:_identifier];
    
    err = AudioUnitAddRenderNotify(_audioUnit, NotifyRenderCallback, (__bridge void *)(renderInfo));
    YAS_Require_NoErr(err, bail);
    
bail:
    {
    
    }
}

- (void)removeRenderNotify
{
    OSStatus err = noErr;
    
    err = AudioUnitRemoveRenderNotify(_audioUnit, NotifyRenderCallback, (__bridge void *)(self));
    YAS_Require_NoErr(err, bail);
    
bail:
    {
    
    }
}

- (void)setInputFormat:(AudioStreamBasicDescription *)asbd busNumber:(UInt32)bus
{
    OSStatus err = noErr;
    
    err = AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, bus, asbd, sizeof(AudioStreamBasicDescription));
    YAS_Require_NoErr(err, bail);
    
bail:
    {
    
    }
}

- (void)setOutputFormat:(AudioStreamBasicDescription *)asbd busNumber:(UInt32)bus
{
    OSStatus err = noErr;
    
    err = AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, bus, asbd, sizeof(AudioStreamBasicDescription));
    YAS_Require_NoErr(err, bail);
    
bail:
    {
    
    }
}

- (void)getInputFormat:(AudioStreamBasicDescription *)asbd busNumber:(UInt32)bus
{
    OSStatus err = noErr;
    
    UInt32 size = sizeof(AudioStreamBasicDescription);
    err = AudioUnitGetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, bus, asbd, &size);
    YAS_Require_NoErr(err, bail);
    
bail:
    if (err) {
    
    }
}

- (void)getOutputFormat:(AudioStreamBasicDescription *)asbd busNumber:(UInt32)bus
{
    OSStatus err = noErr;
    
    UInt32 size = sizeof(AudioStreamBasicDescription);
    err = AudioUnitGetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, bus, asbd, &size);
    YAS_Require_NoErr(err, bail);
    
bail:
    if (err) {
    
    }
}

- (void)setMaximumFramesPerSlice:(UInt32)frames
{
    OSStatus err = noErr;
    
    UInt32 size = sizeof(UInt32);
    err = AudioUnitGetProperty(_audioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &frames, &size);
    YAS_Require_NoErr(err, bail);
    
bail:
    if (err) {
        
    }
}

- (void)setParameter:(AudioUnitParameterID)parameterID value:(AudioUnitParameterValue)val scope:(AudioUnitScope)scope element:(AudioUnitElement)element
{
    OSStatus err = noErr;
    
    err = AudioUnitSetParameter(_audioUnit, parameterID, scope, element, val, 0);
    YAS_Require_NoErr(err, bail);
    
bail:
    if (err) {
        
    }
}

- (void)setGlobalParameter:(AudioUnitParameterID)parameterID value:(AudioUnitParameterValue)val
{
    [self setParameter:parameterID value:val scope:kAudioUnitScope_Global element:0];
}

- (Float32)getParameter:(AudioUnitParameterID)parameterID scope:(AudioUnitScope)scope element:(AudioUnitElement)element
{
    Float32 result = 0;
    
    OSStatus err = noErr;
    
    err = AudioUnitGetParameter(_audioUnit, parameterID, scope, element, &result);
    YAS_Require_NoErr(err, bail);
    
    return result;
    
bail:
    if (err) {
        
    }
    
    return 0;
}

#pragma mark - ミキサー用

- (void)setInputElementCount:(UInt32)count
{
    OSStatus err = noErr;
    
    err = AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &count, sizeof(UInt32));
    YAS_Require_NoErr(err, bail);
    
bail:
    if (err) {
        
    }
}

@end




@implementation YASAudioIONode

static OSStatus InputRenderCallback(void *							inRefCon,
                                    AudioUnitRenderActionFlags *	ioActionFlags,
                                    const AudioTimeStamp *			inTimeStamp,
                                    UInt32							inBusNumber,
                                    UInt32							inNumberFrames,
                                    AudioBufferList *				ioData)
{
    return CommonRenderCallback(inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData, YASAudioNodeRenderTypeInput);
}

- (void)render:(YASAudioNodeRenderInfo *)renderInfo
{
    switch (renderInfo.renderType) {
            
        case YASAudioNodeRenderTypeInput:
        {
            YASAudioNodeRenderCallbackBlock block = NULL;
            block = self.inputRenderCallbackBlock;
            if (block) {
                block(renderInfo);
            }
        }
            break;
            
        default:
            [super render:renderInfo];
            break;
    }
}

- (void)_releaseVariables
{
    [super _releaseVariables];
    YASAudioRelease(_inputRenderCallbackBlock);
    _inputRenderCallbackBlock = NULL;
}

#pragma mark - RemoteIO用

- (BOOL)isEnableOutput
{
    OSStatus err = noErr;
    UInt32 enableIO = 0;
    UInt32 size = sizeof(UInt32);
    
    err = AudioUnitGetProperty(self.audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &enableIO, &size);
    YAS_Verify_NoErr(err);
    
    return enableIO;
}

- (BOOL)isEnableInput
{
    OSStatus err = noErr;
    UInt32 enableIO = 0;
    UInt32 size = sizeof(UInt32);
    
    err = AudioUnitGetProperty(self.audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &enableIO, &size);
    YAS_Verify_NoErr(err);
    
    return enableIO;
}

- (void)setEnableOutput:(BOOL)b
{
    if ([self isEnableOutput] == b) {
        return;
    }
    
    OSStatus err = noErr;
    UInt32 enableIO = b ? 1 : 0;
    
    err = AudioUnitSetProperty(self.audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &enableIO, sizeof(UInt32));
    YAS_Require_NoErr(err, bail);
    
bail:
    if (err) {
        
    }
}

- (void)setEnableInput:(BOOL)b
{
    if ([self isEnableInput] == b) {
        return;
    }
    
    OSStatus err = noErr;
    UInt32 enableIO = b ? 1 : 0;
    
    err = AudioUnitSetProperty(self.audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &enableIO, sizeof(UInt32));
    YAS_Require_NoErr(err, bail);
    
bail:
    if (err) {
        
    }
}

- (void)setInputCallback
{
    OSStatus err = noErr;
    
    YASAudioNodeRenderInfo *renderInfo = [YASAudioGraph audioNodeRenderInfoWithGraphKey:self.graph.identifier nodeKey:self.identifier];
    
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = InputRenderCallback;
    callbackStruct.inputProcRefCon = (__bridge void *)(renderInfo);
    
    err = AudioUnitSetProperty(self.audioUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 0, &callbackStruct, sizeof(AURenderCallbackStruct));
    YAS_Require_NoErr(err, bail);
    
bail:
    if (err) {
        
    }
}

- (void)removeInputCallback
{
    OSStatus err = noErr;
    
    err = AudioUnitSetProperty(self.audioUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 0, NULL, sizeof(AURenderCallbackStruct));
    YAS_Require_NoErr(err, bail);
    
bail:
    if (err) {
        
    }
}

- (NSArray *)outputChannelMap
{
    return self.outputChannelMapArray;
}

- (void)setOutputChannelMap:(NSArray *)mapArray
{
    if (!mapArray || mapArray.count == 0) {
        return;
    }
    
    UInt32 count = (UInt32)mapArray.count;
    UInt32 *map = calloc(count, sizeof(UInt32));
    for (NSInteger i = 0; i < count; i++) {
        map[i] = (UInt32)[mapArray[i] integerValue];
    }
    
    [self _setOutputChannelMap:map count:count];
    
    free(map);
    
    self.outputChannelMapArray = mapArray;
}

- (void)_setOutputChannelMap:(UInt32 *)map count:(UInt32)count
{
    OSStatus err = noErr;
    
    UInt32 size = count * sizeof(UInt32);
    err = AudioUnitSetProperty(self.audioUnit, kAudioOutputUnitProperty_ChannelMap, kAudioUnitScope_Output, 0, map, size);
    YAS_Require_NoErr(err, bail);
    
    return;
    
bail:
    if (err) {
        NSLog(@"err = %d", (int)err);
    }
}

@end
