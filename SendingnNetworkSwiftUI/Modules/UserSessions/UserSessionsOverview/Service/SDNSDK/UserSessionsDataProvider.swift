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

class UserSessionsDataProvider: UserSessionsDataProviderProtocol {
    private let session: MXSession
    
    init(session: MXSession) {
        self.session = session
    }
    
    var myDeviceId: String {
        session.myDeviceId
    }
    
    var myUserId: String? {
        session.myUserId
    }
    
    var activeAccounts: [MXKAccount] {
        MXKAccountManager.shared().activeAccounts
    }
    
    func devices(completion: @escaping (MXResponse<[MXDevice]>) -> Void) {
        session.sdnRestClient.devices { [weak self] response in
            switch response {
            case .success(let devices):
                self?.deleteAccountDataIfNeeded(deviceList: devices)
            case .failure:
                break
            }
            
            completion(response)
        }
    }
    
    func device(withDeviceId deviceId: String, ofUser userId: String) -> MXDeviceInfo? {
        session.crypto.device(withDeviceId: deviceId, ofUser: userId)
    }
    
    func verificationState(for deviceInfo: MXDeviceInfo?) -> UserSessionInfo.VerificationState {
        guard let deviceInfo = deviceInfo else {
            return .permanentlyUnverified
        }
        
        // When the app is launched offline the cross signing state is "notBootstrapped"
        // In this edge case the verification state returned is `.unknown` since we cannot say more even for the current session.
        guard
            let crossSigning = session.crypto?.crossSigning,
            crossSigning.state.rawValue > MXCrossSigningState.notBootstrapped.rawValue
        else {
            return .unknown
        }
        
        guard crossSigning.canCrossSign else {
            return deviceInfo.deviceId == session.myDeviceId ? .unverified : .unknown
        }
        
        return deviceInfo.trustLevel.isVerified ? .verified : .unverified
    }
    
    func accountData(for eventType: String) -> [AnyHashable: Any]? {
        session.accountData.accountData(forEventType: eventType)
    }

    func qrLoginAvailable() async throws -> Bool {
        let service = QRLoginService(client: session.sdnRestClient,
                                     mode: .authenticated)
        return try await service.isServiceAvailable()
    }
}

extension UserSessionsDataProvider {
    private func deleteAccountDataIfNeeded(deviceList: [MXDevice]) {
        let obsoletedDeviceAccountDataKeys = obsoletedDeviceAccountData(deviceList: deviceList,
                                                                        accountDataEvents: session.accountData.allAccountDataEvents())
        
        for accountDataKey in obsoletedDeviceAccountDataKeys {
            session.deleteAccountData(withType: accountDataKey, success: {}, failure: { _ in })
        }
    }
    
    // internal just to facilitate tests
    func obsoletedDeviceAccountData(deviceList: [MXDevice], accountDataEvents: [String: Any]) -> Set<String> {
        let deviceAccountDataKeys = Set(
                accountDataEvents
                .map(\.key)
                .filter { $0.hasPrefix(kMXAccountDataTypeClientInformation) }
        )
        
        let expectedDeviceAccountDataKeys = Set(deviceList.map {
            "\(kMXAccountDataTypeClientInformation).\($0.deviceId)"
        })
        
        return deviceAccountDataKeys.subtracting(expectedDeviceAccountDataKeys)
    }
}
