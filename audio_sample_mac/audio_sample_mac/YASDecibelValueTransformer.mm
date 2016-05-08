//
//  YASDecibelValueTransformer.m
//

#import "YASDecibelValueTransformer.h"
#import "yas_audio.h"

using namespace yas;

@interface YASDecibelValueTransformer ()

@property (nonatomic, strong) NSNumberFormatter *numberFormatter;

@end

@implementation YASDecibelValueTransformer

+ (Class)transformedValueClass {
    return [NSString class];
}

+ (BOOL)allowsReverseTransformation {
    return NO;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSNumberFormatter *formatter = yas_autorelease([[NSNumberFormatter alloc] init]);
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        formatter.minimumFractionDigits = 1;
        formatter.maximumFractionDigits = 1;
        self.numberFormatter = formatter;
    }
    return self;
}

- (void)dealloc {
    yas_release(_numberFormatter);

    _numberFormatter = nil;

    yas_super_dealloc();
}

- (id)transformedValue:(id)value {
    if ([value isKindOfClass:[NSNumber class]]) {
        NSNumber *numberValue = value;
        numberValue = @(audio::math::decibel_from_linear(numberValue.doubleValue));
        return [self.numberFormatter stringFromNumber:numberValue];
    }

    return nil;
}

@end
