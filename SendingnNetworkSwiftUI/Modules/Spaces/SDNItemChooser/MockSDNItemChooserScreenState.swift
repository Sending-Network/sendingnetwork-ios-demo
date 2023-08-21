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
import SwiftUI

/// Using an enum for the screen allows you define the different state cases with
/// the relevant associated data for each case.
enum MockSDNItemChooserScreenState: MockScreenState, CaseIterable {
    // A case for each state you want to represent
    // with specific, minimal associated data that will allow you
    // mock that screen.
    case noItems
    case items
    case selectedItems
    case selectionHeader
    
    /// The associated screen
    var screenType: Any.Type {
        SDNItemChooserType.self
    }
    
    /// Generate the view struct for the screen state.
    var screenView: ([Any], AnyView) {
        let service: MockSDNItemChooserService
        let selectionHeader: SDNItemChooserSelectionHeader?
        switch self {
        case .noItems:
            selectionHeader = nil
            service = MockSDNItemChooserService(type: .room, sections: [SDNListItemSectionData()])
        case .items:
            selectionHeader = nil
            service = MockSDNItemChooserService()
        case .selectedItems:
            selectionHeader = nil
            service = MockSDNItemChooserService(type: .room, sections: MockSDNItemChooserService.mockSections, selectedItemIndexPaths: [IndexPath(row: 0, section: 0), IndexPath(row: 2, section: 0), IndexPath(row: 1, section: 1)])
        case .selectionHeader:
            selectionHeader = SDNItemChooserSelectionHeader(title: "Selection Title", selectAllTitle: "Select all items", selectNoneTitle: "Select no items")
            service = MockSDNItemChooserService(type: .room, sections: MockSDNItemChooserService.mockSections, selectedItemIndexPaths: [IndexPath(row: 0, section: 0), IndexPath(row: 2, section: 0), IndexPath(row: 1, section: 1)])
        }
        let viewModel = SDNItemChooserViewModel.makeSDNItemChooserViewModel(sdnItemChooserService: service,
                                                                                  title: VectorL10n.spacesCreationAddRoomsTitle,
                                                                                  detail: VectorL10n.spacesCreationAddRoomsMessage,
                                                                                  selectionHeader: selectionHeader)
        
        // can simulate service and viewModel actions here if needs be.
        
        return (
            [service, viewModel],
            AnyView(SDNItemChooser(viewModel: viewModel.context, listBottomPadding: nil)
                .environmentObject(AvatarViewModel.withMockedServices()))
        )
    }
}
