/*
 Copyright 2015 OpenMarket Ltd
 
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

#import "MXKEventFormatter.h"

/**
 Define a `MXEvent` category at sdnKit level to store data related to UI handling.
 */
@interface MXEvent (SDNKit)

/**
 The potential error observed when the event formatter tried to stringify the event (MXKEventFormatterErrorNone by default).
 */
@property (nonatomic) MXKEventFormatterError mxkEventFormatterError;

/**
 Tell whether the event is highlighted or not (NO by default).
 */
@property (nonatomic) BOOL mxkIsHighlighted;

@end