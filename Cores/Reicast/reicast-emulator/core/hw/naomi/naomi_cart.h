#ifndef NAOMI_CART_H
#define NAOMI_CART_H

#include "types.h"

bool naomi_cart_Read(u32 offset, u32 size, void* dst);
void* naomi_cart_GetPtr(u32 offset, u32 size);
bool naomi_cart_SelectFile(void* handle);

#endif //NAOMI_CART_H
