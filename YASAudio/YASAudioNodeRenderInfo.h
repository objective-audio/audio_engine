
/**
 * @class YASAudioNodeRenderInfo
 * @author Yuki Yasoshima
 */

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

//! レンダーの種類
NS_ENUM(NSUInteger, YASAudioNodeRenderType) {
    YASAudioNodeRenderTypeNormal, //!< 通常のインプット側
    YASAudioNodeRenderTypeInput, //!< RemoteIOの音声入力側(Scopeはoutput)
    YASAudioNodeRenderTypeNotify, //!< 通知
    YASAudioNodeRenderTypeUnknown, //!< 不明
};

//! ノードのレンダー情報です
@interface YASAudioNodeRenderInfo : NSObject

@property (nonatomic, copy, readonly) NSString *graphKey; //!< グラフのKey
@property (nonatomic, copy, readonly) NSString *nodeKey; //!< ノードのKey

@property (nonatomic, assign) enum YASAudioNodeRenderType renderType; //!< レンダーの種類

@property (nonatomic, assign) AudioUnitRenderActionFlags *ioActionFlags; //!< コールバックの種類
@property (nonatomic, assign) const AudioTimeStamp *inTimeStamp; //!< タイムスタンプ
@property (nonatomic, assign) UInt32 inBusNumber; //!< バス番号
@property (nonatomic, assign) UInt32 inNumberFrames; //!< 処理するフレーム数
@property (nonatomic, assign) AudioBufferList *ioData; //!< オーディオデータ

//! 初期化します。YASAudio内部でのみ使用されます
- (id)initWithGraphKey:(NSString *)graphKey nodeKey:(NSString *)nodeKey;

@end


/**
 * @class YASAudioNodeRenderInfo
 *  レンダーコールバックの引数に使用されます。<br>
 *  YASAudio内部で生成されますので、生成の必要はありません。
 */
