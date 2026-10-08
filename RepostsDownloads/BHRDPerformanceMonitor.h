#pragma once
#import <Foundation/Foundation.h>
@class UIScene;

// Calls serialize on the main thread. Sampling belongs to the active source
// scene, may continue while navigating X, and stops after 20 wall minutes.
// The summary's acceptanceSession is captured at start; later acceptance rounds
// must not display these measurements as their own.
void BHRDPerformanceStart(void);
void BHRDPerformanceStartInScene(UIScene *scene);
void BHRDPerformanceStop(void);
NSDictionary *BHRDPerformanceCurrentSummary(void);
