#pragma once
#import <Foundation/Foundation.h>

// Only runtime observations and explicit user confirmations count as evidence.
// Static capability checks and host test results are never accepted here.
NSDictionary *BHRDAcceptanceBeginSession(void);
NSDictionary *BHRDAcceptanceSnapshot(void);
NSArray<NSDictionary *> *BHRDAcceptanceItems(void);
NSString *BHRDAcceptanceCurrentSessionIdentifier(void);
void BHRDAcceptanceObserveEvent(NSString *event, NSDictionary *fields);
void BHRDAcceptanceObserveLaunch(BOOL paused, BOOL hooksEnabled);
void BHRDAcceptanceRecordManualResult(NSString *item, BOOL passed);
void BHRDAcceptanceFlush(void);
NSURL *BHRDAcceptanceExportReport(NSError **error);
void BHRDAcceptanceRemoveExport(NSURL *url);

#if BHRD_ACCEPTANCE_TEST
void BHRDAcceptanceTestReload(void);
#endif
