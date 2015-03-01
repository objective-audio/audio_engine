//
//  YASAudioGraph.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioGraph.h"
#import "YASAudioUnit.h"
#import "YASMacros.h"
#import "NSArray+YASAudio.h"
#import "NSDictionary+YASAudio.h"
#import "NSException+YASAudio.h"
#import <AVFoundation/AVFoundation.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#elif TARGET_OS_MAC
#import "YASAudioDeviceIO.h"
#endif

static NSMapTable *_graphs = nil;
static BOOL _interrupting = NO;

@interface YASAudioGraph()

@property (nonatomic, copy, readonly) NSNumber *key;

@end

@implementation YASAudioGraph {
    NSMutableDictionary *_units;
    NSMutableSet *_ioUnits;
    
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    NSMutableSet *_deviceIOs;
#endif
}

#pragma mark - Global

+ (void)initialize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _graphs = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsWeakMemory capacity:2];
        
#if TARGET_OS_IPHONE
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(_didBecomeActiveNotification:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [center addObserver:self selector:@selector(_interruptionNotification:) name:AVAudioSessionInterruptionNotification object:nil];
#endif
    });
}

+ (BOOL)isInterrupting
{
    return _interrupting;
}

+ (void)_startAllGraphs
{
#if TARGET_OS_IPHONE
    NSError *error = nil;
    if (![[AVAudioSession sharedInstance] setActive:YES error:&error]) {
        YASRaiseIfError(error);
        return;
    }
#endif
    
    @synchronized(self) {
        for (YASAudioGraph *graph in _graphs.objectEnumerator) {
            if (graph.running) [graph _startAllIOs];
        }
    }
    
    _interrupting = NO;
}

+ (void)_stopAllGraphs
{
    @synchronized(self) {
        for (YASAudioGraph *graph in _graphs.objectEnumerator) {
            [graph _stopAllIOs];
        }
    }
}

+ (void)_addGraph:(YASAudioGraph *)graph
{
    if (!graph || !graph.key) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil", __PRETTY_FUNCTION__]));
        return;
    }
    
    @synchronized(self) {
        [_graphs setObject:graph forKey:graph.key];
    }
}

+ (void)_removeGraph:(YASAudioGraph *)graph
{
    if (!graph || !graph.key) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil", __PRETTY_FUNCTION__]));
        return;
    }
    
    @synchronized(self) {
        [_graphs removeObjectForKey:graph.key];
    }
}

+ (YASAudioGraph *)_graphForKey:(NSNumber *)key
{
    if (!key) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil", __PRETTY_FUNCTION__]));
        return nil;
    }
    
    @synchronized(self) {
        YASAudioGraph *graph = [_graphs objectForKey:key];
        return YASRetainAndAutorelease(graph);
    }
}

- (NSNumber *)_nextUnitKey
{
    @synchronized(self) {
        return [_units yas_emptyNumberKeyInLength:UINT16_MAX + 1];
    }
}

#pragma mark - Global / Render

+ (void)audioUnitRender:(YASAudioUnitRenderParameters *)renderParameters graphKey:(NSNumber *)graphKey unitKey:(NSNumber *)unitKey
{
    YASRaiseIfMainThread;
    
    YASAudioGraph *graph = [YASAudioGraph _graphForKey:graphKey];
    if (graph) {
        YASAudioUnit *unit = [graph _unitForKey:unitKey];
        if (unit) {
            [unit renderCallbackBlock:renderParameters];
        }
    }
}

#pragma mark - Setup

- (instancetype)init
{
    self = [super init];
    if (self) {
        _units = [[NSMutableDictionary alloc] init];
        _ioUnits = [[NSMutableSet alloc] init];
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
        _deviceIOs = [[NSMutableSet alloc] init];
#endif
        _running = NO;
        
        @synchronized(self.class) {
            NSNumber *key = [_graphs.keyEnumerator.allObjects yas_emptyNumberInLength:UINT8_MAX + 1];
            if (key && ![YASAudioGraph _graphForKey:key]) {
                _key = [key copy];
            }
            if (_key) {
                [YASAudioGraph _addGraph:self];
            } else {
                YASRelease(self);
                self = nil;
            }
        }
    }
    return self;
}

- (void)dealloc
{
    [self _stopAllIOs];
    [YASAudioGraph _removeGraph:self];
    [self removeAllUnits];
    
    YASRelease(_key);
    YASRelease(_units);
    YASRelease(_ioUnits);
    
    _key = nil;
    _units = nil;
    _ioUnits = nil;
    
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    YASRelease(_deviceIOs);
    _deviceIOs = nil;
#endif
    
    YASSuperDealloc;
}

#pragma mark - Public

- (void)setRunning:(BOOL)running
{
    if (_running != running) {
        _running = running;
        if (_running) {
            [self _startAllIOs];
        } else {
            [self _stopAllIOs];
        }
    }
}

