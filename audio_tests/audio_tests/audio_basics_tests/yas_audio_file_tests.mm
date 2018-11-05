//
//  yas_audio_file_tests.m
//

#import "yas_audio_test_utils.h"
#import "yas_file_manager.h"
#import "yas_objc_ptr.h"
#import "yas_system_url_utils.h"

using namespace yas;

namespace yas::test {
struct audio_file_test_data {
    std::string file_name;
    double file_sample_rate;
    double processing_sample_rate;
    uint32_t channels;
    uint32_t file_bit_depth;
    uint32_t frame_length;
    uint32_t loop_count;
    audio::pcm_format pcm_format;
    bool interleaved;
    bool standard;
    bool async;

    audio_file_test_data() : _file_type(nullptr) {
    }

    ~audio_file_test_data() {
        set_file_type(nullptr);
    }

    void set_file_type(CFStringRef const file_type) {
        set_cf_property(_file_type, file_type);
    }

    CFStringRef file_type() const {
        return get_cf_property(_file_type);
    }

    CFDictionaryRef settings() const {
        if (CFStringCompare(file_type(), audio::file_type_cf_string::wave, kNilOptions) == kCFCompareEqualTo) {
            return audio::wave_file_settings(file_sample_rate, channels, file_bit_depth);
        } else if (CFStringCompare(file_type(), audio::file_type_cf_string::aiff, kNilOptions) == kCFCompareEqualTo) {
            return audio::aiff_file_settings(file_sample_rate, channels, file_bit_depth);
        }
        return nullptr;
    }

   private:
    CFStringRef _file_type;
};

static yas::url temporary_test_dir_url() {
    return system_url_utils::directory_url(system_url_utils::dir::temporary).appending("yas_audio_test_files");
}

static void removeAllFiles() {
    auto url = test::temporary_test_dir_url();

    if (auto result = file_manager::remove_files_in_directory(url.path()); result.is_error()) {
        throw std::runtime_error("remove_files failed");
    }
}

static void setupDirectory() {
    test::removeAllFiles();

    auto path = test::temporary_test_dir_url().path();
    if (auto result = file_manager::create_directory_if_not_exists(path); result.is_error()) {
        throw std::runtime_error("create_directory_if_not_exists failed");
    }
}
}

@interface yas_audio_file_tests : XCTestCase

@end

@implementation yas_audio_file_tests

- (void)setUp {
    [super setUp];

    test::setupDirectory();
}

- (void)tearDown {
    test::removeAllFiles();

    [super tearDown];
}

#warning iOS11.4でsample_rateを変えた時にファイルサイズが大きくなっている
- (void)_test_wave_file {
#if WAVEFILE_LIGHT_TEST
    double sample_rates[] = {44100.0, 382000.0};
    uint32_t channels[] = {1, 2};
    uint32_t file_bit_depths[] = {16, 24};
    audio::pcm_format pcm_formats[] = {audio::pcm_format::float32, audio::pcm_format::float64};
    bool interleaveds[] = {YES, NO};
#else
    double sample_rates[] = {8000.0, 44100.0, 48000.0, 382000.0};
    uint32_t channels[] = {1, 2, 3, 6};
    uint32_t file_bit_depths[] = {16, 24, 32};
    audio::pcm_format pcm_formats[] = {audio::pcm_format::float32, audio::pcm_format::float64, audio::pcm_format::int16,
                                       audio::pcm_format::fixed824};
    bool interleaveds[] = {YES, NO};
#endif

    test::audio_file_test_data test_data;
    test_data.frame_length = 8;
    test_data.loop_count = 4;
    test_data.file_name = "test.wav";
    test_data.set_file_type(audio::file_type_cf_string::wave);
    test_data.standard = NO;
    test_data.async = NO;

    for (double file_sample_rate : sample_rates) {
        for (double processing_sample_rate : sample_rates) {
            for (uint32_t channel : channels) {
                for (uint32_t file_bit_depth : file_bit_depths) {
                    for (audio::pcm_format pcm_format : pcm_formats) {
                        for (bool interleved : interleaveds) {
                            test_data.file_sample_rate = file_sample_rate;
                            test_data.channels = channel;
                            test_data.file_bit_depth = file_bit_depth;
                            test_data.processing_sample_rate = processing_sample_rate;
                            test_data.pcm_format = pcm_format;
                            test_data.interleaved = interleved;
                            @autoreleasepool {
                                [self _commonAudioFileTest:test_data];
                            }
                        }
                    }
                }
            }
        }
    }

    test_data.standard = YES;
    test_data.file_sample_rate = 48000;
    test_data.channels = 2;
    test_data.file_bit_depth = 32;
    test_data.processing_sample_rate = 44100;
    test_data.pcm_format = audio::pcm_format::float32;
    test_data.interleaved = NO;

    [self _commonAudioFileTest:test_data];
#if !WAVEFILE_LIGHT_TEST
    test_data.async = YES;
    [self _commonAudioFileTest:test_data];
#endif
}

