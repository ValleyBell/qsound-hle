// QSound DL-1425 emulation
// ------------------------
// Valley Bell, May 2018
// ported from a disassembly of the QSound DSP program ROM dl-1425.bin
//
// Thanks to superctr for documenting all the RAM offsets.
#include <stdlib.h>
#include <string.h>	// for memset

#include <stdtype.h>
#include "qsound_vb.h"


#ifndef INLINE
#if defined(_MSC_VER)
#define INLINE	static __inline
#elif defined(__GNUC__)
#define INLINE	static __inline__
#else
#define INLINE	static inline
#endif
#endif	// INLINE
INLINE UINT32 pow2_mask(UINT32 v)
{
	UINT8 i;
	for (i = 0; i < 32 && (1 << i) < v; i ++)
		;
	return (1 << i) - 1;
}


typedef struct qsound_chip QSOUND_CHIP;


static const INT16* get_filter_table_1(UINT16 offset);
static const INT16* get_filter_table_2(UINT16 offset);
static INT16 dsp_get_sample(QSOUND_CHIP* chip, UINT16 bank, UINT16 ofs);
INLINE void INC_MODULO(UINT16* reg, UINT16 rb, UINT16 re);
INLINE INT32 DSP_ROUND(INT32 value);
static void dsp_do_update_step(QSOUND_CHIP* chip);
static void dsp_update_delay(QSOUND_CHIP* chip);
static void dsp_update_test(QSOUND_CHIP* chip);	// ROM: 0018
static void dsp_copy_mode1_fir_data(QSOUND_CHIP* chip);	// ROM: 0039
static void dsp_copy_mode2_fir_data(QSOUND_CHIP* chip);	// ROM: 004F
static void dsp_mode1_init(QSOUND_CHIP* chip);	// ROM: 0288
static void dsp_mode2_init(QSOUND_CHIP* chip);	// ROM: 061A
static void dsp_recalculate_delay(QSOUND_CHIP* chip, UINT16 refreshFlagAddr);	// ROM: 05DD / 099B
static void dsp_update_mode_1(QSOUND_CHIP* chip);	// ROM: 0314
static void dsp_update_mode_2(QSOUND_CHIP* chip);	// ROM: 06B2
static void dsp_update_adpcm(QSOUND_CHIP* chip, UINT8 chn, UINT8 nibble);
static void dsp_update_pcm(QSOUND_CHIP* chip);	// ROM: 050A/08A8
static void dsp_sample_calc_1(QSOUND_CHIP* chip);	// ROM: 0504
static void dsp_sample_calc_2(QSOUND_CHIP* chip);	// ROM: 08A2
static void dsp_sample_speaker_calc_1(QSOUND_CHIP* chip, UINT8 spkr, INT32 a1);	// ROM: 0572/05A9
static void dsp_sample_speaker_calc_2(QSOUND_CHIP* chip, UINT8 spkr, INT32 a1);	// ROM: 0910/0957


typedef void (*UPDATE_FUNC)(QSOUND_CHIP* chip);
struct qsound_chip
{
	UINT16 ram[0x800];	// DSP RAM, 2048 words, 16-bit each
	
	UINT8* romData;
	UINT32 romSize;
	UINT32 romMask;
	
	INT16 testInc;	// test mode increment (Y register)
	INT16 testOut;	// test mode output value (A0 register)
	UINT16 dataLatch;
	UINT8 busyState;
	INT16 out[2];
	
	UINT16 dspRoutine;	// offset of currently running update routine
	UINT8 dspRtStep;	// each routine outputs 6 samples before restarting, this indicates the current sample
	UPDATE_FUNC updateFunc;
	
	UINT32 muteMask;
};


// ---- routine offsets ----
// The routine to be executed can be selected externally by writing to OFS_ROUTINE.
//
// initialization routines
#define DSPRT_INIT1		0x0288	// default initialization routine
#define DSPRT_INIT2		0x061A	// alternate initialization routine
// refresh filter data, then start update
#define DSPRT_DO_TEST1	0x000C	// test routine - low-frequency sawtooth
#define DSPRT_DO_TEST2	0x000F	// test routine - high-frequency sawtooth
#define DSPRT_DO_UPD1	0x0039
#define DSPRT_DO_UPD2	0x004F
// update routines
#define DSPRT_TEST		0x0018	// test routine, outputs a sawtooth wave, doesn't do any additonal processing
#define DSPRT_UPDATE1	0x0314	// default update routine
#define DSPRT_UPDATE2	0x06B2	// alternate update routine


// ---- RAM offsets ----
#define OFS_CHANNEL_MEM		0x000	// 000-07F, 16 channels, 8 words per channel
	#define OFS_CH_BANK			0x000
	#define OFS_CH_CUR_ADDR		0x001
	#define OFS_CH_RATE			0x002
	#define OFS_CH_FRAC			0x003
	#define OFS_CH_LOOP_LEN		0x004
	#define OFS_CH_END_ADDR		0x005
	#define OFS_CH_VOLUME		0x006
#define OFS_PAN_POS			0x080	// 080-092, 16+3 channels, offset into DSP ROM pan table for left speaker
#define OFS_REVERB_FB_VOL	0x093	// Reverb feedback volume
// 094-0B9 are unused
#define OFS_CH_REVERB		0x0BA	// 0BA-0C9, 16 channels

#define OFS_ADPCM_ST_ADDR	0x0CA	// 0CA-0D5, 3 ADPCM channels, 4 words per channel
#define OFS_ADPCM_END_ADDR	0x0CB
#define OFS_ADPCM_BANK		0x0CC
#define OFS_ADPCM_VOLUME	0x0CD
#define OFS_ADPCM_CH_PLAY	0x0D6	// 0D6-0D8, 3 ADPCM channels, non-zero value starts ADPCM playback

#define OFS_DELAYBUF_END	0x0D9	// subtract with OFS_Mx_DELAY_BUF for reverb delay length

#define OFS_FIR_LPOS		0x0DA	// left filter A select
#define OFS_FIR1_LPOS		OFS_FIR_LPOS
#define OFS_FIR2_LPOS		0x0DB	// left filter B select
#define OFS_FIR_RPOS		0x0DC	// right filter A select
#define OFS_FIR1_RPOS		OFS_FIR_RPOS
#define OFS_FIR2_RPOS		0x0DD	// right filter B select
#define OFS_WET_LDELAY		0x0DE	// left filtered phase delay
#define OFS_DRY_LDELAY		0x0DF	// left raw phase delay
#define OFS_WET_RDELAY		0x0E0	// right filtered phase delay
#define OFS_DRY_RDELAY		0x0E1	// right raw phase delay

#define OFS_DELAY_REFRESH	0x0E2	// set to 1 to request recalculation of wet/dry delay
#define OFS_ROUTINE			0x0E3	// offset of DSP ROM sample processing routine

#define OFS_WET_LVOL		0x0E4	// volume for left speaker filtered part
#define OFS_DRY_LVOL		0x0E5	// volume for left speaker unfiltered part
#define OFS_WET_RVOL		0x0E6	// volume for right speaker filtered part
#define OFS_DRY_RVOL		0x0E7	// volume for right speaker unfiltered part

// **** End of Z80 communication registers ***

#define OFS_ADPCM_CUR_VOL	0x0E8	// 0E8-0EA, 3 channels
#define OFS_ADPCM_SIGNAL	0x0EB	// 0EB-0EE, 3 channels
#define OFS_ADPCM_CUR_ADDR	0x0F1	// 0F1-0F3, 3 channels
#define OFS_ADPCM_STEP		0x0F4	// 0F4-0F6, 3 channels

#define OFS_PAN_RPOS		0x0F7	// 0F7-109, 16+3 channels, offset cache for right speaker (== RAM[OFS_PAN_POS]+2*98)
#define OFS_CH_SMPLDATA		0x10A	// 10A-11C, 16+3 channels, caches (sampleData * channelVolume)
#define OFS_ACH_SMPLDATA	0x11A	// ADPCM data

#define OFS_RAW_OUT			0x11E	// raw / non filtered output

#define OFS_DELAYBUF_POS	0x11F
#define OFS_REV_OUTBUF_POS	0x120	// position of some delay buffer for the reverb output
#define OFS_REVERB_OUTPUT	0x121
#define OFS_REVERB_LASTSAMP	0x122	// Last value from the filter buffer, used to smooth the reverb output

