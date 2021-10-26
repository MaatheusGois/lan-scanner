//
//  LAN Scan
//
//  Created by Marcin Kielesiński on 4 July 2018
//

#import "LanScan.h"
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <netdb.h>
#include <net/if_dl.h>
#include <net/if.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <sys/sysctl.h>

#include "if_arp.h"
#include "if_ether.h"
#include "route.h"

#include "PingOperation.h"
#import <SystemConfiguration/CaptiveNetwork.h>

#define VENDORS_DICTIONARY @"vendors.out"

#ifndef DEFAULT_WIFI_INTERFACE
#define DEFAULT_WIFI_INTERFACE @"en0"
#endif
#ifndef DEFAULT_CELLULAR_INTERFACE
#define DEFAULT_CELLULAR_INTERFACE @"pdp_ip0"
#endif

#ifndef deb
#define deb(format, ...) {if(DEBUG){NSString *__oo = [NSString stringWithFormat: @"%s:%@", __PRETTY_FUNCTION__, [NSString stringWithFormat:format, ## __VA_ARGS__]]; NSLog(@"%@", __oo); }}
#endif

#define BUFLEN (sizeof(struct rt_msghdr) + 512)
#define SEQ 9999
#define RTM_VERSION    5
#define RTM_GET    0x4
#define RTF_LLINFO    0x400
#define RTF_IFSCOPE 0x1000000
#define RTA_DST    0x1
#define CTL_NET    4

#if defined(BSD) || defined(__APPLE__)
#define ROUNDUP(a) ((a) > 0 ? (1 + (((a) - 1) | (sizeof(long) - 1))) : sizeof(long))
#endif

@interface LanScan ()

@property (nonatomic, retain) NSString *localAddress;
@property (nonatomic,retain) NSString *baseAddress;
@property (nonatomic) NSInteger currentHostAddress;
@property (nonatomic, retain) NSTimer *timer;
@property (nonatomic, retain) NSString *netMask;
@property (nonatomic) NSInteger baseAddressEnd;
@property (nonatomic, retain) NSMutableDictionary *brandDictionary;

@end

@implementation LanScan

- (id)initWithDelegate:(id<LANScanDelegate>)delegate {
    deb(@"init scanner");
    self = [super init];
    if(self) {
        self.delegate = delegate;
    }
    return self;
}

-(BOOL) isEmpty: (NSObject*) o {
    if(o == nil) {
        return true;
    }
    if([o isKindOfClass: [NSString class]]) {
        return !(((NSString*)o).length > 0);
    }
    if([o isKindOfClass: [NSArray class]]) {
        return !(((NSArray*)o).count > 0);
    }
    if([o isKindOfClass: [NSDictionary class]]) {
        return !(((NSDictionary*)o).count > 0);
    }
    if([o isKindOfClass: [NSData class]]) {
        return !(((NSData*)o).length > 0);
    }
    return true;
}

-(NSString*) getDownloadedVendorsDictionaryPath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (![self isEmpty:paths]) {
        return [[paths objectAtIndex:0] stringByAppendingPathComponent: VENDORS_DICTIONARY];
    }
    return nil;
}

-(NSMutableDictionary*) downloadedVendorsDictionary {
    NSString *path = [self getDownloadedVendorsDictionaryPath];
    if(![self isEmpty:path]){
        NSMutableDictionary *dict = [[NSDictionary dictionaryWithContentsOfFile: path] mutableCopy];
        if(dict == nil){
            dict = [NSMutableDictionary new];
        }
        return dict;
    }
    return [NSMutableDictionary new];
}

