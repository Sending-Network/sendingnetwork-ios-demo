/*
 Copyright 2015 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
 Copyright 2019 The Matrix.org Foundation C.I.C
 
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

#import "MXKContactManager.h"

#import "MXKContact.h"

#import "MXKAppSettings.h"
#import "MXKTools.h"
#import "NSBundle+SDNKit.h"
#import <SDNSDK/MXAes.h>
#import <SDNSDK/MXRestClient.h>
#import <SDNSDK/MXKeyProvider.h>

#import "MXKSwiftHeader.h"

NSString *const kMXKContactManagerDidUpdateSDNContactsNotification = @"kMXKContactManagerDidUpdateSDNContactsNotification";

NSString *const kMXKContactManagerDidUpdateLocalContactsNotification = @"kMXKContactManagerDidUpdateLocalContactsNotification";
NSString *const kMXKContactManagerDidUpdateLocalContactSDNIDsNotification = @"kMXKContactManagerDidUpdateLocalContactSDNIDsNotification";

NSString *const kMXKContactManagerSDNUserPresenceChangeNotification = @"kMXKContactManagerSDNUserPresenceChangeNotification";
NSString *const kMXKContactManagerSDNPresenceKey = @"kMXKContactManagerSDNPresenceKey";

NSString *const kMXKContactManagerDidInternationalizeNotification = @"kMXKContactManagerDidInternationalizeNotification";

NSString *const MXKContactManagerDataType = @"org.sdn.kit.MXKContactManagerDataType";

@interface MXKContactManager()
{
    /**
     Array of `MXSession` instances.
     */
    NSMutableArray *mxSessionArray;
    id mxSessionStateObserver;
    id mxSessionNewSyncedRoomObserver;
    
    /**
     Listeners registered on sdn presence and membership events (one by sdn session)
     */
    NSMutableArray *mxEventListeners;
    
    /**
     Local contacts handling
     */
    BOOL isLocalContactListRefreshing;
    dispatch_queue_t processingQueue;
    NSDate *lastSyncDate;
    // Local contacts by contact Id
    NSMutableDictionary* localContactByContactID;
    NSMutableArray* localContactsWithMethods;
    NSMutableArray* splitLocalContacts;
    
    // SDN id linked to 3PID.
    NSMutableDictionary<NSString*, NSString*> *sdnIDBy3PID;
    
    /**
     SDN contacts handling
     */
    // SDN contacts by contact Id
    NSMutableDictionary* sdnContactByContactID;
    // SDN contacts by sdn id
    NSMutableDictionary* sdnContactBySDNID;
}

@end

@implementation MXKContactManager
@synthesize contactManagerMXRoomSource;

#pragma mark Singleton Methods

+ (instancetype)sharedManager
{
    static MXKContactManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[MXKContactManager alloc] init];
    });
    return sharedInstance;
}

#pragma mark -

-(MXKContactManager *)init
{
    if (self = [super init])
    {
        NSString *label = [NSString stringWithFormat:@"SDNKit.%@.Contacts", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]];
        
        [self deleteOldFiles];
        
        processingQueue = dispatch_queue_create([label UTF8String], DISPATCH_QUEUE_SERIAL);
        
        // save the last sync date
        // to avoid resync the whole phonebook
        lastSyncDate = nil;
        
        self.contactManagerMXRoomSource = MXKContactManagerMXRoomSourceDirectChats;
        
        // Observe related settings change
        [[MXKAppSettings standardAppSettings]  addObserver:self forKeyPath:@"syncLocalContacts" options:0 context:nil];
        [[MXKAppSettings standardAppSettings]  addObserver:self forKeyPath:@"phonebookCountryCode" options:0 context:nil];

        [self registerAccountDataDidChangeIdentityServerNotification];
        self.allowLocalContactsAccess = YES;
    }
    
    return self;
}

-(void)dealloc
{
    sdnIDBy3PID = nil;

    localContactByContactID = nil;
    localContactsWithMethods = nil;
    splitLocalContacts = nil;
    
    sdnContactByContactID = nil;
    sdnContactBySDNID = nil;
    
    lastSyncDate = nil;
    
    while (mxSessionArray.count) {
        [self removeSDNSession:mxSessionArray.lastObject];
    }
    mxSessionArray = nil;
    mxEventListeners = nil;
    
    [[MXKAppSettings standardAppSettings] removeObserver:self forKeyPath:@"syncLocalContacts"];
    [[MXKAppSettings standardAppSettings] removeObserver:self forKeyPath:@"phonebookCountryCode"];
    
    processingQueue = nil;
}

#pragma mark -

- (void)addSDNSession:(MXSession*)mxSession
{
    if (!mxSessionArray)
    {
        mxSessionArray = [NSMutableArray array];
    }
    if (!mxEventListeners)
    {
        mxEventListeners = [NSMutableArray array];
    }
    
    if ([mxSessionArray indexOfObject:mxSession] == NSNotFound)
    {
        [mxSessionArray addObject:mxSession];
        
        MXWeakify(self);
        
        // Register a listener on sdn presence and membership events
        id eventListener = [mxSession listenToEventsOfTypes:@[kMXEventTypeStringRoomMember, kMXEventTypeStringPresence]
                                                       onEvent:^(MXEvent *event, MXTimelineDirection direction, id customObject) {
                                                           
                               MXStrongifyAndReturnIfNil(self);
                                                           
                               // Consider only live event
                               if (direction == MXTimelineDirectionForwards)
                               {
                                   // Consider first presence events
                                   if (event.eventType == MXEventTypePresence)
                                   {
                                       // Check whether the concerned sdn user belongs to at least one contact.
                                       BOOL isMatched = ([self->sdnContactBySDNID objectForKey:event.sender] != nil);
                                       if (!isMatched)
                                       {
                                           NSArray *sdnIDs = [self->sdnIDBy3PID allValues];
                                           isMatched = ([sdnIDs indexOfObject:event.sender] != NSNotFound);
                                       }
                                       
                                       if (isMatched) {
                                           [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerSDNUserPresenceChangeNotification object:event.sender userInfo:@{kMXKContactManagerSDNPresenceKey:event.content[@"presence"]}];
                                       }
                                   }
                                   // Else the event type is MXEventTypeRoomMember.
                                   // Ignore here membership events if the session is not running yet,
                                   // Indeed all the contacts are refreshed when session state becomes running.
                                   else if (mxSession.state == MXSessionStateRunning)
                                   {
                                       // Update sdn contact list on membership change
                                       [self updateSDNContactWithID:event.sender];
                                   }
                               }
                           }];
        
        [mxEventListeners addObject:eventListener];
        
        // Update sdn contact list in case of new synced one-to-one room
        if (!mxSessionNewSyncedRoomObserver)
        {
            mxSessionNewSyncedRoomObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXRoomInitialSyncNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
                
                MXStrongifyAndReturnIfNil(self);
                
                // create contact for known room members
                if (self.contactManagerMXRoomSource != MXKContactManagerMXRoomSourceNone)
                {
                    MXRoom *room = notif.object;
                    [room state:^(MXRoomState *roomState) {

                        MXRoomMembers *roomMembers = roomState.members;

                        NSArray *members = roomMembers.members;

                        // Consider only 1:1 chat for MXKMemberContactCreationOneToOneRoom
                        // or adding all
                        if (((members.count == 2) && (self.contactManagerMXRoomSource == MXKContactManagerMXRoomSourceDirectChats)) || (self.contactManagerMXRoomSource == MXKContactManagerMXRoomSourceAll))
                        {
                            NSString* myUserId = room.mxSession.myUser.userId;

                            for (MXRoomMember* member in members)
                            {
                                if ([member.userId isEqualToString:myUserId])
                                {
                                    [self updateSDNContactWithID:member.userId];
                                }
                            }
                        }
                    }];
                }
            }];
        }
        
        // Update all sdn contacts as soon as sdn session is ready
        if (!mxSessionStateObserver) {
            mxSessionStateObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXSessionStateDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
                
                MXStrongifyAndReturnIfNil(self);
                
                MXSession *mxSession = notif.object;
                
                if ([self->mxSessionArray indexOfObject:mxSession] != NSNotFound)
                {
                    if ((mxSession.state == MXSessionStateStoreDataReady) || (mxSession.state == MXSessionStateRunning)) {
                        [self refreshSDNContacts];
                    }
                }
            }];
        }

        // refreshSDNContacts can take time. Delay its execution to not overload
        // launch of apps that call [MXKContactManager addSDNSession] at startup
        dispatch_async(dispatch_get_main_queue(), ^{
            [self refreshSDNContacts];
        });
    }
}

