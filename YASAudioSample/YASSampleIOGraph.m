//
//  YASSampleIOGraph.m
//  YASAudioSample
//
//  Created by Yuki Yasoshima on 2014/02/02.
//  Copyright (c) 2014年 Yuki Yasoshima. All rights reserved.
//

#import "YASSampleIOGraph.h"
#import "YASAudioUtilities.h"
#import <AVFoundation/AVFoundation.h>
#import "YASAudioNodeRenderInfo.h"

static double const SAMPLE_IO_SAMPLERATE = 44100.0;

@implementation YASSampleIOGraph

+ (id)sampleIOGraph
{
    YASSampleIOGraph *sampleGraph = [YASSampleIOGraph graph];
    
    [sampleGraph setup];
    
    return sampleGraph;
}

- (void)_setupAudioSession
{
    NSError *error = nil;
    if (![[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&error]) {
        NSLog(@"%s %@", __PRETTY_FUNCTION__, error);
    }
}

- (void)_setupNodes
{
    AudioStreamBasicDescription format;
    YASGetFloat32NonInterleavedStereoFormat(&format, SAMPLE_IO_SAMPLERATE);
    
#if __has_feature(objc_arc)
    __weak YASSampleIOGraph *weakSelf = self;
    __weak YASAudioIONode *ioNode = self.ioNode;
#else
    __block YASSampleIOGraph *weakSelf = self;
    __block YASAudioIONode *ioNode = self.ioNode;
#endif
    
    [ioNode setEnableInput:YES];
    [ioNode setEnableOutput:YES];
    
    [ioNode setInputFormat:&format busNumber:0];
    [ioNode setOutputFormat:&format busNumber:1];
    
    [ioNode setRenderCallback:0];
    
    ioNode.renderCallbackBlock = ^(YASAudioNodeRenderInfo *renderInfo) {
        
        OSStatus err = noErr;
        
        err = AudioUnitRender(ioNode.audioUnit, renderInfo.ioActionFlags, renderInfo.inTimeStamp, 1, renderInfo.inNumberFrames, renderInfo.ioData);
        
        Float32 vol = weakSelf.inputVolume;
        
        if (err == noErr) {
            const NSUInteger bufCount = renderInfo.ioData->mNumberBuffers;
            for (NSInteger bufIndex = 0; bufIndex < bufCount; bufIndex++) {
                Float32 *ptr = renderInfo.ioData->mBuffers[bufIndex].mData;
                const NSUInteger channels = renderInfo.ioData->mBuffers[bufIndex].mNumberChannels;
                for (NSInteger ch = 0; ch < channels; ch++) {
                    for (NSInteger i = 0; i < renderInfo.inNumberFrames; i++) {
                        ptr[i * channels + ch] = ptr[i * channels + ch] * vol;
                    }
                }
            }
        }
        
    };
}

- (void)setup
{
    _inputVolume = 1.0f;
    
    [self _setupAudioSession];
    [self _setupNodes];
    
    self.running = YES;
}

@end
