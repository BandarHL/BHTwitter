#import <UIKit/UIKit.h>
#import "../BHRDShareVisibleData.h"
@interface T1AuthorNameView : UIView
@property(nonatomic,copy) NSString *text;
@end
@implementation T1AuthorNameView @end
@interface T1ProfileImageView : UIView
@property(nonatomic,strong) UIImage *image;
@end
@implementation T1ProfileImageView @end
@interface T1TweetTextView : T1AuthorNameView @end
@implementation T1TweetTextView @end
@interface T1ConversationFocalStatusViewTableViewCell : UITableViewCell @end
@implementation T1ConversationFocalStatusViewTableViewCell @end
static NSUInteger checks;
static void Check(BOOL ok, NSString *name) { checks++; if (!ok) { NSLog(@"FAIL: %@",name); exit(1); } }
static void Header(UIView *card, NSString *text, NSString *imageID) {
    T1AuthorNameView *name=[T1AuthorNameView new]; name.text=text; name.frame=CGRectMake(60,10,230,24); name.bounds=CGRectMake(0,0,230,24); [card addSubview:name];
    T1ProfileImageView *avatar=[T1ProfileImageView new]; avatar.frame=CGRectMake(10,10,40,40); avatar.bounds=CGRectMake(0,0,40,40); avatar.image=[UIImage new]; avatar.image.fixtureData=[imageID dataUsingEncoding:NSUTF8StringEncoding]; [card addSubview:avatar];
}
int main(void) { @autoreleasepool {
    UIView *card=[UIView new]; Header(card,@"Bob @bob",@"bob-avatar");
    BHRDSharePost *known=[BHRDSharePost new]; known.author=@"Alice"; known.handle=@"alice";
    BHRDEnrichSharePostFromView(known,card);
    Check(!known.avatarData && [known.handle isEqual:@"alice"],@"Production view enrichment cannot bypass mismatched-author rejection via largest-avatar fallback");
    UIView *anonymous=[UIView new]; Header(anonymous,@"no username",@"unverified-avatar");
    BHRDSharePost *empty=[BHRDSharePost new]; BHRDEnrichSharePostFromView(empty,anonymous);
    Check(!empty.avatarData && !empty.handle.length,@"Unverified top-left image cannot become a signed author");
    UIView *matching=[UIView new]; Header(matching,@"Alice @alice",@"alice-avatar");
    BHRDEnrichSharePostFromView(known,matching);
    Check([known.avatarData isEqual:[@"alice-avatar" dataUsingEncoding:NSUTF8StringEncoding]],@"Matching semantic author header fills avatar through production traversal");
    BHRDSharePost *discovered=[BHRDSharePost new]; BHRDEnrichSharePostFromView(discovered,matching);
    Check([discovered.author isEqual:@"Alice"] && [discovered.handle isEqual:@"alice"],@"Missing identity is recovered from verified header");
    T1TweetTextView *body=[T1TweetTextView new]; body.text=@"Mention @not_author"; body.frame=CGRectMake(60,10,230,24); body.bounds=CGRectMake(0,0,230,24);
    UIView *bodyCard=[UIView new]; [bodyCard addSubview:body];
    BHRDSharePost *mention=[BHRDSharePost new]; BHRDEnrichSharePostFromView(mention,bodyCard);
    Check(!mention.author.length && !mention.handle.length,@"Body mentions cannot bypass dedicated author adapter");
    UITableView *table=[UITableView new]; table.tableHeaderView=card;
    T1ConversationFocalStatusViewTableViewCell *focal=[T1ConversationFocalStatusViewTableViewCell new]; [table addSubview:focal];
    BHRDSharePost *detail=[BHRDSharePost new]; detail.author=@"Alice"; detail.handle=@"alice";
    BHRDEnrichSharePostFromView(detail,focal);
    Check(!detail.avatarData && [detail.handle isEqual:@"alice"],@"Actual focal-header fallback rejects another author's header");
    table.tableHeaderView=matching; BHRDEnrichSharePostFromView(detail,focal);
    Check(detail.avatarData.length>0,@"Matching focal header restores missing avatar");
    NSLog(@"PASS: %lu production author-view integration checks",(unsigned long)checks);
} return 0; }
