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

import Foundation

class SpaceCreationInviteUsersItemsProcessor: SDNItemChooserProcessorProtocol {
    // MARK: Private
    
    private let creationParams: SpaceCreationParameters
    
    // MARK: Setup
    
    init(creationParams: SpaceCreationParameters) {
        self.creationParams = creationParams
    }
    
    // MARK: SDNItemChooserSelectionProcessorProtocol
    
    private(set) var dataSource: SDNItemChooserDataSource = SDNItemChooserUsersDataSource()
    
    var loadingText: String? {
        nil
    }

    func computeSelection(withIds itemsIds: [String], completion: @escaping (Result<Void, Error>) -> Void) {
        creationParams.inviteType = .userId
        creationParams.userIdInvites = itemsIds
        completion(.success(()))
    }
    
    func isItemIncluded(_ item: SDNListItemData) -> Bool {
        true
    }
}
