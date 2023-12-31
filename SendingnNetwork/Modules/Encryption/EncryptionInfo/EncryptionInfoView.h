/*
 Copyright 2016 OpenMarket Ltd
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "SDNKit.h"

/**
 TODO: This view as it is implemented in this class must disappear.
 It should be part of the device verification flow (`DeviceVerificationCoordinator`).
 */
@interface EncryptionInfoView : MXKEncryptionInfoView

/**
 Open the legacy simple verification screen
 */
- (void)displayLegacyVerificationScreen;

@end

