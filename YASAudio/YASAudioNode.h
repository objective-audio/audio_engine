
/**
 * @class YASAudioNode
 * @author Yuki Yasoshima
 */

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@class YASAudioNodeRenderInfo, YASAudioGraph;

//! AudioUnitのレンダーコールバックの引数そのままを渡して処理するブロック
typedef void (^YASAudioNodeRenderCallbackBlock)(YASAudioNodeRenderInfo *renderInfo);

//! オーディオグラフのノードです
@interface YASAudioNode : NSObject

@property (nonatomic, assign, readonly) YASAudioGraph *graph; //!< このノードが保持されているグラフです
@property (nonatomic, strong, readonly) NSString *identifier; //!< ノードを識別するためのIDです
@property (nonatomic, assign, readonly) AUNode node; //!< AUNodeを取得します
@property (nonatomic, assign, readonly) AudioUnit audioUnit; //!< AudioUnitを取得します

@property (nonatomic, copy) YASAudioNodeRenderCallbackBlock renderCallbackBlock; //!< レンダーコールバックの処理ブロックです
@property (nonatomic, copy) YASAudioNodeRenderCallbackBlock notifyRenderCallbackBlock; //!< 通知の処理ブロックです

//! 指定したバス番号のRenderCallbackが呼ばれるようにします
- (void)setRenderCallback:(UInt32)inputNumber;

//! 指定したバス番号のRenderCallbackの呼び出しを取り除きます
- (void)removeRenderCallback:(UInt32)inputNumber;

//! RenderNotifyを追加します
- (void)addRenderNotify;

//! RenderNotifyを取り除きます
- (void)removeRenderNotify;

//! 入力側のフォーマットをセットします
- (void)setInputFormat:(AudioStreamBasicDescription *)inAsbd busNumber:(UInt32)bus;

//! 出力側のフォーマットをセットします
- (void)setOutputFormat:(AudioStreamBasicDescription *)inAsbd busNumber:(UInt32)bus;

//! 入力側のフォーマットを取得します
- (void)getInputFormat:(AudioStreamBasicDescription *)outAsbd busNumber:(UInt32)bus;

//! 出力側のフォーマットを取得します
- (void)getOutputFormat:(AudioStreamBasicDescription *)outAsbd busNumber:(UInt32)bus;

//! スライスごとの最大フレーム数をセットする
- (void)setMaximumFramesPerSlice:(UInt32)frames;

//! パラメータをセットする
- (void)setParameter:(AudioUnitParameterID)parameterID value:(AudioUnitParameterValue)val scope:(AudioUnitScope)scope element:(AudioUnitElement)element;

//! グローバルのパラメータをセットする
- (void)setGlobalParameter:(AudioUnitParameterID)parameterID value:(AudioUnitParameterValue)val;

//! パラメータを取得する
- (Float32)getParameter:(AudioUnitParameterID)parameterID scope:(AudioUnitScope)scope element:(AudioUnitElement)element;


#pragma mark - ミキサー用

//! 入力側のelementの数をセットします
- (void)setInputElementCount:(UInt32)count;


#pragma mark - YASAudio内部でのみ使用されるもの

//! renderCallbackBlockを呼び出します
- (void)render:(YASAudioNodeRenderInfo *)renderInfo;

//! 初期化します
- (instancetype)initWithGraph:(YASAudioGraph *)graph acd:(AudioComponentDescription *)acd;

//! AUGraphから取り除きます
- (void)remove;

@end

#pragma mark - RemoteIOのノード

//! オーディオグラフのIOノードです
@interface YASAudioIONode : YASAudioNode

@property (nonatomic, copy) YASAudioNodeRenderCallbackBlock inputRenderCallbackBlock;

@property (nonatomic, assign, getter = isEnableOutput) BOOL enableOutput; //!< セットはグラフ動作開始前に行ってください
@property (nonatomic, assign, getter = isEnableInput) BOOL enableInput; //!< セットはグラフ動作開始前に行ってください

//! RemoteIOの入力を受け取るコールバックをセットします
- (void)setInputCallback;

//! RemoteIOの入力を受け取るコールバックを取り除きます
- (void)removeInputCallback;

//! チャンネルマップを取得します
- (NSArray *)outputChannelMap;

//! チャンネルマップをセットします
- (void)setOutputChannelMap:(NSArray *)mapArray;

@end

/**
 * @class YASAudioNode
 * 直接生成はせず、YASAudioGraphのaddNodeWithType:メソッドから取得してください。
 */
