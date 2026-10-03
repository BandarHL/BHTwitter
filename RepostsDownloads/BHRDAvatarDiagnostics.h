#pragma once
#import <Foundation/Foundation.h>
#if BHRD_AVATAR_DIAGNOSTICS
@class UIView;
void BHRDAvatarLog(NSString *event, NSDictionary *fields);
void BHRDAvatarInspectModel(id model, NSString *row);
void BHRDAvatarInspectView(UIView *view, NSString *row);
NSString *BHRDAvatarDiagnosticURL(NSURL *url);
NSString *BHRDAvatarDiagnosticPath(void);
void BHRDAvatarDiagnosticFlush(void);
// Detailed model/view inspection is off by default and expires after 10 minutes.
NSTimeInterval BHRDAvatarDetailedCollectionRemaining(void);
void BHRDAvatarSetDetailedCollection(BOOL enabled);
void BHRDAvatarClearLogs(void (^completion)(NSError *error));
void BHRDAvatarReadLog(void (^completion)(NSString *text));
// Exports a consistent, redacted snapshot and a summary of dropped records.
void BHRDAvatarExportLogs(void (^completion)(NSArray<NSURL *> *files, NSError *error));
void BHRDAvatarRemoveExport(NSArray<NSURL *> *files);
#if BHRD_AVATAR_DIAGNOSTICS_TEST
void BHRDAvatarDiagnosticTestSuspendWriter(BOOL suspended);
void BHRDAvatarDiagnosticTestExpireDetailedCollection(void);
#endif
#else
#define BHRDAvatarLog(...) do {} while (0)
#define BHRDAvatarInspectModel(...) do {} while (0)
#define BHRDAvatarInspectView(...) do {} while (0)
#endif
