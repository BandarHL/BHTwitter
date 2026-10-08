#import <Foundation/Foundation.h>
id BHRDMediaObject(id source, NSString *selectorName);
NSString *BHRDMediaStatusIdentity(id source);
NSArray *BHRDResolveMedia(id source);
void BHRDRememberMedia(id source);
// The caller must select an attached, currently visible playback/card source.
// Resolution never follows generic delegates or status-ID caches. Live asset
// identity takes precedence over older hydrated post metadata; ambiguous
// current resources fail closed. Result keys include media, identity,
// statusIdentity, assetIdentity, reason, stage, sourcePath and sourceClass.
NSDictionary *BHRDResolveLiveVideoSource(id source);
