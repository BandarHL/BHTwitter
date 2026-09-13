#import <Foundation/Foundation.h>
@interface BHRDSharePost : NSObject <NSCopying>
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy) NSString *author;
@property(nonatomic, copy) NSString *authorIdentifier;
@property(nonatomic, copy) NSString *handle;
@property(nonatomic, copy) NSString *body;
@property(nonatomic, copy) NSString *translatedBody;
@property(nonatomic) BOOL bodyIsOriginal;
@property(nonatomic) NSInteger bodyPriority; // 0 display text, 1 full text, 2 long-post text
@property(nonatomic) BOOL bodyTruncated;
@property(nonatomic, copy) NSDictionary<NSString *, NSData *> *imageData;
@property(nonatomic, copy) NSString *link;
@property(nonatomic, copy) NSString *quote;
@property(nonatomic, copy) NSURL *avatar;
@property(nonatomic, copy) NSData *avatarData;
@property(nonatomic, strong) BHRDSharePost *quotedPost;
@property(nonatomic, copy) NSString *quotedIdentifier;
@property(nonatomic, copy) NSString *repostedBy;
@property(nonatomic, copy) NSString *replyToIdentifier;
@property(nonatomic, copy) NSString *conversationIdentifier;
@property(nonatomic, strong) BHRDSharePost *replyContextPost;
@property(nonatomic, copy) NSArray<NSURL *> *images;
@end
void BHRDCacheSharePosts(id json, NSData *data);
BHRDSharePost *BHRDSharePostFromSource(id source);
NSArray<NSDictionary *> *BHRDShareThemes(void);
NSArray<NSString *> *BHRDShareOptionKeys(void);
NSArray<NSString *> *BHRDShareOptionTitles(void);
void BHRDRestoreShareAuthorOption(NSUserDefaults *defaults);
NSDictionary *BHRDShareOptions(NSUserDefaults *defaults);

void BHRDMergeSharePost(BHRDSharePost *target, BHRDSharePost *additional);
NSArray<NSURL *> *BHRDShareImageURLs(BHRDSharePost *post);
NSArray<NSURL *> *BHRDShareVisibleImageURLs(BHRDSharePost *post, NSDictionary *options);
NSString *BHRDShareText(id value);
void BHRDApplyShareTextRows(BHRDSharePost *post, NSArray<NSDictionary *> *rows);

NSDictionary<NSString *, NSData *> *BHRDShareEmbeddedImages(BHRDSharePost *post);
BOOL BHRDShareHasDistinctTranslation(BHRDSharePost *post);

NSArray<BHRDSharePost *> *BHRDShareAllPosts(BHRDSharePost *post);
void BHRDAttachShareReplyContext(BHRDSharePost *post, BHRDSharePost *candidate);
