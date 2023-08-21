/*
 Copyright 2015 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
 
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

#import "MXKContactTableCell.h"

@import SDNSDK.MXTools;

#import "MXKContactManager.h"
#import "MXKAppSettings.h"

#import "NSBundle+SDNKit.h"

#pragma mark - Constant definitions
NSString *const kMXKContactCellTapOnThumbnailView = @"kMXKContactCellTapOnThumbnailView";

NSString *const kMXKContactCellContactIdKey = @"kMXKContactCellContactIdKey";

@interface MXKContactTableCell()
{
    /**
     The current displayed contact.
     */
    MXKContact *contact;
    
    /**
     The observer of the presence for sdn user.
     */
    id mxPresenceObserver;
}
@end

@implementation MXKContactTableCell
@synthesize delegate;

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.thumbnailDisplayBoxType = MXKTableViewCellDisplayBoxTypeDefault;
    
    // No accessory view by default
    self.contactAccessoryViewType = MXKContactTableCellAccessoryCustom;
    
    self.hideSDNPresence = NO;
}

- (void)customizeTableViewCellRendering
{
    [super customizeTableViewCellRendering];
    
    self.thumbnailView.defaultBackgroundColor = [UIColor clearColor];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (self.thumbnailDisplayBoxType == MXKTableViewCellDisplayBoxTypeCircle)
    {
        // Round image view for thumbnail
        self.thumbnailView.layer.cornerRadius = self.thumbnailView.frame.size.width / 2;
        self.thumbnailView.clipsToBounds = YES;
    }
    else if (self.thumbnailDisplayBoxType == MXKTableViewCellDisplayBoxTypeRoundedCorner)
    {
        self.thumbnailView.layer.cornerRadius = 5;
        self.thumbnailView.clipsToBounds = YES;
    }
    else
    {
        self.thumbnailView.layer.cornerRadius = 0;
        self.thumbnailView.clipsToBounds = NO;
    }
}

- (UIImage*)picturePlaceholder
{
    return [NSBundle mxk_imageFromMXKAssetsBundleWithName:@"default-profile"];
}

- (void)setContactAccessoryViewType:(MXKContactTableCellAccessoryType)contactAccessoryViewType
{
    _contactAccessoryViewType = contactAccessoryViewType;
    
    if (contactAccessoryViewType == MXKContactTableCellAccessorySDNIcon)
    {
        // Load default sdn icon
        self.contactAccessoryImageView.image = [NSBundle mxk_imageFromMXKAssetsBundleWithName:@"sdnUser"];
        self.contactAccessoryImageView.hidden = NO;
        self.contactAccessoryButton.hidden = YES;
        
        // Update accessory view visibility
        [self refreshSDNIdentifiers];
    }
    else
    {
        // Hide accessory view by default
        self.contactAccessoryView.hidden = YES;
        self.contactAccessoryImageView.hidden = YES;
        self.contactAccessoryButton.hidden = YES;
    }
}

#pragma mark - MXKCellRendering

- (void)render:(MXKCellData *)cellData
{
    // Sanity check: accept only object of MXKContact classes or sub-classes
    NSParameterAssert([cellData isKindOfClass:[MXKContact class]]);
    
    contact = (MXKContact*)cellData;
    
    // remove any pending observers
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (mxPresenceObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:mxPresenceObserver];
        mxPresenceObserver = nil;
    }
    
    self.thumbnailView.layer.borderWidth = 0;
    
    if (contact)
    {
        // Be warned when the thumbnail is updated
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onThumbnailUpdate:) name:kMXKContactThumbnailUpdateNotification object:nil];
        
        if (! self.hideSDNPresence)
        {
            // Observe contact presence change
            MXWeakify(self);
            mxPresenceObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXKContactManagerSDNUserPresenceChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
                MXStrongifyAndReturnIfNil(self);

                // get the sdn identifiers
                NSArray* sdnIdentifiers = self->contact.sdnIdentifiers;
                if (sdnIdentifiers.count > 0)
                {
                    // Consider only the first id
                    NSString *sdnUserID = sdnIdentifiers.firstObject;
                    if ([sdnUserID isEqualToString:notif.object])
                    {
                        [self refreshPresenceUserRing:[MXTools presence:[notif.userInfo objectForKey:kMXKContactManagerSDNPresenceKey]]];
                    }
                }
            }];
        }
        
        if (!contact.isSDNContact)
        {
            // Be warned when the linked sdn IDs are updated
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onSDNIdUpdate:)  name:kMXKContactManagerDidUpdateLocalContactSDNIDsNotification object:nil];
        }
        
        NSArray* sdnIDs = contact.sdnIdentifiers;
        
        if (sdnIDs.count)
        {
            self.contactDisplayNameLabel.hidden = YES;
            
            self.sdnDisplayNameLabel.hidden = NO;
            self.sdnDisplayNameLabel.text = contact.displayName;
            self.sdnIDLabel.hidden = NO;
            self.sdnIDLabel.text = [sdnIDs firstObject];
        }
        else
        {
            self.contactDisplayNameLabel.hidden = NO;
            self.contactDisplayNameLabel.text = contact.displayName;
            
            self.sdnDisplayNameLabel.hidden = YES;
            self.sdnIDLabel.hidden = YES;
        }
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onContactThumbnailTap:)];
        [tap setNumberOfTouchesRequired:1];
        [tap setNumberOfTapsRequired:1];
        [tap setDelegate:self];
        [self.thumbnailView addGestureRecognizer:tap];
    }
    
    [self refreshContactThumbnail];
    [self manageSDNIcon];
}

