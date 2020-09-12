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
    enum called_node {
        input_0,
        input_1,
        input_2,
        middle_0,
        middle_1,
        last,
    };

    std::vector<called_node> called;

    audio::rendering_node const input_node_0{
        .render_handler = [&called](auto const &) { called.emplace_back(called_node::input_0); }, .input_nodes = {}};
    audio::rendering_node const input_node_1{
        .render_handler = [&called](auto const &) { called.emplace_back(called_node::input_1); }, .input_nodes = {}};
    audio::rendering_node const input_node_2{
        .render_handler = [&called](auto const &) { called.emplace_back(called_node::input_2); }, .input_nodes = {}};

    audio::rendering_node const middle_node_0{
        .render_handler = [&called](auto const &) { called.emplace_back(called_node::middle_0); },
        .input_nodes = {{0, &input_node_0}}};
    audio::rendering_node const middle_node_1{
        .render_handler = [&called](auto const &) { called.emplace_back(called_node::middle_1); },
        .input_nodes = {{1, &input_node_1}, {2, &input_node_2}}};

    audio::rendering_node const last_node{
        .render_handler = [&called](auto const &) { called.emplace_back(called_node::last); },
        .input_nodes = {{0, &middle_node_0}, {1, &middle_node_1}}};
}

@end
