// 
// Copyright 2020 New Vector Ltd
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

import Foundation

/// Represents the node configuration (usually based on HS Well-Known or hardcoded values in the project)
@objcMembers
final class NodeConfiguration: NSObject {
    
    // Note: Use an object per configuration subject when there is multiple properties related
    let jitsi: NodeJitsiConfiguration
    let encryption: NodeEncryptionConfiguration
    let tileServer: NodeTileServerConfiguration
    
    init(jitsi: NodeJitsiConfiguration,
         encryption: NodeEncryptionConfiguration,
         tileServer: NodeTileServerConfiguration) {
        self.jitsi = jitsi
        self.encryption = encryption
        self.tileServer = tileServer
    }
}
