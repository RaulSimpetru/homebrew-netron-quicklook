#import <AppKit/AppKit.h>

static const CGFloat WindowWidth = 600;
static const CGFloat Inset = 32;

// A rounded background that re-resolves its dynamic colors when the appearance changes.
@interface PillView : NSView

@property(nonatomic, strong) NSColor *fill;
@property(nonatomic, strong) NSColor *border;

@end

@implementation PillView

- (BOOL)wantsUpdateLayer {
    return YES;
}

- (void)updateLayer {
    self.layer.cornerRadius = 6;
    self.layer.backgroundColor = self.fill.CGColor;
    self.layer.borderColor = self.border.CGColor;
    self.layer.borderWidth = self.border ? 1 : 0;
}

@end

static NSTextField *Label(NSString *text, NSFont *font, NSColor *color) {
    NSTextField *label = [NSTextField labelWithString:text];
    label.font = font;
    label.textColor = color;
    return label;
}

static NSView *Pill(NSString *text, NSColor *fill, NSColor *border, CGFloat horizontalPadding) {
    PillView *pill = [[PillView alloc] init];
    pill.wantsLayer = YES;
    pill.fill = fill;
    pill.border = border;
    pill.translatesAutoresizingMaskIntoConstraints = NO;
    NSTextField *label = Label(text, [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular], NSColor.labelColor);
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [pill addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:pill.leadingAnchor constant:horizontalPadding],
        [label.trailingAnchor constraintEqualToAnchor:pill.trailingAnchor constant:-horizontalPadding],
        [label.topAnchor constraintEqualToAnchor:pill.topAnchor constant:3],
        [label.bottomAnchor constraintEqualToAnchor:pill.bottomAnchor constant:-3]
    ]];
    return pill;
}

static NSView *Separator(void) {
    NSBox *line = [[NSBox alloc] init];
    line.boxType = NSBoxSeparator;
    return line;
}