#define OFS_FIR_LBPOS		0x123	// ring buffer position, left channel
#define OFS_FIR_RBPOS		0x124	// ring buffer position, right channel
#define OFS_WET_LBUF_W		0x125	// write pointer
#define OFS_WET_LBUF_R		0x126	// read pointer
#define OFS_DRY_LBUF_W		0x127	// write pointer
#define OFS_DRY_LBUF_R		0x128	// read pointer
#define OFS_WET_RBUF_W		0x129	// write pointer
#define OFS_WET_RBUF_R		0x12A	// read pointer
#define OFS_DRY_RBUF_W		0x12B	// write pointer
#define OFS_DRY_RBUF_R		0x12C	// read pointer

#define DW_BUF_SIZE		0x033		// dry/wet buffer size
#define OFS_WET_LBUF		0x12D	// 12D-15F, delay line for left filtered output
#define OFS_DRY_LBUF		0x160	// 160-192, delay line for left unfiltered output
#define OFS_WET_RBUF		0x193	// 193-1C5, delay line for left filtered output
#define OFS_DRY_RBUF		0x1C6	// 1C6-1F8, delay line for left unfiltered output
#define OFS_WET_LBEND		(OFS_WET_LBUF + DW_BUF_SIZE - 1)
#define OFS_DRY_LBEND		(OFS_DRY_LBUF + DW_BUF_SIZE - 1)
#define OFS_WET_RBEND		(OFS_WET_RBUF + DW_BUF_SIZE - 1)
#define OFS_DRY_RBEND		(OFS_DRY_RBUF + DW_BUF_SIZE - 1)

#define OFS_M1_FIR_LBUF		0x1F9	// 1F9-256, tapped delay line for the left channel FIR filter
#define OFS_M1_FIR_RBUF		0x257	// 257-2B4, tapped delay line for the right channel FIR filter
#define OFS_M1_FIR_LTBL		0x2B5	// 2B5-313, coefficients for the left channel FIR filter
#define OFS_M1_FIR_RTBL		0x314	// 314-372, coefficients for the right channel FIR filter
#define OFS_M1_REV_OUTBUF	0x373	// 373-553, reverb output buffer. Only written to, never read ?
#define OFS_M1_DELAY_BUF	0x554	// 554-7FF

// for mode 2, the "unfiltered" output actually goes through another filter.
#define OFS_M2_FIR2_LBPOS	0x1F9	// ring buffer position
#define OFS_M2_FIR2_RBPOS	0x1FA	// used for the second filter
#define OFS_M2_FIR1_LBUF	0x1FB	// 1FB-226
#define OFS_M2_FIR1_RBUF	0x227	// 227-252
#define OFS_M2_FIR2_LBUF	0x253	// 253-27D
#define OFS_M2_FIR2_RBUF	0x27E	// 27E-2A8
#define OFS_M2_FIR1_LTBL	0x2A9	// 2A9-2D5
#define OFS_M2_FIR2_LTBL	0x2D6	// 2D6-301
#define OFS_M2_FIR1_RTBL	0x302	// 302-32E
#define OFS_M2_FIR2_RTBL	0x32F	// 32F-35A
#define OFS_M2_REV_OUTBUF	0x35B	// 35B-53B
#define OFS_M2_DELAY_BUF	0x53C	// 53C-7FF


// ---- lookup tables ----
#define PANTBL_LEFT_OUTPUT	0
#define PANTBL_LEFT_FILTER	1
#define PANTBL_RIGHT_OUTPUT	2
#define PANTBL_RIGHT_FILTER	3
static const INT16 PAN_TABLES[4][0x62] =
{
	{	// left channel output (ROM: 0110)
		0xC000, 0xC000, 0xC000, 0xC000, 0xC000, 0xC000, 0xC000, 0xC000,
		0xC000, 0xC000, 0xC000, 0xC000, 0xC000, 0xC000, 0xC000, 0xC000,
		0xC000, 0xC666, 0xCCCD, 0xD28F, 0xD70A, 0xDC29, 0xDEB8, 0xE3D7,
		0xE7AE, 0xEB96, 0xEE14, 0xF148, 0xF333, 0xF571, 0xF7AE, 0xF8F6,
		0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		
		0xC005, 0xC02E, 0xC07F, 0xC0F9, 0xC19B, 0xC264, 0xC355, 0xC46D,
		0xC5AA, 0xC70C, 0xC893, 0xCA3D, 0xCC09, 0xCDF6, 0xD004, 0xD22F,
		0xD22F, 0xD478, 0xD6DD, 0xD95B, 0xDBF3, 0xDEA1, 0xE164, 0xE43B,
		0xE724, 0xEA1C, 0xED23, 0xF035, 0xF352, 0xF676, 0xF9A1, 0xFCCF,
		0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		0x0000, 0x0000
	},
	{	// left channel filter (ROM: 0172)
		0x0000, 0xF99A, 0xF852, 0xF666, 0xF47B, 0xF28F, 0xF000, 0xEDC3,
		0xECCD, 0xEC00, 0xEA8F, 0xE800, 0xE28F, 0xDD81, 0xDB85, 0xD99A,
		0xD800, 0xD7AE, 0xD70A, 0xD6B8, 0xD666, 0xD1EC, 0xD000, 0xD000,
		0xCF0A, 0xCE98, 0xCE14, 0xCDE3, 0xCD71, 0xCCCD, 0xCB96, 0xC8F6,
		0xC000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		
		0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		0x0000, 0x0000
	},
	{	// right channel output (ROM: 01D4)
		0x0000, 0xF8F6, 0xF7AE, 0xF571, 0xF333, 0xF148, 0xEE14, 0xEB96,
		0xE7AE, 0xE3D7, 0xDEB8, 0xDC29, 0xD70A, 0xD28F, 0xCCCD, 0xC666,
		0xC000, 0xC000, 0xC000, 0xC000, 0xC000, 0xC000, 0xC000, 0xC000,
		0xC000, 0xC000, 0xC000, 0xC000, 0xC000, 0xC000, 0xC000, 0xC000,
		0xC000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		
		0x0000, 0xFCCF, 0xF9A1, 0xF676, 0xF352, 0xF035, 0xED23, 0xEA1C,
		0xE724, 0xE43B, 0xE164, 0xDEA1, 0xDBF3, 0xD95B, 0xD6DD, 0xD478,
		0xD22F, 0xD22F, 0xD004, 0xCDF6, 0xCC09, 0xCA3D, 0xC893, 0xC70C,
		0xC5AA, 0xC46D, 0xC355, 0xC264, 0xC19B, 0xC0F9, 0xC07F, 0xC02E,
		0xC005, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		0x0000, 0x0000
	},
	{	// right channel filter (ROM: 0236)
		0xC000, 0xC8F6, 0xCB96, 0xCCCD, 0xCD71, 0xCDE3, 0xCE14, 0xCE98,
		0xCF0A, 0xD000, 0xD000, 0xD1EC, 0xD666, 0xD6B8, 0xD70A, 0xD7AE,
		0xD800, 0xD99A, 0xDB85, 0xDD81, 0xE28F, 0xE800, 0xEA8F, 0xEC00,
		0xECCD, 0xEDC3, 0xF000, 0xF28F, 0xF47B, 0xF666, 0xF852, 0xF99A,
		0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		
		0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		0x0000, 0x0000
	}
};

static const INT16 LUT_09D2[] =
{	// ROM: 09D2
	0, 13061, -573, 573, -14665, 30602, -1146, 1146, 1264, 0
};

static const INT16 LUT_ADPCM_SHIFT[] =
{	// ROM: 09DC
	154, 154, 128, 102,  77,  58,  58,  58,
	// ROM: 09E4
	 58,  58,  58,  58,  77, 102, 128, 154
};

