#pragma once
#import <Foundation/Foundation.h>
BOOL BHRDTweakEnabled(void);
BOOL BHRDIsPaused(void);
BOOL BHRDFeatureHooksEnabledAtLaunch(void);
NSString *BHRDSafetyFlagPath(void);
BOOL BHRDSetPaused(BOOL paused, NSError **error);
