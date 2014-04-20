
/**
 * YASAudioUtility.h
 */

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

/*! AudioBufferListを生成します */
AudioBufferList *YASAllocateAudioBufferList(UInt32 bufferCount, UInt32 ch, UInt32 size);

/*! AudioBufferListを解放します */
void YASRemoveAudioBufferList(AudioBufferList *list);

/*! AudioBufferListのバッファをゼロでクリアします */
void YASClearAudioBufferList(AudioBufferList *list);

/*! AudioBufferListにサイン波を書き込みます（デバッグ用） */
void YASFillFloat32SinewaveToAudioBufferList(AudioBufferList *list, UInt32 cycle);

/*! リニア値をdB値に変換します */
CGFloat YASDBValueFromLinearValue(CGFloat val);

/*! dB値をリニア値に変換します */
CGFloat YASLinearValueFromDBValue(CGFloat val);

/*! 秒数をテンポに変換します */
CGFloat YASTempoValueFromSeconds(CGFloat sec);

/*! テンポを秒数に変換します */
CGFloat YASSecondsFromTempoValue(CGFloat tempo);

/*! ASBDにFloat32・NonInterleavedのデータをセットします */
void YASGetFloat32NonInterleavedStereoFormat(AudioStreamBasicDescription *outFormat, Float64 sampleRate);

/*! ASBDにSInt16・Interleavedのデータをセットします */
void YASGetSInt16InterleavedStereoFormat(AudioStreamBasicDescription *outFormat, Float64 sampleRate);

/*! フレーム数を秒数に変換します */
NSTimeInterval YASSecFromFrames(UInt32 frames, Float64 sampleRate);

