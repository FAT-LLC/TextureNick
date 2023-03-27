//
//  ASCollectionGalleryLayoutDelegate.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "ASCollectionGalleryLayoutDelegate.h"
#else
#import <AsyncDisplayKit/ASCollectionGalleryLayoutDelegate.h>
#endif

#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "_ASCollectionGalleryLayoutInfo.h"
#else
#import <AsyncDisplayKit/_ASCollectionGalleryLayoutInfo.h>
#endif
#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "_ASCollectionGalleryLayoutItem.h"
#else
#import <AsyncDisplayKit/_ASCollectionGalleryLayoutItem.h>
#endif
#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "ASCellNode.h"
#else
#import <AsyncDisplayKit/ASCellNode.h>
#endif
#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "ASCollectionElement.h"
#else
#import <AsyncDisplayKit/ASCollectionElement.h>
#endif
#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "ASCollections.h"
#else
#import <AsyncDisplayKit/ASCollections.h>
#endif
#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "ASCollectionLayoutContext.h"
#else
#import <AsyncDisplayKit/ASCollectionLayoutContext.h>
#endif
#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "ASCollectionLayoutDefines.h"
#else
#import <AsyncDisplayKit/ASCollectionLayoutDefines.h>
#endif
#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "ASCollectionLayoutState.h"
#else
#import <AsyncDisplayKit/ASCollectionLayoutState.h>
#endif
#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "ASElementMap.h"
#else
#import <AsyncDisplayKit/ASElementMap.h>
#endif
#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "ASLayout.h"
#else
#import <AsyncDisplayKit/ASLayout.h>
#endif
#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "ASInsetLayoutSpec.h"
#else
#import <AsyncDisplayKit/ASInsetLayoutSpec.h>
#endif
#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "ASStackLayoutSpec.h"
#else
#import <AsyncDisplayKit/ASStackLayoutSpec.h>
#endif

#pragma mark - ASCollectionGalleryLayoutDelegate

@implementation ASCollectionGalleryLayoutDelegate {
  ASScrollDirection _scrollableDirections;

  struct {
    unsigned int minimumLineSpacingForElements:1;
    unsigned int minimumInteritemSpacingForElements:1;
    unsigned int sectionInsetForElements:1;
  } _propertiesProviderFlags;
}

- (instancetype)initWithScrollableDirections:(ASScrollDirection)scrollableDirections
{
  self = [super init];
  if (self) {
    // Scrollable directions must be either vertical or horizontal, but not both
    ASDisplayNodeAssertTrue(ASScrollDirectionContainsVerticalDirection(scrollableDirections)
                            || ASScrollDirectionContainsHorizontalDirection(scrollableDirections));
    ASDisplayNodeAssertFalse(ASScrollDirectionContainsVerticalDirection(scrollableDirections)
                             && ASScrollDirectionContainsHorizontalDirection(scrollableDirections));
    _scrollableDirections = scrollableDirections;
  }
  return self;
}

- (ASScrollDirection)scrollableDirections
{
  ASDisplayNodeAssertMainThread();
  return _scrollableDirections;
}

- (void)setPropertiesProvider:(id<ASCollectionGalleryLayoutPropertiesProviding>)propertiesProvider
{
  ASDisplayNodeAssertMainThread();
  if (propertiesProvider == nil) {
    _propertiesProvider = nil;
    _propertiesProviderFlags = {};
  } else {
    _propertiesProvider = propertiesProvider;
    _propertiesProviderFlags.minimumLineSpacingForElements = [_propertiesProvider respondsToSelector:@selector(galleryLayoutDelegate:minimumLineSpacingForElements:)];
    _propertiesProviderFlags.minimumInteritemSpacingForElements = [_propertiesProvider respondsToSelector:@selector(galleryLayoutDelegate:minimumInteritemSpacingForElements:)];
    _propertiesProviderFlags.sectionInsetForElements = [_propertiesProvider respondsToSelector:@selector(galleryLayoutDelegate:sectionInsetForElements:)];
  }
}

