//
//  ASImageNode.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "ASImageNode.h"
#else
#import <AsyncDisplayKit/ASImageNode.h>
#endif

#import <tgmath.h>

#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "_ASDisplayLayer.h"
#import "ASDisplayNode+FrameworkPrivate.h"
#import "ASDisplayNode+Subclasses.h"
#import "ASDisplayNodeExtras.h"
#import "ASGraphicsContext.h"
#import "ASLayout.h"
#import "ASTextNode.h"
#import "ASImageNode+AnimatedImagePrivate.h"
#import "ASImageNode+CGExtras.h"
#import "AsyncDisplayKit+Debug.h"
#import "ASInternalHelpers.h"
#import "ASEqualityHelpers.h"
#import "ASHashing.h"
#import "ASWeakMap.h"
#import "CoreGraphics+ASConvenience.h"
#else
#import <AsyncDisplayKit/_ASDisplayLayer.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASDisplayNodeExtras.h>
#import <AsyncDisplayKit/ASGraphicsContext.h>
#import <AsyncDisplayKit/ASLayout.h>
#import <AsyncDisplayKit/ASTextNode.h>
#import <AsyncDisplayKit/ASImageNode+AnimatedImagePrivate.h>
#import <AsyncDisplayKit/ASImageNode+CGExtras.h>
#import <AsyncDisplayKit/AsyncDisplayKit+Debug.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>
#import <AsyncDisplayKit/ASEqualityHelpers.h>
#import <AsyncDisplayKit/ASHashing.h>
#import <AsyncDisplayKit/ASWeakMap.h>
#import <AsyncDisplayKit/CoreGraphics+ASConvenience.h>
#endif

// TODO: It would be nice to remove this dependency; it's the only subclass using more than +FrameworkSubclasses.h
#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "ASDisplayNodeInternal.h"
#else
#import <AsyncDisplayKit/ASDisplayNodeInternal.h>
#endif

typedef void (^ASImageNodeDrawParametersBlock)(ASWeakMapEntry *entry);

@interface ASImageNodeDrawParameters : NSObject {
@package
  UIImage *_image;
  BOOL _opaque;
  CGRect _bounds;
  CGFloat _contentsScale;
  UIColor *_backgroundColor;
  UIColor *_tintColor;
  UIViewContentMode _contentMode;
  BOOL _cropEnabled;
  BOOL _forceUpscaling;
  CGSize _forcedSize;
  CGRect _cropRect;
  CGRect _cropDisplayBounds;
  asimagenode_modification_block_t _imageModificationBlock;
  ASDisplayNodeContextModifier _willDisplayNodeContentWithRenderingContext;
  ASDisplayNodeContextModifier _didDisplayNodeContentWithRenderingContext;
  ASImageNodeDrawParametersBlock _didDrawBlock;
  ASPrimitiveTraitCollection _traitCollection;
}

@end

@implementation ASImageNodeDrawParameters

@end

/**
 * Contains all data that is needed to generate the content bitmap.
 */
@interface ASImageNodeContentsKey : NSObject

@property (nonatomic) UIImage *image;
@property CGSize backingSize;
@property CGRect imageDrawRect;
@property BOOL isOpaque;
@property (nonatomic, copy) UIColor *backgroundColor;
@property (nonatomic, copy) UIColor *tintColor;
@property (nonatomic) ASDisplayNodeContextModifier willDisplayNodeContentWithRenderingContext;
@property (nonatomic) ASDisplayNodeContextModifier didDisplayNodeContentWithRenderingContext;
@property (nonatomic) asimagenode_modification_block_t imageModificationBlock;
@property UIUserInterfaceStyle userInterfaceStyle API_AVAILABLE(tvos(10.0), ios(12.0));
@end

@implementation ASImageNodeContentsKey

