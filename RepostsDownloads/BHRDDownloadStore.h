#import <Foundation/Foundation.h>
NSURL *BHRDDownloadDirectory(void);
NSURL *BHRDNewDownloadURL(BOOL partial);
NSURL *BHRDCompleteDownload(NSURL *partial);
NSArray<NSURL *> *BHRDSavedDownloads(void);
void BHRDCleanSavedDownloads(void);

void BHRDPruneDownloads(NSURL *directory, NSDate *now, NSSet<NSString *> *activePaths);
void BHRDDiscardDownload(NSURL *url);
