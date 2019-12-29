//
//  yas_audio_device_tests.m
//

#include <TargetConditionals.h>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#import <audio/yas_audio_mac_device.h>
#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_device_tests : XCTestCase

@end

@implementation yas_audio_device_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

@end

#endif