- (BOOL)isEqual:(id)object
{
  if (self == object) {
    return YES;
  }

  // Optimization opportunity: The `isKindOfClass` call here could be avoided by not using the NSObject `isEqual:`
  // convention and instead using a custom comparison function that assumes all items are heterogeneous.
  // However, profiling shows that our entire `isKindOfClass` expression is only ~1/40th of the total
  // overheard of our caching, so it's likely not high-impact.
  if ([object isKindOfClass:[ASImageNodeContentsKey class]]) {
    ASImageNodeContentsKey *other = (ASImageNodeContentsKey *)object;
    BOOL areKeysEqual = [_image isEqual:other.image]
      && CGSizeEqualToSize(_backingSize, other.backingSize)
      && CGRectEqualToRect(_imageDrawRect, other.imageDrawRect)
      && _isOpaque == other.isOpaque
      && [_backgroundColor isEqual:other.backgroundColor]
      && [_tintColor isEqual:other.tintColor]
      && _willDisplayNodeContentWithRenderingContext == other.willDisplayNodeContentWithRenderingContext
      && _didDisplayNodeContentWithRenderingContext == other.didDisplayNodeContentWithRenderingContext
      && _imageModificationBlock == other.imageModificationBlock;
    if (AS_AVAILABLE_IOS_TVOS(12, 10)) {
      // iOS 12, tvOS 10 and later (userInterfaceStyle only available in iOS12+)
      areKeysEqual = areKeysEqual && _userInterfaceStyle == other.userInterfaceStyle;
    }
    return areKeysEqual;
  } else {
    return NO;
  }
}

- (NSUInteger)hash
{
#pragma clang diagnostic push
#pragma clang diagnostic warning "-Wpadded"
  struct {
    NSUInteger imageHash;
    CGSize backingSize;
    CGRect imageDrawRect;
    NSInteger isOpaque;
    NSUInteger backgroundColorHash;
    NSUInteger tintColorHash;
    void *willDisplayNodeContentWithRenderingContext;
    void *didDisplayNodeContentWithRenderingContext;
    void *imageModificationBlock;
#pragma clang diagnostic pop
  } data = {
    _image.hash,
    _backingSize,
    _imageDrawRect,
    _isOpaque,
    _backgroundColor.hash,
    _tintColor.hash,
    (void *)_willDisplayNodeContentWithRenderingContext,
    (void *)_didDisplayNodeContentWithRenderingContext,
    (void *)_imageModificationBlock
  };
  return ASHashBytes(&data, sizeof(data));
}

@end

@implementation ASImageNode
{
@private
  UIImage *_image;
  ASWeakMapEntry *_weakCacheEntry;  // Holds a reference that keeps our contents in cache.
  UIColor *_placeholderColor;

  void (^_displayCompletionBlock)(BOOL canceled);

  // Drawing
  ASTextNode *_debugLabelNode;

  // Cropping.
  CGSize _forcedSize; //Defaults to CGSizeZero, indicating no forced size.
  CGRect _cropRect; // Defaults to CGRectMake(0.5, 0.5, 0, 0)
  CGRect _cropDisplayBounds; // Defaults to CGRectNull
}

@synthesize image = _image;
@synthesize imageModificationBlock = _imageModificationBlock;

#pragma mark - Lifecycle

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;

  // TODO can this be removed?
  self.contentsScale = ASScreenScale();
  self.contentMode = UIViewContentModeScaleAspectFill;
  self.opaque = NO;
  self.clipsToBounds = YES;

  // If no backgroundColor is set to the image node and it's a subview of UITableViewCell, UITableView is setting
  // the opaque value of all subviews to YES if highlighting / selection is happening and does not set it back to the
  // initial value. With setting a explicit backgroundColor we can prevent that change.
  self.backgroundColor = [UIColor clearColor];

  _imageNodeFlags.cropEnabled = YES;
  _imageNodeFlags.forceUpscaling = NO;
  _imageNodeFlags.regenerateFromImageAsset = NO;
  _cropRect = CGRectMake(0.5, 0.5, 0, 0);
  _cropDisplayBounds = CGRectNull;
  _placeholderColor = ASDisplayNodeDefaultPlaceholderColor();
  _animatedImageRunLoopMode = ASAnimatedImageDefaultRunLoopMode;

  return self;
}

- (void)dealloc
{
  // Invalidate all components around animated images
  [self invalidateAnimatedImage];
}

#pragma mark - Placeholder

