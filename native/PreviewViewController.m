#import <AppKit/AppKit.h>
#import <QuickLookUI/QuickLookUI.h>
#import <WebKit/WebKit.h>

static NSString *const PreviewErrorDomain = @"io.github.raulsimpetru.NetronQuickLook.preview";

static unsigned long long PreviewMaximumFileSize(void) {
    static unsigned long long maximumFileSize = 0;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSNumber *maximumSizeMiB = [NSBundle.mainBundle objectForInfoDictionaryKey:@"NetronQuickLookMaximumPreviewSizeMiB"];
        maximumFileSize = maximumSizeMiB.unsignedLongLongValue * 1024ULL * 1024ULL;
    });
    return maximumFileSize;
}

typedef NS_ENUM(NSInteger, PreviewErrorCode) {
    PreviewErrorInvalidURL = 1,
    PreviewErrorFileNotFound = 2,
    PreviewErrorFileTooLarge = 3
};

@interface ModelSchemeHandler : NSObject <WKURLSchemeHandler>

@property(nonatomic, nullable, copy) NSURL *modelURL;

@end


@interface ModelSchemeHandler ()

@property(nonatomic, readonly) NSURL *resourceRoot;
@property(nonatomic, readonly) dispatch_queue_t queue;
@property(nonatomic, readonly) NSMutableSet<NSValue *> *activeTasks;
@property(nonatomic) BOOL securityScopeActive;

@end


@implementation ModelSchemeHandler

- (instancetype)init {
    self = [super init];
    if (self) {
        _resourceRoot = [[NSBundle bundleForClass:self.class] URLForResource:@"Web" withExtension:nil];
        _queue = dispatch_queue_create("io.github.raulsimpetru.netron-quicklook.files", DISPATCH_QUEUE_CONCURRENT);
        _activeTasks = [NSMutableSet set];
    }
    return self;
}

- (void)dealloc {
    if (_securityScopeActive) {
        [_modelURL stopAccessingSecurityScopedResource];
    }
}

- (void)setModelURL:(NSURL *)modelURL {
    if ([_modelURL isEqual:modelURL]) {
        return;
    }
    if (_securityScopeActive) {
        [_modelURL stopAccessingSecurityScopedResource];
    }
    _modelURL = [modelURL copy];
    _securityScopeActive = [_modelURL startAccessingSecurityScopedResource];
}

- (void)webView:(WKWebView *)webView startURLSchemeTask:(id<WKURLSchemeTask>)urlSchemeTask {
    (void)webView;
    [self registerTask:urlSchemeTask];
    NSError *error = nil;
    NSURL *fileURL = [self fileURLForRequestURL:urlSchemeTask.request.URL error:&error];
    if (!fileURL) {
        [self finishTask:urlSchemeTask data:nil response:nil error:error];
        return;
    }
    dispatch_async(self.queue, ^{
        NSError *readError = nil;
        NSNumber *fileSize = nil;
        [fileURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:&readError];
        if (!readError && fileSize.unsignedLongLongValue > PreviewMaximumFileSize()) {
            readError = [self errorWithCode:PreviewErrorFileTooLarge description:@"This model is too large for a Quick Look preview."];
        }
        NSData *data = readError ? nil : [NSData dataWithContentsOfURL:fileURL options:NSDataReadingMappedIfSafe error:&readError];
        NSURLResponse *response = nil;
        if (data) {
            NSString *mimeType = [self mimeTypeForFileURL:fileURL];
            BOOL text = [mimeType hasPrefix:@"text/"] || [mimeType isEqualToString:@"application/json"];
            NSString *textEncoding = text ? @"utf-8" : nil;
            response = [[NSURLResponse alloc] initWithURL:urlSchemeTask.request.URL MIMEType:mimeType expectedContentLength:(NSInteger)data.length textEncodingName:textEncoding];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self finishTask:urlSchemeTask data:data response:response error:readError];
        });
    });
}

- (void)webView:(WKWebView *)webView stopURLSchemeTask:(id<WKURLSchemeTask>)urlSchemeTask {
    (void)webView;
    @synchronized(self.activeTasks) {
        [self.activeTasks removeObject:[NSValue valueWithNonretainedObject:urlSchemeTask]];
    }
}

