//
//  YASAudioConnection.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioConnection.h"
#import "YASAudioNode.h"
#import "YASMacros.h"
#import "NSException+YASAudio.h"

@interface YASAudioConnection ()

@property (atomic, strong, readonly) YASAudioNode *sourceNode;
@property (atomic, strong, readonly) YASAudioNode *destinationNode;
@property (nonatomic, strong, readonly) YASAudioFormat *format;
@property (nonatomic, strong) YASWeakContainer *sourceNodeContainer;
@property (nonatomic, strong) YASWeakContainer *destinationNodeContainer;

@end

@implementation YASAudioConnection

- (instancetype)initWithSourceNode:(YASAudioNode *)sourceNode
                         sourceBus:(NSNumber *)sourceBus
                   destinationNode:(YASAudioNode *)destinationNode
                    destinationBus:(NSNumber *)destinationBus
                            format:(YASAudioFormat *)format
{
    self = [super init];
    if (self) {
        if (!sourceNode || !sourceBus || !destinationNode || !destinationBus || !format) {
            YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil.", __PRETTY_FUNCTION__]));
            YASRelease(self);
            return nil;
        }

        self.sourceNodeContainer = sourceNode.weakContainer;
        _sourceBus = YASRetain(sourceBus);
        self.destinationNodeContainer = destinationNode.weakContainer;
        _destinationBus = YASRetain(destinationBus);
        _format = YASRetain(format);
        [destinationNode addConnection:self];
        [sourceNode addConnection:self];
    }
    return self;
}

- (void)dealloc
{
    YASAudioNode *destinationNode = [self.destinationNodeContainer retainedObject];
    YASAudioNode *sourceNode = [self.sourceNodeContainer retainedObject];
    [destinationNode removeConnection:self];
    [sourceNode removeConnection:self];
    YASRelease(destinationNode);
    YASRelease(sourceNode);

    YASRelease(_sourceNodeContainer);
    YASRelease(_destinationNodeContainer);
    YASRelease(_sourceBus);
    YASRelease(_destinationBus);
    YASRelease(_format);

    _sourceNodeContainer = nil;
    _destinationNodeContainer = nil;
    _sourceBus = nil;
    _destinationBus = nil;
    _format = nil;

    YASSuperDealloc;
}

- (void)removeNodes
{
    @synchronized(self)
    {
        self.sourceNodeContainer = nil;
        self.destinationNodeContainer = nil;
    }
}

- (void)removeSourceNode
{
    @synchronized(self)
    {
        self.sourceNodeContainer = nil;
    }
}

- (void)removeDestinationNode
{
    @synchronized(self)
    {
        self.destinationNodeContainer = nil;
    }
}

- (YASAudioNode *)sourceNode
{
    @synchronized(self)
    {
        return [self.sourceNodeContainer autoreleasingObject];
    }
}

- (YASAudioNode *)destinationNode
{
    @synchronized(self)
    {
        return [self.destinationNodeContainer autoreleasingObject];
    }
}

@end
