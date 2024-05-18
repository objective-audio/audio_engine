//
//  yas_playing_buffering_tests.mm
//

#import <XCTest/XCTest.h>
#import <audio-playing/umbrella.hpp>
#import <thread>
#import "test_utils.h"

using namespace yas;
using namespace yas::playing;

namespace yas::playing::buffering_test {
static uint32_t const ch_count = 2;
static uint32_t const element_count = 3;
static sample_rate_t const sample_rate = 4;
static audio::pcm_format const pcm_format = audio::pcm_format::int16;
static audio::format const format{
    {.sample_rate = sample_rate, .pcm_format = pcm_format, .channel_count = 1, .interleaved = false}};
static path::timeline tl_path{
    .root_path = test_utils::root_path(), .identifier = "0", .sample_rate = static_cast<sample_rate_t>(sample_rate)};
static path::timeline timeline_path(std::string const &identifier) {
    return path::timeline{.root_path = test_utils::root_path(),
                          .identifier = identifier,
                          .sample_rate = static_cast<sample_rate_t>(sample_rate)};
}

static path::channel channel_path(std::string const &identifier, channel_index_t const ch_idx) {
    return path::channel{buffering_test::timeline_path(identifier), ch_idx};
}

struct channel : buffering_channel_for_buffering_resource {
    std::size_t element_count;
    audio::format format;
    sample_rate_t frag_length;

    channel(std::size_t const element_count, audio::format const &format, sample_rate_t const frag_length)
        : element_count(element_count), format(format), frag_length(frag_length) {
    }

    std::function<bool()> write_elements_handler;
    std::function<void(path::channel const &, fragment_index_t const)> write_all_elements_handler;
    std::function<void(fragment_index_t const)> advance_handler;
    std::function<void(fragment_range const)> overwrite_element_handler;
    std::function<bool(audio::pcm_buffer *, frame_index_t const)> read_into_buffer_handler;

    bool write_elements_if_needed_on_task() {
        return this->write_elements_handler();
    }

    void write_all_elements_on_task(path::channel const &ch_path, fragment_index_t const top_frag_idx) {
        this->write_all_elements_handler(ch_path, top_frag_idx);
    }

    void advance_on_render(fragment_index_t const frag_idx) {
        this->advance_handler(frag_idx);
    }

    void overwrite_element_on_render(fragment_range const frag_range) {
        this->overwrite_element_handler(frag_range);
    }

    bool read_into_buffer_on_render(audio::pcm_buffer *out_buffer, frame_index_t const frame) {
        return this->read_into_buffer_handler(out_buffer, frame);
    }
};

struct cpp {
    std::shared_ptr<buffering_resource> buffering = nullptr;
    std::vector<std::shared_ptr<buffering_test::channel>> channels;

    void setup_rendering() {
        std::vector<std::shared_ptr<buffering_test::channel>> channels;

        auto const buffering = buffering_resource::make_shared(
            buffering_test::element_count, test_utils::root_path(),
            [&channels](std::size_t const element_count, audio::format const &format, sample_rate_t const frag_length) {
                auto channel = std::make_shared<buffering_test::channel>(element_count, format, frag_length);
                channels.emplace_back(channel);
                return channel;
            });

        std::thread{[&buffering] {
            buffering->set_creating_on_render(buffering_test::sample_rate, buffering_test::pcm_format,
                                              buffering_test::ch_count);
        }}.join();

        std::thread{[&buffering] { buffering->create_buffer_on_task(); }}.join();

        XCTAssertEqual(buffering->setup_state(), audio_buffering_setup_state::rendering);

        this->buffering = buffering;
        this->channels = std::move(channels);
    }

    void setup_advancing() {
        std::vector<std::shared_ptr<buffering_test::channel>> channels;

        auto const buffering = buffering_resource::make_shared(
            buffering_test::element_count, test_utils::root_path(),
            [&channels](std::size_t const element_count, audio::format const &format, sample_rate_t const frag_length) {
                auto channel = std::make_shared<buffering_test::channel>(element_count, format, frag_length);
                channels.emplace_back(channel);
                return channel;
            });

        std::thread{[&buffering] {
            buffering->set_creating_on_render(buffering_test::sample_rate, buffering_test::pcm_format,
                                              buffering_test::ch_count);
        }}.join();

        std::thread{[&buffering] { buffering->create_buffer_on_task(); }}.join();

        auto each = make_fast_each(buffering_test::ch_count);
        while (yas_each_next(each)) {
            channels.at(yas_each_index(each))->write_all_elements_handler = [](path::channel const &,
                                                                               fragment_index_t const) {};
        }

        std::thread{[&buffering] { buffering->set_all_writing_on_render(0); }}.join();

        std::thread{[&buffering] { buffering->write_all_elements_on_task(); }}.join();

        XCTAssertEqual(buffering->rendering_state(), audio_buffering_rendering_state::advancing);

        this->buffering = buffering;
        this->channels = std::move(channels);
    }
};
}  // namespace yas::playing::buffering_test