- (void)registerTask:(id<WKURLSchemeTask>)task {
    @synchronized(self.activeTasks) {
        [self.activeTasks addObject:[NSValue valueWithNonretainedObject:task]];
    }
}

- (BOOL)takeTask:(id<WKURLSchemeTask>)task {
    NSValue *key = [NSValue valueWithNonretainedObject:task];
    @synchronized(self.activeTasks) {
        if (![self.activeTasks containsObject:key]) {
            return NO;
        }
        [self.activeTasks removeObject:key];
        return YES;
    }
}

- (void)finishTask:(id<WKURLSchemeTask>)task data:(NSData *)data response:(NSURLResponse *)response error:(NSError *)error {
    if (![self takeTask:task]) {
        return;
    }
    if (error) {
        [task didFailWithError:error];
        return;
    }
    [task didReceiveResponse:response];
    [task didReceiveData:data];
    [task didFinish];
}

- (NSURL *)fileURLForRequestURL:(NSURL *)url error:(NSError **)error {
    if (![url.scheme isEqualToString:@"netron-quicklook"] || ![url.host isEqualToString:@"app"]) {
        if (error) {
            *error = [self errorWithCode:PreviewErrorInvalidURL description:@"Invalid preview URL."];
        }
        return nil;
    }
    NSString *requestPath = url.path.stringByRemovingPercentEncoding ?: url.path;
    BOOL modelRequest = [requestPath hasPrefix:@"/model/"];
    NSUInteger offset = modelRequest ? @"/model/".length : MIN((NSUInteger)1, requestPath.length);
    NSString *relativePath = [requestPath substringFromIndex:offset];
    if (!modelRequest && relativePath.length == 0) {
        relativePath = @"index.html";
    }
    NSURL *root = modelRequest ? self.modelURL.URLByDeletingLastPathComponent : self.resourceRoot;
    if (!root || relativePath.length == 0 || [relativePath.pathComponents containsObject:@".."] || [relativePath.pathComponents containsObject:@"."]) {
        if (error) {
            *error = [self errorWithCode:PreviewErrorInvalidURL description:@"Invalid preview path."];
        }
        return nil;
    }
    root = root.URLByStandardizingPath;
    NSURL *fileURL = [[root URLByAppendingPathComponent:relativePath] URLByStandardizingPath];
    NSString *rootPath = root.path;
    NSString *filePath = fileURL.path;
    NSString *rootPrefix = [rootPath stringByAppendingString:@"/"];
    if (![filePath isEqualToString:rootPath] && ![filePath hasPrefix:rootPrefix]) {
        if (error) {
            *error = [self errorWithCode:PreviewErrorInvalidURL description:@"The preview requested a file outside its allowed directory."];
        }
        return nil;
    }
    NSNumber *regularFile = nil;
    if (![fileURL getResourceValue:&regularFile forKey:NSURLIsRegularFileKey error:error] || !regularFile.boolValue) {
        if (error && !*error) {
            *error = [self errorWithCode:PreviewErrorFileNotFound description:@"The requested preview file was not found."];
        }
        return nil;
    }
    return fileURL;
}

- (NSString *)mimeTypeForFileURL:(NSURL *)url {
    static NSDictionary<NSString *, NSString *> *types;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        types = @{
            @"css": @"text/css",
            @"html": @"text/html",
            @"ico": @"image/x-icon",
            @"js": @"text/javascript",
            @"json": @"application/json",
            @"png": @"image/png"
        };
    });
    return types[url.pathExtension.lowercaseString] ?: @"application/octet-stream";
}

- (NSError *)errorWithCode:(PreviewErrorCode)code description:(NSString *)description {
    return [NSError errorWithDomain:PreviewErrorDomain code:code userInfo:@{ NSLocalizedDescriptionKey: description }];
}

@end

@interface PreviewViewController : NSViewController <QLPreviewingController, WKNavigationDelegate> {
    ModelSchemeHandler *_schemeHandler;
    WKWebView *_webView;
}

