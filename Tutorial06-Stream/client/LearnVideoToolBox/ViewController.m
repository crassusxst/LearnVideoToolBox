//
//  ViewController.m
//  LearnVideoToolBox
//
//  Created by 林伟池 on 16/9/1.
//  Copyright © 2016年 林伟池. All rights reserved.
//

#import "ViewController.h"
#import <netdb.h>
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>
#include <pthread.h>

#define PRINTERROR(LABEL)	printf("%s err %4.4s %d\n", LABEL, (char *)&err, err)

const int port = 51515;			// socket端口号
const unsigned int kNumAQBufs = 3;			// audio queue buffers 数量
const size_t kAQBufSize = 128 * 1024;		// buffer 的大小 单位是字节
const size_t kAQMaxPacketDescs = 512;		// ASPD的最大数量

struct MyData
{
    AudioFileStreamID audioFileStream;	// the audio file stream parser
    
    AudioQueueRef audioQueue;								// the audio queue
    AudioQueueBufferRef audioQueueBuffer[kNumAQBufs];		// audio queue buffers
    
    AudioStreamPacketDescription packetDescs[kAQMaxPacketDescs];	// packet descriptions for enqueuing audio
    
    unsigned int fillBufferIndex;	// the index of the audioQueueBuffer that is being filled
    size_t bytesFilled;				// how many bytes have been filled
    size_t packetsFilled;			// how many packets have been filled
    
    bool inuse[kNumAQBufs];			// flags to indicate that a buffer is still in use
    bool started;					// flag to indicate that the queue has been started
    bool failed;					// flag to indicate an error occurred
    
    pthread_mutex_t mutex;			// a mutex to protect the inuse flags
    pthread_cond_t cond;			// a condition varable for handling the inuse flags
    pthread_cond_t done;			// a condition varable for handling the inuse flags
};
typedef struct MyData MyData;


@interface ViewController () <AVCaptureVideoDataOutputSampleBufferDelegate>


@end

@implementation ViewController
{
    UIButton *button;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    button = [[UIButton alloc] initWithFrame:CGRectMake(100, 100, 100, 100)];
    [button setTitle:@"PLAY" forState:UIControlStateNormal];
    [button setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [self.view addSubview:button];
    [button addTarget:self action:@selector(onClick:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)onClick:(id)sender {
    if (button.selected) {
        NSLog(@"playing now");
    }
    else {
        button.selected = YES;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self start];
            button.selected = NO;
        });
    }
}

- (int)start {
    // allocate a struct for storing our state
    MyData* myData = (MyData*)calloc(1, sizeof(MyData));
    
    // initialize a mutex and condition so that we can block on buffers in use.
    pthread_mutex_init(&myData->mutex, NULL);
    pthread_cond_init(&myData->cond, NULL);
    pthread_cond_init(&myData->done, NULL);
    
    // get connected
    int connection_socket = MyConnectSocket();
    if (connection_socket < 0) return 1;
    printf("connected\n");
    
    // allocate a buffer for reading data from a socket
    const size_t kRecvBufSize = 40;
    char* buf = (char*)malloc(kRecvBufSize * sizeof(char));
    
    // AudioFileStream可以用来读取音频流信息和分离音频帧，与之类似的API簇还有AudioFile和ExtAudioFile。
    // 打开一个音频流转换器，需要设置AudioFileStream_PropertyListenerProc 和 AudioFileStream_PacketsProc 回调函数；
    OSStatus err = AudioFileStreamOpen(myData, MyPropertyListenerProc, MyPacketsProc,
                                       0, &myData->audioFileStream);
    if (err) { PRINTERROR("AudioFileStreamOpen"); free(buf); return 1; }
    
    while (!myData->failed) {
        // read data from the socket
        printf("->recv\n");
        ssize_t bytesRecvd = recv(connection_socket, buf, kRecvBufSize, 0);
        printf("bytesRecvd %ld\n", bytesRecvd);
        if (bytesRecvd <= 0) break; // eof or failure
        
        // AudioFileStreamParseBytes 解析数据，会调用之前设置好的AudioFileStream_PropertyListenerProc 和 AudioFileStream_PacketsProc 回调函数；
        err = AudioFileStreamParseBytes(myData->audioFileStream, (UInt32)bytesRecvd, buf, 0);
        if (err) { PRINTERROR("AudioFileStreamParseBytes"); break; }
    }
    
    // enqueue last buffer
    MyEnqueueBuffer(myData);
    
    printf("flushing\n");
    // 播放结束
    // 传入最后的音频数据后需要调用，否则buffer里面的数据可能会影响下次播放
    err = AudioQueueFlush(myData->audioQueue);
    if (err) { PRINTERROR("AudioQueueFlush"); free(buf); return 1; }
    
    printf("stopping\n");
    // 如果需要停止播放，可以调用这个函数，第二个参数表示同步/异步
    err = AudioQueueStop(myData->audioQueue, false);
    if (err) { PRINTERROR("AudioQueueStop"); free(buf); return 1; }
    
    printf("waiting until finished playing..\n");
    printf("start->lock\n");
    pthread_mutex_lock(&myData->mutex);
    pthread_cond_wait(&myData->done, &myData->mutex);
    printf("start->unlock\n");
    pthread_mutex_unlock(&myData->mutex);
    
    
    printf("done\n");
    
    // cleanup
    free(buf);
    // 关闭音频流
    err = AudioFileStreamClose(myData->audioFileStream);
    // 播放完毕，销毁队列
    err = AudioQueueDispose(myData->audioQueue, false);
    close(connection_socket);
    free(myData);

    return 0;
}


