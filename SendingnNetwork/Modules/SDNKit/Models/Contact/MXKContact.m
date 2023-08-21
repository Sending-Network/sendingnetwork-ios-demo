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

#import "MXKContact.h"

#import "MXKEmail.h"
#import "MXKPhoneNumber.h"

NSString *const kMXKContactThumbnailUpdateNotification = @"kMXKContactThumbnailUpdateNotification";

NSString *const kMXKContactLocalContactPrefixId = @"Local_";
NSString *const kMXKContactSDNContactPrefixId = @"SDN_";
NSString *const kMXKContactDefaultContactPrefixId = @"Default_";

@interface MXKContact()
{
    UIImage* contactThumbnail;
    UIImage* sdnThumbnail;
    
    // The sdn id of the contact (used when the contact is not defined in the contacts book)
    MXKContactField *sdnIdField;
}
@end

@implementation MXKContact
@synthesize isSDNContact, isThirdPartyInvite;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
+ (NSString*)contactID:(ABRecordRef)record
{
    return [NSString stringWithFormat:@"%@%d", kMXKContactLocalContactPrefixId, ABRecordGetRecordID(record)];
}

- (id)init
{
    self = [super init];
    if (self)
    {
        sdnIdField = nil;
        isSDNContact = NO;
        _sdnAvatarURL = nil;
        
        isThirdPartyInvite = NO;
    }
    
    return self;
}

- (id)initLocalContactWithABRecord:(ABRecordRef)record
{
    self = [self init];
    if (self)
    {
        // compute a contact ID
        _contactID = [MXKContact contactID:record];
        
        // use the contact book display name
        _displayName = (__bridge NSString*) ABRecordCopyCompositeName(record);
        
        // avoid nil display name
        // the display name is used to sort contacts
        if (!_displayName)
        {
            _displayName = @"";
        }
        
        // extract the phone numbers and their related label
        ABMultiValueRef multi = ABRecordCopyValue(record, kABPersonPhoneProperty);
        CFIndex        nCount = ABMultiValueGetCount(multi);
        NSMutableArray* pns = [[NSMutableArray alloc] initWithCapacity:nCount];
        
        for (int i = 0; i < nCount; i++)
        {
            CFTypeRef phoneRef = ABMultiValueCopyValueAtIndex(multi, i);
            NSString *phoneVal = (__bridge NSString*)phoneRef;
            
            // sanity check
            if (0 != [phoneVal length])
            {
                CFStringRef lblRef = ABMultiValueCopyLabelAtIndex(multi, i);
                CFStringRef localizedLblRef = nil;
                NSString *lbl =  @"";
                
                if (lblRef != nil)
                {
                    localizedLblRef = ABAddressBookCopyLocalizedLabel(lblRef);
                    if (localizedLblRef)
                    {
                        lbl = (__bridge NSString*)localizedLblRef;
                    }
                    else
                    {
                        lbl = (__bridge NSString*)lblRef;
                    }
                }
                else
                {
                    localizedLblRef = ABAddressBookCopyLocalizedLabel(kABOtherLabel);
                    if (localizedLblRef)
                    {
                        lbl = (__bridge NSString*)localizedLblRef;
                    }
                }
                
                [pns addObject:[[MXKPhoneNumber alloc] initWithTextNumber:phoneVal type:lbl contactID:_contactID sdnID:nil]];
                
                if (lblRef)
                {
                    CFRelease(lblRef);
                }
                if (localizedLblRef)
                {
                    CFRelease(localizedLblRef);
                }
            }
            
            // release meory
            if (phoneRef)
            {
                CFRelease(phoneRef);
            }
        }
        
        CFRelease(multi);
        _phoneNumbers = pns;
        
        // extract the emails
        multi = ABRecordCopyValue(record, kABPersonEmailProperty);
        nCount = ABMultiValueGetCount(multi);
        
        NSMutableArray *emails = [[NSMutableArray alloc] initWithCapacity:nCount];
        
        for (int i = 0; i < nCount; i++)
        {
            CFTypeRef emailValRef = ABMultiValueCopyValueAtIndex(multi, i);
            NSString *emailVal = (__bridge NSString*)emailValRef;
            
            // sanity check
            if ((nil != emailVal) && (0 != [emailVal length]))
            {
                CFStringRef lblRef = ABMultiValueCopyLabelAtIndex(multi, i);
                CFStringRef localizedLblRef = nil;
                NSString *lbl =  @"";
                
                if (lblRef != nil)
                {
                    localizedLblRef = ABAddressBookCopyLocalizedLabel(lblRef);
                    
                    if (localizedLblRef)
                    {
                        lbl = (__bridge NSString*)localizedLblRef;
                    }
                    else
                    {
                        lbl = (__bridge NSString*)lblRef;
                    }
                }
                else
                {
                    localizedLblRef = ABAddressBookCopyLocalizedLabel(kABOtherLabel);
                    if (localizedLblRef)
                    {
                        lbl = (__bridge NSString*)localizedLblRef;
                    }
                }
                
                [emails addObject: [[MXKEmail alloc] initWithEmailAddress:emailVal type:lbl contactID:_contactID sdnID:nil]];
                
                if (lblRef)
                {
                    CFRelease(lblRef);
                }
                
                if (localizedLblRef)
                {
                    CFRelease(localizedLblRef);
                }
            }
            
            if (emailValRef)
            {
                CFRelease(emailValRef);
            }
        }
        
        CFRelease(multi);
        
        _emailAddresses = emails;
        
        // thumbnail/picture
        // check whether the contact has a picture
        if (ABPersonHasImageData(record))
        {
            CFDataRef dataRef;
            
            dataRef = ABPersonCopyImageDataWithFormat(record, kABPersonImageFormatThumbnail);
            if (dataRef)
            {
                contactThumbnail = [UIImage imageWithData:(__bridge NSData*)dataRef];
                CFRelease(dataRef);
            }
        }
    }
    return self;
}
#pragma clang diagnostic pop

