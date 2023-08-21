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

protocol AuthenticationServiceDelegate: AnyObject {
    /// The authentication service encountered an unrecognized certificate and needs to
    /// prompt the user to find out whether or not it should be trusted.
    /// - Parameters:
    ///   - service: The authentication service.
    ///   - unrecognizedCertificate: The certificate data to be trusted.
    ///   - completion: A completion handler called one the user accepts/rejects the certificate.
    func authenticationService(_ service: AuthenticationService, needsPromptFor unrecognizedCertificate: Data?, completion: @escaping (Bool) -> Void)
    /// The authentication service received an SSO login token via a deep link.
    /// This only occurs when SSOAuthenticationPresenter uses an SFSafariViewController.
    /// - Parameters:
    ///   - service: The authentication service.
    ///   - ssoLoginToken: The login token provided when SSO succeeded.
    ///   - transactionID: The transaction ID generated during SSO page presentation.
    /// - Returns: `true` if the SSO login can be continued.
    func authenticationService(_ service: AuthenticationService, didReceive ssoLoginToken: String, with transactionID: String) -> Bool

    func authenticationService(_ service: AuthenticationService,
                               didUpdateStateWithLink link: UniversalLink)
}

@objcMembers
class AuthenticationService: NSObject {
    /// The shared service object.
    static let shared = AuthenticationService()
    
    // MARK: - Properties
    
    // MARK: Private
    
    /// The object used to create a new `MXSession` when authentication has completed.
    private var sessionCreator: SessionCreatorProtocol
    
    // MARK: Public
    
    /// The current state of the authentication flow.
    private(set) var state: AuthenticationState
    /// The rest client used to make authentication requests.
    private(set) var client: AuthenticationRestClient
    /// The current login wizard or `nil` if `startFlow` hasn't been called.
    private(set) var loginWizard: LoginWizard?
    /// The current registration wizard or `nil` if `startFlow` hasn't been called for `.registration`.
    private(set) var registrationWizard: RegistrationWizard?
    /// The provisioning link the service is currently configured with.
    private(set) var provisioningLink: UniversalLink?
    
    /// The authentication service's delegate.
    weak var delegate: AuthenticationServiceDelegate?
    
    /// The type of client to use during the flow.
    var clientType: AuthenticationRestClient.Type = MXRestClient.self
    
    // MARK: - Setup
    
    init(sessionCreator: SessionCreatorProtocol = SessionCreator()) {
        guard let nodeURL = URL(string: BuildSettings.serverConfigDefaultNodeUrlString) else {
            MXLog.failure("[AuthenticationService]: Failed to create URL from default node URL string.")
            fatalError("Invalid default node URL string.")
        }
        
        state = AuthenticationState(flow: .login, nodeAddress: BuildSettings.serverConfigDefaultNodeUrlString)
        client = clientType.init(node: nodeURL, unrecognizedCertificateHandler: nil)
        
        self.sessionCreator = sessionCreator
        
        super.init()
    }
    
    // MARK: - Public

    /// Parse and handle a server provisioning link.
    /// - Parameter universalLink: A link such as https://mobile.sendingnetwork.io/?hs_url=sdn.example.com&is_url=identity.example.com
    /// - Returns: `true` if a provisioning link was detected and handled.
    @discardableResult
    func handleServerProvisioningLink(_ universalLink: UniversalLink) -> Bool {
        MXLog.debug("[AuthenticationService] handleServerProvisioningLink: \(universalLink)")

        let hsUrl = universalLink.nodeUrl
        let isUrl = universalLink.identityServerUrl

        if hsUrl == nil, isUrl == nil {
            MXLog.debug("[AuthenticationService] handleServerProvisioningLink: no hsUrl or isUrl")
            return false
        }

        let isRegister = universalLink.pathParams.first == "register"
        let flow: AuthenticationFlow = isRegister ? .register : .login

        if needsAuthentication {
            reset()
            //  not logged in
            //  update the state with given HS and IS addresses
            state = AuthenticationState(flow: flow,
                                        nodeAddress: hsUrl ?? BuildSettings.serverConfigDefaultNodeUrlString,
                                        identityServer: isUrl ?? BuildSettings.serverConfigDefaultIdentityServerUrlString)
            
            // store the link to override the default node address.
            provisioningLink = universalLink
            delegate?.authenticationService(self, didUpdateStateWithLink: universalLink)
        } else {
            //  logged in
            AppDelegate.theDelegate().displayLogoutConfirmation(for: universalLink, completion: nil)
        }
        return true
    }

