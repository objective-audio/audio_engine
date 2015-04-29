//
//  NSArray+YASAudio.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "NSArray+YASAudio.h"
#import "YASMacros.h"
#import "NSException+YASAudio.h"

@implementation NSArray (YASAudio)

+ (NSArray *)yas_arrayWithBlock:(id (^)(NSUInteger idx, BOOL *stop))block count:(NSUInteger)count
{
    if (block) {
        NSMutableArray *tempArray = [[NSMutableArray alloc] initWithCapacity:count];
        BOOL stop = NO;
        for (NSInteger i = 0; i < count; i++) {
            id obj = block(i, &stop);
            if (obj) {
                [tempArray addObject:obj];
            }
            if (stop) {
                break;
            }
        }
        NSArray *array = [self arrayWithArray:tempArray];
        YASRelease(tempArray);
        return array;
    }
    return nil;
}

- (NSArray *)yas_arrayOfPropertyForKey:(id)key
{
    if (!key) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil. key(%@)", __PRETTY_FUNCTION__, key]));
        return nil;
    }

    NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:self.count];
    for (id object in self) {
        id value = [object valueForKey:key];
        if (value) {
            [array addObject:value];
        }
    }
    NSArray *result = [array copy];
    YASRelease(array);
    return YASAutorelease(result);
}

- (NSNumber *)yas_emptyNumberInLength:(NSUInteger)length
{
    NSNumber *result = nil;

    if (self.count >= length) {
        YASLog(@"%s - Out of range. count(%@) length(%@)", __PRETTY_FUNCTION__, @(self.count), @(length));
        return nil;
    }

    NSNumber *max = [self valueForKeyPath:@"@max.self"];
    NSInteger next = max ? max.integerValue : -1;

    while (!result) {
        next = (next + 1) % length;
        NSNumber *number = [[NSNumber alloc] initWithInteger:next];
        if (![self containsObject:number]) {
            result = YASAutorelease(number);
        } else {
            YASRelease(number);
        }
    }

    return result;
}

@end
