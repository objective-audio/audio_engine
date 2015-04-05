//
//  YASAudioOfflineOutputNode.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioOfflineOutputNode.h"
#import "YASAudioPCMBuffer.h"
#import "YASAudioFormat.h"
#import "YASAudioConnection.h"
#import "YASAudioTime.h"
#import "YASMacros.h"
#import "NSException+YASAudio.h"
#import "NSError+YASAudio.h"

static const UInt32 YASAudioOfflineOutputRenderFrameLength = 1024;

@interface YASAudioOfflineOutputNode ()

@property (nonatomic, strong) NSOperationQueue *queue;
@property (nonatomic, copy) YASAudioOfflineRenderCompletionBlock completionBlock;

@end

@implementation YASAudioOfflineOutputNode

- (void)dealloc
{
    [_queue cancelAllOperations];

    YASRelease(_queue);
    YASRelease(_completionBlock);

    _queue = nil;
    _completionBlock = nil;

    YASSuperDealloc;
}

- (UInt32)outputBusCount
{
    return 0;
}

- (UInt32)inputBusCount
{
    return 1;
}

- (void)updateConnections
{
}

- (BOOL)startWithOutputCallbackBlock:(YASAudioOfflineRenderCallbackBlock)outputBlock
                     completionBlock:(YASAudioOfflineRenderCompletionBlock)completionBlock
                               error:(NSError **)outError
{
    NSError *error = nil;
    YASAudioConnection *connection = nil;

    if (self.queue) {
        error = [NSError yas_errorWithCode:YASAudioOfflineOutputErrorCodeAlreadyRunning];
    } else if (!(connection = [self inputConnectionForBus:@0])) {
        error = [NSError yas_errorWithCode:YASAudioOfflineOutputErrorCodeConnectionIsNil];
    } else {
        self.completionBlock = completionBlock;
        completionBlock = self.completionBlock;

        YASWeakContainer *container = self.weakContainer;

        NSBlockOperation *blockOperation = [[NSBlockOperation alloc] init];
        __unsafe_unretained NSBlockOperation *weakOperation = blockOperation;

        YASAudioPCMBuffer *renderBuffer =
            [[YASAudioPCMBuffer alloc] initWithPCMFormat:connection.format
                                           frameCapacity:YASAudioOfflineOutputRenderFrameLength];

        [blockOperation addExecutionBlock:^{
            BOOL cancelled = NO;
            UInt32 currentSampleTime = 0;
            BOOL stop = NO;

            while (!stop) {
                @autoreleasepool
                {
                    YASAudioTime *when =
                        [YASAudioTime timeWithSampleTime:currentSampleTime atRate:renderBuffer.format.sampleRate];

                    YASAudioOfflineOutputNode *offlineNode = container.retainedObject;
                    YASAudioNodeCore *nodeCore = offlineNode.nodeCore;
                    YASRelease(offlineNode);

                    YASAudioConnection *connectionOnBlock = [nodeCore inputConnectionForBus:@0];
                    YASAudioFormat *format = connectionOnBlock.format;

                    if (!format || ![format isEqualToAudioFormat:renderBuffer.format]) {
                        cancelled = YES;
                        break;
                    }

                    [renderBuffer clearData];

                    YASAudioNode *sourceNode = connectionOnBlock.sourceNode;
                    [sourceNode renderWithBuffer:renderBuffer bus:connectionOnBlock.sourceBus when:when];

                    if (outputBlock) {
                        outputBlock(renderBuffer, when, &stop);
                    }

                    if (weakOperation.isCancelled) {
                        cancelled = YES;
                        break;
                    }

                    currentSampleTime += YASAudioOfflineOutputRenderFrameLength;
                }
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                YASAudioOfflineOutputNode *offlineNode = container.retainedObject;
                YASAudioOfflineRenderCompletionBlock nodeCompletionBlock = offlineNode.completionBlock;
                offlineNode.completionBlock = nil;
                offlineNode.queue = nil;
                if (completionBlock && [nodeCompletionBlock isEqual:completionBlock]) {
                    if (completionBlock) {
                        completionBlock(cancelled);
                    }
                }
                YASRelease(offlineNode);
            });
        }];

        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        queue.maxConcurrentOperationCount = 1;
        self.queue = queue;
        [queue addOperation:blockOperation];

        YASRelease(blockOperation);
        YASRelease(queue);
        YASRelease(renderBuffer);
    }

    if (error) {
        if (outError) {
            *outError = error;
        }
        return NO;
    } else {
        return YES;
    }
}

- (void)stop
{
    YASAudioOfflineRenderCompletionBlock completionBlock = self.completionBlock;
    self.completionBlock = nil;

    [self.queue cancelAllOperations];
    [self.queue waitUntilAllOperationsAreFinished];
    self.queue = nil;

    if (completionBlock) {
        completionBlock(YES);
    }
}

- (BOOL)isRunning
{
    return !!_queue;
}

@end
