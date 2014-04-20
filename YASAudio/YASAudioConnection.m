
//
//  YASAudioGraphConnection.m
//  Created by Yuki Yasoshima
//

#import "YASAudioConnection.h"
#import "YASAudioMacros.h"

@implementation YASAudioConnection

- (void)dealloc {
    YASAudioRelease(_sourceNode);
    YASAudioRelease(_destNode);
    YASAudioSuperDealloc;
}

@end