- (YASAudioUnit *)addAudioUnitWithAudioComponentDescription:(const AudioComponentDescription *)acd prepareBlock:(void (^)(YASAudioUnit *))prepareBlock
{
    YASAudioUnit *unit = nil;
    
    unit = [[YASAudioUnit alloc] initWithGraph:self acd:acd];
    
    if (unit) {
        [self _addUnitToUnits:unit];
        YASRelease(unit);
        
        if (prepareBlock) {
            prepareBlock(unit);
        }
        
        [unit initialize];
        
        if (acd->componentType == kAudioUnitType_Output && self.isRunning && !self.class.isInterrupting) {
            [unit start];
        }
    }
    
    return unit;
}

- (YASAudioUnit *)addAudioUnitWithType:(OSType)type subType:(OSType)subType prepareBlock:(void (^)(YASAudioUnit *))prepareBlock
{
    const AudioComponentDescription acd = {
        .componentType = type,
        .componentSubType = subType,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        .componentFlags = 0,
        .componentFlagsMask = 0,
    };
    
    return [self addAudioUnitWithAudioComponentDescription:&acd prepareBlock:prepareBlock];
}

- (void)removeAudioUnit:(YASAudioUnit *)unit
{
    if (!unit || !unit.key) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - unit or unit.key is nil.", __PRETTY_FUNCTION__]));
    }
    
    [unit uninitialize];
    
    @synchronized(self) {
        [_units removeObjectForKey:unit.key];
        [_ioUnits removeObject:unit];
        unit.key = nil;
    }
}

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

- (YASAudioDeviceIO *)addAudioDeviceIOWithAudioDevice:(YASAudioDevice *)audioDevice
{
    YASAudioDeviceIO *deviceIO = [[YASAudioDeviceIO alloc] initWithGraph:self];
    
    if (deviceIO) {
        deviceIO.audioDevice = audioDevice;
        @synchronized(self) {
            [_deviceIOs addObject:deviceIO];
        }
        YASRelease(deviceIO);
    }
    
    if (self.isRunning && !self.class.isInterrupting) {
        [deviceIO start];
    }
    
    return deviceIO;
}

- (void)removeAudioDeviceIO:(YASAudioDeviceIO *)audioDeviceIO
{
    if (!audioDeviceIO) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil.", __PRETTY_FUNCTION__]));
        return;
    }
    
    [audioDeviceIO stop];
    
    @synchronized(self) {
        [_deviceIOs removeObject:audioDeviceIO];
    }
}

#endif

- (void)removeAllUnits
{
    @synchronized(self) {
        NSDictionary *tmpDict = [_units copy];
        for (YASAudioUnit *unit in tmpDict.objectEnumerator) {
            [self removeAudioUnit:unit];
        }
        YASRelease(tmpDict);
        
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
        NSSet *tmpSet = [_deviceIOs copy];
        for (YASAudioDeviceIO *deviceIO in tmpSet) {
            [self removeAudioDeviceIO:deviceIO];
        }
        YASRelease(tmpSet);
#endif
    }
}

#pragma mark - Private

- (YASAudioUnit *)_unitForKey:(NSNumber *)key
{
    if (!key) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil.", __PRETTY_FUNCTION__]));
        return nil;
    }
    
    @synchronized(self) {
        YASAudioUnit *unit = [_units objectForKey:key];
        return YASRetainAndAutorelease(unit);
    }
}

- (void)_addUnitToUnits:(YASAudioUnit *)unit
{
    if (!unit) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil.", __PRETTY_FUNCTION__]));
        return;
    }
    
    if (unit.key) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - unit.key is not nil.", __PRETTY_FUNCTION__]));
    }
    
    @synchronized(self) {
        NSNumber *key = [self _nextUnitKey];
        if (key) {
            unit.key = key;
            _units[key] = unit;
            if (unit.isOutputUnit) {
                [_ioUnits addObject:unit];
            }
        }
    }
}

- (void)_startAllIOs
{
    for (YASAudioUnit *ioUnit in _ioUnits) {
        [ioUnit start];
    }
    
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    for (YASAudioDeviceIO *deviceIO in _deviceIOs) {
        [deviceIO start];
    }
#endif
}

- (void)_stopAllIOs
{
    for (YASAudioUnit *ioUnit in _ioUnits) {
        [ioUnit stop];
    }
    
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    for (YASAudioDeviceIO *deviceIO in _deviceIOs) {
        [deviceIO stop];
    }
#endif
}

#pragma mark - AudioSession

#if TARGET_OS_IPHONE

+ (void)_didBecomeActiveNotification:(NSNotification *)notification
{
    [self _startAllGraphs];
}

+ (void)_interruptionNotification:(NSNotification *)notification
{
    NSDictionary *info = notification.userInfo;
    NSNumber *typeNum = [info valueForKey:AVAudioSessionInterruptionTypeKey];
    AVAudioSessionInterruptionType interruptionType = [typeNum unsignedIntegerValue];
    
    if (interruptionType == AVAudioSessionInterruptionTypeBegan) {
        _interrupting = YES;
        [self _stopAllGraphs];
    } else if (interruptionType == AVAudioSessionInterruptionTypeEnded) {
        if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
            [self _startAllGraphs];
            _interrupting = NO;
        }
    }
}

#endif

@end
