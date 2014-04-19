
/**
 *
 *  YASAudioGraphConnection.m
 *
 *  Created by Yuki Yasoshima
 *
 */

#import "YASAudioConnection.h"
#import "YASAudioUtilities.h"

@implementation YASAudioConnection

- (void)dealloc {
    YASRelease(_sourceNode);
    YASRelease(_destNode);
    YASSuperDealloc;
}

@end
