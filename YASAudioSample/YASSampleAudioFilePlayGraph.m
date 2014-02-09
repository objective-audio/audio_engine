//
//  YASSampleAudioFilePlayGraph.m
//  YASAudioSample
//
//  Created by Yuki Yasoshima on 2014/02/04.
//  Copyright (c) 2014年 Yuki Yasoshima. All rights reserved.
//

#import "YASSampleAudioFilePlayGraph.h"
#import "YASAudioFile.h"
#import "YASAudioUtilities.h"
#import "YASAudioNodeRenderInfo.h"
#import "YASAudioBufferList.h"
#import <AVFoundation/AVFoundation.h>

static double const SAMPLE_AFP_SAMPLERATE = 44100.0;

@interface YASSampleAudioFilePlayGraph()
@property (nonatomic, strong) NSLock *loadingLock;
@property (nonatomic, strong) YASAudioBufferList *audioBufferList;
@property (assign) BOOL isPlaying;
@property (nonatomic, assign) UInt32 playFrame;
@property (nonatomic, assign) UInt32 totalFrames;
@property (nonatomic, strong) NSOperationQueue *audioLoadQueue;
@end

@implementation YASSampleAudioFilePlayGraph

+ (id)sampleAudioFilePlayGraph
{
    YASSampleAudioFilePlayGraph *sampleGraph = [YASSampleAudioFilePlayGraph graph];
    
    [sampleGraph setup];
    
    return sampleGraph;
}

- (void)_setupAudioSession
{
    NSError *error = nil;
    if (![[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error]) {
        NSLog(@"%s %@", __PRETTY_FUNCTION__, error);
    }
}

- (void)_setupNodes
{
    self.loadingLock = [[[NSLock alloc] init] autorelease];
    
    AudioStreamBasicDescription format;
    YASGetSInt16InterleavedStereoFormat(&format, SAMPLE_AFP_SAMPLERATE);
    
    __block YASSampleAudioFilePlayGraph *weakSelf = self;
    const YASAudioIONode *ioNode = self.ioNode;
    
    [ioNode setInputFormat:&format busNumber:0];
    
    [ioNode setRenderCallback:0];
    
    ioNode.renderCallbackBlock = ^(YASAudioNodeRenderInfo *renderInfo) {
        
        BOOL isRendered = NO;
        
        if ([weakSelf.loadingLock tryLock]) {
            
            YASAudioBufferList *audioBufferList = weakSelf.audioBufferList;
            
            if (audioBufferList && weakSelf.isPlaying) {
                
                UInt32 renderFrame = 0;
                UInt32 playFrame = weakSelf.playFrame;
                const UInt32 totalFrames = weakSelf.totalFrames;
                const UInt32 bytesPerFrame = format.mBytesPerFrame;
                const UInt32 channels = format.mChannelsPerFrame;
                
                const Byte *bufPtr = [audioBufferList dataAtBufferIndex:0];
                Byte *renderPtr = renderInfo.ioData->mBuffers[0].mData;
                
                while (renderFrame < renderInfo.inNumberFrames) {
                    
                    UInt32 renderRemainFrames = renderInfo.inNumberFrames - renderFrame;
                    UInt32 bufferRemainFrames = totalFrames - playFrame;
                    UInt32 copyFrames = renderRemainFrames < bufferRemainFrames ? renderRemainFrames : bufferRemainFrames;
                    
                    memcpy(&renderPtr[renderFrame * bytesPerFrame], &bufPtr[playFrame * bytesPerFrame], copyFrames * bytesPerFrame);
                    
                    renderFrame += copyFrames;
                    playFrame = (playFrame + copyFrames) % totalFrames;
                }
                
                weakSelf.playFrame = playFrame;
                
                const Float32 vol = weakSelf.volume;
                
                for (NSInteger i = 0; i < renderInfo.inNumberFrames; i++) {
                    for (NSInteger ch = 0; ch < channels; ch++) {
                        ((SInt16 *)renderPtr)[i * channels + ch] *= vol;
                    }
                }
                
                isRendered = YES;
            }
            
            [weakSelf.loadingLock unlock];
            
        }
        
        if (!isRendered) {
            YASClearAudioBufferList(renderInfo.ioData);
        }
        
    };
}

- (void)setup
{
    self.audioLoadQueue = [[[NSOperationQueue alloc] init] autorelease];
    _audioLoadQueue.maxConcurrentOperationCount = 1;
    
    [self _setupAudioSession];
    [self _setupNodes];
    
    self.running = YES;
}

- (void)dealloc
{
    [_loadingLock release];
    [_audioBufferList release];
    [_audioLoadQueue release];
    
    [super dealloc];
}

- (void)setAudioFileURL:(NSURL *)url
{
    [_audioLoadQueue cancelAllOperations];
    
    __block NSBlockOperation *operation = [[[NSBlockOperation alloc] init] autorelease];
    [operation setThreadPriority:0.3];
    
    [operation addExecutionBlock:^{
        
        [self.loadingLock lock];
        
        self.audioBufferList = nil;
        
        YASAudioFile *audioFile = [[YASAudioFile alloc] initWithURL:url];
        
        AudioStreamBasicDescription format;
        YASGetSInt16InterleavedStereoFormat(&format, SAMPLE_AFP_SAMPLERATE);
        [audioFile setClientFormat:&format];
        
        if ([audioFile open]) {
            
            UInt32 totalFrames = (UInt32)audioFile.totalFrames;
            self.totalFrames = totalFrames;
            
            UInt32 readFrame = 0;
            const UInt32 maxReadFrames = 44100;
            const UInt32 channels = format.mChannelsPerFrame;
            
            self.audioBufferList = [YASAudioBufferList audioBufferWithBufferCount:1 channels:channels bufferSize:_totalFrames * format.mBytesPerFrame];
            SInt16 *ptr = [self.audioBufferList dataAtBufferIndex:0];
            
            while (readFrame < totalFrames) {
                
                const UInt32 remainFrames = totalFrames - readFrame;
                UInt32 ioFrames = remainFrames < maxReadFrames ? remainFrames : maxReadFrames;
                
                [audioFile read:&ptr[readFrame * channels] ioFrames:&ioFrames];
                
                if (ioFrames == 0 || operation.isCancelled) {
                    break;
                }
                
                readFrame += ioFrames;
            }
        }
        
        [audioFile release];
        
        self.playFrame = 0;
        
        [self.loadingLock unlock];
        
    }];
    
    [_audioLoadQueue addOperation:operation];
}

- (void)play
{
    self.isPlaying = YES;
}

- (void)stop
{
    self.isPlaying = NO;
}

- (void)invalidate
{
    [_audioLoadQueue cancelAllOperations];
    [super invalidate];
}
/*
- (id)retain
{
    NSLog(@"%s %@", __PRETTY_FUNCTION__, [NSThread callStackSymbols]);
    return [super retain];
}
*/
@end