static const INT16 FILTER_LUT_MODE1[6][95] =
{
	{	// ROM: 0D53
		0x0000, 0x0000, 0x0000, 0x0006, 0x002C, 0xFFE8, 0xFFCB, 0xFFF6,
		0x003B, 0xFFD8, 0xFFE5, 0x0001, 0x0027, 0xFFE5, 0x0038, 0x007F,
		0x00AE, 0x0024, 0xFFF3, 0x0031, 0x00D4, 0x008E, 0x008F, 0xFFB7,
		0xFFEC, 0x0042, 0xFF94, 0xFF8B, 0xFE71, 0xFEF7, 0xFE78, 0xFDC7,
		0xFE27, 0xFFB9, 0x005F, 0xFEC1, 0xFF26, 0xFF1A, 0x014B, 0x027E,
		0x01C1, 0x01DD, 0xFF4C, 0x0214, 0x0453, 0x02EE, 0x26AB, 0x0EF4,
		0xF68E, 0x042F, 0xFF50, 0x00BF, 0xFE51, 0x0040, 0x0075, 0xFF6A,
		0xFEEE, 0xFF9F, 0xFF12, 0x00A5, 0x00A6, 0x00FA, 0xFFED, 0x0004,
		0x0025, 0x00CC, 0x00BA, 0xFFFA, 0x008C, 0xFFB3, 0xFFFF, 0x0001,
		0x0012, 0xFFF6, 0xFF69, 0xFF6B, 0xFF99, 0xFFF7, 0x0037, 0x0017,
		0xFF9A, 0xFF9F, 0xFFF5, 0x000D, 0xFFD0, 0xFFE5, 0x0005, 0x0012,
		0xFFC3, 0xFFE2, 0x0040, 0x0048, 0x0000, 0x0000, 0x0000
	},
	{	// ROM: 0DB2
		0x0000, 0x0000, 0x0000, 0x0055, 0x0018, 0xFFB4, 0xFF85, 0xFFAA,
		0xFFE3, 0xFFF2, 0xFFEC, 0xFFF9, 0x0006, 0xFFE4, 0xFFA9, 0xFFA7,
		0xFFFB, 0x0064, 0x009A, 0x00A0, 0x0096, 0x0076, 0x0029, 0xFFD0,
		0xFFB2, 0xFFE9, 0x003B, 0x0053, 0xFFFE, 0xFF50, 0xFEB3, 0xFEA8,
		0xFF35, 0xFFBE, 0xFFD9, 0x0002, 0x00E0, 0x01EF, 0x01EF, 0x0118,
		0x01B0, 0x053C, 0x09B3, 0x1501, 0x0771, 0x0292, 0x0000, 0x0061,
		0x015B, 0x011D, 0x0023, 0xFFA1, 0xFFB2, 0xFFAE, 0xFF69, 0xFF40,
		0xFF55, 0xFF6B, 0xFF6D, 0xFF8F, 0xFFEA, 0x0047, 0x0076, 0x0081,
		0x007F, 0x006E, 0x0047, 0x001F, 0x0014, 0x0024, 0x002E, 0x0017,
		0xFFE5, 0xFFC1, 0xFFCB, 0xFFEB, 0xFFED, 0xFFC4, 0xFFA4, 0xFFBB,
		0xFFF4, 0x0019, 0x001D, 0x001E, 0x0028, 0x0029, 0x001D, 0x001E,
		0x002E, 0x0027, 0xFFF1, 0xFFB6, 0x0000, 0x0000, 0x0000
	},
	{	// ROM: 0E11
		0x0000, 0x0000, 0x0000, 0x0017, 0x002A, 0x002F, 0x001D, 0x000A,
		0x0002, 0xFFF2, 0xFFCA, 0xFFA4, 0xFFA3, 0xFFBA, 0xFFC0, 0xFFB3,
		0xFFC7, 0x0012, 0x005E, 0x0071, 0x0057, 0x0045, 0x0043, 0x0032,
		0x0019, 0x001D, 0x003A, 0x003E, 0x0018, 0xFFD9, 0xFF7D, 0xFF00,
		0xFEBB, 0xFF16, 0xFFD3, 0x003A, 0x004E, 0x00DF, 0x01E5, 0x01F0,
		0x007F, 0x0006, 0x0359, 0x08EB, 0x0A7B, 0x1340, 0x0530, 0x0084,
		0x004F, 0x013A, 0x00BD, 0xFFB0, 0xFFA6, 0x0023, 0xFFEB, 0xFF46,
		0xFF3D, 0xFF9D, 0xFF78, 0xFEFE, 0xFF43, 0x0052, 0x0101, 0x00B9,
		0x0035, 0x0029, 0x0054, 0x0044, 0x0026, 0x003F, 0x004D, 0x000E,
		0xFFC4, 0xFFB9, 0xFFB9, 0xFF88, 0xFF69, 0xFFAC, 0x000E, 0x001D,
		0xFFF8, 0x0007, 0x0042, 0x0045, 0x000C, 0xFFFD, 0x0036, 0x005C,
		0x0034, 0xFFFA, 0xFFF1, 0xFFFE, 0x0000, 0x0000, 0x0000
	},
	{	// ROM: 0E70
		0x0000, 0x0000, 0x0000, 0x0002, 0xFFE4, 0xFFDB, 0xFFEF, 0x0000,
		0xFFF7, 0xFFEA, 0xFFFD, 0x0023, 0x0034, 0x0027, 0x0014, 0x0007,
		0xFFFA, 0x0002, 0x0037, 0x0079, 0x0081, 0x0043, 0x0008, 0x0001,
		0x0009, 0xFFFA, 0xFFF0, 0x0010, 0x0042, 0x0060, 0x0076, 0x0082,
		0x004B, 0xFFD1, 0xFFA4, 0x002B, 0x00DF, 0x00EF, 0x0097, 0x00DB,
		0x01B8, 0x01DB, 0x00E2, 0x00CE, 0x03AC, 0x0834, 0x0A67, 0x1374,
		0x0361, 0x0031, 0xFFDF, 0x00BA, 0x00E7, 0x0067, 0x002A, 0x0072,
		0x00BF, 0x00B8, 0x0074, 0x001D, 0xFFD1, 0xFFB8, 0xFFEB, 0x003C,
		0x0060, 0x0044, 0x001F, 0x0020, 0x003F, 0x0057, 0x004C, 0x0027,
		0x0007, 0x000E, 0x0037, 0x0055, 0x0043, 0x0012, 0xFFF4, 0xFFFD,
		0x0015, 0x0022, 0x001D, 0x0006, 0xFFE5, 0xFFCF, 0xFFDB, 0xFFFE,
		0x0010, 0x0000, 0xFFEB, 0xFFF0, 0x0000, 0x0000, 0x0000
	},
	{	// ROM: 0ECF
		0x0000, 0x0000, 0x0000, 0x0030, 0x0007, 0xFFEA, 0xFFE3, 0xFFF6,
		0x0018, 0x0036, 0x003B, 0x001D, 0xFFDC, 0xFF8B, 0xFF47, 0xFF2B,
		0xFF47, 0xFF9D, 0x000D, 0x005A, 0x0053, 0x0018, 0xFFFB, 0x0017,
		0x0035, 0x002F, 0x0026, 0x0038, 0x0043, 0x0039, 0x004B, 0x006B,
		0x0010, 0xFF0E, 0xFE48, 0xFE9D, 0xFF88, 0xFFDF, 0xFFD1, 0x0098,
		0x01F5, 0x01D8, 0xFFC7, 0xFEDC, 0x0220, 0x0791, 0x08E5, 0x1801,
		0x04D8, 0x0099, 0x002F, 0x00C8, 0x0098, 0x0024, 0x0040, 0x0086,
		0x004A, 0xFFAE, 0xFF30, 0xFEF6, 0xFEF4, 0xFF44, 0xFFD6, 0x0041,
		0x004A, 0x0038, 0x0059, 0x0085, 0x0072, 0x002C, 0xFFFD, 0xFFFF,
		0x0011, 0x001D, 0x001D, 0xFFFE, 0xFFB4, 0xFF64, 0xFF45, 0xFF69,
		0xFFAB, 0xFFE1, 0xFFFB, 0x0007, 0x0014, 0x0020, 0x0018, 0xFFFB,
		0xFFEC, 0x0006, 0x0030, 0x003E, 0x0000, 0x0000, 0x0000
	},
	{	// ROM: 0F2E
		0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
	}
};

static const INT16 FILTER_LUT_MODE2[95] =
{
	// ROM: 0F73
	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
	0x0000, 0x0000, 0xFE8D, 0xFF3C, 0xFEF4, 0xFE00, 0xFED1, 0xFEC5,
	0xFF48, 0xFFB4, 0x0114, 0xFF00, 0x012A, 0x00C4, 0x03DE, 0x00EC,
	0x045A, 0xFF82, 0x1119, 0x1995, 0x0317,
	0x0000, 0x0000, 0x0000, 0x0000,
	// ROM: 0FA4
	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
	0x0000, 0x0000, 0x0000, 0xC000,
	0x0000, 0x0000
};


static const INT16* get_filter_table_1(UINT16 offset)
{
	size_t tblIdx;
	
	if (offset < 0x0D53)
		return NULL;
	offset -= 0x0D53;
	if ((offset % 95) > 0)
		return NULL;
	tblIdx = offset / 95;
	if (tblIdx >= 6)
		return NULL;
	return FILTER_LUT_MODE1[tblIdx];	// return beginning of one of the tables
}

static const INT16* get_filter_table_2(UINT16 offset)
{
	if (offset < 0x0F73)
		return NULL;
	offset -= 0x0F73;
	if (offset >= 95)
		return NULL;
	return &FILTER_LUT_MODE2[offset];	// return pointer to table data
}

