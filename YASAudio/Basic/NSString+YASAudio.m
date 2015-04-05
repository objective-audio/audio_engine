//
//  NSString+YASAudio.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "NSString+YASAudio.h"

@implementation NSString (YASAudio)

+ (NSString *)yas_fileTypeStringWithHFSTypeCode:(OSType)fcc
{
#if TARGET_OS_IPHONE
    const char fourChar[5] = {(fcc >> 24) & 0xFF, (fcc >> 16) & 0xFF, (fcc >> 8) & 0xFF, fcc & 0xFF, 0};
    NSString *fourCharString = [NSString stringWithCString:fourChar encoding:NSUTF8StringEncoding];
    return [NSString stringWithFormat:@"'%@'", fourCharString];
#elif TARGET_OS_MAC
    return NSFileTypeForHFSTypeCode(fcc);
#endif
}

- (OSType)yas_HFSTypeCode
{
#if TARGET_OS_IPHONE
    if (self.length != 6) {
        return 0;
    }

    NSString *quote = @"'";
    if (![[self substringToIndex:1] isEqualToString:quote] || ![[self substringFromIndex:5] isEqualToString:quote]) {
        return 0;
    }

    NSString *fourCharFileType = [self substringWithRange:NSMakeRange(1, 4)];

    if (fourCharFileType.length != 4) {
        return 0;
    }

    OSType result = 0;

    for (NSInteger i = 0; i < 4; i++) {
        unichar uc = [fourCharFileType characterAtIndex:i];
        if (uc > UINT8_MAX) {
            return 0;
        }
        result |= uc << ((3 - i) * 8);
    }
    return result;
#elif TARGET_OS_MAC
    return NSHFSTypeCodeFromFileType(self);
#endif
}

+ (NSString *)yas_stringWithAudioUnitScope:(AudioUnitScope)scope
{
    switch (scope) {
        case kAudioUnitScope_Global:
            return @"Global";
        case kAudioUnitScope_Input:
            return @"Input";
        case kAudioUnitScope_Output:
            return @"Output";
        case kAudioUnitScope_Group:
            return @"Group";
        case kAudioUnitScope_Part:
            return @"Part";
        case kAudioUnitScope_Note:
            return @"Note";
        case kAudioUnitScope_Layer:
            return @"Layer";
        case kAudioUnitScope_LayerItem:
            return @"LayerItem";
    }
    return nil;
}

+ (NSString *)yas_stringWithAudioUnitParameterUnit:(AudioUnitParameterUnit)parameterUnit
{
    switch (parameterUnit) {
        case kAudioUnitParameterUnit_Generic:
            return @"Generic";
        case kAudioUnitParameterUnit_Indexed:
            return @"Indexed";
        case kAudioUnitParameterUnit_Boolean:
            return @"Boolean";
        case kAudioUnitParameterUnit_Percent:
            return @"Percent";
        case kAudioUnitParameterUnit_Seconds:
            return @"Seconds";
        case kAudioUnitParameterUnit_SampleFrames:
            return @"SampleFrames";
        case kAudioUnitParameterUnit_Phase:
            return @"Phase";
        case kAudioUnitParameterUnit_Rate:
            return @"Rate";
        case kAudioUnitParameterUnit_Hertz:
            return @"Hertz";
        case kAudioUnitParameterUnit_Cents:
            return @"Cents";
        case kAudioUnitParameterUnit_RelativeSemiTones:
            return @"RelativeSemiTones";
        case kAudioUnitParameterUnit_MIDINoteNumber:
            return @"MIDINoteNumber";
        case kAudioUnitParameterUnit_MIDIController:
            return @"MIDIController";
        case kAudioUnitParameterUnit_Decibels:
            return @"Decibels";
        case kAudioUnitParameterUnit_LinearGain:
            return @"LinearGain";
        case kAudioUnitParameterUnit_Degrees:
            return @"Degrees";
        case kAudioUnitParameterUnit_EqualPowerCrossfade:
            return @"EqualPowerCrossfade";
        case kAudioUnitParameterUnit_MixerFaderCurve1:
            return @"MixerFaderCurve1";
        case kAudioUnitParameterUnit_Meters:
            return @"Meters";
        case kAudioUnitParameterUnit_AbsoluteCents:
            return @"AbsoluteCents";
        case kAudioUnitParameterUnit_Octaves:
            return @"Octaves";
        case kAudioUnitParameterUnit_BPM:
            return @"BPM";
        case kAudioUnitParameterUnit_Milliseconds:
            return @"Milliseconds";
        case kAudioUnitParameterUnit_Ratio:
            return @"Ratio";
        case kAudioUnitParameterUnit_CustomUnit:
            return @"CustomUnit";
    }
    return nil;
}

- (NSString *)stringByAppendingLinePrefix:(NSString *)prefix
{
    NSArray *lines = [self componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableArray *indentedLines = [NSMutableArray array];
    for (NSString *line in lines) {
        [indentedLines addObject:[NSString stringWithFormat:@"%@%@", prefix, line]];
    }

    return [indentedLines componentsJoinedByString:@"\n"];
}

@end