//音频属性回调函数
void MyPropertyListenerProc(	void *							inClientData,
                            AudioFileStreamID				inAudioFileStream,
                            AudioFileStreamPropertyID		inPropertyID,
                            UInt32 *						ioFlags)
{
    // this is called by audio file stream when it finds property values
    MyData* myData = (MyData*)inClientData;
    OSStatus err = noErr;
    
    printf("found property '%c%c%c%c'\n", (char)(inPropertyID>>24)&255, (char)(inPropertyID>>16)&255, (char)(inPropertyID>>8)&255, (char)inPropertyID&255);
    
    switch (inPropertyID) {
        case kAudioFileStreamProperty_ReadyToProducePackets :
        {
            // the file stream parser is now ready to produce audio packets.
            // get the stream format.
            AudioStreamBasicDescription asbd;
            UInt32 asbdSize = sizeof(asbd);
            // 获取特定的属性
            err = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_DataFormat, &asbdSize, &asbd);
            if (err) { PRINTERROR("get kAudioFileStreamProperty_DataFormat"); myData->failed = true; break; }
            
            // 配置AudioQueue
            // 添加AudioQueue的回调函数和添加参数，MyAudioQueueOutputCallback是播完结束的回调
            err = AudioQueueNewOutput(&asbd, MyAudioQueueOutputCallback, myData, NULL, NULL, 0, &myData->audioQueue);
            if (err) { PRINTERROR("AudioQueueNewOutput"); myData->failed = true; break; }
            
            // AudioBuffer分配buffer
            for (unsigned int i = 0; i < kNumAQBufs; ++i) {
                err = AudioQueueAllocateBuffer(myData->audioQueue, kAQBufSize, &myData->audioQueueBuffer[i]);
                if (err) { PRINTERROR("AudioQueueAllocateBuffer"); myData->failed = true; break; }
            }
            
            // get the cookie size
            UInt32 cookieSize;
            Boolean writable;
            err = AudioFileStreamGetPropertyInfo(inAudioFileStream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, &writable);
            if (err) { PRINTERROR("info kAudioFileStreamProperty_MagicCookieData"); break; }
            printf("cookieSize %d\n", (unsigned int)cookieSize);
            
            // get the cookie data
            void* cookieData = calloc(1, cookieSize);
            err = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, cookieData);
            if (err) { PRINTERROR("get kAudioFileStreamProperty_MagicCookieData"); free(cookieData); break; }
            
            // set the cookie on the queue.
            err = AudioQueueSetProperty(myData->audioQueue, kAudioQueueProperty_MagicCookie, cookieData, cookieSize);
            free(cookieData);
            if (err) { PRINTERROR("set kAudioQueueProperty_MagicCookie"); break; }
            
            // listen for kAudioQueueProperty_IsRunning
            // 添加AudioQueue的属性监听
            err = AudioQueueAddPropertyListener(myData->audioQueue, kAudioQueueProperty_IsRunning, MyAudioQueueIsRunningCallback, myData);
            if (err) { PRINTERROR("AudioQueueAddPropertyListener"); myData->failed = true; break; }
            
            break;
        }
    }
}

