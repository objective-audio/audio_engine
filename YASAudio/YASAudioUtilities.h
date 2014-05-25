
/**
 *  @file YASAudioUtilities.h
 *  @author Yuki Yasoshima
 */

#import <AudioToolbox/AudioToolbox.h>

//! AudioBufferListを生成します
AudioBufferList *YASAllocateAudioBufferList(UInt32 bufferCount, UInt32 ch, UInt32 size);

//! AudioBufferListを解放します
void YASRemoveAudioBufferList(AudioBufferList *list);

//! AudioBufferListのバッファをゼロでクリアします
void YASClearAudioBufferList(AudioBufferList *list);

//! AudioBufferListにサイン波を書き込みます（デバッグ用）
void YASFillFloat32SinewaveToAudioBufferList(AudioBufferList *list, UInt32 cycle);

//! リニア値をdB値に変換します
double YASDBValueFromLinearValue(double val);

//! dB値をリニア値に変換します
double YASLinearValueFromDBValue(double val);

//! 秒数をテンポに変換します
double YASTempoValueFromSeconds(double sec);

//! テンポを秒数に変換します
double YASSecondsFromTempoValue(double tempo);

//! ASBDにFloat32・NonInterleavedのデータをセットします
void YASGetFloat32NonInterleavedStereoFormat(AudioStreamBasicDescription *outFormat, Float64 sampleRate);

//! ASBDにSInt16・Interleavedのデータをセットします
void YASGetSInt16InterleavedStereoFormat(AudioStreamBasicDescription *outFormat, Float64 sampleRate);

//! AudioBufferListが同じかどうかを判定します
BOOL YASIsEqualFormat(AudioStreamBasicDescription *list1, AudioStreamBasicDescription *list2);

//! フレーム数を秒数に変換します
Float64 YASSecFromFrames(UInt32 frames, Float64 sampleRate);

