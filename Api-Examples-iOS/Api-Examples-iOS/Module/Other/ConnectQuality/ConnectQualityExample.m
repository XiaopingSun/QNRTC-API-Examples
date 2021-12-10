//
//  ConnectQualityExample.m
//  Api-Examples-iOS
//
//  Created by WorkSpace_Sun on 2021/12/8.
//

#import "ConnectQualityExample.h"
#import "ConnectQualityControlView.h"

static NSString *network_grade[] = {@"初始状态", @"网络优", @"网络良", @"网络一般", @"网络差"};
static NSString *video_profile[] = {@"Low", @"Medium", @"High"};

@interface ConnectQualityExample () <QNRTCClientDelegate>

@property (nonatomic, strong) ConnectQualityControlView *controlView;
@property (nonatomic, strong) NSTimer *timer;

@property (nonatomic, strong) QNRTCClient *client;
@property (nonatomic, strong) QNCameraVideoTrack *cameraVideoTrack;
@property (nonatomic, strong) QNMicrophoneAudioTrack *microphoneAudioTrack;
@property (nonatomic, strong) QNGLKView *localRenderView;
@property (nonatomic, strong) QNVideoView *remoteRenderView;
@property (nonatomic, copy) NSString *remoteUserID;

@end

@implementation ConnectQualityExample

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    [self loadSubviews];
    [self initRTC];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(getTrackStatsAndShow) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
    [self.timer fire];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.timer invalidate];
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
    self.tipsView.text = @"Tips：本示例仅展示一对一场景下发布订阅后获取本地和远端单路音视频 Track 状态统计的功能。质量统计参数详细介绍可参考：\nhttps://developer.qiniu.com/rtc/10085/quality-statistics-iOS";
    
    // 添加状态统计视图
    self.controlView = [[[NSBundle mainBundle] loadNibNamed:@"ConnectQualityControlView" owner:nil options:nil] lastObject];
    [self.controlScrollView addSubview:self.controlView];
    [self.controlView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.equalTo(self.controlView);
        make.width.mas_equalTo(SCREEN_WIDTH);
        make.height.mas_equalTo(660);
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
    
    // 创建相机采集视频 Track
    self.cameraVideoTrack = [QNRTC createCameraVideoTrack];
    
    // 创建麦克风采集音频 Track
    self.microphoneAudioTrack = [QNRTC createMicrophoneAudioTrack];
        
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
    [self.client publish:@[self.cameraVideoTrack, self.microphoneAudioTrack] completeCallback:^(BOOL onPublished, NSError *error) {
        if (onPublished) {
            [self showAlertWithTitle:@"房间状态" message:@"发布成功"];
        } else {
            [self showAlertWithTitle:@"房间状态" message:[NSString stringWithFormat:@"发布失败: %@", error.localizedDescription]];
        }
    }];
}

#pragma mark - 通话质量统计相关
/*!
 * @abstract 展示本地和远端网络质量、单路音视频 Track 的统计信息
 */
