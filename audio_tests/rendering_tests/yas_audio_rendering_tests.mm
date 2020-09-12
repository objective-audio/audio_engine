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
        .render_handler = [&called](auto const &args) { called.emplace_back(called_node::input_0); },
        .source_connections = {}};
    audio::rendering_node const input_node_1{
        .render_handler = [&called](auto const &args) { called.emplace_back(called_node::input_1); },
        .source_connections = {}};

    audio::rendering_node const middle_node_0{
        .render_handler = [&called](auto const &args) { called.emplace_back(called_node::middle_0); },
        .source_connections = {{0, {.source_bus_idx = 0, .source_node = &input_node_0}}}};
    audio::rendering_node const middle_node_1{
        .render_handler = [&called](auto const &args) { called.emplace_back(called_node::middle_1); },
        .source_connections = {{0, {.source_bus_idx = 0, .source_node = &input_node_1}},
                               {1, {.source_bus_idx = 1, .source_node = &input_node_1}}}};

    audio::rendering_node const last_node{
        .render_handler =
            [&called](auto const &args) {
                called.emplace_back(called_node::last);
                for (auto [bus_idx, connection] : args.source_connections) {
                }
            },
        .source_connections = {{0, {.source_bus_idx = 0, .source_node = &middle_node_0}},
                               {1, {.source_bus_idx = 0, .source_node = &middle_node_1}}}};

    XCTAssertEqual(called.size(), 0);

    audio::format format{{.sample_rate = 2, .channel_count = 1}};
    audio::pcm_buffer buffer{format, 2};
    audio::time time{0};

    last_node.render_handler(
        {.buffer = &buffer, .bus_idx = 0, .time = time, .source_connections = last_node.source_connections});

    XCTAssertEqual(called.size(), 1);
}

@end