- (void)test_make_create_and_open_file {
    auto const file_name = "test.wav";
    auto file_url = test::temporary_test_dir_url().appending(file_name);

    {
        auto file_result = audio::make_created_file({.file_url = file_url,
                                                     .file_type = audio::file_type_cf_string::wave,
                                                     .settings = audio::wave_file_settings(48000.0, 2, 16)});
        XCTAssertTrue(file_result);

        auto file = file_result.value();

        XCTAssertEqual(file.url(), file_url);
        XCTAssertTrue(CFEqual(file.file_type(), audio::file_type_cf_string::wave));
        auto const &file_format = file.file_format();
        XCTAssertEqual(file_format.buffer_count(), 1);
        XCTAssertEqual(file_format.channel_count(), 2);
        XCTAssertEqual(file_format.sample_rate(), 48000.0);
        XCTAssertEqual(file_format.pcm_format(), audio::pcm_format::int16);
        XCTAssertEqual(file_format.is_interleaved(), true);
    }

    {
        auto file_result = audio::make_opened_file({.file_url = file_url});
        XCTAssertTrue(file_result);

        auto file = file_result.value();

        XCTAssertEqual(file.url(), file_url);
        XCTAssertTrue(CFEqual(file.file_type(), audio::file_type_cf_string::wave));
        auto const &file_format = file.file_format();
        XCTAssertEqual(file_format.buffer_count(), 1);
        XCTAssertEqual(file_format.channel_count(), 2);
        XCTAssertEqual(file_format.sample_rate(), 48000.0);
        XCTAssertEqual(file_format.pcm_format(), audio::pcm_format::int16);
        XCTAssertEqual(file_format.is_interleaved(), true);
    }
}

- (void)test_read_into_buffer_error_frame_length_out_of_range {
    auto const file_name = "test.wav";
    auto file_url = test::temporary_test_dir_url().appending(file_name);

    auto file_result = audio::make_created_file({.file_url = file_url,
                                                 .file_type = audio::file_type_cf_string::wave,
                                                 .settings = audio::wave_file_settings(48000.0, 2, 16)});

    auto &file = file_result.value();

    uint32_t const frame_capacity = 10;
    audio::pcm_buffer buffer{file.processing_format(), frame_capacity};

    auto result = file.read_into_buffer(buffer, 11);
    XCTAssertFalse(result);
    XCTAssertEqual(result.error(), audio::file::read_error_t::frame_length_out_of_range);
}

- (void)test_open_error_to_string {
    XCTAssertEqual(to_string(audio::file::open_error_t::opened), "opened");
    XCTAssertEqual(to_string(audio::file::open_error_t::invalid_argument), "invalid_argument");
    XCTAssertEqual(to_string(audio::file::open_error_t::open_failed), "open_failed");
}

- (void)test_read_error_to_string {
    XCTAssertEqual(to_string(audio::file::read_error_t::closed), "closed");
    XCTAssertEqual(to_string(audio::file::read_error_t::invalid_argument), "invalid_argument");
    XCTAssertEqual(to_string(audio::file::read_error_t::invalid_format), "invalid_format");
    XCTAssertEqual(to_string(audio::file::read_error_t::read_failed), "read_failed");
    XCTAssertEqual(to_string(audio::file::read_error_t::tell_failed), "tell_failed");
    XCTAssertEqual(to_string(audio::file::read_error_t::frame_length_out_of_range), "frame_length_out_of_range");
}

- (void)test_create_error_to_string {
    XCTAssertEqual(to_string(audio::file::create_error_t::created), "created");
    XCTAssertEqual(to_string(audio::file::create_error_t::invalid_argument), "invalid_argument");
    XCTAssertEqual(to_string(audio::file::create_error_t::create_failed), "create_failed");
}

