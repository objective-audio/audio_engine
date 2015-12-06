//
//  YASFrequencyValueFormatter.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASFrequencyValueFormatter.h"
#import "yas_objc_macros.h"

@interface YASFrequencyValueFormatter ()

@property (nonatomic, strong) NSNumberFormatter *numberFormatter;

@end

@implementation YASFrequencyValueFormatter

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
        return [self.numberFormatter stringFromNumber:value];
    }

    return nil;
}

@end