static INT16 dsp_get_sample(QSOUND_CHIP* chip, UINT16 bank, UINT16 ofs)
{
	UINT32 romOfs;
	UINT8 smplData;
	
	if (! chip->romMask)
		return 0;	// no ROM loaded
	if (! (bank & 0x8000))
		return 0;	// ignore attempts to read from DSP program ROM
	bank &= 0x7FFF;
	romOfs = (bank << 16) | (ofs << 0);
	
	smplData = chip->romData[romOfs & chip->romMask];
	return (INT16)((smplData << 8) | (smplData << 0));	// MAME currently expands the 8 bit ROM data to 16 bits this way.
}

INLINE void INC_MODULO(UINT16* reg, UINT16 rb, UINT16 re)
{
	if (*reg == re)
		*reg = rb;
	else
		(*reg) ++;
	return;
}

INLINE INT32 DSP_ROUND(INT32 value)
{
	return (value + 0x8000) & ~0xFFFF;
}

static void dsp_do_update_step(QSOUND_CHIP* chip)
{
	do
	{
		switch(chip->ram[OFS_ROUTINE])
		{
		case DSPRT_INIT1:
			dsp_mode1_init(chip);
			break;
		case DSPRT_INIT2:
			dsp_mode2_init(chip);
			break;
		case DSPRT_DO_TEST1:	// ROM: 000C
			chip->testInc = 0x0001;
			chip->ram[OFS_ROUTINE] = DSPRT_TEST;
			break;
		case DSPRT_DO_TEST2:	// ROM: 000F
			chip->testInc = 0x0400;
			chip->ram[OFS_ROUTINE] = DSPRT_TEST;
			break;
		case DSPRT_DO_UPD1:
			dsp_copy_mode1_fir_data(chip);
			break;
		case DSPRT_DO_UPD2:
			dsp_copy_mode2_fir_data(chip);
			break;
		case DSPRT_TEST:
			chip->updateFunc = dsp_update_test;
			break;
		case DSPRT_UPDATE1:
			chip->updateFunc = dsp_update_mode_1;
			break;
		case DSPRT_UPDATE2:
			chip->updateFunc = dsp_update_mode_2;
			break;
		default:	// handle invalid routines
			chip->ram[OFS_ROUTINE] = DSPRT_INIT1;
			break;
		}
	} while(chip->updateFunc == dsp_do_update_step);
	
	chip->dspRtStep = 0;
	chip->updateFunc(chip);
	return;
}

static void dsp_update_delay(QSOUND_CHIP* chip)
{
	if (chip->dspRtStep > 0)
		chip->dspRtStep --;
	else
		chip->updateFunc = dsp_do_update_step;
	
	return;
}

static void dsp_update_test(QSOUND_CHIP* chip)	// ROM: 0018
{
	if (chip->dspRtStep == 0)
	{
		chip->testOut += chip->testInc;	// saturation is disabled here
		
		// ---- Note: The DSP program processes external commands here. ---
		chip->busyState = 0;
	}
	
	chip->out[0] = chip->testOut;
	chip->out[1] = chip->testOut;
	
	chip->dspRtStep ++;
	if (chip->dspRtStep >= 2)
	{
		chip->dspRtStep -= 2;
		chip->updateFunc = dsp_do_update_step;
	}
	return;
}

static void dsp_copy_mode1_fir_data(QSOUND_CHIP* chip)	// ROM: 0039
{
	const INT16* filterTbl;
	
	filterTbl = get_filter_table_1(chip->ram[OFS_FIR_LPOS]);
	if (filterTbl != NULL)
		memcpy(&chip->ram[OFS_M1_FIR_LTBL], filterTbl, 95 * sizeof(INT16));
	
	filterTbl = get_filter_table_1(chip->ram[OFS_FIR_RPOS]);
	if (filterTbl != NULL)
		memcpy(&chip->ram[OFS_M1_FIR_RTBL], filterTbl, 95 * sizeof(INT16));
	
	chip->ram[OFS_ROUTINE] = DSPRT_UPDATE1;
	return;
}

static void dsp_copy_mode2_fir_data(QSOUND_CHIP* chip)	// ROM: 004F
{
	const INT16* filterTbl;
	
	filterTbl = get_filter_table_2(chip->ram[OFS_FIR1_LPOS]);
	if (filterTbl != NULL)
		memcpy(&chip->ram[OFS_M2_FIR1_LTBL], filterTbl, 45 * sizeof(INT16));
	filterTbl = get_filter_table_2(chip->ram[OFS_FIR2_LPOS]);
	if (filterTbl != NULL)
		memcpy(&chip->ram[OFS_M2_FIR2_LTBL], filterTbl, 44 * sizeof(INT16));
	
	filterTbl = get_filter_table_2(chip->ram[OFS_FIR1_RPOS]);
	if (filterTbl != NULL)
		memcpy(&chip->ram[OFS_M2_FIR1_RTBL], filterTbl, 45 * sizeof(INT16));
	filterTbl = get_filter_table_2(chip->ram[OFS_FIR2_RPOS]);
	if (filterTbl != NULL)
		memcpy(&chip->ram[OFS_M2_FIR2_RTBL], filterTbl, 44 * sizeof(INT16));
	
	chip->ram[OFS_ROUTINE] = DSPRT_UPDATE2;
	return;
}

static void dsp_mode1_init(QSOUND_CHIP* chip)	// ROM: 0288
{
	UINT8 curChn;
	
	memset(chip->ram, 0x00, 0x800);
	chip->ram[OFS_ROUTINE] = DSPRT_UPDATE1;
	
	for (curChn = 0; curChn < 19; curChn ++)
		chip->ram[OFS_PAN_POS + curChn] = 0x0120;	// pan = centre
	chip->ram[OFS_FIR_LBPOS] = OFS_M1_FIR_LBUF;
	chip->ram[OFS_FIR_RBPOS] = OFS_M1_FIR_RBUF;
	chip->ram[OFS_REV_OUTBUF_POS] = OFS_M1_REV_OUTBUF;
	chip->ram[OFS_DELAYBUF_POS] = OFS_M1_DELAY_BUF;
	chip->ram[OFS_DELAYBUF_END] = OFS_M1_DELAY_BUF + 6;
	chip->ram[OFS_WET_LBUF_W] = OFS_WET_LBUF;
	chip->ram[OFS_DRY_LBUF_W] = OFS_DRY_LBUF;
	chip->ram[OFS_WET_RBUF_W] = OFS_WET_RBUF;
	chip->ram[OFS_DRY_RBUF_W] = OFS_DRY_RBUF;
	
	chip->ram[OFS_WET_LDELAY] = 0x0000;
	chip->ram[OFS_DRY_LDELAY] = 0x002E;
	chip->ram[OFS_WET_RDELAY] = 0x0000;
	chip->ram[OFS_DRY_RDELAY] = 0x0030;
	dsp_recalculate_delay(chip, OFS_DELAY_REFRESH);
	chip->ram[OFS_WET_LVOL] = 0x3FFF;
	chip->ram[OFS_DRY_LVOL] = 0x3FFF;
	chip->ram[OFS_WET_RVOL] = 0x3FFF;
	chip->ram[OFS_DRY_RVOL] = 0x3FFF;
	for (curChn = 0; curChn < 16; curChn ++)
		chip->ram[OFS_CH_BANK + curChn * 0x08] = 0x8000;
	
	chip->ram[OFS_ADPCM_BANK + 0x00] = 0x8000;
	chip->ram[OFS_ADPCM_BANK + 0x04] = 0x8000;
	chip->ram[OFS_ADPCM_BANK + 0x08] = 0x8000;
	chip->ram[OFS_FIR_LPOS] = 0x0DB2;	// FILTER_LUT_MODE1[1]
	chip->ram[OFS_FIR_RPOS] = 0x0E11;	// FILTER_LUT_MODE1[2]
	
	dsp_copy_mode1_fir_data(chip);
	chip->dspRtStep = 4;
	chip->updateFunc = dsp_update_delay;	// simulate the DSP being busy for 4 samples
	return;
}

