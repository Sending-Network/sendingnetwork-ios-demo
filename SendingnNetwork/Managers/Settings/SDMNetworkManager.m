// 
// Copyright 2022 New Vector Ltd
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "SDMNetworkManager.h"
#import "GeneratedInterface-Swift.h"

@implementation SDMNetworkManager

+ (SDMNetworkManager *)sharedInstance {
    static SDMNetworkManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[SDMNetworkManager alloc] init];
    });
    
    return sharedManager;
}

//- (SDMNetworkType)getNetworkType {
//    SDMNetworkType type = SDMNetworkAgencyType;
//    BOOL isP2pNetworkOn = SendingnNetworkSettings.shared.isP2PNetworkOn;
//    if (isP2pNetworkOn) {
//        type = SDMNetworkP2PType;
//    } else {
//        type = SDMNetworkAgencyType;
//    }
//    return type;
//}
//
//- (void)switchNework:(SDMNetworkType)network {
//    switch (network) {
//        case SDMNetworkP2PType:
//            SendingnNetworkSettings.shared.isP2PNetworkOn = true;
//            SendingnNetworkSettings.shared.nodeUrlString = BuildSettings.serverConfigDefaultP2PNodeUrlString;
//            break;
//        case SDMNetworkAgencyType:
//        default:
//            SendingnNetworkSettings.shared.isP2PNetworkOn = false;
//            SendingnNetworkSettings.shared.nodeUrlString = BuildSettings.serverConfigDefaultNodeUrlString;
//            break;
//    }
//}
//
//- (void)switchToP2PNework:(BOOL)ret {
//    SendingnNetworkSettings.shared.isP2PNetworkOn = ret;
//    SendingnNetworkSettings.shared.nodeUrlString = ret
//                        ? BuildSettings.serverConfigDefaultP2PNodeUrlString
//                        : BuildSettings.serverConfigDefaultNodeUrlString;
//}

@end