- (void)removeSDNSession:(MXSession*)mxSession
{
    NSUInteger index = [mxSessionArray indexOfObject:mxSession];
    if (index != NSNotFound)
    {
        id eventListener = [mxEventListeners objectAtIndex:index];
        [mxSession removeListener:eventListener];
        
        [mxEventListeners removeObjectAtIndex:index];
        [mxSessionArray removeObjectAtIndex:index];
        
        if (!mxSessionArray.count) {
            if (mxSessionStateObserver) {
                [[NSNotificationCenter defaultCenter] removeObserver:mxSessionStateObserver];
                mxSessionStateObserver = nil;
            }
            
            if (mxSessionNewSyncedRoomObserver) {
                [[NSNotificationCenter defaultCenter] removeObserver:mxSessionNewSyncedRoomObserver];
                mxSessionNewSyncedRoomObserver = nil;
            }
        }
        
        // Update sdn contacts list
        [self refreshSDNContacts];
    }
}

- (NSArray*)mxSessions
{
    return [NSArray arrayWithArray:mxSessionArray];
}


- (NSArray*)sdnContacts
{
    NSParameterAssert([NSThread isMainThread]);

    return [sdnContactByContactID allValues];
}

- (NSArray*)localContacts
{
    NSParameterAssert([NSThread isMainThread]);

    // Return nil if the loading step is in progress.
    if (isLocalContactListRefreshing)
    {
        return nil;
    }
    
    return [localContactByContactID allValues];
}

- (NSArray*)localContactsWithMethods
{
    NSParameterAssert([NSThread isMainThread]);

    // Return nil if the loading step is in progress.
    if (isLocalContactListRefreshing)
    {
        return nil;
    }
    
    // Check whether the array must be prepared
    if (!localContactsWithMethods)
    {
        // List all the local contacts with emails and/or phones
        NSArray *localContacts = self.localContacts;
        localContactsWithMethods = [NSMutableArray arrayWithCapacity:localContacts.count];
        
        for (MXKContact* contact in localContacts)
        {
            if (contact.emailAddresses)
            {
                [localContactsWithMethods addObject:contact];
            }
            else if (contact.phoneNumbers)
            {
                [localContactsWithMethods addObject:contact];
            }
        }
    }
    
    return localContactsWithMethods;
}

- (NSArray*)localContactsSplitByContactMethod
{
   NSParameterAssert([NSThread isMainThread]);

    // Return nil if the loading step is in progress.
    if (isLocalContactListRefreshing)
    {
        return nil;
    }
    
    // Check whether the array must be prepared
    if (!splitLocalContacts)
    {
        // List all the local contacts with contact methods
        NSArray *contactsArray = self.localContactsWithMethods;
        
        splitLocalContacts = [NSMutableArray arrayWithCapacity:contactsArray.count];
        
        for (MXKContact* contact in contactsArray)
        {
            NSArray *emails = contact.emailAddresses;
            NSArray *phones = contact.phoneNumbers;
            
            if (emails.count + phones.count > 1)
            {
                for (MXKEmail *email in emails)
                {
                    MXKContact *splitContact = [[MXKContact alloc] initContactWithDisplayName:contact.displayName emails:@[email] phoneNumbers:nil andThumbnail:contact.thumbnail];
                    [splitLocalContacts addObject:splitContact];
                }
                
                for (MXKPhoneNumber *phone in phones)
                {
                    MXKContact *splitContact = [[MXKContact alloc] initContactWithDisplayName:contact.displayName emails:nil phoneNumbers:@[phone] andThumbnail:contact.thumbnail];
                    [splitLocalContacts addObject:splitContact];
                }
            }
            else if (emails.count + phones.count)
            {
                [splitLocalContacts addObject:contact];
            }
        }
        
        // Sort alphabetically the resulting list
        [self sortAlphabeticallyContacts:splitLocalContacts];
    }
    
    return splitLocalContacts;
}


//- (void)localContactsSplitByContactMethod:(void (^)(NSArray<MXKContact*> *localContactsSplitByContactMethod))onComplete
//{
//    NSParameterAssert([NSThread isMainThread]);
//
//    // Return nil if the loading step is in progress.
//    if (isLocalContactListRefreshing)
//    {
//        onComplete(nil);
//        return;
//    }
//    
//    // Check whether the array must be prepared
//    if (!splitLocalContacts)
//    {
//        // List all the local contacts with contact methods
//        NSArray *contactsArray = self.localContactsWithMethods;
//        
//        splitLocalContacts = [NSMutableArray arrayWithCapacity:contactsArray.count];
//        
//        for (MXKContact* contact in contactsArray)
//        {
//            NSArray *emails = contact.emailAddresses;
//            NSArray *phones = contact.phoneNumbers;
//            
//            if (emails.count + phones.count > 1)
//            {
//                for (MXKEmail *email in emails)
//                {
//                    MXKContact *splitContact = [[MXKContact alloc] initContactWithDisplayName:contact.displayName emails:@[email] phoneNumbers:nil andThumbnail:contact.thumbnail];
//                    [splitLocalContacts addObject:splitContact];
//                }
//                
//                for (MXKPhoneNumber *phone in phones)
//                {
//                    MXKContact *splitContact = [[MXKContact alloc] initContactWithDisplayName:contact.displayName emails:nil phoneNumbers:@[phone] andThumbnail:contact.thumbnail];
//                    [splitLocalContacts addObject:splitContact];
//                }
//            }
//            else if (emails.count + phones.count)
//            {
//                [splitLocalContacts addObject:contact];
//            }
//        }
//        
//        // Sort alphabetically the resulting list
//        [self sortAlphabeticallyContacts:splitLocalContacts];
//    }
//    
//    onComplete(splitLocalContacts);
//}

- (NSArray*)directSDNContacts
{
    NSParameterAssert([NSThread isMainThread]);

    NSMutableDictionary *directContacts = [NSMutableDictionary dictionary];
    
    NSArray *mxSessions = self.mxSessions;
    
    for (MXSession *mxSession in mxSessions)
    {
        // Check all existing users for whom a direct chat exists
        NSArray *mxUserIds = mxSession.directRooms.allKeys;
        
        for (NSString *mxUserId in mxUserIds)
        {
            MXKContact* contact = [sdnContactBySDNID objectForKey:mxUserId];
            
            // Sanity check - the contact must be already defined here
            if (contact)
            {
                [directContacts setValue:contact forKey:mxUserId];
            }
        }
    }
    
    return directContacts.allValues;
}

// The current identity service used with the contact manager
- (MXIdentityService*)identityService
{
    // For the moment, only use the one of the first session
    MXSession *mxSession = [mxSessionArray firstObject];
    return mxSession.identityService;
}

- (BOOL)isUsersDiscoveringEnabled
{
    // Check whether the 3pid lookup is available
    return (self.discoverUsersBoundTo3PIDsBlock || self.identityService);
}