static void dsp_mode2_init(QSOUND_CHIP* chip)	// ROM: 061A
{
	UINT8 curChn;
	
	memset(chip->ram, 0x00, 0x800);
	chip->ram[OFS_ROUTINE] = DSPRT_UPDATE2;
	
	for (curChn = 0; curChn < 19; curChn ++)
		chip->ram[OFS_PAN_POS + curChn] = 0x0120;	// pan = centre
	chip->ram[OFS_FIR_LBPOS] = OFS_M2_FIR1_LBUF;
	chip->ram[OFS_FIR_RBPOS] = OFS_M2_FIR1_RBUF;
	chip->ram[OFS_M2_FIR2_LBPOS] = OFS_M2_FIR2_LBUF;
	chip->ram[OFS_M2_FIR2_RBPOS] = OFS_M2_FIR2_RBUF;
	chip->ram[OFS_REV_OUTBUF_POS] = OFS_M2_REV_OUTBUF;
	chip->ram[OFS_DELAYBUF_POS] = OFS_M2_DELAY_BUF;
	chip->ram[OFS_DELAYBUF_END] = OFS_M2_DELAY_BUF + 6;
	chip->ram[OFS_WET_LBUF_W] = OFS_WET_LBUF;
	chip->ram[OFS_DRY_LBUF_W] = OFS_DRY_LBUF;
	chip->ram[OFS_WET_RBUF_W] = OFS_WET_RBUF;
	chip->ram[OFS_DRY_RBUF_W] = OFS_DRY_RBUF;
	
	chip->ram[OFS_WET_LDELAY] = 0x0001;
	chip->ram[OFS_DRY_LDELAY] = 0x0000;
	chip->ram[OFS_WET_RDELAY] = 0x0000;
	chip->ram[OFS_DRY_RDELAY] = 0x0000;
	dsp_recalculate_delay(chip, OFS_DELAY_REFRESH);
	chip->ram[OFS_WET_LVOL] = 0x3FFF;
	chip->ram[OFS_DRY_LVOL] = 0x3FFF;
	chip->ram[OFS_WET_RVOL] = 0x3FFF;
	chip->ram[OFS_DRY_RVOL] = 0x3FFF;
	for (curChn = 0; curChn < 16; curChn ++)
		chip->ram[OFS_CH_BANK + curChn * 0x08] = 0x8000;
	
	chip->ram[OFS_ADPCM_BANK + 0x00] = 0x8000;
	chip->ram[OFS_ADPCM_BANK + 0x04] = 0x8000;
	chip->ram[OFS_ADPCM_BANK + 0x08] = 0x8000;
	chip->ram[OFS_FIR1_LPOS] = 0x0F73;
	chip->ram[OFS_FIR2_LPOS] = 0x0FA4;
	chip->ram[OFS_FIR1_RPOS] = 0x0F73;
	chip->ram[OFS_FIR2_RPOS] = 0x0FA4;
	
	dsp_copy_mode2_fir_data(chip);
	chip->dspRtStep = 4;
	chip->updateFunc = dsp_update_delay;	// simulate the DSP being busy for 4 samples
	return;
}

static void dsp_recalculate_delay(QSOUND_CHIP* chip, UINT16 refreshFlagAddr)	// ROM: 05DD / 099B
{
	// Note: Subroutines 05DD and 099B are identical, except for a varying amount of NOPs at the end of the routines.
	UINT8 curFilter;
	UINT16 temp;
	
	for (curFilter = 0; curFilter < 4; curFilter ++)
	{
		temp = chip->ram[OFS_WET_LBUF_W + curFilter * 2] - chip->ram[OFS_WET_LDELAY + curFilter];
		if (temp < 301 + curFilter * 51)
			temp += 51;
		chip->ram[OFS_WET_LBUF_R + curFilter * 2] = temp;
	}
	
	chip->ram[refreshFlagAddr] = 0;
	return;
}

static void dsp_update_mode_1(QSOUND_CHIP* chip)	// ROM: 0314
{
	if (chip->dspRtStep < 3)
		dsp_update_adpcm(chip, chip->dspRtStep - 0, 0);
	else
		dsp_update_adpcm(chip, chip->dspRtStep - 3, 1);
	dsp_sample_calc_1(chip);
	
	chip->dspRtStep ++;
	if (chip->dspRtStep >= 6)
	{
		chip->dspRtStep -= 6;
		chip->updateFunc = dsp_do_update_step;
	}
	return;
}

static void dsp_update_mode_2(QSOUND_CHIP* chip)	// ROM: 06B2
{
	if (chip->dspRtStep < 3)
		dsp_update_adpcm(chip, chip->dspRtStep - 0, 0);
	else
		dsp_update_adpcm(chip, chip->dspRtStep - 3, 1);
	dsp_sample_calc_2(chip);
	
	chip->dspRtStep ++;
	if (chip->dspRtStep >= 6)
	{
		chip->dspRtStep -= 6;
		chip->updateFunc = dsp_do_update_step;
	}
	return;
}

static void dsp_update_adpcm(QSOUND_CHIP* chip, UINT8 chn, UINT8 nibble)
{
	UINT16 chn4 = chn * 4;
	INT16 x, y, z;
	INT32 a1;
	INT32 p;
	
	if (! nibble)
	{
		// process high nibble
		// ROM: 0314/036F/03CA
		if (chip->ram[OFS_ADPCM_CUR_ADDR + chn] == chip->ram[OFS_ADPCM_END_ADDR + chn4])
			chip->ram[OFS_ADPCM_CUR_VOL + chn] = 0;
		// ROM 0322/037D/03D8
		if (chip->ram[OFS_ADPCM_CH_PLAY + chn] != 0)
		{
			chip->ram[OFS_ACH_SMPLDATA + chn] = 0;
			chip->ram[OFS_ADPCM_CH_PLAY + chn] = 0;
			chip->ram[OFS_ADPCM_SIGNAL + chn] = 0x000A;
			chip->ram[OFS_ADPCM_CUR_VOL + chn] = chip->ram[OFS_ADPCM_VOLUME + chn4];
			chip->ram[OFS_ADPCM_CUR_ADDR + chn] = chip->ram[OFS_ADPCM_ST_ADDR + chn4];
		}
		// ROM: 0333/038E/03E9
		//chip->ram[OFS_ADPCM_CUR_ADDR + chn] = chip->ram[OFS_ADPCM_CUR_ADDR + chn];
		x = dsp_get_sample(chip, chip->ram[OFS_ADPCM_BANK + chn4], chip->ram[OFS_ADPCM_CUR_ADDR + chn]);
		x = (INT16)(x << 0) >> 12;	// high nibble of high byte, sign-extended
	}
	else
	{
		// process low nibble
		// ROM: 0425/0470/04B4
		x = dsp_get_sample(chip, chip->ram[OFS_ADPCM_BANK + chn4], chip->ram[OFS_ADPCM_CUR_ADDR + chn]);
		chip->ram[OFS_ADPCM_CUR_ADDR + chn] ++;
		x = (INT16)(x << 4) >> 12;	// low nibble of high byte, sign-extended
	}
	chip->ram[OFS_ADPCM_STEP + chn] = x;
	p = x * (INT16)chip->ram[OFS_ADPCM_SIGNAL + chn];
	z = (INT16)chip->ram[OFS_ADPCM_SIGNAL + chn] >> 1;
	// ROM 034A/03A5/0400/0447/0492/04DD
	if (p <= 0)
		z = -z;
	a1 = chip->ram[OFS_ACH_SMPLDATA + chn] + p;
	x = chip->ram[OFS_ADPCM_CUR_VOL + chn];
	y = a1 + z;
	p = x * y;
	chip->ram[OFS_ACH_SMPLDATA + chn] = p >> 16;
	// ROM: 0354/03AF/040A/0451/049C/04E7
	x = LUT_ADPCM_SHIFT[0x08 + (INT16)chip->ram[OFS_ADPCM_STEP + chn]];
	p = x * (INT16)chip->ram[OFS_ADPCM_SIGNAL + chn];
	y = (p << 10) >> 16;
	if (y <= 1)
		y = 1;
	else if (y >= 2000)
		y = 2000;
	chip->ram[OFS_ADPCM_SIGNAL + chn] = y;
	
	return;
}

