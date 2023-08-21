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

/*
 var to: String
 var data: String
 var gas: String
 var gasPrice: String
 var value: String
 var nonce: String
 */


class SDMWalletManager: NSObject {
    @objc static let sharedSingleton = SDMWalletManager()
    
    @objc var from: String = ""
    @objc var to: String = ""
    @objc var data: String = ""
    @objc var gas: String = ""
    @objc var gasPrice: String = ""
    @objc var value: String = ""
    @objc var nonce: String = ""
    @objc var message: String = ""
    @objc var secondMessage: String = ""
    @objc var chainId: String = ""
    @objc var hasLogin: Bool = false
    @objc var otherLogin: String = ""
    
    @objc var invitationCode: String?
    
    private override init() {
        super.init()
    }
    
    func description() -> String {
        return "from:\(from) to:\(to)  data: \(data) gas: \(gas) gasPrice:\(gasPrice) value:\(value) nonce:\(nonce)"
    }
    @objc
    public func updateInfo(from:String, to:String, data:String, gas:String, gasPrice:String, value:String, nonce:String, message:String, chainId:String) {
        SDMWalletManager.sharedSingleton.from = from
        SDMWalletManager.sharedSingleton.to = to
        SDMWalletManager.sharedSingleton.data = data
        SDMWalletManager.sharedSingleton.gas = gas
        SDMWalletManager.sharedSingleton.gasPrice = gasPrice
        SDMWalletManager.sharedSingleton.value = value
        SDMWalletManager.sharedSingleton.nonce = nonce
        SDMWalletManager.sharedSingleton.message = message
        SDMWalletManager.sharedSingleton.chainId = chainId
    }
    
    @objc
    public func clear() {
        SDMWalletManager.sharedSingleton.from = ""
        SDMWalletManager.sharedSingleton.to = ""
        SDMWalletManager.sharedSingleton.data = ""
        SDMWalletManager.sharedSingleton.gas = ""
        SDMWalletManager.sharedSingleton.gasPrice = ""
        SDMWalletManager.sharedSingleton.value = ""
        SDMWalletManager.sharedSingleton.nonce = ""
        SDMWalletManager.sharedSingleton.message = ""
        SDMWalletManager.sharedSingleton.chainId = ""
        SDMWalletManager.sharedSingleton.secondMessage = ""
        SDMWalletManager.sharedSingleton.hasLogin = false
        SDMWalletManager.sharedSingleton.otherLogin = ""
    }
}
