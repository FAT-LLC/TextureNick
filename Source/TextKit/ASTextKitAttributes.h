//
//  ASTextKitAttributes.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#pragma once

#import <UIKit/UIKit.h>

#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "ASAvailability.h"
#else
#import <AsyncDisplayKit/ASAvailability.h>
#endif

#if AS_ENABLE_TEXTNODE

#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "ASEqualityHelpers.h"
#else
#import <AsyncDisplayKit/ASEqualityHelpers.h>
#endif

ASDK_EXTERN NSString *const ASTextKitTruncationAttributeName;
/**
 Use ASTextKitEntityAttribute as the value of this attribute to embed a link or other interactable content inside the
 text.
 */
ASDK_EXTERN NSString *const ASTextKitEntityAttributeName;

/**
 All NSObject values in this struct should be copied when passed into the TextComponent.
 */
struct ASTextKitAttributes {
  /**
   The string to be drawn.  ASTextKit will not augment this string with default colors, etc. so this must be complete.
   */
  NSAttributedString *attributedString;
  /**
   The string to use as the truncation string, usually just "...".  If you have a range of text you would like to
   restrict highlighting to (for instance if you have "... Continue Reading", use the ASTextKitTruncationAttributeName
   to mark the specific range of the string that should be highlightable.
   */
  NSAttributedString *truncationAttributedString;
  /**
   This is the character set that ASTextKit should attempt to avoid leaving as a trailing character before your
   truncation token.  By default this set includes "\s\t\n\r.,!?:;" so you don't end up with ugly looking truncation
   text like "Hey, this is some fancy Truncation!\n\n...".  Instead it would be truncated as "Hey, this is some fancy
   truncation...".  This is not always possible.

   Set this to the empty charset if you want to just use the "dumb" truncation behavior.  A nil value will be
   substituted with the default described above.
   */
  NSCharacterSet *avoidTailTruncationSet;
  /**
   The line-break mode to apply to the text.  Since this also impacts how TextKit will attempt to truncate the text
   in your string, we only support NSLineBreakByWordWrapping and NSLineBreakByCharWrapping.
   */
  NSLineBreakMode lineBreakMode;
  /**
   The maximum number of lines to draw in the drawable region.  Leave blank or set to 0 to define no maximum.
   This is required to apply scale factors to shrink text to fit within a number of lines
   */
  NSUInteger maximumNumberOfLines;
  /**
   An array of UIBezierPath objects representing the exclusion paths inside the receiver's bounding rectangle. Default value: nil.
   */
  NSArray<UIBezierPath *> *exclusionPaths;
  /**
   The shadow offset for any shadows applied to the text.  The coordinate space for this is the same as UIKit, so a
   positive width means towards the right, and a positive height means towards the bottom.
   */
  CGSize shadowOffset;
  /**
   The color to use in drawing the text's shadow.
   */
  UIColor *shadowColor;
  /**
   The opacity of the shadow from 0 to 1.
   */
  CGFloat shadowOpacity;
  /**
   The radius that should be applied to the shadow blur.  Larger values mean a larger, more blurred shadow.
   */
  CGFloat shadowRadius;
  /**
   An array of scale factors in descending order to apply to the text to try to make it fit into a constrained size.
   */
  NSArray *pointSizeScaleFactors;

  /**
   The tint color to use in drawing the text foreground color. Only applied if the attributedString does not define foreground color
   */
  UIColor *tintColor;
  /**
   We provide an explicit copy function so we can use aggregate initializer syntax while providing copy semantics for
   the NSObjects inside.
   */
  const ASTextKitAttributes copy() const
  {
    return {
      [attributedString copy],
      [truncationAttributedString copy],
      [avoidTailTruncationSet copy],
      lineBreakMode,
      maximumNumberOfLines,
      [exclusionPaths copy],
      shadowOffset,
      [shadowColor copy],
      shadowOpacity,
      shadowRadius,
      pointSizeScaleFactors,
      [tintColor copy]
    };
  };

  bool operator==(const ASTextKitAttributes &other) const
  {
    // These comparisons are in a specific order to reduce the overall cost of this function.
    return lineBreakMode == other.lineBreakMode
    && maximumNumberOfLines == other.maximumNumberOfLines
    && shadowOpacity == other.shadowOpacity
    && shadowRadius == other.shadowRadius
    && (pointSizeScaleFactors == other.pointSizeScaleFactors
        || [pointSizeScaleFactors isEqualToArray:other.pointSizeScaleFactors])
    && CGSizeEqualToSize(shadowOffset, other.shadowOffset)
    && ASObjectIsEqual(exclusionPaths, other.exclusionPaths)
    && ASObjectIsEqual(avoidTailTruncationSet, other.avoidTailTruncationSet)
    && ASObjectIsEqual(shadowColor, other.shadowColor)
    && ASObjectIsEqual(attributedString, other.attributedString)
    && ASObjectIsEqual(truncationAttributedString, other.truncationAttributedString)
    && ASObjectIsEqual(tintColor, other.tintColor);
  }

  size_t hash() const;
};

#endif