static void dsp_update_pcm(QSOUND_CHIP* chip)	// ROM: 050A/08A8
{
	INT32 p;
	UINT8 curChn;
	UINT16 curBank;
	UINT16 chnBase;
	INT64 addr;
	
	curBank = chip->ram[0x0078 + OFS_CH_BANK];
	for (curChn = 0, chnBase = OFS_CHANNEL_MEM; curChn < 16; curChn ++, chnBase += 0x08)
	{
		p = (INT16)chip->ram[chnBase + OFS_CH_VOLUME] * dsp_get_sample(chip, curBank, chip->ram[chnBase + OFS_CH_CUR_ADDR]);
		chip->ram[OFS_CH_SMPLDATA + curChn] = p >> 14;	// p*4 >> 16
		
		curBank = chip->ram[chnBase + OFS_CH_BANK];
		addr = chip->ram[chnBase + OFS_CH_RATE] << 4;
		addr += ((INT16)chip->ram[chnBase + OFS_CH_CUR_ADDR] << 16) | (chip->ram[chnBase + OFS_CH_FRAC] << 0);
		if ((addr >> 16) >= (INT16)chip->ram[chnBase + OFS_CH_END_ADDR])
			addr -= (chip->ram[chnBase + OFS_CH_LOOP_LEN] << 16);
		// The DSP's a0/a1 registers are 36 bits. The result is clamped when writing it back to RAM.
		if (addr > 0x7FFFFFFFLL)
			addr = 0x7FFFFFFFLL;
		else if (addr < -0x80000000LL)
			addr = -0x80000000LL;
		chip->ram[chnBase + OFS_CH_FRAC] = (addr >> 0) & 0xFFFF;
		chip->ram[chnBase + OFS_CH_CUR_ADDR] = (addr >> 16) & 0xFFFF;
	}
	
	return;
}

static void dsp_sample_calc_1(QSOUND_CHIP* chip)	// ROM: 0504
{
	INT16 x, y;
	INT32 a0, a1;
	INT32 p;
	UINT8 curChn;
	UINT16 tmpOfs;
	
	dsp_update_pcm(chip);	// ROM: 050A
	
	// ROM: 051E
	a1 = 0;
	for (curChn = 0; curChn < 16; curChn ++)
	{
		p = (INT16)chip->ram[OFS_CH_SMPLDATA + curChn] * (INT16)chip->ram[OFS_CH_REVERB + curChn];
		a1 += (p * 4);
	}
	tmpOfs = chip->ram[OFS_DELAYBUF_POS] & 0x7FF;
	a0 = (INT16)chip->ram[tmpOfs];
	y = (INT16)chip->ram[OFS_REVERB_LASTSAMP];
	chip->ram[OFS_REVERB_LASTSAMP] = a0;
	a0 = (a0 + y) >> 1;	// Note: addition has a 17-bit result
	y = a0;
	x = (INT16)chip->ram[OFS_REVERB_FB_VOL];
	chip->ram[OFS_REVERB_OUTPUT] = y;
	p = x * y;
	a1 += (p * 4);
	chip->ram[tmpOfs] = a1 >> 16;
	INC_MODULO(&tmpOfs, OFS_M1_DELAY_BUF, chip->ram[OFS_DELAYBUF_END]);
	chip->ram[OFS_DELAYBUF_POS] = tmpOfs;
	
	// ROM: 0538
	tmpOfs = chip->ram[OFS_REV_OUTBUF_POS] & 0x7FF;
	chip->ram[tmpOfs] = a0;
	INC_MODULO(&tmpOfs, OFS_M1_REV_OUTBUF, OFS_M1_DELAY_BUF - 1);
	chip->ram[OFS_REV_OUTBUF_POS] = tmpOfs;
	
	// ---- Note: The DSP program processes external commands here. ---
	chip->busyState = 0;
	
	// ---- left channel ----
	// ROM: 055E
	y = 0; p = 0; a0 = 0; a1 = 0;
	for (curChn = 0; curChn < 19; curChn ++)
	{
		UINT16 panPos;
		
		panPos = chip->ram[OFS_PAN_POS + curChn];
		a0 -= p*4;
		p = x * y;
		y = (INT16)chip->ram[OFS_CH_SMPLDATA + curChn];
		x = PAN_TABLES[PANTBL_LEFT_OUTPUT][panPos - 0x110];
		
		a1 -= p*4;
		p = x * y;
		y = (INT16)chip->ram[OFS_CH_SMPLDATA + curChn];
		x = PAN_TABLES[PANTBL_LEFT_FILTER][panPos - 0x110];
		
		chip->ram[OFS_PAN_RPOS + curChn] = panPos + 98 * 2;
	}
	a0 -= p*4;
	p = x * y;
	a1 -= p*4;
	a0 += (INT16)chip->ram[OFS_REVERB_OUTPUT] << 16;
	chip->ram[OFS_RAW_OUT] = a0 >> 16;
	
	dsp_sample_speaker_calc_1(chip, 0, a1);
	
	// ---- right channel ----
	// ROM: 059D
	y = 0; p = 0; a0 = 0; a1 = 0;
	for (curChn = 0; curChn < 19; curChn ++)
	{
		UINT16 panPos;
		
		//panPos = chip->ram[OFS_PAN_POS + curChn] + 98 * 2;
		panPos = chip->ram[OFS_PAN_RPOS + curChn];
		a0 -= p*4;
		p = x * y;
		y = (INT16)chip->ram[OFS_CH_SMPLDATA + curChn];
		x = PAN_TABLES[PANTBL_RIGHT_OUTPUT][panPos - 0x110 - 98 * 2];
		
		a1 -= p*4;
		p = x * y;
		y = (INT16)chip->ram[OFS_CH_SMPLDATA + curChn];
		x = PAN_TABLES[PANTBL_RIGHT_FILTER][panPos - 0x110 - 98 * 2];
	}
	a0 -= p*4;
	p = x * y;
	a1 -= p*4;
	a1 += (INT16)chip->ram[OFS_REVERB_OUTPUT] << 16;
	chip->ram[OFS_RAW_OUT] = a0 >> 16;
	
	dsp_sample_speaker_calc_1(chip, 1, a1);
	
	if (chip->ram[OFS_DELAY_REFRESH])
		dsp_recalculate_delay(chip, OFS_DELAY_REFRESH);
	
	return;
}

static void dsp_sample_calc_2(QSOUND_CHIP* chip)	// ROM: 08A2
{
	INT16 x, y;
	INT32 a0, a1;
	INT32 p;
	UINT8 curChn;
	UINT16 tmpOfs;
	
	dsp_update_pcm(chip);	// ROM: 08A8
	
	// ROM: 08BC
	a1 = 0;
	for (curChn = 0; curChn < 16; curChn ++)
	{
		p = (INT16)chip->ram[OFS_CH_SMPLDATA + curChn] * (INT16)chip->ram[OFS_CH_REVERB + curChn];
		a1 += (p * 4);
	}
	tmpOfs = chip->ram[OFS_DELAYBUF_POS] & 0x7FF;
	a0 = (INT16)chip->ram[tmpOfs];
	y = (INT16)chip->ram[OFS_REVERB_LASTSAMP];
	chip->ram[OFS_REVERB_LASTSAMP] = a0;
	a0 = (a0 + y) >> 1;	// Note: addition has a 17-bit result
	y = a0;
	x = (INT16)chip->ram[OFS_REVERB_FB_VOL];
	chip->ram[OFS_REVERB_OUTPUT] = y;
	p = x * y;
	a1 += (p * 4);
	chip->ram[tmpOfs] = a1 >> 16;
	INC_MODULO(&tmpOfs, OFS_M2_DELAY_BUF, chip->ram[OFS_DELAYBUF_END]);
	chip->ram[OFS_DELAYBUF_POS] = tmpOfs;
	
	// ROM: 08D6
	tmpOfs = chip->ram[OFS_REV_OUTBUF_POS] & 0x7FF;
	chip->ram[tmpOfs] = a0;
	INC_MODULO(&tmpOfs, OFS_M2_REV_OUTBUF, OFS_M2_DELAY_BUF - 1);
	chip->ram[OFS_REV_OUTBUF_POS] = tmpOfs;
	
	// ---- Note: The DSP program processes external commands here. ---
	chip->busyState = 0;
	
	// ---- left channel ----
	// ROM: 08FC
	y = 0; p = 0; a0 = 0; a1 = 0;
	for (curChn = 0; curChn < 19; curChn ++)
	{
		UINT16 panPos;
		
		panPos = chip->ram[OFS_PAN_POS + curChn];
		a0 -= p*4;
		p = x * y;
		y = (INT16)chip->ram[OFS_CH_SMPLDATA + curChn];
		x = PAN_TABLES[PANTBL_LEFT_OUTPUT][panPos - 0x110];
		
		a1 -= p*4;
		p = x * y;
		y = (INT16)chip->ram[OFS_CH_SMPLDATA + curChn];
		x = PAN_TABLES[PANTBL_LEFT_FILTER][panPos - 0x110];
		
		chip->ram[OFS_PAN_RPOS + curChn] = panPos + 98 * 2;
	}
	a0 -= p*4;
	p = x * y;
	a1 -= p*4;
	a0 += (INT16)chip->ram[OFS_REVERB_OUTPUT] << 16;
	chip->ram[OFS_RAW_OUT] = a0 >> 16;
	
	dsp_sample_speaker_calc_2(chip, 0, a1);
	
	// ---- right channel ----
	// ROM: 094B
	y = 0; p = 0; a0 = 0; a1 = 0;
	for (curChn = 0; curChn < 19; curChn ++)
	{
		UINT16 panPos;
		
		//panPos = chip->ram[OFS_PAN_POS + curChn] + 98 * 2;
		panPos = chip->ram[OFS_PAN_RPOS + curChn];
		a0 -= p*4;
		p = x * y;
		y = (INT16)chip->ram[OFS_CH_SMPLDATA + curChn];
		x = PAN_TABLES[PANTBL_RIGHT_OUTPUT][panPos - 0x110 - 98 * 2];
		
		a1 -= p*4;
		p = x * y;
		y = (INT16)chip->ram[OFS_CH_SMPLDATA + curChn];
		x = PAN_TABLES[PANTBL_RIGHT_FILTER][panPos - 0x110 - 98 * 2];
	}
	a0 -= p*4;
	p = x * y;
	a1 -= p*4;
	a1 += (INT16)chip->ram[OFS_REVERB_OUTPUT] << 16;
	chip->ram[OFS_RAW_OUT] = a0 >> 16;
	
	dsp_sample_speaker_calc_2(chip, 1, a1);
	
	if (chip->ram[OFS_DELAY_REFRESH])
		dsp_recalculate_delay(chip, OFS_DELAY_REFRESH);
	
	return;
}

