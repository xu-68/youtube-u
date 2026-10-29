#import <UIKit/UIKit.h>
#import <math.h>
#import "RuntimeCompatibility.h"

@interface SponsorSegment : NSObject
@property CGFloat startTime;
@property CGFloat endTime;
@property(copy) NSString *category;
@end
@implementation SponsorSegment
@end
@interface YTPlayerViewController : UIViewController
@property(copy) NSString *channelID;
@end
@implementation YTPlayerViewController
@end
@interface PlayingState : NSObject
@property CGFloat totalTimeSec;
@end
@implementation PlayingState
@end
@interface YTIModularPlayerBarModel : NSObject
@property(strong) PlayingState *playingState;
@end
@implementation YTIModularPlayerBarModel
@end
@interface YTPlayerBarRectangleDecorationView : UIView
@end
@implementation YTPlayerBarRectangleDecorationView
@end
@interface YTModularPlayerBarView : UIView
@property(strong) NSMutableArray *sponsorMarkerViews;
@property(strong) NSMutableDictionary *fixtureValues;
@property CGFloat totalTime;
@property NSUInteger keyReads;
- (void)removeSponsorMarkers;
@end
@implementation YTModularPlayerBarView
- (id)valueForKey:(NSString *)key {
    self.keyReads++;
    id result = self.fixtureValues[key];
    return result ?: [super valueForKey:key];
}
- (void)removeSponsorMarkers {
    for (UIView *view in self.sponsorMarkerViews) [view removeFromSuperview];
    self.sponsorMarkerViews = [NSMutableArray array];
}
@end
@interface ThrowingFixture : NSObject
@end
@implementation ThrowingFixture
- (id)valueForKey:(NSString *)key {
    [NSException raise:NSInternalInconsistencyException format:@"Unrelated failure"];
    return nil;
}
@end

static NSMutableArray *kWhitelistedChannels;
static NSDictionary *kCategorySettings;
static UIColor *colorWithHexString(NSString *hex) { return UIColor.redColor; }
// INSERT_ACTUAL_RENDERERS

@interface YTQTMButton : UIButton
@end
@implementation YTQTMButton
@end
@interface YTMainAppControlsOverlayView : UIView
@property(strong) NSMutableDictionary *overlayButtons;
@end
@implementation YTMainAppControlsOverlayView
@end
static NSMutableArray *topButtons;
static BOOL UseTopButton(NSString *name) { return YES; }
// INSERT_ACTUAL_CONTROLS

static SponsorSegment *segment(CGFloat start, CGFloat end) {
    SponsorSegment *s = [SponsorSegment new];
    s.startTime = start; s.endTime = end; s.category = @"sponsor";
    return s;
}
static YTModularPlayerBarView *bar(void) {
    YTModularPlayerBarView *view = [[YTModularPlayerBarView alloc] initWithFrame:CGRectMake(0, 0, 100, 10)];
    view.totalTime = 100;
    YTPlayerViewController *player = [YTPlayerViewController new];
    player.channelID = @"fixture-channel";
    UIViewController *delegate = [UIViewController new];
    [player addChildViewController:delegate];
    // Keep the owning controller alive through fixture state.
    UIView *scrubber = [UIView new];
    [view addSubview:scrubber];
    UIView *reference = [[YTPlayerBarRectangleDecorationView alloc] initWithFrame:CGRectMake(0, 5, 100, 2)];
    [view addSubview:reference];
    view.fixtureValues = [@{@"_accessibilityDelegate": delegate, @"_scrubberCircle": scrubber,
        @"_segmentViews": @[reference], @"fixturePlayer": player} mutableCopy];
    return view;
}
static void check(BOOL condition, NSString *message) {
    if (!condition) [NSException raise:@"RegressionFailure" format:@"%@", message];
}

