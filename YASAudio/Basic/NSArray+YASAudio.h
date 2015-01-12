//
//  NSArray+YASAudio.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <Foundation/Foundation.h>

@interface NSArray (YASAudio)

+ (NSArray *)yas_arrayWithBlock:(id (^)(NSUInteger idx, BOOL *stop))block count:(NSUInteger)count;
- (NSArray *)yas_arrayOfPropertyForKey:(id)key;
- (NSNumber *)yas_emptyNumberInLength:(NSUInteger)length;

@end
