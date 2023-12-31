/*
 Copyright 2016 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
 
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

#import "UINavigationController+SendingnNetwork.h"

@implementation UINavigationController (SendingnNetwork)

- (BOOL)shouldAutorotate
{
    if (self.topViewController)
    {
        return [self.topViewController shouldAutorotate];
    }
    
    return YES;
}

-(UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    if (self.topViewController)
    {
        return [self.topViewController supportedInterfaceOrientations];
    }
    
    return UIInterfaceOrientationMaskAll;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    if (self.topViewController)
    {
        return [self.topViewController preferredInterfaceOrientationForPresentation];
    }
    
    return UIInterfaceOrientationPortrait;
}

@end
