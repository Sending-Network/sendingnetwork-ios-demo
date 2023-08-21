// 
// Copyright 2020 Vector Creations Ltd
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

/// AppConfiguration is CommonConfiguration plus configurations dedicated to the app
class AppConfiguration: CommonConfiguration {
    
    // MARK: - Global settings
    
    override func setupSettings() {
        super.setupSettings()
        setupAppSettings()
    }
    
    private func setupAppSettings() {
        // Enable CallKit for app
        MXKAppSettings.standard()?.isCallKitEnabled = true
        
        // Get additional events (modular widget, voice broadcast...)
        MXKAppSettings.standard()?.addSupportedEventTypes([kWidgetSDNEventTypeString,
                                                           kWidgetModularEventTypeString,
                                                           VoiceBroadcastSettings.voiceBroadcastInfoContentKeyType])
        
        // Hide undecryptable messages that were sent while the user was not in the room
        MXKAppSettings.standard()?.hidePreJoinedUndecryptableEvents = true
        
        // Enable long press on event in bubble cells
        MXKRoomBubbleTableViewCell.disableLongPressGesture(onEvent: false)
        
        // Each room member will be considered as a potential contact.
        MXKContactManager.shared().contactManagerMXRoomSource = MXKContactManagerMXRoomSource.all
        
        // Use UIKit BackgroundTask for handling background tasks in the SDK
        MXSDKOptions.sharedInstance().backgroundModeHandler = MXUIKitBackgroundModeHandler()
        
        // Enable key backup on app
        MXSDKOptions.sharedInstance().enableKeyBackupWhenStartingMXCrypto = true
    }
    
    
    // MARK: - Per sdn session settings
    
    override func setupSettings(for sdnSession: MXSession) {
        super.setupSettings(for: sdnSession)
        setupWidgetReadReceipts(for: sdnSession)
    }
  
    private func setupWidgetReadReceipts(for sdnSession: MXSession) {
        var acknowledgableEventTypes = sdnSession.acknowledgableEventTypes ?? []
        acknowledgableEventTypes.append(kWidgetSDNEventTypeString)
        acknowledgableEventTypes.append(kWidgetModularEventTypeString)

        sdnSession.acknowledgableEventTypes = acknowledgableEventTypes
    }
    
}