@interface buffering_tests : XCTestCase

@end

@implementation buffering_tests {
    buffering_test::cpp _cpp;
}

- (void)tearDown {
    self->_cpp = buffering_test::cpp{};
    [super tearDown];
}

- (void)test_setup_state {
    std::vector<std::shared_ptr<buffering_test::channel>> channels;

    auto const buffering = buffering_resource::make_shared(
        buffering_test::element_count, test_utils::root_path(),
        [&channels](std::size_t const element_count, audio::format const &format, sample_rate_t const frag_length) {
            auto channel = std::make_shared<buffering_test::channel>(element_count, format, frag_length);
            channels.emplace_back(channel);
            return channel;
        });

    XCTAssertEqual(buffering->setup_state(), audio_buffering_setup_state::initial);

    buffering->set_creating_on_render(buffering_test::sample_rate, buffering_test::pcm_format,
                                      buffering_test::ch_count);

    XCTAssertEqual(buffering->setup_state(), audio_buffering_setup_state::creating);
    XCTAssertEqual(channels.size(), 0);

    buffering->create_buffer_on_task();

    XCTAssertEqual(buffering->setup_state(), audio_buffering_setup_state::rendering);
    XCTAssertEqual(channels.size(), 2);

    XCTAssertEqual(channels.at(0)->element_count, 3);
    XCTAssertEqual(channels.at(0)->format, buffering_test::format);
    XCTAssertEqual(channels.at(0)->frag_length, buffering_test::sample_rate);
    XCTAssertEqual(channels.at(1)->element_count, 3);
    XCTAssertEqual(channels.at(1)->format, buffering_test::format);
    XCTAssertEqual(channels.at(1)->frag_length, buffering_test::sample_rate);

    channels.clear();

    buffering->set_creating_on_render(buffering_test::sample_rate, buffering_test::pcm_format,
                                      buffering_test::ch_count);

    XCTAssertEqual(buffering->setup_state(), audio_buffering_setup_state::creating);
    XCTAssertEqual(channels.size(), 0);
}

- (void)test_rendering_state {
    std::vector<std::shared_ptr<buffering_test::channel>> channels;

    auto const buffering = buffering_resource::make_shared(
        buffering_test::element_count, test_utils::root_path(),
        [&channels](std::size_t const element_count, audio::format const &format, sample_rate_t const frag_length) {
            auto channel = std::make_shared<buffering_test::channel>(element_count, format, frag_length);
            channels.emplace_back(channel);
            return channel;
        });

    std::thread{[&buffering] {
        buffering->set_creating_on_render(buffering_test::sample_rate, buffering_test::pcm_format,
                                          buffering_test::ch_count);
    }}.join();

    std::thread{[&buffering] { buffering->create_buffer_on_task(); }}.join();

    channels.at(0)->write_all_elements_handler = [](path::channel const &ch_path, fragment_index_t const top_frag_idx) {
    };
    channels.at(1)->write_all_elements_handler = [](path::channel const &ch_path, fragment_index_t const top_frag_idx) {
    };

    XCTAssertEqual(buffering->setup_state(), audio_buffering_setup_state::rendering);
    XCTAssertEqual(buffering->rendering_state(), audio_buffering_rendering_state::waiting);

    buffering->set_all_writing_on_render(0);

    XCTAssertEqual(buffering->rendering_state(), audio_buffering_rendering_state::all_writing);

    buffering->write_all_elements_on_task();

    XCTAssertEqual(buffering->rendering_state(), audio_buffering_rendering_state::advancing);

    buffering->set_all_writing_on_render(20);

    XCTAssertEqual(buffering->rendering_state(), audio_buffering_rendering_state::all_writing);
}