- (void)start {
    
    deb(@"start scan for router: %@", [self getRouterIP]);

    //Initializing the dictionary that holds the Brands name for each MAC Address

    self.brandDictionary = [[NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource: @"data" ofType: @"plist"]] mutableCopy];
    
    //Initializing the dictionary that holds the Brands downloaded from the internet
    NSMutableDictionary *vendors = [self downloadedVendorsDictionary];
    if(![self isEmpty:vendors]){
        [self.brandDictionary addEntriesFromDictionary: vendors];
    }
    

    self.localAddress = [self localIPAddress];
    NSArray *a = [self.localAddress componentsSeparatedByString:@"."];
    NSArray *b = [self.netMask componentsSeparatedByString:@"."];
    if ([self isIpAddressValid:self.localAddress] && (a.count == 4) && (b.count == 4))
    {
        for (int i = 0; i < 4; i++) {
            int and = (int)[[a objectAtIndex:i] integerValue] & [[b objectAtIndex:i] integerValue];
            if (!self.baseAddress.length)
            {
                self.baseAddress = [NSString stringWithFormat:@"%d", and];
            }
            else
            {
                self.baseAddress = [NSString stringWithFormat:@"%@.%d", self.baseAddress, and];
                self.currentHostAddress = and;
                self.baseAddressEnd = and;
            }
        }
        self.timer = [NSTimer scheduledTimerWithTimeInterval:TIMEOUT target:self selector:@selector(probeNetwork) userInfo:nil repeats:YES];
    }
}

- (void)stop {
    deb(@"stop scan");
    [self.timer invalidate];
    self.timer = nil;
}

- (void)probeNetwork{
    NSString *deviceIPAddress = [[[[NSString stringWithFormat:@"%@%ld", self.baseAddress, (long)self.currentHostAddress] stringByReplacingOccurrencesOfString:@".0" withString:@"."] stringByReplacingOccurrencesOfString:@".00" withString:@"."] stringByReplacingOccurrencesOfString:@".." withString:@".0."];
    
    if(deviceIPAddress != nil) {
        //ping to check if device is active
        PingOperation *pingOperation = [[PingOperation alloc]initWithIPToPing:deviceIPAddress andCompletionHandler:^(NSError  * _Nullable error, NSString  * _Nonnull ip) {
            
            if(error == nil) {
                
                NSMutableString *deviceHostName = [[self hostnamesForAddress: deviceIPAddress] mutableCopy];
                if([deviceIPAddress isEqualToString:[self getRouterIP]]){
                    [deviceHostName appendString: @" (router)"];
                }
                
                NSString *deviceMac = [self ip2mac: deviceIPAddress];
                NSString *deviceBrand = [self.brandDictionary objectForKey: [self makeKeyFromMAC: deviceMac]];
                
                if([self isEmpty:deviceBrand]) {
                    
                    NSURL *url = [NSURL URLWithString:[[NSString alloc] initWithFormat:@"https://api.macvendors.com/%@", deviceMac]];
                    NSData *data = [NSData dataWithContentsOfURL: url];
                    if(![self isEmpty: data]) {
                        deviceBrand = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                        if(![self isEmpty:deviceBrand]){
                            
                            NSMutableDictionary *vendors = [self downloadedVendorsDictionary];
                            NSString *path = [self getDownloadedVendorsDictionaryPath];
                            if(![self isEmpty: path]){
                                vendors[[self makeKeyFromMAC:deviceMac]] = deviceBrand;
                                [vendors writeToFile:path atomically:YES];
                            }
                        }
                    }
                }
                
                NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys:
                                      deviceHostName != nil ? deviceHostName : @"", DEVICE_NAME,
                                      deviceIPAddress != nil ? deviceIPAddress : @"", DEVICE_IP_ADDRESS,
                                      deviceMac != nil ? deviceMac : @"", DEVICE_MAC,
                                      deviceBrand != nil ? deviceBrand : @"", DEVICE_BRAND,
                                      nil];
                
                [self.delegate lanScanDidFindNewDevice: dict];
            } else {
                // If debug mode is active
                deb(@"%@", error);
            }
            
        }];
        [pingOperation start];
    }

    [self.delegate lanScanHasUpdatedProgress:self.currentHostAddress address: deviceIPAddress];
    
    if (self.currentHostAddress >= MAX_IP_RANGE) {
        [self.timer invalidate];
        [self.delegate lanScanDidFinishScanning];
    }
    
    self.currentHostAddress++;
}

