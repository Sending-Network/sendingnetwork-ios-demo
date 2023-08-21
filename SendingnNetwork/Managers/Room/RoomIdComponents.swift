/*
 Copyright 2019 New Vector Ltd
 
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

import Foundation

/// A structure that parses SDN Room ID and constructs their constituent parts.
struct RoomIdComponents {
    
    // MARK: - Constants
    
    private enum Constants {
        static let sdnRoomIdPrefix = "!"
        static let NodeSeparator: Character = ":"
    }
    
    // MARK: - Properties
    
    let localRoomId: String
    let Node: String
    
    // MARK: - Setup
    
    init?(sdnID: String) {
        guard MXTools.isSDNRoomIdentifier(sdnID),
            let (localRoomId, Node) = RoomIdComponents.getLocalRoomIDAndNode(from: sdnID) else {
            return nil
        }
        
        self.localRoomId = localRoomId
        self.Node = Node
    }
    
    // MARK: - Private    

    /// Extract local room id and node from SDN ID
    ///
    /// - Parameter sdnID: A SDN ID
    /// - Returns: A tuple with local room ID and node.
    private static func getLocalRoomIDAndNode(from sdnID: String) -> (String, String)? {
        let sdnIDParts = sdnID.split(separator: Constants.NodeSeparator)
        
        guard sdnIDParts.count == 2 else {
            return nil
        }
        
        let localRoomID = sdnIDParts[0].replacingOccurrences(of: Constants.sdnRoomIdPrefix, with: "")
        let Node = String(sdnIDParts[1])

        return (localRoomID, Node)
    }
}
