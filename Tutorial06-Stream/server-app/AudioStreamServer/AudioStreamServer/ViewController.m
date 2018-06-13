//
//  ViewController.m
//  AudioStreamServer
//
//  Created by 林伟池 on 2017/4/1.
//  Copyright © 2017年 loying. All rights reserved.
//

#import "ViewController.h"
#include <unistd.h>
#include <netinet/in.h>

@interface ViewController()

@end

@implementation ViewController
const int port = 51515;

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self startServer];
    });
}



/**
 对已经失效的socket，send两次数据就会触发SIGPIPE信号，默认的处理是关闭进程。
 */
- (int)startServer {
    // 打开文件
    FILE* file = fopen([[[NSBundle mainBundle] pathForResource:@"abc" ofType:@"mp3"] UTF8String], "r");
    if (file == NULL) {
        printf("error file path\n");
        return 1;
    }
    
    // 创建socket
    int listener_socket = socket(AF_INET, SOCK_STREAM, 0);
    if (listener_socket < 0) {
        printf("can't create listener_socket\n");
        return 1;
    }
    
    // 绑定socket
    struct sockaddr_in server_sockaddr;
    server_sockaddr.sin_family = AF_INET;
    server_sockaddr.sin_addr.s_addr = htonl(INADDR_ANY);
    server_sockaddr.sin_port = htons(port);
    if (bind(listener_socket, (struct sockaddr*)&server_sockaddr, sizeof(server_sockaddr)) < 0) {
        printf("can't bind listener_socket\n");
        return 1;
    }
    
    // 监听tcp连接
    listen(listener_socket, 4);
    
    // loop for each connection
    while (true) {
        printf("waiting for connection\n");
        struct sockaddr_in client_sockaddr;
        socklen_t client_sockaddr_size = sizeof(client_sockaddr);
        // 接收tcp连接，注意！这里并不是三次握手。
        int connection_socket = accept(listener_socket, (struct sockaddr*)&client_sockaddr, &client_sockaddr_size);
        if (connection_socket < 0) {
            printf("accept failed\n");
            continue;
        }
        printf("connected\n");
        off_t totalSent = 0;
        // send out the file
        /* SEEK_SET    Beginning of file
           SEEK_CUR    Current position of the file pointer
           SEEK_END    End of file *
        */
        fseek(file, 0L, SEEK_END);
        long sz = ftell(file);
        printf("读取文件大小 %ld", sz);

        // 回到初始位置
        fseek(file, 0, SEEK_SET); // rewind

        while (true) {
            // 读取文件
            char buf[32768];
            size_t bytesRead = fread(buf, 1, 32768, file);
            printf("bytesRead %ld\n", bytesRead);
            
            if (bytesRead == 0) {
                printf("读取文件完毕\n");
                break; // eof
            }
            
            // 发送音频流
            ssize_t bytesSent = send(connection_socket, buf, bytesRead, 0);
            totalSent += bytesSent;
            printf("  bytesSent %ld  totalSent %qd\n", bytesSent, totalSent);
            if (bytesSent < 0) {
                printf("send failed\n");
                break;
            }
        }

        // 关闭socket
        close(connection_socket);
    }
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}


@end