- (void)getTrackStatsAndShow {
    // 本端用户质量统计
    if (self.client.roomState == QNConnectionStateConnected || self.client.roomState == QNConnectionStateReconnected) {
        // 网络质量
        QNNetworkQuality *localNetworkQuality = [self.client getUserNetworkQuality:self.userID];
        if (localNetworkQuality) {
            self.controlView.localUplinkNetworkGradeL.text = network_grade[localNetworkQuality.uplinkNetworkGrade];
            self.controlView.localDownlinkNetworkGradeL.text = network_grade[localNetworkQuality.downlinkNetworkGrade];
        }
        
        // 音频 Track 质量
        NSDictionary *localAudioTrackStats = [self.client getLocalAudioTrackStats];
        if (localAudioTrackStats && localAudioTrackStats.count > 0) {
            for (NSString *trackID in localAudioTrackStats.allKeys) {
                if ([self.microphoneAudioTrack.trackID isEqualToString:trackID]) {
                    QNLocalAudioTrackStats *microphoneAudioTrackStat = localAudioTrackStats[trackID];
                    self.controlView.localAudioUplinkBitrateL.text = [NSString stringWithFormat:@"%d kbps", (int)microphoneAudioTrackStat.uplinkBitrate / 1000];
                    self.controlView.localAudioUplinkRttL.text = [NSString stringWithFormat:@"%lu ms", microphoneAudioTrackStat.uplinkRTT];
                    self.controlView.localAudioUplinkLostRateL.text = [NSString stringWithFormat:@"%.1f %%", microphoneAudioTrackStat.uplinkLostRate];
                }
            }
        }
        
        // 视频 Track 质量
        NSDictionary *localVideoTrackStats = [self.client getLocalVideoTrackStats];
        if (localVideoTrackStats && localVideoTrackStats.count > 0) {
            for (NSString *trackID in localVideoTrackStats.allKeys) {
                if ([self.cameraVideoTrack.trackID isEqualToString:trackID]) {
                    QNLocalVideoTrackStats *cameraVideoTrackStat = localVideoTrackStats[trackID];
                    self.controlView.localVideoProfileL.text = video_profile[cameraVideoTrackStat.profile];
                    self.controlView.localVideoUplinkFpsL.text = [NSString stringWithFormat:@"%lu fps", cameraVideoTrackStat.uplinkFrameRate];
                    self.controlView.localVideoUplinkBitrateL.text = [NSString stringWithFormat:@"%d kbps", (int)cameraVideoTrackStat.uplinkBitrate / 1000];
                    self.controlView.localVideoUplinkRttL.text = [NSString stringWithFormat:@"%lu ms", cameraVideoTrackStat.uplinkRTT];
                    self.controlView.localVideoUplinkLostRateL.text = [NSString stringWithFormat:@"%.1f %%", cameraVideoTrackStat.uplinkLostRate];
                }
            }
        }
    } else {
        [self.controlView resetLocal];
    }
            
    // 远端用户质量统计
    if (self.remoteUserID) {
        // 获取远端用户对象
        QNRemoteUser *remoteUser = [self.client getRemoteUser:self.remoteUserID];
        if (remoteUser) {
            // 取该用户音视频 Track 数组的首个 Track 做统计展示
            QNRemoteAudioTrack *remoteAudioTrack = remoteUser.audioTrack.firstObject;
            QNRemoteVideoTrack *remoteVideoTrack = remoteUser.videoTrack.firstObject;
            
            // 网络质量
            QNNetworkQuality *remoteNetworkQuality = [self.client getUserNetworkQuality:self.remoteUserID];
            if (remoteNetworkQuality) {
                self.controlView.remoteUplinkNetworkGradeL.text = network_grade[remoteNetworkQuality.uplinkNetworkGrade];
                self.controlView.remoteDownlinkNetworkGradeL.text = network_grade[remoteNetworkQuality.downlinkNetworkGrade];
            }
            
            // 音频 Track 质量
            NSDictionary *remoteAudioTrackStats = [self.client getRemoteAudioTrackStats];
            if (remoteAudioTrackStats && remoteAudioTrackStats.count > 0) {
                for (NSString *trackID in remoteAudioTrackStats.allKeys) {
                    if ([remoteAudioTrack.trackID isEqualToString:trackID]) {
                        QNRemoteAudioTrackStats *remoteAudioTrackStat = remoteAudioTrackStats[trackID];
                        self.controlView.remoteAudioDownlinkBitrateL.text = [NSString stringWithFormat:@"%d kbps", (int)remoteAudioTrackStat.downlinkBitrate / 1000];
                        self.controlView.remoteAudioDownloadLostRateL.text = [NSString stringWithFormat:@"%.1f %%", remoteAudioTrackStat.downlinkLostRate];
                        self.controlView.remoteAudioUplinkRttL.text = [NSString stringWithFormat:@"%lu ms", remoteAudioTrackStat.uplinkRTT];
                        self.controlView.remoteAudioUplinkLostRateL.text = [NSString stringWithFormat:@"%.1f %%", remoteAudioTrackStat.uplinkLostRate];
                    }
                }
            }
            
            // 视频 Track 质量
            NSDictionary *remoteVideoTrackStats = [self.client getRemoteVideoTrackStats];
            if (remoteVideoTrackStats && remoteVideoTrackStats.count > 0) {
                for (NSString *trackID in remoteVideoTrackStats.allKeys) {
                    if ([remoteVideoTrack.trackID isEqualToString:trackID]) {
                        QNRemoteVideoTrackStats *remoteVideoTrackStat = remoteVideoTrackStats[trackID];
                        self.controlView.remoteVideoProfileL.text = video_profile[remoteVideoTrackStat.profile];
                        self.controlView.remoteVideoDownloadFpsL.text = [NSString stringWithFormat:@"%lu fps", remoteVideoTrackStat.downlinkFrameRate];
                        self.controlView.remoteVideoDownloadBitrateL.text = [NSString stringWithFormat:@"%.1f kbps", remoteVideoTrackStat.downlinkBitrate / 1000];
                        self.controlView.remoteVideoDownloadLostRateL.text = [NSString stringWithFormat:@"%.1f %%", remoteVideoTrackStat.downlinkLostRate];
                        self.controlView.remoteVideoUplinkRttL.text = [NSString stringWithFormat:@"%lu ms", remoteVideoTrackStat.uplinkRTT];
                        self.controlView.remoteVideoUplinkLostRateL.text = [NSString stringWithFormat:@"%.1f %%", remoteVideoTrackStat.uplinkLostRate];
                    }
                }
            }
        } else {
            [self.controlView resetRemote];
        }
    } else {
        [self.controlView resetRemote];
    }
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
