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
#else
#define BHRDAvatarLog(...) do {} while (0)
#define BHRDAvatarInspectModel(...) do {} while (0)
#define BHRDAvatarInspectView(...) do {} while (0)
#endif
