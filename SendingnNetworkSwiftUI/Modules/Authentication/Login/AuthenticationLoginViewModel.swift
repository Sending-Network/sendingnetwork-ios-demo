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

import SwiftUI

typealias AuthenticationLoginViewModelType = StateStoreViewModel<AuthenticationLoginViewState, AuthenticationLoginViewAction>

class AuthenticationLoginViewModel: AuthenticationLoginViewModelType, AuthenticationLoginViewModelProtocol {
    // MARK: - Properties

    // MARK: Public

    var callback: (@MainActor (AuthenticationLoginViewModelResult) -> Void)?

    // MARK: - Setup

    init(node: AuthenticationNodeViewData) {
        let bindings = AuthenticationLoginBindings()
        let viewState = AuthenticationLoginViewState(node: node, bindings: bindings)
        
        super.init(initialViewState: viewState)
    }
    
    // MARK: - Public

    override func process(viewAction: AuthenticationLoginViewAction) {
        switch viewAction {
        case .selectServer:
            Task { await callback?(.selectServer) }
        case .parseUsername:
            Task { await callback?(.parseUsername(state.bindings.username)) }
        case .forgotPassword:
            Task { await callback?(.forgotPassword) }
        case .next:
            Task { await callback?(.login(username: state.bindings.username, password: state.bindings.password)) }
        case .fallback:
            Task { await callback?(.fallback) }
        case .continueWithSSO(let provider):
            Task { await callback?(.continueWithSSO(provider)) }
        case .qrLogin:
            Task { await callback?(.qrLogin) }
        case .loginClick:
            Task {await callback?(.loginClick)}
        }
    }
    
    @MainActor func update(isLoading: Bool) {
        guard state.isLoading != isLoading else { return }
        state.isLoading = isLoading
    }
    
    @MainActor func update(node: AuthenticationNodeViewData) {
        state.node = node
    }
    
    @MainActor func displayError(_ type: AuthenticationLoginErrorType) {
        switch type {
        case .mxError(let message):
            state.bindings.alertInfo = AlertInfo(id: type,
                                                 title: VectorL10n.error,
                                                 message: message)
        case .invalidNode:
            state.bindings.alertInfo = AlertInfo(id: type,
                                                 title: VectorL10n.error,
                                                 message: VectorL10n.authenticationServerSelectionGenericError)
        case .unknown:
            state.bindings.alertInfo = AlertInfo(id: type)
        }
    }
}
