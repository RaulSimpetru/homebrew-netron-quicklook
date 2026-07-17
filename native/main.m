#import <AppKit/AppKit.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property(nonatomic, strong) NSWindow *window;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    NSRect frame = NSMakeRect(0, 0, 520, 300);
    NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable;
    self.window = [[NSWindow alloc] initWithContentRect:frame styleMask:style backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"Netron Quick Look";
    self.window.releasedWhenClosed = NO;

    NSTextField *title = [NSTextField labelWithString:@"Netron Quick Look is installed"];
    title.font = [NSFont systemFontOfSize:20 weight:NSFontWeightSemibold];
    title.alignment = NSTextAlignmentCenter;

    NSTextField *detail = [NSTextField wrappingLabelWithString:@"Select a supported machine-learning model in Finder and press Space to open the full interactive Netron graph viewer. This independent extension does not replace or modify the Netron app."];
    detail.alignment = NSTextAlignmentCenter;
    detail.textColor = NSColor.secondaryLabelColor;
    detail.maximumNumberOfLines = 0;

    NSButton *settings = [NSButton buttonWithTitle:@"Open Extensions Settings" target:self action:@selector(openExtensionsSettings:)];
    settings.bezelStyle = NSBezelStyleRounded;

    NSStackView *stack = [NSStackView stackViewWithViews:@[title, detail, settings]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeCenterX;
    stack.spacing = 18;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.window.contentView addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.window.contentView.leadingAnchor constant:48],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:self.window.contentView.trailingAnchor constant:-48],
        [stack.centerXAnchor constraintEqualToAnchor:self.window.contentView.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:self.window.contentView.centerYAnchor],
        [detail.widthAnchor constraintEqualToConstant:420]
    ]];

    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    (void)sender;
    return YES;
}

- (void)openExtensionsSettings:(id)sender {
    (void)sender;
    NSURL *url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.ExtensionsPreferences"];
    [NSWorkspace.sharedWorkspace openURL:url];
}

@end

int main(void) {
    @autoreleasepool {
        NSApplication *application = NSApplication.sharedApplication;
        AppDelegate *delegate = [[AppDelegate alloc] init];
        application.delegate = delegate;
        application.activationPolicy = NSApplicationActivationPolicyRegular;
        [application run];
    }
    return 0;
}