// 数据回调函数
void MyPacketsProc(void *							inClientData,
                   UInt32							inNumberBytes,
                   UInt32							inNumberPackets,
                   const void *                     inInputData,
                   AudioStreamPacketDescription	*   inPacketDescriptions)
{
    // this is called by audio file stream when it finds packets of audio
    MyData* myData = (MyData*)inClientData;
    printf("got data.  bytes: %d  packets: %d\n", (unsigned int)inNumberBytes, (unsigned int)inNumberPackets);
    
    // the following code assumes we're streaming VBR data. for CBR data, you'd need another code branch here.
    
    for (int i = 0; i < inNumberPackets; ++i) {
        SInt64 packetOffset = inPacketDescriptions[i].mStartOffset;
        SInt64 packetSize   = inPacketDescriptions[i].mDataByteSize;
        
        // if the space remaining in the buffer is not enough for this packet, then enqueue the buffer.
        size_t bufSpaceRemaining = kAQBufSize - myData->bytesFilled;
        if (bufSpaceRemaining < packetSize) {
            MyEnqueueBuffer(myData);
            WaitForFreeBuffer(myData);
        }
        
        // copy data to the audio queue buffer
        AudioQueueBufferRef fillBuf = myData->audioQueueBuffer[myData->fillBufferIndex];
        memcpy((char*)fillBuf->mAudioData + myData->bytesFilled, (const char*)inInputData + packetOffset, packetSize);
        // fill out packet description
        myData->packetDescs[myData->packetsFilled] = inPacketDescriptions[i];
        myData->packetDescs[myData->packetsFilled].mStartOffset = myData->bytesFilled;
        // keep track of bytes filled and packets filled
        myData->bytesFilled += packetSize;
        myData->packetsFilled += 1;
        
        // if that was the last free packet description, then enqueue the buffer.
        size_t packetsDescsRemaining = kAQMaxPacketDescs - myData->packetsFilled;
        if (packetsDescsRemaining == 0) {
            MyEnqueueBuffer(myData);
            WaitForFreeBuffer(myData);
        }
    }
}

// 开始播放
OSStatus StartQueueIfNeeded(MyData* myData)
{
    OSStatus err = noErr;
    if (!myData->started) {		// start the queue if it has not been started already
        // 开始AudioQueue播放
        err = AudioQueueStart(myData->audioQueue, NULL);
        if (err) { PRINTERROR("AudioQueueStart"); myData->failed = true; return err; }
        myData->started = true;
        printf("started\n");
    }
    return err;
}

// 把buffer里面的数据传入AudioQueue
OSStatus MyEnqueueBuffer(MyData* myData)
{
    OSStatus err = noErr;
    myData->inuse[myData->fillBufferIndex] = true;		// set in use flag
    
    // enqueue buffer
    AudioQueueBufferRef fillBuf = myData->audioQueueBuffer[myData->fillBufferIndex];
    fillBuf->mAudioDataByteSize = (UInt32)myData->bytesFilled;
    // 向AudioQueue传入buffer
    err = AudioQueueEnqueueBuffer(myData->audioQueue, fillBuf, (UInt32)myData->packetsFilled, myData->packetDescs);
    if (err) { PRINTERROR("AudioQueueEnqueueBuffer"); myData->failed = true; return err; }
    
    StartQueueIfNeeded(myData);
    
    return err;
}

