
//
//  YASAudioMacros.h
//  Created by Yuki Yasoshima
//

#ifndef YASAudioSample_YASAudioMacros_h
#define YASAudioSample_YASAudioMacros_h

#pragma mark -
#pragma mark Error Handling
#pragma mark -

#if !DEBUG

#define YAS_Require_NoErr(errorCode, exceptionLabel)                    \
do                                                                      \
{                                                                       \
    if ( __builtin_expect(0 != (errorCode), 0) )                        \
    {                                                                   \
        goto exceptionLabel;                                            \
    }                                                                   \
} while ( 0 )

#else

#define YAS_Require_NoErr(errorCode, exceptionLabel)                    \
do                                                                      \
{                                                                       \
    long evalOnceErrorCode = (errorCode);                               \
    if ( __builtin_expect(0 != evalOnceErrorCode, 0) )                  \
    {                                                                   \
        NSLog(@"YASRequireError %s %d", __PRETTY_FUNCTION__, __LINE__); \
        goto exceptionLabel;                                            \
    }                                                                   \
} while ( 0 )

#endif


#if !DEBUG

#define YAS_Verify_NoErr(errorCode)                                     \
do                                                                      \
{                                                                       \
    if ( 0 != (errorCode) )                                             \
    {                                                                   \
    }                                                                   \
} while ( 0 )

#else

#define YAS_Verify_NoErr(errorCode)                                     \
do                                                                      \
{                                                                       \
    long evalOnceErrorCode = (errorCode);                               \
    if ( __builtin_expect(0 != evalOnceErrorCode, 0) )                  \
    {                                                                   \
        NSLog(@"YASVerifyError %s %d", __PRETTY_FUNCTION__, __LINE__);  \
    }                                                                   \
} while ( 0 )

#endif

#pragma mark -
#pragma mark Automatic Reference Counting
#pragma mark -

#if ! __has_feature(objc_arc)
    #define YASAudioAutorelease(__v) ([__v autorelease]);
    #define YASAudioRetain(__v) ([__v retain]);
    #define YASAudioRelease(__v) ([__v release]);
    #define YASAudioSuperDealloc [super dealloc];
    #define YASAudioDispatchQueueRelease(__v) (dispatch_release(__v));
#else
    #define YASAudioAutorelease(__v)
    #define YASAudioRetain(__v)
    #define YASAudioRelease(__v)
    #define YASAudioSuperDealloc
    #if OS_OBJECT_USE_OBJC
        #define YASAudioDispatchQueueRelease(__v)
    #else
        #define YASAudioDispatchQueueRelease(__v) (dispatch_release(__v));
    #endif
#endif

#endif
