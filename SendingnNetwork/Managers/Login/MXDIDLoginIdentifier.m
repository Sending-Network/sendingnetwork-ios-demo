//
//  MXDIDLoginIdentifier.m
//  SDNSDK
//
//  Created by fqchen.abcft on 8/3/22.
//

#import "MXDIDLoginIdentifier.h"
#import "MXJSONModel.h"

@interface MXDIDLoginIdentifier()

// did address
@property (nonatomic, readwrite) NSString *address;
// random nonce for make message to sign
@property (nonatomic, readwrite) NSString *nonce;
// timestamp for make message to sign
@property (nonatomic, readwrite) int64_t timestamp;
// wallet address
@property (nonatomic, readwrite) NSString *publicKey;
// token generated from signed message (URL-Safe Base64)
@property (nonatomic, readwrite) NSString *token;
// login type
@property (nonatomic, readwrite) NSString *type;
// login medium
@property (nonatomic, readwrite) NSString *medium;
// salt for make message to sign
@property (nonatomic, readwrite) NSString *salt;

@end

@implementation MXDIDLoginIdentifier


+ (instancetype)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXDIDLoginIdentifier *identity = [MXDIDLoginIdentifier new];

    MXJSONModelSetString(identity.address, JSONDictionary[@"address"]);
    MXJSONModelSetString(identity.nonce, JSONDictionary[@"nonce"]);
    MXJSONModelSetString(identity.timestamp, JSONDictionary[@"timestamp"]);
    MXJSONModelSetString(identity.publicKey, JSONDictionary[@"publicKey"]);
    MXJSONModelSetString(identity.token, JSONDictionary[@"token"]);
    MXJSONModelSetString(identity.type, JSONDictionary[@"type"]);
    MXJSONModelSetString(identity.medium, JSONDictionary[@"medium"]);
    MXJSONModelSetString(identity.salt, JSONDictionary[@"salt"]);

    return identity;
}

+(instancetype)modelFromAddress:(NSString *)address
                          nonce:(NSString *)nonce
                      timestamp:(int64_t)timestamp
                      publicKey:(NSString *)publicKey
                          token:(NSString *)token
                           type:(NSString *)type
                         medium:(NSString *)medium
                           salt:(NSString *)salt {
    MXDIDLoginIdentifier *identity = [MXDIDLoginIdentifier new];
    
    identity.address = address;
    identity.nonce = nonce;
    identity.timestamp = timestamp;
    identity.publicKey = publicKey;
    identity.token = token;
    identity.type = type;
    identity.medium = medium;
    identity.salt = salt;
    
    return identity;
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"address": _address,
        @"nonce": _nonce,
        @"timestamp": @(_timestamp),
        @"publicKey": _publicKey,
        @"token": _token,
        @"type": _type,
        @"medium": _medium,
        @"salt": _salt
    };
}



@end