- (void)test_channel_count_and_fragment_length {
    self->_cpp.setup_advancing();

    auto const buffering = self->_cpp.buffering;

    XCTAssertEqual(buffering->channel_count_on_render(), buffering_test::ch_count);
    XCTAssertEqual(buffering->fragment_length_on_render(), buffering_test::sample_rate);
}

- (void)test_needs_create {
    self->_cpp.setup_rendering();

    auto const buffering = self->_cpp.buffering;

    XCTAssertFalse(buffering->needs_create_on_render(buffering_test::sample_rate, buffering_test::pcm_format,
                                                     buffering_test::ch_count));

    XCTAssertTrue(buffering->needs_create_on_render(5, buffering_test::pcm_format, buffering_test::ch_count));
    XCTAssertTrue(buffering->needs_create_on_render(buffering_test::sample_rate, audio::pcm_format::other,
                                                    buffering_test::ch_count));
    XCTAssertTrue(buffering->needs_create_on_render(buffering_test::sample_rate, buffering_test::pcm_format, 3));
}

- (void)test_set_all_writing_from_waiting {
    self->_cpp.setup_rendering();

    auto const buffering = self->_cpp.buffering;

    XCTAssertEqual(buffering->rendering_state(), audio_buffering_rendering_state::waiting);

    buffering->set_all_writing_on_render(100);

    XCTAssertEqual(buffering->rendering_state(), audio_buffering_rendering_state::all_writing);
    XCTAssertEqual(buffering->all_writing_frame_for_test(), 100);
    XCTAssertEqual(buffering->ch_mapping_for_test().indices.size(), 0);
}

- (void)test_set_all_writing_from_advancing {
    self->_cpp.setup_advancing();

    auto const buffering = self->_cpp.buffering;

    XCTAssertEqual(buffering->rendering_state(), audio_buffering_rendering_state::advancing);

    buffering->set_all_writing_on_render(200);

    XCTAssertEqual(buffering->rendering_state(), audio_buffering_rendering_state::all_writing);
    XCTAssertEqual(buffering->all_writing_frame_for_test(), 200);
}

- (void)test_advance {
    self->_cpp.setup_advancing();

    auto const buffering = self->_cpp.buffering;

    XCTAssertEqual(buffering->rendering_state(), audio_buffering_rendering_state::advancing);

    std::vector<fragment_index_t> called_advance_0;
    std::vector<fragment_index_t> called_advance_1;

    auto &channels = self->_cpp.channels;
    channels.at(0)->advance_handler = [&called_advance_0](fragment_index_t const frag_idx) {
        called_advance_0.emplace_back(frag_idx);
    };
    channels.at(1)->advance_handler = [&called_advance_1](fragment_index_t const frag_idx) {
        called_advance_1.emplace_back(frag_idx);
    };

    buffering->advance_on_render(10);

    XCTAssertEqual(called_advance_0.size(), 1);
    XCTAssertEqual(called_advance_0.at(0), 10);
    XCTAssertEqual(called_advance_1.size(), 1);
    XCTAssertEqual(called_advance_1.at(0), 10);
}

- (void)test_write_elements_if_needed {
    self->_cpp.setup_advancing();

    auto const buffering = self->_cpp.buffering;

    bool result0 = false;
    bool result1 = false;

    std::size_t called_count_0 = 0;
    std::size_t called_count_1 = 0;

    auto &channels = self->_cpp.channels;
    channels.at(0)->write_elements_handler = [&result0, &called_count_0]() {
        ++called_count_0;
        return result0;
    };
    channels.at(1)->write_elements_handler = [&result1, &called_count_1]() {
        ++called_count_1;
        return result1;
    };

    XCTAssertFalse(buffering->write_elements_if_needed_on_task());

    XCTAssertEqual(called_count_0, 1);
    XCTAssertEqual(called_count_1, 1);

    result0 = true;
    result1 = false;

    XCTAssertTrue(buffering->write_elements_if_needed_on_task());

    XCTAssertEqual(called_count_0, 2);
    XCTAssertEqual(called_count_1, 2);

    result0 = false;
    result1 = true;

    XCTAssertTrue(buffering->write_elements_if_needed_on_task());

    XCTAssertEqual(called_count_0, 3);
    XCTAssertEqual(called_count_1, 3);

    result0 = true;
    result1 = true;

    XCTAssertTrue(buffering->write_elements_if_needed_on_task());

    XCTAssertEqual(called_count_0, 4);
    XCTAssertEqual(called_count_1, 4);
}

