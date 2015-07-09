//
//  YASMacros.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

// clang-format off

#pragma once

#if ! __has_feature(objc_arc)
    #define YASAutorelease(__v) [__v autorelease]
    #define YASRetain(__v) [__v retain]
    #define YASRetainOrIgnore(__v) [__v retain]
    #define YASRelease(__v) [__v release]
    #define YASRetainAndAutorelease(__v) [[__v retain] autorelease]
    #define YASSuperDealloc [super dealloc]
    #define YASDispatchQueueRelease(__v) dispatch_release(__v)
    #define YASBlockWeak __block
#else
    #define YASAutorelease(__v) __v
    #define YASRetain(__v) __v
    #define YASRetainOrIgnore(__v)
    #define YASRelease(__v)
    #define YASRetainAndAutorelease(__v) __v
    #define YASSuperDealloc
    #if OS_OBJECT_USE_OBJC
        #define YASDispatchQueueRelease(__v)
    #else
        #define YASDispatchQueueRelease(__v) dispatch_release(__v)
    #endif
    #define YASBlockWeak __weak
#endif

#if DEBUG
    #define YASLog(...) NSLog(__VA_ARGS__)
#else
    #define YASLog(...)
#endif
