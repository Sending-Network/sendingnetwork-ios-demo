//
//  MXLoginDIDIdentityProvider.m
//  SDNSDK
//
//  Created by fqchen.abcft on 8/3/22.
//

#import "MXLoginDIDIdentityProvider.h"
#import "MXJSONModels.h"

@interface MXLoginDIDIdentityProvider()

@property (nonatomic, readwrite) NSString *type;
@property (nonatomic, readwrite) MXDIDLoginIdentifier *identifier;

@end

@implementation MXLoginDIDIdentityProvider

+ (instancetype)modelFromJSON:(NSDictionary *)JSONDictionary {
    
    MXLoginDIDIdentityProvider *provider = [MXLoginDIDIdentityProvider new];
    MXJSONModelSetString(provider.type, JSONDictionary[@"type"]);
    MXJSONModelSetMXJSONModel(provider.identifier, MXDIDLoginIdentifier, JSONDictionary[@"identifier"]);
    
    return provider;
}

+ (instancetype)modelFromIdentifier:(MXDIDLoginIdentifier *)identifier {
    MXLoginDIDIdentityProvider *provider = [MXLoginDIDIdentityProvider new];
//    provider.type = kMXLoginFlowTypeDID;
    provider.identifier = identifier;
    
    return provider;
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"type": _type,
        @"identifier": _identifier.JSONDictionary
    };
}


@end