- (void)test_write_all_elements {
    self->_cpp.setup_rendering();

    auto const &buffering = self->_cpp.buffering;
    auto &channels = self->_cpp.channels;

    std::vector<std::pair<path::channel, fragment_index_t>> called_channel_0;
    std::vector<std::pair<path::channel, fragment_index_t>> called_channel_1;

    channels.at(0)->write_all_elements_handler = [&called_channel_0](path::channel const &ch_path,
                                                                     fragment_index_t const top_frag_idx) {
        called_channel_0.emplace_back(ch_path, top_frag_idx);
    };
    channels.at(1)->write_all_elements_handler = [&called_channel_1](path::channel const &ch_path,
                                                                     fragment_index_t const top_frag_idx) {
        called_channel_1.emplace_back(ch_path, top_frag_idx);
    };

    buffering->set_all_writing_on_render(0);

    XCTAssertEqual(buffering->rendering_state(), audio_buffering_rendering_state::all_writing);

    XCTAssertEqual(called_channel_0.size(), 0);
    XCTAssertEqual(called_channel_1.size(), 0);

    buffering->write_all_elements_on_task();

    XCTAssertEqual(buffering->rendering_state(), audio_buffering_rendering_state::advancing);

    XCTAssertEqual(called_channel_0.size(), 1);
    XCTAssertEqual(called_channel_0.at(0).first, buffering_test::channel_path("", 0));
    XCTAssertEqual(called_channel_0.at(0).second, 0);
    XCTAssertEqual(called_channel_1.size(), 1);
    XCTAssertEqual(called_channel_1.at(0).first, buffering_test::channel_path("", 1));
    XCTAssertEqual(called_channel_1.at(0).second, 0);

    buffering->set_channel_mapping_request_on_main(channel_mapping{.indices = {1, 0}});

    std::thread{[&buffering] { buffering->set_all_writing_on_render(10); }}.join();
    std::thread{[&buffering] { buffering->write_all_elements_on_task(); }}.join();

    XCTAssertEqual(called_channel_0.size(), 2);
    XCTAssertEqual(called_channel_0.at(1).first, buffering_test::channel_path("", 1));
    XCTAssertEqual(called_channel_0.at(1).second, 2, @"10(frame) / 4(frag_length) = 2");
    XCTAssertEqual(called_channel_1.size(), 2);
    XCTAssertEqual(called_channel_1.at(1).first, buffering_test::channel_path("", 0));
    XCTAssertEqual(called_channel_1.at(1).second, 2);

    buffering->set_identifier_request_on_main("111");

    std::thread{[&buffering] { buffering->set_all_writing_on_render(20); }}.join();
    std::thread{[&buffering] { buffering->write_all_elements_on_task(); }}.join();

    XCTAssertEqual(called_channel_0.size(), 3);
    XCTAssertEqual(called_channel_0.at(2).first, buffering_test::channel_path("111", 1),
                   @"nulloptの場合は最後のch_pathが使われる");
    XCTAssertEqual(called_channel_0.at(2).second, 5, @"20(frame) / 4(frag_length) = 5");
    XCTAssertEqual(called_channel_1.size(), 3);
    XCTAssertEqual(called_channel_1.at(2).first, buffering_test::channel_path("111", 0));
    XCTAssertEqual(called_channel_1.at(2).second, 5);
}

