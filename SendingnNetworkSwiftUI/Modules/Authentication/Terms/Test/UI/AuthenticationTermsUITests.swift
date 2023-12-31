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

import SendingnNetworkSwiftUI
import XCTest

class AuthenticationTermsUITests: MockScreenTestCase {
    func testSDNDotOrg() {
        app.goToScreenWithIdentifier(MockAuthenticationTermsScreenState.sdnDotOrg.title)
        verifyTerms(accepted: false)
    }
    
    func testAccepted() {
        app.goToScreenWithIdentifier(MockAuthenticationTermsScreenState.accepted.title)
        verifyTerms(accepted: true)
    }
    
    func testMultiple() {
        app.goToScreenWithIdentifier(MockAuthenticationTermsScreenState.multiple.title)
        verifyTerms(accepted: false)
    }
    
    func verifyTerms(accepted: Bool) {
        let nextButton = app.buttons["nextButton"]
        XCTAssertTrue(nextButton.exists, "The next button should always exist.")
        XCTAssertEqual(nextButton.isEnabled, accepted, "The next button should be enabled when the terms are accepted")
    }
}
