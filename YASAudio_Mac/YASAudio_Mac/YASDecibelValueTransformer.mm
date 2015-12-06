//
//  YASDecibelValueTransformer.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASDecibelValueTransformer.h"
#import "yas_audio.h"

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
        numberValue = @(yas::audio_math::decibel_from_linear(numberValue.doubleValue));
        return [self.numberFormatter stringFromNumber:numberValue];
    }

    return nil;
}

@end
