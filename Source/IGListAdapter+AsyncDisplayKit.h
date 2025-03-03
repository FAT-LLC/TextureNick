//
//  IGListAdapter+AsyncDisplayKit.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "ASAvailability.h"
#else
#import <AsyncDisplayKit/ASAvailability.h>
#endif

#if AS_IG_LIST_KIT

#if !__has_include(<IGListKit/IGListKit.h>)
#import "IGListKit.h"
#else
#import <IGListKit/IGListKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@class ASCollectionNode;

@interface IGListAdapter (AsyncDisplayKit)

/**
 * Connect this list adapter to the given collection node.
 *
 * @param collectionNode The collection node to drive with this list adapter.
 *
 * @note This method may only be called once per list adapter, 
 *   and it must be called on the main thread. -[UIViewController init]
 *   is a good place to call it. This method does not retain the collection node.
 */
- (void)setASDKCollectionNode:(ASCollectionNode *)collectionNode;

@end

NS_ASSUME_NONNULL_END

#endif // AS_IG_LIST_KIT