- (id)additionalInfoForLayoutWithElements:(ASElementMap *)elements
{
  ASDisplayNodeAssertMainThread();
  id<ASCollectionGalleryLayoutPropertiesProviding> propertiesProvider = _propertiesProvider;
  if (propertiesProvider == nil) {
    return nil;
  }

  CGSize itemSize = [propertiesProvider galleryLayoutDelegate:self sizeForElements:elements];
  UIEdgeInsets sectionInset = _propertiesProviderFlags.sectionInsetForElements ? [propertiesProvider galleryLayoutDelegate:self sectionInsetForElements:elements] : UIEdgeInsetsZero;
  CGFloat lineSpacing = _propertiesProviderFlags.minimumLineSpacingForElements ? [propertiesProvider galleryLayoutDelegate:self minimumLineSpacingForElements:elements] : 0.0;
  CGFloat interitemSpacing = _propertiesProviderFlags.minimumInteritemSpacingForElements ? [propertiesProvider galleryLayoutDelegate:self minimumInteritemSpacingForElements:elements] : 0.0;
  return [[_ASCollectionGalleryLayoutInfo alloc] initWithItemSize:itemSize
                                               minimumLineSpacing:lineSpacing
                                          minimumInteritemSpacing:interitemSpacing
                                                     sectionInset:sectionInset];
}

+ (ASCollectionLayoutState *)calculateLayoutWithContext:(ASCollectionLayoutContext *)context
{
  ASElementMap *elements = context.elements;
  CGSize pageSize = context.viewportSize;
  ASScrollDirection scrollableDirections = context.scrollableDirections;

  _ASCollectionGalleryLayoutInfo *info = ASDynamicCast(context.additionalInfo, _ASCollectionGalleryLayoutInfo);
  CGSize itemSize = info.itemSize;
  if (info == nil || CGSizeEqualToSize(CGSizeZero, itemSize)) {
    return [[ASCollectionLayoutState alloc] initWithContext:context];
  }

  NSArray<_ASGalleryLayoutItem *> *children = ASArrayByFlatMapping(elements.itemElements,
                                                                   ASCollectionElement *element,
                                                                   [[_ASGalleryLayoutItem alloc] initWithItemSize:itemSize collectionElement:element]);
  if (children.count == 0) {
    return [[ASCollectionLayoutState alloc] initWithContext:context];
  }

  // Use a stack spec to calculate layout content size and frames of all elements without actually measuring each element
  ASStackLayoutDirection stackDirection = ASScrollDirectionContainsVerticalDirection(scrollableDirections)
                                              ? ASStackLayoutDirectionHorizontal
                                              : ASStackLayoutDirectionVertical;
  ASStackLayoutSpec *stackSpec = [ASStackLayoutSpec stackLayoutSpecWithDirection:stackDirection
                                                                         spacing:info.minimumInteritemSpacing
                                                                  justifyContent:ASStackLayoutJustifyContentStart
                                                                      alignItems:ASStackLayoutAlignItemsStart
                                                                        flexWrap:ASStackLayoutFlexWrapWrap
                                                                    alignContent:ASStackLayoutAlignContentStart
                                                                     lineSpacing:info.minimumLineSpacing
                                                                        children:children];
  stackSpec.concurrent = YES;

  ASLayoutSpec *finalSpec = stackSpec;
  UIEdgeInsets sectionInset = info.sectionInset;
  if (UIEdgeInsetsEqualToEdgeInsets(sectionInset, UIEdgeInsetsZero) == NO) {
    finalSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:sectionInset child:stackSpec];
  }

  ASLayout *layout = [finalSpec layoutThatFits:ASSizeRangeForCollectionLayoutThatFitsViewportSize(pageSize, scrollableDirections)];

  return [[ASCollectionLayoutState alloc] initWithContext:context layout:layout getElementBlock:^ASCollectionElement * _Nullable(ASLayout * _Nonnull sublayout) {
    _ASGalleryLayoutItem *item = ASDynamicCast(sublayout.layoutElement, _ASGalleryLayoutItem);
    return item ? item.collectionElement : nil;
  }];
}

@end
