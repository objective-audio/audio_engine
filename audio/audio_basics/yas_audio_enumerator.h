//
//  yas_audio_enumerator.h
//

#pragma once

#include <vector>
#include "yas_audio_types.h"
#include "yas_flex_ptr.h"

namespace yas {
namespace audio {
    class pcm_buffer;

    class enumerator {
       public:
        enumerator(flex_ptr const &pointer, uint32_t const byte_stride, uint32_t const length);
        enumerator(pcm_buffer const &buffer, uint32_t const channel);

        flex_ptr const *pointer() const;
        uint32_t const *index() const;
        uint32_t length() const;

        void move();
        void stop();
        void set_position(uint32_t const index);
        void reset();

        enumerator &operator++();

        flex_ptr _pointer;
        flex_ptr _top_pointer;
        uint32_t _byte_stride;
        uint32_t _length;
        uint32_t _index;
    };

    class frame_enumerator {
       public:
        explicit frame_enumerator(pcm_buffer const &buffer);

        flex_ptr const *pointer() const;
        uint32_t const *frame() const;
        uint32_t const *channel() const;
        uint32_t frame_length() const;
        uint32_t channel_count() const;

        void move_frame();
        void move_channel();
        void move();
        void stop();
        void set_frame_position(uint32_t const frame);
        void set_channel_position(uint32_t const channel);
        void reset();

        frame_enumerator &operator++();

        flex_ptr _pointer;
        std::vector<flex_ptr> _pointers;
        std::vector<flex_ptr> _top_pointers;
        uint32_t _pointers_size;
        uint32_t _frame_byte_stride;
        uint32_t _frame_length;
        uint32_t _frame;
        uint32_t _channel;
        uint32_t _channel_count;
    };
}
}

#define yas_audio_enumerator_move(__v)           \
    if (++(__v)._index >= (__v)._length) {       \
        (__v)._pointer.v = nullptr;              \
    } else {                                     \
        (__v)._pointer.u8 += (__v)._byte_stride; \
    }

#define yas_audio_enumerator_stop(__v) \
    (__v)._pointer.v = nullptr;        \
    (__v)._index = (__v)._length;

#define yas_audio_enumerator_reset(__v) \
    (__v)._index = 0;                   \
    (__v)._pointer.v = (__v)._top_pointer.v;

#define yas_audio_frame_enumerator_move_frame(__v)                 \
    if (++(__v)._frame >= (__v)._frame_length) {                   \
        memset(&(__v)._pointers[0], 0, (__v)._pointers_size);      \
        (__v)._pointer.v = nullptr;                                \
    } else {                                                       \
        uint32_t index = (__v)._channel_count;                     \
        while (index--) {                                          \
            (__v)._pointers[index].u8 += (__v)._frame_byte_stride; \
        }                                                          \
        if ((__v)._pointer.v) {                                    \
            (__v)._pointer.v = (__v)._pointers[(__v)._channel].v;  \
        } else {                                                   \
            (__v)._channel = 0;                                    \
            (__v)._pointer.v = (__v)._pointers[0].v;               \
        }                                                          \
    }

#define yas_audio_frame_enumerator_move_channel(__v)          \
    if (++(__v)._channel >= (__v)._channel_count) {           \
        (__v)._pointer.v = nullptr;                           \
    } else {                                                  \
        (__v)._pointer.v = (__v)._pointers[(__v)._channel].v; \
    }

#define yas_audio_frame_enumerator_move(__v)        \
    yas_audio_frame_enumerator_move_channel(__v);   \
    if (!(__v)._pointer.v) {                        \
        yas_audio_frame_enumerator_move_frame(__v); \
    }

#define yas_audio_frame_enumerator_stop(__v) \
    (__v)._pointer.v = nullptr;              \
    (__v)._frame = (__v)._frame_length;      \
    (__v)._channel = (__v)._channel_count;

#define yas_audio_frame_enumerator_reset(__v)                                                             \
    (__v)._frame = 0;                                                                                     \
    (__v)._channel = 0;                                                                                   \
    memcpy(&(__v)._pointers[0], &(__v)._top_pointers[0], (__v)._channel_count * sizeof(yas::flex_ptr *)); \
    (__v)._pointer.v = (__v)._pointers[0].v;
