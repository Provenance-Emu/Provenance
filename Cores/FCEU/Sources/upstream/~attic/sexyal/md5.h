#ifndef _MD5_H
#define _MD5_H

struct sal_md5_context
{
    uint32_t total[2];
    uint32_t state[4];
    uint8_t buffer[64];
};

void sal_md5_starts( struct sal_md5_context *ctx );
void sal_md5_update( struct sal_md5_context *ctx, uint8_t *input, uint32_t length );
void sal_md5_finish( struct sal_md5_context *ctx, uint8_t digest[16] );

#endif /* md5.h */
