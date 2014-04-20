
/**
 * @class YASAudioBufferList
 * @author Yuki Yasoshima
 */

#import <Foundation/Foundation.h>

/*! AudioBufferListのラッパーです */
@interface YASAudioBufferList : NSObject

@property (nonatomic, assign, readonly) NSUInteger bufferCount; /*!< バッファの数 */
@property (nonatomic, assign, readonly) NSUInteger channels; /*!< １つのバッファのチャンネル数 */
@property (nonatomic, assign, readonly) NSUInteger bufferSize; /*!< １つのバッファのバイトサイズ */

/*! 初期化してインスタンスを返します */
+ (id)audioBufferListWithBufferCount:(NSUInteger)bufferCount channels:(NSUInteger)ch bufferSize:(NSUInteger)size;

/*! 初期化します */
- (id)initWithBufferCount:(NSUInteger)bufferCount channels:(NSUInteger)ch bufferSize:(NSUInteger)size;

/*! バッファの先頭のポインタを取得します */
- (void *)dataAtBufferIndex:(NSUInteger)bufferIndex;

@end
