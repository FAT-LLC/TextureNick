//
//  ASBatchFetching.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <UIKit/UIKit.h>

#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "ASScrollDirection.h"
#else
#import <AsyncDisplayKit/ASScrollDirection.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@class ASBatchContext;
@protocol ASBatchFetchingDelegate;

@protocol ASBatchFetchingScrollView <NSObject>

- (BOOL)canBatchFetch;
- (ASBatchContext *)batchContext;
- (CGFloat)leadingScreensForBatching;
- (nullable id<ASBatchFetchingDelegate>)batchFetchingDelegate;

@end

/**
 @abstract Determine if batch fetching should begin based on the state of the parameters.
 @discussion This method is broken into a category for unit testing purposes and should be used with the ASTableView and
 * ASCollectionView batch fetching API.
 @param scrollView The scroll view that in-flight fetches are happening.
 @param scrollDirection The current scrolling direction of the scroll view.
 @param scrollableDirections The possible scrolling directions of the scroll view.
 @param contentOffset The offset that the scrollview will scroll to.
 @param velocity The velocity of the scroll view (in points) at the moment the touch was released.
 @param flipsHorizontallyInOppositeLayoutDirection Whether or not this scroll view flips its layout automatically in RTL.
         See flipsHorizontallyInOppositeLayoutDirection in UICollectionViewLayout
 @return Whether or not the current state should proceed with batch fetching.
 */
ASDK_EXTERN BOOL ASDisplayShouldFetchBatchForScrollView(UIScrollView<ASBatchFetchingScrollView> *scrollView,
                                            ASScrollDirection scrollDirection,
                                            ASScrollDirection scrollableDirections,
                                            CGPoint contentOffset,
                                            CGPoint velocity,
                                            BOOL flipsHorizontallyInOppositeLayoutDirection);


/**
 @abstract Determine if batch fetching should begin based on the state of the parameters.
 @param context The batch fetching context that contains knowledge about in-flight fetches.
 @param scrollDirection The current scrolling direction of the scroll view.
 @param scrollableDirections The possible scrolling directions of the scroll view.
 @param bounds The bounds of the scrollview.
 @param contentSize The content size of the scrollview.
 @param targetOffset The offset that the scrollview will scroll to.
 @param leadingScreens How many screens in the remaining distance will trigger batch fetching.
 @param visible Whether the view is visible or not.
 @param velocity The velocity of the scroll view (in points) at the moment the touch was released.
 @param delegate The delegate to be consulted if needed.
 @param flipsHorizontallyInOppositeLayoutDirection Whether or not this scroll view flips its layout automatically in RTL.
         See flipsHorizontallyInOppositeLayoutDirection in UICollectionViewLayout
 @return Whether or not the current state should proceed with batch fetching.
 @discussion This method is broken into a category for unit testing purposes and should be used with the ASTableView and
 * ASCollectionView batch fetching API.
 */
ASDK_EXTERN BOOL ASDisplayShouldFetchBatchForContext(ASBatchContext *context,
                                                ASScrollDirection scrollDirection,
                                                ASScrollDirection scrollableDirections,
                                                CGRect bounds,
                                                CGSize contentSize,
                                                CGPoint targetOffset,
                                                CGFloat leadingScreens,
                                                BOOL visible,
                                                BOOL shouldRenderRTLLayout,
                                                CGPoint velocity,
                                                BOOL flipsHorizontallyInOppositeLayoutDirection,
                                                _Nullable id<ASBatchFetchingDelegate> delegate);

NS_ASSUME_NONNULL_END
