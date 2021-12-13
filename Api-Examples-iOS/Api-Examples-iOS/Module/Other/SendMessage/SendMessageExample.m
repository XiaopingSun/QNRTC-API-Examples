//
//  SendMessageExample.m
//  Api-Examples-iOS
//
//  Created by WorkSpace_Sun on 2021/12/6.
//

#import "SendMessageExample.h"
#import "SendMessageControlView.h"

@interface SendMessageExample () <QNRTCClientDelegate>

@property (nonatomic, strong) SendMessageControlView  *controlView;

@property (nonatomic, strong) QNRTCClient *client;
@property (nonatomic, strong) QNCameraVideoTrack *cameraVideoTrack;
@property (nonatomic, strong) QNGLKView *localRenderView;
@property (nonatomic, strong) QNVideoView *remoteRenderView;
@property (nonatomic, copy) NSString *remoteUserID;

@end

@implementation SendMessageExample

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    [self loadSubviews];
    [self initRTC];
}

/*!
 * @abstract 释放 SDK 资源
 */
- (void)dealloc {
    // 离开房间  释放 client
    [self.client leave];
    self.client.delegate = nil;
    self.client = nil;
    
    // 清理配置
    [QNRTC deinit];
}

/*!
 * @abstract 初始化视图
 */
- (void)loadSubviews {
    self.localView.text = @"本端视图";
    self.remoteView.text = @"远端视图";
    self.tipsView.text = @"Tips：本示例仅展示一对一场景下消息的发送和接收功能，为简化代码示例中只发布视频 Track。";
    
    // 添加消息发送控制视图
    self.controlView = [[[NSBundle mainBundle] loadNibNamed:@"SendMessageControlView" owner:nil options:nil] lastObject];
    [self.controlView.sendButton addTarget:self action:@selector(sendButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.controlScrollView addSubview:self.controlView];
    [self.controlView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.equalTo(self.controlScrollView);
        make.width.mas_equalTo(SCREEN_WIDTH);
        make.height.mas_equalTo(100);
    }];
    [self.controlView layoutIfNeeded];
    self.controlScrollView.contentSize = self.controlView.frame.size;
    
    // 初始化本地预览视图
    self.localRenderView = [[QNGLKView alloc] init];
    [self.localView addSubview:self.localRenderView];
    self.localRenderView.hidden = YES;
    [self.localRenderView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.localView);
    }];
    
    // 初始化远端渲染视图
    self.remoteRenderView = [[QNVideoView alloc] init];
    [self.remoteView addSubview:self.remoteRenderView];
    self.remoteRenderView.hidden = YES;
    [self.remoteRenderView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.remoteView);
    }];
}

/*!
 * @abstract 初始化 RTC
 */
- (void)initRTC {
    
    // QNRTC 配置
    [QNRTC enableFileLogging];
    QNRTCConfiguration *configuration = [QNRTCConfiguration defaultConfiguration];
    [QNRTC configRTC:configuration];
    
    // 创建 client
    self.client = [QNRTC createRTCClient];
    self.client.delegate = self;
    
    // 使用默认配置初始化相机 Track
    self.cameraVideoTrack = [QNRTC createCameraVideoTrack];
    
    // 开启本地预览
    [self.cameraVideoTrack play:self.localRenderView];
    self.localRenderView.hidden = NO;

    // 加入房间
    [self.client join:ROOM_TOKEN];
}

/*!
 * @abstract 发布相机视频 Track
 */
- (void)publish {
    __weak SendMessageExample *weakSelf = self;
    [self.client publish:@[self.cameraVideoTrack] completeCallback:^(BOOL onPublished, NSError *error) {
        if (onPublished) {
            [weakSelf showAlertWithTitle:@"房间状态" message:@"发布成功"];
        } else {
            [weakSelf showAlertWithTitle:@"房间状态" message:[NSString stringWithFormat:@"发布失败: %@", error.localizedDescription]];
        }
    }];
}

#pragma mark - 发送 / 接收 消息
/*!
 * @abstract 发送房间消息
 *
 * @discussion 如果房间内有 remoteUser 则给该用户发送消息，如果没有 remoteUser，sendMessage 的 Users 数组传nil，默认给房间内所有用户发送消息
 */