- (UIImage *)placeholderImage
{
  // FIXME: Replace this implementation with reusable CALayers that have .backgroundColor set.
  // This would completely eliminate the memory and performance cost of the backing store.
  CGSize size = self.calculatedSize;
  if ((size.width * size.height) < CGFLOAT_EPSILON) {
    return nil;
  }

  __instanceLock__.lock();
  ASPrimitiveTraitCollection tc = _primitiveTraitCollection;
  __instanceLock__.unlock();
  return ASGraphicsCreateImage(tc, size, NO, 1, nil, nil, ^{
    AS::MutexLocker l(__instanceLock__);
    [_placeholderColor setFill];
    UIRectFill(CGRectMake(0, 0, size.width, size.height));
  });
}

#pragma mark - Layout and Sizing

- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize
{
  const auto image = ASLockedSelf(_image);

  if (image == nil) {
    return [super calculateSizeThatFits:constrainedSize];
  }

  return image.size;
}

#pragma mark - Setter / Getter

- (void)setImage:(UIImage *)image
{
  AS::MutexLocker l(__instanceLock__);
  [self _locked_setImage:image];
}

- (void)_locked_setImage:(UIImage *)image
{
  DISABLED_ASAssertLocked(__instanceLock__);
  if (ASObjectIsEqual(_image, image)) {
    return;
  }

  _image = image;

  if (image != nil) {
    // We explicitly call setNeedsDisplay in this case, although we know setNeedsDisplay will be called with lock held.
    // Therefore we have to be careful in methods that are involved with setNeedsDisplay to not run into a deadlock
    [self setNeedsDisplay];

    // For debugging purposes we don't care about locking for now
    if ([ASImageNode shouldShowImageScalingOverlay] && _debugLabelNode == nil) {
      // do not use ASPerformBlockOnMainThread here, if it performs the block synchronously it will continue
      // holding the lock while calling addSubnode.
      dispatch_async(dispatch_get_main_queue(), ^{
        self->_debugLabelNode = [[ASTextNode alloc] init];
        self->_debugLabelNode.layerBacked = YES;
        [self addSubnode:self->_debugLabelNode];
      });
    }
  } else {
    self.contents = nil;
  }
}

- (UIImage *)image
{
  return ASLockedSelf(_image);
}

- (UIColor *)placeholderColor
{
  return ASLockedSelf(_placeholderColor);
}

- (void)setPlaceholderColor:(UIColor *)placeholderColor
{
  ASLockScopeSelf();
  if (ASCompareAssignCopy(_placeholderColor, placeholderColor)) {
    _flags.placeholderEnabled = (placeholderColor != nil);
  }
}

#pragma mark - Drawing

- (NSObject *)drawParametersForAsyncLayer:(_ASDisplayLayer *)layer
{
  ASImageNodeDrawParameters *drawParameters = [[ASImageNodeDrawParameters alloc] init];
  
  {
    ASLockScopeSelf();
    UIImage *drawImage = _image;
    if (AS_AVAILABLE_IOS_TVOS(13, 10)) {
      if (_imageNodeFlags.regenerateFromImageAsset && drawImage != nil) {
        _imageNodeFlags.regenerateFromImageAsset = NO;
        UITraitCollection *tc = [UITraitCollection traitCollectionWithUserInterfaceStyle:_primitiveTraitCollection.userInterfaceStyle];
        UIImage *generatedImage = [drawImage.imageAsset imageWithTraitCollection:tc];
        if ( generatedImage != nil ) {
          drawImage = generatedImage;
        }
      }
    }

    drawParameters->_image = drawImage;
    drawParameters->_contentsScale = _contentsScaleForDisplay;
    drawParameters->_cropEnabled = _imageNodeFlags.cropEnabled;
    drawParameters->_forceUpscaling = _imageNodeFlags.forceUpscaling;
    drawParameters->_forcedSize = _forcedSize;
    drawParameters->_cropRect = _cropRect;
    drawParameters->_cropDisplayBounds = _cropDisplayBounds;
    drawParameters->_imageModificationBlock = _imageModificationBlock;
    drawParameters->_willDisplayNodeContentWithRenderingContext = _willDisplayNodeContentWithRenderingContext;
    drawParameters->_didDisplayNodeContentWithRenderingContext = _didDisplayNodeContentWithRenderingContext;
    drawParameters->_traitCollection = _primitiveTraitCollection;

    // Hack for now to retain the weak entry that was created while this drawing happened
    drawParameters->_didDrawBlock = ^(ASWeakMapEntry *entry){
      ASLockScopeSelf();
      self->_weakCacheEntry = entry;
    };
  }
  
  // We need to unlock before we access the other accessor.
  // Especially tintColor because it needs to walk up the view hierarchy
  drawParameters->_bounds = [self threadSafeBounds];
  drawParameters->_opaque = self.opaque;
  drawParameters->_backgroundColor = self.backgroundColor;
  drawParameters->_contentMode = self.contentMode;
  drawParameters->_tintColor = self.tintColor;

  return drawParameters;
}

