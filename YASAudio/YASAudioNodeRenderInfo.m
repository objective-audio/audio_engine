
/**
 *
 *  YASAudioNodeRenderInfo.m
 *
 *  Created by Yuki Yasoshima
 *
 */

#import "YASAudioNodeRenderInfo.h"


@interface YASAudioNodeRenderInfo()
@property (nonatomic, copy) NSString *graphKey;
@property (nonatomic, copy) NSString *nodeKey;
@end

@implementation YASAudioNodeRenderInfo

- (id)initWithGraphKey:(NSString *)graphKey nodeKey:(NSString *)nodeKey
{
    self = [super init];
    if (self) {
        self.graphKey = graphKey;
        self.nodeKey = nodeKey;
        _renderType = YASAudioNodeRenderTypeUnknown;
    }
    return self;
}

- (void)dealloc
{
    [_graphKey release];
    [_nodeKey release];
    [super dealloc];
}

@end
