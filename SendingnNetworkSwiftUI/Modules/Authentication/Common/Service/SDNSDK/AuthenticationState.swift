//
// Copyright 2022 New Vector Ltd
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
import SDNSDK

struct AuthenticationState {
    // var serverType: ServerType = .unknown
    var flow: AuthenticationFlow
    
    /// Information about the currently selected node.
    var node: Node
    /// Currently selected identity server
    var identityServer: String?
    var isForceLoginFallbackEnabled = false
    
    init(flow: AuthenticationFlow, nodeAddress: String, identityServer: String? = nil) {
        self.flow = flow
        node = Node(address: nodeAddress)
        self.identityServer = identityServer
    }
    
    init(flow: AuthenticationFlow, node: Node, identityServer: String? = nil) {
        self.flow = flow
        self.node = node
        self.identityServer = identityServer
    }
    
    struct Node {
        /// The node address as returned by the server.
        var address: String
        /// The node address as input by the user (it can differ to the well-known request).
        var addressFromUser: String?
        /// The node's address formatted to be displayed to the user in labels, text fields etc.
        var displayableAddress: String {
            let address = addressFromUser ?? address
            return address.replacingOccurrences(of: "https://", with: "") // Only remove https. Leave http to indicate the server doesn't use SSL.
        }
        
        /// The preferred login mode for the server
        var preferredLoginMode: LoginMode = .unknown

        /// Flag indicating whether the node supports logging in via a QR code.
        var supportsQRLogin = false
        
        /// The response returned when querying the node for registration flows.
        var registrationFlow: RegistrationResult?
        
        /// Whether or not the node is for sdn.org.
        var isSDNDotOrg: Bool {
            guard let url = URL(string: address) else { return false }
            return url.host == "sdn.org" || url.host == "sdn-client.sdn.org"
        }
        
        /// The node mapped into view data that is ready for display.
        var viewData: AuthenticationNodeViewData {
            AuthenticationNodeViewData(address: displayableAddress,
                                             showLoginForm: preferredLoginMode.supportsPasswordFlow,
                                             showRegistrationForm: registrationFlow != nil && !needsRegistrationFallback,
                                             showQRLogin: supportsQRLogin,
                                             ssoIdentityProviders: preferredLoginMode.ssoIdentityProviders ?? [])
        }

        /// Needs authentication fallback for login
        var needsLoginFallback: Bool {
            preferredLoginMode.isUnsupported
        }

        /// Needs authentication fallback for registration
        var needsRegistrationFallback: Bool {
            guard let flow = registrationFlow else {
                return false
            }
            switch flow {
            case .flowResponse(let result):
                return result.needsFallback
            default:
                return false
            }
        }
    }
}
