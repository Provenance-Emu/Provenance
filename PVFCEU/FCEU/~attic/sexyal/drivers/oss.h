void SexyALI_OSS_Enumerate(int (*func)(uint8_t *name, uint64_t id, void *udata), void *udata);
SexyAL_device *SexyALI_OSS_Open(uint64_t id, SexyAL_format *format, SexyAL_buffering *buffering);
int SexyALI_OSS_Close(SexyAL_device *device);
uint32_t SexyALI_OSS_RawWrite(SexyAL_device *device, void *data, uint32_t len);
uint32_t SexyALI_OSS_RawCanWrite(SexyAL_device *device);

