#import "BHRDFullscreenVideoResolver.h"
#import "BHRDFullscreenContext.h"
#import "BHRDMediaResolver.h"
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

@interface BHRDFullscreenSelection : NSObject
@property(nonatomic,copy) NSString *token;
@property(nonatomic,copy) NSString *status;
@property(nonatomic,copy) NSString *asset;
@end
@implementation BHRDFullscreenSelection @end
static char SelectionKey,ItemSelectionKey;
static char InlineBindingKey;
@interface BHRDFullscreenInlineBinding : NSObject
@property(nonatomic,weak) id model;
@property(nonatomic,copy) NSString *status;
@end
@implementation BHRDFullscreenInlineBinding @end
void BHRDRegisterFullscreenInlineModel(id view,id model) {
    if (!view) return;
    if (!model || model==NSNull.null) { objc_setAssociatedObject(view,&InlineBindingKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); return; }
    BHRDFullscreenInlineBinding *binding=[BHRDFullscreenInlineBinding new];
    binding.model=model; binding.status=BHRDMediaStatusIdentity(model);
    objc_setAssociatedObject(view,&InlineBindingKey,binding,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static id Read(id object,NSString *key) {
    @try { return BHRDMediaObject(object,key); }
    @catch (__unused NSException *exception) { return nil; }
}
static NSValue *Box(CGRect value) { return [NSValue value:&value withObjCType:@encode(CGRect)]; }
static CGRect Unbox(NSValue *value) { CGRect rect=CGRectZero; [value getValue:&rect]; return rect; }
static BOOL VisibleRect(CGRect rect) { return !CGRectIsNull(rect) && !CGRectIsEmpty(rect); }
static BOOL Chrome(UIView *view) {
    NSString *name=NSStringFromClass(view.class).lowercaseString;
    for (NSString *part in @[@"bhrd",@"backdrop",@"visualeffect",@"blur",@"inlineaction",@"author",@"username",@"replycomposer",@"quoted",@"quotetweet",@"playbutton"])
        if ([name containsString:part]) return YES;
    return NO;
}
static BOOL InlineActions(UIView *view) { return [NSStringFromClass(view.class).lowercaseString containsString:@"statusinlineactionsview"]; }
static id InlineModel(UIView *view) {
    id live=Read(view,@"viewModel") ?: Read(Read(view,@"delegate"),@"viewModel");
    if (live) return live;
    // A public getter returning nil means this reused view is no longer bound.
    if ([view respondsToSelector:NSSelectorFromString(@"viewModel")]) return nil;
    BHRDFullscreenInlineBinding *binding=objc_getAssociatedObject(view,&InlineBindingKey);
    id model=binding.model;
    NSString *status=BHRDMediaStatusIdentity(model);
    return (!binding.status.length || [binding.status isEqual:status]) ? model : nil;
}
static NSString *CardStatus(UIView *view,UIView *root) {
    for (UIView *parent=view.superview;parent && parent!=root;parent=parent.superview) {
        NSString *name=NSStringFromClass(parent.class).lowercaseString;
        if ([name containsString:@"immersivecard"] || [name containsString:@"slideshowstatus"])
            return BHRDMediaStatusIdentity(Read(parent,@"viewModel")) ?: BHRDMediaStatusIdentity(Read(parent,@"media"));
    }
    return nil;
}
static BOOL VideoView(UIView *view) {
    NSString *name=NSStringFromClass(view.class).lowercaseString;
    for (NSString *part in @[@"video",@"player",@"mediaplayback",@"immersivecard",@"slideshowstatus"])
        if ([name containsString:part]) return YES;
    return NO;
}
static BOOL PlaybackSurface(UIView *view) {
    NSString *name=NSStringFromClass(view.class).lowercaseString;
    return [name containsString:@"video"] || [name containsString:@"player"] || [name containsString:@"mediaplayback"];
}
static BOOL Page(UIView *view,UIView *root) {
    if (view==root) return NO;
    NSString *name=NSStringFromClass(view.class).lowercaseString;
    BOOL named=[name containsString:@"immersivecard"] || [name containsString:@"slideshowstatus"];
    return named && view.bounds.size.height>=root.bounds.size.height*0.55 && view.bounds.size.width>=root.bounds.size.width*0.65;
}
static NSDictionary *Result(NSString *reason,NSUInteger playerCount,NSUInteger modelCount) {
    return @{@"media":@[],@"identity":@"",@"reason":reason,@"sourceClass":@"",@"sourcePath":@"",
        @"stage":@"visible_source_probe",
        @"playerCount":@(playerCount),@"modelCount":@(modelCount),@"visibleSourceCount":@(playerCount+modelCount),
        @"observedViewClasses":@[],@"examinedViewCount":@0,@"scanTruncated":@NO};
}
static NSDictionary *Scanned(NSDictionary *result,NSArray *classes,NSUInteger count,BOOL truncated) {
    NSMutableDictionary *observed=[result mutableCopy]; observed[@"observedViewClasses"]=[classes copy];
    observed[@"examinedViewCount"]=@(count); observed[@"scanTruncated"]=@(truncated); return observed;
}
static void AddSource(NSMutableArray *sources,id source,NSString *kind,UIView *owner,CGRect visible,NSMutableSet *seen) {
    if (!source || source==NSNull.null || [source isKindOfClass:NSArray.class]) return;
    NSValue *pointer=[NSValue valueWithNonretainedObject:source]; if ([seen containsObject:pointer]) return;
    [seen addObject:pointer]; [sources addObject:@{@"source":source,@"kind":kind,@"owner":owner,@"visible":Box(visible)}];
}
static NSString *Text(id value) { return [value isKindOfClass:NSString.class] ? value : @""; }
static id AtPath(id source,NSArray<NSString *> *path) {
    id current=source;
    for (NSString *key in path) { current=Read(current,key); if (!current || current==NSNull.null) return nil; }
    return [current isKindOfClass:NSArray.class] ? nil : current;
}
static id CurrentItem(id source) {
    // X 12.24 uses a reused TAVPlayer with a distinct internal item. The outer
    // player is not a selection identity; switching its internal item must
    // invalidate an old download menu even before the new URL becomes readable.
    id item=AtPath(source,@[@"internalState",@"currentItem"]) ?: AtPath(source,@[@"mainThreadState",@"currentItem"]) ?: Read(source,@"currentItem");
    if (!item) for (NSString *key in @[@"currentPlayer",@"player",@"videoPlayer",@"avPlayer"]) {
        id player=Read(source,key);
        item=AtPath(player,@[@"internalState",@"currentItem"]) ?: AtPath(player,@[@"mainThreadState",@"currentItem"]) ?: Read(player,@"currentItem"); if (item) break;
    }
    return item && item!=NSNull.null && ![item isKindOfClass:NSArray.class] ? item : nil;
}
static NSString *Selection(id source,NSDictionary *context) {
    id item=CurrentItem(source);
    if (item && item!=NSNull.null && ![item isKindOfClass:NSArray.class]) {
        NSString *token=objc_getAssociatedObject(item,&ItemSelectionKey);
        if (!token) { token=[@"item:" stringByAppendingString:NSUUID.UUID.UUIDString]; objc_setAssociatedObject(item,&ItemSelectionKey,token,OBJC_ASSOCIATION_COPY_NONATOMIC); }
        return token;
    }
    NSString *status=Text(context[@"statusIdentity"]),*asset=Text(context[@"assetIdentity"]);
    if (!asset.length && !status.length) asset=Text(context[@"identity"]);
    if (!status.length && !asset.length) { objc_setAssociatedObject(source,&SelectionKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); return @""; }
    BHRDFullscreenSelection *old=objc_getAssociatedObject(source,&SelectionKey);
    BOOL changed=!old || (old.status.length && status.length && ![old.status isEqual:status]) ||
        (old.asset.length && asset.length && ![old.asset isEqual:asset]);
    if (changed) { old=[BHRDFullscreenSelection new]; old.token=[@"selection:" stringByAppendingString:NSUUID.UUID.UUIDString]; }
    if (status.length) old.status=status; if (asset.length) old.asset=asset;
    objc_setAssociatedObject(source,&SelectionKey,old,OBJC_ASSOCIATION_RETAIN_NONATOMIC); return old.token;
}
static NSString *CombinedSelection(NSArray *observations) {
    NSMutableSet *tokens=[NSMutableSet set];
    for (NSDictionary *entry in observations) if ([entry[@"token"] length]) [tokens addObject:entry[@"token"]];
    NSArray *sorted=[tokens.allObjects sortedArrayUsingSelector:@selector(compare:)];
    if (sorted.count<=1) return sorted.firstObject ?: @"";
    return [@"items:" stringByAppendingString:[sorted componentsJoinedByString:@"|"]];
}
static BOOL SameSurface(NSDictionary *left,NSDictionary *right) {
    if (left[@"owner"]!=right[@"owner"]) return NO;
    CGRect first=Unbox(left[@"visible"]),second=Unbox(right[@"visible"]),shared=CGRectIntersection(first,second);
    CGFloat smaller=MIN(first.size.width*first.size.height,second.size.width*second.size.height);
    return VisibleRect(shared) && smaller>0 && shared.size.width*shared.size.height/smaller>=0.90;
}
static NSDictionary *ObservedResult(NSDictionary *result,NSArray *observations,NSUInteger resolvedCount) {
    NSMutableDictionary *value=[result mutableCopy]; value[@"resolvedSourceCount"]=@(resolvedCount);
    value[@"unresolvedSourceCount"]=@(observations.count-resolvedCount);
    NSUInteger resolvedPlayers=0,unresolvedPlayers=0;
    NSMutableSet *reasons=[NSMutableSet set],*paths=[NSMutableSet set],*excluded=[NSMutableSet set]; NSMutableArray *candidates=[NSMutableArray array];
    for (NSDictionary *entry in observations) {
        NSDictionary *context=entry[@"context"]; BOOL resolved=[context[@"media"] count]>0;
        if ([Text(entry[@"kind"]) hasPrefix:@"player_"]) { if (resolved) resolvedPlayers++; else unresolvedPlayers++; }
        if (!resolved) [reasons addObject:context[@"reason"] ?: @"visible_source_unresolved"];
        if ([context[@"sourcePath"] length]) [paths addObject:context[@"sourcePath"]];
        for (id path in context[@"resourceProbePaths"]) if ([path isKindOfClass:NSString.class] && paths.count<64) [paths addObject:path];
        for (id path in context[@"excludedPlaybackBranches"]) if ([path isKindOfClass:NSString.class] && excluded.count<8) [excluded addObject:path];
        [candidates addObject:@{@"kind":entry[@"kind"] ?: @"",@"sourceClass":context[@"sourceClass"] ?: @"",@"reason":context[@"reason"] ?: @"",
            @"stage":context[@"stage"] ?: @"",@"sourcePath":context[@"sourcePath"] ?: @"",@"currentItemPresent":@(entry[@"item"]!=nil),@"resolved":@(resolved),
            @"resourceAccess":Text(context[@"resourceAccess"]),@"endpointCount":[context[@"endpointCount"] isKindOfClass:NSNumber.class] ? context[@"endpointCount"] : @0}];
    }
    value[@"resolvedPlayerCount"]=@(resolvedPlayers); value[@"unresolvedPlayerCount"]=@(unresolvedPlayers);
    value[@"candidateResults"]=candidates; value[@"resourceProbePaths"]=[paths.allObjects sortedArrayUsingSelector:@selector(compare:)];
    value[@"excludedPlaybackBranches"]=[excluded.allObjects sortedArrayUsingSelector:@selector(compare:)];
    value[@"unresolvedReasons"]=[reasons.allObjects sortedArrayUsingSelector:@selector(compare:)]; return value;
}
static BOOL HardResourceFailure(NSString *reason) {
    return [reason isEqual:@"resource_scan_budget_exceeded"] || [reason hasPrefix:@"ambiguous_"] || [reason isEqual:@"current_item_mismatch"];
}
static NSDictionary *ResolveSources(NSArray *sources,NSUInteger playerCount,NSUInteger modelCount,BOOL strictPlayback) {
    NSMutableArray *observations=[NSMutableArray array],*usable=[NSMutableArray array],*missing=[NSMutableArray array];
    for (NSDictionary *candidate in sources) {
        NSDictionary *current=BHRDResolveLiveVideoSource(candidate[@"source"]);
        NSArray *media=current[@"media"]; NSString *next=current[@"identity"];
        NSString *token=Selection(candidate[@"source"],current);
        NSMutableDictionary *entry=[candidate mutableCopy]; entry[@"context"]=current; entry[@"token"]=token;
        id item=CurrentItem(candidate[@"source"]); if (item) entry[@"item"]=item;
        [observations addObject:entry];
        if (![media isKindOfClass:NSArray.class] || !media.count || ![next isKindOfClass:NSString.class] || !next.length) {
            [missing addObject:entry];
        } else {
            [usable addObject:entry];
        }
    }
    // Complete the probe before deciding: an unreadable outer wrapper must not
    // hide another usable current player merely because it was scanned first.
    NSString *selection=CombinedSelection(observations),*resource=nil;
    for (NSDictionary *entry in usable) {
        NSString *next=entry[@"context"][@"identity"];
        if (resource && ![resource isEqual:next]) return ObservedResult(Result(@"conflicting_visible_resources",playerCount,modelCount),observations,usable.count);
        resource=next;
    }
    // Pick deterministic diagnostic metadata, including when every candidate
    // failed, instead of letting UIKit subview order choose the error shown.
    [missing sortUsingComparator:^NSComparisonResult(NSDictionary *left,NSDictionary *right) {
        NSString *a=[NSString stringWithFormat:@"%@:%@",left[@"context"][@"reason"],left[@"context"][@"sourceClass"]];
        NSString *b=[NSString stringWithFormat:@"%@:%@",right[@"context"][@"reason"],right[@"context"][@"sourceClass"]]; return [a compare:b];
    }];
    NSDictionary *fatal=nil;
    for (NSDictionary *entry in missing) {
        NSString *reason=entry[@"context"][@"reason"];
        if (HardResourceFailure(reason)) { fatal=entry; break; }
    }
    for (NSDictionary *entry in missing) {
        if (fatal || !strictPlayback || !usable.count) break;
        BOOL provedDuplicate=NO;
        for (NSDictionary *ready in usable) {
            if (entry[@"item"] && entry[@"item"]==ready[@"item"]) { provedDuplicate=YES; break; }
            // Geometric overlap alone cannot connect two independent players.
            // Only an outer wrapper in this same visible surface may be skipped
            // when it has no non-null current item of its own. A wrapper's nil
            // getter is ordinary before it binds, not proof of another video.
            if (!entry[@"item"] && SameSurface(entry,ready)) { provedDuplicate=YES; break; }
        }
        if (!provedDuplicate) { fatal=entry; break; }
    }
    if (!usable.count || fatal) {
        NSDictionary *failure=(fatal ?: missing.firstObject)[@"context"];
        NSString *reason=failure[@"reason"] ?: (playerCount ? @"visible_player_unresolved" : @"current_model_unresolved");
        if (fatal && usable.count && !HardResourceFailure(reason)) reason=@"ambiguous_visible_player_selection";
        NSMutableDictionary *failed=[Result(reason,playerCount,modelCount) mutableCopy];
        failed[@"identity"]=selection; failed[@"sourceClass"]=failure[@"sourceClass"] ?: @"";
        failed[@"sourcePath"]=failure[@"sourcePath"] ?: @""; failed[@"stage"]=failure[@"stage"] ?: @"visible_source_probe";
        return ObservedResult(failed,observations,usable.count);
    }
    // Prefer the richer current resource when two wrappers expose the same
    // asset. The binding token still includes every observed real item.
    [usable sortUsingComparator:^NSComparisonResult(NSDictionary *left,NSDictionary *right) {
        NSUInteger a=[BHRDMediaObject(BHRDMediaObject([left[@"context"][@"media"] firstObject],@"videoInfo"),@"variants") count];
        NSUInteger b=[BHRDMediaObject(BHRDMediaObject([right[@"context"][@"media"] firstObject],@"videoInfo"),@"variants") count];
        if (a!=b) return a>b ? NSOrderedAscending : NSOrderedDescending;
        return [Text(left[@"context"][@"sourcePath"]) compare:Text(right[@"context"][@"sourcePath"])];
    }];
    NSMutableDictionary *result=[usable.firstObject[@"context"] mutableCopy];
    result[@"resourceIdentity"]=resource ?: @""; result[@"identity"]=selection;
    result[@"playerCount"]=@(playerCount); result[@"modelCount"]=@(modelCount); result[@"visibleSourceCount"]=@(playerCount+modelCount);
    return ObservedResult(result,observations,usable.count);
}
static NSDictionary *ResolveInline(NSArray *inlines,NSArray *players,NSUInteger modelCount) {
    NSDictionary *chosen=nil,*pending=nil; UIView *chosenView=nil,*pendingView=nil; NSString *post=nil; NSSet *resources=nil;
    for (NSDictionary *candidate in inlines) {
        NSDictionary *context=BHRDResolveBoundVideoSource(candidate[@"model"]);
        if (![context[@"media"] count]) {
            if ([context[@"reason"] isEqual:@"resource_scan_budget_exceeded"] || [context[@"reason"] hasPrefix:@"ambiguous_"])
                return Result(context[@"reason"],players.count,modelCount);
            if (inlines.count==1 && [context[@"statusIdentity"] length]) { pending=context; pendingView=candidate[@"view"]; }
            continue;
        }
        NSString *identity=Text(context[@"statusIdentity"]),*card=Text(candidate[@"cardStatus"]);
        if (card.length && identity.length && ![card isEqual:identity]) return Result(@"inline_identity_mismatch",players.count,modelCount);
        NSSet *next=[NSSet setWithArray:context[@"assetIdentities"]];
        if (chosen && ((post.length && identity.length && ![post isEqual:identity]) || ![resources isEqual:next]))
            return Result(@"conflicting_visible_resources",players.count,modelCount);
        if (!chosen) { chosen=context; chosenView=candidate[@"view"]; post=identity; resources=next; }
    }
    if (!chosen && !pending) return nil;
    if (!chosen) { chosen=pending; chosenView=pendingView; post=Text(chosen[@"statusIdentity"]); resources=[NSSet set]; }
    // A usable live URL proves which video within the bound post is current.
    // An opaque player still permits the native, explicitly grouped post menu.
    NSString *knownAsset=nil; NSMutableArray *playerSelections=[NSMutableArray array];
    NSDictionary *liveSelection=players.count ? ResolveSources(players,players.count,modelCount,YES) : nil;
    NSString *liveReason=liveSelection[@"reason"];
    if (HardResourceFailure(liveReason) || [liveReason isEqual:@"conflicting_visible_resources"]) return liveSelection;
    for (NSDictionary *candidate in players) {
        NSDictionary *live=BHRDResolveLiveVideoSource(candidate[@"source"]);
        NSString *asset=Text(live[@"assetIdentity"]);
        if ([chosen[@"media"] count] && [live[@"media"] count] && asset.length) {
            if (![resources containsObject:asset] || (knownAsset && ![knownAsset isEqual:asset])) return Result(@"inline_identity_mismatch",players.count,modelCount);
            knownAsset=asset;
        }
        NSString *token=Selection(candidate[@"source"],live);
        if ([token hasPrefix:@"item:"]) [playerSelections addObject:@{@"token":token}];
    }
    NSMutableDictionary *result=[chosen mutableCopy];
    if (knownAsset) { result[@"media"]=@[chosen[@"assetMedia"][knownAsset]]; result[@"assetIdentity"]=knownAsset; }
    NSString *playerToken=CombinedSelection(playerSelections);
    result[@"identity"]=playerToken.length ? playerToken : Selection(chosenView,chosen);
    NSString *single=knownAsset ?: ([chosen[@"assetIdentities"] count]==1 ? [chosen[@"assetIdentities"] firstObject] : nil);
    result[@"resourceIdentity"]=single.length ? [@"asset:" stringByAppendingString:single] : [NSString stringWithFormat:@"post:%@:%@",post ?: @"",[[chosen[@"assetIdentities"] sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@"|"]];
    result[@"reason"]=[chosen[@"media"] count] ? @"resolved_inline_model" : @"bound_media_unavailable"; result[@"sourceClass"]=NSStringFromClass(chosenView.class); result[@"sourcePath"]=@"current_inline_actions.viewModel";
    result[@"playerCount"]=@(players.count); result[@"modelCount"]=@(modelCount); result[@"visibleSourceCount"]=@(players.count+modelCount);
    for (NSString *key in @[@"resolvedPlayerCount",@"unresolvedPlayerCount",@"resolvedSourceCount",@"unresolvedSourceCount",@"candidateResults",@"resourceProbePaths",@"unresolvedReasons",@"excludedPlaybackBranches"])
        if (liveSelection[key]) result[key]=liveSelection[key];
    return result;
}
NSDictionary *BHRDCurrentFullscreenVideoContext(id controller) {
    if (!NSThread.isMainThread) return Result(@"fullscreen_scan_requires_main_thread",0,0);
    if (!BHRDIsFullscreenMediaController(controller)) return Result(@"unverified_fullscreen_host",0,0);
    UIView *root=Read(controller,@"viewIfLoaded");
    if (![root isKindOfClass:UIView.class] || !root.window || root.hidden || root.alpha<=0.01 || !VisibleRect(root.bounds)) return Result(@"detached_or_hidden_host",0,0);
    CGPoint center=CGPointMake(CGRectGetMidX(root.bounds),CGRectGetMidY(root.bounds));
    NSMutableArray *pending=[NSMutableArray arrayWithObject:@{@"view":root,@"clip":Box(root.bounds),@"pageCurrent":@YES}];
    NSMutableArray *players=[NSMutableArray array],*models=[NSMutableArray array],*inlines=[NSMutableArray array],*currentEntities=[NSMutableArray array];
    NSMutableSet *seenSources=[NSMutableSet set],*seenLayers=[NSMutableSet set];
    NSMutableArray *classes=[NSMutableArray array]; NSUInteger examined=0,budget=700;
    while (pending.count && budget--) {
        NSDictionary *entry=pending.lastObject; [pending removeLastObject]; UIView *view=entry[@"view"];
        examined++;
        BOOL inlineView=InlineActions(view);
        if (view.hidden || view.alpha<=0.01 || (Chrome(view) && !inlineView)) continue;
        CGRect clip=Unbox(entry[@"clip"]), rect=[view convertRect:view.bounds toView:root], visible=CGRectIntersection(rect,clip);
        BOOL pageCurrent=[entry[@"pageCurrent"] boolValue];
        if (VisibleRect(visible)) {
            NSString *className=NSStringFromClass(view.class);
            if (classes.count<24 && [className lengthOfBytesUsingEncoding:NSUTF8StringEncoding]<=512 && ![classes containsObject:className]) [classes addObject:className];
        }
        if (Page(view,root)) {
            pageCurrent=pageCurrent && VisibleRect(visible) && CGRectContainsPoint(visible,center);
            CGFloat whole=rect.size.width*rect.size.height,shown=visible.size.width*visible.size.height;
            if (pageCurrent && whole>0 && shown/whole<0.60) return Scanned(Result(@"pager_transition_unsettled",players.count,models.count),classes,examined,NO);
        }
        if (!pageCurrent) continue;
        if (inlineView) {
            if (VisibleRect(visible) && visible.size.width>=MIN(120,root.bounds.size.width*0.4) && visible.size.height>=20) {
                id model=InlineModel(view);
                if (model) [inlines addObject:@{@"view":view,@"model":model,@"cardStatus":CardStatus(view,root) ?: @""}];
            }
            continue; // Read the bound model, never its button images or delegates' unrelated view graph.
        }
        if (VisibleRect(visible)) {
            NSMutableSet *childViewLayers=[NSMutableSet set];
            for (UIView *child in view.subviews) [childViewLayers addObject:[NSValue valueWithNonretainedObject:child.layer]];
            NSMutableArray *layers=[NSMutableArray arrayWithObject:@{@"layer":view.layer,@"clip":Box(clip)}];
            NSUInteger layerBudget=64;
            while (layers.count && layerBudget--) {
                NSDictionary *node=layers.lastObject; [layers removeLastObject]; CALayer *layer=node[@"layer"];
                NSValue *pointer=[NSValue valueWithNonretainedObject:layer]; if ([seenLayers containsObject:pointer]) continue; [seenLayers addObject:pointer];
                if (layer.hidden || layer.opacity<=0.01) continue;
                CGRect layerClip=Unbox(node[@"clip"]), layerRect=[layer convertRect:layer.bounds toLayer:root.layer], shown=CGRectIntersection(layerRect,layerClip);
                if ([layer isKindOfClass:AVPlayerLayer.class] && VisibleRect(shown) && shown.size.width>=90 && shown.size.height>=60) {
                    AVPlayer *player=((AVPlayerLayer *)layer).player;
                    if (player) AddSource(players,player,@"player_layer",view,shown,seenSources);
                }
                CGRect nextClip=layer.masksToBounds ? shown : layerClip;
                if (!VisibleRect(nextClip)) continue;
                // Each child UIView must first pass its own visibility, clipping,
                // and pager checks. Do not bypass that via root.layer.sublayers.
                for (CALayer *child in layer.sublayers ?: @[]) if (![childViewLayers containsObject:[NSValue valueWithNonretainedObject:child]])
                    [layers addObject:@{@"layer":child,@"clip":Box(nextClip)}];
            }
            if (layers.count) return Scanned(Result(@"layer_scan_budget_exceeded",players.count,models.count),classes,examined,YES);
            CGFloat fullArea=rect.size.width*rect.size.height,area=visible.size.width*visible.size.height;
            BOOL mainMedia=rect.size.width>=90 && rect.size.height>=60 && fullArea>0 && area/fullArea>=0.60 && visible.size.width>=MIN(160,root.bounds.size.width*0.60);
            if (mainMedia) {
                // Probe current player properties even when playback uses a
                // private wrapper or surface instead of an AVPlayerLayer.
                for (NSString *key in @[@"currentPlayer",@"player",@"videoPlayer",@"avPlayer"])
                    AddSource(players,Read(view,key),@"player_view",view,visible,seenSources);
                if (VideoView(view)) AddSource(models,view,PlaybackSurface(view) ? @"visible_video_surface" : @"visible_card_model",view,visible,seenSources);
                NSString *name=NSStringFromClass(view.class).lowercaseString;
                if ([name containsString:@"slideshowstatus"] || [name containsString:@"immersivecard"]) {
                    id entity=Read(view,@"currentMediaEntity") ?: Read(view,@"media");
                    if (entity) [currentEntities addObject:@{@"view":view,@"model":entity,@"cardStatus":@""}];
                }
            }
        }
        CGRect childClip=view.clipsToBounds ? visible : clip;
        if (!VisibleRect(childClip)) continue;
        for (UIView *child in view.subviews) [pending addObject:@{@"view":child,@"clip":Box(childClip),@"pageCurrent":@(pageCurrent)}];
    }
    if (pending.count) return Scanned(Result(@"source_scan_budget_exceeded",players.count,models.count),classes,examined,YES);
    NSDictionary *inlineContext=ResolveInline(inlines,players,models.count+inlines.count);
    if (inlineContext && [inlineContext[@"media"] count]) return Scanned(inlineContext,classes,examined,NO);
    if (inlineContext && ![inlineContext[@"reason"] isEqual:@"bound_media_unavailable"]) {
        NSDictionary *playing=players.count ? ResolveSources(players,players.count,models.count,YES) : nil;
        return Scanned([playing[@"media"] count] ? playing : inlineContext,classes,examined,NO);
    }
    NSDictionary *entityContext=ResolveInline(currentEntities,players,models.count+inlines.count);
    if ([entityContext[@"media"] count]) {
        NSMutableDictionary *current=[entityContext mutableCopy]; current[@"sourcePath"]=@"current_card.media";
        return Scanned(current,classes,examined,NO);
    }
    if (entityContext && ![entityContext[@"reason"] isEqual:@"bound_media_unavailable"]) {
        NSDictionary *playing=players.count ? ResolveSources(players,players.count,models.count,YES) : nil;
        return Scanned([playing[@"media"] count] ? playing : entityContext,classes,examined,NO);
    }
    if (!players.count && !models.count) return Scanned(inlineContext ?: entityContext ?: Result(@"no_visible_video_source",0,0),classes,examined,NO);
    NSMutableArray *surfaces=[NSMutableArray array];
    for (NSDictionary *candidate in models) if ([candidate[@"kind"] isEqual:@"visible_video_surface"]) [surfaces addObject:candidate];
    // A card/post can retain old hydrated metadata while its actual playback
    // surface is switching or unreadable. That parent cannot rescue the surface.
    NSArray *current=players.count ? players : surfaces.count ? surfaces : models;
    NSDictionary *resolved=ResolveSources(current,players.count,models.count,players.count || surfaces.count);
    return Scanned(players.count ? resolved : [resolved[@"media"] count] ? resolved : inlineContext ?: entityContext ?: resolved,classes,examined,NO);
}