-(NSString*)makeKeyFromMAC: (NSString*) deviceMac {
    if(![self isEmpty: deviceMac]){
        return [[[deviceMac substringWithRange:NSMakeRange(0, 8)] stringByReplacingOccurrencesOfString:@":" withString:@"-"] uppercaseString];
    }
    return nil;
}

-(NSString*)ip2mac: (NSString*)strIP {
    
    const char *ip = [strIP UTF8String];
    
    int sockfd = 0;
    unsigned char buf[BUFLEN];
    unsigned char buf2[BUFLEN];
    ssize_t n = 0;
    struct rt_msghdr *rtm;
    struct sockaddr_in *sin;
    memset(buf, 0, sizeof(buf));
    memset(buf2, 0, sizeof(buf2));
    
    sockfd = socket(AF_ROUTE, SOCK_RAW, 0);
    rtm = (struct rt_msghdr *) buf;
    rtm->rtm_msglen = sizeof(struct rt_msghdr) + sizeof(struct sockaddr_in);
    rtm->rtm_version = RTM_VERSION;
    rtm->rtm_type = RTM_GET;
    rtm->rtm_addrs = RTA_DST;
    rtm->rtm_flags = RTF_LLINFO;
    rtm->rtm_pid = getpid();
    rtm->rtm_seq = SEQ;
    
    sin = (struct sockaddr_in *) (rtm + 1);
    sin->sin_len = sizeof(struct sockaddr_in);
    sin->sin_family = AF_INET;
    sin->sin_addr.s_addr = inet_addr(ip);
    write(sockfd, rtm, rtm->rtm_msglen);
    
    n = read(sockfd, buf2, BUFLEN);
    close(sockfd);
    
    if (n != 0) {
        int index =  sizeof(struct rt_msghdr) + sizeof(struct sockaddr_inarp) + 8;
        NSString *macAddress =[NSString stringWithFormat:@"%2.2x:%2.2x:%2.2x:%2.2x:%2.2x:%2.2x",buf2[index+0], buf2[index+1], buf2[index+2], buf2[index+3], buf2[index+4], buf2[index+5]];
        if ([macAddress isEqualToString:@"00:00:00:00:00:00"] ||[macAddress isEqualToString:@"08:00:00:00:00:00"] ) {
            return nil;
        }
        return macAddress;
    }
    return nil;
}

- (NSString *)hostnamesForAddress:(NSString *)address {
    struct addrinfo *result = NULL;
    struct addrinfo hints;
    
    memset(&hints, 0, sizeof(hints));
    hints.ai_flags = AI_NUMERICHOST;
    hints.ai_family = PF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = 0;
    
    const char *strHost = [address cStringUsingEncoding: NSASCIIStringEncoding];
    int errorStatus = getaddrinfo(strHost, NULL, &hints, &result);
    if (errorStatus != 0) {
        return [self getErrorDescription:errorStatus];
    }
    
    NSString *backupHostName = nil;
    for (struct addrinfo *r = result; r; r = r->ai_next) {
        char hostname[NI_MAXHOST] = {0};
        int error = getnameinfo(r->ai_addr, r->ai_addrlen, hostname, sizeof hostname, NULL, 0 , NI_NUMERICHOST);
        if (error != 0) {
            continue;
        } else {
            if(r->ai_canonname != nil && strlen(r->ai_canonname) > 0) {
                backupHostName = [NSString stringWithUTF8String: r->ai_canonname];
            } else {
                backupHostName = [NSString stringWithUTF8String: hostname];
            }
            break;
        }
    }
    
    CFDataRef addressRef = CFDataCreate(NULL, (UInt8 *)result->ai_addr, result->ai_addrlen);
    if (addressRef == nil) {
        freeaddrinfo(result);
        return backupHostName;
    }
    freeaddrinfo(result);
    
    CFHostRef hostRef = CFHostCreateWithAddress(kCFAllocatorDefault, addressRef);
    if (hostRef == nil) {
        return backupHostName;
    }
    CFRelease(addressRef);
    
    BOOL succeeded = CFHostStartInfoResolution(hostRef, kCFHostNames, NULL);
    if (!succeeded) {
        return backupHostName;
    }
    
    CFArrayRef hostnamesRef = CFHostGetNames(hostRef, NULL);
    NSInteger count = [(__bridge NSArray *)hostnamesRef count];
    if(count == 1) {
        return [(__bridge NSArray *)hostnamesRef objectAtIndex: 0];
    }
    
    NSMutableString *hostnames = [NSMutableString new];
    for (int currentIndex = 0; currentIndex < count; currentIndex++) {
        NSString *name = [(__bridge NSArray *)hostnamesRef objectAtIndex:currentIndex];
        
        if(currentIndex == 0) {
            [hostnames appendString: name];
            [hostnames appendString: @" ("];
        }
        if(currentIndex > 0 && currentIndex < count - 1) {
            [hostnames appendString: name];
            [hostnames appendString: @" ,"];
        }
        if(currentIndex > 0 && currentIndex == count - 1) {
            [hostnames appendString: name];
            [hostnames appendString: @")"];
        }
    }
    
    return hostnames;
}