static void dsp_sample_speaker_calc_1(QSOUND_CHIP* chip, UINT8 spkr, INT32 a1)	// ROM: 0572/05A9
{
	UINT8 spkr2 = spkr * 2;
	UINT8 spkr4 = spkr * 4;
	UINT16 OFS_FIR_TBL;
	UINT16 OFS_FIR_BUF;
	UINT16 OFS_FIR_BEND;
	UINT16 OFS_WET_BUF;
	UINT16 OFS_WET_BEND;
	UINT16 OFS_DRY_BUF;
	UINT16 OFS_DRY_BEND;
	INT16 x, y;
	INT32 a0;
	INT32 p;
	UINT16 tmpOfs, tmpOf2;
	UINT8 firStep;
	
	if (! spkr)
	{
		OFS_FIR_TBL = OFS_M1_FIR_LTBL;
		OFS_FIR_BUF = OFS_M1_FIR_LBUF;
		OFS_FIR_BEND = OFS_M1_FIR_RBUF - 1;
		OFS_WET_BUF = OFS_WET_LBUF;
		OFS_WET_BEND = OFS_WET_LBEND;
		OFS_DRY_BUF = OFS_DRY_LBUF;
		OFS_DRY_BEND = OFS_DRY_LBEND;
	}
	else
	{
		OFS_FIR_TBL = OFS_M1_FIR_RTBL;
		OFS_FIR_BUF = OFS_M1_FIR_RBUF;
		OFS_FIR_BEND = OFS_M1_FIR_LTBL - 1;
		OFS_WET_BUF = OFS_WET_RBUF;
		OFS_WET_BEND = OFS_WET_RBEND;
		OFS_DRY_BUF = OFS_DRY_RBUF;
		OFS_DRY_BEND = OFS_DRY_RBEND;
	}
	
	// ROM: 0572/05A9
	tmpOf2 = OFS_FIR_TBL;
	tmpOfs = chip->ram[OFS_FIR_LBPOS + spkr] & 0x7FF;
	a0 = 0; p = 0;
	x = (INT16)chip->ram[tmpOf2];	tmpOf2 ++;
	y = (INT16)chip->ram[tmpOfs];	INC_MODULO(&tmpOfs, OFS_FIR_BUF, OFS_FIR_BEND);
	for (firStep = 0; firStep < 93; firStep ++)
	{
		a0 -= p*4;
		p = x * y;
		x = (INT16)chip->ram[tmpOf2];	tmpOf2 ++;
		y = (INT16)chip->ram[tmpOfs];	INC_MODULO(&tmpOfs, OFS_FIR_BUF, OFS_FIR_BEND);
	}
	a0 -= p*4;
	p = x * y;
	x = (INT16)chip->ram[tmpOf2];	tmpOf2 ++;
	y = a1 >> 16;
	a0 -= p*4;
	p = x * y;
	chip->ram[tmpOfs] = y;	INC_MODULO(&tmpOfs, OFS_FIR_BUF, OFS_FIR_BEND);
	chip->ram[OFS_FIR_LBPOS + spkr] = tmpOfs;
	
	// ROM: 0582/05BA
	a0 -= p*4;
	x = (INT16)chip->ram[OFS_WET_LVOL + spkr2];
	tmpOfs = chip->ram[OFS_WET_LBUF_W + spkr4] & 0x7FF;
	chip->ram[tmpOfs] = a0 >> 16;	INC_MODULO(&tmpOfs, OFS_WET_BUF, OFS_WET_BEND);
	chip->ram[OFS_WET_LBUF_W + spkr4] = tmpOfs;
	
	tmpOfs = chip->ram[OFS_WET_LBUF_R + spkr4] & 0x7FF;
	y = (INT16)chip->ram[tmpOfs];	INC_MODULO(&tmpOfs, OFS_WET_BUF, OFS_WET_BEND);
	p = x * y;
	x = (INT16)chip->ram[OFS_DRY_LVOL + spkr2];
	a0 = p*4;
	y = (INT16)chip->ram[OFS_RAW_OUT];
	chip->ram[OFS_WET_LBUF_R + spkr4] = tmpOfs;
	
	tmpOfs = chip->ram[OFS_DRY_LBUF_W + spkr4] & 0x7FF;
	chip->ram[tmpOfs] = y;	INC_MODULO(&tmpOfs, OFS_DRY_BUF, OFS_DRY_BEND);
	chip->ram[OFS_DRY_LBUF_W + spkr4] = tmpOfs;
	
	tmpOfs = chip->ram[OFS_DRY_LBUF_R + spkr4] & 0x7FF;
	y = chip->ram[tmpOfs];	INC_MODULO(&tmpOfs, OFS_DRY_BUF, OFS_DRY_BEND);
	chip->ram[OFS_DRY_LBUF_R + spkr4] = tmpOfs;
	p = x * y;
	y = (INT16)chip->ram[tmpOfs];
	x = LUT_09D2[0];
	a0 += p*4;
	p = x * y;
	a0 = DSP_ROUND(a0);
	chip->out[spkr] = a0 >> 16;
	
	return;
}