- (void)test_overwrite_element {
    self->_cpp.setup_advancing();

    auto const &buffering = self->_cpp.buffering;
    auto &channels = self->_cpp.channels;

    std::vector<fragment_range> called0;
    std::vector<fragment_range> called1;

    channels.at(0)->overwrite_element_handler = [&called0](fragment_range const frag_range) {
        called0.emplace_back(frag_range);
    };
    channels.at(1)->overwrite_element_handler = [&called1](fragment_range const frag_range) {
        called1.emplace_back(frag_range);
    };

    buffering->overwrite_element_on_render({.file_channel_index = 0, .fragment_range = {.index = 0, .length = 1}});

    XCTAssertEqual(called0.size(), 1);
    XCTAssertEqual(called0.at(0).index, 0);
    XCTAssertEqual(called0.at(0).length, 1);
    XCTAssertEqual(called1.size(), 0);

    buffering->overwrite_element_on_render({.file_channel_index = 1, .fragment_range = {.index = 1, .length = 1}});

    XCTAssertEqual(called0.size(), 1);
    XCTAssertEqual(called1.size(), 1);
    XCTAssertEqual(called1.at(0).index, 1);
    XCTAssertEqual(called1.at(0).length, 1);

    buffering->overwrite_element_on_render({.file_channel_index = 2, .fragment_range = {.index = 2, .length = 1}});
    buffering->overwrite_element_on_render({.file_channel_index = -1, .fragment_range = {.index = -1, .length = 1}});

    XCTAssertEqual(called0.size(), 1);
    XCTAssertEqual(called1.size(), 1);

    buffering->set_channel_mapping_request_on_main(channel_mapping{.indices = {2, 3}});

    std::thread{[&buffering] { buffering->set_all_writing_on_render(0); }}.join();
    std::thread{[&buffering] { buffering->write_all_elements_on_task(); }}.join();

    XCTAssertEqual(called0.size(), 1);
    XCTAssertEqual(called1.size(), 1);

    buffering->overwrite_element_on_render({.file_channel_index = 3, .fragment_range = {.index = 3, .length = 1}});

    XCTAssertEqual(called0.size(), 1);
    XCTAssertEqual(called1.size(), 2);
    XCTAssertEqual(called1.at(1).index, 3);
    XCTAssertEqual(called1.at(1).length, 1);

    buffering->overwrite_element_on_render({.file_channel_index = 2, .fragment_range = {.index = 4, .length = 1}});

    XCTAssertEqual(called0.size(), 2);
    XCTAssertEqual(called0.at(1).index, 4);
    XCTAssertEqual(called0.at(1).length, 1);
    XCTAssertEqual(called1.size(), 2);

    buffering->overwrite_element_on_render({.file_channel_index = 0, .fragment_range = {.index = 5, .length = 1}});
    buffering->overwrite_element_on_render({.file_channel_index = 1, .fragment_range = {.index = 6, .length = 1}});

    XCTAssertEqual(called0.size(), 2);
    XCTAssertEqual(called1.size(), 2);

    // file_channel_indexがnulloptなら全ch上書き
    buffering->overwrite_element_on_render(
        {.file_channel_index = std::nullopt, .fragment_range = {.index = 7, .length = 1}});

    XCTAssertEqual(called0.size(), 3);
    XCTAssertEqual(called0.at(2).index, 7);
    XCTAssertEqual(called0.at(2).length, 1);
    XCTAssertEqual(called1.size(), 3);
    XCTAssertEqual(called1.at(2).index, 7);
    XCTAssertEqual(called1.at(2).length, 1);
}

- (void)test_read_into_buffer {
    self->_cpp.setup_advancing();

    auto const &buffering = self->_cpp.buffering;
    auto &channels = self->_cpp.channels;

    bool result0 = false;
    bool result1 = false;
    std::vector<std::pair<audio::pcm_buffer *, frame_index_t>> called0;
    std::vector<std::pair<audio::pcm_buffer *, frame_index_t>> called1;

    channels.at(0)->read_into_buffer_handler = [&called0, &result0](audio::pcm_buffer *buffer,
                                                                    frame_index_t const frame) {
        called0.emplace_back(buffer, frame);
        return result0;
    };

    channels.at(1)->read_into_buffer_handler = [&called1, &result1](audio::pcm_buffer *buffer,
                                                                    frame_index_t const frame) {
        called1.emplace_back(buffer, frame);
        return result1;
    };

    audio::pcm_buffer buffer{buffering_test::format, buffering_test::sample_rate};

    result0 = false;
    result1 = false;

    XCTAssertFalse(buffering->read_into_buffer_on_render(&buffer, 0, 100));

    XCTAssertEqual(called0.size(), 1);
    XCTAssertEqual(called0.at(0).first, &buffer);
    XCTAssertEqual(called0.at(0).second, 100);
    XCTAssertEqual(called1.size(), 0);

    XCTAssertFalse(buffering->read_into_buffer_on_render(&buffer, 1, 101));

    XCTAssertEqual(called0.size(), 1);
    XCTAssertEqual(called1.size(), 1);
    XCTAssertEqual(called1.at(0).first, &buffer);
    XCTAssertEqual(called1.at(0).second, 101);

    XCTAssertFalse(buffering->read_into_buffer_on_render(&buffer, 2, 102));

    // ch_idxが範囲外で呼ばれない
    XCTAssertEqual(called0.size(), 1);
    XCTAssertEqual(called1.size(), 1);

    result0 = true;
    result1 = false;

    XCTAssertTrue(buffering->read_into_buffer_on_render(&buffer, 0, 300), @"channelから返したフラグと一致");
    XCTAssertFalse(buffering->read_into_buffer_on_render(&buffer, 1, 301));
}

