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

/*2.解析数据
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

/*
 3.解析文件格式信息
  a.AudioFileStream_PropertyListenerProc
 歌曲信息解析的回调，每解析出一个歌曲信息都会进行一次回调
 在调用AudioFileStreamParseBytes方法进行解析时会首先读取格式信息，并同步的进入AudioFileStream_PropertyListenerProc回调方法
 typedef void (*AudioFileStream_PropertyListenerProc)(
 void * inClientData,           // Open方法中的上下文对象
 AudioFileStreamID inAudioFileStream,    // 表示当前FileStream的ID
 AudioFileStreamPropertyID inPropertyID, // 此次回调解析的信息ID, 表示当前PropertyID对应的信息已经解析完成信息（例如数据格式、音频数据的偏移量等等）,使用者可以通过AudioFileStreamGetProperty接口获取PropertyID对应的值或者数据结构
 // extern OSStatus AudioFileStreamGetProperty(AudioFileStreamID inAudioFileStream,
 AudioFileStreamPropertyID inPropertyID,
 UInt32 * ioPropertyDataSize,
 void * outPropertyData);

 UInt32 * ioFlags);     // ioFlags是一个返回参数,表示这个property是否需要被缓存,如果需要赋值kAudioFileStreamPropertyFlag_PropertyIsCached否则不赋值
 这个回调会进来多次，但并不是每一次都需要进行处理，可以根据需求处理需要的PropertyID进行处理（PropertyID列表如下）:
 //AudioFileStreamProperty枚举
 enum
 {
 kAudioFileStreamProperty_ReadyToProducePackets           =    'redy',
 kAudioFileStreamProperty_FileFormat                      =    'ffmt',
 kAudioFileStreamProperty_DataFormat                      =    'dfmt',
 kAudioFileStreamProperty_FormatList                      =    'flst',
 kAudioFileStreamProperty_MagicCookieData                 =    'mgic',
 kAudioFileStreamProperty_AudioDataByteCount              =    'bcnt',
 kAudioFileStreamProperty_AudioDataPacketCount            =    'pcnt',
 kAudioFileStreamProperty_MaximumPacketSize               =    'psze',
 kAudioFileStreamProperty_DataOffset                      =    'doff',
 kAudioFileStreamProperty_ChannelLayout                   =    'cmap',
 kAudioFileStreamProperty_PacketToFrame                   =    'pkfr',
 kAudioFileStreamProperty_FrameToPacket                   =    'frpk',
 kAudioFileStreamProperty_PacketToByte                    =    'pkby',
 kAudioFileStreamProperty_ByteToPacket                    =    'bypk',
 kAudioFileStreamProperty_PacketTableInfo                 =    'pnfo',
 kAudioFileStreamProperty_PacketSizeUpperBound            =    'pkub',
 kAudioFileStreamProperty_AverageBytesPerPacket           =    'abpp',
 kAudioFileStreamProperty_BitRate                         =    'brat',
 kAudioFileStreamProperty_InfoDictionary                  =    'info'
 };
 比较重要的PropertyID：
 1、kAudioFileStreamProperty_BitRate：表示音频数据的码率,这个Property是为了计算音频的总时长Duration.
 UInt32 bitRate;
 UInt32 bitRateSize = sizeof(bitRate);
 OSStatus status = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_BitRate, &bitRateSize, &bitRate);
 if (status != noErr)
 {
    //错误处理
 }
 发现在流播放的情况下，有时数据流量比较小时会出现ReadyToProducePackets还是没有获取到bitRate的情况，这时就需要分离一些拼音帧然后计算平均bitRate，计算公式如下：
 UInt32 averageBitRate = totalPackectByteCount / totalPacketCout;

 2、kAudioFileStreamProperty_DataOffset:表示音频数据在整个音频文件中的offset（因为大多数音频文件都会有一个文件头之后才使真正的音频数据）这个值在seek时会发挥比较大的作用，音频的seek并不是直接seek文件位置而seek时间,（比如seek到2分10秒的位置），seek时会根据时间计算出音频数据的字节offset然后需要再加上音频数据的offset才能得到在文件中的真正offset。
     SInt64 dataOffset;
     UInt32 offsetSize = sizeof(dataOffset);
     OSStatus status = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_DataOffset, &offsetSize, &dataOffset);
     if (status != noErr)
     {
        //错误处理
     }
 3、kAudioFileStreamProperty_DataFormat:表示音频文件结构信息，是一个AudioStreamBasicDescription的结构
 struct AudioStreamBasicDescription
 {
     Float64 mSampleRate;
     UInt32  mFormatID;
     UInt32  mFormatFlags;
     UInt32  mBytesPerPacket;
     UInt32  mFramesPerPacket;
     UInt32  mBytesPerFrame;
     UInt32  mChannelsPerFrame;
     UInt32  mBitsPerChannel;
     UInt32  mReserved;
 };

 AudioStreamBasicDescription asbd;
 UInt32 asbdSize = sizeof(asbd);
 OSStatus status = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_DataFormat, &asbdSize, &asbd);
 if (status != noErr)
 {
    //错误处理
 }

 4、kAudioFileStreamProperty_FormatList:作用和kAudioFileStreamProperty_DataFormat是一样的，区别在于用这个PropertyID获取到是一个AudioStreamBasicDescription的数组，这个参数是用来支持AAC SBR这样的包含多个文件类型的音频格式。由于到底有多少个format我们并不知晓，所以需要先获取一下总数据大小：
 //获取数据大小
 Boolean outWriteable;
 UInt32 formatListSize;
 OSStatus status = AudioFileStreamGetPropertyInfo(inAudioFileStream, kAudioFileStreamProperty_FormatList, &formatListSize, &outWriteable);
 if (status != noErr)
 {
    //错误处理
 }

 //获取formatlist
 AudioFormatListItem *formatList = malloc(formatListSize);
 OSStatus status = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_FormatList, &formatListSize, formatList);
 if (status != noErr)
 {
    //错误处理
 }

 //选择需要的格式
 for (int i = 0; i * sizeof(AudioFormatListItem) < formatListSize; i++)
 {
    AudioStreamBasicDescription pasbd = formatList[i].mASBD;
    //选择需要的格式。。
 }
 free(formatList);

 5、kAudioFileStreamProperty_AudioDataByteCount:音频文件中音频数据的总量,Property的作用一是用来计算音频的总时长，二是可以在seek时用来计算时间对应的字节offset
 UInt64 audioDataByteCount;
 UInt32 byteCountSize = sizeof(audioDataByteCount);
 OSStatus status = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_AudioDataByteCount, &byteCountSize, &audioDataByteCount);
 if (status != noErr)
 {
    //错误处理
 }
 发现在流播放的情况下，有时数据流量比较小时会出现ReadyToProducePackets还是没有获取到audioDataByteCount的情况，这时就需要近似计算audioDataByteCount。一般来说音频文件的总大小一定是可以得到的（利用文件系统或者Http请求中的contentLength），那么计算方法如下：
 UInt32 dataOffset = ...; //kAudioFileStreamProperty_DataOffset
 UInt32 fileLength = ...; //音频文件大小
 UInt32 audioDataByteCount = fileLength - dataOffset;

 5、kAudioFileStreamProperty_ReadyToProducePackets:这个PropertyID可以不必获取对应的值，一旦回调中这个PropertyID出现就代表解析完成，接下来可以对音频数据进行帧分离了.

 */

