//
//  YASAudioUnitParameterInfo.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioUnitParameterInfo.h"
#import "YASMacros.h"

@implementation YASAudioUnitParameterInfo

- (instancetype)initWithAudioUnitParameterInfo:(const AudioUnitParameterInfo *)info
{
    self = [super init];
    if (self) {
        if (info->unitName != NULL) {
            _unitName = YASRetain((__bridge NSString *)(info->unitName));
        }

        if (info->cfNameString != NULL) {
            _name = YASRetain((__bridge NSString *)(info->cfNameString));
        }

        _hasClump = info->flags & kAudioUnitParameterFlag_HasClump;
        _clumpID = info->clumpID;
        _unit = info->unit;
        _minValue = info->minValue;
        _maxValue = info->maxValue;
        _defaultValue = info->defaultValue;
    }
    return self;
}

- (void)dealloc
{
    YASRelease(_unitName);
    YASRelease(_name);

    _unitName = nil;
    _name = nil;

    YASSuperDealloc;
}

@end
