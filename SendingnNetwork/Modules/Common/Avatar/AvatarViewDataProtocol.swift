// 
// Copyright 2021 New Vector Ltd
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

import UIKit

enum AvatarFallbackImage {
    
    /// sdnItem represent a SDN item like a room, space, user
    /// sdnItemId: SDN item identifier (user id or room id)
    /// displayName: SDN item display name (user or room display name)
    case sdnItem(_ sdnItemId: String, _ displayName: String?)
    
    /// Normal image with optional content mode
    case image(_ image: UIImage, _ contentMode: UIView.ContentMode? = nil)
}

/// AvatarViewDataProtocol describe a view data that should be given to an AvatarView sublcass
protocol AvatarViewDataProtocol: AvatarProtocol {
    /// SDN item identifier (user id or room id)
    var sdnItemId: String { get }
    
    /// SDN item display name (user or room display name)
    var displayName: String? { get }
    
    /// SDN item avatar URL (user or room avatar url)
    var avatarUrl: String? { get }            
        
    /// SDN media handler
    var mediaManager: MXMediaManager? { get }
    
    /// Fallback images used when avatarUrl is nil
    var fallbackImages: [AvatarFallbackImage]? { get }
}

extension AvatarViewDataProtocol {
    func fallbackImageParameters() -> (UIImage?, UIView.ContentMode)? {
        fallbackImages?
            .lazy
            .map { fallbackImage in
                switch fallbackImage {
                case .sdnItem(let sdnItemId, let sdnItemDisplayName):
                    return (AvatarGenerator.generateAvatar(forSDNItem: sdnItemId, withDisplayName: sdnItemDisplayName), .scaleAspectFill)
                case .image(let image, let contentMode):
                    return (image, contentMode ?? .scaleAspectFill)
                }
            }
            .first { (image, contentMode) in
                image != nil
            }
    }
}
