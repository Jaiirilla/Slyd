#import "Tweak.h"

/* Config */
static bool enabled = true;
static bool showChevron = true;
static bool disableHome = true;
static bool disableSwipe = true;
static NSString *text = @"slide to unlock";

/* Random stuff to keep track of */
static SBPagedScrollView *psv = nil;
static SBDashBoardMainPageView *sdbmpv = nil;
static SBDashBoardTodayContentView *sdbtcv = nil;
static SBDashBoardFixedFooterViewController *sdbffvc = nil;
static SBDashBoardTeachableMomentsContainerViewController *sdbtmcvc = nil;
static bool preventHome = false;
static bool isOnLockscreen = true;
static bool canUnlock = false;

void setIsOnLockscreen(bool isIt) {
    isOnLockscreen = isIt;
    preventHome = false;
    canUnlock = false;
    [sdbmpv stuStateChanged];
    [sdbtcv stuStateChanged];
    [sdbffvc stuStateChanged];
    [sdbtmcvc stuStateChanged];
}

%group SlideToUnlock

%hook SBDashBoardMainPageView

%property (nonatomic, retain) _UIGlintyStringView *stuGlintyStringView;

-(id)initWithFrame:(CGRect)arg1 {
    id orig = %orig;
    sdbmpv = self;
    return orig;
}

-(void)layoutSubviews {
    %orig;
    if (!self.stuGlintyStringView) {
        self.stuGlintyStringView = [[_UIGlintyStringView alloc] initWithText:text andFont:[UIFont systemFontOfSize:25]];
    }

    [self stuStateChanged];
}

%new;
-(void)stuStateChanged {
    if (isOnLockscreen && enabled) {
        [self addSubview:self.stuGlintyStringView];
        self.stuGlintyStringView.frame = CGRectMake(0, self.frame.size.height - 150, self.frame.size.width, 150);
        [self sendSubviewToBack:self.stuGlintyStringView];
        if (showChevron) {
            [self.stuGlintyStringView setChevronStyle:1];
        } else {
            [self.stuGlintyStringView setChevronStyle:0];
        }
        [self.stuGlintyStringView hide];
        [self.stuGlintyStringView show];
    } else {
        [self.stuGlintyStringView hide];
        [self.stuGlintyStringView removeFromSuperview];
    }
}

%end

%hook SBUIPasscodeLockNumberPad

-(void)_cancelButtonHit {
    %orig;
    if (psv && enabled) {
        preventHome = true;
        [psv scrollToPageAtIndex:1 animated:true];
    }
}

%end

%hook SBPagedScrollView

-(id)initWithFrame:(CGRect)arg1 {
    id orig = %orig;
    psv = self;
    return orig;
}

-(void)_bs_didScrollWithContext:(id)arg1 {
    %orig;
    if (self.currentPageIndex == 0 && self.pageRelativeScrollOffset < 0.50
            && !preventHome && isOnLockscreen && enabled) {
        preventHome = true;
        canUnlock = true;
        [[%c(SBLockScreenManager) sharedInstance] lockScreenViewControllerRequestsUnlock];
    }

    if (self.currentPageIndex != 0) {
        preventHome = false;
    }
}

-(void)setCurrentPageIndex:(NSUInteger)idx {
    %orig;
}

%end

%hook SBCoverSheetPrimarySlidingViewController

-(void)_handleDismissGesture:(id)arg1 {
    if (enabled && isOnLockscreen && disableSwipe) {
        return;
    }

    %orig;
}

-(void)setPresented:(BOOL)arg1 animated:(BOOL)arg2 withCompletion:(/*^block*/id)arg3 {
    if (enabled && isOnLockscreen && disableHome && !arg1 && !canUnlock) {
        return;
    }

    %orig;
}

%end

/* Bloat remover */

%hook SBDashBoardTodayContentView

-(id)initWithFrame:(CGRect)arg1 {
    id orig = %orig;
    sdbtcv = self;
    return orig;
}

-(void)layoutSubviews {
    %orig;
    [self stuStateChanged];
}

%new;
-(void)stuStateChanged {
    if (isOnLockscreen && enabled) {
        self.alpha = 0.0;
        self.hidden = YES;
    } else {
        self.alpha = 1.0;
        self.hidden = NO;
    }
}

%end

/* Move time/date with slide to unlock */

%hook SBDashBoardTodayPageViewController

-(void)aggregateAppearance:(id)arg1 {
    %orig;
    SBDashBoardComponent *dateView = [[NSClassFromString(@"SBDashBoardComponent") dateView] hidden:YES];
    [arg1 addComponent:dateView];
}

%end

%hook SBDashBoardFixedFooterViewController

-(id)init {
    id orig = %orig;
    sdbffvc = self;
    return orig;
}

-(void)viewDidLoad{
    %orig;
    [self stuStateChanged];
}

%new;
-(void)stuStateChanged {
    if (enabled) {
        self.view.alpha = 0.0;
        self.view.hidden = YES;
    } else {
        self.view.alpha = 1.0;
        self.view.hidden = NO;
    }
}

%end

%hook SBDashBoardTeachableMomentsContainerViewController

-(id)init {
    id orig = %orig;
    sdbtmcvc = self;
    return orig;
}

-(void)viewDidLoad{
    %orig;
    [self stuStateChanged];
}

%new;
-(void)stuStateChanged {
    if (enabled) {
        self.view.alpha = 0.0;
        self.view.hidden = YES;
    } else {
        self.view.alpha = 1.0;
        self.view.hidden = NO;
    }
}

%end

/* Check for unlock */

%hook SBDashBoardViewController

-(void)viewWillAppear:(BOOL)animated {
    %orig;

    setIsOnLockscreen(!self.authenticated);
}

%end

%end

static void displayStatusChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    setIsOnLockscreen(true);
}

static void reloadPreferences() {
    HBPreferences *file = [[HBPreferences alloc] initWithIdentifier:@"me.nepeta.slyd"];
    enabled = [([file objectForKey:@"Enabled"] ?: @(YES)) boolValue];
    showChevron = [([file objectForKey:@"ShowChevron"] ?: @(YES)) boolValue];
    disableHome = [([file objectForKey:@"DisableHome"] ?: @(YES)) boolValue];
    disableSwipe = [([file objectForKey:@"DisableSwipe"] ?: @(YES)) boolValue];
    text = [file objectForKey:@"Text"];
    if (!text) text = @"slide to unlock";

    if (sdbmpv) {
        [sdbmpv.stuGlintyStringView setText:text];
        [sdbmpv.stuGlintyStringView setNeedsTextUpdate:true];
        [sdbmpv.stuGlintyStringView updateText];
    }

    setIsOnLockscreen(isOnLockscreen);
}

%ctor{
    reloadPreferences();
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)reloadPreferences, (CFStringRef)@"me.nepeta.slyd/ReloadPrefs", NULL, kNilOptions);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, displayStatusChanged, CFSTR("com.apple.iokit.hid.displayStatus"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);

    %init(SlideToUnlock);
}