#pragma mark -

- (void)validateSyncLocalContactsStateForSession:(MXSession *)mxSession
{
    if (!self.allowLocalContactsAccess)
    {
        return;
    }
    
    // Get the status of the identity service terms.
    BOOL areAllTermsAgreed = mxSession.identityService.areAllTermsAgreed;
    
    if (MXKAppSettings.standardAppSettings.syncLocalContacts)
    {
        // Disable local contact sync when all terms are no longer accepted or if contacts access has been revoked.
        if (!areAllTermsAgreed || [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts] != CNAuthorizationStatusAuthorized)
        {
            MXLogDebug(@"[MXKContactManager] validateSyncLocalContactsState : Disabling contacts sync.");
            MXKAppSettings.standardAppSettings.syncLocalContacts = false;
            return;
        }
    }
    else
    {
        // Check whether the user has been directed to the Settings app to enable contact access.
        if (MXKAppSettings.standardAppSettings.syncLocalContactsPermissionOpenedSystemSettings)
        {
            // Reset the system settings app flag as they are back in the app.
            MXKAppSettings.standardAppSettings.syncLocalContactsPermissionOpenedSystemSettings = false;
            
            // And if all other conditions are met for contacts sync enable it.
            if (areAllTermsAgreed && [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts] == CNAuthorizationStatusAuthorized)
            {
                MXLogDebug(@"[MXKContactManager] validateSyncLocalContactsState : Enabling contacts sync after user visited Settings app.");
                MXKAppSettings.standardAppSettings.syncLocalContacts = true;
            }
        }
    }
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (void)refreshLocalContacts
{
    MXLogDebug(@"[MXKContactManager] refreshLocalContacts : Started");
    
    if (!self.allowLocalContactsAccess)
    {
        MXLogDebug(@"[MXKContactManager] refreshLocalContacts : Finished because local contacts access not allowed.");
        return;
    }
    
    NSDate *startDate = [NSDate date];
    
    if ([CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts] != CNAuthorizationStatusAuthorized)
    {
        if ([MXKAppSettings standardAppSettings].syncLocalContacts)
        {
            // The user authorised syncLocalContacts and allowed access to his contacts
            // but he then removed contacts access from app permissions.
            // So, reset syncLocalContacts value
            [MXKAppSettings standardAppSettings].syncLocalContacts = NO;
        }
        
        // Local contacts list is empty if the access is denied.
        self->localContactByContactID = nil;
        self->localContactsWithMethods = nil;
        self->splitLocalContacts = nil;
        [self cacheLocalContacts];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerDidUpdateLocalContactsNotification object:nil userInfo:nil];
        
        MXLogDebug(@"[MXKContactManager] refreshLocalContacts : Complete");
        MXLogDebug(@"[MXKContactManager] refreshLocalContacts : Local contacts access denied");
    }
    else
    {
        self->isLocalContactListRefreshing = YES;
        
        // Reset the internal contact lists (These arrays will be prepared only if need).
        self->localContactsWithMethods = self->splitLocalContacts = nil;
        
        BOOL isColdStart = NO;
        
        // Check whether the local contacts sync has been disabled.
        if (self->sdnIDBy3PID && ![MXKAppSettings standardAppSettings].syncLocalContacts)
        {
            // The user changed his mind and disabled the local contact sync, remove the cached data.
            self->sdnIDBy3PID = nil;
            [self cacheSDNIDsDict];
            
            // Reload the local contacts from the system
            self->localContactByContactID = nil;
            [self cacheLocalContacts];
        }
        
        // Check whether this is a cold start.
        if (!self->sdnIDBy3PID)
        {
            isColdStart = YES;
            
            // Load the dictionary from the file system. It is cached to improve UX.
            [self loadCachedSDNIDsDict];
        }
        
        MXWeakify(self);
        
        dispatch_async(self->processingQueue, ^{
            
            MXStrongifyAndReturnIfNil(self);

            // In case of cold start, retrieve the data from the file system
            if (isColdStart)
            {
                [self loadCachedLocalContacts];
                [self loadCachedContactBookInfo];

                // no local contact -> assume that the last sync date is useless
                if (self->localContactByContactID.count == 0)
                {
                    self->lastSyncDate = nil;
                }
            }

            BOOL didContactBookChange = NO;

            NSMutableArray* deletedContactIDs = [NSMutableArray arrayWithArray:[self->localContactByContactID allKeys]];

            // can list local contacts?
            if (ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusAuthorized)
            {
                NSString* countryCode = [[MXKAppSettings standardAppSettings] phonebookCountryCode];

                ABAddressBookRef ab = ABAddressBookCreateWithOptions(nil, nil);
                ABRecordRef      contactRecord;
                CFIndex          index;
                CFMutableArrayRef people = (CFMutableArrayRef)ABAddressBookCopyArrayOfAllPeople(ab);

                if (nil != people)
                {
                    CFIndex peopleCount = CFArrayGetCount(people);

                    for (index = 0; index < peopleCount; index++)
                    {
                        contactRecord = (ABRecordRef)CFArrayGetValueAtIndex(people, index);

                        NSString* contactID = [MXKContact contactID:contactRecord];

                        // the contact still exists
                        [deletedContactIDs removeObject:contactID];

                        if (self->lastSyncDate)
                        {
                            // ignore unchanged contacts since the previous sync
                            CFDateRef lastModifDate = ABRecordCopyValue(contactRecord, kABPersonModificationDateProperty);
                            if (lastModifDate)
                            {
                                if (kCFCompareGreaterThan != CFDateCompare(lastModifDate, (__bridge CFDateRef)self->lastSyncDate, nil))

                                {
                                    CFRelease(lastModifDate);
                                    continue;
                                }
                                CFRelease(lastModifDate);
                            }
                        }

                        didContactBookChange = YES;

                        MXKContact* contact = [[MXKContact alloc] initLocalContactWithABRecord:contactRecord];

                        if (countryCode)
                        {
                            contact.defaultCountryCode = countryCode;
                        }

                        // update the local contacts list
                        [self->localContactByContactID setValue:contact forKey:contactID];
                    }

                    CFRelease(people);
                }

                if (ab)
                {
                    CFRelease(ab);
                }
            }

            // some contacts have been deleted
            for (NSString* contactID in deletedContactIDs)
            {
                didContactBookChange = YES;
                [self->localContactByContactID removeObjectForKey:contactID];
            }

            // something has been modified in the local contact book
            if (didContactBookChange)
            {
                [self cacheLocalContacts];
            }
            
            self->lastSyncDate = [NSDate date];
            [self cacheContactBookInfo];
            
            // Update loaded contacts with the known dict 3PID -> sdn ID
            [self updateAllLocalContactsSDNIDs];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                // Contacts are loaded, post a notification
                self->isLocalContactListRefreshing = NO;
                [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerDidUpdateLocalContactsNotification object:nil userInfo:nil];
                
                // Check the conditions required before triggering a sdn users lookup.
                if (isColdStart || didContactBookChange)
                {
                    [self updateSDNIDsForAllLocalContacts];
                }
                
                MXLogDebug(@"[MXKContactManager] refreshLocalContacts : Complete");
                MXLogDebug(@"[MXKContactManager] refreshLocalContacts : Refresh %tu local contacts in %.0fms", self->localContactByContactID.count, [[NSDate date] timeIntervalSinceDate:startDate] * 1000);
            });
        });
    }
}
#pragma clang diagnostic pop