- (void)test_write_error_to_string {
    XCTAssertEqual(to_string(audio::file::write_error_t::closed), "closed");
    XCTAssertEqual(to_string(audio::file::write_error_t::invalid_argument), "invalid_argument");
    XCTAssertEqual(to_string(audio::file::write_error_t::invalid_format), "invalid_format");
    XCTAssertEqual(to_string(audio::file::write_error_t::write_failed), "write_failed");
    XCTAssertEqual(to_string(audio::file::write_error_t::tell_failed), "tell_failed");
}

- (void)test_open_error_ostream {
    auto const errors = {audio::file::open_error_t::opened, audio::file::open_error_t::invalid_argument,
                         audio::file::open_error_t::open_failed};

    for (auto const &error : errors) {
        std::ostringstream stream;
        stream << error;
        XCTAssertEqual(stream.str(), to_string(error));
    }
}

- (void)test_read_error_ostream {
    auto const errors = {audio::file::read_error_t::closed, audio::file::read_error_t::invalid_argument,
                         audio::file::read_error_t::invalid_format, audio::file::read_error_t::read_failed,
                         audio::file::read_error_t::tell_failed};

    for (auto const &error : errors) {
        std::ostringstream stream;
        stream << error;
        XCTAssertEqual(stream.str(), to_string(error));
    }
}

- (void)test_create_error_ostream {
    auto const errors = {audio::file::create_error_t::created, audio::file::create_error_t::invalid_argument,
                         audio::file::create_error_t::create_failed};

    for (auto const &error : errors) {
        std::ostringstream stream;
        stream << error;
        XCTAssertEqual(stream.str(), to_string(error));
    }
}

- (void)test_write_error_ostream {
    auto const errors = {audio::file::write_error_t::closed, audio::file::write_error_t::invalid_argument,
                         audio::file::write_error_t::invalid_format, audio::file::write_error_t::write_failed,
                         audio::file::write_error_t::tell_failed};

    for (auto const &error : errors) {
        std::ostringstream stream;
        stream << error;
        XCTAssertEqual(stream.str(), to_string(error));
    }
}

#pragma mark -

- (void)_commonAudioFileTest:(test::audio_file_test_data &)test_data {
    auto file_url = test::temporary_test_dir_url().appending(test_data.file_name);
    uint32_t const frame_length = test_data.frame_length;
    uint32_t const loopCount = test_data.loop_count;
    double const file_sample_rate = test_data.file_sample_rate;
    double const processing_sample_rate = test_data.processing_sample_rate;
    audio::pcm_format const pcm_format = test_data.pcm_format;
    bool const interleaved = test_data.interleaved;
    bool const async = test_data.async;
    CFDictionaryRef settings = test_data.settings();

    auto const default_processing_format = audio::format({.sample_rate = file_sample_rate,
                                                          .channel_count = test_data.channels,
                                                          .pcm_format = pcm_format,
                                                          .interleaved = interleaved});
    auto const processing_format = audio::format({.sample_rate = processing_sample_rate,
                                                  .channel_count = test_data.channels,
                                                  .pcm_format = pcm_format,
                                                  .interleaved = interleaved});

    // write

    @autoreleasepool {
        audio::file audio_file;

        if (test_data.standard) {
            XCTAssertTrue(
                audio_file.create({.file_url = file_url, .file_type = test_data.file_type(), .settings = settings}));
        } else {
            XCTAssertTrue(audio_file.create({.file_url = file_url,
                                             .file_type = test_data.file_type(),
                                             .settings = settings,
                                             .pcm_format = pcm_format,
                                             .interleaved = interleaved}));
        }

        XCTAssertTrue(audio_file.processing_format() == default_processing_format);

        audio_file.set_processing_format(processing_format);

        audio::pcm_buffer buffer(processing_format, frame_length);

        uint32_t startIndex = 0;

        for (NSInteger i = 0; i < loopCount; i++) {
            [self _writeToBuffer:buffer fileFormat:audio_file.file_format() startIndex:startIndex];

            XCTAssertTrue(audio_file.write_from_buffer(buffer, async));

            startIndex += frame_length;
        }
    }

    // read

    @autoreleasepool {
        audio::file audio_file;

        if (test_data.standard) {
            XCTAssertTrue(audio_file.open({.file_url = file_url}));
        } else {
            XCTAssertTrue(
                audio_file.open({.file_url = file_url, .pcm_format = pcm_format, .interleaved = interleaved}));
        }

        int64_t looped_frame_length = frame_length * loopCount;
        XCTAssertEqualWithAccuracy(audio_file.file_length(),
                                   (int64_t)(looped_frame_length * (file_sample_rate / processing_sample_rate)), 1);

        audio_file.set_processing_format(processing_format);

        XCTAssertEqualWithAccuracy(audio_file.processing_length(),
                                   audio_file.file_length() * (processing_sample_rate / file_sample_rate), 1);

        audio::pcm_buffer buffer(processing_format, frame_length);

        uint32_t startIndex = 0;

        for (NSInteger i = 0; i < loopCount; i++) {
            XCTAssertTrue(audio_file.read_into_buffer(buffer));
            if (test_data.file_sample_rate == test_data.processing_sample_rate) {
                XCTAssert(buffer.frame_length() == frame_length);
                XCTAssert([self _compareData:buffer fileFormat:audio_file.file_format() startIndex:startIndex]);
            }

            startIndex += frame_length;
        }

        audio_file.set_file_frame_position(0);
        XCTAssertEqual(audio_file.file_frame_position(), 0);
    }
}