static void dsp_sample_speaker_calc_2(QSOUND_CHIP* chip, UINT8 spkr, INT32 a1)	// ROM: 0910/0957
{
	UINT8 spkr2 = spkr * 2;
	UINT8 spkr4 = spkr * 4;
	UINT16 OFS_FIR_TBL;
	UINT16 OFS_FIR1_BUF;
	UINT16 OFS_FIR1_BEND;
	UINT16 OFS_FIR2_BUF;
	UINT16 OFS_FIR2_BEND;
	UINT16 OFS_WET_BUF;
	UINT16 OFS_WET_BEND;
	UINT16 OFS_DRY_BUF;
	UINT16 OFS_DRY_BEND;
	INT16 x, y;
	INT32 a0;
	INT32 p;
	UINT16 tmpOfs, tmpOf2;
	UINT8 firStep;
	
	if (! spkr)
	{
		OFS_FIR_TBL = OFS_M2_FIR1_LTBL;
		OFS_FIR1_BUF = OFS_M2_FIR1_LBUF;
		OFS_FIR1_BEND = OFS_M2_FIR1_RBUF - 1;
		OFS_FIR2_BUF = OFS_M2_FIR2_LBUF;
		OFS_FIR2_BEND = OFS_M2_FIR2_RBUF - 1;
		OFS_WET_BUF = OFS_WET_LBUF;
		OFS_WET_BEND = OFS_WET_LBEND;
		OFS_DRY_BUF = OFS_DRY_LBUF;
		OFS_DRY_BEND = OFS_DRY_LBEND;
	}
	else
	{
		OFS_FIR_TBL = OFS_M2_FIR1_RTBL;
		OFS_FIR1_BUF = OFS_M2_FIR1_RBUF;
		OFS_FIR1_BEND = OFS_M2_FIR2_LBUF - 1;
		OFS_FIR2_BUF = OFS_M2_FIR2_RBUF;
		OFS_FIR2_BEND = OFS_M2_FIR1_LTBL - 1;
		OFS_WET_BUF = OFS_WET_RBUF;
		OFS_WET_BEND = OFS_WET_RBEND;
		OFS_DRY_BUF = OFS_DRY_RBUF;
		OFS_DRY_BEND = OFS_DRY_RBEND;
	}
	
	// ROM: 0910/0957
	tmpOf2 = OFS_FIR_TBL;
	tmpOfs = chip->ram[OFS_FIR_LBPOS + spkr] & 0x7FF;
	a0 = 0; p = 0;
	x = (INT16)chip->ram[tmpOf2];	tmpOf2 ++;
	y = (INT16)chip->ram[tmpOfs];	INC_MODULO(&tmpOfs, OFS_FIR1_BUF, OFS_FIR1_BEND);
	for (firStep = 0; firStep < 43; firStep ++)
	{
		a0 -= p*4;
		p = x * y;
		x = (INT16)chip->ram[tmpOf2];	tmpOf2 ++;
		y = (INT16)chip->ram[tmpOfs];	INC_MODULO(&tmpOfs, OFS_FIR1_BUF, OFS_FIR1_BEND);
	}
	a0 -= p*4;
	p = x * y;
	x = (INT16)chip->ram[tmpOf2];	tmpOf2 ++;
	y = a1 >> 16;
	a0 -= p*4;
	p = x * y;
	a0 -= p*4;
	chip->ram[tmpOfs] = y;	INC_MODULO(&tmpOfs, OFS_FIR1_BUF, OFS_FIR1_BEND);
	chip->ram[OFS_FIR_LBPOS + spkr] = tmpOfs;
	
	// ROM: 0921/0969
	tmpOfs = chip->ram[OFS_M2_FIR2_LBPOS + spkr] & 0x7FF;
	a1 = 0; p = 0;
	x = (INT16)chip->ram[tmpOf2];	tmpOf2 ++;
	y = (INT16)chip->ram[tmpOfs];	INC_MODULO(&tmpOfs, OFS_FIR2_BUF, OFS_FIR2_BEND);
	for (firStep = 0; firStep < 42; firStep ++)
	{
		a1 -= p*4;
		p = x * y;
		x = (INT16)chip->ram[tmpOf2];	tmpOf2 ++;
		y = (INT16)chip->ram[tmpOfs];	INC_MODULO(&tmpOfs, OFS_FIR2_BUF, OFS_FIR2_BEND);
	}
	a1 -= p*4;
	p = x * y;
	x = (INT16)chip->ram[tmpOf2];	tmpOf2 ++;
	y = (INT16)chip->ram[OFS_RAW_OUT];
	a1 -= p*4;
	p = x * y;
	chip->ram[tmpOfs] = y;	INC_MODULO(&tmpOfs, OFS_FIR2_BUF, OFS_FIR2_BEND);
	chip->ram[OFS_M2_FIR2_LBPOS + spkr] = tmpOfs;
	
	// ROM: 0930/0978
	a1 -= p*4;
	x = (INT16)chip->ram[OFS_WET_LVOL + spkr2];
	tmpOfs = chip->ram[OFS_WET_LBUF_W + spkr4] & 0x7FF;
	chip->ram[tmpOfs] = a0 >> 16;	INC_MODULO(&tmpOfs, OFS_WET_BUF, OFS_WET_BEND);
	chip->ram[OFS_WET_LBUF_W + spkr4] = tmpOfs;
	
	tmpOfs = chip->ram[OFS_WET_LBUF_R + spkr4] & 0x7FF;
	y = (INT16)chip->ram[tmpOfs];	INC_MODULO(&tmpOfs, OFS_WET_BUF, OFS_WET_BEND);
	p = x * y;
	x = (INT16)chip->ram[OFS_DRY_LVOL + spkr2];
	a0 = p*4;
	y = (INT16)chip->ram[OFS_RAW_OUT];
	chip->ram[OFS_WET_LBUF_R + spkr4] = tmpOfs;
	
	tmpOfs = chip->ram[OFS_DRY_LBUF_W + spkr4] & 0x7FF;
	chip->ram[tmpOfs] = a1 >> 16;	INC_MODULO(&tmpOfs, OFS_DRY_BUF, OFS_DRY_BEND);
	chip->ram[OFS_DRY_LBUF_W + spkr4] = tmpOfs;
	
	tmpOfs = chip->ram[OFS_DRY_LBUF_R + spkr4] & 0x7FF;
	y = chip->ram[tmpOfs];	INC_MODULO(&tmpOfs, OFS_DRY_BUF, OFS_DRY_BEND);
	chip->ram[OFS_DRY_LBUF_R + spkr4] = tmpOfs;
	p = x * y;
	y = (INT16)chip->ram[tmpOfs];
	x = LUT_09D2[0];
	a0 += p*4;
	p = x * y;
	a0 = DSP_ROUND(a0);
	chip->out[spkr] = a0 >> 16;
	
	return;
}


void* device_start_qsound_vb(UINT32* retSampleRate)
{
	QSOUND_CHIP* chip;
	
	chip = (QSOUND_CHIP*)calloc(1, sizeof(QSOUND_CHIP));
	if (chip == NULL)
		return NULL;
	
	chip->romData = NULL;
	chip->romSize = 0x00;
	chip->romMask = 0x00;
	
	qsoundv_set_mute_mask(chip, 0x0000);
	
	*retSampleRate = 60000000 / 2 / 1248;
	
	return chip;
}

void device_stop_qsound_vb(void* info)
{
	QSOUND_CHIP* chip = (QSOUND_CHIP*)info;
	
	free(chip->romData);
	free(chip);
	
	return;
}

void device_reset_qsound_vb(void* info)
{
	QSOUND_CHIP* chip = (QSOUND_CHIP*)info;
	
	memset(chip->ram, 0x00, 0x800);
	chip->testInc = 0;
	chip->testOut = 0;
	chip->dataLatch = 0x0000;
	chip->busyState = 1;
	chip->out[0] = chip->out[1] = 0;
	chip->dspRoutine = DSPRT_INIT1;
	chip->dspRtStep = 0;
	chip->updateFunc = dsp_do_update_step;
	
	dsp_mode1_init(chip);
	
	return;
}

UINT8 qsoundv_r(void* info, UINT8 offset)
{
	QSOUND_CHIP* chip = (QSOUND_CHIP*)info;
	
	// ready bit (0x00 = busy, 0x80 == ready)
	return chip->busyState ? 0x00 : 0x80;
}

void qsoundv_w(void* info, UINT8 offset, UINT8 data)
{
	QSOUND_CHIP* chip = (QSOUND_CHIP*)info;
	
	switch (offset)
	{
	case 0:
		chip->dataLatch = (chip->dataLatch & 0x00FF) | (data << 8);
		break;
	case 1:
		chip->dataLatch = (chip->dataLatch & 0xFF00) | (data << 0);
		break;
	case 2:
		qsoundv_write_data(chip, data, chip->dataLatch);
		break;
	}
	
	return;
}

void qsoundv_write_data(void* info, UINT8 address, UINT16 data)
{
	QSOUND_CHIP* chip = (QSOUND_CHIP*)info;
	
	chip->ram[address] = data;
	chip->busyState = 1;
	
	return;
}

void qsoundv_update(void* param, UINT32 samples, DEV_SMPL** outputs)
{
	QSOUND_CHIP* chip = (QSOUND_CHIP*)param;
	UINT32 curSmpl;
	
	memset(outputs[0], 0, samples * sizeof(*outputs[0]));
	memset(outputs[1], 0, samples * sizeof(*outputs[1]));
	
	for (curSmpl = 0; curSmpl < samples; curSmpl ++)
	{
		chip->updateFunc(chip);
		outputs[0][curSmpl] = chip->out[0];
		outputs[1][curSmpl] = chip->out[1];
	}
	
	return;
}

void qsoundv_alloc_rom(void* info, UINT32 memsize)
{
	QSOUND_CHIP* chip = (QSOUND_CHIP*)info;
	
	if (chip->romSize == memsize)
		return;
	
	chip->romData = (UINT8*)realloc(chip->romData, memsize);
	chip->romSize = memsize;
	chip->romMask = pow2_mask(memsize);
	memset(chip->romData, 0xFF, memsize);
	
	return;
}

void qsoundv_write_rom(void* info, UINT32 offset, UINT32 length, const UINT8* data)
{
	QSOUND_CHIP* chip = (QSOUND_CHIP*)info;
	
	if (offset > chip->romSize)
		return;
	if (offset + length > chip->romSize)
		length = chip->romSize - offset;
	
	memcpy(chip->romData + offset, data, length);
	
	return;
}

void qsoundv_set_mute_mask(void* info, UINT32 MuteMask)
{
	QSOUND_CHIP* chip = (QSOUND_CHIP*)info;
	
	chip->muteMask = MuteMask;
	
	return;
}