    /// Whether authentication is needed by checking for any accounts.
    /// - Returns: `true` there are no accounts or if there is an inactive account that has had a soft logout.
    var needsAuthentication: Bool {
        MXKAccountManager.shared().accounts.isEmpty || softLogoutCredentials != nil
    }
    
    /// Credentials to be used when authenticating after soft logout, otherwise `nil`.
    var softLogoutCredentials: MXCredentials?
    
    /// Get the last authenticated [Session], if there is an active session.
    /// - Returns: The last active session if any, or `nil`
    var lastAuthenticatedSession: MXSession? {
        MXKAccountManager.shared().activeAccounts?.first?.mxSession
    }
    
    /// Set up the service to start a new authentication flow.
    /// - Parameters:
    ///   - flow: The flow to be started (login or register).
    ///   - nodeAddress: The node to start the flow for, or `nil` to use the default.
    ///   If a provisioning link has been set, it will override the default node when passing `nil`.
    func startFlow(_ flow: AuthenticationFlow, for nodeAddress: String? = nil) async throws {
        let address = nodeAddress ?? provisioningLink?.nodeUrl ?? BuildSettings.serverConfigDefaultNodeUrlString
        
        var (client, node) = try await loginFlow(for: address)
        
        let loginWizard = LoginWizard(client: client, sessionCreator: sessionCreator)
        self.loginWizard = loginWizard
        
        if flow == .register {
            do {
                let registrationWizard = RegistrationWizard(client: client, sessionCreator: sessionCreator)
                node.registrationFlow = try await registrationWizard.registrationFlow()
                self.registrationWizard = registrationWizard
            } catch {
                guard node.preferredLoginMode.hasSSO, error as? RegistrationError == .registrationDisabled else {
                    throw error
                }
                // Continue without throwing when registration is disabled but SSO is available.
            }
        }
        
        // The state and client are set after trying the registration flow to
        // ensure the existing state isn't wiped out when an error occurs.
        state = AuthenticationState(flow: flow, node: node)
        self.client = client
    }
    
    /// Get the sign in or sign up fallback URL
    func fallbackURL(for flow: AuthenticationFlow) -> URL {
        switch flow {
        case .login:
            return client.loginFallbackURL
        case .register:
            return client.registerFallbackURL
        }
    }
    
    /// True when login and password has been sent with success to the node
    var isRegistrationStarted: Bool {
        registrationWizard?.isRegistrationStarted ?? false
    }
    
    /// Reset the service to a fresh state.
    /// - Parameter useDefaultServer: Pass `true` to revert back to the one in `BuildSettings`, otherwise the current node will be kept.
    func reset(useDefaultServer: Bool = false) {
        loginWizard = nil
        registrationWizard = nil
        softLogoutCredentials = nil
        
        if useDefaultServer {
            provisioningLink = nil
        }

        // This address will be replaced when `startFlow` is called, but for
        // completeness revert to the default node if requested anyway.
        let address = useDefaultServer ? BuildSettings.serverConfigDefaultNodeUrlString : state.node.addressFromUser ?? state.node.address
        let identityServer = state.identityServer
        state = AuthenticationState(flow: .login,
                                    nodeAddress: address,
                                    identityServer: identityServer)
    }
    
    /// Continues an SSO flow when completion comes via a deep link.
    /// - Parameters:
    ///   - token: The login token provided when SSO succeeded.
    ///   - transactionID: The transaction ID generated during SSO page presentation.
    /// - Returns: `true` if the SSO login can be continued.
    func continueSSOLogin(with token: String, and transactionID: String) -> Bool {
        delegate?.authenticationService(self, didReceive: token, with: transactionID) ?? false
    }
    
    // MARK: - Private
    