+ (UIImage *)displayWithParameters:(id<NSObject>)parameter isCancelled:(NS_NOESCAPE asdisplaynode_iscancelled_block_t)isCancelled
{
  ASImageNodeDrawParameters *drawParameter = (ASImageNodeDrawParameters *)parameter;

  UIImage *image = drawParameter->_image;
  if (image == nil) {
    return nil;
  }

  CGRect drawParameterBounds       = drawParameter->_bounds;
  BOOL forceUpscaling              = drawParameter->_forceUpscaling;
  CGSize forcedSize                = drawParameter->_forcedSize;
  BOOL cropEnabled                 = drawParameter->_cropEnabled;
  BOOL isOpaque                    = drawParameter->_opaque;
  UIColor *backgroundColor         = drawParameter->_backgroundColor;
  UIColor *tintColor               = drawParameter->_tintColor;
  UIViewContentMode contentMode    = drawParameter->_contentMode;
  CGFloat contentsScale            = drawParameter->_contentsScale;
  CGRect cropDisplayBounds         = drawParameter->_cropDisplayBounds;
  CGRect cropRect                  = drawParameter->_cropRect;
  asimagenode_modification_block_t imageModificationBlock                 = drawParameter->_imageModificationBlock;
  ASDisplayNodeContextModifier willDisplayNodeContentWithRenderingContext = drawParameter->_willDisplayNodeContentWithRenderingContext;
  ASDisplayNodeContextModifier didDisplayNodeContentWithRenderingContext  = drawParameter->_didDisplayNodeContentWithRenderingContext;

  BOOL hasValidCropBounds = cropEnabled && !CGRectIsEmpty(cropDisplayBounds);
  CGRect bounds = (hasValidCropBounds ? cropDisplayBounds : drawParameterBounds);


  ASDisplayNodeAssert(contentsScale > 0, @"invalid contentsScale at display time");

  // if the image is resizable, bail early since the image has likely already been configured
  BOOL stretchable = !UIEdgeInsetsEqualToEdgeInsets(image.capInsets, UIEdgeInsetsZero);
  if (stretchable) {
    if (imageModificationBlock != NULL) {
      image = imageModificationBlock(image, drawParameter->_traitCollection);
    }
    return image;
  }

  CGSize imageSize = image.size;
  CGSize imageSizeInPixels = CGSizeMake(imageSize.width * image.scale, imageSize.height * image.scale);
  CGSize boundsSizeInPixels = CGSizeMake(std::floor(bounds.size.width * contentsScale), std::floor(bounds.size.height * contentsScale));

  BOOL contentModeSupported = contentMode == UIViewContentModeScaleAspectFill ||
                              contentMode == UIViewContentModeScaleAspectFit ||
                              contentMode == UIViewContentModeCenter;

  CGSize backingSize   = CGSizeZero;
  CGRect imageDrawRect = CGRectZero;

  if (boundsSizeInPixels.width * contentsScale < 1.0f || boundsSizeInPixels.height * contentsScale < 1.0f ||
      imageSizeInPixels.width < 1.0f                  || imageSizeInPixels.height < 1.0f) {
    return nil;
  }


  // If we're not supposed to do any cropping, just decode image at original size
  if (!cropEnabled || !contentModeSupported) {
    backingSize = imageSizeInPixels;
    imageDrawRect = (CGRect){.size = backingSize};
  } else {
    if (CGSizeEqualToSize(CGSizeZero, forcedSize) == NO) {
      //scale forced size
      forcedSize.width *= contentsScale;
      forcedSize.height *= contentsScale;
    }
    ASCroppedImageBackingSizeAndDrawRectInBounds(imageSizeInPixels,
                                                 boundsSizeInPixels,
                                                 contentMode,
                                                 cropRect,
                                                 forceUpscaling,
                                                 forcedSize,
                                                 &backingSize,
                                                 &imageDrawRect);
  }

  if (backingSize.width <= 0.0f        || backingSize.height <= 0.0f ||
      imageDrawRect.size.width <= 0.0f || imageDrawRect.size.height <= 0.0f) {
    return nil;
  }

  ASImageNodeContentsKey *contentsKey = [[ASImageNodeContentsKey alloc] init];
  contentsKey.image = image;
  contentsKey.backingSize = backingSize;
  contentsKey.imageDrawRect = imageDrawRect;
  contentsKey.isOpaque = isOpaque;
  contentsKey.backgroundColor = backgroundColor;
  contentsKey.tintColor = tintColor;
  contentsKey.willDisplayNodeContentWithRenderingContext = willDisplayNodeContentWithRenderingContext;
  contentsKey.didDisplayNodeContentWithRenderingContext = didDisplayNodeContentWithRenderingContext;
  contentsKey.imageModificationBlock = imageModificationBlock;

  if (AS_AVAILABLE_IOS_TVOS(12, 10)) {
    contentsKey.userInterfaceStyle = drawParameter->_traitCollection.userInterfaceStyle;
  }

  if (isCancelled()) {
    return nil;
  }

  ASWeakMapEntry<UIImage *> *entry = [self.class contentsForkey:contentsKey
                                                 drawParameters:parameter
                                                    isCancelled:isCancelled];
  // If nil, we were cancelled.
  if (entry == nil) {
    return nil;
  }

  if (drawParameter->_didDrawBlock) {
    drawParameter->_didDrawBlock(entry);
  }

  return entry.value;
}