int main(int argc, char **argv) {
    @autoreleasepool {
        kWhitelistedChannels = [NSMutableArray array];
        kCategorySettings = @{@"sponsorColor": @"ff0000"};
        NSMutableArray *results = [NSMutableArray array];
        void (^test)(NSString *, void (^)(void)) = ^(NSString *name, void (^body)(void)) {
            @try { body(); [results addObject:@{@"name": name, @"passed": @YES}]; }
            @catch (NSException *exception) {
                [results addObject:@{@"name": name, @"passed": @NO, @"error": exception.description}];
            }
        };
        NSMutableArray *segments = [NSMutableArray arrayWithObject:segment(10, 30)];
        topButtons = [NSMutableArray arrayWithObject:@"fixture-button"];
        test(@"baseline overlay reproduces nil button exception", ^{
            YTMainAppControlsOverlayView *view = [YTMainAppControlsOverlayView new];
            view.overlayButtons = [NSMutableDictionary dictionary];
            BOOL reproduced = NO;
            @try { baselineTopControls(view, [NSMutableArray array]); }
            @catch (NSException *e) { reproduced = [e.name isEqualToString:NSInvalidArgumentException]; }
            check(reproduced, @"Baseline should expose missing button failure");
        });
        test(@"overlay omits missing button", ^{
            YTMainAppControlsOverlayView *view = [YTMainAppControlsOverlayView new];
            view.overlayButtons = [NSMutableDictionary dictionary];
            check(patchedTopControls(view, [NSMutableArray array]).count == 0, @"Missing button must be omitted");
        });
        test(@"overlay preserves existing buttons", ^{
            YTMainAppControlsOverlayView *view = [YTMainAppControlsOverlayView new];
            YTQTMButton *button = [YTQTMButton new];
            view.overlayButtons = [@{@"fixture-button": button} mutableCopy];
            check(patchedTopControls(view, [NSMutableArray array]).firstObject == button, @"Existing button lost");
        });
        test(@"baseline reproduces undefined-key exception", ^{
            YTModularPlayerBarView *v = bar(); [v.fixtureValues removeObjectForKey:@"_accessibilityDelegate"];
            BOOL reproduced = NO;
            @try { baselineRenderer(v, segments); }
            @catch (NSException *e) { reproduced = [e.name isEqualToString:NSUndefinedKeyException]; }
            check(reproduced, @"Baseline must reproduce the reported exception class");
        });
        test(@"empty segments avoid private field reads", ^{
            YTModularPlayerBarView *v = bar(); patchedRenderer(v, [NSMutableArray array]);
            check(v.keyReads == 0 && v.sponsorMarkerViews.count == 0, @"Empty reset must not read KVC");
        });
        for (NSString *key in @[@"_accessibilityDelegate", @"_scrubberCircle"]) {
            test([@"missing private field " stringByAppendingString:key], ^{
                YTModularPlayerBarView *v = bar(); [v.fixtureValues removeObjectForKey:key];
                patchedRenderer(v, segments); check(v.sponsorMarkerViews.count == 0, @"Omit unsupported markers");
            });
        }
        test(@"unexpected delegate type", ^{
            YTModularPlayerBarView *v = bar(); v.fixtureValues[@"_accessibilityDelegate"] = [NSObject new];
            patchedRenderer(v, segments); check(v.sponsorMarkerViews.count == 0, @"Reject wrong type");
        });
        test(@"unexpected player controller", ^{
            YTModularPlayerBarView *v = bar(); v.fixtureValues[@"_accessibilityDelegate"] = [UIViewController new];
            patchedRenderer(v, segments); check(v.sponsorMarkerViews.count == 0, @"Reject unknown parent");
        });
        test(@"scrubber has different parent", ^{
            YTModularPlayerBarView *v = bar(); v.fixtureValues[@"_scrubberCircle"] = [UIView new];
            patchedRenderer(v, segments); check(v.sponsorMarkerViews.count == 0, @"Reject foreign subview");
        });
        test(@"valid marker geometry", ^{
            YTModularPlayerBarView *v = bar(); patchedRenderer(v, segments);
            check(v.sponsorMarkerViews.count == 1, @"Expected one marker");
            UIView *marker = v.sponsorMarkerViews.firstObject;
            check(CGRectGetMinX(marker.frame) == 10 && CGRectGetWidth(marker.frame) == 20, @"Incorrect geometry");
        });
        test(@"missing segment field uses view fallback", ^{
            YTModularPlayerBarView *v = bar(); [v.fixtureValues removeObjectForKey:@"_segmentViews"];
            patchedRenderer(v, segments); check(v.sponsorMarkerViews.count == 1, @"Fallback marker missing");
        });
        for (NSNumber *duration in @[@0, @(-1), @(NAN), @(INFINITY)]) {
            test([@"invalid duration " stringByAppendingString:duration.description], ^{
                YTModularPlayerBarView *v = bar(); v.totalTime = duration.doubleValue;
                patchedRenderer(v, segments); check(v.sponsorMarkerViews.count == 0, @"Invalid duration drew markers");
            });
        }
        test(@"bad segment does not suppress later valid segment", ^{
            YTModularPlayerBarView *v = bar();
            patchedRenderer(v, [NSMutableArray arrayWithObjects:segment(NAN, 30), segment(10, 30), nil]);
            check(v.sponsorMarkerViews.count == 1, @"Valid segment should survive");
        });
        test(@"whitelisted channel", ^{
            [kWhitelistedChannels addObject:@"fixture-channel"];
            YTModularPlayerBarView *v = bar(); patchedRenderer(v, segments);
            [kWhitelistedChannels removeAllObjects];
            check(v.sponsorMarkerViews.count == 0, @"Whitelist must omit markers");
        });
        test(@"repeat rendering removes stale views", ^{
            YTModularPlayerBarView *v = bar(); patchedRenderer(v, segments); patchedRenderer(v, segments);
            check(v.sponsorMarkerViews.count == 1 && v.subviews.count == 3, @"Leaked stale marker");
        });
        test(@"optional KVC helper handles missing key and nil", ^{
            check(UYOptionalValueForKey([NSObject new], @"absent") == nil, @"Missing key must be nil");
            check(UYOptionalValueForKey(nil, @"absent") == nil, @"Nil object must be nil");
            check([UYOptionalValueForKey(@{@"present": @42}, @"present") isEqual:@42], @"Existing key lost");
        });
        test(@"optional KVC helper propagates unrelated exceptions", ^{
            BOOL propagated = NO;
            @try { UYOptionalValueForKey([ThrowingFixture new], @"anything"); }
            @catch (NSException *e) { propagated = [e.name isEqualToString:NSInternalInconsistencyException]; }
            check(propagated, @"Unrelated exceptions must remain observable");
        });
        NSUInteger failed = 0;
        for (NSDictionary *result in results) if (![result[@"passed"] boolValue]) failed++;
        NSDictionary *report = @{@"scope": @"Actual marker renderer with UIKit fixtures; not the YouTube app",
            @"tests": results, @"failed": @(failed), @"total": @(results.count)};
        NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        [[NSFileManager defaultManager] createDirectoryAtPath:documents withIntermediateDirectories:YES attributes:nil error:NULL];
        NSData *json = [NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:NULL];
        [json writeToFile:[documents stringByAppendingPathComponent:@"results.json"] atomically:YES];
        NSLog(@"Regression results: %@", report);
        return failed ? 1 : 0;
    }
}
