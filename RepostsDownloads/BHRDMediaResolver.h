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
// Current TAV technological-item / Foundation-player wrappers and their native
// quality endpoints are supported. endpointCount records directly observed URL
// choices; custom-scheme asset URLs are never rewritten into guessed URLs.
// The verified TAVFoundationPlayerEndpointsManager has an ivar-only manifest;
// only its object-typed _manifestURL is read inside a current item binding.
// resourceAccess distinguishes that limited object_ivar read from getters.
NSDictionary *BHRDResolveLiveVideoSource(id source);
// The caller must prove this is the currently attached inline-actions model or
// its own delegate/model. This path mirrors the working post download button:
// all videos in that bound post retain their variants, even when the player is
// opaque. If direct fields are not hydrated, only a fresh, stamped cache for
// this exact nonzero bound post may supply variants; never neighboring items
// or a global most-recent-video record.
// Returned identity/bindingToken changes when the model, post, or media identity
// change; callers must re-resolve and compare it before showing/downloading.
// assetMedia maps assetIdentities to validated media, in addition to media,
// statusIdentity, postID, reason, stage, sourcePath, and sourceClass.
NSDictionary *BHRDResolveBoundVideoSource(id source);