static ASWeakMap<ASImageNodeContentsKey *, UIImage *> *cache = nil;

+ (ASWeakMapEntry *)contentsForkey:(ASImageNodeContentsKey *)key drawParameters:(id)drawParameters isCancelled:(asdisplaynode_iscancelled_block_t)isCancelled
{
  static dispatch_once_t onceToken;
  static AS::Mutex *cacheLock = nil;
  dispatch_once(&onceToken, ^{
    cacheLock = new AS::Mutex();
  });

  {
    AS::MutexLocker l(*cacheLock);
    if (!cache) {
      cache = [[ASWeakMap alloc] init];
    }
    ASWeakMapEntry *entry = [cache entryForKey:key];
    if (entry != nil) {
      return entry;
    }
  }

  // cache miss
  UIImage *contents = [self createContentsForkey:key drawParameters:drawParameters isCancelled:isCancelled];
  if (contents == nil) { // If nil, we were cancelled
    return nil;
  }

  {
    AS::MutexLocker l(*cacheLock);
    return [cache setObject:contents forKey:key];
  }
}

+ (UIImage *)createContentsForkey:(ASImageNodeContentsKey *)key drawParameters:(id)parameter isCancelled:(asdisplaynode_iscancelled_block_t)isCancelled
{
  // The following `ASGraphicsCreateImage` call will sometimes take take longer than 5ms on an
  // A5 processor for a 400x800 backingSize.
  // Check for cancellation before we call it.
  if (isCancelled()) {
    return nil;
  }
  
  ASImageNodeDrawParameters *drawParameters = (ASImageNodeDrawParameters *)parameter;

  // Use contentsScale of 1.0 and do the contentsScale handling in boundsSizeInPixels so ASCroppedImageBackingSizeAndDrawRectInBounds
  // will do its rounding on pixel instead of point boundaries
  UIImage *result = ASGraphicsCreateImage(drawParameters->_traitCollection, key.backingSize, key.isOpaque, 1.0, key.image, isCancelled, ^{
    BOOL contextIsClean = YES;

    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context && key.willDisplayNodeContentWithRenderingContext) {
      key.willDisplayNodeContentWithRenderingContext(context, drawParameters);
      contextIsClean = NO;
    }

    // if view is opaque, fill the context with background color
    if (key.isOpaque && key.backgroundColor) {
      [key.backgroundColor setFill];
      UIRectFill({ .size = key.backingSize });
      contextIsClean = NO;
    }

    // iOS 9 appears to contain a thread safety regression when drawing the same CGImageRef on
    // multiple threads concurrently.  In fact, instead of crashing, it appears to deadlock.
    // The issue is present in Mac OS X El Capitan and has been seen hanging Pro apps like Adobe Premiere,
    // as well as iOS games, and a small number of ASDK apps that provide the same image reference
    // to many separate ASImageNodes.  A workaround is to set .displaysAsynchronously = NO for the nodes
    // that may get the same pointer for a given UI asset image, etc.
    // FIXME: We should replace @synchronized here, probably using a global, locked NSMutableSet, and
    // only if the object already exists in the set we should create a semaphore to signal waiting threads
    // upon removal of the object from the set when the operation completes.
    // Another option is to have ASDisplayNode+AsyncDisplay coordinate these cases, and share the decoded buffer.
    // Details tracked in https://github.com/facebook/AsyncDisplayKit/issues/1068

    UIImage *image = key.image;
    BOOL canUseCopy = (contextIsClean || ASImageAlphaInfoIsOpaque(CGImageGetAlphaInfo(image.CGImage)));
    CGBlendMode blendMode = canUseCopy ? kCGBlendModeCopy : kCGBlendModeNormal;
    UIImageRenderingMode renderingMode = [image renderingMode];
    if (renderingMode == UIImageRenderingModeAlwaysTemplate && key.tintColor) {
      [key.tintColor setFill];
    }

    @synchronized(image) {
      [image drawInRect:key.imageDrawRect blendMode:blendMode alpha:1];
    }

    if (context && key.didDisplayNodeContentWithRenderingContext) {
      key.didDisplayNodeContentWithRenderingContext(context, drawParameters);
    }
  });

  // if the original image was stretchy, keep it stretchy
  UIImage *originalImage = key.image;
  if (!UIEdgeInsetsEqualToEdgeInsets(originalImage.capInsets, UIEdgeInsetsZero)) {
    result = [result resizableImageWithCapInsets:originalImage.capInsets resizingMode:originalImage.resizingMode];
  }

  if (key.imageModificationBlock) {
    result = key.imageModificationBlock(result, drawParameters->_traitCollection);
  }

  return result;
}

