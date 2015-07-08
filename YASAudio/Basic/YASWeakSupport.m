//
//  YASWeakSupport.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASWeakSupport.h"
#import "NSException+YASAudio.h"
#import "YASMacros.h"

@implementation YASWeakContainer {
    YASWeakForVariable id _object;
}

- (instancetype)initWithObject:(id)object
{
    self = [super init];
    if (self) {
        @synchronized(self)
        {
            _object = object;
        }
    }
    return self;
}

- (void)setObject:(id)object
{
    @synchronized(self)
    {
        _object = object;
    }
}

- (id)retainedObject
{
    @synchronized(self)
    {
        return YASRetain(_object);
    }
}

- (id)autoreleasingObject
{
    @synchronized(self)
    {
        return YASRetainAndAutorelease(_object);
    }
}

- (void)clearObject
{
    [self setObject:nil];
}

@end

#pragma mark -

@implementation YASWeakProvider {
    YASWeakContainer *_weakContainer;
}

- (void)dealloc
{
    if (_weakContainer) {
        @autoreleasepool
        {
            [_weakContainer clearObject];
            YASRelease(_weakContainer);
            _weakContainer = nil;
        }
    }

    YASSuperDealloc;
}

- (YASWeakContainer *)weakContainer
{
    @synchronized(self)
    {
        if (!_weakContainer) {
            _weakContainer = [[YASWeakContainer alloc] initWithObject:self];
        }
        return _weakContainer;
    }
}

@end

#pragma mark -

@implementation NSDictionary (YASWeakSupport)

- (NSDictionary *)yas_unwrappedDictionaryFromWeakContainers
{
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:self.count];

    @autoreleasepool
    {
        [self enumerateKeysAndObjectsUsingBlock:^(id key, YASWeakContainer *container, BOOL *stop) {
            if ([container isKindOfClass:[YASWeakContainer class]]) {
                id obj = [container retainedObject];
                if (obj) {
                    result[key] = obj;
                } else {
                    YASLog(@"%s - Object is released.", __PRETTY_FUNCTION__);
                }
                YASRelease(obj);
            } else {
                YASRaiseWithReason(([NSString stringWithFormat:@"%s - Value is not container.", __PRETTY_FUNCTION__]));
            }
        }];
    }

    return result;
}

@end

@implementation NSArray (YASWeakSupport)

- (NSArray *)yas_unwrappedArrayFromWeakContainers
{
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:self.count];

    @autoreleasepool
    {
        [self enumerateObjectsUsingBlock:^(YASWeakContainer *container, NSUInteger idx, BOOL *stop) {
            if ([container isKindOfClass:[YASWeakContainer class]]) {
                id obj = [container retainedObject];
                if (obj) {
                    [result addObject:obj];
                } else {
                    YASLog(@"%s - Object is released.", __PRETTY_FUNCTION__);
                }
                YASRelease(obj);
            } else {
                YASRaiseWithReason(([NSString stringWithFormat:@"%s - Value is not container.", __PRETTY_FUNCTION__]));
            }
        }];
    }

    return result;
}

@end
