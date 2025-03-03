//
//  _ASCollectionGalleryLayoutItem.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <UIKit/UIKit.h>

#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "ASBaseDefines.h"
#import "ASLayoutElement.h"
#else
#import <AsyncDisplayKit/ASBaseDefines.h>
#import <AsyncDisplayKit/ASLayoutElement.h>
#endif

@class ASCollectionElement;

NS_ASSUME_NONNULL_BEGIN

/**
 * A dummy item that represents a collection element to participate in the collection layout calculation process
 * without triggering measurement on the actual node of the collection element.
 *
 * This item always has a fixed size that is the item size passed to it.
 */
AS_SUBCLASSING_RESTRICTED
@interface _ASGalleryLayoutItem : NSObject <ASLayoutElement>

@property (nonatomic, readonly) CGSize itemSize;
@property (nonatomic, weak, readonly) ASCollectionElement *collectionElement;

- (instancetype)initWithItemSize:(CGSize)itemSize collectionElement:(ASCollectionElement *)collectionElement;
- (instancetype)init __unavailable;

@end

NS_ASSUME_NONNULL_END
