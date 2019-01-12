//
//  YASDecibelValueTransformer.mm
//

#import "YASDecibelValueTransformer.h"
#import <audio/yas_audio_umbrella.h>
#import <cpp_utils/yas_objc_ptr.h>

using namespace yas;

@interface YASDecibelValueTransformer ()

@end

@implementation YASDecibelValueTransformer {
    objc_ptr<NSNumberFormatter *> _formatter;
}

+ (Class)transformedValueClass {
    return [NSString class];
}

+ (BOOL)allowsReverseTransformation {
    return NO;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _formatter = make_objc_ptr([[NSNumberFormatter alloc] init]);
        _formatter.object().numberStyle = NSNumberFormatterDecimalStyle;
        _formatter.object().minimumFractionDigits = 1;
        _formatter.object().maximumFractionDigits = 1;
    }
    return self;
}

- (id)transformedValue:(id)value {
    if ([value isKindOfClass:[NSNumber class]]) {
        NSNumber *numberValue = value;
        numberValue = @(audio::math::decibel_from_linear(numberValue.doubleValue));
        return [_formatter.object() stringFromNumber:numberValue];
    }

    return nil;
}

@end
