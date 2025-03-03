//
//  ASDisplayNodeImplicitHierarchyTests.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <XCTest/XCTest.h>

#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "AsyncDisplayKit.h"
#import "ASDisplayNode+FrameworkPrivate.h"
#else
#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#endif

#import "ASDisplayNodeTestsHelper.h"

@interface ASSpecTestDisplayNode : ASDisplayNode

/**
 Simple state identifier to allow control of current spec inside of the layoutSpecBlock
 */
@property (nonatomic) NSNumber *layoutState;

@end

@implementation ASSpecTestDisplayNode

- (instancetype)init
{
  self = [super init];
  if (self) {
    _layoutState = @1;
  }
  return self;
}

@end

@interface ASDisplayNodeImplicitHierarchyTests : XCTestCase

@end

@implementation ASDisplayNodeImplicitHierarchyTests

- (void)testFeatureFlag
{
  ASDisplayNode *node = [[ASDisplayNode alloc] init];
  XCTAssertFalse(node.automaticallyManagesSubnodes);
  
  node.automaticallyManagesSubnodes = YES;
  XCTAssertTrue(node.automaticallyManagesSubnodes);
}

- (void)testInitialNodeInsertionWithOrdering
{
  static CGSize kSize = {100, 100};
  
  ASDisplayNode *node1 = [[ASDisplayNode alloc] init];
  ASDisplayNode *node2 = [[ASDisplayNode alloc] init];
  ASDisplayNode *node3 = [[ASDisplayNode alloc] init];
  ASDisplayNode *node4 = [[ASDisplayNode alloc] init];
  ASDisplayNode *node5 = [[ASDisplayNode alloc] init];
  
  
  // As we will involve a stack spec we have to give the nodes an intrinsic content size
  node1.style.preferredSize = kSize;
  node2.style.preferredSize = kSize;
  node3.style.preferredSize = kSize;
  node4.style.preferredSize = kSize;
  node5.style.preferredSize = kSize;

  ASSpecTestDisplayNode *node = [[ASSpecTestDisplayNode alloc] init];
  node.automaticallyManagesSubnodes = YES;
  node.layoutSpecBlock = ^(ASDisplayNode *weakNode, ASSizeRange constrainedSize) {
    ASAbsoluteLayoutSpec *absoluteLayout = [ASAbsoluteLayoutSpec absoluteLayoutSpecWithChildren:@[node4]];
    
    ASStackLayoutSpec *stack1 = [[ASStackLayoutSpec alloc] init];
    [stack1 setChildren:@[node1, node2]];

    ASStackLayoutSpec *stack2 = [[ASStackLayoutSpec alloc] init];
    [stack2 setChildren:@[node3, absoluteLayout]];
    
    return [ASAbsoluteLayoutSpec absoluteLayoutSpecWithChildren:@[stack1, stack2, node5]];
  };
  
  ASDisplayNodeSizeToFitSizeRange(node, ASSizeRangeMake(CGSizeZero, CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)));
  [node.view layoutIfNeeded];

  XCTAssertEqual(node.subnodes[0], node1);
  XCTAssertEqual(node.subnodes[1], node2);
  XCTAssertEqual(node.subnodes[2], node3);
  XCTAssertEqual(node.subnodes[3], node4);
  XCTAssertEqual(node.subnodes[4], node5);
}

- (void)testInitialNodeInsertionWhenEnterPreloadState
{
  static CGSize kSize = {100, 100};

  static NSInteger subnodeCount = 5;
  NSMutableArray<ASDisplayNode *> *subnodes = [NSMutableArray arrayWithCapacity:subnodeCount];
  for (NSInteger i = 0; i < subnodeCount; i++) {
    ASDisplayNode *subnode = [[ASDisplayNode alloc] init];
    // As we will involve a stack spec we have to give the nodes an intrinsic content size
    subnode.style.preferredSize = kSize;
    [subnodes addObject:subnode];
  }

  ASSpecTestDisplayNode *node = [[ASSpecTestDisplayNode alloc] init];
  [node setHierarchyState:ASHierarchyStateRangeManaged];
  node.automaticallyManagesSubnodes = YES;
  node.layoutSpecBlock = ^(ASDisplayNode *weakNode, ASSizeRange constrainedSize) {
    ASAbsoluteLayoutSpec *absoluteLayout = [ASAbsoluteLayoutSpec absoluteLayoutSpecWithChildren:@[subnodes[3]]];

    ASStackLayoutSpec *stack1 = [[ASStackLayoutSpec alloc] init];
    [stack1 setChildren:@[subnodes[0], subnodes[1]]];

    ASStackLayoutSpec *stack2 = [[ASStackLayoutSpec alloc] init];
    [stack2 setChildren:@[subnodes[2], absoluteLayout]];

    return [ASAbsoluteLayoutSpec absoluteLayoutSpecWithChildren:@[stack1, stack2, subnodes[4]]];
  };

  ASDisplayNodeSizeToFitSizeRange(node, ASSizeRangeMake(CGSizeZero, CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)));
  [node recursivelySetInterfaceState:ASInterfaceStatePreload];

  ASCATransactionQueueWait(nil);
  // No premature view allocation
  XCTAssertFalse(node.isNodeLoaded);
  // Subnodes should be inserted, laid out and entered preload state
  XCTAssertTrue([subnodes isEqualToArray:node.subnodes]);
  for (NSInteger i = 0; i < subnodeCount; i++) {
    ASDisplayNode *subnode = subnodes[i];
    XCTAssertTrue(CGSizeEqualToSize(kSize, subnode.bounds.size));
    XCTAssertTrue(ASInterfaceStateIncludesPreload(subnode.interfaceState));
  }
}

