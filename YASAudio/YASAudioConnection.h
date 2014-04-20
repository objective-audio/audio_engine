
/**
 * @class YASAudioConnection
 * @author Yuki Yasoshima
 */

#import <Foundation/Foundation.h>

@class YASAudioNode;

//! オーディオグラフのノードの接続情報です
@interface YASAudioConnection : NSObject

@property (nonatomic, strong) YASAudioNode *sourceNode; //!< 接続元のノードです
@property (nonatomic, assign) UInt32 sourceOutputNumber; //!< 接続元のバス番号です
@property (nonatomic, strong) YASAudioNode *destNode; //!< 接続先のノードです
@property (nonatomic, assign) UInt32 destInputNumber; //!< 接続先のバス番号です

@end

/**
 * @class YASAudioConnection
 * 直接生成はせず、YASAudioGraphのaddConnectionWithSourceNode:sourceOutputNumber:destNode:destInputNumber:メソッドから取得してください。<br>
 */
