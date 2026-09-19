#import <UIKit/UIKit.h>
#import "../BHRDAdFilter.h"
#import "../BHRDAdPresentation.h"
#import "../BHRDPreferences.h"
#import "../BHRDLayoutGeometry.h"
@interface T1TweetTextView : UIView @end
@implementation T1TweetTextView @end
@interface T1QuotedStatusView : UIView @end
@implementation T1QuotedStatusView @end
@interface T1PremiumUpsellView : UIView @end
@implementation T1PremiumUpsellView @end
static NSUInteger checks;
static void Check(BOOL ok, NSString *message) { checks++; if (!ok) { NSLog(@"FAIL: %@",message); exit(1); } }
void BHRDInvalidateAdCell(UITableViewCell *cell) { [cell setNeedsLayout]; }
static UILabel *Label(UIView *parent, NSString *text) { UILabel *label=[UILabel new]; label.text=text; [parent addSubview:label]; return label; }
int main(void) { @autoreleasepool {
    for (NSString *label in @[@"广告",@"推广",@"Ad",@"Promoted",@"Publicidad",@"Anúncio",@"広告",@"광고"]) {
        Check(BHRDAdLabel(label),@"BetterX exact localized ad labels");
        UIView *cell=[UIView new]; Label(cell,label); Check(BHRDAdViewEvidence(cell),@"Native disclosure label is recognized");
    }
    Check(!BHRDAdLabel(@"我讨论广告") && !BHRDAdLabel(@"Adam"),@"No substring match");
    for (Class cls in @[T1TweetTextView.class,T1QuotedStatusView.class]) {
        UIView *cell=[UIView new], *body=[cls new]; [cell addSubview:body]; Label(body,@"广告");
        Check(!BHRDAdViewEvidence(cell),@"Body and quoted post annotations are excluded");
    }
    Check(BHRDIsPromotedModel(@{@"promotedMetadata":@{@"advertiser":@"1"}}),@"Native promoted metadata");
    Check(!BHRDIsPromotedModel(@{@"promotedMetadata":@{},@"full_text":@"广告"}),@"Empty metadata and tweet text do not identify an ad");
    Check(!BHRDIsPromotedModel(@{@"quotedStatus":@{@"isPromoted":@YES}}),@"Quoted ad does not erase ordinary main post");
    Check(BHRDStandaloneAdIdentifier(@"whoToFollowSspAd") && BHRDStandaloneAdIdentifier(@"foo-impression-pixel"),@"Standalone card and impression marker");
    Check(BHRDPremiumSignupAction(@"https://x.com/i/premium_sign_up",@"订阅"),@"Recognized Premium call to action");
    Check(!BHRDPremiumSignupAction(@"https://example.com/i/premium_sign_up",@"订阅"),@"Unrelated domain cannot identify Premium ad");
    Check(!BHRDPremiumSignupAction(@"https://x.com/i/premium_sign_up",@"新闻报道"),@"Ordinary linked text is not a signup action");
    UIView *normal=[UIView new]; Label(normal,@"Subscribe to Premium");
    Check(!BHRDAdViewEvidence(normal),@"Premium words alone outside upsell container are preserved");
    T1PremiumUpsellView *premium=[T1PremiumUpsellView new]; Label(premium,@"Subscribe to Premium");
    Check(BHRDAdViewEvidence(premium),@"Premium heading in an upsell container");
    id previous=[NSUserDefaults.standardUserDefaults objectForKey:BHRDHideAdsKey];
    [NSUserDefaults.standardUserDefaults setBool:YES forKey:BHRDHideAdsKey];
    BHRDUpdateStandaloneAdView(premium); Check(premium.hidden,@"Ad switch hides standalone subscription promotion");
    [NSUserDefaults.standardUserDefaults setBool:NO forKey:BHRDHideAdsKey];
    BHRDUpdateStandaloneAdView(premium); Check(!premium.hidden,@"Turning off restores own visibility change");
    premium.hidden=YES; [NSUserDefaults.standardUserDefaults setBool:YES forKey:BHRDHideAdsKey]; BHRDUpdateStandaloneAdView(premium);
    [NSUserDefaults.standardUserDefaults setBool:NO forKey:BHRDHideAdsKey]; BHRDUpdateStandaloneAdView(premium);
    Check(premium.hidden,@"Originally hidden native view remains hidden");
    if (previous) [NSUserDefaults.standardUserDefaults setObject:previous forKey:BHRDHideAdsKey]; else [NSUserDefaults.standardUserDefaults removeObjectForKey:BHRDHideAdsKey];
    Check(BHRDShouldDisableAdFeature(@"ad_formats_video") && !BHRDShouldDisableAdFeature(@"upload_media"),@"Feature overrides stay in ad namespace");
    CGRect button=BHRDFloatingDownloadFrame(CGRectMake(0,0,390,844),47,0,34,0);
    Check(button.size.width==44 && button.size.height==44,@"Icon-only download has 44pt touch target");
    Check(CGRectGetMidX(button)==390-16-52 && fabs(CGRectGetMidY(button)-844*0.65)<0.001,@"Original download capsule center remains unchanged");
    NSLog(@"PASS: %lu BetterX ad adaptation and icon layout checks",(unsigned long)checks);
} return 0; }
