#ifndef __QSOUND_VB_H__
#define __QSOUND_VB_H__

#include <stdtype.h>

typedef INT32 DEV_SMPL;

void qsoundv_update(void* param, UINT32 samples, DEV_SMPL** outputs);
void* device_start_qsound_vb(UINT32* retSampleRate);
void device_stop_qsound_vb(void* info);
void device_reset_qsound_vb(void* info);

UINT8 qsoundv_r(void* info, UINT8 offset);
void qsoundv_w(void* info, UINT8 offset, UINT8 data);
void qsoundv_write_data(void* info, UINT8 address, UINT16 data);

void qsoundv_alloc_rom(void* info, UINT32 memsize);
void qsoundv_write_rom(void* info, UINT32 offset, UINT32 length, const UINT8* data);
void qsoundv_set_mute_mask(void* info, UINT32 MuteMask);

#endif	// __QSOUND_VB_H__
