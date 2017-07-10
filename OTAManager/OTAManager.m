//
//  OTAManager.m
//  Mavic
//
//  Created by XiaoQiang on 2017/6/28.
//  Copyright © 2017年 LoHas-Tech. All rights reserved.
//

#import "OTAManager.h"
#import "YModem.h"
#import "DeviceManager.h"

@interface OTAManager ()
{
  int index_packet;
  int index_packet_cache;
}
@property (nonatomic, strong) DeviceManager *deviceManager;
@property (nonatomic, strong) NSArray  *packetArray;
@end

@implementation OTAManager

- (instancetype)init
{
  self = [super init];
  if (self) {
    self.status = OTAStatusNONE;
    index_packet = 0;
    index_packet_cache = -1;
  }
  return self;
}

#pragma mark - 下位机进入OTA模式
- (void)setFirmwareEnterOTAMode {
  // 让下位机进入OTA模式
  // 开始命令
  Byte byte4[] = {0x0a,0x05,0x0c,0x01,0x01,0x09,0xA5,0xA5,0xA5,0xA5,0xA5,0xA5,0xA5,0xA5,0xA5,0xA5,0xA5,0xA5,0xA5,0xf0};
  NSData *data23 = [NSData dataWithBytes:byte4 length:sizeof(byte4)];
  NSLog(@"Enter OTA Mode");
  [self.deviceManager.R_T_CB_Peripheral writeValue:data23 forCharacteristic:self.deviceManager.R_T_CB_Characteristic type:1];
}

#pragma mark - 下位机进入Ymodem数据下载模式
- (void)setFirmwareEnterYmodemDataDownloadMode {
  // 开始命令
  Byte byte4[] = {0x0a,0x06,0x0c,0x02,0x03,0x01,0x0A,0xA5,0xA5,0xA5,0xA5,0xA5,0xA5,0xA5,0xA5,0xA5,0xA5,0xA5,0xA5,0xf0};
  NSData *data23 = [NSData dataWithBytes:byte4 length:sizeof(byte4)];
  NSLog(@"Enter Ymodem Data Download Mode");
  [self.deviceManager.R_T_CB_Peripheral writeValue:data23 forCharacteristic:self.deviceManager.R_T_CB_Characteristic type:1];
}

