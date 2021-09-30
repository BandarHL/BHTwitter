//
//  keychain.m
//  BHTwitter
//
//  Created by BandarHelal on 25/09/2021.
//

#import "keychain.h"
#import "SAMKeychainQuery.h"

@interface keychain ()
@property (nonatomic, strong) SAMKeychainQuery *query;
@end
@implementation keychain

+ (instancetype)shared {
    static keychain *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.query = [[SAMKeychainQuery alloc] init];
        self.query.service = @"com.bhtwitter.padlock";
        self.query.account = @"com.bhtwitter.user";
        [self.query fetch:nil];
    }
    return self;
}

- (void)saveDictionary:(NSDictionary *)dicData {
    self.query.passwordData = [NSKeyedArchiver archivedDataWithRootObject:dicData];
    [self.query save:nil];
}

- (NSDictionary *)getData {
    [self.query fetch:nil];
    return (NSDictionary *)[NSKeyedUnarchiver unarchiveObjectWithData:self.query.passwordData];
}

- (void)deleteService {
    [self.query deleteItem:nil];
}
@end
