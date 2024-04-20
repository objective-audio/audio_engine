//
//  YASFrequencyValueFormatter.m
//

#import "YASFrequencyValueFormatter.h"
#import <cpp-utils/yas_objc_ptr.h>

using namespace yas;

@interface YASFrequencyValueFormatter ()

@end

@implementation YASFrequencyValueFormatter {
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
        _formatter = objc_ptr_with_move_object([[NSNumberFormatter alloc] init]);
        _formatter.object().numberStyle = NSNumberFormatterDecimalStyle;
        _formatter.object().minimumFractionDigits = 1;
        _formatter.object().maximumFractionDigits = 1;
    }
    return self;
}

- (id)transformedValue:(id)value {
    if ([value isKindOfClass:[NSNumber class]]) {
        return [_formatter.object() stringFromNumber:value];
    }

    return nil;
}

@end
