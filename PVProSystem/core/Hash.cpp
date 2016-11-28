// ----------------------------------------------------------------------------
//   ___  ___  ___  ___       ___  ____  ___  _  _
//  /__/ /__/ /  / /__  /__/ /__    /   /_   / |/ /
// /    / \  /__/ ___/ ___/ ___/   /   /__  /    /  emulator
//
// ----------------------------------------------------------------------------
// Copyright 2005 Greg Stanton
// 
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
// ----------------------------------------------------------------------------
// Hash.cpp
// ----------------------------------------------------------------------------
#include "Hash.h"

// ----------------------------------------------------------------------------
// Step1
// ----------------------------------------------------------------------------
static uint hash_Step1(uint w, uint x, uint y, uint z, uint data, uint s) {
  w += (z ^ (x & (y ^ z))) + data;
  w = w << s | w >> (32 - s);
  w += x;
  return w;
}

// ----------------------------------------------------------------------------
// Step2
// ----------------------------------------------------------------------------
static uint hash_Step2(uint w, uint x, uint y, uint z, uint data, uint s) {
  w += (y ^ (z & (x ^ y))) + data;
  w = w << s | w >> (32 - s);
  w += x;
  return w;
}

// ----------------------------------------------------------------------------
// Step3
// ----------------------------------------------------------------------------
static uint hash_Step3(uint w, uint x, uint y, uint z, uint data, uint s) {
  w += (x ^ y ^ z) + data;  
  w = w << s | w >> (32 - s);
  w += x;
  return w;
}

// ----------------------------------------------------------------------------
// Step4
// ----------------------------------------------------------------------------
static uint hash_Step4(uint w, uint x, uint y, uint z, uint data, uint s) {
  w += (y ^ (x | ~z)) + data;  
  w = w << s | w >> (32 - s);
  w += x;
  return w;
}    

// ----------------------------------------------------------------------------
// Transform
// ----------------------------------------------------------------------------
static void hash_Transform(uint out[4], uint in[16]) {
  uint a, b, c, d;

  a = out[0];
  b = out[1];
  c = out[2];
  d = out[3];

  a = hash_Step1(a, b, c, d, in[0] + 0xd76aa478, 7);
  d = hash_Step1(d, a, b, c, in[1] + 0xe8c7b756, 12);
  c = hash_Step1(c, d, a, b, in[2] + 0x242070db, 17);
  b = hash_Step1(b, c, d, a, in[3] + 0xc1bdceee, 22);
  a = hash_Step1(a, b, c, d, in[4] + 0xf57c0faf, 7);
  d = hash_Step1(d, a, b, c, in[5] + 0x4787c62a, 12);
  c = hash_Step1(c, d, a, b, in[6] + 0xa8304613, 17);
  b = hash_Step1(b, c, d, a, in[7] + 0xfd469501, 22);
  a = hash_Step1(a, b, c, d, in[8] + 0x698098d8, 7);
  d = hash_Step1(d, a, b, c, in[9] + 0x8b44f7af, 12);
  c = hash_Step1(c, d, a, b, in[10] + 0xffff5bb1, 17);
  b = hash_Step1(b, c, d, a, in[11] + 0x895cd7be, 22);
  a = hash_Step1(a, b, c, d, in[12] + 0x6b901122, 7);
  d = hash_Step1(d, a, b, c, in[13] + 0xfd987193, 12);
  c = hash_Step1(c, d, a, b, in[14] + 0xa679438e, 17);
  b = hash_Step1(b, c, d, a, in[15] + 0x49b40821, 22);

  a = hash_Step2(a, b, c, d, in[1] + 0xf61e2562, 5);
  d = hash_Step2(d, a, b, c, in[6] + 0xc040b340, 9);
  c = hash_Step2(c, d, a, b, in[11] + 0x265e5a51, 14);
  b = hash_Step2(b, c, d, a, in[0] + 0xe9b6c7aa, 20);
  a = hash_Step2(a, b, c, d, in[5] + 0xd62f105d, 5);
  d = hash_Step2(d, a, b, c, in[10] + 0x02441453, 9);
  c = hash_Step2(c, d, a, b, in[15] + 0xd8a1e681, 14);
  b = hash_Step2(b, c, d, a, in[4] + 0xe7d3fbc8, 20);
  a = hash_Step2(a, b, c, d, in[9] + 0x21e1cde6, 5);
  d = hash_Step2(d, a, b, c, in[14] + 0xc33707d6, 9);
  c = hash_Step2(c, d, a, b, in[3] + 0xf4d50d87, 14);
  b = hash_Step2(b, c, d, a, in[8] + 0x455a14ed, 20);
  a = hash_Step2(a, b, c, d, in[13] + 0xa9e3e905, 5);
  d = hash_Step2(d, a, b, c, in[2] + 0xfcefa3f8, 9);
  c = hash_Step2(c, d, a, b, in[7] + 0x676f02d9, 14);
  b = hash_Step2(b, c, d, a, in[12] + 0x8d2a4c8a, 20);

  a = hash_Step3(a, b, c, d, in[5] + 0xfffa3942, 4);
  d = hash_Step3(d, a, b, c, in[8] + 0x8771f681, 11);
  c = hash_Step3(c, d, a, b, in[11] + 0x6d9d6122, 16);
  b = hash_Step3(b, c, d, a, in[14] + 0xfde5380c, 23);
  a = hash_Step3(a, b, c, d, in[1] + 0xa4beea44, 4);
  d = hash_Step3(d, a, b, c, in[4] + 0x4bdecfa9, 11);
  c = hash_Step3(c, d, a, b, in[7] + 0xf6bb4b60, 16);
  b = hash_Step3(b, c, d, a, in[10] + 0xbebfbc70, 23);
  a = hash_Step3(a, b, c, d, in[13] + 0x289b7ec6, 4);
  d = hash_Step3(d, a, b, c, in[0] + 0xeaa127fa, 11);
  c = hash_Step3(c, d, a, b, in[3] + 0xd4ef3085, 16);
  b = hash_Step3(b, c, d, a, in[6] + 0x04881d05, 23);
  a = hash_Step3(a, b, c, d, in[9] + 0xd9d4d039, 4);
  d = hash_Step3(d, a, b, c, in[12] + 0xe6db99e5, 11);
  c = hash_Step3(c, d, a, b, in[15] + 0x1fa27cf8, 16);
  b = hash_Step3(b, c, d, a, in[2] + 0xc4ac5665, 23);

  a = hash_Step4(a, b, c, d, in[0] + 0xf4292244, 6);
  d = hash_Step4(d, a, b, c, in[7] + 0x432aff97, 10);
  c = hash_Step4(c, d, a, b, in[14] + 0xab9423a7, 15);
  b = hash_Step4(b, c, d, a, in[5] + 0xfc93a039, 21);
  a = hash_Step4(a, b, c, d, in[12] + 0x655b59c3, 6);
  d = hash_Step4(d, a, b, c, in[3] + 0x8f0ccc92, 10);
  c = hash_Step4(c, d, a, b, in[10] + 0xffeff47d, 15);
  b = hash_Step4(b, c, d, a, in[1] + 0x85845dd1, 21);
  a = hash_Step4(a, b, c, d, in[8] + 0x6fa87e4f, 6);
  d = hash_Step4(d, a, b, c, in[15] + 0xfe2ce6e0, 10);
  c = hash_Step4(c, d, a, b, in[6] + 0xa3014314, 15);
  b = hash_Step4(b, c, d, a, in[13] + 0x4e0811a1, 21);
  a = hash_Step4(a, b, c, d, in[4] + 0xf7537e82, 6);
  d = hash_Step4(d, a, b, c, in[11] + 0xbd3af235, 10);
  c = hash_Step4(c, d, a, b, in[2] + 0x2ad7d2bb, 15);
  b = hash_Step4(b, c, d, a, in[9] + 0xeb86d391, 21);

  out[0] += a;
  out[1] += b;
  out[2] += c;
  out[3] += d;
}

