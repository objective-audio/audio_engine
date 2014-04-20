
/**
 * @class YASAudioFile
 * @author Yuki Yasoshima
 */

#import <AudioToolbox/AudioToolbox.h>
#import <Foundation/Foundation.h>

/**
 *  オーディオファイルの読み書きを行います<br>
 *  読み込む場合は、初期化した後にopenを呼んでください<br>
 *  書き込む場合は、初期化した後にcreateを呼んでください。既にファイルが存在した場合は上書きされます
 */

@interface YASAudioFile : NSObject

@property (nonatomic, strong, readonly) NSURL *url; /*!< ファイルのURL */
@property (nonatomic, assign) AudioFileTypeID fileType; /*!< ファイルの種類（kAudioFile〜Type） */
@property (nonatomic, assign) AudioStreamBasicDescription *fileFormat; /*!< ファイル側のフォーマット */
@property (nonatomic, assign) AudioStreamBasicDescription *clientFormat; /*!< 読み書きする側のフォーマット */
@property (nonatomic, assign, readonly) SInt64 totalFrames; /*!< clientFormatでの全体のフレーム数 */
@property (nonatomic, assign) BOOL loop; /*!< 読み込み時にループして読み出すフラグ */

/*! パスを指定して初期化します */
- (id)initWithPath:(NSString *)path;

/*! URLを指定して初期化します */

- (id)initWithURL:(NSURL *)url;

/*! オーディオファイルを読み込む場合にファイルを開きます */
- (BOOL)open;

/*! オーディオファイルを書き込む場合にファイルを作成します。既にファイルが存在している場合は上書きされます */
- (BOOL)create;

/*! ファイルを閉じます。deallocでも呼ばれますが、読み書きのタイミングがシビアな場合は明示的に呼び出してください */
- (void)close;

/*! タイトルを取得します */
- (NSString *)title;

/*! オーディオファイルの情報を取得します */
- (NSDictionary *)infoDictionary;

/*! ファイルの属性を取得します */
- (NSDictionary *)attributes;

/*! ファイル側のフォーマットを設定します。指定されたパラメータ以外は、ファイルの種類に応じて自動でASBDが設定されます */
- (void)setAndFillFileFormatWithFormatID:(UInt32)formatID sampleRate:(Float64)sampleRate channels:(UInt32)ch;

/*! 頭出しをします。指定するフレーム位置はclientFormatに準じます */
- (BOOL)seek:(SInt64)frame;

/*! 現在の読み込みフレーム位置を取得します。フレーム位置はclientFormatに準じます */
- (SInt64)tell;

/*! オーディオデータを読み込みます */
- (void)read:(void *)outBuffer ioFrames:(UInt32 *)ioFrames;

/*! リニアPCM16ビットのオーディオデータをAudioFileServiceで直接読み込みます */
- (void)readDirectLPCM16Bits:(SInt16 *)outBuffer ioFrames:(UInt32 *)ioFrames startFrame:(SInt64)startFrame;

/*! オーディオデータを書き込みます */
- (void)write:(void *)inBuffer frames:(UInt32)inFrames;

@end

