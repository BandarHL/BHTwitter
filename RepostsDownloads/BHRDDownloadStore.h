#import <Foundation/Foundation.h>
NSURL *BHRDDownloadDirectory(void);
NSURL *BHRDNewDownloadURL(BOOL partial);
NSURL *BHRDCompleteDownload(NSURL *partial);
NSArray<NSURL *> *BHRDSavedDownloads(void);
void BHRDCleanSavedDownloads(void);

void BHRDPruneDownloads(NSURL *directory, NSDate *now, NSSet<NSString *> *activePaths);
void BHRDDiscardDownload(NSURL *url);
// Permanent retention is attached to the file itself and survives a rename.
BOOL BHRDDownloadIsPermanent(NSURL *url);
BOOL BHRDSetDownloadPermanent(NSURL *url, BOOL permanent, NSError **error);
NSInteger BHRDDownloadRetentionDays(void);
NSString *BHRDDownloadRetentionTitle(void);
// Successful export removes ordinary temporary downloads, while protected files stay.
void BHRDDiscardExportedDownload(NSURL *url);
