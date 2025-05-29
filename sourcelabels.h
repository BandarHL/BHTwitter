#ifndef sourcelabels_h
#define sourcelabels_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "TWHeaders.h" // Added to get TweetSourceHelper definition

// Forward declarations
@class TFNAttributedTextModel;
@class BHTManager; // Assuming BHTManager.h will be imported in sourcelabels.m for its implementation

// Function declarations (if they are truly global and not part of a class)

UIColor *BHTCurrentAccentColor(void);

// TweetSourceHelper interface is now imported from TWHeaders.h

// Extern declarations for global variables
extern NSMutableDictionary *tweetSources;
extern NSMutableDictionary *viewToTweetID;
extern NSMutableDictionary *fetchTimeouts;
extern NSMutableDictionary *viewInstances;
extern NSMutableDictionary *fetchRetries;
extern NSMutableDictionary *updateRetries;
extern NSMutableDictionary *updateCompleted;
extern NSMutableDictionary *fetchPending;
extern NSMutableDictionary *cookieCache;

extern NSString *_lastCopiedURL;
extern NSDictionary<NSString *, NSArray<NSString *> *> *trackingParams;
extern id _PasteboardChangeObserver; // NSObject <NSCopying, NSObject> * _PasteboardChangeObserver; if more specific type is known

#endif /* sourcelabels_h */ 