- (void)testCalculatedLayoutHierarchyTransitions
{
  static CGSize kSize = {100, 100};
  
  ASDisplayNode *node1 = [[ASDisplayNode alloc] init];
  ASDisplayNode *node2 = [[ASDisplayNode alloc] init];
  ASDisplayNode *node3 = [[ASDisplayNode alloc] init];

  node1.debugName = @"a";
  node2.debugName = @"b";
  node3.debugName = @"c";

  // As we will involve a stack spec we have to give the nodes an intrinsic content size
  node1.style.preferredSize = kSize;
  node2.style.preferredSize = kSize;
  node3.style.preferredSize = kSize;
  
  ASSpecTestDisplayNode *node = [[ASSpecTestDisplayNode alloc] init];
  node.automaticallyManagesSubnodes = YES;
  node.layoutSpecBlock = ^(ASDisplayNode *weakNode, ASSizeRange constrainedSize){
    ASSpecTestDisplayNode *strongNode = (ASSpecTestDisplayNode *)weakNode;
    if ([strongNode.layoutState isEqualToNumber:@1]) {
      return [ASAbsoluteLayoutSpec absoluteLayoutSpecWithChildren:@[node1, node2]];
    } else {
      ASStackLayoutSpec *stackLayout = [[ASStackLayoutSpec alloc] init];
      [stackLayout setChildren:@[node3, node2]];
      return [ASAbsoluteLayoutSpec absoluteLayoutSpecWithChildren:@[node1, stackLayout]];
    }
  };
  
  ASDisplayNodeSizeToFitSizeRange(node, ASSizeRangeMake(CGSizeZero, CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)));
  [node.view layoutIfNeeded];
  XCTAssertEqual(node.subnodes[0], node1);
  XCTAssertEqual(node.subnodes[1], node2);
  
  node.layoutState = @2;
  [node setNeedsLayout]; // After a state change the layout needs to be invalidated
  [node.view layoutIfNeeded]; // A new layout pass will trigger the hiearchy transition

  XCTAssertEqual(node.subnodes[0], node1);
  XCTAssertEqual(node.subnodes[1], node3);
  XCTAssertEqual(node.subnodes[2], node2);
}

// Disable test for now as we disabled the assertion
//- (void)testLayoutTransitionWillThrowForManualSubnodeManagement
//{
//  ASDisplayNode *node1 = [[ASDisplayNode alloc] init];
//  node1.name = @"node1";
//  
//  ASSpecTestDisplayNode *node = [[ASSpecTestDisplayNode alloc] init];
//  node.automaticallyManagesSubnodes = YES;
//  node.layoutSpecBlock = ^ASLayoutSpec *(ASDisplayNode *weakNode, ASSizeRange constrainedSize){
//    return [ASAbsoluteLayoutSpec absoluteLayoutSpecWithChildren:@[node1]];
//  };
//  
//  XCTAssertNoThrow([node layoutThatFits:ASSizeRangeMake(CGSizeZero)]);
//  XCTAssertThrows([node1 removeFromSupernode]);
//}

