//
//  ASDKNavigationControllerTests.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <XCTest/XCTest.h>

#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "AsyncDisplayKit.h"
#else
#import <AsyncDisplayKit/AsyncDisplayKit.h>
#endif

@interface ASDKNavigationControllerTests : XCTestCase
@end

@implementation ASDKNavigationControllerTests

- (void)testSetViewControllers {
  ASDKViewController *firstController = [ASDKViewController new];
  ASDKViewController *secondController = [ASDKViewController new];
  NSArray *expectedViewControllerStack = @[firstController, secondController];
  ASDKNavigationController *navigationController = [ASDKNavigationController new];
  [navigationController setViewControllers:@[firstController, secondController]];
  XCTAssertEqual(navigationController.topViewController, secondController);
  XCTAssertEqual(navigationController.visibleViewController, secondController);
  XCTAssertTrue([navigationController.viewControllers isEqualToArray:expectedViewControllerStack]);
}

- (void)testPopViewController {
  ASDKViewController *firstController = [ASDKViewController new];
  ASDKViewController *secondController = [ASDKViewController new];
  NSArray *expectedViewControllerStack = @[firstController];
  ASDKNavigationController *navigationController = [ASDKNavigationController new];
  [navigationController setViewControllers:@[firstController, secondController]];
  [navigationController popViewControllerAnimated:false];
  XCTAssertEqual(navigationController.topViewController, firstController);
  XCTAssertEqual(navigationController.visibleViewController, firstController);
  XCTAssertTrue([navigationController.viewControllers isEqualToArray:expectedViewControllerStack]);
}

- (void)testPushViewController {
  ASDKViewController *firstController = [ASDKViewController new];
  ASDKViewController *secondController = [ASDKViewController new];
  NSArray *expectedViewControllerStack = @[firstController, secondController];
  ASDKNavigationController *navigationController = [[ASDKNavigationController new] initWithRootViewController:firstController];
  [navigationController pushViewController:secondController animated:false];
  XCTAssertEqual(navigationController.topViewController, secondController);
  XCTAssertEqual(navigationController.visibleViewController, secondController);
  XCTAssertTrue([navigationController.viewControllers isEqualToArray:expectedViewControllerStack]);
}

@end
