
/**
 *
 *  YASAudioGraphConnection.m
 *
 *  Created by Yuki Yasoshima
 *
 */

#import "YASAudioConnection.h"

@implementation YASAudioConnection

- (void)dealloc {
    [_sourceNode release];
    [_destNode release];
    [super dealloc];
}

@end
