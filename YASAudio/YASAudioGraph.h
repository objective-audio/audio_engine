
/**
 *
 * @class YASAudioGraph
 *
 *  AUGraphを管理します
 *
 * @author Yuki Yasoshima
 *
 */

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "YASAudioNode.h"

@class YASAudioConnection;

@interface YASAudioGraph : NSObject

@property (nonatomic, strong, readonly) NSString *identifier;
@property (nonatomic, assign, readonly) AUGraph graph; /*!< 保持しているAUGraphです */
@property (nonatomic, strong, readonly) YASAudioIONode *ioNode; /*!< RemoteIOのノード */
@property (nonatomic, assign) BOOL running; /*!< グラフ動作中フラグです */

/*! 名前を指定して生成したグラフのインスタンスを返します。 */
+ (id)graph;

/*! 名前を指定して初期化します。 */
- (id)init;

/*! グラフを破棄する前に、グラフを無効にします。このメソッドを呼び出さないと解放されません。 */
- (void)invalidate;

/*! ノードを生成・追加して返します。Type（kAudioUnitType_〜）、SubType（kAudioUnitSubType_〜） */
- (YASAudioNode *)addNodeWithType:(OSType)type subType:(OSType)subType;

/*! ノードを取り除きます */
- (void)removeNode:(YASAudioNode *)node;

/*! ノードを取得します */
- (YASAudioNode *)nodeForKey:(NSString *)key;

/*! ノードの接続情報を生成・追加して返します。 */
- (YASAudioConnection *)addConnectionWithSourceNode:(YASAudioNode *)sourceNode sourceOutputNumber:(UInt32)sourceOutputNumber destNode:(YASAudioNode *)destNode destInputNumber:(UInt32)destInputNumber;

/*! ノード接続情報を取り除きます。 */
- (void)removeConnection:(YASAudioConnection *)connection;

/*! グラフの接続を更新します。 */
- (void)update;


#pragma mark - YASAudio内部でのみ使用されるメソッド

/*! ノードのレンダー情報オブジェクトが存在するかを調べます */
+ (BOOL)containsAudioNodeRenderInfoWithGraphKey:(NSString *)graphKey nodeKey:(NSString *)nodeKey;

/*! ノードのレンダー情報オブジェクトをグラフから取得します。オブジェクトが生成されていない場合には生成して返します。 */
+ (YASAudioNodeRenderInfo *)audioNodeRenderInfoWithGraphKey:(NSString *)graphKey nodeKey:(NSString *)nodeKey;

/*! レンダー情報と一致するノードでオーディオのレンダーをします */
+ (void)audioNodeRender:(YASAudioNodeRenderInfo *)renderInfo;

@end
