//
//  yas_audio_file_tests.m
//

#import "yas_audio_test_utils.h"

using namespace yas;

namespace yas {
namespace test {
    struct audio_file_test_data {
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

        audio_file_test_data() : _file_name(nullptr), _file_type(nullptr) {
        }

        ~audio_file_test_data() {
            set_file_type(nullptr);
            set_file_name(nullptr);
        }

        void set_file_type(const CFStringRef file_type) {
            set_cf_property(_file_type, file_type);
        }

        CFStringRef file_type() const {
            return get_cf_property(_file_type);
        }

        void set_file_name(const CFStringRef file_name) {
            set_cf_property(_file_name, file_name);
        }

        CFStringRef file_name() const {
            return get_cf_property(_file_name);
        }

        CFDictionaryRef settings() const {
            if (CFStringCompare(file_type(), audio::file_type::wave, kNilOptions) == kCFCompareEqualTo) {
                return audio::wave_file_settings(file_sample_rate, channels, file_bit_depth);
            } else if (CFStringCompare(file_type(), audio::file_type::aiff, kNilOptions) == kCFCompareEqualTo) {
                return audio::aiff_file_settings(file_sample_rate, channels, file_bit_depth);
            }
            return nullptr;
        }

       private:
        CFStringRef _file_type;
        CFStringRef _file_name;
    };
}
}

@interface yas_audio_file_tests : XCTestCase

@end

@implementation yas_audio_file_tests

- (void)setUp {
    [super setUp];

    [self setupDirectory];
}

- (void)tearDown {
    [self removeAllFiles];

    [super tearDown];
}

- (void)testWAVEFile {
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
    test_data.set_file_name(CFSTR("test.wav"));
    test_data.set_file_type(audio::file_type::wave);
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
    auto file_name = CFSTR("test.wav");
    NSString *filePath = [[self temporaryTestDirectory] stringByAppendingPathComponent:(__bridge NSString *)file_name];
    CFURLRef fileURL = (__bridge CFURLRef)[NSURL fileURLWithPath:filePath];

    {
        auto file = audio::create_file({.file_url = fileURL,
                                        .file_type = audio::file_type::wave,
                                        .settings = audio::wave_file_settings(48000.0, 2, 16)});

        XCTAssertTrue(CFEqual(file.url(), fileURL));
        XCTAssertTrue(CFEqual(file.file_type(), audio::file_type::wave));
        auto const &file_format = file.file_format();
        XCTAssertEqual(file_format.buffer_count(), 1);
        XCTAssertEqual(file_format.channel_count(), 2);
        XCTAssertEqual(file_format.sample_rate(), 48000.0);
        XCTAssertEqual(file_format.pcm_format(), audio::pcm_format::int16);
        XCTAssertEqual(file_format.is_interleaved(), true);
    }

    if (auto file = audio::open_file({.file_url = fileURL})) {
        XCTAssertTrue(CFEqual(file.url(), fileURL));
        XCTAssertTrue(CFEqual(file.file_type(), audio::file_type::wave));
        auto const &file_format = file.file_format();
        XCTAssertEqual(file_format.buffer_count(), 1);
        XCTAssertEqual(file_format.channel_count(), 2);
        XCTAssertEqual(file_format.sample_rate(), 48000.0);
        XCTAssertEqual(file_format.pcm_format(), audio::pcm_format::int16);
        XCTAssertEqual(file_format.is_interleaved(), true);
    }
}

#pragma mark -