- (void)displayDidFinish
{
  [super displayDidFinish];

  __instanceLock__.lock();
    UIImage *image = _image;
    void (^displayCompletionBlock)(BOOL canceled) = _displayCompletionBlock;
    BOOL shouldPerformDisplayCompletionBlock = (image && displayCompletionBlock);

    // Clear the ivar now. The block is retained and will be executed shortly.
    if (shouldPerformDisplayCompletionBlock) {
      _displayCompletionBlock = nil;
    }

    BOOL hasDebugLabel = (_debugLabelNode != nil);
  __instanceLock__.unlock();

  // Update the debug label if necessary
  if (hasDebugLabel) {
    // For debugging purposes we don't care about locking for now
    CGSize imageSize = image.size;
    CGSize imageSizeInPixels = CGSizeMake(imageSize.width * image.scale, imageSize.height * image.scale);
    CGSize boundsSizeInPixels = CGSizeMake(std::floor(self.bounds.size.width * self.contentsScale), std::floor(self.bounds.size.height * self.contentsScale));
    CGFloat pixelCountRatio            = (imageSizeInPixels.width * imageSizeInPixels.height) / (boundsSizeInPixels.width * boundsSizeInPixels.height);
    if (pixelCountRatio != 1.0) {
      NSString *scaleString            = [NSString stringWithFormat:@"%.2fx", pixelCountRatio];
      _debugLabelNode.attributedText   = [[NSAttributedString alloc] initWithString:scaleString attributes:[self debugLabelAttributes]];
      _debugLabelNode.hidden           = NO;
    } else {
      _debugLabelNode.hidden           = YES;
      _debugLabelNode.attributedText   = nil;
    }
  }

  // If we've got a block to perform after displaying, do it.
  if (shouldPerformDisplayCompletionBlock) {
    displayCompletionBlock(NO);
  }
}

