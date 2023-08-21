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

import XCTest

@testable import SendingnNetworkSwiftUI

class AuthenticationSoftLogoutViewModelTests: XCTestCase {
    @MainActor func testInitialStateForSDNOrg() async {
        let credentials = SoftLogoutCredentials(userId: "mock_user_id",
                                                nodeName: "https://sdn.org",
                                                userDisplayName: "mock_username",
                                                deviceId: nil)
        let viewModel = AuthenticationSoftLogoutViewModel(credentials: credentials,
                                                          node: .mockSDNDotOrg,
                                                          keyBackupNeeded: true)
        let context = viewModel.context

        // Given a view model where the user hasn't yet sent the verification email.
        XCTAssert(context.password.isEmpty, "The view model should start with an empty password.")
        XCTAssert(context.viewState.hasInvalidPassword, "The view model should start with an invalid password.")
        XCTAssert(context.viewState.showSSOButtons, "The view model should show SSO buttons for the given node.")
        XCTAssert(context.viewState.showLoginForm, "The view model should show login form for the given node.")
        XCTAssert(context.viewState.showRecoverEncryptionKeysMessage, "The view model should show recover encryption keys message.")
    }

    @MainActor func testInitialStateForNoSSO() async {
        let credentials = SoftLogoutCredentials(userId: "mock_user_id",
                                                nodeName: "https://example.com",
                                                userDisplayName: "mock_username",
                                                deviceId: nil)
        let viewModel = AuthenticationSoftLogoutViewModel(credentials: credentials,
                                                          node: .mockBasicServer,
                                                          keyBackupNeeded: false)
        let context = viewModel.context

        // Given a view model where the user hasn't yet sent the verification email.
        XCTAssert(context.password.isEmpty, "The view model should start with an empty password.")
        XCTAssert(context.viewState.hasInvalidPassword, "The view model should start with an invalid password.")
        XCTAssertFalse(context.viewState.showSSOButtons, "The view model should not show SSO buttons for the given node.")
        XCTAssert(context.viewState.showLoginForm, "The view model should show login form for the given node.")
        XCTAssertFalse(context.viewState.showRecoverEncryptionKeysMessage, "The view model should not show recover encryption keys message.")
    }
}
