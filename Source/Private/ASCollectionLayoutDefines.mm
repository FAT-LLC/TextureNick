//
//  ASCollectionLayoutDefines.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "ASCollectionLayoutDefines.h"
#else
#import <AsyncDisplayKit/ASCollectionLayoutDefines.h>
#endif

ASSizeRange ASSizeRangeForCollectionLayoutThatFitsViewportSize(CGSize viewportSize, ASScrollDirection scrollableDirections)
{
  ASSizeRange sizeRange = ASSizeRangeUnconstrained;
  if (ASScrollDirectionContainsVerticalDirection(scrollableDirections) == NO) {
    sizeRange.min.height = viewportSize.height;
    sizeRange.max.height = viewportSize.height;
  }
  if (ASScrollDirectionContainsHorizontalDirection(scrollableDirections) == NO) {
    sizeRange.min.width = viewportSize.width;
    sizeRange.max.width = viewportSize.width;
  }
  return sizeRange;
}
