//
//  DirectLiveControlView.h
//  Api-Examples-iOS
//
//  Created by WorkSpace_Sun on 2021/12/8.
//

#import <UIKit/UIKit.h>
#import "RadioButton.h"

NS_ASSUME_NONNULL_BEGIN

@interface DirectLiveControlView : UIView
@property (weak, nonatomic) IBOutlet UITextField *publishUrlTF;
@property (weak, nonatomic) IBOutlet RadioButton *localUserButton;
@property (weak, nonatomic) IBOutlet RadioButton *remoteUserButton;
@property (weak, nonatomic) IBOutlet UIButton *startButton;
@property (weak, nonatomic) IBOutlet UIButton *stopButton;
@end

NS_ASSUME_NONNULL_END