/*
 4.计算时长Duration
 a.获取时长的最佳方法是从ID3信息中去读取，那样是最准确的。如果ID3信息中没有存，那就依赖于文件头中的信息去计算了。
 b.计算：double duration = (audioDataByteCount * 8) / bitRate
 (音频数据的字节总量audioDataByteCount可以通过kAudioFileStreamProperty_AudioDataByteCount获取，码率bitRate可以通过kAudioFileStreamProperty_BitRate获取也可以通过Parse一部分数据后计算平均码率来得到)
 总结：CBR数据来说用这样的计算方法的duration会比较准确，对于VBR数据就不好说了。所以对于VBR数据来说，最好是能够从ID3信息中获取到duration，获取不到再想办法通过计算平均码率的途径来计算duration.
 */

/*
 5.分离音频帧
 读取格式信息完成之后继续调用AudioFileStreamParseBytes方法可以对帧进行分离，并同步的进入AudioFileStream_PacketsProc回调方法
 typedef void (*AudioFileStream_PacketsProc)(
 void * inClientData,     // 上下文对象
 UInt32 numberOfBytes,    // 本次处理的数据大小
 UInt32 numberOfPackets,  // 本次总共处理了多少帧（即代码里的Packet）
 const void * inInputData,// 本次处理的所有数据
 AudioStreamPacketDescription * inPacketDescriptions); // 数组存储了每一帧数据是从第几个字节开始的，这一帧总共多少字节。
 struct  AudioStreamPacketDescription
 {
     SInt64  mStartOffset;
     UInt32  mVariableFramesInPacket;   // 实际的数据帧只有VBR的数据才能用到（像MP3这样的压缩数据一个帧里会有好几个数据帧）
     UInt32  mDataByteSize;
 };
 */