- (void)updateSDNIDsForLocalContact:(MXKContact *)contact
{
    // Check if the user allowed to sync local contacts.
    // + Check whether users discovering is available.
    if ([MXKAppSettings standardAppSettings].syncLocalContacts && !contact.isSDNContact && [self isUsersDiscoveringEnabled])
    {
        // Retrieve all 3PIDs of the contact
        NSMutableArray* threepids = [[NSMutableArray alloc] init];
        NSMutableArray* lookup3pidsArray = [[NSMutableArray alloc] init];
        
        for (MXKEmail* email in contact.emailAddresses)
        {
            // Not yet added
            if (email.emailAddress.length && [threepids indexOfObject:email.emailAddress] == NSNotFound)
            {
                [lookup3pidsArray addObject:@[kMX3PIDMediumEmail, email.emailAddress]];
                [threepids addObject:email.emailAddress];
            }
        }
        
        for (MXKPhoneNumber* phone in contact.phoneNumbers)
        {
            if (phone.msisdn)
            {
                [lookup3pidsArray addObject:@[kMX3PIDMediumMSISDN, phone.msisdn]];
                [threepids addObject:phone.msisdn];
            }
        }
        
        if (lookup3pidsArray.count > 0)
        {
            MXWeakify(self);
            
            void (^success)(NSArray<NSArray<NSString *> *> *) = ^(NSArray<NSArray<NSString *> *> *discoveredUsers) {
                MXStrongifyAndReturnIfNil(self);
                
                // Look for updates
                BOOL isUpdated = NO;
                
                // Consider each discored user
                for (NSArray *discoveredUser in discoveredUsers)
                {
                    // Sanity check
                    if (discoveredUser.count == 3)
                    {
                        NSString *pid = discoveredUser[1];
                        NSString *sdnId = discoveredUser[2];
                        
                        // Remove the 3pid from the requested list
                        [threepids removeObject:pid];
                        
                        NSString *currentSDNID = [self->sdnIDBy3PID objectForKey:pid];
                        
                        if (![currentSDNID isEqualToString:sdnId])
                        {
                            [self->sdnIDBy3PID setObject:sdnId forKey:pid];
                            isUpdated = YES;
                        }
                    }
                }
                
                // Remove existing information which is not valid anymore
                for (NSString *pid in threepids)
                {
                    if ([self->sdnIDBy3PID objectForKey:pid])
                    {
                        [self->sdnIDBy3PID removeObjectForKey:pid];
                        isUpdated = YES;
                    }
                }
                
                if (isUpdated)
                {
                    [self cacheSDNIDsDict];
                    
                    // Update only this contact
                    [self updateLocalContactSDNIDs:contact];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerDidUpdateLocalContactSDNIDsNotification object:contact.contactID userInfo:nil];
                    });
                }
            };
            
            void (^failure)(NSError *) = ^(NSError *error) {
                MXLogDebug(@"[MXKContactManager] updateSDNIDsForLocalContact failed");
            };
            
            if (self.discoverUsersBoundTo3PIDsBlock)
            {
                self.discoverUsersBoundTo3PIDsBlock(lookup3pidsArray, success, failure);
            }
            else
            {
                // Consider the potential identity server url by default
                [self.identityService lookup3pids:lookup3pidsArray
                                          success:success
                                          failure:failure];
            }
        }
    }
}


- (void)updateSDNIDsForAllLocalContacts
{
    // If localContactByContactID is not loaded, the manager will consider there is no local contacts
    // and will reset its cache
    NSAssert(localContactByContactID, @"[MXKContactManager] updateSDNIDsForAllLocalContacts: refreshLocalContacts must be called before");

    // Check if the user allowed to sync local contacts.
    // + Check if at least an identity server is available, and if the loading step is not in progress.
    if (![MXKAppSettings standardAppSettings].syncLocalContacts || ![self isUsersDiscoveringEnabled] || isLocalContactListRefreshing)
    {
        return;
    }
    
    MXWeakify(self);
    
    // Refresh the 3PIDs -> SDN ID mapping
    dispatch_async(processingQueue, ^{
        
        MXStrongifyAndReturnIfNil(self);
        
        NSArray* contactsSnapshot = [self->localContactByContactID allValues];
        
        // Retrieve all 3PIDs
        NSMutableArray* threepids = [[NSMutableArray alloc] init];
        NSMutableArray* lookup3pidsArray = [[NSMutableArray alloc] init];
        
        for (MXKContact* contact in contactsSnapshot)
        {
            for (MXKEmail* email in contact.emailAddresses)
            {
                // Not yet added
                if (email.emailAddress.length && [threepids indexOfObject:email.emailAddress] == NSNotFound)
                {
                    [lookup3pidsArray addObject:@[kMX3PIDMediumEmail, email.emailAddress]];
                    [threepids addObject:email.emailAddress];
                }
            }
            
            for (MXKPhoneNumber* phone in contact.phoneNumbers)
            {
                if (phone.msisdn)
                {
                    // Not yet added
                    if ([threepids indexOfObject:phone.msisdn] == NSNotFound)
                    {
                        [lookup3pidsArray addObject:@[kMX3PIDMediumMSISDN, phone.msisdn]];
                        [threepids addObject:phone.msisdn];
                    }
                }
            }
        }
        
        // Update 3PIDs mapping
        if (lookup3pidsArray.count > 0)
        {
            MXWeakify(self);
            
            void (^success)(NSArray<NSArray<NSString *> *> *) = ^(NSArray<NSArray<NSString *> *> *discoveredUsers) {
                MXStrongifyAndReturnIfNil(self);
                
                [threepids removeAllObjects];
                NSMutableArray* userIds = [[NSMutableArray alloc] init];
                
                // Consider each discored user
                for (NSArray *discoveredUser in discoveredUsers)
                {
                    // Sanity check
                    if (discoveredUser.count == 3)
                    {
                        id threepid = discoveredUser[1];
                        id userId = discoveredUser[2];
                        
                        if ([threepid isKindOfClass:[NSString class]] && [userId isKindOfClass:[NSString class]])
                        {
                            [threepids addObject:threepid];
                            [userIds addObject:userId];
                        }
                    }
                }
                
                if (userIds.count)
                {
                    self->sdnIDBy3PID = [[NSMutableDictionary alloc] initWithObjects:userIds forKeys:threepids];
                }
                else
                {
                    self->sdnIDBy3PID = nil;
                }
                
                [self cacheSDNIDsDict];
                
                [self updateAllLocalContactsSDNIDs];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerDidUpdateLocalContactSDNIDsNotification object:nil userInfo:nil];
                });
            };
            
            void (^failure)(NSError *) = ^(NSError *error) {
                MXLogDebug(@"[MXKContactManager] updateSDNIDsForAllLocalContacts failed");
            };
            
            if (self.discoverUsersBoundTo3PIDsBlock)
            {
                self.discoverUsersBoundTo3PIDsBlock(lookup3pidsArray, success, failure);
            }
            else if (self.identityService)
            {
                [self.identityService lookup3pids:lookup3pidsArray
                                          success:success
                                          failure:failure];
            }
            else
            {
                // No IS, no detection of SDN users in local contacts
                self->sdnIDBy3PID = nil;
                [self cacheSDNIDsDict];
            }
        }
        else
        {
            self->sdnIDBy3PID = nil;
            [self cacheSDNIDsDict];
        }
    });
}

- (void)resetSDNIDs
{
    dispatch_async(processingQueue, ^{
        
        self->sdnIDBy3PID = nil;
        [self cacheSDNIDsDict];

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerDidUpdateLocalContactSDNIDsNotification object:nil userInfo:nil];
        });
    });
}

- (void)reset
{
    sdnIDBy3PID = nil;
    [self cacheSDNIDsDict];
    
    isLocalContactListRefreshing = NO;
    localContactByContactID = nil;
    localContactsWithMethods = nil;
    splitLocalContacts = nil;
    [self cacheLocalContacts];
    
    sdnContactByContactID = nil;
    sdnContactBySDNID = nil;
    [self cacheSDNContacts];
    
    lastSyncDate = nil;
    [self cacheContactBookInfo];
    
    while (mxSessionArray.count) {
        [self removeSDNSession:mxSessionArray.lastObject];
    }
    mxSessionArray = nil;
    mxEventListeners = nil;
    
    // warn of the contacts list update
    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerDidUpdateSDNContactsNotification object:nil userInfo:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerDidUpdateLocalContactsNotification object:nil userInfo:nil];
}