- (NSString *)getErrorDescription:(NSInteger)errorCode {
    NSString *errorDescription = @"";
    switch (errorCode) {
        case EAI_ADDRFAMILY: {
            errorDescription = @" address family for hostname not supported";
            break;
        }
        case EAI_AGAIN: {
            errorDescription = @" temporary failure in name resolution";
            break;
        }
        case EAI_BADFLAGS: {
            errorDescription = @" invalid value for ai_flags";
            break;
        }
        case EAI_FAIL: {
            errorDescription = @" non-recoverable failure in name resolution";
            break;
        }
        case EAI_FAMILY: {
            errorDescription = @" ai_family not supported";
            break;
        }
        case EAI_MEMORY: {
            errorDescription = @" memory allocation failure";
            break;
        }
        case EAI_NODATA: {
            errorDescription = @" no address associated with hostname";
            break;
        }
        case EAI_NONAME: {
            errorDescription = @" hostname nor servname provided, or not known";
            break;
        }
        case EAI_SERVICE: {
            errorDescription = @" servname not supported for ai_socktype";
            break;
        }
        case EAI_SOCKTYPE: {
            errorDescription = @" ai_socktype not supported";
            break;
        }
        case EAI_SYSTEM: {
            errorDescription = @" system error returned in errno";
            break;
        }
        case EAI_BADHINTS: {
            errorDescription = @" invalid value for hints";
            break;
        }
        case EAI_PROTOCOL: {
            errorDescription = @" resolved protocol is unknown";
            break;
        }
        case EAI_OVERFLOW: {
            errorDescription = @" argument buffer overflow";
            break;
        }
    }
    return errorDescription;
}

- (NSString *)getIPAddress {
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    NSString *wifiAddress = nil;
    NSString *cellAddress = nil;
    
    // retrieve the current interfaces - returns 0 on success
    if(!getifaddrs(&interfaces)) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            sa_family_t sa_type = temp_addr->ifa_addr->sa_family;
            if(sa_type == AF_INET || sa_type == AF_INET6) {
                NSString *name = [NSString stringWithUTF8String:temp_addr->ifa_name];
                NSString *addr = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)]; // pdp_ip0
                
                if([name isEqualToString: DEFAULT_WIFI_INTERFACE]) {
                    // Interface is the wifi connection on the iPhone
                    wifiAddress = addr;
                } else
                    if([name isEqualToString: DEFAULT_CELLULAR_INTERFACE]) {
                        // Interface is the cell connection on the iPhone
                        cellAddress = addr;
                    }
            }
            temp_addr = temp_addr->ifa_next;
        }
        // Free memory
        freeifaddrs(interfaces);
    }
    NSString *addr = wifiAddress ? wifiAddress : cellAddress;
    return addr ? addr : @"0.0.0.0";
}

