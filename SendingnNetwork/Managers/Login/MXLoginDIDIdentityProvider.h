//
//  MXLoginDIDIdentityProvider.h
//  SDNSDK
//
//  Created by fqchen.abcft on 8/3/22.
//

#import "MXJSONModel.h"
#import "MXDIDLoginIdentifier.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Spec
 https://confluence.linxme.io/pages/viewpage.action?pageId=4655348
 https://confluence.linxme.io/display/LINC/LinX+Web3+Wallet+Login+Specification#LinXWeb3WalletLoginSpecification-DIDLoginIdentifier
 */
@interface MXLoginDIDIdentityProvider : MXJSONModel


@property (nonatomic, readonly) NSString *type;

/**
 The identifier field (id field in JSON) is the Identity Provider identifier used for the DID login
 */
@property (nonatomic, readonly) MXDIDLoginIdentifier *identifier;

+ (instancetype)modelFromIdentifier:(MXDIDLoginIdentifier *)identifier;

@end

NS_ASSUME_NONNULL_END
