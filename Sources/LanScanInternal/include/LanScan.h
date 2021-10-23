//
//  LAN Scan
//
//  Created by Marcin Kielesiński on 4 July 2018
//

#import <Foundation/Foundation.h>

@protocol LANScanDelegate <NSObject>

#define MAX_IP_RANGE 254
#define TIMEOUT 0.1

#define DEVICE_NAME @"DEVICE_NAME"
#define DEVICE_IP_ADDRESS @"DEVICE_IP_ADDRESS"
#define DEVICE_MAC @"DEVICE_MAC"
#define DEVICE_BRAND @"DEVICE_BRAND"

@optional
- (void)lanScanDidFinishScanning;
- (void)lanScanDidFindNewDevice:(NSDictionary *) device;
- (void)lanScanHasUpdatedProgress:(NSInteger) counter address:(NSString*) address;
@end

@interface LanScan : NSObject

@property(nonatomic,weak) id<LANScanDelegate> delegate;

- (id)initWithDelegate:(id<LANScanDelegate>)delegate;
- (void)start;
- (void)stop;

@end
