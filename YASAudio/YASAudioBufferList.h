
/**
 * @class YASAudioBufferList
 * @author Yuki Yasoshima
 */

#import <Foundation/Foundation.h>

/*! AudioBufferListのラッパーです */
@interface YASAudioBufferList : NSObject

@property (nonatomic, assign, readonly) NSUInteger bufferCount; //!< バッファの数
@property (nonatomic, assign, readonly) NSUInteger channels; //!< １つのバッファのチャンネル数
@property (nonatomic, assign, readonly) NSUInteger bufferSize; //!< １つのバッファのバイトサイズ

//! YASAudioBufferListのインスタンスを生成して返します
+ (id)audioBufferListWithBufferCount:(NSUInteger)bufferCount channels:(NSUInteger)ch bufferSize:(NSUInteger)size;

//! 初期化します
- (id)initWithBufferCount:(NSUInteger)bufferCount channels:(NSUInteger)ch bufferSize:(NSUInteger)size;

//! バッファの先頭のポインタを取得します
- (void *)dataAtBufferIndex:(NSUInteger)bufferIndex;


/**
 * @fn audioBufferListWithBufferCount:channels:bufferSize:
 * @param bufferCount バッファの数
 * @param ch バッファ１つのチャンネル数
 * @param size バッファ１つのバイトサイズ
 */

/**
 * @fn initWithBufferCount:channels:bufferSize:
 * @param bufferCount バッファの数
 * @param ch バッファ１つのチャンネル数
 * @param size バッファ１つのバイトサイズ
 */

/**
 * @fn dataAtBufferIndex:
 * @param bufferIndex 取得するバッファのインデックス
 */

@end