- (void)testLayoutTransitionMeasurementCompletionBlockIsCalledOnMainThread
{
  const CGSize kSize = CGSizeMake(100, 100);

  ASDisplayNode *displayNode = [[ASDisplayNode alloc] init];
  displayNode.style.preferredSize = kSize;
  
  // Trigger explicit view creation to be able to use the Transition API
  [displayNode view];
  
  XCTestExpectation *expectation = [self expectationWithDescription:@"Call measurement completion block on main"];
  
  [displayNode transitionLayoutWithSizeRange:ASSizeRangeMake(CGSizeZero, CGSizeMake(INFINITY, INFINITY)) animated:YES shouldMeasureAsync:YES measurementCompletion:^{
    XCTAssertTrue(ASDisplayNodeThreadIsMain(), @"Measurement completion block should be called on main thread");
    [expectation fulfill];
  }];
  
  [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

- (void)testMeasurementInBackgroundThreadWithLoadedNode
{
  const CGSize kNodeSize = CGSizeMake(100, 100);
  ASDisplayNode *node1 = [[ASDisplayNode alloc] init];
  ASDisplayNode *node2 = [[ASDisplayNode alloc] init];
  
  ASSpecTestDisplayNode *node = [[ASSpecTestDisplayNode alloc] init];
  node.style.preferredSize = kNodeSize;
  node.automaticallyManagesSubnodes = YES;
  node.layoutSpecBlock = ^(ASDisplayNode *weakNode, ASSizeRange constrainedSize) {
    ASSpecTestDisplayNode *strongNode = (ASSpecTestDisplayNode *)weakNode;
    if ([strongNode.layoutState isEqualToNumber:@1]) {
      return [ASAbsoluteLayoutSpec absoluteLayoutSpecWithChildren:@[node1]];
    } else {
      return [ASAbsoluteLayoutSpec absoluteLayoutSpecWithChildren:@[node2]];
    }
  };
  
  // Intentionally trigger view creation
  [node view];
  [node2 view];
  
  XCTestExpectation *expectation = [self expectationWithDescription:@"Fix IHM layout also if one node is already loaded"];
  
  dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    
    // Measurement happens in the background
    ASDisplayNodeSizeToFitSizeRange(node, ASSizeRangeMake(CGSizeZero, CGSizeMake(INFINITY, INFINITY)));
    
    // Dispatch back to the main thread to let the insertion / deletion of subnodes happening
    dispatch_async(dispatch_get_main_queue(), ^{
      
      // Layout on main
      [node setNeedsLayout];
      [node.view layoutIfNeeded];
      XCTAssertEqual(node.subnodes[0], node1);
      
      dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        // Change state and measure in the background
        node.layoutState = @2;
        [node setNeedsLayout];
    
        ASDisplayNodeSizeToFitSizeRange(node, ASSizeRangeMake(CGSizeZero, CGSizeMake(INFINITY, INFINITY)));
        
        // Dispatch back to the main thread to let the insertion / deletion of subnodes happening
        dispatch_async(dispatch_get_main_queue(), ^{
          
          // Layout on main again
          [node.view layoutIfNeeded];
          XCTAssertEqual(node.subnodes[0], node2);
          
          [expectation fulfill];
        });
      });
    });
  });
  
  [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
    if (error) {
      NSLog(@"Timeout Error: %@", error);
    }
  }];
}

- (void)testTransitionLayoutWithAnimationWithLoadedNodes
{
  const CGSize kNodeSize = CGSizeMake(100, 100);
  ASDisplayNode *node1 = [[ASDisplayNode alloc] init];
  ASDisplayNode *node2 = [[ASDisplayNode alloc] init];
  
  ASSpecTestDisplayNode *node = [[ASSpecTestDisplayNode alloc] init];
  node.automaticallyManagesSubnodes = YES;
  node.style.preferredSize = kNodeSize;
  node.layoutSpecBlock = ^(ASDisplayNode *weakNode, ASSizeRange constrainedSize) {
    ASSpecTestDisplayNode *strongNode = (ASSpecTestDisplayNode *)weakNode;
    if ([strongNode.layoutState isEqualToNumber:@1]) {
      return [ASAbsoluteLayoutSpec absoluteLayoutSpecWithChildren:@[node1]];
    } else {
      return [ASAbsoluteLayoutSpec absoluteLayoutSpecWithChildren:@[node2]];
    }
  };
 
  // Intentionally trigger view creation
  [node1 view];
  [node2 view];
  
  XCTestExpectation *expectation = [self expectationWithDescription:@"Fix IHM layout transition also if one node is already loaded"];
  
  ASDisplayNodeSizeToFitSizeRange(node, ASSizeRangeMake(CGSizeZero, CGSizeMake(INFINITY, INFINITY)));
  [node.view layoutIfNeeded];
  XCTAssertEqual(node.subnodes[0], node1);
  
  node.layoutState = @2;
  [node invalidateCalculatedLayout];
  [node transitionLayoutWithAnimation:YES shouldMeasureAsync:YES measurementCompletion:^{
    // Push this to the next runloop to let async insertion / removing of nodes finished before checking
    dispatch_async(dispatch_get_main_queue(), ^{
      XCTAssertEqual(node.subnodes[0], node2);
      [expectation fulfill];
    });
  }];
  
  [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
    if (error) {
      NSLog(@"Timeout Error: %@", error);
    }
  }];
}

@end