- (void)setNeedsDisplayWithCompletion:(void (^ _Nullable)(BOOL canceled))displayCompletionBlock
{
  if (self.displaySuspended) {
    if (displayCompletionBlock)
      displayCompletionBlock(YES);
    return;
  }

  // Stash the block and call-site queue. We'll invoke it in -displayDidFinish.
  {
    AS::MutexLocker l(__instanceLock__);
    if (_displayCompletionBlock != displayCompletionBlock) {
      _displayCompletionBlock = displayCompletionBlock;
    }
  }

  [self setNeedsDisplay];
}

- (void)_setNeedsDisplayOnTemplatedImages
{
  BOOL isTemplateImage = NO;
  {
    AS::MutexLocker l(__instanceLock__);
    isTemplateImage = (_image.renderingMode == UIImageRenderingModeAlwaysTemplate);
  }

  if (isTemplateImage) {
    [self setNeedsDisplay];
  }
}

- (void)tintColorDidChange
{
  [super tintColorDidChange];

  [self _setNeedsDisplayOnTemplatedImages];
}

#pragma mark Interface State

- (void)didEnterHierarchy
{
  [super didEnterHierarchy];

  [self _setNeedsDisplayOnTemplatedImages];
}

- (void)clearContents
{
  [super clearContents];

  AS::MutexLocker l(__instanceLock__);
  _weakCacheEntry = nil;  // release contents from the cache.
}

#pragma mark - Cropping

- (BOOL)isCropEnabled
{
  AS::MutexLocker l(__instanceLock__);
  return _imageNodeFlags.cropEnabled;
}

- (void)setCropEnabled:(BOOL)cropEnabled
{
  [self setCropEnabled:cropEnabled recropImmediately:NO inBounds:self.bounds];
}

- (void)setCropEnabled:(BOOL)cropEnabled recropImmediately:(BOOL)recropImmediately inBounds:(CGRect)cropBounds
{
  __instanceLock__.lock();
  if (_imageNodeFlags.cropEnabled == cropEnabled) {
    __instanceLock__.unlock();
    return;
  }

  _imageNodeFlags.cropEnabled = cropEnabled;
  _cropDisplayBounds = cropBounds;

  UIImage *image = _image;
  __instanceLock__.unlock();

  // If we have an image to display, display it, respecting our recrop flag.
  if (image != nil) {
    ASPerformBlockOnMainThread(^{
      if (recropImmediately)
        [self displayImmediately];
      else
        [self setNeedsDisplay];
    });
  }
}

- (CGRect)cropRect
{
  AS::MutexLocker l(__instanceLock__);
  return _cropRect;
}

- (void)setCropRect:(CGRect)cropRect
{
  {
    AS::MutexLocker l(__instanceLock__);
    if (CGRectEqualToRect(_cropRect, cropRect)) {
      return;
    }

    _cropRect = cropRect;
  }

  // TODO: this logic needs to be updated to respect cropRect.
  CGSize boundsSize = self.bounds.size;
  CGSize imageSize = self.image.size;

  BOOL isCroppingImage = ((boundsSize.width < imageSize.width) || (boundsSize.height < imageSize.height));

  // Re-display if we need to.
  ASPerformBlockOnMainThread(^{
    if (self.nodeLoaded && self.contentMode == UIViewContentModeScaleAspectFill && isCroppingImage)
      [self setNeedsDisplay];
  });
}

- (BOOL)forceUpscaling
{
  AS::MutexLocker l(__instanceLock__);
  return _imageNodeFlags.forceUpscaling;
}

