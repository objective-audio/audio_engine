//
//  YASAudioTapNode.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioTapNode.h"
#import "YASAudioPCMBuffer.h"
#import "YASAudioConnection.h"
#import "YASMacros.h"

@implementation YASAudioTapNode

- (void)dealloc
{
    YASRelease(_renderBlock);

    _renderBlock = nil;

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

- (void)renderWithBuffer:(YASAudioWritablePCMBuffer *)buffer bus:(NSNumber *)bus when:(YASAudioTime *)when
{
    [super renderWithBuffer:buffer bus:bus when:when];

    @autoreleasepool
    {
        YASAudioNodeCore *nodeCore = self.nodeCore;
        YASAudioNodeRenderBlock renderBlock = self.renderBlock;

        if (renderBlock) {
            renderBlock(buffer, bus, when, nodeCore);
        } else {
            YASAudioConnection *connection = [nodeCore inputConnectionForBus:@0];
            YASAudioNode *sourceNode = connection.sourceNode;
            if (sourceNode) {
                [sourceNode renderWithBuffer:buffer bus:connection.sourceBus when:when];
            }
        }
    }
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