- (NSString *) localIPAddress {
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    
    if (success == 0) {
        temp_addr = interfaces;
        
        while(temp_addr != NULL) {
            // check if interface is en0 which is the wifi connection on the iPhone
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString: DEFAULT_WIFI_INTERFACE]) {
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                    self.netMask = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_netmask)->sin_addr)];
                }
            }
            
            temp_addr = temp_addr->ifa_next;
        }
    }
    
    freeifaddrs(interfaces);
    
    return address;
}

- (BOOL) isIpAddressValid:(NSString *)ipAddress{
    struct in_addr pin;
    int success = inet_aton([ipAddress UTF8String],&pin);
    if (success == 1) return TRUE;
    return FALSE;
}

-(int) getDefaultGateway: (in_addr_t *) addr  {
    int mib[] = {CTL_NET, PF_ROUTE, 0, AF_INET,
        NET_RT_FLAGS, RTF_GATEWAY};
    size_t l;
    char * buf, * p;
    struct rt_msghdr * rt;
    struct sockaddr * sa;
    struct sockaddr * sa_tab[RTAX_MAX];
    int i;
    int r = -1;
    if(sysctl(mib, sizeof(mib)/sizeof(int), 0, &l, 0, 0) < 0) {
        return -1;
    }
    if(l > 0) {
        buf = malloc(l);
        if(sysctl(mib, sizeof(mib)/sizeof(int), buf, &l, 0, 0) < 0) {
            return -1;
        }
        for(p = buf; p < buf + l; p += rt->rtm_msglen) {
            rt = (struct rt_msghdr *)p;
            sa = (struct sockaddr *)(rt + 1);
            for(i = 0; i < RTAX_MAX; i++) {
                if(rt->rtm_addrs & (1 << i)) {
                    sa_tab[i] = sa;
                    sa = (struct sockaddr *)((char *)sa + ROUNDUP(sa->sa_len));
                } else {
                    sa_tab[i] = NULL;
                }
            }
            
            if( ((rt->rtm_addrs & (RTA_DST|RTA_GATEWAY)) == (RTA_DST|RTA_GATEWAY))
               && sa_tab[RTAX_DST]->sa_family == AF_INET
               && sa_tab[RTAX_GATEWAY]->sa_family == AF_INET) {
                
                if(((struct sockaddr_in *)sa_tab[RTAX_DST])->sin_addr.s_addr == 0) {
                    char ifName[128];
                    if_indextoname(rt->rtm_index,ifName);
                    
                    if(strcmp([DEFAULT_WIFI_INTERFACE UTF8String], ifName) == 0){
                        
                        *addr = ((struct sockaddr_in *)(sa_tab[RTAX_GATEWAY]))->sin_addr.s_addr;
                        r = 0;
                    }
                }
            }
        }
        free(buf);
    }
    return r;
}

-(NSString*) getRouterIP {
    struct in_addr gatewayaddr;
    int r = [self getDefaultGateway:(&(gatewayaddr.s_addr))];
    if (r >= 0) {
        return [NSString stringWithUTF8String:inet_ntoa(gatewayaddr)];
    }
    
    return @"";
}

//-(NSString*) getCurrentWifiSSID {
//#if TARGET_IPHONE_SIMULATOR
//    return @"Sim_err_SSID_NotSupported";
//#else
//    NSString *data = nil;
//    CFDictionaryRef dict = CNCopyCurrentNetworkInfo((CFStringRef) DEFAULT_WIFI_INTERFACE);
//    if (dict) {
//        deb(@"AP Wifi: %@", dict);
//        data = [NSString stringWithString:(NSString *)CFDictionaryGetValue(dict, @"SSID")];
//        CFRelease(dict);
//    }
//
//    if (data == nil) {
//        data = @"none";
//    }
//
//    return data;
//#endif
//}

@end