- (id)initSDNContactWithDisplayName:(NSString*)displayName andSDNID:(NSString*)sdnID
{
    self = [self init];
    if (self)
    {
        _contactID = [NSString stringWithFormat:@"%@%@", kMXKContactSDNContactPrefixId, [[NSUUID UUID] UUIDString]];
        
        // Sanity check
        if (sdnID.length)
        {
            // used when the contact is not defined in the contacts book
            sdnIdField = [[MXKContactField alloc] initWithContactID:_contactID sdnID:sdnID];
            isSDNContact = YES;
        }
        
        // _displayName must not be nil
        // it is used to sort the contacts
        if (displayName)
        {
            _displayName = displayName;
        }
        else
        {
            _displayName = @"";
        }
    }
    
    return self;
}

- (id)initSDNContactWithDisplayName:(NSString*)displayName sdnID:(NSString*)sdnID andSDNAvatarURL:(NSString*)sdnAvatarURL
{
    self = [self initSDNContactWithDisplayName:displayName andSDNID:sdnID];
    if (self)
    {
        sdnIdField.sdnAvatarURL = sdnAvatarURL;
    }
    return self;
}

- (id)initContactWithDisplayName:(NSString*)displayName
                          emails:(NSArray<MXKEmail*> *)emails
                    phoneNumbers:(NSArray<MXKPhoneNumber*> *)phones
                    andThumbnail:(UIImage *)thumbnail
{
    self = [self init];
    if (self)
    {
        _contactID = [NSString stringWithFormat:@"%@%@", kMXKContactDefaultContactPrefixId, [[NSUUID UUID] UUIDString]];
        
        // _displayName must not be nil
        // it is used to sort the contacts
        if (displayName)
        {
            _displayName = displayName;
        }
        else
        {
            _displayName = @"";
        }
        
        _emailAddresses = emails;
        _phoneNumbers = phones;
        
        contactThumbnail = thumbnail;
    }
    
    return self;
}

#pragma mark -

- (NSString*)sortingDisplayName
{
    if (!_sortingDisplayName)
    {
        // Sanity check - display name should not be nil here
        if (self.displayName)
        {
            NSCharacterSet *specialCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"_!~`@#$%^&*-+();:={}[],.<>?\\/\"\'"];
            
            _sortingDisplayName = [self.displayName stringByTrimmingCharactersInSet:specialCharacterSet];
        }
        else
        {
            return @"";
        }
    }
    
    return _sortingDisplayName;
}