#pragma mark - 下位机数据传输并处理
- (void)setFirmwareHandleOTADataWithOrderStatus:(OrderStatus)status completion:(void(^)(NSString *))complete {
  switch (status) {
    case OrderStatusC: {
      if (self.status == OTAStatusBinOrderDone) { // EOT 结束传输
        NSData *data = [self prepareEndPacket];
        
        NSInteger size = data.length;
        for (int i = 0; i<size; i++) {
          if (i%20==0) {
            NSInteger l = 20;
            if ((size-i) < 20) {
              l = size-i;
            }
            NSData *aData=[data subdataWithRange:NSMakeRange(i,l)];
            [self.deviceManager.R_T_CB_Peripheral writeValue:aData forCharacteristic:self.deviceManager.R_T_CB_Characteristic type:1];
            NSLog(@"EOT拆包");
            
            [NSThread sleepForTimeInterval:0.02];
          }
        }
        self.status = OTAStatusEnd;
        break;
      }
      if (self.status != OTAStatusFirstOrder) { // 发送第一个包：文件名+大小
        complete(@"OTA升级中...");
        NSLog(@"Head");
        
        NSData *data_first = [self prepareFirstPacketWithFileName:@"fw_updata.bin"];
        
        for (int i = 0; i<133; i++) {
          if (i%20==0) {
            NSInteger l = 20;
            if ((133-i) < 20) {
              l = 133-i;
            }
            NSData *aData=[data_first subdataWithRange:NSMakeRange(i,l)];
            [self.deviceManager.R_T_CB_Peripheral writeValue:aData forCharacteristic:self.deviceManager.R_T_CB_Characteristic type:1];
            
            [NSThread sleepForTimeInterval:0.02];
          }
        }
        self.status = OTAStatusFirstOrder;
      }
      else {
        if (self.status != OTAStatusBinOrder) { // 发送正式文件包第一包
          
          if (index_packet != index_packet_cache) {
            // 正式包数组
            if (!self.packetArray) {
              self.packetArray = [self preparePacketWithFileName:@"fw_updata.bin"];
            }
            NSData *data = self.packetArray[index_packet];
            // 拆包发送
            NSInteger size = data.length;
            for (int i = 0; i<size; i++) {
              if (i%20==0) {
                NSInteger l = 20;
                if ((size-i) < 20) {
                  l = size-i;
                }
                NSData *aData=[data subdataWithRange:NSMakeRange(i,l)];
                [self.deviceManager.R_T_CB_Peripheral writeValue:aData forCharacteristic:self.deviceManager.R_T_CB_Characteristic type:1];
                NSLog(@"拆包");
                
                [NSThread sleepForTimeInterval:0.02];
              }
            }
            NSLog(@"相比上次%d,第%d次传输", index_packet_cache,index_packet);
            index_packet_cache = index_packet;
            self.status = OTAStatusBinOrder;
          }
          
        }
        
      }
      break;
    }
    case OrderStatusACK: {
      if (self.status == OTAStatusBinOrder) { // 正式文件包开始第二包及之后的发送
        // 下一步传输
        NSLog(@"ACK");
        index_packet++;
        
        if (index_packet < self.packetArray.count) {
          if (index_packet != index_packet_cache) {
            // 正式包数组
            if (!self.packetArray) {
              self.packetArray = [self preparePacketWithFileName:@"fw_updata.bin"];
            }
            NSData *data = self.packetArray[index_packet];
            // 拆包发送
            NSInteger size = data.length;
            for (int i = 0; i<size; i++) {
              if (i%20==0) {
                NSInteger l = 20;
                if ((size-i) < 20) {
                  l = size-i;
                }
                NSData *aData=[data subdataWithRange:NSMakeRange(i,l)];
                [self.deviceManager.R_T_CB_Peripheral writeValue:aData forCharacteristic:self.deviceManager.R_T_CB_Characteristic type:1];
                NSLog(@"拆包");
                
                [NSThread sleepForTimeInterval:0.02];
              }
            }
            NSLog(@"相比上次%d,第%d次传输", index_packet_cache,index_packet);
            index_packet_cache = index_packet;
            self.status = OTAStatusBinOrder;
          }
        }
        else { // 所有正式文件包发送完成，发送结束OTA命令
          if (self.status != OTAStatusBinOrderDone) {
            Byte byte4[] = {0x04};
            NSData *data23 = [NSData dataWithBytes:byte4 length:sizeof(byte4)];
            NSLog(@"准备结束OTA");
            [self.deviceManager.R_T_CB_Peripheral writeValue:data23 forCharacteristic:self.deviceManager.R_T_CB_Characteristic type:1];
            
            self.status = OTAStatusBinOrderDone;
          }
          
        }
        
        
      }
      if (self.status == OTAStatusEnd) { // OTA完成，发送退出OTA模式命令
        complete(@"OTA升级完成");
        NSLog(@"OTA升级完成");
        
        // 退出OTA模式
        [self setFirmwareExitOTAMode];
      }
      break;
    }
    case OrderStatusCAN: { // 异常处理1：取消传输
      complete(@"OTA升级已取消");
      [self setFirmwareExitOTAMode];
      
      
      break;
    }
    case OrderStatusNAK: { // 异常处理2：出现错误
      complete(@"OTA升级出错");
      [self setFirmwareExitOTAMode];
      
      break;
    }
    default:
      break;
  }
}

#pragma mark - 下位机退出OTA模式
- (void)setFirmwareExitOTAMode {
  // 让下位机退出OTA模式
  // 开始命令
  Byte byte4[] = {0x0a,0x05,0x0c,0x01,0x02,0x0a,0xA5,0xA5,0xA5,0xA5,0xA5,0xA5,0xA5,0xA5,0xA5,0xA5,0xA5,0xA5,0xA5,0xf0};
  NSData *data23 = [NSData dataWithBytes:byte4 length:sizeof(byte4)];
  NSLog(@"Exit OTA Mode");
  [self.deviceManager.R_T_CB_Peripheral writeValue:data23 forCharacteristic:self.deviceManager.R_T_CB_Characteristic type:1];
}


