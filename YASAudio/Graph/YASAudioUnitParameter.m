//
//  YASAudioUnitParameter.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioUnitParameter.h"
#import "YASMacros.h"
#import "NSString+YASAudio.h"

@implementation YASAudioUnitParameter

- (instancetype)initWithAudioUnitParameterInfo:(const AudioUnitParameterInfo *)info
                                   parameterID:(const AudioUnitParameterID)parameterID
                                         scope:(const AudioUnitScope)scope
{
    self = [super init];
    if (self) {
        _parameterID = parameterID;
        _scope = scope;

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
        _values = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)dealloc
{
    YASRelease(_unitName);
    YASRelease(_name);
    YASRelease(_values);

    _unitName = nil;
    _name = nil;
    _values = nil;

    YASSuperDealloc;
}

- (NSString *)description
{
    NSMutableString *result = [NSMutableString stringWithFormat:@"<%@: %p>\n{\n", self.class, self];
    NSMutableArray *lines = [NSMutableArray array];
    [lines addObject:[NSString stringWithFormat:@"UnitName = %@", _unitName]];
    [lines addObject:[NSString stringWithFormat:@"Name = %@", _name]];
    [lines addObject:[NSString stringWithFormat:@"ParameterID = %@", @(_parameterID)]];
    [lines addObject:[NSString stringWithFormat:@"Scope = %@", [NSString yas_stringWithAudioUnitScope:_scope]]];
    [lines addObject:[NSString stringWithFormat:@"HasClamp = %@", @(_hasClump)]];
    [lines addObject:[NSString stringWithFormat:@"ClumpID = %@", @(_clumpID)]];
    [lines addObject:[NSString stringWithFormat:@"Unit = %@", [NSString yas_stringWithAudioUnitParameterUnit:_unit]]];
    [lines addObject:[NSString stringWithFormat:@"MinValue = %@", @(_minValue)]];
    [lines addObject:[NSString stringWithFormat:@"MaxValue = %@", @(_maxValue)]];
    [lines addObject:[NSString stringWithFormat:@"DefaultValue = %@", @(_defaultValue)]];
    [result appendString:[[lines componentsJoinedByString:@"\n"] stringByAppendingLinePrefix:@"    "]];
    [result appendFormat:@"\n}"];
    return result;
}

- (Float32)valueForElement:(const AudioUnitElement)element
{
    NSNumber *valueNumber = _values[@(element)];
    if (valueNumber) {
        return valueNumber.floatValue;
    } else {
        return _defaultValue;
    }
}

- (void)setValue:(Float32)value forElement:(const AudioUnitElement)element
{
    _values[@(element)] = @(value);
}

@end
