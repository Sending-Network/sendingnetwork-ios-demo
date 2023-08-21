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

import Combine
import SwiftUI

typealias SDNItemChooserViewModelType = StateStoreViewModel<SDNItemChooserViewState, SDNItemChooserViewAction>

class SDNItemChooserViewModel: SDNItemChooserViewModelType, SDNItemChooserViewModelProtocol {
    // MARK: - Properties

    // MARK: Private

    private var sdnItemChooserService: SDNItemChooserServiceProtocol

    private var isLoading = false {
        didSet {
            state.loading = isLoading
            if isLoading {
                state.error = nil
            }
        }
    }
    
    // MARK: Public

    var completion: ((SDNItemChooserViewModelResult) -> Void)?

    // MARK: - Setup

    static func makeSDNItemChooserViewModel(sdnItemChooserService: SDNItemChooserServiceProtocol, title: String?, detail: String?, selectionHeader: SDNItemChooserSelectionHeader?) -> SDNItemChooserViewModelProtocol {
        SDNItemChooserViewModel(sdnItemChooserService: sdnItemChooserService, title: title, detail: detail, selectionHeader: selectionHeader)
    }

    private init(sdnItemChooserService: SDNItemChooserServiceProtocol, title: String?, detail: String?, selectionHeader: SDNItemChooserSelectionHeader?) {
        self.sdnItemChooserService = sdnItemChooserService
        super.init(initialViewState: Self.defaultState(service: sdnItemChooserService, title: title, detail: detail, selectionHeader: selectionHeader))
        startObservingItems()
    }

    private static func defaultState(service: SDNItemChooserServiceProtocol, title: String?, detail: String?, selectionHeader: SDNItemChooserSelectionHeader?) -> SDNItemChooserViewState {
        let title = title
        let message = detail
        let emptyListMessage = VectorL10n.spacesNoResultFoundTitle

        return SDNItemChooserViewState(title: title, message: message, emptyListMessage: emptyListMessage, sections: service.sectionsSubject.value, itemCount: service.itemCount, selectedItemIds: service.selectedItemIdsSubject.value, loadingText: service.loadingText, loading: false, selectionHeader: selectionHeader)
    }

    private func startObservingItems() {
        sdnItemChooserService.sectionsSubject.sink { [weak self] sections in
            self?.state.sections = sections
            self?.state.itemCount = self?.sdnItemChooserService.itemCount ?? 0
        }
        .store(in: &cancellables)
        sdnItemChooserService.selectedItemIdsSubject.sink { [weak self] selectedItemIds in
            self?.state.selectedItemIds = selectedItemIds
        }
        .store(in: &cancellables)
    }

    // MARK: - Public

    override func process(viewAction: SDNItemChooserViewAction) {
        switch viewAction {
        case .cancel:
            cancel()
        case .back:
            back()
        case .done:
            isLoading = true
            sdnItemChooserService.processSelection { [weak self] result in
                guard let self = self else { return }
                
                self.isLoading = false

                switch result {
                case .success:
                    let selectedItemsId = Array(self.sdnItemChooserService.selectedItemIdsSubject.value)
                    self.done(selectedItemsId: selectedItemsId)
                case .failure(let error):
                    self.sdnItemChooserService.refresh()
                    self.state.error = error.localizedDescription
                }
            }
        case .searchTextChanged(let searchText):
            sdnItemChooserService.searchText = searchText
        case .itemTapped(let itemId):
            sdnItemChooserService.reverseSelectionForItem(withId: itemId)
        case .selectAll:
            sdnItemChooserService.selectAllItems()
        case .selectNone:
            sdnItemChooserService.deselectAllItems()
        }
    }
    
    private func done(selectedItemsId: [String]) {
        completion?(.done(selectedItemsId))
    }

    private func cancel() {
        completion?(.cancel)
    }
    
    private func back() {
        completion?(.back)
    }
}