- (MXKContact*)contactWithContactID:(NSString*)contactID
{
    if ([contactID hasPrefix:kMXKContactLocalContactPrefixId])
    {
        return [localContactByContactID objectForKey:contactID];
    }
    else
    {
        return [sdnContactByContactID objectForKey:contactID];
    }
}

// refresh the international phonenumber of the contacts
- (void)internationalizePhoneNumbers:(NSString*)countryCode
{
    MXWeakify(self);
    
    dispatch_async(processingQueue, ^{
        
        MXStrongifyAndReturnIfNil(self);
        
        NSArray* contactsSnapshot = [self->localContactByContactID allValues];
        
        for (MXKContact* contact in contactsSnapshot)
        {
            contact.defaultCountryCode = countryCode;
        }
        
        [self cacheLocalContacts];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerDidInternationalizeNotification object:nil userInfo:nil];
        });
    });
}

- (MXKSectionedContacts *)getSectionedContacts:(NSArray*)contactsList
{
    if (!contactsList.count)
    {
        return nil;
    }
    
    UILocalizedIndexedCollation *collation = [UILocalizedIndexedCollation currentCollation];
    
    int indexOffset = 0;
    
    NSInteger index, sectionTitlesCount = [[collation sectionTitles] count];
    NSMutableArray *tmpSectionsArray = [[NSMutableArray alloc] initWithCapacity:(sectionTitlesCount)];
    
    sectionTitlesCount += indexOffset;
    
    for (index = 0; index < sectionTitlesCount; index++)
    {
        NSMutableArray *array = [[NSMutableArray alloc] init];
        [tmpSectionsArray addObject:array];
    }
    
    int contactsCount = 0;
    
    for (MXKContact *aContact in contactsList)
    {
        NSInteger section = [collation sectionForObject:aContact collationStringSelector:@selector(displayName)] + indexOffset;
        
        [[tmpSectionsArray objectAtIndex:section] addObject:aContact];
        ++contactsCount;
    }
    
    NSMutableArray *tmpSectionedContactsTitle = [[NSMutableArray alloc] initWithCapacity:sectionTitlesCount];
    NSMutableArray *shortSectionsArray = [[NSMutableArray alloc] initWithCapacity:sectionTitlesCount];
    
    for (index = indexOffset; index < sectionTitlesCount; index++)
    {
        NSMutableArray *usersArrayForSection = [tmpSectionsArray objectAtIndex:index];
        
        if ([usersArrayForSection count] != 0)
        {
            NSArray* sortedUsersArrayForSection = [collation sortedArrayFromArray:usersArrayForSection collationStringSelector:@selector(displayName)];
            [shortSectionsArray addObject:sortedUsersArrayForSection];
            [tmpSectionedContactsTitle addObject:[[[UILocalizedIndexedCollation currentCollation] sectionTitles] objectAtIndex:(index - indexOffset)]];
        }
    }
    
    return [[MXKSectionedContacts alloc] initWithContacts:shortSectionsArray andTitles:tmpSectionedContactsTitle andCount:contactsCount];
}

- (void)sortAlphabeticallyContacts:(NSMutableArray<MXKContact*> *)contactsArray
{
    NSComparator comparator = ^NSComparisonResult(MXKContact *contactA, MXKContact *contactB) {
        
        if (contactA.sortingDisplayName.length && contactB.sortingDisplayName.length)
        {
            return [contactA.sortingDisplayName compare:contactB.sortingDisplayName options:NSCaseInsensitiveSearch];
        }
        else if (contactA.sortingDisplayName.length)
        {
            return NSOrderedAscending;
        }
        else if (contactB.sortingDisplayName.length)
        {
            return NSOrderedDescending;
        }
        return [contactA.displayName compare:contactB.displayName options:NSCaseInsensitiveSearch];
    };
    
    // Sort the contacts list
    [contactsArray sortUsingComparator:comparator];
}

- (void)sortContactsByLastActiveInformation:(NSMutableArray<MXKContact*> *)contactsArray
{
    // Sort invitable contacts by last active, with "active now" first.
    // ...and then alphabetically.
    NSComparator comparator = ^NSComparisonResult(MXKContact *contactA, MXKContact *contactB) {
        
        MXUser *userA = [self firstSDNUserOfContact:contactA];
        MXUser *userB = [self firstSDNUserOfContact:contactB];
        
        // Non-SDN-enabled contacts are moved to the end.
        if (userA && !userB)
        {
            return NSOrderedAscending;
        }
        if (!userA && userB)
        {
            return NSOrderedDescending;
        }
        
        // Display active contacts first.
        if (userA.currentlyActive && userB.currentlyActive)
        {
            // Then order by name
            if (contactA.sortingDisplayName.length && contactB.sortingDisplayName.length)
            {
                return [contactA.sortingDisplayName compare:contactB.sortingDisplayName options:NSCaseInsensitiveSearch];
            }
            else if (contactA.sortingDisplayName.length)
            {
                return NSOrderedAscending;
            }
            else if (contactB.sortingDisplayName.length)
            {
                return NSOrderedDescending;
            }
            return [contactA.displayName compare:contactB.displayName options:NSCaseInsensitiveSearch];
        }
        
        if (userA.currentlyActive && !userB.currentlyActive)
        {
            return NSOrderedAscending;
        }
        if (!userA.currentlyActive && userB.currentlyActive)
        {
            return NSOrderedDescending;
        }
        
        // Finally, compare the lastActiveAgo
        NSUInteger lastActiveAgoA = userA.lastActiveAgo;
        NSUInteger lastActiveAgoB = userB.lastActiveAgo;
        
        if (lastActiveAgoA == lastActiveAgoB)
        {
            return NSOrderedSame;
        }
        else
        {
            return ((lastActiveAgoA > lastActiveAgoB) ? NSOrderedDescending : NSOrderedAscending);
        }
    };
    
    // Sort the contacts list
    [contactsArray sortUsingComparator:comparator];
}

+ (void)requestUserConfirmationForLocalContactsSyncInViewController:(UIViewController *)viewController completionHandler:(void (^)(BOOL))handler
{
    NSString *appDisplayName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];

    [MXKContactManager requestUserConfirmationForLocalContactsSyncWithTitle:[VectorL10n localContactsAccessDiscoveryWarningTitle]
                                                                    message:[VectorL10n localContactsAccessDiscoveryWarning:appDisplayName]
                                                manualPermissionChangeMessage:[VectorL10n localContactsAccessNotGranted:appDisplayName]
                                                    showPopUpInViewController:viewController
                                                            completionHandler:handler];
}

+ (void)requestUserConfirmationForLocalContactsSyncWithTitle:(NSString*)title
                                                     message:(NSString*)message
                                           manualPermissionChangeMessage:(NSString*)manualPermissionChangeMessage
                                     showPopUpInViewController:(UIViewController*)viewController
                                             completionHandler:(void (^)(BOOL granted))handler
{
    if ([[MXKAppSettings standardAppSettings] syncLocalContacts])
    {
        handler(YES);
    }
    else
    {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addAction:[UIAlertAction actionWithTitle:[VectorL10n ok]
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction * action) {
                                                    
                                                    [MXKTools checkAccessForContacts:manualPermissionChangeMessage showPopUpInViewController:viewController completionHandler:^(BOOL granted) {
                                                        
                                                        handler(granted);
                                                    }];
                                                    
                                                }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:[VectorL10n cancel]
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction * action) {
                                                    
                                                    handler(NO);
                                                    
                                                }]];
        
        
        [viewController presentViewController:alert animated:YES completion:nil];
    }
}

