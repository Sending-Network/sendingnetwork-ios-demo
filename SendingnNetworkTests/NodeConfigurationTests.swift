//
// Copyright 2020 New Vector Ltd
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

@testable import Element

class NodeConfigurationTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    // MARK: - Tests
    
    func testNodeConfigurationBuilder() {
    
        let expectedJitsiServer = "your.jitsi.example.org"
        let expectedJitsiServerStringURL = "https://\(expectedJitsiServer)"
        let expectedDeprecatedJitsiServer = "your.deprecated.jitsi.example.org"
        let expectedE2EEEByDefaultEnabled = true
        let expectedDeprecatedE2EEEByDefaultEnabled = false
        let expectedMapStyleURLString = "https://your.tileserver.org/style.json"
        let expectedSecureBackupRequired = true
        let secureBackupSetupMethods = ["passphrase"]
        let expectedSecureBackupSetupMethods: [VectorWellKnownBackupSetupMethod] = [.passphrase]
        let outboundKeysPreSharingMode = "on_room_opening"
        let expectedOutboundKeysPreSharingMode: MXKKeyPreSharingStrategy = .whenEnteringRoom
    
        let wellKnownDictionary: [String: Any] = [
            "m.node": [
                 "base_url": "https://your.node.org"
            ],
             "m.identity_server": [
                 "base_url": "https://your.identity-server.org"
            ],
            "m.tile_server": [
                 "map_style_url": expectedMapStyleURLString
            ],
            "im.vectSending.SendingnNetwork.e2ee" : [
                "default" : expectedDeprecatedE2EEEByDefaultEnabled
            ],
            "im.vectSending.SendingnNetwork.jitsi" : [
                "preferredDomain" : expectedDeprecatedJitsiServer
            ],
            "io.sendingnetwork.e2ee" : [
                "default" : expectedE2EEEByDefaultEnabled,
                "secure_backup_required": expectedSecureBackupRequired,
                "secure_backup_setup_methods": secureBackupSetupMethods,
                "outbound_keys_pre_sharing_mode": outboundKeysPreSharingMode
            ],
            "io.sendingnetwork.jitsi" : [
                "preferredDomain" : expectedJitsiServer
            ]
        ]
        
        let wellKnown = MXWellKnown(fromJSON: wellKnownDictionary)
        
        let nodeConfigurationBuilder = NodeConfigurationBuilder()
        let nodeConfiguration = nodeConfigurationBuilder.build(from: wellKnown)
    
        XCTAssertEqual(nodeConfiguration.jitsi.serverDomain, expectedJitsiServer)
        XCTAssertEqual(nodeConfiguration.jitsi.serverURL?.absoluteString, expectedJitsiServerStringURL)
        XCTAssertEqual(nodeConfiguration.encryption.isE2EEByDefaultEnabled, expectedE2EEEByDefaultEnabled)
        XCTAssertEqual(nodeConfiguration.encryption.isSecureBackupRequired, expectedSecureBackupRequired)
        XCTAssertEqual(nodeConfiguration.encryption.secureBackupSetupMethods, expectedSecureBackupSetupMethods)
        XCTAssertEqual(nodeConfiguration.encryption.outboundKeysPreSharingMode, expectedOutboundKeysPreSharingMode)
        
        XCTAssertEqual(nodeConfiguration.tileServer.mapStyleURL.absoluteString, expectedMapStyleURLString)
    }

    func testNodeEncryptionConfigurationDefaults() {

        let expectedE2EEEByDefaultEnabled = true
        let expectedSecureBackupRequired = false
        let expectedSecureBackupSetupMethods: [VectorWellKnownBackupSetupMethod] = [.passphrase, .key]
        let expectedOutboundKeysPreSharingMode: MXKKeyPreSharingStrategy = .whenTyping

        let wellKnownDictionary: [String: Any] = [
            "m.node": [
                 "base_url": "https://your.node.org"
            ],
             "m.identity_server": [
                 "base_url": "https://your.identity-server.org"
            ]
        ]

        let wellKnown = MXWellKnown(fromJSON: wellKnownDictionary)

        let nodeConfigurationBuilder = NodeConfigurationBuilder()
        let nodeConfiguration = nodeConfigurationBuilder.build(from: wellKnown)

        XCTAssertEqual(nodeConfiguration.encryption.isE2EEByDefaultEnabled, expectedE2EEEByDefaultEnabled)
        XCTAssertEqual(nodeConfiguration.encryption.isSecureBackupRequired, expectedSecureBackupRequired)
        XCTAssertEqual(nodeConfiguration.encryption.secureBackupSetupMethods, expectedSecureBackupSetupMethods)
        XCTAssertEqual(nodeConfiguration.encryption.outboundKeysPreSharingMode, expectedOutboundKeysPreSharingMode)
    }
}