- (void)setForceUpscaling:(BOOL)forceUpscaling
{
  AS::MutexLocker l(__instanceLock__);
  _imageNodeFlags.forceUpscaling = forceUpscaling;
}

- (CGSize)forcedSize
{
  AS::MutexLocker l(__instanceLock__);
  return _forcedSize;
}

- (void)setForcedSize:(CGSize)forcedSize
{
  AS::MutexLocker l(__instanceLock__);
  _forcedSize = forcedSize;
}

- (asimagenode_modification_block_t)imageModificationBlock
{
  AS::MutexLocker l(__instanceLock__);
  return _imageModificationBlock;
}

- (void)setImageModificationBlock:(asimagenode_modification_block_t)imageModificationBlock
{
  AS::MutexLocker l(__instanceLock__);
  _imageModificationBlock = imageModificationBlock;
}

#pragma mark - Debug

- (void)layout
{
  [super layout];

  if (_debugLabelNode) {
    CGSize boundsSize        = self.bounds.size;
    CGSize debugLabelSize    = [_debugLabelNode layoutThatFits:ASSizeRangeMake(CGSizeZero, boundsSize)].size;
    CGPoint debugLabelOrigin = CGPointMake(boundsSize.width - debugLabelSize.width,
                                           boundsSize.height - debugLabelSize.height);
    _debugLabelNode.frame    = (CGRect) {debugLabelOrigin, debugLabelSize};
  }
}

- (NSDictionary *)debugLabelAttributes
{
  return @{
    NSFontAttributeName: [UIFont systemFontOfSize:15.0],
    NSForegroundColorAttributeName: [UIColor redColor]
  };
}

- (void)asyncTraitCollectionDidChangeWithPreviousTraitCollection:(ASPrimitiveTraitCollection)previousTraitCollection {
  [super asyncTraitCollectionDidChangeWithPreviousTraitCollection:previousTraitCollection];

  if (AS_AVAILABLE_IOS_TVOS(13, 10)) {
    AS::MutexLocker l(__instanceLock__);
      // update image if userInterfaceStyle was changed (dark mode)
      if (_image != nil
          && _primitiveTraitCollection.userInterfaceStyle != previousTraitCollection.userInterfaceStyle) {
        _imageNodeFlags.regenerateFromImageAsset = YES;
      }
  }
}


@end

#pragma mark - Extras

asimagenode_modification_block_t ASImageNodeRoundBorderModificationBlock(CGFloat borderWidth, UIColor *borderColor)
{
  return ^(UIImage *originalImage, ASPrimitiveTraitCollection traitCollection) {
    return ASGraphicsCreateImage(traitCollection, originalImage.size, NO, originalImage.scale, originalImage, nil, ^{
      UIBezierPath *roundOutline = [UIBezierPath bezierPathWithOvalInRect:(CGRect){CGPointZero, originalImage.size}];

      // Make the image round
      [roundOutline addClip];

      // Draw the original image
      [originalImage drawAtPoint:CGPointZero blendMode:kCGBlendModeCopy alpha:1];

      // Draw a border on top.
      if (borderWidth > 0.0) {
        [borderColor setStroke];
        [roundOutline setLineWidth:borderWidth];
        [roundOutline stroke];
      }
    });
  };
}

asimagenode_modification_block_t ASImageNodeTintColorModificationBlock(UIColor *color)
{
  return ^(UIImage *originalImage, ASPrimitiveTraitCollection traitCollection) {
    UIImage *modifiedImage = ASGraphicsCreateImage(traitCollection, originalImage.size, NO, originalImage.scale, originalImage, nil, ^{
      // Set color and render template
      [color setFill];
      UIImage *templateImage = [originalImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
      [templateImage drawAtPoint:CGPointZero blendMode:kCGBlendModeCopy alpha:1];
    });

    // if the original image was stretchy, keep it stretchy
    if (!UIEdgeInsetsEqualToEdgeInsets(originalImage.capInsets, UIEdgeInsetsZero)) {
      modifiedImage = [modifiedImage resizableImageWithCapInsets:originalImage.capInsets resizingMode:originalImage.resizingMode];
    }

    return modifiedImage;
  };
}
