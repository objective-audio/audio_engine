//
//  YASAudioTapNode.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioTapNode.h"
#import "YASAudioNode+Internal.h"
#import "YASAudioConnection+Internal.h"
#import "YASMacros.h"

@interface YASAudioTapNode ()

@property (nonatomic, strong) YASAudioNodeCore *nodeCoreOnRender;

@end

@implementation YASAudioTapNode

- (void)dealloc
{
    YASRelease(_renderBlock);
    YASRelease(_nodeCoreOnRender);

    _renderBlock = nil;
    _nodeCoreOnRender = nil;

    YASSuperDealloc;
}

- (UInt32)inputBusCount
{
    return 1;
}

- (UInt32)outputBusCount
{
    return 1;
}

#pragma mark Render thread

- (void)renderWithData:(YASAudioData *)data bus:(NSNumber *)bus when:(YASAudioTime *)when
{
    [super renderWithData:data bus:bus when:when];

    @autoreleasepool
    {
        YASAudioNodeCore *nodeCore = self.nodeCore;
        self.nodeCoreOnRender = nodeCore;

        YASAudioNodeRenderBlock renderBlock = self.renderBlock;

        if (renderBlock) {
            renderBlock(data, bus, when);
        } else {
            YASAudioConnection *connection = [nodeCore inputConnectionForBus:@0];
            YASAudioNode *sourceNode = connection.sourceNode;
            if (sourceNode) {
                [sourceNode renderWithData:data bus:connection.sourceBus when:when];
            }
        }

        self.nodeCoreOnRender = nil;
    }
}

- (YASAudioConnection *)inputConnectionOnRenderForBus:(NSNumber *)bus
{
    return [self.nodeCoreOnRender inputConnectionForBus:bus];
}

- (YASAudioConnection *)outputConnectionOnRenderForBus:(NSNumber *)bus
{
    return [self.nodeCoreOnRender outputConnectionForBus:bus];
}

- (NSDictionary *)inputConnectionsOnRender
{
    return [self.nodeCoreOnRender inputConnections];
}

- (NSDictionary *)outputConnectionsOnRender
{
    return [self.nodeCoreOnRender outputConnections];
}

@end

#pragma mark -

@implementation YASAudioInputTapNode

- (UInt32)inputBusCount
{
    return 1;
}

- (UInt32)outputBusCount
{
    return 0;
}

@end
