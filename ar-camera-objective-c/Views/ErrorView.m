#import "ErrorView.h"

@interface ErrorView ()

@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UIButton *retryButton;
@property (nonatomic, copy) void (^retryAction)(void);

@end

@implementation ErrorView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
    self.layer.cornerRadius = 10;
    self.clipsToBounds = YES;
    
    // Message Label
    self.messageLabel = [[UILabel alloc] init];
    self.messageLabel.textColor = [UIColor whiteColor];
    self.messageLabel.textAlignment = NSTextAlignmentCenter;
    self.messageLabel.numberOfLines = 0;
    self.messageLabel.font = [UIFont systemFontOfSize:16];
    [self addSubview:self.messageLabel];
    
    // Retry Button
    self.retryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.retryButton setTitle:@"Retry" forState:UIControlStateNormal];
    [self.retryButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.retryButton.backgroundColor = [UIColor systemBlueColor];
    self.retryButton.layer.cornerRadius = 5;
    [self.retryButton addTarget:self action:@selector(retryButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.retryButton];
    
    // Layout
    self.messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.retryButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    [NSLayoutConstraint activateConstraints:@[
        [self.messageLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:20],
        [self.messageLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
        [self.messageLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],
        
        [self.retryButton.topAnchor constraintEqualToAnchor:self.messageLabel.bottomAnchor constant:20],
        [self.retryButton.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [self.retryButton.widthAnchor constraintEqualToConstant:100],
        [self.retryButton.heightAnchor constraintEqualToConstant:40],
        [self.retryButton.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-20]
    ]];
}

- (void)showError:(NSString *)message withRetryAction:(void (^)(void))retryAction {
    self.messageLabel.text = message;
    self.retryAction = retryAction;
    self.hidden = NO;
    self.alpha = 0;
    
    [UIView animateWithDuration:0.3 animations:^{
        self.alpha = 1;
    }];
}

- (void)hide {
    [UIView animateWithDuration:0.3 animations:^{
        self.alpha = 0;
    } completion:^(BOOL finished) {
        self.hidden = YES;
    }];
}

- (void)retryButtonTapped {
    if (self.retryAction) {
        self.retryAction();
    }
    [self hide];
}

@end 