- (void)_commonAudioFileTest:(test::audio_file_test_data &)test_data {
    NSString *filePath =
        [[self temporaryTestDirectory] stringByAppendingPathComponent:(__bridge NSString *)test_data.file_name()];
    CFURLRef fileURL = (__bridge CFURLRef)[NSURL fileURLWithPath:filePath];
    const uint32_t frame_length = test_data.frame_length;
    const uint32_t loopCount = test_data.loop_count;
    const double file_sample_rate = test_data.file_sample_rate;
    const double processing_sample_rate = test_data.processing_sample_rate;
    const audio::pcm_format pcm_format = test_data.pcm_format;
    const bool interleaved = test_data.interleaved;
    const bool async = test_data.async;
    CFDictionaryRef settings = test_data.settings();

    auto default_processing_format = audio::format(file_sample_rate, test_data.channels, pcm_format, interleaved);
    auto processing_format = audio::format(processing_sample_rate, test_data.channels, pcm_format, interleaved);

    // write

    @autoreleasepool {
        audio::file audio_file;

        if (test_data.standard) {
            XCTAssertTrue(
                audio_file.create({.file_url = fileURL, .file_type = test_data.file_type(), .settings = settings}));
        } else {
            XCTAssertTrue(audio_file.create({.file_url = fileURL,
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
            XCTAssertTrue(audio_file.open({.file_url = fileURL}));
        } else {
            XCTAssertTrue(audio_file.open({.file_url = fileURL, .pcm_format = pcm_format, .interleaved = interleaved}));
        }

        SInt64 looped_frame_length = frame_length * loopCount;
        XCTAssertEqualWithAccuracy(audio_file.file_length(),
                                   (SInt64)(looped_frame_length * (file_sample_rate / processing_sample_rate)), 1);

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
            fileFormat:(const audio::format &)fileFormat
            startIndex:(NSInteger)startIndex {
    const auto &format = buffer.format();
    const uint32_t buffer_count = format.buffer_count();
    const uint32_t stride = format.stride();

    for (uint32_t buf_idx = 0; buf_idx < buffer_count; buf_idx++) {
        auto pointer = buffer.flex_ptr_at_index(buf_idx);
        for (NSInteger frameIndex = 0; frameIndex < buffer.frame_length(); frameIndex++) {
            SInt16 value = frameIndex + startIndex + 1;
            for (NSInteger ch_idx = 0; ch_idx < stride; ch_idx++) {
                switch (format.pcm_format()) {
                    case audio::pcm_format::int16: {
                        pointer.i16[frameIndex * stride + ch_idx] = value;
                    } break;
                    case audio::pcm_format::fixed824: {
                        pointer.i32[frameIndex * stride + ch_idx] = value << 16;
                    } break;
                    case audio::pcm_format::float32: {
                        float float32Value = (float)value / INT16_MAX;
                        pointer.f32[frameIndex * stride + ch_idx] = float32Value;
                    } break;
                    case audio::pcm_format::float64: {
                        double float64Value = (double)value / INT16_MAX;
                        pointer.f64[frameIndex * stride + ch_idx] = (double)float64Value;
                    } break;
                    default:
                        break;
                }
            }
        }
    }
}

- (bool)_compareData:(audio::pcm_buffer &)buffer
          fileFormat:(const audio::format &)fileFormat
          startIndex:(NSInteger)startIndex {
    const auto &format = buffer.format();
    const uint32_t buffer_count = format.buffer_count();
    const uint32_t stride = format.stride();

    for (uint32_t buf_idx = 0; buf_idx < buffer_count; buf_idx++) {
        const auto pointer = buffer.flex_ptr_at_index(buf_idx);
        for (NSInteger frameIndex = 0; frameIndex < buffer.frame_length(); frameIndex++) {
            SInt16 value = frameIndex + startIndex + 1;
            for (NSInteger ch_idx = 0; ch_idx < stride; ch_idx++) {
                SInt16 ptrValue = 0;
                switch (format.pcm_format()) {
                    case audio::pcm_format::int16: {
                        ptrValue = pointer.i16[frameIndex * stride + ch_idx];
                    } break;
                    case audio::pcm_format::fixed824: {
                        ptrValue = pointer.i32[frameIndex * stride + ch_idx] >> 16;
                    } break;
                    case audio::pcm_format::float32: {
                        ptrValue = roundf(pointer.f32[frameIndex * stride + ch_idx] * INT16_MAX);
                    } break;
                    case audio::pcm_format::float64: {
                        ptrValue = round(pointer.f64[frameIndex * stride + ch_idx] * INT16_MAX);
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

#pragma mark -

- (NSString *)temporaryTestDirectory {
    return [NSTemporaryDirectory() stringByAppendingPathComponent:@"yas_audio_test_files"];
}

- (void)setupDirectory {
    [self removeAllFiles];

    NSString *path = [self temporaryTestDirectory];

    NSFileManager *fileManager = [[NSFileManager alloc] init];

    [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];

    yas_release(fileManager);
}

- (void)removeAllFiles {
    NSString *path = [self temporaryTestDirectory];

    NSFileManager *fileManager = [[NSFileManager alloc] init];

    for (NSString *fileName in [fileManager contentsOfDirectoryAtPath:path error:nil]) {
        NSString *fullPath = [path stringByAppendingPathComponent:fileName];
        [fileManager removeItemAtPath:fullPath error:nil];
    }

    [fileManager removeItemAtPath:path error:nil];

    yas_release(fileManager);
}

@end
