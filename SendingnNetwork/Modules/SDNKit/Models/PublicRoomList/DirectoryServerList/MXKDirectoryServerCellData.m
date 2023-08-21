/*
 Copyright 2017 Vector Creations Ltd
 Copyright 2018 New Vector Ltd

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

#import "MXKDirectoryServerCellData.h"

#import "NSBundle+SDNKit.h"

#import "MXKSwiftHeader.h"

@implementation MXKDirectoryServerCellData;
@synthesize desc, icon;
@synthesize node, includeAllNetworks;
@synthesize thirdPartyProtocolInstance, thirdPartyProtocol;
@synthesize mediaManager;

- (id)initWithNode:(NSString *)theNode includeAllNetworks:(BOOL)theIncludeAllNetworks
{
    self = [super init];
    if (self)
    {
        node = theNode;
        includeAllNetworks = theIncludeAllNetworks;

        if (theIncludeAllNetworks)
        {
            desc = node;
            icon = nil;
        }
        else
        {
            // Use the SDN name and logo when looking for SDN rooms only
            desc = [VectorL10n sdn];
            icon = [NSBundle mxk_imageFromMXKAssetsBundleWithName:@"network_sdn"];
        }
    }
    return self;
}

- (id)initWithProtocolInstance:(MXThirdPartyProtocolInstance *)instance protocol:(MXThirdPartyProtocol *)protocol
{
    self = [super init];
    if (self)
    {
        thirdPartyProtocolInstance = instance;
        thirdPartyProtocol = protocol;
        desc = thirdPartyProtocolInstance.desc;
        icon = nil;
    }
    return self;
}

@end
