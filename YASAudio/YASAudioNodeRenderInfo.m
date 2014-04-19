
/**
 *
 *  YASAudioNodeRenderInfo.m
 *
 *  Created by Yuki Yasoshima
 *
 */

#import "YASAudioNodeRenderInfo.h"
#import "YASAudioUtilities.h"

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
    YASAudioRelease(_graphKey);
    YASAudioRelease(_nodeKey);
    YASAudioSuperDealloc;
}

@end
