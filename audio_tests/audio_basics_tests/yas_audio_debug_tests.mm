//
//  yas_audio_debug_tests.mm
//

#import <XCTest/XCTest.h>
#import "yas_audio_test_utils.h"

#if DEBUG

@interface yas_audio_debug_tests : XCTestCase

@end

@implementation yas_audio_debug_tests

- (void)test_debug_log {
    yas_audio_log("test_log disabled");

    yas::audio::set_log_enabled(true);

    yas_audio_log("test_log enabled");
}

@end

#endif