#pragma mark - Internals

- (NSDictionary*)sdnContactsBySDNIDFromMXSessions:(NSArray<MXSession*>*)mxSessions
{
    // The existing dictionary of contacts will be replaced by this one
    NSMutableDictionary *sdnContactBySDNID = [[NSMutableDictionary alloc] init];
    for (MXSession *mxSession in mxSessions)
    {
        // Check all existing users
        NSArray *mxUsers = [mxSession.users copy];
        
        for (MXUser *user in mxUsers)
        {
            // Check whether this user has already been added
            if (!sdnContactBySDNID[user.userId])
            {
                if ((self.contactManagerMXRoomSource == MXKContactManagerMXRoomSourceAll) || ((self.contactManagerMXRoomSource == MXKContactManagerMXRoomSourceDirectChats) && mxSession.directRooms[user.userId]))
                {
                    // Check whether a contact is already defined for this id in previous dictionary
                    // (avoid delete and create the same ones, it could save thumbnail downloads).
                    MXKContact* contact = sdnContactBySDNID[user.userId];
                    if (contact)
                    {
                        contact.displayName = (user.displayname.length > 0) ? user.displayname : user.userId;
                        
                        // Check the avatar change
                        if ((user.avatarUrl || contact.sdnAvatarURL) && ([user.avatarUrl isEqualToString:contact.sdnAvatarURL] == NO))
                        {
                            [contact resetSDNThumbnail];
                        }
                    }
                    else
                    {
                        contact = [[MXKContact alloc] initSDNContactWithDisplayName:((user.displayname.length > 0) ? user.displayname : user.userId) andSDNID:user.userId];
                    }
                    
                    sdnContactBySDNID[user.userId] = contact;
                }
            }
        }
    }
    
    // Do not make an immutable copy to avoid performance penalty
    return sdnContactBySDNID;
}

- (void)refreshSDNContacts
{
    NSArray *mxSessions = self.mxSessions;

    // Check whether at least one session is available
    if (!mxSessions.count)
    {
        sdnContactBySDNID = nil;
        sdnContactByContactID = nil;
        [self cacheSDNContacts];

        [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerDidUpdateSDNContactsNotification object:nil userInfo:nil];
    }
    else if (self.contactManagerMXRoomSource != MXKContactManagerMXRoomSourceNone)
    {
        MXWeakify(self);

        BOOL shouldFetchLocalContacts = self->sdnContactByContactID == nil;
        
        dispatch_async(processingQueue, ^{

            MXStrongifyAndReturnIfNil(self);
            
            NSArray *sessions = self.mxSessions;

            NSMutableDictionary *sdnContactsBySDNID = nil;
            NSMutableDictionary *sdnContactsByContactID = nil;

            if (shouldFetchLocalContacts)
            {
                NSDictionary *cachedSDNContacts = [self fetchCachedSDNContacts];

                if (!sdnContactsByContactID)
                {
                    sdnContactsByContactID = [NSMutableDictionary dictionary];
                }
                else
                {
                    sdnContactsByContactID = [cachedSDNContacts mutableCopy];
                }
            }
            else
            {
                sdnContactsByContactID = [NSMutableDictionary dictionary];
            }

            NSDictionary *sdnContacts = [self sdnContactsBySDNIDFromMXSessions:sessions];

            if (!sdnContacts)
            {
                sdnContactsBySDNID = [NSMutableDictionary dictionary];
                
                for (MXKContact *contact in sdnContactsByContactID.allValues)
                {
                    sdnContactsBySDNID[contact.sdnIdentifiers.firstObject] = contact;
                }
            }
            else
            {
                sdnContactsBySDNID = [sdnContacts mutableCopy];
            }

            for (MXKContact *contact in sdnContactsBySDNID.allValues)
            {
                sdnContactsByContactID[contact.contactID] = contact;
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                MXStrongifyAndReturnIfNil(self);

                // Update the sdn contacts list
                self->sdnContactBySDNID = sdnContactsBySDNID;
                self->sdnContactByContactID = sdnContactsByContactID;

                [self cacheSDNContacts];

                [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerDidUpdateSDNContactsNotification object:nil userInfo:nil];
            });
        });
    }
}

- (void)updateSDNContactWithID:(NSString*)sdnId
{
    // Check if a one-to-one room exist for this sdn user in at least one sdn session.
    NSArray *mxSessions = self.mxSessions;
    for (MXSession *mxSession in mxSessions)
    {
        if ((self.contactManagerMXRoomSource == MXKContactManagerMXRoomSourceAll) || ((self.contactManagerMXRoomSource == MXKContactManagerMXRoomSourceDirectChats) && mxSession.directRooms[sdnId]))
        {
            // Retrieve the user object related to this contact
            MXUser* user = [mxSession userWithUserId:sdnId];
            
            // This user may not exist (if the oneToOne room is a pending invitation to him).
            if (user)
            {
                // Update or create a contact for this user
                MXKContact* contact = [sdnContactBySDNID objectForKey:sdnId];
                BOOL isUpdated = NO;
                
                // already defined
                if (contact)
                {
                    // Check the display name change
                    NSString *userDisplayName = (user.displayname.length > 0) ? user.displayname : user.userId;
                    if (![contact.displayName isEqualToString:userDisplayName])
                    {
                        contact.displayName = userDisplayName;
                        
                        [self cacheSDNContacts];
                        isUpdated = YES;
                    }
                    
                    // Check the avatar change
                    if ((user.avatarUrl || contact.sdnAvatarURL) && ([user.avatarUrl isEqualToString:contact.sdnAvatarURL] == NO))
                    {
                        [contact resetSDNThumbnail];
                        isUpdated = YES;
                    }
                }
                else
                {
                    contact = [[MXKContact alloc] initSDNContactWithDisplayName:((user.displayname.length > 0) ? user.displayname : user.userId) andSDNID:user.userId];
                    [sdnContactBySDNID setValue:contact forKey:sdnId];
                    
                    // update the sdn contacts list
                    [sdnContactByContactID setValue:contact forKey:contact.contactID];
                    
                    [self cacheSDNContacts];
                    isUpdated = YES;
                }
                
                if (isUpdated)
                {
                    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerDidUpdateSDNContactsNotification object:contact.contactID userInfo:nil];
                }
                
                // Done
                return;
            }
        }
    }
    
    // Here no one-to-one room exist, remove the contact if any
    MXKContact* contact = [sdnContactBySDNID objectForKey:sdnId];
    if (contact)
    {
        [sdnContactByContactID removeObjectForKey:contact.contactID];
        [sdnContactBySDNID removeObjectForKey:sdnId];
        
        [self cacheSDNContacts];
        [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerDidUpdateSDNContactsNotification object:contact.contactID userInfo:nil];
    }
}

- (void)updateLocalContactSDNIDs:(MXKContact*) contact
{
    for (MXKPhoneNumber* phoneNumber in contact.phoneNumbers)
    {
        if (phoneNumber.msisdn)
        {
            NSString* sdnID = [sdnIDBy3PID objectForKey:phoneNumber.msisdn];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [phoneNumber setSdnID:sdnID];
                
            });
        }
    }
    
    for (MXKEmail* email in contact.emailAddresses)
    {
        if (email.emailAddress.length > 0)
        {
            NSString *sdnID = [sdnIDBy3PID objectForKey:email.emailAddress];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [email setSdnID:sdnID];
                
            });
        }
    }
}

