#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ErrorView : UIView

@property (nonatomic, strong, readonly) UILabel *messageLabel;
@property (nonatomic, strong, readonly) UIButton *retryButton;

- (void)showError:(NSString *)message withRetryAction:(void (^)(void))retryAction;
- (void)hide;

@end

NS_ASSUME_NONNULL_END 