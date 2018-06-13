//
//  AudioFilePlayObject.m
//  LearnVideoToolBox
//
//  Created by Crassus on 2018/6/13.
//  Copyright © 2018年 林伟池. All rights reserved.
//

#import "AudioFilePlayObject.h"

@implementation AudioFilePlayObject

- (instancetype)init
{
    self = [super init];
    if (self) {

    }
    return self;
}

//1.自然是要生成一个AudioFileStream的实例
/*
 extern OSStatus AudioFileStreamOpen (void * inClientData,    // 上下文对象
 AudioFileStream_PropertyListenerProc inPropertyListenerProc, // 是歌曲信息解析的回调，每解析出一个歌曲信息都会进行一次回调
 AudioFileStream_PacketsProc inPacketsProc,   // 是分离帧的回调，每解析出一部分帧就会进行一次回调
 AudioFileTypeID inFileTypeHint,    // 是文件类型的提示,所以在确定文件类型的情况下建议各位还是填上这个参数，如果无法确定可以传入0.
 //AudioFileTypeID枚举
 enum {
     kAudioFileAIFFType             = 'AIFF',
     kAudioFileAIFCType             = 'AIFC',
     kAudioFileWAVEType             = 'WAVE',
     kAudioFileSoundDesigner2Type   = 'Sd2f',
     kAudioFileNextType             = 'NeXT',
     kAudioFileMP3Type              = 'MPG3',    // mpeg layer 3
     kAudioFileMP2Type              = 'MPG2',    // mpeg layer 2
     kAudioFileMP1Type              = 'MPG1',    // mpeg layer 1
     kAudioFileAC3Type              = 'ac-3',
     kAudioFileAAC_ADTSType         = 'adts',
     kAudioFileMPEG4Type            = 'mp4f',
     kAudioFileM4AType              = 'm4af',
     kAudioFileM4BType              = 'm4bf',
     kAudioFileCAFType              = 'caff',
     kAudioFile3GPType              = '3gpp',
     kAudioFile3GP2Type             = '3gp2',
     kAudioFileAMRType              = 'amrf'
 };
 AudioFileStreamID * outAudioFileStream   // 返回的AudioFileStream实例对应的AudioFileStreamID，这个ID需要保存起来作为后续一些方法的参数使用);

 返回值用来判断是否成功初始化（OSStatus == noErr）
 */

/*2.自然是要生成一个AudioFileStream的实例
 解析数据
 在初始化完成之后，只要拿到文件数据就可以进行解析了。解析时调用方法：
 extern OSStatus AudioFileStreamParseBytes(
 AudioFileStreamID inAudioFileStream,    // 即初始化时返回的ID
 UInt32 inDataByteSize,                  // 本次解析的数据长度
 const void* inData,                     // 本次解析的数据
 UInt32 inFlags);                        // 本次的解析和上一次解析是否是连续的关系，如果是连续的传入0，否则传入kAudioFileStreamParseFlag_Discontinuity
  回调得到kAudioFileStreamProperty_ReadyToProducePackets之后，在正常解析第一帧之前都传入kAudioFileStreamParseFlag_Discontinuity比较好。

 解析返回状态：
 OSStatus的值不是noErr则表示解析不成功，其中错误码包括：
 enum
 {
 kAudioFileStreamError_UnsupportedFileType        = 'typ?',
 kAudioFileStreamError_UnsupportedDataFormat      = 'fmt?',
 kAudioFileStreamError_UnsupportedProperty        = 'pty?',
 kAudioFileStreamError_BadPropertySize            = '!siz',
 kAudioFileStreamError_NotOptimized               = 'optm',  // 这个文件需要全部下载完才能播放，无法流播。
 kAudioFileStreamError_InvalidPacketOffset        = 'pck?',
 kAudioFileStreamError_InvalidFile                = 'dta?',
 kAudioFileStreamError_ValueUnknown               = 'unk?',
 kAudioFileStreamError_DataUnavailable            = 'more',
 kAudioFileStreamError_IllegalOperation           = 'nope',
 kAudioFileStreamError_UnspecifiedError           = 'wht?',
 kAudioFileStreamError_DiscontinuityCantRecover   = 'dsc!'
 };
 注意AudioFileStreamParseBytes方法每一次调用都应该注意返回值，一旦出现错误就可以不必继续Parse了。

 */


- (void)fistStep
{

}


@end