    /// Query the supported login flows for the supplied node.
    /// This is the first method to call to be able to get a wizard to login or to create an account
    /// - Parameter nodeAddress: The node string entered by the user.
    /// - Returns: A tuple containing the REST client for the server along with the node state containing the login flows.
    private func loginFlow(for nodeAddress: String) async throws -> (AuthenticationRestClient, AuthenticationState.Node) {
        let nodeAddress = NodeAddress.sanitized(nodeAddress)
        
        guard var nodeURL = URL(string: nodeAddress) else {
            MXLog.error("[AuthenticationService] Unable to create a URL from the supplied node address when calling loginFlow.")
            throw AuthenticationError.invalidNode
        }

        var identityServerURL: URL?
        
        if let wellKnown = try? await wellKnown(for: nodeURL) {
            if let baseURL = URL(string: wellKnown.node.baseUrl) {
                nodeURL = baseURL
            }
            if let identityServer = wellKnown.identityServer,
               let baseURL = URL(string: identityServer.baseUrl) {
                identityServerURL = baseURL
            }
        }
        
        let client = clientType.init(node: nodeURL, unrecognizedCertificateHandler: { [weak self] certificate in
            guard let self = self else { return false }
            
            var isTrusted = false
            let semaphore = DispatchSemaphore(value: 0)
            
            self.delegate?.authenticationService(self, needsPromptFor: certificate) { didTrust in
                isTrusted = didTrust
                semaphore.signal()
            }
            
            semaphore.wait()
            return isTrusted
        })
        
        if let identityServerURL = identityServerURL {
            client.identityServer = identityServerURL.absoluteString
        }
        
        let loginFlow = try await getLoginFlowResult(client: client)
        
        let supportsQRLogin = try await QRLoginService(client: client,
                                                       mode: .notAuthenticated).isServiceAvailable()
        
        let node = AuthenticationState.Node(address: loginFlow.nodeAddress,
                                                        addressFromUser: nodeAddress,
                                                        preferredLoginMode: loginFlow.loginMode,
                                                        supportsQRLogin: supportsQRLogin)
        return (client, node)
    }
    
    /// Request the supported login flows for the corresponding session.
    /// This method is used to get the flows for a server after a soft-logout.
    /// - Parameter session: The MXSession where a soft-logout has occurred.
    private func loginFlow(for session: MXSession) async throws -> (AuthenticationRestClient, AuthenticationState.Node) {
        guard let client = session.sdnRestClient else {
            MXLog.error("[AuthenticationService] loginFlow called on a session that doesn't have a sdnRestClient.")
            throw AuthenticationError.missingMXRestClient
        }
        
        let loginFlow = try await getLoginFlowResult(client: session.sdnRestClient)
        
        let node = AuthenticationState.Node(address: loginFlow.nodeAddress,
                                                        preferredLoginMode: loginFlow.loginMode)
        return (client, node)
    }
    
    private func getLoginFlowResult(client: AuthenticationRestClient) async throws -> LoginFlowResult {
        // Get the login flow
        let loginFlowResponse = try await client.getLoginSession()
        
        let identityProviders = loginFlowResponse.flows?.compactMap { $0 as? MXLoginSSOFlow }.first?.identityProviders ?? []
        return LoginFlowResult(supportedLoginTypes: loginFlowResponse.flows?.compactMap { $0 } ?? [],
                               ssoIdentityProviders: identityProviders.sorted { $0.name < $1.name }.map(\.ssoIdentityProvider),
                               nodeAddress: client.node)
    }
    
    /// Perform a well-known request on the specified node URL.
    private func wellKnown(for nodeURL: URL) async throws -> MXWellKnown {
        let wellKnownClient = clientType.init(node: nodeURL, unrecognizedCertificateHandler: nil)
        
        // The .well-known/sdn/client API is often just a static file returned with no content type.
        // Make our HTTP client compatible with this behaviour
        wellKnownClient.acceptableContentTypes = nil
        
        return try await wellKnownClient.wellKnown()
    }
}

extension MXLoginSSOIdentityProvider {
    var ssoIdentityProvider: SSOIdentityProvider {
        SSOIdentityProvider(id: identifier, name: name, brand: brand, iconURL: icon)
    }
}
