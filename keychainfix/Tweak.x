#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Security/Security.h>

static NSString * _Nonnull accessGroupID() {
    NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
                           (__bridge NSString *)kSecClassGenericPassword, (__bridge NSString *)kSecClass,
                           @"bundleSeedID", kSecAttrAccount,
                           @"", kSecAttrService,
                           (id)kCFBooleanTrue, kSecReturnAttributes,
                           nil];
    CFDictionaryRef result = nil;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
    if (status == errSecItemNotFound)
        status = SecItemAdd((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
        if (status != errSecSuccess)
            return nil;
    NSString *accessGroup = [(__bridge NSDictionary *)result objectForKey:(__bridge NSString *)kSecAttrAccessGroup];

    return accessGroup;
}

%hook TFSKeychain
- (NSString *)providerDefaultAccessGroup {
   return accessGroupID();
}
- (NSString *)providerSharedAccessGroup {
   return accessGroupID();
}
%end

%hook TFSKeychainDefaultTwitterConfiguration
- (NSString *)defaultAccessGroup {
   return accessGroupID();
}
- (NSString *)sharedAccessGroup {
   return accessGroupID();
}
%end