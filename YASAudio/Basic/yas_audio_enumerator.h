//
//  yas_audio_enumerator.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_types.h"
#include "yas_audio_pcm_buffer.h"
#include "yas_flex_ptr.h"
#include <vector>

namespace yas
{
    class audio_enumerator
    {
       public:
        audio_enumerator(const flex_ptr &pointer, const UInt32 byte_stride, const UInt32 length);
        audio_enumerator(const audio_pcm_buffer &buffer, const UInt32 channel);

        const flex_ptr *pointer() const;
        const UInt32 *index() const;
        const UInt32 length() const;

        void move();
        void stop();
        void set_position(const UInt32 index);
        void reset();

        audio_enumerator &operator++();

        flex_ptr _pointer;
        flex_ptr _top_pointer;
        UInt32 _byte_stride;
        UInt32 _length;
        UInt32 _index;
    };

    class audio_frame_enumerator
    {
       public:
        explicit audio_frame_enumerator(const audio_pcm_buffer &buffer);

        const flex_ptr *pointer() const;
        const UInt32 *frame() const;
        const UInt32 *channel() const;
        const UInt32 frame_length() const;
        const UInt32 channel_count() const;

        void move_frame();
        void move_channel();
        void move();
        void stop();
        void set_frame_position(const UInt32 frame);
        void set_channel_position(const UInt32 channel);
        void reset();

        audio_frame_enumerator &operator++();

        flex_ptr _pointer;
        std::vector<flex_ptr> _pointers;
        std::vector<flex_ptr> _top_pointers;
        UInt32 _pointers_size;
        UInt32 _frame_byte_stride;
        UInt32 _frame_length;
        UInt32 _frame;
        UInt32 _channel;
        UInt32 _channel_count;
    };
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
        UInt32 index = (__v)._channel_count;                       \
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