- (BOOL)hasPrefix:(NSString*)prefix
{
    prefix = [prefix lowercaseString];
    
    // Check first display name
    if (_displayName.length)
    {
        NSString *lowercaseString = [_displayName lowercaseString];
        if ([lowercaseString hasPrefix:prefix])
        {
            return YES;
        }
        
        NSArray *components = [lowercaseString componentsSeparatedByString:@" "];
        for (NSString *component in components)
        {
            NSString *theComponent = [component stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if ([theComponent hasPrefix:prefix])
            {
                return YES;
            }
        }
    }
    
    // Check sdn identifiers
    NSArray *identifiers = self.sdnIdentifiers;
    NSString *idPrefix = prefix;
    if (![prefix hasPrefix:@"@"])
    {
        idPrefix = [NSString stringWithFormat:@"@%@", prefix];
    }
    
    for (NSString* mxId in identifiers)
    {
        if ([[mxId lowercaseString] hasPrefix:idPrefix])
        {
            return YES;
        }
    }
    
    // Check email
    for (MXKEmail* email in _emailAddresses)
    {
        if ([email.emailAddress hasPrefix:prefix])
        {
            return YES;
        }
    }
    
    // Check phones
    for (MXKPhoneNumber* phone in _phoneNumbers)
    {
        if ([phone hasPrefix:prefix])
        {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)matchedWithPatterns:(NSArray*)patterns
{
    BOOL matched = NO;
    
    if (patterns.count > 0)
    {
        matched = YES;
        
        // test first display name
        for (NSString* pattern in patterns)
        {
            if ([_displayName rangeOfString:pattern options:NSCaseInsensitiveSearch].location == NSNotFound)
            {
                matched = NO;
                break;
            }
        }
        
        NSArray *identifiers = self.sdnIdentifiers;
        if (!matched && identifiers.count > 0)
        {
            for (NSString* mxId in identifiers)
            {
                // Consider only the first part of the sdn id (ignore node name)
                NSRange range = [mxId rangeOfString:@":"];
                if (range.location != NSNotFound)
                {
                    NSString *mxIdName = [mxId substringToIndex:range.location];
                    for (NSString* pattern in patterns)
                    {
                        if ([mxIdName rangeOfString:pattern options:NSCaseInsensitiveSearch].location != NSNotFound)
                        {
                            matched = YES;
                            break;
                        }
                    }
                    
                    if (matched)
                    {
                        break;
                    }
                }
            }
        }
        
        if (!matched && _phoneNumbers.count > 0)
        {
            for (MXKPhoneNumber* phonenumber in _phoneNumbers)
            {
                if ([phonenumber matchedWithPatterns:patterns])
                {
                    matched = YES;
                    break;
                }
            }
        }
        
        if (!matched && _emailAddresses.count > 0)
        {
            for (MXKEmail* email in _emailAddresses)
            {
                if ([email matchedWithPatterns:patterns])
                {
                    matched = YES;
                    break;
                }
            }
        }
    }
    else
    {
        // if there is no pattern to search, it should always matched
        matched = YES;
    }
    
    return matched;
}

- (void)setDefaultCountryCode:(NSString *)defaultCountryCode
{
    for (MXKPhoneNumber* phonenumber in _phoneNumbers)
    {
        phonenumber.defaultCountryCode = defaultCountryCode;
    }
    
    _defaultCountryCode = defaultCountryCode;
}

#pragma mark - getter/setter

- (NSArray*)sdnIdentifiers
{
    NSMutableArray* identifiers = [[NSMutableArray alloc] init];
    
    if (sdnIdField)
    {
        [identifiers addObject:sdnIdField.sdnID];
    }
    
    for (MXKEmail* email in _emailAddresses)
    {
        if (email.sdnID && ([identifiers indexOfObject:email.sdnID] == NSNotFound))
        {
            [identifiers addObject:email.sdnID];
        }
    }
    
    for (MXKPhoneNumber* pn in _phoneNumbers)
    {
        if (pn.sdnID && ([identifiers indexOfObject:pn.sdnID] == NSNotFound))
        {
            [identifiers addObject:pn.sdnID];
        }
    }
    
    return identifiers;
}

- (void)setDisplayName:(NSString *)displayName
{
    // a display name must not be emptied
    // it is used to sort the contacts
    if (displayName.length == 0)
    {
        _displayName = _contactID;
    }
    else
    {
        _displayName = displayName;
    }
}

- (void)resetSDNThumbnail
{
    sdnThumbnail = nil;
    _sdnAvatarURL = nil;
    
    // Reset the avatar in the contact fields too.
    [sdnIdField resetSDNAvatar];
    
    for (MXKEmail* email in _emailAddresses)
    {
        [email resetSDNAvatar];
    }
}

- (UIImage*)thumbnailWithPreferedSize:(CGSize)size
{
    // Consider first the local thumbnail if any.
    if (contactThumbnail)
    {
        return contactThumbnail;
    }
    
    // Check whether a sdn thumbnail is already found.
    if (sdnThumbnail)
    {
        return sdnThumbnail;
    }
    
    // Look for a thumbnail from the sdn identifiers
    MXKContactField* firstField = sdnIdField;
    if (firstField)
    {
        if (firstField.avatarImage)
        {
            sdnThumbnail = firstField.avatarImage;
            _sdnAvatarURL = firstField.sdnAvatarURL;
            return sdnThumbnail;
        }
    }
    
    // try to replace the thumbnail by the sdn one
    if (_emailAddresses.count > 0)
    {
        // list the linked email
        // search if one email field has a dedicated thumbnail
        for (MXKEmail* email in _emailAddresses)
        {
            if (email.avatarImage)
            {
                sdnThumbnail = email.avatarImage;
                _sdnAvatarURL = email.sdnAvatarURL;
                return sdnThumbnail;
            }
            else if (!firstField && email.sdnID)
            {
                firstField = email;
            }
        }
    }
    
    if (_phoneNumbers.count > 0)
    {
        // list the linked phones
        // search if one phone field has a dedicated thumbnail
        for (MXKPhoneNumber* phoneNb in _phoneNumbers)
        {
            if (phoneNb.avatarImage)
            {
                sdnThumbnail = phoneNb.avatarImage;
                _sdnAvatarURL = phoneNb.sdnAvatarURL;
                return sdnThumbnail;
            }
            else if (!firstField && phoneNb.sdnID)
            {
                firstField = phoneNb;
            }
        }
    }
    
    // if no thumbnail has been found
    // try to load the first field one
    if (firstField)
    {
        // should be retrieved by the cell info
        [firstField loadAvatarWithSize:size];
    }
    
    return nil;
}

- (UIImage*)thumbnail
{
    return [self thumbnailWithPreferedSize:CGSizeMake(256, 256)];
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder
{
    _contactID = [coder decodeObjectForKey:@"contactID"];
    _displayName = [coder decodeObjectForKey:@"displayName"];
    
    sdnIdField = [coder decodeObjectForKey:@"sdnIdField"];
    
    _phoneNumbers = [coder decodeObjectForKey:@"phoneNumbers"];
    _emailAddresses = [coder decodeObjectForKey:@"emailAddresses"];
    
    NSData *data = [coder decodeObjectForKey:@"contactThumbnail"];
    if (!data)
    {
        // Check the legacy storage.
        data = [coder decodeObjectForKey:@"contactBookThumbnail"];
    }
    
    if (data)
    {
        contactThumbnail = [UIImage imageWithData:data];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    
    [coder encodeObject:_contactID forKey:@"contactID"];
    [coder encodeObject:_displayName forKey:@"displayName"];
    
    if (sdnIdField)
    {
        [coder encodeObject:sdnIdField forKey:@"sdnIdField"];
    }
    
    if (_phoneNumbers.count)
    {
        [coder encodeObject:_phoneNumbers forKey:@"phoneNumbers"];
    }
    
    if (_emailAddresses.count)
    {
        [coder encodeObject:_emailAddresses forKey:@"emailAddresses"];
    }
    
    if (contactThumbnail)
    {
        @autoreleasepool
        {
            NSData *data = UIImageJPEGRepresentation(contactThumbnail, 0.8);
            [coder encodeObject:data forKey:@"contactThumbnail"];
        }
    }
}

@end