- (void)sendButtonAction:(UIButton  *)button {
    [self.view endEditing:YES];
    if ([self.controlView.messageTF.text isEqualToString:@""]) {
        [self showAlertWithTitle:@"提示" message:@"请输入消息内容"];
    } else {
        NSString *identifier = @"TEST_ID";
        [self.client sendMessage:self.controlView.messageTF.text toUsers:self.remoteUserID ? @[self.remoteUserID] : nil messageId:identifier];
        NSString *sendMessage = [NSString stringWithFormat:@"identifier: %@\nuserId: %@\ncontent: %@", identifier, self.remoteUserID ? self.remoteUserID : @"All", self.controlView.messageTF.text];
        [self showAlertWithTitle:@"发送消息" message:sendMessage cancelAction:nil];
        self.controlView.messageTF.text = @"";
    }
}

/*!
 * @abstract QNRTCClientDelegate 中接收消息的回调
 */
- (void)RTCClient:(QNRTCClient *)client didReceiveMessage:(QNMessageInfo *)message {
    NSString *receiveMessage = [NSString stringWithFormat:@"timestamp: %@\nidentifier: %@\nuserId: %@\ncontent: %@", message.timestamp, message.identifier, message.userId, message.content];
    [self showAlertWithTitle:@"收到消息" message:receiveMessage cancelAction:nil];
}

#pragma mark - QNRTCClientDelegate 中其他回调
/*!
 * @abstract 房间状态变更的回调。
 */
- (void)RTCClient:(QNRTCClient *)client didConnectionStateChanged:(QNConnectionState)state disconnectedInfo:(QNConnectionDisconnectedInfo *)info {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (state == QNConnectionStateConnected) {
            // 已加入房间
            [self showAlertWithTitle:@"房间状态" message:@"已加入房间"];
            [self publish];
        } else if (state == QNConnectionStateIdle) {
            // 空闲  此时应查看回调 info 的具体信息做进一步处理
            [self showAlertWithTitle:@"房间状态" message:[NSString stringWithFormat:@"已离开房间：%@", info.error.localizedDescription]];
        } else if (state == QNConnectionStateReconnecting) {
            // 重连中
            [self showAlertWithTitle:@"房间状态" message:@"重连中"];
        } else if (state == QNConnectionStateReconnected) {
            // 重连成功
            [self showAlertWithTitle:@"房间状态" message:@"重连成功"];
        }
    });
}

/*!
 * @abstract 远端用户加入房间的回调。
 */
- (void)RTCClient:(QNRTCClient *)client didJoinOfUserID:(NSString *)userID userData:(NSString *)userData {
    // 示例仅支持一对一的通话，因此这里记录首次加入房间的远端 userID
    self.remoteUserID = self.remoteUserID ?: userID;
    [self showAlertWithTitle:@"房间状态" message:[NSString stringWithFormat:@"%@ 加入房间", userID]];
}

/*!
 * @abstract 远端用户离开房间的回调。
 */
- (void)RTCClient:(QNRTCClient *)client didLeaveOfUserID:(NSString *)userID {
    // 重置 remoteUserID
    if ([self.remoteUserID isEqualToString:userID]) self.remoteUserID = nil;
    [self showAlertWithTitle:@"房间状态" message:[NSString stringWithFormat:@"%@ 离开房间", userID]];
}

/*!
 * @abstract 远端用户视频首帧解码后的回调。
 */
- (void)RTCClient:(QNRTCClient *)client firstVideoDidDecodeOfTrack:(QNRemoteVideoTrack *)videoTrack remoteUserID:(NSString *)userID {
    // 仅渲染当前加入房间的首个远端用户的视图
    if ([userID isEqualToString:self.remoteUserID]) {
        [videoTrack play:self.remoteRenderView];
        self.remoteRenderView.hidden = NO;
    }
}

/*!
 * @abstract 远端用户视频取消渲染到 renderView 上的回调。
 */
- (void)RTCClient:(QNRTCClient *)client didDetachRenderTrack:(QNRemoteVideoTrack *)videoTrack remoteUserID:(NSString *)userID {
    // 移除当前渲染的远端用户的视图
    if ([userID isEqualToString:self.remoteUserID]) {
        [videoTrack play:nil];
        self.remoteRenderView.hidden = YES;
    }
}

@end
