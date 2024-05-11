//
//  ios_session_tests.mm
//

#import "../test_utils.h"

#if TARGET_OS_IPHONE

#include <audio-engine/ios/ios_session.h>

using namespace yas;
using namespace yas::audio;

@interface ios_session_tests : XCTestCase

@end

@implementation ios_session_tests

- (void)setUp {
}

- (void)tearDown {
}

- (void)test_is_output_category {
    XCTAssertTrue(audio::is_output_category(audio::ios_session::category::ambient));
    XCTAssertTrue(audio::is_output_category(audio::ios_session::category::solo_ambient));
    XCTAssertTrue(audio::is_output_category(audio::ios_session::category::playback));
    XCTAssertTrue(audio::is_output_category(audio::ios_session::category::play_and_record));
    XCTAssertTrue(audio::is_output_category(audio::ios_session::category::multi_route));

    XCTAssertFalse(audio::is_output_category(audio::ios_session::category::record));
}

- (void)test_is_input_session {
    XCTAssertTrue(audio::is_input_category(audio::ios_session::category::play_and_record));
    XCTAssertTrue(audio::is_input_category(audio::ios_session::category::record));
    XCTAssertTrue(audio::is_input_category(audio::ios_session::category::multi_route));

    XCTAssertFalse(audio::is_input_category(audio::ios_session::category::ambient));
    XCTAssertFalse(audio::is_input_category(audio::ios_session::category::solo_ambient));
    XCTAssertFalse(audio::is_input_category(audio::ios_session::category::playback));
}

@end

#endif