// 当前所有buffer已经占用满，等待AudioQueue播放完释放buffer
void WaitForFreeBuffer(MyData* myData)
{
    // go to next buffer
    if (++myData->fillBufferIndex >= kNumAQBufs) myData->fillBufferIndex = 0;
    myData->bytesFilled = 0;		// reset bytes filled
    myData->packetsFilled = 0;		// reset packets filled
    
    // wait until next buffer is not in use
    printf("WaitForFreeBuffer->lock\n");
    //  调用pthread_cond_wait前，要先调用pthread_mutex_lock(mutex)加锁，pthread_cond_wait会在调用结束解锁mutex；
    pthread_mutex_lock(&myData->mutex);
    while (myData->inuse[myData->fillBufferIndex]) {
        printf("... WAITING ...\n");
        // 条件锁(pthread_cond_wait), 条件不成立则阻塞，直到条件成立
        pthread_cond_wait(&myData->cond, &myData->mutex);
    }
    // pthread_cond_wait条件满足后(pthread_cond_signal被调用)，会对mutex加锁，当我们执行完程序时需要对mutex解锁；
    pthread_mutex_unlock(&myData->mutex);
    printf("WaitForFreeBuffer->unlock\n");

    /*
     申请条件锁
     pthread_mutex_lock(&mutex);
     pthread_cond_wait(&cond, &mutex);
     pthread_mutex_unlock(&mutex);

     释放条件锁
     pthread_mutex_lock(&mutex);
     pthread_cond_signal(&cond);
     pthread_mutex_unlock(&mutex);
     */
}

int MyFindQueueBuffer(MyData* myData, AudioQueueBufferRef inBuffer)
{
    for (unsigned int i = 0; i < kNumAQBufs; ++i) {
        if (inBuffer == myData->audioQueueBuffer[i])
            return i;
    }
    return -1;
}

// AudioQueue释放buffer的回调函数
void MyAudioQueueOutputCallback(	void*					inClientData,
                                AudioQueueRef			inAQ,
                                AudioQueueBufferRef		inBuffer)
{
    // this is called by the audio queue when it has finished decoding our data.
    // The buffer is now free to be reused.
    MyData* myData = (MyData*)inClientData;
    
    unsigned int bufIndex = MyFindQueueBuffer(myData, inBuffer);
    
    if (bufIndex != -1) {
        // signal waiting thread that the buffer is free.
        printf("MyAudioQueueOutputCallback->lock\n");
        pthread_mutex_lock(&myData->mutex);
        myData->inuse[bufIndex] = false;
        pthread_cond_signal(&myData->cond);
        printf("MyAudioQueueOutputCallback->unlock\n");
        pthread_mutex_unlock(&myData->mutex);
    }
    
}

// AudioQueue是否在播放的回调函数
void MyAudioQueueIsRunningCallback(		void*					inClientData,
                                   AudioQueueRef			inAQ,
                                   AudioQueuePropertyID	inID)
{
    MyData* myData = (MyData*)inClientData;
    
    UInt32 running;
    UInt32 size;
    OSStatus err = AudioQueueGetProperty(inAQ, kAudioQueueProperty_IsRunning, &running, &size);
    if (err) { PRINTERROR("get kAudioQueueProperty_IsRunning"); return; }
    if (!running) {
        printf("MyAudioQueueIsRunningCallback->lock\n");
        pthread_mutex_lock(&myData->mutex);
        pthread_cond_signal(&myData->done);
        printf("MyAudioQueueIsRunningCallback->unlock\n");
        pthread_mutex_unlock(&myData->mutex);
    }
}

// 建立socket链接
int MyConnectSocket() {
    
    int connection_socket;
    // 这里的host，要改成对应的地址！！！
    struct hostent *host = gethostbyname("192.168.2.101");
    if (!host) { printf("can't get host\n"); return -1; }
    
    connection_socket = socket(AF_INET, SOCK_STREAM, 0);
    if (connection_socket < 0) { printf("can't create socket\n"); return -1; }
    
    struct sockaddr_in server_sockaddr;
    server_sockaddr.sin_family = host->h_addrtype;
    memcpy(&server_sockaddr.sin_addr.s_addr, host->h_addr_list[0], host->h_length);
    server_sockaddr.sin_port = htons(port);
    
    int err = connect(connection_socket, (struct sockaddr*)&server_sockaddr, sizeof(server_sockaddr));
    if (err < 0) { printf("can't connect\n"); return -1; }
    
    return connection_socket;
}


@end