static NSView *Row(NSString *symbol, NSColor *tint, NSString *text, NSView *trailing) {
    NSImageView *icon = [NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil]];
    icon.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:17 weight:NSFontWeightRegular];
    icon.contentTintColor = tint;
    [icon.widthAnchor constraintEqualToConstant:22].active = YES;
    NSTextField *label = Label(text, [NSFont systemFontOfSize:13 weight:NSFontWeightMedium], NSColor.labelColor);
    [label setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSStackView *row = [NSStackView stackViewWithViews:@[icon, label, trailing]];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeCenterY;
    row.distribution = NSStackViewDistributionFill;
    row.spacing = 12;
    [row.heightAnchor constraintGreaterThanOrEqualToConstant:48].active = YES;
    return row;
}

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property(nonatomic, strong) NSWindow *window;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    NSDictionary *info = NSBundle.mainBundle.infoDictionary;
    NSString *version = info[@"CFBundleShortVersionString"] ?: @"";
    NSArray *declarations = info[@"UTImportedTypeDeclarations"];
    NSDictionary *declaration = declarations.firstObject;
    NSArray *extensions = declaration[@"UTTypeTagSpecification"][@"public.filename-extension"];

    NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable;
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, WindowWidth, 440) styleMask:style backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"Netron Quick Look";
    self.window.releasedWhenClosed = NO;

    NSImageView *appIcon = [NSImageView imageViewWithImage:NSApp.applicationIconImage];
    [NSLayoutConstraint activateConstraints:@[
        [appIcon.widthAnchor constraintEqualToConstant:80],
        [appIcon.heightAnchor constraintEqualToConstant:80]
    ]];
    NSTextField *title = Label(@"Ready to preview models", [NSFont systemFontOfSize:22 weight:NSFontWeightSemibold], NSColor.labelColor);
    NSTextField *subtitle = [NSTextField wrappingLabelWithString:@"Select a model in Finder and press Space to open the interactive graph."];
    subtitle.textColor = NSColor.secondaryLabelColor;
    NSStackView *headline = [NSStackView stackViewWithViews:@[title, subtitle]];
    headline.orientation = NSUserInterfaceLayoutOrientationVertical;
    headline.alignment = NSLayoutAttributeLeading;
    headline.spacing = 4;
    NSStackView *header = [NSStackView stackViewWithViews:@[appIcon, headline]];
    header.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    header.alignment = NSLayoutAttributeCenterY;
    header.spacing = 18;

    NSTextField *versionLabel = Label([NSString stringWithFormat:@"Version %@", version], [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular], NSColor.secondaryLabelColor);
    NSButton *settings = [NSButton buttonWithTitle:@"Extensions Settings…" target:self action:@selector(openExtensionsSettings:)];
    settings.bezelStyle = NSBezelStyleRounded;
    NSView *spaceKey = Pill(@"space", NSColor.controlBackgroundColor, NSColor.separatorColor, 20);
    NSStackView *checklist = [NSStackView stackViewWithViews:@[
        Separator(),
        Row(@"checkmark.circle", NSColor.systemGreenColor, @"App installed", versionLabel),
        Separator(),
        Row(@"puzzlepiece.extension", NSColor.secondaryLabelColor, @"Quick Look extension", settings),
        Separator(),
        Row(@"magnifyingglass", NSColor.systemOrangeColor, @"Try it: select a model, then press", spaceKey),
        Separator()
    ]];
    checklist.orientation = NSUserInterfaceLayoutOrientationVertical;
    checklist.spacing = 0;
    for (NSView *view in checklist.arrangedSubviews) {
        [view.widthAnchor constraintEqualToAnchor:checklist.widthAnchor].active = YES;
    }

    NSArray<NSString *> *featured = @[@"onnx", @"pt", @"safetensors", @"gguf", @"tflite", @"keras"];
    NSMutableArray<NSView *> *chips = [NSMutableArray array];
    for (NSString *extension in featured) {
        [chips addObject:Pill([@"." stringByAppendingString:extension], NSColor.quaternaryLabelColor, nil, 7)];
    }
    if (extensions.count > featured.count) {
        NSString *more = [NSString stringWithFormat:@"+%lu more", (unsigned long)(extensions.count - featured.count)];
        [chips addObject:Label(more, [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular], NSColor.secondaryLabelColor)];
    }
    NSStackView *chipRow = [NSStackView stackViewWithViews:chips];
    chipRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    chipRow.spacing = 6;
    NSString *formatsText = [NSString stringWithFormat:@"Previews %lu model formats", (unsigned long)extensions.count];
    NSStackView *formats = [NSStackView stackViewWithViews:@[Label(formatsText, [NSFont systemFontOfSize:12], NSColor.secondaryLabelColor), chipRow]];
    formats.orientation = NSUserInterfaceLayoutOrientationVertical;
    formats.alignment = NSLayoutAttributeLeading;
    formats.spacing = 8;

    NSTextField *credit = Label(@"Independent project · renders with Netron (MIT)", [NSFont systemFontOfSize:11], NSColor.secondaryLabelColor);
    [credit setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSButton *notices = [NSButton buttonWithTitle:@"Notices" target:self action:@selector(openNotices:)];
    notices.bordered = NO;
    notices.attributedTitle = [[NSAttributedString alloc] initWithString:@"Notices" attributes:@{
        NSForegroundColorAttributeName: NSColor.linkColor,
        NSFontAttributeName: [NSFont systemFontOfSize:11]
    }];
    NSStackView *footer = [NSStackView stackViewWithViews:@[credit, notices]];
    footer.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    footer.distribution = NSStackViewDistributionFill;

    NSStackView *stack = [NSStackView stackViewWithViews:@[header, checklist, formats, footer]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 22;
    stack.edgeInsets = NSEdgeInsetsMake(26, Inset, 18, Inset);
    [stack setCustomSpacing:18 afterView:formats];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    NSView *content = self.window.contentView;
    [content addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [content.widthAnchor constraintEqualToConstant:WindowWidth],
        [stack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:content.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:content.bottomAnchor],
        [checklist.widthAnchor constraintEqualToConstant:WindowWidth - 2 * Inset],
        [footer.widthAnchor constraintEqualToConstant:WindowWidth - 2 * Inset],
        [subtitle.widthAnchor constraintEqualToConstant:WindowWidth - 2 * Inset - 98]
    ]];

    [self.window layoutIfNeeded];
    [self.window setContentSize:NSMakeSize(WindowWidth, stack.fittingSize.height)];
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

- (void)openNotices:(id)sender {
    (void)sender;
    NSURL *url = [NSBundle.mainBundle URLForResource:@"THIRD_PARTY_NOTICES" withExtension:@"txt"];
    if (url) {
        [NSWorkspace.sharedWorkspace openURL:url];
    }
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
