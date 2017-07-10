//
//  YModem.c
//  Mavic
//
//  Created by XiaoQiang on 2017/6/28.
//  Copyright © 2017年 LoHas-Tech. All rights reserved.
//

#include "YModem.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include <limits.h>



#define SUCCESS 1

#define FAIL  0

int Status = SUCCESS;

void PrepareIntialPacket(uint8_t *p_data, const uint8_t *p_file_name, uint32_t length)
{
  uint32_t i, j = 0;
  char astring[10];
  
  /* first 3 bytes are constant */
  p_data[PACKET_START_INDEX] = SOH;
  p_data[PACKET_NUMBER_INDEX] = 0x00;
  p_data[PACKET_CNUMBER_INDEX] = 0xff;
  
  /* Filename written */
  for (i = 0; (p_file_name[i] != '\0') && (i < FILE_NAME_LENGTH); i++)
  {
    p_data[i + PACKET_DATA_INDEX] = p_file_name[i];
  }
  
  p_data[i + PACKET_DATA_INDEX] = 0x00;
  
  /* file size written */
//  Int2Str (astring, length);
  
  sprintf(astring,"%d", length);
  i = i + PACKET_DATA_INDEX + 1;
//  while (astring[j] != '\0')
//  {
//    p_data[i++] = astring[j++];
//  }
//  p_data[i] = length;
  
  for (int j=0; j<strlen(astring); j++) {
      int a = astring[j];
    p_data[i] = a;
    i++;
  }
  
  
  
  /* padding with zeros */
  for (j = i; j < PACKET_SIZE + PACKET_DATA_INDEX; j++)
  {
    p_data[j] = 0;
  }
  
  uint8_t *crc_data;
  crc_data = (uint8_t *)malloc(sizeof(uint8_t)*128);
  int index = 0;
  for (int i = 3; i<=130; i++) {
    crc_data[index] = p_data[i];
    index++;
  }
  
  uint16_t result = Cccal_CRC16(crc_data, 128);
  // 低位
  uint16_t resultL=result & 0xFF;
  // 高位
  uint16_t resultH=result >> 8;
  
  p_data[j] = resultH;
  p_data[j+1] = resultL;

}

void PreparePacket(uint8_t *p_source, uint8_t *p_packet, uint8_t pkt_nr, uint32_t size_blk)
{
  uint8_t *p_record;
  uint32_t i, size, packet_size;
  
  /* Make first three packet */
  packet_size = PACKET_1K_SIZE;// ? PACKET_1K_SIZE : PACKET_SIZE;
  size = size_blk < packet_size ? size_blk : packet_size;
  if (packet_size == PACKET_1K_SIZE)
  {
    p_packet[PACKET_START_INDEX] = STX;
  }
  else
  {
    p_packet[PACKET_START_INDEX] = SOH;
  }
  p_packet[PACKET_NUMBER_INDEX] = pkt_nr;
  p_packet[PACKET_CNUMBER_INDEX] = (~pkt_nr);
  p_record = p_source;
  
  /* Filename packet has valid data */
  for (i = PACKET_DATA_INDEX; i < size + PACKET_DATA_INDEX;i++)
  {
    p_packet[i] = *p_record++;
  }
  
  /* 空位补0x1A*/
  if ( size  <= packet_size)
  {
    for (i = size + PACKET_DATA_INDEX; i < packet_size + PACKET_DATA_INDEX; i++)
    {
      p_packet[i] = 0x1A; /* EOF (0x1A) or 0x00 */
    }
  }
  
  /* CRC校验 */
  uint8_t *crc_data;
  crc_data = (uint8_t *)malloc(sizeof(uint8_t)*packet_size);
  int index = 0;
  for (int j = 3; j<=packet_size+2; j++) {
    crc_data[index] = p_packet[j];
    index++;
  }
  
  uint16_t result = Cccal_CRC16(crc_data, packet_size);
  // 低位
  uint16_t resultL=result & 0xFF;
  // 高位
  uint16_t resultH=result >> 8;
  
  p_packet[i] = resultH;
  p_packet[i+1] = resultL;
}

void PrepareEndPacket(uint8_t *p_packet) {

  uint32_t i, packet_size;
  
  /* Make first three packet */
  packet_size = PACKET_1K_SIZE;// ? PACKET_1K_SIZE : PACKET_SIZE;
  if (packet_size == PACKET_1K_SIZE)
  {
    p_packet[PACKET_START_INDEX] = STX;
  }
  else
  {
    p_packet[PACKET_START_INDEX] = SOH;
  }
  p_packet[PACKET_NUMBER_INDEX] = 0x00;
  p_packet[PACKET_CNUMBER_INDEX] = 0xff;
  
  /* Filename packet has valid data */
  for (i = PACKET_DATA_INDEX; i < packet_size + PACKET_DATA_INDEX;i++)
  {
    p_packet[i] = 0x00;
  }
  
  /* CRC校验 */
  uint8_t *crc_data;
  crc_data = (uint8_t *)malloc(sizeof(uint8_t)*packet_size);
  int index = 0;
  for (int j = 3; j<=packet_size+2; j++) {
    crc_data[index] = p_packet[j];
    index++;
  }
  
  uint16_t result = Cccal_CRC16(crc_data, packet_size);
  // 低位
  uint16_t resultL=result & 0xFF;
  // 高位
  uint16_t resultH=result >> 8;
  
  p_packet[i] = resultH;
  p_packet[i+1] = resultL;
}

/**
 * @brief  Update CRC16 for input byte
 * @param  crc_in input value
 * @param  input byte
 * @retval None
 */
uint16_t UpdateCRC16(uint16_t crc_in, uint8_t byte)
{
  uint32_t crc = crc_in;
  uint32_t in = byte | 0x100;
  
  do
  {
    crc <<= 1;
    in <<= 1;
    if(in & 0x100)
      ++crc;
    if(crc & 0x10000)
      crc ^= 0x1021;
  }
  
  while(!(in & 0x10000));
  
  return crc & 0xffffu;
}

/**
 * @brief  Cal CRC16 for YModem Packet
 * @param  data
 * @param  length
 * @retval None
 */
uint16_t Cccal_CRC16(const uint8_t* p_data, uint32_t size)
{
  uint32_t crc = 0;
  const uint8_t* dataEnd = p_data+size;
  
  while(p_data < dataEnd)
    crc = UpdateCRC16(crc, *p_data++);
  
  crc = UpdateCRC16(crc, 0);
  crc = UpdateCRC16(crc, 0);
  
  return crc&0xffffu;
}