- (void)test_needs_all_writing_on_render {
    self->_cpp.setup_advancing();

    auto const &buffering = self->_cpp.buffering;

    XCTAssertFalse(buffering->needs_all_writing_on_render(), @"初期状態はfalse");

    buffering->set_channel_mapping_request_on_main(channel_mapping{});

    XCTAssertTrue(buffering->needs_all_writing_on_render(), @"channel_mapping_requestがあればtrue");

    buffering->set_all_writing_on_render(0);
    buffering->write_all_elements_on_task();

    XCTAssertFalse(buffering->needs_all_writing_on_render(), @"書き込めばリセットされてfalse");

    buffering->set_identifier_request_on_main("333");

    XCTAssertTrue(buffering->needs_all_writing_on_render(), @"identifier_requestがあればtrue");

    buffering->set_all_writing_on_render(0);
    buffering->write_all_elements_on_task();

    XCTAssertFalse(buffering->needs_all_writing_on_render(), @"書き込めばリセットされてfalse");
}

- (void)test_channel_mapping_request {
    self->_cpp.setup_advancing();

    auto const &buffering = self->_cpp.buffering;

    buffering->set_channel_mapping_request_on_main(channel_mapping{.indices = {2, 1}});

    XCTAssertEqual(buffering->ch_mapping_for_test().indices, (std::vector<channel_index_t>{}));

    buffering->set_all_writing_on_render(0);
    buffering->write_all_elements_on_task();

    XCTAssertEqual(buffering->ch_mapping_for_test().indices, (std::vector<channel_index_t>{2, 1}));
}

- (void)test_identifier_request {
    self->_cpp.setup_advancing();

    auto const &buffering = self->_cpp.buffering;

    buffering->set_identifier_request_on_main("444");

    XCTAssertEqual(buffering->identifier_for_test(), "");

    buffering->set_all_writing_on_render(0);
    buffering->write_all_elements_on_task();

    XCTAssertEqual(buffering->identifier_for_test(), "444");
}

- (void)test_element_count {
    auto const buffering = buffering_resource::make_shared(
        buffering_test::element_count, test_utils::root_path(),
        [](std::size_t const element_count, audio::format const &format, sample_rate_t const frag_length) {
            return std::make_shared<buffering_test::channel>(element_count, format, frag_length);
        });

    XCTAssertEqual(buffering->element_count(), buffering_test::element_count);
}

- (void)test_setup_state_to_string {
    XCTAssertEqual(to_string(audio_buffering_setup_state::initial), "initial");
    XCTAssertEqual(to_string(audio_buffering_setup_state::creating), "creating");
    XCTAssertEqual(to_string(audio_buffering_setup_state::rendering), "rendering");
}

- (void)test_rendering_state_to_string {
    XCTAssertEqual(to_string(audio_buffering_rendering_state::waiting), "waiting");
    XCTAssertEqual(to_string(audio_buffering_rendering_state::all_writing), "all_writing");
    XCTAssertEqual(to_string(audio_buffering_rendering_state::advancing), "advancing");
}

- (void)test_setup_state_ostream {
    auto const values = {audio_buffering_setup_state::initial, audio_buffering_setup_state::creating,
                         audio_buffering_setup_state::rendering};

    for (auto const &value : values) {
        std::ostringstream stream;
        stream << value;
        XCTAssertEqual(stream.str(), to_string(value));
    }
}

- (void)test_rendering_state_ostream {
    auto const values = {audio_buffering_rendering_state::waiting, audio_buffering_rendering_state::all_writing,
                         audio_buffering_rendering_state::advancing};

    for (auto const &value : values) {
        std::ostringstream stream;
        stream << value;
        XCTAssertEqual(stream.str(), to_string(value));
    }
}

@end
