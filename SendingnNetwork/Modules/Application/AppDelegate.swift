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

import UIKit
import PushKit
import web3swift
import BigInt
import Web3Core
import SDNSDK
import ParticleAuthServiceWrap


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    // MARK: - Properties

    // MARK: Private

    private var appCoordinator: AppCoordinatorType!
    private var rootRouter: RootRouterType!

    private var legacyAppDelegate: LegacyAppDelegate {
        return AppDelegate.theDelegate()
    }
    
    // MARK: Public
    
    /// Call the SendingnNetwork legacy AppDelegate
    @objc class func theDelegate() -> LegacyAppDelegate {
        guard let legacyAppDelegate = LegacyAppDelegate.the() else {
            fatalError("[AppDelegate] theDelegate property should not be nil")
        }
        return legacyAppDelegate
    }
    
    // UIApplicationDelegate properties
    
    /// Main application window
    var window: UIWindow?
    
    // MARK: - UIApplicationDelegate
    
    // MARK: Life cycle
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        
        
        return self.legacyAppDelegate.application(application, willFinishLaunchingWithOptions: launchOptions)
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Setup window
        let window = UIWindow(frame: UIScreen.main.bounds)
        self.window = window
        
        // Create AppCoordinator
        self.rootRouter = RootRouter(window: window)
        
        let appCoordinator = AppCoordinator(router: self.rootRouter, window: window)
        appCoordinator.start()
        self.legacyAppDelegate.delegate = appCoordinator
        
        self.appCoordinator = appCoordinator
        
        // Call legacy AppDelegate
        self.legacyAppDelegate.window = window
        self.legacyAppDelegate.application(application, didFinishLaunchingWithOptions: launchOptions)
        ParticleAuthServiceWrap.WrapParticleAuthService.registerSDK()

    
        return true
    }
    

    
    func someAsyncFunction() async {
        // Perform asynchronous tasks here
        
//        func someFunction() throws {
//            // 可能引发错误的函数
//        }

        do {
            //            try someFunction()/
//            let web3Rinkeby =  try await Web3.InfuraRinkebyWeb3()
//            let keystore = try! EthereumKeystoreV3(password: "")
//            let keystoreManager = KeystoreManager([keystore!])
//            web3Rinkeby.addKeystoreManager(keystoreManager)
//            let address = keystoreManager.addresses![0]
//            let addressString = "0xa6dC81DE79ba5BDB908da792d5A96cBB15Cc7424"
//            if let ethereumAddress = EthereumAddress(addressString) {
////                MXLog.info("Valid Ethereum Address: \(ethereumAddress)")
//                let msgStr = "This is my first Ethereum App";
//                let data = msgStr.data(using: .utf8)
//                let signMsg = try web3Rinkeby.wallet.signPersonalMessage(data!, account: ethereumAddress,password:"f630d27bafc00df4bfb452586f9e7b4dfda1b3f16e242819311473164a2e28d9");
//                MXLog.info("signMsg =\(signMsg)");
//            } else {
//                MXLog.info("Invalid Ethereum Address")
//            }
            
            
            let web3Rinkeby = try await Web3.InfuraRinkebyWeb3()
            ///
            let keystore = try EthereumKeystoreV3(password: "f630d27bafc00df4bfb452586f9e7b4dfda1b3f16e242819311473164a2e28d9")
            let keystoreManager = KeystoreManager([keystore!])
            web3Rinkeby.addKeystoreManager(keystoreManager)
            let address = keystoreManager.addresses![0]
            MXLog.info("address =\(address)");

            let msgStr = "This is my first Ethereum App";
            let data = msgStr.data(using: .utf8)
            MXLog.info("address =\(address)")
            let add = EthereumAddress("0xa6dC81DE79ba5BDB908da792d5A96cBB15Cc7424");
            let signMsg = try web3Rinkeby.wallet.signPersonalMessage(data!, account:address,password: "f630d27bafc00df4bfb452586f9e7b4dfda1b3f16e242819311473164a2e28d9");
            
            
            //            MXLog.info("[UISIDetector] triggerUISI: Unable To Decrypt \(source)")
            let base64str =  signMsg.base64EncodedString(options: []);
//            let dataString = String(data: base64str, encoding: .utf8);
//            MXLog.info("signMsg=\(base64str)");
            
//            if let data = Data(base64Encoded: base64str) {
                // 将二进制数据转化为UTF-8编码的字符串
//            let utf8String = String(data: signMsg, encoding: .utf8)
            MXLog.info("signMsg =\(base64str)")
                
//            }
            
            
            
            // 函数调用成功，继续执行其他操作
        } catch {
            // 处理错误
            MXLog.info("An error occurred: \(error)")
        }
        
        

    }
    

    
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        self.legacyAppDelegate.applicationDidBecomeActive(application)
    }
    
    func applicationWillResignActive(_ application: UIApplication) {        
        self.legacyAppDelegate.applicationWillResignActive(application)
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        Task {
              // Perform any asynchronous tasks here
              await someAsyncFunction()
              
              // Continue with any other tasks
        }
        self.legacyAppDelegate.applicationDidEnterBackground(application)
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        self.legacyAppDelegate.applicationWillEnterForeground(application)
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        self.legacyAppDelegate.applicationWillTerminate(application)
    }
    
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        self.legacyAppDelegate.applicationDidReceiveMemoryWarning(application)
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return self.appCoordinator.open(url: url, options: options)
    }
    
    // MARK: User Activity Continuation
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        return self.legacyAppDelegate.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }
    
    // MARK: Push Notifications
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        self.legacyAppDelegate.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        self.legacyAppDelegate.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        self.legacyAppDelegate.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
    }
}
