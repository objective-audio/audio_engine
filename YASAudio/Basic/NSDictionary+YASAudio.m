//
//  NSDictionary+YASAudio.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "NSDictionary+YASAudio.h"
#import "NSArray+YASAudio.h"

@implementation NSDictionary (YASAudio)

- (NSNumber *)yas_emptyNumberKeyInLength:(NSUInteger)length
{
    return [self.allKeys yas_emptyNumberInLength:length];
}

@end
