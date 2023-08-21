//
//  MXDIDLoginIdentifier.h
//  SDNSDK
//
//  Created by fqchen.abcft on 8/3/22.
//

#import "MXJSONModel.h"

NS_ASSUME_NONNULL_BEGIN

/**
 DIDLoginIdentifier spec:
 https://confluence.linxme.io/display/LINC/LinX+Web3+Wallet+Login+Specification#LinXWeb3WalletLoginSpecification-DIDLoginIdentifier
 */

@interface MXDIDLoginIdentifier : MXJSONModel

// did address
@property (nonatomic, readonly) NSString *address;
// random nonce for make message to sign
@property (nonatomic, readonly) NSString *nonce;
// timestamp for make message to sign
@property (nonatomic, readonly) int64_t timestamp;
// wallet address
@property (nonatomic, readonly) NSString *publicKey;
// token generated from signed message (URL-Safe Base64)
@property (nonatomic, readonly) NSString *token;
// login type
@property (nonatomic, readonly) NSString *type;
// login medium
@property (nonatomic, readonly) NSString *medium;
// salt for make message to sign
@property (nonatomic, readonly) NSString *salt;

+(instancetype)modelFromAddress:(NSString *)address
                          nonce:(NSString *)nonce
                      timestamp:(int64_t)timestamp
                      publicKey:(NSString *)publicKey
                          token:(NSString *)token
                           type:(NSString *)type
                         medium:(NSString *)medium
                           salt:(NSString *)salt;


@end

NS_ASSUME_NONNULL_END
