# YASAudio

iOS向けのAUGraphのObjective-Cのラッパーです。複数のAUGraphの生成・破棄を安全に行うことを目的に作成しました。割り込み時のAUGraphの一時停止にも対応しています。

サンプルプロジェクトには以下の３つのパターンのサンプルを用意していますので参考にしてください。

- [Effect & Mixer]
ミキサーとディレイの接続サンプルです。サイン波とノイズをRenderCallbackで生成し、ノイズにディレイをかけます。AUGraph動作中のnodeの生成・破棄、およびconnectionの接続・非接続も試せます。

- [IO Through]
RenderCallbackを使用して入力から出力へ音声をスルーするサンプルです。

- [Audio File]
オーディオファイルの再生サンプルです。

# 動作環境

- iOS 7
- 非ARC

# 注意点

オーディオセッションのカテゴリのセットはYASAudio内部に記述されていません。カテゴリはオーディオ処理開始前に設定してください。サンプルプロジェクトでは各サンプルのグラフは同時に動作させていないため、各グラフの初期化時にカテゴリを設定しています。同時に複数のグラフを動作させる場合は、それらの生成前に１度だけカテゴリを設定してください。オーディオセッションのアクティブ・非アクティブについてはYASAudio内部で行っています。

# 実装方法

AUGraphを使用する場合は、`YASAudioGraph`を継承したサブクラスを作成してください（以下、`YASAudioGraph`のサブクラスをグラフと呼びます）。グラフのオーディオ処理はグラフの外に出さず、オーディオ処理に必要なオブジェクトのメモリ管理をグラフに任せる事をお勧めします。

```objc
@interface YASSampleEffectGraph : YASAudioGraph

// ...

@end

@implementation YASSampleEffectGraph

// ...

@end
```

グラフの中にAUNodeを作成する場合は、グラフの「addNodeWithType:subType:」メソッドを使用してYASAudioNodeを生成してください。RemoteIOのノードはすでにioNodeプロパティで用意されていますので、作成する必要はありません。

```objc
- (YASAudioNode *)addNodeWithType:(OSType)type subType:(OSType)subType;
```

```objc
// ミキサーを作成する場合
self.mixerNode = [self addNodeWithType:kAudioUnitType_Mixer subType:kAudioUnitSubType_MultiChannelMixer];
```

ノードのフォーマットなどのプロパティの設定はメソッドを用意しています。

```objc
// ノードのフォーマットを設定する場合

AudioStreamBasicDescription format;
// ここでセットするformatを記述してください

[_mixerNode setInputFormat:&format busNumber:0];
[_mixerNode setOutputFormat:&format busNumber:0];
```

ノードでコールバックが呼ばれる場合は、ブロックで処理を記述します。YASAudioGraphのサブクラスにアクセスする場合など、循環参照に陥ってしまう変数はweakにしてください。`YASAudioNodeRenderInfo`からRenderCallbackの引数を取得できます。

```objc
// ノードの0番のバスにレンダーコールバックが呼ばれるようにします
[_mixerNode setRenderCallback:0];

__block YASSampleEffectGraph *weakSelf = self;

_mixerNode.renderCallbackBlock = ^(YASAudioNodeRenderInfo *renderInfo) {
    if (renderInfo.inBusNumber == 0) {
        [weakSelf callMethod];
    }
};
```

グラフ内のノード同士を接続する場合は、グラフの「addConnectionWithSourceNode:sourceOutputNumber:destNode:destInputNumber:」メソッドを使用してYASAudioConnectionを生成してください。

```objc
- (YASAudioConnection *)addConnectionWithSourceNode:(YASAudioNode *)sourceNode sourceOutputNumber:(UInt32)sourceOutputNumber destNode:(YASAudioNode *)destNode destInputNumber:(UInt32)destInputNumber;
```

```objc
self.mixerToIOConnection = [self addConnectionWithSourceNode:_mixerNode sourceOutputNumber:0 destNode:self.ioNode destInputNumber:0];
```

runningプロパティをYESにするとグラフのオーディオ処理を開始します。

```objc
self.running = YES; // selfはグラフ
```

グラフを破棄する前には必ずinvalidateメソッドを呼び出してください。

```objc
[self.graph invalidate];
```

# ライセンス
[Apache]: http://www.apache.org/licenses/LICENSE-2.0
[MIT]: http://www.opensource.org/licenses/mit-license.php
[GPL]: http://www.gnu.org/licenses/gpl.html
[BSD]: http://opensource.org/licenses/bsd-license.php
[MIT license][MIT].