#pragma mark - first
- (NSData *)prepareFirstPacketWithFileName:(NSString *)filename {
  // 文件名
  NSString *room_name = filename;
  NSData* bytes = [room_name dataUsingEncoding:NSUTF8StringEncoding];
  Byte * myByte = (Byte *)[bytes bytes];
  UInt8 buff_name[bytes.length+1];
  memcpy(buff_name, [room_name UTF8String],[room_name lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1);
  //|UTF8String|返回是包含\0的  |lengthOfBytesUsingEncoding|计算不包括\0 所以这里加上一
  
  // 文件大小
  NSMutableData *file = [[NSMutableData alloc]init];
  
  //    NSString *path=  [[NSBundle mainBundle]pathForResource:@"w3.bin" ofType:nil];
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *documentsDirectory = [paths objectAtIndex:0];
  NSString* path = [documentsDirectory stringByAppendingPathComponent:room_name];
  path = [[NSBundle mainBundle] pathForResource:room_name ofType:nil];
  
  file = [NSMutableData  dataWithContentsOfFile:path];
  uint32_t length = (uint32_t)file.length;
  
  // 发送SOH数据包
  // 生成包
  UInt8 *buff_data;
  buff_data = (uint8_t *)malloc(sizeof(uint8_t)*133);
  
  UInt8 *crc_data;
  crc_data = (uint8_t *)malloc(sizeof(uint8_t)*128);
  
  PrepareIntialPacket(buff_data, myByte, length);
  
  NSData *data_first = [NSData dataWithBytes:buff_data length:sizeof(uint8_t)*133];
  
  return data_first;
}

#pragma mark - 发送数据包
- (NSArray *)preparePacketWithFileName:(NSString *)filename {
  NSString *room_name = filename;
  NSString *path = [[NSBundle mainBundle] pathForResource:room_name ofType:nil];
  NSMutableData *file = [[NSMutableData alloc]init];
  file = [NSMutableData  dataWithContentsOfFile:path];
  
  uint32_t size = file.length>=PACKET_1K_SIZE?(PACKET_1K_SIZE):(PACKET_SIZE);
  
  // 拆包
  int index = 0;
  NSMutableArray *dataArray = [NSMutableArray array];
  for (int i = 0; i<file.length; i++) {
    if (i%size == 0) {
      index++;
      uint32_t len = size;
      if ((file.length-i)<size) {
        len = (uint32_t)file.length - i;
      }
      // 截取1024 或 128 长度数据
      NSData *sub_file_data = [file subdataWithRange:NSMakeRange(i, len)];
      
      uint32_t sub_size = PACKET_1K_SIZE;
      
      Byte *sub_file_byte = (Byte *)[sub_file_data bytes];
      uint8_t *p_packet;
      p_packet = (uint8_t *)malloc(sub_size+5);
      PreparePacket(sub_file_byte, p_packet, index, (uint32_t)sub_file_data.length);
      
      NSData *data_ = [NSData dataWithBytes:p_packet length:sizeof(uint8_t)*(sub_size+5)];
      [dataArray addObject:data_];
    }
  }
  
  return dataArray;
  
}

- (NSData *)prepareEndPacket {
  UInt8 *buff_data;
  buff_data = (uint8_t *)malloc(sizeof(uint8_t)*(PACKET_1K_SIZE+5));
  
  PrepareEndPacket(buff_data);
  NSData *data_first = [NSData dataWithBytes:buff_data length:sizeof(uint8_t)*(PACKET_1K_SIZE+5)];
  
  
  return data_first;
}

#pragma mark - properties
- (DeviceManager *)deviceManager {
  return [DeviceManager defaultManager];
}

@end
