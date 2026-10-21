#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import "../BHRDShareExport.h"
#import "../BHRDPhotoLibrarySave.h"
#import "../BHRDPreferences.h"
static NSUInteger checks;
static void Check(BOOL value, NSString *message) { checks++; if (!value) { NSLog(@"FAIL: %@", message); exit(1); } }
static void Pump(void) { [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]]; }
static void Reset(PHAuthorizationStatus status) {
    PHPhotoLibrary.fixtureStatus = status; PHPhotoLibrary.fixtureRequests = 0; PHPhotoLibrary.fixtureCommits = 0;
    PHPhotoLibrary.fixturePermission = nil; PHPhotoLibrary.fixtureCompletion = nil; PHPhotoLibrary.fixtureData = nil;
}
int main(void) { @autoreleasepool {
    NSData *png = [[NSData alloc] initWithBase64EncodedString:@"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aK1cAAAAASUVORK5CYII=" options:0];
    NSDictionary *info = @{@"NSPhotoLibraryAddUsageDescription":@"Save generated images"};
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    id oldLocal = [defaults objectForKey:BHRDCopyLocalOnlyKey], oldExpiry = [defaults objectForKey:BHRDCopyExpiresKey];
    [defaults setBool:YES forKey:BHRDCopyLocalOnlyKey]; [defaults setBool:YES forKey:BHRDCopyExpiresKey];
    __block NSUInteger results = 0; __block BHRDShareExportOutcome outcome = BHRDShareExportNone; __block NSError *error = nil;
    void (^finished)(BHRDShareExportOutcome, NSError *) = ^(BHRDShareExportOutcome result, NSError *err) {
        Check(NSThread.isMainThread, @"Share export completion on main"); results++; outcome = result; error = err;
    };
    BHRDShareExport *session = [BHRDShareExport new]; session.completion = finished;
    UIPasteboard *board = UIPasteboard.generalPasteboard;
    [session copyPNG:png];
    Check(outcome == BHRDShareExportCopied && !session.busy && results == 1, @"Share copy reports only verified clipboard success");
    Check([board.fixtureOptions[UIPasteboardOptionLocalOnly] boolValue] && [board.fixtureOptions[UIPasteboardOptionExpirationDate] timeIntervalSinceNow] > 598,
          @"Share copy uses the same local-only and expiry policy as image toolbox");
    for (NSString *mode in @[@"reject", @"replace", @"race", @"clear", @"no_image", @"throw_write", @"throw_read"]) {
        results = 0; board.fixtureFailure = mode; [session copyPNG:png];
        Check(outcome == BHRDShareExportFailed && results == 1 && error.localizedDescription.length && !session.busy,
              @"Rejected, replaced or inaccessible clipboard reports actionable failure");
    }
    board.fixtureFailure = nil;
    for (NSUInteger result = 0; result < 3; result++) {
        results = 0; NSURL *file = [session prepareSharePNG:png];
        Check(file && session.busy && [[NSData dataWithContentsOfURL:file] isEqualToData:png], @"System share attachment contains exact selected PNG");
        [session copyPNG:png]; [session savePNG:png hostInfo:info];
        Check(![session prepareSharePNG:png] && results == 0, @"An in-flight share blocks duplicate exports");
        NSError *shareError = result == 2 ? [NSError errorWithDomain:@"ShareFixture" code:42 userInfo:nil] : nil;
        [session completeShare:result != 1 error:shareError];
        BHRDShareExportOutcome expected = result == 2 ? BHRDShareExportFailed : result == 1 ? BHRDShareExportCancelled : BHRDShareExportShared;
        Check(results == 1 && outcome == expected && !session.busy && ![NSFileManager.defaultManager fileExistsAtPath:file.path], @"Share distinguishes success, cancellation and error and cleans all attachments");
        [session completeShare:YES error:nil];
        Check(results == 1, @"Late duplicate share completion cannot change the result");
    }
    results = 0; NSURL *file = [session prepareSharePNG:png]; [session close];
    Check(session.closed && session.busy && [NSFileManager.defaultManager fileExistsAtPath:file.path], @"Closing editor does not remove a still-consumed system share attachment");
    [session completeShare:NO error:nil];
    Check(outcome == BHRDShareExportCancelled && !session.busy && ![NSFileManager.defaultManager fileExistsAtPath:file.path], @"Share result after close still cleans attachment and records cancellation");
    NSUInteger previous = results; [session copyPNG:png]; [session savePNG:png hostInfo:info];
    Check(![session prepareSharePNG:png] && results == previous, @"Disposed editor cannot begin another export");
    session = [BHRDShareExport new]; session.completion = finished;
    results = 0; Check(![session prepareSharePNG:[@"bad" dataUsingEncoding:NSUTF8StringEncoding]], @"Invalid image cannot create share attachment");
    Check(outcome == BHRDShareExportFailed && results == 1 && !session.busy, @"Invalid share payload restores controls with failure feedback");
    Reset(PHAuthorizationStatusNotDetermined); results = 0;
    [session savePNG:png hostInfo:info]; Pump();
    Check(session.busy && PHPhotoLibrary.fixtureRequests == 1 && PHPhotoLibrary.fixtureCommits == 0, @"Share save waits for add-only authorization before Photos submission");
    void (^permission)(PHAuthorizationStatus) = PHPhotoLibrary.fixturePermission; PHPhotoLibrary.fixturePermission = nil;
    [session close]; permission(PHAuthorizationStatusAuthorized); Pump();
    Check(results == 1 && outcome == BHRDShareExportCancelled && PHPhotoLibrary.fixtureCommits == 0 && !session.busy,
          @"Closing share editor during permission prompt cancels and rejects late authorization");
    Reset(PHAuthorizationStatusAuthorized); results = 0;
    session = [BHRDShareExport new]; session.completion = finished; [session savePNG:png hostInfo:info]; [session close]; Pump();
    Check(results == 1 && outcome == BHRDShareExportCancelled && PHPhotoLibrary.fixtureCommits == 0, @"Close before asynchronous save start prevents submission");
    for (NSUInteger success = 0; success < 2; success++) {
        Reset(PHAuthorizationStatusAuthorized); results = 0;
        session = [BHRDShareExport new]; session.completion = finished;
        [session savePNG:png hostInfo:info]; Pump();
        Check(PHPhotoLibrary.fixtureCommits == 1 && [PHPhotoLibrary.fixtureData isEqual:png], @"Share Photos request commits exact captured preview bytes");
        [session close]; Check(session.busy && results == 0, @"Close after Photos commit preserves pending real outcome");
        NSError *photosError = success ? nil : [NSError errorWithDomain:@"PhotosFixture" code:43 userInfo:nil];
        void (^complete)(BOOL, NSError *) = PHPhotoLibrary.fixtureCompletion; PHPhotoLibrary.fixtureCompletion = nil;
        complete(success, photosError); complete(success, photosError); Pump();
        Check(results == 1 && outcome == (success ? BHRDShareExportSaved : BHRDShareExportFailed) && !session.busy,
              @"Committed share Photos save keeps true success or failure exactly once after close");
        Check(session.lastOutcome == outcome && (success || error == photosError), @"Closed export retains true final state and Photos error");
    }
    Reset(PHAuthorizationStatusDenied); results = 0;
    session = [BHRDShareExport new]; session.completion = finished; [session savePNG:png hostInfo:info]; Pump();
    Check(results == 1 && outcome == BHRDShareExportFailed && error.code == BHRDPhotoSaveDenied && PHPhotoLibrary.fixtureCommits == 0, @"Denied authorization reports failure without Photos write");
    Reset(PHAuthorizationStatusAuthorized); results = 0;
    [session savePNG:png hostInfo:@{}]; Pump();
    Check(results == 1 && outcome == BHRDShareExportFailed && error.code == BHRDPhotoSaveMissingUsage && PHPhotoLibrary.fixtureCommits == 0, @"Missing host usage string prevents save and gives feedback");
    if (oldLocal) [defaults setObject:oldLocal forKey:BHRDCopyLocalOnlyKey]; else [defaults removeObjectForKey:BHRDCopyLocalOnlyKey];
    if (oldExpiry) [defaults setObject:oldExpiry forKey:BHRDCopyExpiresKey]; else [defaults removeObjectForKey:BHRDCopyExpiresKey];
    NSLog(@"PASS: %lu production share-export orchestration checks", (unsigned long)checks);
} return 0; }