/*
    代码块整理
 static void MyAudioFileStreamPacketsCallBack(void *inClientData,
     UInt32 numberOfBytes,
     UInt32 numberOfPackets,
     const void *inInputData,
     AudioStreamPacketDescription  *inPacketDescriptions)
{
     //处理discontinuous..
     if (numberOfBytes == 0 || numberOfPackets == 0)
     {
        return;
     }

     BOOL deletePackDesc = NO;
     if (packetDescriptioins == NULL)
     {
     //如果packetDescriptioins不存在，就按照CBR处理，平均每一帧的数据后生成packetDescriptioins
     deletePackDesc = YES;
     UInt32 packetSize = numberOfBytes / numberOfPackets;
     packetDescriptioins = (AudioStreamPacketDescription *)malloc(sizeof(AudioStreamPacketDescription) * numberOfPackets);

     for (int i = 0; i < numberOfPackets; i++)
     {
     UInt32 packetOffset = packetSize * i;
     descriptions[i].mStartOffset = packetOffset;
     descriptions[i].mVariableFramesInPacket = 0;
     if (i == numberOfPackets - 1)
     {
     packetDescriptioins[i].mDataByteSize = numberOfBytes - packetOffset;
     }
     else
     {
     packetDescriptioins[i].mDataByteSize = packetSize;
     }
     }
     }

     for (int i = 0; i < numberOfPackets; ++i)
     {
     SInt64 packetOffset = packetDescriptioins[i].mStartOffset;
     UInt32 packetSize   = packetDescriptioins[i].mDataByteSize;

     //把解析出来的帧数据放进自己的buffer中
     ...
     }

     if (deletePackDesc)
     {
     free(packetDescriptioins);
     }
 }
 */

/*
  6.Seek几种方案
 CBR数据的seek
 1、近似地计算应该seek到哪个字节
 double seekToTime = ...; //需要seek到哪个时间，秒为单位
 UInt64 audioDataByteCount = ...; //通过kAudioFileStreamProperty_AudioDataByteCount获取的值
 SInt64 dataOffset = ...; //通过kAudioFileStreamProperty_DataOffset获取的值
 double durtion = ...; //通过公式(AudioDataByteCount * 8) / BitRate计算得到的时长

 //近似seekOffset = 数据偏移 + seekToTime对应的近似字节数
 SInt64 approximateSeekOffset = dataOffset + (seekToTime / duration) * audioDataByteCount;

 2、计算seekToTime对应的是第几个帧（Packet）
    Parse得到的音频格式信息来计算PacketDuration。audioItem.fileFormat.mFramesPerPacket / audioItem.fileFormat.mSampleRate;
     //首先需要计算每个packet对应的时长
     AudioStreamBasicDescription asbd = ...; ////通过kAudioFileStreamProperty_DataFormat或者kAudioFileStreamProperty_FormatList获取的值
     double packetDuration = asbd.mFramesPerPacket / asbd.mSampleRate

     //然后计算packet位置
     SInt64 seekToPacket = floor(seekToTime / packetDuration);

 3、使用AudioFileStreamSeek计算精确的字节偏移和时间
 AudioFileStreamSeek可以用来寻找某一个帧（Packet）对应的字节偏移（byte offset）：

 如果ioFlags里有kAudioFileStreamSeekFlag_OffsetIsEstimated说明给出的outDataByteOffset是估算的，并不准确，那么还是应该用第1步计算出来的approximateSeekOffset来做seek；
 如果ioFlags里没有kAudioFileStreamSeekFlag_OffsetIsEstimated说明给出了准确的outDataByteOffset，就是输入的seekToPacket对应的字节偏移量，我们可以根据outDataByteOffset来计算出精确的seekOffset和seekToTime；
 SInt64 seekByteOffset;
 UInt32 ioFlags = 0;
 SInt64 outDataByteOffset;
 OSStatus status = AudioFileStreamSeek(audioFileStreamID, seekToPacket, &outDataByteOffset, &ioFlags);
 if (status == noErr && !(ioFlags & kAudioFileStreamSeekFlag_OffsetIsEstimated))
 {
     //如果AudioFileStreamSeek方法找到了准确的帧字节偏移，需要修正一下时间
     seekToTime -= ((approximateSeekOffset - dataOffset) - outDataByteOffset) * 8.0 / bitRate;
     seekByteOffset = outDataByteOffset + dataOffset;
 }
 else
 {
    seekByteOffset = approximateSeekOffset;
 }

 4、按照seekByteOffset读取对应的数据继续使用AudioFileStreamParseByte进行解析
    如果是网络流可以通过设置range头来获取字节，本地文件的话直接seek就好了。调用AudioFileStreamParseByte时注意刚seek完第一次Parse数据需要加参数kAudioFileStreamParseFlag_Discontinuity
 */


/*
 7.关闭AudioFileStream
 AudioFileStream使用完毕后需要调用AudioFileStreamClose进行关闭，没啥特别需要注意的。
 extern OSStatus AudioFileStreamClose(AudioFileStreamID inAudioFileStream);
 */
@end
