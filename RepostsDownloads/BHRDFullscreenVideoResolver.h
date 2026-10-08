#import <Foundation/Foundation.h>

// Call on the main thread. A fresh observation of the visible fullscreen resource.
// The result
// always has media/identity/reason; it never retains a model across pager reuse.
NSDictionary *BHRDCurrentFullscreenVideoContext(id controller);
// Only an attached, visible native actions view can consume this binding.
void BHRDRegisterFullscreenInlineModel(id view,id model);
