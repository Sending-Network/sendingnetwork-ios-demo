/*
Copyright 2015 OpenMarket Ltd

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

#import <UIKit/UIKit.h>

#import "MXKViewController.h"

#import "MXKSearchDataSource.h"

/**
 This view controller handles search server side. Only one sdn session is handled by this view controller.
 
 According to its dataSource configuration the search can be done all user's rooms or a set of rooms.
 */
@interface MXKSearchViewController : MXKViewController <UITableViewDelegate, MXKDataSourceDelegate, UISearchBarDelegate>

@property (weak, nonatomic) IBOutlet UISearchBar *searchSearchBar;
@property (weak, nonatomic) IBOutlet UITableView *searchTableView;
@property (weak, nonatomic) IBOutlet UILabel *noResultsLabel;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *searchSearchBarTopConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *searchSearchBarHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *searchTableViewBottomConstraint;

/**
 The current data source associated to the view controller.
 */
@property (nonatomic, readonly) MXKSearchDataSource *dataSource;

/**
 Enable the search option by adding a navigation item in the navigation bar (YES by default).
 Set NO this property to disable this option and hide the related bar button.
 */
@property (nonatomic) BOOL enableBarButtonSearch;

/**
 If YES, the table view will scroll at the bottom on the next data source refresh.
 It comes back to NO after each refresh.
 */
@property (nonatomic) BOOL shouldScrollToBottomOnRefresh;


#pragma mark - Class methods

/**
 Creates and returns a new `MXKSearchViewController` object.
 
 @discussion This is the designated initializer for programmatic instantiation.
 @return An initialized `MXKSearchViewController` object if successful, `nil` otherwise.
 */
+ (instancetype)searchViewController;

/**
 Display the search results described in the provided data source.
 
 Note: The provided data source replaces the current data source if any. The current
 data source is released.

 @param searchDataSource the data source providing the search results.
 */
- (void)displaySearch:(MXKSearchDataSource*)searchDataSource;

@end