- (void)updateAllLocalContactsSDNIDs
{
    // Check if the user allowed to sync local contacts
    if (![MXKAppSettings standardAppSettings].syncLocalContacts)
    {
        return;
    }
    
    NSArray* localContacts = [localContactByContactID allValues];
    
    // update the contacts info
    for (MXKContact* contact in localContacts)
    {
        [self updateLocalContactSDNIDs:contact];
    }
}

- (MXUser*)firstSDNUserOfContact:(MXKContact*)contact;
{
    MXUser *user = nil;
    
    NSArray *identifiers = contact.sdnIdentifiers;
    if (identifiers.count)
    {
        for (MXSession *session in mxSessionArray)
        {
            user = [session userWithUserId:identifiers.firstObject];
            if (user)
            {
                break;
            }
        }
    }
    
    return user;
}


#pragma mark - Identity server updates

- (void)registerAccountDataDidChangeIdentityServerNotification
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAccountDataDidChangeIdentityServerNotification:) name:kMXSessionAccountDataDidChangeIdentityServerNotification object:nil];
}

- (void)handleAccountDataDidChangeIdentityServerNotification:(NSNotification*)notification
{
    MXLogDebug(@"[MXKContactManager] handleAccountDataDidChangeIdentityServerNotification");
    
    if (!self.allowLocalContactsAccess)
    {
        MXLogDebug(@"[MXKContactManager] handleAccountDataDidChangeIdentityServerNotification. Does nothing because local contacts access not allowed.");
        return;
    }

    // Use the identity server of the up
    MXSession *mxSession = notification.object;
    if (mxSession != mxSessionArray.firstObject)
    {
        return;
    }

    if (self.identityService)
    {
        // Do a full lookup
        // But check first if the data is loaded
        if (!self->localContactByContactID )
        {
            // Load data. That will trigger updateSDNIDsForAllLocalContacts if needed
            [self refreshLocalContacts];
        }
        else
        {
            [self updateSDNIDsForAllLocalContacts];
        }
    }
    else
    {
        [self resetSDNIDs];
    }
}


#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (!self.allowLocalContactsAccess)
    {
        MXLogDebug(@"[MXKContactManager] Ignoring KVO changes, because local contacts access not allowed.");
        return;
    }
    
    if ([@"syncLocalContacts" isEqualToString:keyPath])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [self refreshLocalContacts];
            
        });
    }
    else if ([@"phonebookCountryCode" isEqualToString:keyPath])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [self internationalizePhoneNumbers:[[MXKAppSettings standardAppSettings] phonebookCountryCode]];
            
            // Refresh local contacts if we have some
            if (MXKAppSettings.standardAppSettings.syncLocalContacts && self->localContactByContactID.count)
            {
                [self refreshLocalContacts];
            }
            
        });
    }
}

#pragma mark - file caches

static NSString *MXKContactManagerDomain = @"org.sdn.SDNKit.MXKContactManager";
static NSInteger MXContactManagerEncryptionDelegateNotReady = -1;

static NSString *sdnContactsFileOld = @"sdnContacts";
static NSString *sdnIDsDictFileOld = @"sdnIDsDict";
static NSString *localContactsFileOld = @"localContacts";
static NSString *contactsBookInfoFileOld = @"contacts";

static NSString *sdnContactsFile = @"sdnContactsV2";
static NSString *sdnIDsDictFile = @"sdnIDsDictV2";
static NSString *localContactsFile = @"localContactsV2";
static NSString *contactsBookInfoFile = @"contactsV2";

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

- (NSString*)dataFilePathForComponent:(NSString*)component
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return [documentsDirectory stringByAppendingPathComponent:component];
}

- (void)cacheSDNContacts
{
    NSString *dataFilePath = [self dataFilePathForComponent:sdnContactsFile];
    
    if (sdnContactByContactID && (sdnContactByContactID.count > 0))
    {
        // Switch on processing queue because sdnContactByContactID dictionary may be huge.
        NSDictionary *sdnContactByContactIDCpy = [sdnContactByContactID copy];
        
        dispatch_async(processingQueue, ^{
            
            NSMutableData *theData = [NSMutableData data];
            NSKeyedArchiver *encoder = [[NSKeyedArchiver alloc] initForWritingWithMutableData:theData];
            
            [encoder encodeObject:sdnContactByContactIDCpy forKey:@"sdnContactByContactID"];
            
            [encoder finishEncoding];
            
            [self encryptAndSaveData:theData toFile:sdnContactsFile];
        });
    }
    else
    {
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        [fileManager removeItemAtPath:dataFilePath error:nil];
    }
}

- (NSDictionary*)fetchCachedSDNContacts
{
    NSDate *startDate = [NSDate date];
    
    NSString *dataFilePath = [self dataFilePathForComponent:sdnContactsFile];
    
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    
    __block NSDictionary *sdnContactByContactID = nil;
    
    if ([fileManager fileExistsAtPath:dataFilePath])
    {
        @try
        {
            NSData* filecontent = [NSData dataWithContentsOfFile:dataFilePath options:(NSDataReadingMappedAlways | NSDataReadingUncached) error:nil];
            
            NSError *error = nil;
            filecontent = [self decryptData:filecontent error:&error fileName:sdnContactsFile];

            if (!error)
            {
                NSKeyedUnarchiver *decoder = [[NSKeyedUnarchiver alloc] initForReadingWithData:filecontent];
                
                id object = [decoder decodeObjectForKey:@"sdnContactByContactID"];
                
                if ([object isKindOfClass:[NSDictionary class]])
                {
                    sdnContactByContactID = object;
                }
                
                [decoder finishDecoding];
            }
            else
            {
                MXLogDebug(@"[MXKContactManager] fetchCachedSDNContacts: failed to decrypt %@: %@", sdnContactsFile, error);
            }
        }
        @catch (NSException *exception)
        {
        }
    }
    
    MXLogDebug(@"[MXKContactManager] fetchCachedSDNContacts : Loaded %tu contacts in %.0fms", sdnContactByContactID.count, [[NSDate date] timeIntervalSinceDate:startDate] * 1000);
    
    return sdnContactByContactID;
}

- (void)cacheSDNIDsDict
{
    NSString *dataFilePath = [self dataFilePathForComponent:sdnIDsDictFile];
    
    if (sdnIDBy3PID.count)
    {
        NSMutableData *theData = [NSMutableData data];
        NSKeyedArchiver *encoder = [[NSKeyedArchiver alloc] initForWritingWithMutableData:theData];
        
        [encoder encodeObject:sdnIDBy3PID forKey:@"sdnIDsDict"];
        [encoder finishEncoding];
        
        [self encryptAndSaveData:theData toFile:sdnIDsDictFile];
    }
    else
    {
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        [fileManager removeItemAtPath:dataFilePath error:nil];
    }
}

- (void)loadCachedSDNIDsDict
{
    NSString *dataFilePath = [self dataFilePathForComponent:sdnIDsDictFile];
    
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    
    if ([fileManager fileExistsAtPath:dataFilePath])
    {
        // the file content could be corrupted
        @try
        {
            NSData* filecontent = [NSData dataWithContentsOfFile:dataFilePath options:(NSDataReadingMappedAlways | NSDataReadingUncached) error:nil];
            
            NSError *error = nil;
            filecontent = [self decryptData:filecontent error:&error fileName:sdnIDsDictFile];

            if (!error)
            {
                NSKeyedUnarchiver *decoder = [[NSKeyedUnarchiver alloc] initForReadingWithData:filecontent];
                
                id object = [decoder decodeObjectForKey:@"sdnIDsDict"];
                
                if ([object isKindOfClass:[NSDictionary class]])
                {
                    sdnIDBy3PID = [object mutableCopy];
                }
                
                [decoder finishDecoding];
            }
            else
            {
                MXLogDebug(@"[MXKContactManager] loadCachedSDNIDsDict: failed to decrypt %@: %@", sdnIDsDictFile, error);
            }
        }
        @catch (NSException *exception)
        {
        }
    }
    
    if (!sdnIDBy3PID)
    {
        sdnIDBy3PID = [[NSMutableDictionary alloc] init];
    }
}

