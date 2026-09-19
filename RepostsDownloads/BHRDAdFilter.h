#import <Foundation/Foundation.h>
BOOL BHRDIsPromotedModel(id model);
NSArray *BHRDSectionsByRemovingAds(NSArray *sections);

BOOL BHRDAdLabel(NSString *text);
BOOL BHRDStandaloneAdIdentifier(NSString *identifier);
BOOL BHRDPremiumTitle(NSString *text);
BOOL BHRDPremiumSignupAction(id url, NSString *title);
BOOL BHRDShouldDisableAdFeature(NSString *key);
void BHRDSetNativeAdEvidence(id model, BOOL ad);
