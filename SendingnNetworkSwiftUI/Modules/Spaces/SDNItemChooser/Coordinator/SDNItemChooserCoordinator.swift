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
import UIKit

internal protocol SDNItemChooserCoordinatorViewProvider {
    func view(with viewModel: SDNItemChooserViewModelType.Context) -> AnyView
}

struct SDNItemChooserCoordinatorParameters {
    let session: MXSession
    let title: String?
    let detail: String?
    let selectedItemsIds: [String]
    let viewProvider: SDNItemChooserCoordinatorViewProvider?
    let itemsProcessor: SDNItemChooserProcessorProtocol
    let selectionHeader: SDNItemChooserSelectionHeader?
    
    init(session: MXSession,
         title: String? = nil,
         detail: String? = nil,
         selectedItemsIds: [String] = [],
         selectionHeader: SDNItemChooserSelectionHeader? = nil,
         viewProvider: SDNItemChooserCoordinatorViewProvider? = nil,
         itemsProcessor: SDNItemChooserProcessorProtocol) {
        self.session = session
        self.title = title
        self.detail = detail
        self.selectedItemsIds = selectedItemsIds
        self.viewProvider = viewProvider
        self.itemsProcessor = itemsProcessor
        self.selectionHeader = selectionHeader
    }
}

final class SDNItemChooserCoordinator: Coordinator, Presentable {
    // MARK: - Properties
    
    // MARK: Private
    
    private let parameters: SDNItemChooserCoordinatorParameters
    private let sdnItemChooserHostingController: VectorHostingController
    private var sdnItemChooserViewModel: SDNItemChooserViewModelProtocol

    // MARK: Public

    // Must be used only internally
    var childCoordinators: [Coordinator] = []
    var completion: ((SDNItemChooserViewModelResult) -> Void)?
    
    // MARK: - Setup
    
    init(parameters: SDNItemChooserCoordinatorParameters) {
        self.parameters = parameters
        let viewModel = SDNItemChooserViewModel.makeSDNItemChooserViewModel(sdnItemChooserService: SDNItemChooserService(session: parameters.session, selectedItemIds: parameters.selectedItemsIds, itemsProcessor: parameters.itemsProcessor), title: parameters.title, detail: parameters.detail, selectionHeader: parameters.selectionHeader)
        sdnItemChooserViewModel = viewModel
        if let viewProvider = parameters.viewProvider {
            let view = viewProvider.view(with: viewModel.context)
                .environmentObject(AvatarViewModel(avatarService: AvatarService(mediaManager: parameters.session.mediaManager)))
            sdnItemChooserHostingController = VectorHostingController(rootView: view)
        } else {
            let view = SDNItemChooser(viewModel: viewModel.context, listBottomPadding: nil)
                .environmentObject(AvatarViewModel(avatarService: AvatarService(mediaManager: parameters.session.mediaManager)))
            sdnItemChooserHostingController = VectorHostingController(rootView: view)
        }
    }
    
    // MARK: - Coordinator
    
    func start() {
        MXLog.debug("[SDNItemChooserCoordinator] did start.")
        sdnItemChooserViewModel.completion = { [weak self] result in
            MXLog.debug("[SDNItemChooserCoordinator] SDNItemChooserViewModel did complete with result: \(result).")
            guard let self = self else { return }
            self.completion?(result)
        }
    }
    
    // MARK: - Presentable
    
    func toPresentable() -> UIViewController {
        sdnItemChooserHostingController
    }
}