#pragma mark -

- (void)_writeToBuffer:(audio::pcm_buffer &)buffer
            fileFormat:(audio::format const &)fileFormat
            startIndex:(NSInteger)startIndex {
    auto const &format = buffer.format();
    uint32_t const buffer_count = format.buffer_count();
    uint32_t const stride = format.stride();

    for (uint32_t buf_idx = 0; buf_idx < buffer_count; buf_idx++) {
        for (NSInteger frameIndex = 0; frameIndex < buffer.frame_length(); frameIndex++) {
            int16_t value = frameIndex + startIndex + 1;
            for (NSInteger ch_idx = 0; ch_idx < stride; ch_idx++) {
                switch (format.pcm_format()) {
                    case audio::pcm_format::int16: {
                        auto *ptr = buffer.data_ptr_at_index<int16_t>(buf_idx);
                        ptr[frameIndex * stride + ch_idx] = value;
                    } break;
                    case audio::pcm_format::fixed824: {
                        auto *ptr = buffer.data_ptr_at_index<int32_t>(buf_idx);
                        ptr[frameIndex * stride + ch_idx] = value << 16;
                    } break;
                    case audio::pcm_format::float32: {
                        auto *ptr = buffer.data_ptr_at_index<float>(buf_idx);
                        float float32Value = (float)value / INT16_MAX;
                        ptr[frameIndex * stride + ch_idx] = float32Value;
                    } break;
                    case audio::pcm_format::float64: {
                        auto *ptr = buffer.data_ptr_at_index<double>(buf_idx);
                        double float64Value = (double)value / INT16_MAX;
                        ptr[frameIndex * stride + ch_idx] = (double)float64Value;
                    } break;
                    default:
                        break;
                }
            }
        }
    }
}

- (bool)_compareData:(audio::pcm_buffer const &)buffer
          fileFormat:(audio::format const &)fileFormat
          startIndex:(NSInteger)startIndex {
    auto const &format = buffer.format();
    uint32_t const buffer_count = format.buffer_count();
    uint32_t const stride = format.stride();

    for (uint32_t buf_idx = 0; buf_idx < buffer_count; buf_idx++) {
        for (NSInteger frameIndex = 0; frameIndex < buffer.frame_length(); frameIndex++) {
            int16_t value = frameIndex + startIndex + 1;
            for (NSInteger ch_idx = 0; ch_idx < stride; ch_idx++) {
                int16_t ptrValue = 0;
                switch (format.pcm_format()) {
                    case audio::pcm_format::int16: {
                        ptrValue = buffer.data_ptr_at_index<int16_t>(buf_idx)[frameIndex * stride + ch_idx];
                    } break;
                    case audio::pcm_format::fixed824: {
                        ptrValue = buffer.data_ptr_at_index<int32_t>(buf_idx)[frameIndex * stride + ch_idx] >> 16;
                    } break;
                    case audio::pcm_format::float32: {
                        ptrValue =
                            roundf(buffer.data_ptr_at_index<float>(buf_idx)[frameIndex * stride + ch_idx] * INT16_MAX);
                    } break;
                    case audio::pcm_format::float64: {
                        ptrValue =
                            round(buffer.data_ptr_at_index<double>(buf_idx)[frameIndex * stride + ch_idx] * INT16_MAX);
                    } break;
                    default:
                        break;
                }
                if (value != ptrValue) {
                    return NO;
                }
            }
        }
    }
    return YES;
}

@end