// ----------------------------------------------------------------------------
// Compute
// ----------------------------------------------------------------------------
std::string hash_Compute(const byte* source, uint length) {
  uint buffer1[4] = {0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476};
  uint buffer2[2] = {0};
  byte buffer3[64] = {0};

  uint temp = buffer2[0];
  if((buffer2[0] = temp + ((uint)length << 3)) < temp) {
	  buffer2[1]++;
  }
  buffer2[1] += length >> 29;

  temp = (temp >> 3) & 0x3f;
  if(temp) {
	  byte* ptr = (byte*)buffer3 + temp;
	  temp = 64 - temp;
	  if(length < temp) {
      for(uint index = 0; index < length; index++) {
        ptr[index] = source[index];
      }
	  }
	  
    for(uint index = 0; index < temp; index++) {
      ptr[index] = source[index];
    }

	  hash_Transform(buffer1, (uint*)buffer3);
	  source += temp;
	  length -= temp;
  }

  while(length >= 64) {
    for(uint index = 0; index < 64; index++) {
      buffer3[index] = source[index];
    }
	  hash_Transform(buffer1, (uint*)buffer3);
	  source += 64;
	  length -= 64;
  }

  for(uint index = 0; index < length; index++) {
    buffer3[index] = source[index];
  }

  uint count = (buffer2[0] >> 3) & 0x3f;
  byte* ptr = buffer3 + count;
  *ptr++ = 0x80;

  count = 63 - count;

  if(count < 8) {
    for(uint index = 0; index < count; index++) {
      ptr[index] = 0;
    }
	  hash_Transform(buffer1, (uint*)buffer3);
    
    for(uint index = 0; index < 56; index++) {
      buffer3[index] = 0;
    }
  } 
  else {
    for(uint index = 0; index < count - 8; index++) {
      ptr[index] = 0;
    }
  }

  ((uint*)buffer3)[14] = buffer2[0];
  ((uint*)buffer3)[15] = buffer2[1];

  hash_Transform(buffer1, (uint*)buffer3);
  
  byte digest[16];
  byte* bufferptr = (byte*)buffer1;
  for(uint index = 0; index < 16; index++) {
    digest[index] = bufferptr[index];
  }

  char buffer[33] = {0};
  sprintf(buffer, "%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x", digest[0], digest[1], digest[2], digest[3], digest[4], digest[5], digest[6], digest[7], digest[8], digest[9], digest[10], digest[11], digest[12], digest[13], digest[14], digest[15]);
  return std::string(buffer);
}

