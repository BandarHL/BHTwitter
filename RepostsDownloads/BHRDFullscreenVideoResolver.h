#import <Foundation/Foundation.h>

// Call on the main thread. A fresh observation of the visible fullscreen resource.
// The result
// always has media/identity/reason; it never retains a model across pager reuse.
// identity includes the current TAV logical item, rather than its reused outer
// player. All current visible candidates are inspected before selecting a
// resource. candidateResults/probe paths contain only classes and field paths;
// an independent opaque selected item cannot borrow another player's resource.
NSDictionary *BHRDCurrentFullscreenVideoContext(id controller);
// Only an attached, visible native actions view can consume this binding.
void BHRDRegisterFullscreenInlineModel(id view,id model);
