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
#endif

static NSMapTable *_graphs = nil;
static BOOL _interrupting = NO;

@interface YASAudioGraph()

@property (nonatomic, copy, readonly) NSNumber *key;

@end

@implementation YASAudioGraph {
    NSMutableDictionary *_units;
    NSMutableSet *_ioUnits;
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
    
    if (acd->componentType == kAudioUnitType_Output) {
        unit = [[YASAudioIOUnit alloc] initWithGraph:self acd:acd];
    } else {
        unit = [[YASAudioUnit alloc] initWithGraph:self acd:acd];
    }
    
    if (unit) {
        [self _addUnitToUnits:unit];
        YASRelease(unit);
        
        if (prepareBlock) {
            prepareBlock(unit);
        }
        
        [unit initialize];
        
        if ([unit isKindOfClass:[YASAudioIOUnit class]] && self.isRunning && !self.class.isInterrupting) {
            [(YASAudioIOUnit *)unit start];
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

- (void)removeAllUnits
{
    @synchronized(self) {
        NSDictionary *tmpDict = [_units copy];
        for (YASAudioUnit *unit in tmpDict.objectEnumerator) {
            [self removeAudioUnit:unit];
        }
        YASRelease(tmpDict);
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
            if ([unit isKindOfClass:[YASAudioIOUnit class]]) {
                [_ioUnits addObject:unit];
            }
        }
    }
}

- (void)_startAllIOs
{
    for (YASAudioIOUnit *ioUnit in _ioUnits) {
        [ioUnit start];
    }
}

- (void)_stopAllIOs
{
    for (YASAudioIOUnit *ioUnit in _ioUnits) {
        [ioUnit stop];
    }
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
