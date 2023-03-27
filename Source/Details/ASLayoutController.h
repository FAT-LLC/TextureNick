//
//  ASLayoutController.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <UIKit/UIKit.h>

#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "ASBaseDefines.h"
#else
#import <AsyncDisplayKit/ASBaseDefines.h>
#endif
#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "ASLayoutRangeType.h"
#else
#import <AsyncDisplayKit/ASLayoutRangeType.h>
#endif
#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "ASScrollDirection.h"
#else
#import <AsyncDisplayKit/ASScrollDirection.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@class ASCollectionElement, ASElementMap;

struct ASDirectionalScreenfulBuffer {
  CGFloat positiveDirection; // Positive relative to iOS Core Animation layer coordinate space.
  CGFloat negativeDirection;
};
typedef struct ASDirectionalScreenfulBuffer ASDirectionalScreenfulBuffer;

@protocol ASLayoutController <NSObject>

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType;

- (ASRangeTuningParameters)tuningParametersForRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType;

- (NSHashTable<ASCollectionElement *> *)elementsForScrolling:(ASScrollDirection)scrollDirection rangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType map:(ASElementMap *)map;

- (void)allElementsForScrolling:(ASScrollDirection)scrollDirection rangeMode:(ASLayoutRangeMode)rangeMode displaySet:(NSHashTable<ASCollectionElement *> * _Nullable * _Nullable)displaySet preloadSet:(NSHashTable<ASCollectionElement *> * _Nullable * _Nullable)preloadSet map:(ASElementMap *)map;

@optional

@end

NS_ASSUME_NONNULL_END