- (void)cacheLocalContacts
{
    NSString *dataFilePath = [self dataFilePathForComponent:localContactsFile];
    
    if (localContactByContactID && (localContactByContactID.count > 0))
    {
        NSMutableData *theData = [NSMutableData data];
        NSKeyedArchiver *encoder = [[NSKeyedArchiver alloc] initForWritingWithMutableData:theData];
        
        [encoder encodeObject:localContactByContactID forKey:@"localContactByContactID"];
        
        [encoder finishEncoding];
        
        [self encryptAndSaveData:theData toFile:localContactsFile];
    }
    else
    {
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        [fileManager removeItemAtPath:dataFilePath error:nil];
    }
}

- (void)loadCachedLocalContacts
{
    NSString *dataFilePath = [self dataFilePathForComponent:localContactsFile];
    
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    
    if ([fileManager fileExistsAtPath:dataFilePath])
    {
        // the file content could be corrupted
        @try
        {
            NSData* filecontent = [NSData dataWithContentsOfFile:dataFilePath options:(NSDataReadingMappedAlways | NSDataReadingUncached) error:nil];
            
            NSError *error = nil;
            filecontent = [self decryptData:filecontent error:&error fileName:localContactsFile];

            if (!error)
            {
                NSKeyedUnarchiver *decoder = [[NSKeyedUnarchiver alloc] initForReadingWithData:filecontent];
                
                id object = [decoder decodeObjectForKey:@"localContactByContactID"];
                
                if ([object isKindOfClass:[NSDictionary class]])
                {
                    localContactByContactID = [object mutableCopy];
                }
                
                [decoder finishDecoding];
            }
            else
            {
                MXLogDebug(@"[MXKContactManager] loadCachedLocalContacts: failed to decrypt %@: %@", localContactsFile, error);
            }
        }
        @catch (NSException *exception)
        {
            lastSyncDate = nil;
        }
    }
    
    if (!localContactByContactID)
    {
        localContactByContactID = [[NSMutableDictionary alloc] init];
    }
}

- (void)cacheContactBookInfo
{
    NSString *dataFilePath = [self dataFilePathForComponent:contactsBookInfoFile];
    
    if (lastSyncDate)
    {
        NSMutableData *theData = [NSMutableData data];
        NSKeyedArchiver *encoder = [[NSKeyedArchiver alloc] initForWritingWithMutableData:theData];
        
        [encoder encodeObject:lastSyncDate forKey:@"lastSyncDate"];
        
        [encoder finishEncoding];
        
        [self encryptAndSaveData:theData toFile:contactsBookInfoFile];
    }
    else
    {
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        [fileManager removeItemAtPath:dataFilePath error:nil];
    }
}

- (void)loadCachedContactBookInfo
{
    NSString *dataFilePath = [self dataFilePathForComponent:contactsBookInfoFile];
    
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    
    if ([fileManager fileExistsAtPath:dataFilePath])
    {
        // the file content could be corrupted
        @try
        {
            NSData* filecontent = [NSData dataWithContentsOfFile:dataFilePath options:(NSDataReadingMappedAlways | NSDataReadingUncached) error:nil];
            
            NSError *error = nil;
            filecontent = [self decryptData:filecontent error:&error fileName:contactsBookInfoFile];

            if (!error)
            {
                NSKeyedUnarchiver *decoder = [[NSKeyedUnarchiver alloc] initForReadingWithData:filecontent];
                
                lastSyncDate = [decoder decodeObjectForKey:@"lastSyncDate"];
                
                [decoder finishDecoding];
            }
            else
            {
                lastSyncDate = nil;
                MXLogDebug(@"[MXKContactManager] loadCachedContactBookInfo: failed to decrypt %@: %@", contactsBookInfoFile, error);
            }
        }
        @catch (NSException *exception)
        {
            lastSyncDate = nil;
        }
    }
}

#pragma clang diagnostic pop

- (BOOL)encryptAndSaveData:(NSData*)data toFile:(NSString*)fileName
{
    NSError *error = nil;
    NSData *cipher = [self encryptData:data error:&error fileName:fileName];

    if (error == nil)
    {
        [cipher writeToFile:[self dataFilePathForComponent:fileName] atomically:YES];
        [[NSFileManager defaultManager] excludeItemFromBackupAt:[NSURL fileURLWithPath:fileName] error:&error];
        if (error) {
            MXLogDebug(@"[MXKContactManager] Cannot exclude item from backup %@", error.localizedDescription);
        }
    }
    else
    {
        MXLogDebug(@"[MXKContactManager] encryptAndSaveData: failed to encrypt %@", fileName);
    }
    
    return error == nil;
}

- (NSData*)encryptData:(NSData*)data error:(NSError**)error fileName:(NSString*)fileName
{
    @try
    {
        MXKeyData *keyData = (MXKeyData *) [[MXKeyProvider sharedInstance] requestKeyForDataOfType:MXKContactManagerDataType isMandatory:NO expectedKeyType:kAes];
        if (keyData && [keyData isKindOfClass:[MXAesKeyData class]])
        {
            MXAesKeyData *aesKey = (MXAesKeyData *) keyData;
            NSData *cipher = [MXAes encrypt:data aesKey:aesKey.key iv:aesKey.iv error:error];
            MXLogDebug(@"[MXKContactManager] encryptData: encrypted %lu Bytes for %@", cipher.length, fileName);
            return cipher;
        }
    }
    @catch (NSException *exception)
    {
        *error = [NSError errorWithDomain:MXKContactManagerDomain code:MXContactManagerEncryptionDelegateNotReady userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"encryptData failed: %@", exception.reason]}];
    }
    
    MXLogDebug(@"[MXKContactManager] encryptData: no key method provided for encryption of %@", fileName);
    return data;
}

- (NSData*)decryptData:(NSData*)data error:(NSError**)error fileName:(NSString*)fileName
{
    @try
    {
        MXKeyData *keyData = [[MXKeyProvider sharedInstance] requestKeyForDataOfType:MXKContactManagerDataType isMandatory:NO expectedKeyType:kAes];
        if (keyData && [keyData isKindOfClass:[MXAesKeyData class]])
        {
            MXAesKeyData *aesKey = (MXAesKeyData *) keyData;
            NSData *decrypt = [MXAes decrypt:data aesKey:aesKey.key iv:aesKey.iv error:error];
            MXLogDebug(@"[MXKContactManager] decryptData: decrypted %lu Bytes for %@", decrypt.length, fileName);
            return decrypt;
        }
    }
    @catch (NSException *exception)
    {
        *error = [NSError errorWithDomain:MXKContactManagerDomain code:MXContactManagerEncryptionDelegateNotReady userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"decryptData failed: %@", exception.reason]}];
    }
    
    MXLogDebug(@"[MXKContactManager] decryptData: no key method provided for decryption of %@", fileName);
    return data;
}

- (void)deleteOldFiles {
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSArray<NSString*> *oldFileNames = @[sdnContactsFileOld, sdnIDsDictFileOld, localContactsFileOld, contactsBookInfoFileOld];
    NSError *error = nil;
    
    for (NSString *fileName in oldFileNames) {
        NSString *filePath = [self dataFilePathForComponent:fileName];
        if ([fileManager fileExistsAtPath:filePath])
        {
            error = nil;
            if (![fileManager removeItemAtPath:filePath error:&error])
            {
                MXLogDebug(@"[MXKContactManager] deleteOldFiles: failed to remove %@", fileName);
            }
        }
    }
}

@end
