# SendingNetwork-iOS



## To run the demo, you can follow these steps:



1. Configure the company's domain in SDNSDK:

```
static  NSString * **const** sdnDemoBaseUrl = @"https://XXX";
```

2. Use the local path to reference $sdnSDKVersionSpec = { :path => '../sendingnetwork-ios/SDNSDK.podspec'}


3. cd to the sendingnetwork_ios directory

4. Run xcodegen in the terminal

5. Run pod install in the terminal

6. There are multiple certificate signatures. It is recommended to run the demo on the simulator to bypass the signing. The simulator supports login, chatting, and sending various messages.





## The demo has the following features:

- Login and connect to the server, complete wallet authorization and signing.
- Ability to receive messages, including text, location, and images.
- Ability to send messages, including text, location, and images.
- Personal profile information display.
- Message list.

When used in conjunction with the server, the above features constitute a basic version of a chat app. This demo has been verified to support all of these functionalities.




## Support

When you are experiencing an issue on SendingnNetwork iOS, please first search in [GitHub issues](https://github.com/Sending-Network/sendingnetwork-ios/issues)
. Otherwise feel free to create a GitHub issue if you encounter a bug or a crash, by explaining clearly in detail what happened. You can also perform bug reporting (Rageshake) from the SendingnNetwork application by shaking your phone or going to the application settings. This is especially recommended when you encounter a crash.

## Copyright & License

Copyright (c) 2014-2017 OpenMarket Ltd  
Copyright (c) 2017 Vector Creations Ltd  
Copyright (c) 2017-2021 New Vector Ltd

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this work except in compliance with the License. You may obtain a copy of the License in the [LICENSE](LICENSE) file, or at:

[http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
