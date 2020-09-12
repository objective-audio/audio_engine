//
//  yas_audio_rendering_tests.mm
//

#import <XCTest/XCTest.h>
#include <audio/yas_audio_rendering_graph.h>

using namespace yas;

@interface yas_audio_rendering_tests : XCTestCase

@end

@implementation yas_audio_rendering_tests

- (void)test_render {
    audio::rendering_node last_node{.render_handler = [](auto const &) {}, .input_nodes = {}};
    audio::rendering_node middle_node{.render_handler = [](auto const &) {}, .input_nodes = {}};
    audio::rendering_node input_node_0{.render_handler = [](auto const &) {}, .input_nodes = {}};
    audio::rendering_node input_node_1{.render_handler = [](auto const &) {}, .input_nodes = {}};
}

@end