+ (CGFloat)heightForCellData:(MXKCellData*)cellData withMaximumWidth:(CGFloat)maxWidth
{
    // The height is fixed
    return 50;
}

- (void)didEndDisplay
{
    // remove any pending observers
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (mxPresenceObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:mxPresenceObserver];
        mxPresenceObserver = nil;
    }
    
    // Remove all gesture recognizer
    while (self.thumbnailView.gestureRecognizers.count)
    {
        [self.thumbnailView removeGestureRecognizer:self.thumbnailView.gestureRecognizers[0]];
    }
    
    self.delegate = nil;
    contact = nil;
}

#pragma mark -

- (void)refreshSDNIdentifiers
{
    // Look for a potential sdn user linked with this contact
    NSArray* sdnIdentifiers = contact.sdnIdentifiers;
    
    if ((sdnIdentifiers.count > 0) && (! self.hideSDNPresence))
    {
        // Consider only the first sdn identifier
        NSString* sdnUserID = sdnIdentifiers.firstObject;
        
        // Consider here all sessions reported into contact manager
        NSArray* mxSessions = [MXKContactManager sharedManager].mxSessions;
        for (MXSession *mxSession in mxSessions)
        {
            MXUser *mxUser = [mxSession userWithUserId:sdnUserID];
            if (mxUser)
            {
                [self refreshPresenceUserRing:mxUser.presence];
                break;
            }
        }
    }
    
    // Update accessory view visibility
    if (self.contactAccessoryViewType == MXKContactTableCellAccessorySDNIcon)
    {
        self.contactAccessoryView.hidden = (!sdnIdentifiers.count);
    }
}

- (void)refreshContactThumbnail
{
    self.thumbnailView.image = [contact thumbnailWithPreferedSize:self.thumbnailView.frame.size];
    
    if (!self.thumbnailView.image)
    {
        self.thumbnailView.image = self.picturePlaceholder;
    }
}

- (void)refreshPresenceUserRing:(MXPresence)presenceStatus
{
    UIColor* ringColor;
    
    switch (presenceStatus)
    {
        case MXPresenceOnline:
            ringColor = [[MXKAppSettings standardAppSettings] presenceColorForOnlineUser];
            break;
        case MXPresenceUnavailable:
            ringColor = [[MXKAppSettings standardAppSettings] presenceColorForUnavailableUser];
            break;
        case MXPresenceOffline:
            ringColor = [[MXKAppSettings standardAppSettings] presenceColorForOfflineUser];
            break;
        default:
            ringColor = nil;
    }
    
    // if the thumbnail is defined
    if (ringColor && (! self.hideSDNPresence))
    {
        self.thumbnailView.layer.borderWidth = 2;
        self.thumbnailView.layer.borderColor = ringColor.CGColor;
    }
    else
    {
        // remove the border
        // else it draws black border
        self.thumbnailView.layer.borderWidth = 0;
    }
}

- (void)manageSDNIcon
{
    // try to update the thumbnail with the sdn thumbnail
    if (contact.sdnIdentifiers)
    {
        [self refreshContactThumbnail];
    }
    
    [self refreshSDNIdentifiers];
}

- (void)onSDNIdUpdate:(NSNotification *)notif
{
    // sanity check
    if ([notif.object isKindOfClass:[NSString class]])
    {
        NSString* contactID = notif.object;
        
        if ([contactID isEqualToString:contact.contactID])
        {
            [self manageSDNIcon];
        }
    }
}

- (void)onThumbnailUpdate:(NSNotification *)notif
{
    // sanity check
    if ([notif.object isKindOfClass:[NSString class]])
    {
        NSString* contactID = notif.object;
        
        if ([contactID isEqualToString:contact.contactID])
        {
            [self refreshContactThumbnail];
            
            [self refreshSDNIdentifiers];
        }
    }
}

#pragma mark - Action

- (IBAction)onContactThumbnailTap:(id)sender
{
    if (self.delegate)
    {
        [self.delegate cell:self didRecognizeAction:kMXKContactCellTapOnThumbnailView userInfo:@{kMXKContactCellContactIdKey: contact.contactID}];
    }
}

@end
