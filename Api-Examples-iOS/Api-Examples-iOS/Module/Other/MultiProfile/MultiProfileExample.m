//
//  MultiProfileExample.m
//  Api-Examples-iOS
//
//  Created by WorkSpace_Sun on 2021/11/24.
//

#import "MultiProfileExample.h"
#import "MultiProfileControlView.h"

@interface MultiProfileExample () <QNRTCClientDelegate, QNRemoteTrackVideoDataDelegate>

@property (nonatomic, strong) QNRTCClient *client;
@property (nonatomic, strong) QNCameraVideoTrack *cameraVideoTrack;
@property (nonatomic, strong) QNRemoteVideoTrack *remoteVideoTrack;
@property (nonatomic, strong) QNGLKView *localRenderView;
@property (nonatomic, strong) QNVideoView *remoteRenderView;
@property (nonatomic, strong) MultiProfileControlView *controlView;
@property (nonatomic, copy) NSString *remoteUserID;

@end

@implementation MultiProfileExample

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
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
    self.tips = @"Tips：本示例仅展示一对一场景下相机 Track 的大小流发布和订阅，请注意：\n"
    "1. 开启大小流功能设置编码宽高最低为 1280 x 720。\n"
    "2. 目前仅支持在发送端发布单路视频 Track 的场景下，使用大小流功能。\n"
    "3. 对于开启大小流的用户，建议保证有良好的网络环境，保证多流发送质量。";
    
    // 添加大小流参数控制视图
    self.controlView = [[[NSBundle mainBundle] loadNibNamed:@"MultiProfileControlView" owner:nil options:nil] lastObject];
    [self.controlView.switchProfileButton addTarget:self action:@selector(switchProfileButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.controlScrollView addSubview:self.controlView];
    [self.controlView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.equalTo(self.controlScrollView);
        make.width.mas_equalTo(SCREEN_WIDTH);
        make.height.mas_equalTo(200);
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
    
    // 创建相机视频 Track 配置（开启大小流功能设置编码宽高最低为 1280 x 720）
    QNCameraVideoTrackConfig *cameraVideoTrackConfig = [[QNCameraVideoTrackConfig alloc] initWithSourceTag:@"camera"
                                                                                                   bitrate:1000
                                                                                           videoEncodeSize:CGSizeMake(720, 1280)
                                                                                         multiStreamEnable:YES];
    
    // 使用自定义配置创建相机视频 Track
    self.cameraVideoTrack = [QNRTC createCameraVideoTrackWithConfig:cameraVideoTrackConfig];
    
    // 设置采集分辨率（要保证预览分辨率 sessionPreset 不小于 QNCameraVideoTrackConfig 的编码分辨率 videoEncodeSize）
    self.cameraVideoTrack.sessionPreset = AVCaptureSessionPreset1280x720;
    
    // 开启本地预览
    [self.cameraVideoTrack play:self.localRenderView];
    self.localRenderView.hidden = NO;

    // 加入房间
    [self.client join:ROOM_TOKEN];
}

/*!
 * @abstract 发布
 */
- (void)publish {
    __weak MultiProfileExample *weakSelf = self;
    [self.client publish:@[self.cameraVideoTrack] completeCallback:^(BOOL onPublished, NSError *error) {
        if (onPublished) {
            [weakSelf showAlertWithTitle:@"房间状态" message:@"发布成功"];
        } else {
            [weakSelf showAlertWithTitle:@"房间状态" message:[NSString stringWithFormat:@"发布失败: %@", error.localizedDescription]];
        }
    }];
}

#pragma mark - 大小流相关方法、回调
/*!
 * @abstract 切换订阅远端的大小流级别
 */
-  (void)switchProfileButtonAction:(UIButton *)sender {
    if (!self.remoteVideoTrack) {
        [self showAlertWithTitle:@"提示" message:@"远端没有用户发布"];
        return;
    }
    
    if (!self.remoteVideoTrack.isMultiProfileEnabled) {
        [self showAlertWithTitle:@"提示" message:@"远端没有开启大小流"];
        return;
    }
    
    // setProfile 接口仅是设置预期的流等级，并不代表实际的订阅等级，若实际发送端还未发送指定等级的流，则将无法订阅到指定的 profile。
    RadioButton *selectedButton = self.controlView.lowButton.selectedButton;
    if (selectedButton == self.controlView.lowButton) {
        [self.remoteVideoTrack setProfile:QNTrackProfileLow];
    } else if (selectedButton == self.controlView.mediumButton) {
        [self.remoteVideoTrack setProfile:QNTrackProfileMedium];
    } else if (selectedButton == self.controlView.highButton) {
        [self.remoteVideoTrack setProfile:QNTrackProfileHigh];
    }
}

/*!
 * @abstract 订阅的远端视频 Track 分辨率发生变化时的回调。
 */
- (void)remoteVideoTrack:(QNRemoteVideoTrack *)remoteVideoTrack didSubscribeProfileChanged:(QNTrackProfile)profile {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *currentProfile = @"";
        switch (profile) {
            case QNTrackProfileLow: currentProfile = @"Low"; break;
            case QNTrackProfileMedium: currentProfile = @"Medium"; break;
            case QNTrackProfileHigh: currentProfile = @"High"; break;
            default: break;
        }
        self.controlView.currentProfileTF.text = currentProfile;
        [self showAlertWithTitle:@"订阅状态更新" message:[NSString stringWithFormat:@"当前订阅级别：%@", currentProfile]];
    });
}

#pragma mark - QNRTCClientDelegate
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
            // 空闲状态  此时应查看回调 info 的具体信息做进一步处理
            switch (info.reason) {
                case QNConnectionDisconnectedReasonKickedOut: {
                    [self showAlertWithTitle:@"房间状态" message:@"已离开房间：被踢出房间" cancelAction:^{
                        [self.navigationController popViewControllerAnimated:YES];
                    }];
                }
                    break;
                case QNConnectionDisconnectedReasonLeave: {
                    [self showAlertWithTitle:@"房间状态" message:@"已离开房间：主动离开房间" cancelAction:^{
                        [self.navigationController popViewControllerAnimated:YES];
                    }];
                }
                    break;
                case QNConnectionDisconnectedReasonRoomClosed: {
                    [self showAlertWithTitle:@"房间状态" message:@"已离开房间：房间已关闭" cancelAction:^{
                        [self.navigationController popViewControllerAnimated:YES];
                    }];
                }
                    break;
                case QNConnectionDisconnectedReasonRoomFull: {
                    [self showAlertWithTitle:@"房间状态" message:@"已离开房间：房间人数已满" cancelAction:^{
                        [self.navigationController popViewControllerAnimated:YES];
                    }];
                }
                    break;
                case QNConnectionDisconnectedReasonError: {
                    NSString *errorMessage = info.error.localizedDescription;
                    if (info.error.code == QNRTCErrorReconnectTokenError) {
                        errorMessage = @"重新进入房间超时";
                    }
                    [self showAlertWithTitle:@"房间状态" message:[NSString stringWithFormat:@"已离开房间：%@", errorMessage] cancelAction:^{
                        [self.navigationController popViewControllerAnimated:YES];
                    }];
                }
                    break;
                default:
                    break;
            }
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
        videoTrack.videoDelegate = self;
        self.remoteVideoTrack = videoTrack;
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
        videoTrack.videoDelegate = nil;
        self.remoteVideoTrack =  nil;
        self.remoteRenderView.hidden = YES;
        [self.controlView.lowButton deselectAllButtons];
        self.controlView.currentProfileTF.text = @"None";
    }
}


@end