@property(nonatomic, readonly) ModelSchemeHandler *schemeHandler;
@property(nonatomic, readonly) WKWebView *webView;

@end


@implementation PreviewViewController

- (void)loadView {
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    configuration.websiteDataStore = WKWebsiteDataStore.nonPersistentDataStore;
    [configuration setURLSchemeHandler:self.schemeHandler forURLScheme:@"netron-quicklook"];
    _webView = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 960, 720) configuration:configuration];
    _webView.navigationDelegate = self;
    _webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.view = _webView;
}

- (ModelSchemeHandler *)schemeHandler {
    if (!_schemeHandler) {
        _schemeHandler = [[ModelSchemeHandler alloc] init];
    }
    return _schemeHandler;
}

- (void)preparePreviewOfFileAtURL:(NSURL *)url completionHandler:(void (^)(NSError * _Nullable))handler {
    (void)self.view;
    NSNumber *isDirectory = nil;
    NSNumber *fileSize = nil;
    NSError *error = nil;
    [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error];
    [url getResourceValue:&fileSize forKey:NSURLFileSizeKey error:&error];
    if (isDirectory.boolValue) {
        [self showMessageForURL:url detail:@"Package models are not supported in Quick Look yet."];
        handler(nil);
        return;
    }
    if (fileSize.unsignedLongLongValue > PreviewMaximumFileSize()) {
        NSByteCountFormatter *formatter = [[NSByteCountFormatter alloc] init];
        NSString *size = [formatter stringFromByteCount:fileSize.longLongValue];
        NSString *message = [NSString stringWithFormat:@"This %@ model is too large for a Quick Look preview. Open it in Netron to inspect the graph.", size];
        [self showMessageForURL:url detail:message];
        handler(nil);
        return;
    }
    self.schemeHandler.modelURL = url;
    NSURLComponents *model = [[NSURLComponents alloc] init];
    model.scheme = @"netron-quicklook";
    model.host = @"app";
    model.path = [@"/model/" stringByAppendingString:url.lastPathComponent];
    NSURLComponents *page = [[NSURLComponents alloc] init];
    page.scheme = @"netron-quicklook";
    page.host = @"app";
    page.path = @"/index.html";
    page.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"mode" value:@"quicklook"],
        [NSURLQueryItem queryItemWithName:@"url" value:model.URL.absoluteString],
        [NSURLQueryItem queryItemWithName:@"identifier" value:url.lastPathComponent]
    ];
    if (!page.URL) {
        error = [NSError errorWithDomain:PreviewErrorDomain code:PreviewErrorInvalidURL userInfo:@{ NSLocalizedDescriptionKey: @"The model URL could not be prepared for preview." }];
        handler(error);
        return;
    }
    [self.webView loadRequest:[NSURLRequest requestWithURL:page.URL]];
    handler(nil);
}

- (void)showMessageForURL:(NSURL *)url detail:(NSString *)detail {
    NSString *name = [self escapeHTML:url.lastPathComponent];
    NSString *message = [self escapeHTML:detail];
    NSString *html = [NSString stringWithFormat:@"<!doctype html><meta charset='utf-8'><meta name='color-scheme' content='light dark'><style>body{height:100vh;margin:0;display:grid;place-items:center;font:13px -apple-system;color:CanvasText;background:Canvas}.message{max-width:520px;padding:40px;text-align:center}.name{font-size:17px;font-weight:600;margin-bottom:10px}.detail{line-height:1.5;color:GrayText}</style><div class='message'><div class='name'>%@</div><div class='detail'>%@</div></div>", name, message];
    [self.webView loadHTMLString:html baseURL:nil];
}

- (NSString *)escapeHTML:(NSString *)value {
    return [[[[value stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"]
        stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"]
        stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"]
        stringByReplacingOccurrencesOfString:@"\"" withString:@"&quot;"];
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    (void)webView;
    NSString *scheme = navigationAction.request.URL.scheme.lowercaseString;
    BOOL allowed = [scheme isEqualToString:@"netron-quicklook"] || [scheme isEqualToString:@"about"];
    decisionHandler(allowed ? WKNavigationActionPolicyAllow : WKNavigationActionPolicyCancel);
}

@end
