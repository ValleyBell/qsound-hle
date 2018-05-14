; PIOC (Parallel I/O Control Register): always set to 0x3800/0x3820
;	bits   15  (0x8000): same as bit 4
;	bits 13-14 (0x6000) = 1: strobe 2T
;	bit    12  (0x1000) = 1: PODS is output
;	bit    11  (0x0800) = 1: PIDS is output
;	bit    10  (0x0400) = 0: Status/Control mode off
;	bit     9  (0x0200) = 0: IBF interrupt disabled
;	bit     8  (0x0100) = 0: OBE interrupt disabled
;	bit     7  (0x0080) = 0: PIDS interrupt disabled
;	bit     6  (0x0040) = 0: PODS interrupt disabled
;	bit     5  (0x0020) = 0/1: INT interrupt disabled/enabled
;	bit     4  (0x0010): IBF interrupt status
;	bit     3  (0x0008): OBE interrupt status
;	bit     2  (0x0004): PIDS interrupt status
;	bit     1  (0x0002): PODS interrupt status
;	bit     0  (0x0001): INT interrupt status
;
; SIOC (Serial I/O Control Register): always set to 0x02E8
;	bit   9  (0x0200) = 1: active ILD/OLD = OutCLK / 16, active SYNC = OutCLK/128 or OCK/256
;	bits 8-7 (0x0180) = 1: active clock = CKI / 12
;	bit   6  (0x0040) = 1; MSB first
;	bit   5  (0x0020) = 1: OutLoad is output
;	bit   4  (0x0010) = 0: InLoad is input
;	bit   3  (0x0008) = 1: OutCLK is output
;	bit   2  (0x0004) = 0: InCLK is input
;	bit   1  (0x0002) = 0: 16-bit output
;	bit   0  (0x0001) = 0: 16-bit input
;
; AUC (Arithmetic Unit Control Register): set to 0x02/0x08/0x0C
;	bit   6  (0x40) = 0; enable clearing YL
;	bit   5  (0x20) = 0: enable clearing A1L
;	bit   4  (0x10) = 0: enable clearing A0L
;	bit   3  (0x08) = 0/1: enable/disable A1 saturation on overflow
;	bit   2  (0x04) = 0/1: enable/disable A0 saturation on overflow
;	bits 0-1 (0x03) = 0/2: set alignment - 0: Ax = p, 2: Ax = p*4

	0:000: 0288       goto 0x0288	; main

interrupt:
	0:001: 5150 0001  c0 = 0x0001	; set interrupt counter to 1
	0:003: 45d0       a0 = pdx0
	0:004: 30c0       nop, *r0
	0:005: 30c0       nop, *r0
	0:006: 45d0       a0 = pdx0	; read destination offset
	0:007: 30c0       nop, *r0
	0:008: 30c0       nop, *r0
	0:009: 4800       r0 = a0
	0:00a: 61d0       *r0 = pdx0	; read data and write to destination
	0:00b: c100       ireturn
	
	0:00c: 5110 0001  y = 0x0001
	0:00e: 0011       goto 0x0011
	
	0:00f: 5110 0400  y = 0x0400
	0:011: 5130 000c  auc = 0x000c	; disable alignment, disable A0 saturation, disable A1 saturation
	0:013: 5020 00e3  move r2 = 0x00e3
	0:015: 5010 0018  move r1 = 0x0018
	0:017: 6018       *r2 = r1	; set main offset = 0x0018 update_dummy

update_dummy:
	0:018: 51c0 3820  pioc = 0x3820	; enable INT interrupts
	0:01a: 31a0       a0 = a0+y, *r0
	0:01b: 51c0 3800  pioc = 0x3800	; disable INT interrupts
	
	0:01d: 51e0 0000  pdx1 = 0x0000
	0:01f: 49a0       sdx = a0
	0:020: 717f       do 127 { 0x0021...0x0022 }
		0:021: 9e0e       a1 = a1>>1
		0:022: 9e0e       a1 = a1>>1
	
	0:023: 51d0 0000  pdx0 = 0x0000
	0:025: 49a0       sdx = a0
	0:026: 717f       do 127 { 0x0027...0x0028 }
		0:027: 9e0e       a1 = a1>>1
		0:028: 9e0e       a1 = a1>>1
	
	0:029: 51e0 0000  pdx1 = 0x0000
	0:02b: 49a0       sdx = a0
	0:02c: 717f       do 127 { 0x002d...0x002e }
		0:02d: 9e0e       a1 = a1>>1
		0:02e: 9e0e       a1 = a1>>1
	
	0:02f: 51d0 0000  pdx0 = 0x0000
	0:031: 49a0       sdx = a0
	0:032: 70ff       do 127 { 0x0033 }
		0:033: 9e0e       a1 = a1>>1
	0:034: 707f       redo 127
	0:035: 707f       redo 127
	0:036: 703f       redo 63
	0:037: 7898       pr = *r2	; return offset = (*0x00E3)
	0:038: c000       return
	
copy_filter_data_1:
	0:039: 5020 02b5  move r2 = 0x02b5
	0:03b: 5030 00da  move r3 = 0x00da
	0:03d: 788c       pt = *r3			; set ROM Table Pointer = *0x00DA
	0:03e: 715f       do 95 { 0x003f...0x0040 }	; loop for pt = *0x00DA..+0x5E, R2 = 0x02B5..0x313
		0:03f: c8c0       y = a0, x = *pt++	; X = ROM[*0x00DA + n]
		0:040: 6109       move *r2++ = x	; RAM[0x02B5 + n] = X
	
	0:041: 5020 0314  move r2 = 0x0314
	0:043: 5030 00dc  move r3 = 0x00dc
	0:045: 788c       pt = *r3			; set ROM Table Pointer = *0x00DC
	0:046: 715f       do 95 { 0x0047...0x0048 }	; loop for pt = *0x00DC..+0x5E, R2 = 0x02B5..0x313
		0:047: c8c0       y = a0, x = *pt++	; X = ROM[*0x00DC + n]
		0:048: 6109       move *r2++ = x	; RAM[0x0314 + n] = X
	
	0:049: 5020 00e3  move r2 = 0x00e3
	0:04b: 5030 0314  move r3 = 0x0314
	0:04d: 6038       *r2 = r3	; set main offset = 0x0314 update_loop_1
	0:04e: 0314       goto 0x0314	; update_loop_1

copy_filter_data_2:
	0:04f: 5020 02a9  move r2 = 0x02a9
	0:051: 5030 00da  move r3 = 0x00da
	0:053: 788d       pt = *r3++
	0:054: 712d       do 45 { 0x0055...0x0056 }
		0:055: c8c0       y = a0, x = *pt++
		0:056: 6109       move *r2++ = x
	
	0:057: 5020 02d6  move r2 = 0x02d6
	0:059: 788d       pt = *r3++
	0:05a: 712c       do 44 { 0x005b...0x005c }
		0:05b: c8c0       y = a0, x = *pt++
		0:05c: 6109       move *r2++ = x
	
	0:05d: 5020 0302  move r2 = 0x0302
	0:05f: 788d       pt = *r3++
	0:060: 712d       do 45 { 0x0061...0x0062 }
		0:061: c8c0       y = a0, x = *pt++
		0:062: 6109       move *r2++ = x
	
	0:063: 5020 032f  move r2 = 0x032f
	0:065: 788c       pt = *r3
	0:066: 712c       do 44 { 0x0067...0x0068 }
		0:067: c8c0       y = a0, x = *pt++
		0:068: 6109       move *r2++ = x
	
	0:069: 5020 00e3  move r2 = 0x00e3
	0:06b: 5030 06b2  move r3 = 0x06b2
	0:06d: 6038       *r2 = r3		; set main offset = 0x06B2 update_loop_2
	0:06e: 06b2       goto 0x06b2	; update_loop_2
	
	dw	dup (0x0000) times 0xA1

PanTable_FrontL:
0:110	dw	0xC000, 0xC000, 0xC000, 0xC000, 0xC000, 0xC000, 0xC000, 0xC000
0:118	dw	0xC000, 0xC000, 0xC000, 0xC000, 0xC000, 0xC000, 0xC000, 0xC000
0:120	dw	0xC000, 0xC666, 0xCCCD, 0xD28F, 0xD70A, 0xDC29, 0xDEB8, 0xE3D7
0:128	dw	0xE7AE, 0xEB96, 0xEE14, 0xF148, 0xF333, 0xF571, 0xF7AE, 0xF8F6
0:130	dw	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
0:138	dw	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000

0:140	dw	0xC005, 0xC02E, 0xC07F, 0xC0F9, 0xC19B, 0xC264, 0xC355, 0xC46D
0:148	dw	0xC5AA, 0xC70C, 0xC893, 0xCA3D, 0xCC09, 0xCDF6, 0xD004, 0xD22F
0:150	dw	0xD22F, 0xD478, 0xD6DD, 0xD95B, 0xDBF3, 0xDEA1, 0xE164, 0xE43B
0:158	dw	0xE724, 0xEA1C, 0xED23, 0xF035, 0xF352, 0xF676, 0xF9A1, 0xFCCF
0:160	dw	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
0:168	dw	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
0:170	dw	0x0000, 0x0000


0:172	dw	0x0000, 0xF99A, 0xF852, 0xF666, 0xF47B, 0xF28F, 0xF000, 0xEDC3
0:17A	dw	0xECCD, 0xEC00, 0xEA8F, 0xE800, 0xE28F, 0xDD81, 0xDB85, 0xD99A
0:182	dw	0xD800, 0xD7AE, 0xD70A, 0xD6B8, 0xD666, 0xD1EC, 0xD000, 0xD000
0:18A	dw	0xCF0A, 0xCE98, 0xCE14, 0xCDE3, 0xCD71, 0xCCCD, 0xCB96, 0xC8F6
0:192	dw	0xC000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
0:19A	dw	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000

0:1A2	dw	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
0:1AA	dw	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
0:1B2	dw	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
0:1BA	dw	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
0:1C2	dw	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
0:1CA	dw	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
0:1D2	dw	0x0000, 0x0000

PanTable_FrontR:
0:1D4	dw	0x0000, 0xF8F6, 0xF7AE, 0xF571, 0xF333, 0xF148, 0xEE14, 0xEB96
0:1DC	dw	0xE7AE, 0xE3D7, 0xDEB8, 0xDC29, 0xD70A, 0xD28F, 0xCCCD, 0xC666
0:1E4	dw	0xC000, 0xC000, 0xC000, 0xC000, 0xC000, 0xC000, 0xC000, 0xC000
0:1EC	dw	0xC000, 0xC000, 0xC000, 0xC000, 0xC000, 0xC000, 0xC000, 0xC000
0:1F4	dw	0xC000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
0:1FC	dw	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000

0:204	dw	0x0000, 0xFCCF, 0xF9A1, 0xF676, 0xF352, 0xF035, 0xED23, 0xEA1C
0:20C	dw	0xE724, 0xE43B, 0xE164, 0xDEA1, 0xDBF3, 0xD95B, 0xD6DD, 0xD478
0:214	dw	0xD22F, 0xD22F, 0xD004, 0xCDF6, 0xCC09, 0xCA3D, 0xC893, 0xC70C
0:21C	dw	0xC5AA, 0xC46D, 0xC355, 0xC264, 0xC19B, 0xC0F9, 0xC07F, 0xC02E
0:224	dw	0xC005, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
0:22C	dw	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
0:234	dw	0x0000, 0x0000


0:236	dw	0xC000, 0xC8F6, 0xCB96, 0xCCCD, 0xCD71, 0xCDE3, 0xCE14, 0xCE98
0:23E	dw	0xCF0A, 0xD000, 0xD000, 0xD1EC, 0xD666, 0xD6B8, 0xD70A, 0xD7AE
0:246	dw	0xD800, 0xD99A, 0xDB85, 0xDD81, 0xE28F, 0xE800, 0xEA8F, 0xEC00
0:24E	dw	0xECCD, 0xEDC3, 0xF000, 0xF28F, 0xF47B, 0xF666, 0xF852, 0xF99A
0:256	dw	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
0:25E	dw	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
0:266	dw	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
0:26E	dw	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
0:276	dw	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
0:27E	dw	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
0:286	dw	0x0000, 0x0000


main:
	0:288: 51c0 3800  pioc = 0x3800	; disable INT interrupts
	0:28a: 5110 0000  y = 0x0000
	0:28c: 1800       set r0 = 0x000
	0:28d: 70ff       do 127 { 0x028e }	; clear words 0000-007E
		0:28e: a0d1       au *r0++ = y
	0:28f: 707f       redo 127	; clear words 007F-00FE
	0:290: 707f       redo 127
	0:291: 707f       redo 127
	0:292: 707f       redo 127
	0:293: 707f       redo 127
	0:294: 707f       redo 127
	0:295: 707f       redo 127
	0:296: 707f       redo 127
	0:297: 707f       redo 127
	0:298: 707f       redo 127
	0:299: 707f       redo 127
	0:29a: 707f       redo 127
	0:29b: 707f       redo 127
	0:29c: 707f       redo 127
	0:29d: 707f       redo 127
	0:29e: 7010       redo 16	; clear words 07F0-07FFF
	
	0:29f: 5000 00e3  move r0 = 0x00e3
	0:2a1: 5010 0314  move r1 = 0x0314
	0:2a3: 6010       *r0 = r1	; set main offset = 0x0314 update_loop_1
	0:2a4: 5180 02e8  sioc = 0x02e8	; setup Serial I/O
	0:2a6: 51c0 3800  pioc = 0x3800	; setup Parallel I/O, disable INT interrupts
	0:2a8: 5110 0120  y = 0x0120		; pan 0x120 = centre (PanTable_FrontL + 0x010)
	0:2aa: 5000 0080  move r0 = 0x0080	; 0080: pan position
	0:2ac: 7093       do 19 { 0x02ad }	; set pan position of 19 channels (19??)
		0:2ad: a0d1       au *r0++ = y
	0:2ae: 50b0 0000  i = 0x0000
	0:2b0: 5110 0000  y = 0x0000
	0:2b2: 3040       p = x*y, *r0
	0:2b3: 1008       set j = 0x008
	0:2b4: 19f9       set r0 = 0x1f9
	0:2b5: 5010 0123  move r1 = 0x0123
	0:2b7: 6004       *r1 = r0	; *0x0123 = 0x01F9
	0:2b8: 5000 0257  move r0 = 0x0257
	0:2ba: 5010 0124  move r1 = 0x0124
	0:2bc: 6004       *r1 = r0	; *0x0124 = 0x0257
	0:2bd: 5000 0373  move r0 = 0x0373
	0:2bf: 5010 0120  move r1 = 0x0120
	0:2c1: 6004       *r1 = r0	; *0x0120 = 0x0373
	0:2c2: 5000 0554  move r0 = 0x0554
	0:2c4: 5010 011f  move r1 = 0x011f
	0:2c6: 6004       *r1 = r0	; *0x011F = 0x0554
	0:2c7: 5000 00d9  move r0 = 0x00d9
	0:2c9: 5110 055a  y = 0x055a
	0:2cb: a0d0       au *r0 = y	; *0x0D9 = 0x055A
	0:2cc: 1b25       set r1 = 0x125
	0:2cd: 192d       set r0 = 0x12d
	0:2ce: 6005       *r1++ = r0	; *0x125 = 0x012D
	0:2cf: 1b27       set r1 = 0x127
	0:2d0: 1960       set r0 = 0x160
	0:2d1: 6005       *r1++ = r0	; *0x127 = 0x0160
	0:2d2: 1b29       set r1 = 0x129
	0:2d3: 1993       set r0 = 0x193
	0:2d4: 6005       *r1++ = r0	; *0x129 = 0x0193
	0:2d5: 1b2b       set r1 = 0x12b
	0:2d6: 19c6       set r0 = 0x1c6
	0:2d7: 6005       *r1++ = r0	; *0x12B = 0X01C6
	0:2d8: 18de       set r0 = 0x0de
	0:2d9: 5110 0000  y = 0x0000
	0:2db: a0d1       au *r0++ = y	; *0x0DE = 0x0000
	0:2dc: 5110 002e  y = 0x002e
	0:2de: a0d1       au *r0++ = y	; *0x0DF = 0x002E
	0:2df: 5110 0000  y = 0x0000
	0:2e1: a0d1       au *r0++ = y	; *0x0E0 = 0x0000
	0:2e2: 5110 0030  y = 0x0030
	0:2e4: a0d1       au *r0++ = y	; *0x0E1 = 0x0030
	0:2e5: 5010 00e2  move r1 = 0x00e2	; filter refresh flag offset for filter_refresh routine
	0:2e7: 85dd       call 0x05dd	; filter_refresh_1
	0:2e8: 5000 00e4  move r0 = 0x00e4
	0:2ea: 5110 3fff  y = 0x3fff
	0:2ec: 7084       do 4 { 0x02ed }	; set *0x00E4..*0x00E7 = 0x3FFF
		0:2ed: a0d1       au *r0++ = y
	0:2ee: 5000 0000  move r0 = 0x0000
	0:2f0: 1008       set j = 0x008
	0:2f1: 5110 8000  y = 0x8000
	0:2f3: 7090       do 16 { 0x02f4 }	; set *0x0000/*0x0008/.../*0x0078 = 0x8000
		0:2f4: a0d3       au *r0++j = y
	0:2f5: 5190 00ff  srta = 0x00ff	; Serial Receive Address = 0x00, Serial Transmit Address = 0xFF
	0:2f7: 5180 02e8  sioc = 0x02e8	; setup Serial I/O
	0:2f9: 51c0 3800  pioc = 0x3800	; disable INT interrupts
	0:2fb: 1202       set k = 0x002
	0:2fc: 5130 0008  auc = 0x0008	; disable alignment, enable A0 saturation, disable A1 saturation
	0:2fe: 5000 00cc  move r0 = 0x00cc
	0:300: 5110 8000  y = 0x8000
	0:302: a0d0       au *r0 = y	; *0x00CC = 0x8000
	0:303: 5000 00d0  move r0 = 0x00d0
	0:305: a0d0       au *r0 = y	; *0x00D0 = 0x8000
	0:306: 5000 00d4  move r0 = 0x00d4
	0:308: a0d0       au *r0 = y	; *0x00D4 = 0x8000
	0:309: 5000 00da  move r0 = 0x00da
	0:30b: 5010 0db2  move r1 = 0x0db2
	0:30d: 6010       *r0 = r1	; *0x00DA = 0x0DB2
	0:30e: 5000 00dc  move r0 = 0x00dc
	0:310: 5010 0e11  move r1 = 0x0e11
	0:312: 6010       *r0 = r1	; *0x00DC = 0x0E11
	0:313: 0039       goto 0x0039	; copy_filter_data_1

update_loop_1:
	0:314: 5130 0008  auc = 0x0008	; disable alignment, enable A0 saturation, disable A1 saturation
	0:316: 18f1       set r0 = 0x0f1
	0:317: 1acb       set r1 = 0x0cb
	0:318: 3c90       a1 = p, a0 = *r0
	0:319: bef4       a1 = a1-p, y = *r1
	0:31a: 3160       a0-y, *r0
	0:31b: d003 031f  if ne goto 0x031f
	0:31d: 18e8       set r0 = 0x0e8
	0:31e: 20d0       *r0 = a1
	0:31f: 18d6       set r0 = 0x0d6
	0:320: b890       a0 = p, y = *r0
	0:321: 998e       if true a0 = y
	0:322: d002 0333  if eq goto 0x0333
	0:324: 1b1a       set r1 = 0x11a
	0:325: 20d4       *r1 = a1
	0:326: 20d0       *r0 = a1
	0:327: 1aeb       set r1 = 0x0eb
	0:328: 5110 000a  y = 0x000a
	0:32a: a0d4       au *r1 = y
	0:32b: 1ecd       set r3 = 0x0cd
	0:32c: 1ae8       set r1 = 0x0e8
	0:32d: b8dc       au y = *r3
	0:32e: a0d4       au *r1 = y
	0:32f: 1eca       set r3 = 0x0ca
	0:330: 1af1       set r1 = 0x0f1
	0:331: b8dc       au y = *r3
	0:332: a0d4       au *r1 = y
	0:333: 18cc       set r0 = 0x0cc
	0:334: 7880       pt = *r0
	0:335: 18f1       set r0 = 0x0f1
	0:336: 3cd0       a0 = *r0
	0:337: d850       p = x*y, y = a1, x = *pt++i
	0:338: 49e0       pdx1 = a0
	0:339: 1cf4       set r2 = 0x0f4
	0:33a: 1ee8       set r3 = 0x0e8
	0:33b: 30c0       nop, *r0
	0:33c: 30c0       nop, *r0
	0:33d: 30c0       nop, *r0
	0:33e: 1b1a       set r1 = 0x11a
	0:33f: e0d0       *r0 = a0
	0:340: 18eb       set r0 = 0x0eb
	0:341: f850       p = x*y, y = *r0, x = *pt++i
	0:342: 4500       move a0 = x
	0:343: 984e       a0 = a0>>4
	0:344: 988e       a0 = a0>>8
	0:345: e0d8       *r2 = a0	; *r2 = leftmost nibble of X (sign-extended)
	0:346: b0c8       au x = *r2
	0:347: 3c50       p = x*y, a0 = *r0
	0:348: 980e       a0 = a0>>1
	0:349: 9d0e       if true a1 = p
	0:34a: 99f1       if le a0 = -a0
	0:34b: 38c4       a1l = *r1
	0:34c: b6ac       a1 = a1+p, x = *r3
	0:34d: 4920       move yl = a0
	0:34e: 3fb8       a1 = a1+y, a0 = *r2
	0:34f: 9eee       a1 = a1<<16
	0:350: 5910       move y = a1
	0:351: 3040       p = x*y, *r0
	0:352: 9d0e       if true a1 = p
	0:353: 20d4       *r1 = a1
	0:354: 5110 09e4  y = 0x09e4
	0:356: 31a0       a0 = a0+y, *r0
	0:357: 4880       pt = a0
	0:358: f840       p = x*y, y = *r0, x = *pt++
	0:359: 3040       p = x*y, *r0
	0:35a: 990e       if true a0 = p
	0:35b: 98ae       a0 = a0<<8
	0:35c: 982e       a0 = a0<<1
	0:35d: 982e       a0 = a0<<1
	0:35e: 5110 0001  y = 0x0001
	0:360: 3160       a0-y, *r0
	0:361: 9991       if le a0 = y
	0:362: 5110 07d0  y = 0x07d0
	0:364: 3160       a0-y, *r0
	0:365: 9981       if pl a0 = y
	0:366: e0d0       *r0 = a0
	0:367: 8504       call 0x0504	; do_sample_1
	0:368: 50b0 0000  i = 0x0000
	0:36a: 30c0       nop, *r0
	0:36b: 30c0       nop, *r0
	0:36c: 30c0       nop, *r0
	0:36d: 30c0       nop, *r0
	0:36e: 30c0       nop, *r0
	0:36f: 5130 0008  auc = 0x0008	; disable alignment, enable A0 saturation, disable A1 saturation
	0:371: 18f2       set r0 = 0x0f2
	0:372: 1acf       set r1 = 0x0cf
	0:373: 3c90       a1 = p, a0 = *r0
	0:374: bef4       a1 = a1-p, y = *r1
	0:375: 3160       a0-y, *r0
	0:376: d003 037a  if ne goto 0x037a
	0:378: 18e9       set r0 = 0x0e9
	0:379: 20d0       *r0 = a1
	0:37a: 18d7       set r0 = 0x0d7
	0:37b: b890       a0 = p, y = *r0
	0:37c: 998e       if true a0 = y
	0:37d: d002 038e  if eq goto 0x038e
	0:37f: 1b1b       set r1 = 0x11b
	0:380: 20d4       *r1 = a1
	0:381: 20d0       *r0 = a1
	0:382: 1aec       set r1 = 0x0ec
	0:383: 5110 000a  y = 0x000a
	0:385: a0d4       au *r1 = y
	0:386: 1ed1       set r3 = 0x0d1
	0:387: 1ae9       set r1 = 0x0e9
	0:388: b8dc       au y = *r3
	0:389: a0d4       au *r1 = y
	0:38a: 1ece       set r3 = 0x0ce
	0:38b: 1af2       set r1 = 0x0f2
	0:38c: b8dc       au y = *r3
	0:38d: a0d4       au *r1 = y
	0:38e: 18d0       set r0 = 0x0d0
	0:38f: 7880       pt = *r0
	0:390: 18f2       set r0 = 0x0f2
	0:391: 3cd0       a0 = *r0
	0:392: d850       p = x*y, y = a1, x = *pt++i
	0:393: 49e0       pdx1 = a0
	0:394: 1cf5       set r2 = 0x0f5
	0:395: 1ee9       set r3 = 0x0e9
	0:396: 30c0       nop, *r0
	0:397: 30c0       nop, *r0
	0:398: 30c0       nop, *r0
	0:399: 1b1b       set r1 = 0x11b
	0:39a: e0d0       *r0 = a0
	0:39b: 18ec       set r0 = 0x0ec
	0:39c: f850       p = x*y, y = *r0, x = *pt++i
	0:39d: 4500       move a0 = x
	0:39e: 984e       a0 = a0>>4
	0:39f: 988e       a0 = a0>>8
	0:3a0: e0d8       *r2 = a0
	0:3a1: b0c8       au x = *r2
	0:3a2: 3c50       p = x*y, a0 = *r0
	0:3a3: 980e       a0 = a0>>1
	0:3a4: 9d0e       if true a1 = p
	0:3a5: 99f1       if le a0 = -a0
	0:3a6: 38c4       a1l = *r1
	0:3a7: b6ac       a1 = a1+p, x = *r3
	0:3a8: 4920       move yl = a0
	0:3a9: 3fb8       a1 = a1+y, a0 = *r2
	0:3aa: 9eee       a1 = a1<<16
	0:3ab: 5910       move y = a1
	0:3ac: 3040       p = x*y, *r0
	0:3ad: 9d0e       if true a1 = p
	0:3ae: 20d4       *r1 = a1
	0:3af: 5110 09e4  y = 0x09e4
	0:3b1: 31a0       a0 = a0+y, *r0
	0:3b2: 4880       pt = a0
	0:3b3: f840       p = x*y, y = *r0, x = *pt++
	0:3b4: 3040       p = x*y, *r0
	0:3b5: 990e       if true a0 = p
	0:3b6: 98ae       a0 = a0<<8
	0:3b7: 982e       a0 = a0<<1
	0:3b8: 982e       a0 = a0<<1
	0:3b9: 5110 0001  y = 0x0001
	0:3bb: 3160       a0-y, *r0
	0:3bc: 9991       if le a0 = y
	0:3bd: 5110 07d0  y = 0x07d0
	0:3bf: 3160       a0-y, *r0
	0:3c0: 9981       if pl a0 = y
	0:3c1: e0d0       *r0 = a0
	0:3c2: 8504       call 0x0504	; do_sample_1
	0:3c3: 50b0 0000  i = 0x0000
	0:3c5: 30c0       nop, *r0
	0:3c6: 30c0       nop, *r0
	0:3c7: 30c0       nop, *r0
	0:3c8: 30c0       nop, *r0
	0:3c9: 30c0       nop, *r0
	0:3ca: 5130 0008  auc = 0x0008	; disable alignment, enable A0 saturation, disable A1 saturation
	0:3cc: 18f3       set r0 = 0x0f3
	0:3cd: 1ad3       set r1 = 0x0d3
	0:3ce: 3c90       a1 = p, a0 = *r0
	0:3cf: bef4       a1 = a1-p, y = *r1
	0:3d0: 3160       a0-y, *r0
	0:3d1: d003 03d5  if ne goto 0x03d5
	0:3d3: 18ea       set r0 = 0x0ea
	0:3d4: 20d0       *r0 = a1
	0:3d5: 18d8       set r0 = 0x0d8
	0:3d6: b890       a0 = p, y = *r0
	0:3d7: 998e       if true a0 = y
	0:3d8: d002 03e9  if eq goto 0x03e9
	0:3da: 1b1c       set r1 = 0x11c
	0:3db: 20d4       *r1 = a1
	0:3dc: 20d0       *r0 = a1
	0:3dd: 1aed       set r1 = 0x0ed
	0:3de: 5110 000a  y = 0x000a
	0:3e0: a0d4       au *r1 = y
	0:3e1: 1ed5       set r3 = 0x0d5
	0:3e2: 1aea       set r1 = 0x0ea
	0:3e3: b8dc       au y = *r3
	0:3e4: a0d4       au *r1 = y
	0:3e5: 1ed2       set r3 = 0x0d2
	0:3e6: 1af3       set r1 = 0x0f3
	0:3e7: b8dc       au y = *r3
	0:3e8: a0d4       au *r1 = y
	0:3e9: 18d4       set r0 = 0x0d4
	0:3ea: 7880       pt = *r0
	0:3eb: 18f3       set r0 = 0x0f3
	0:3ec: 3cd0       a0 = *r0
	0:3ed: d850       p = x*y, y = a1, x = *pt++i
	0:3ee: 49e0       pdx1 = a0
	0:3ef: 1cf6       set r2 = 0x0f6
	0:3f0: 1eea       set r3 = 0x0ea
	0:3f1: 30c0       nop, *r0
	0:3f2: 30c0       nop, *r0
	0:3f3: 30c0       nop, *r0
	0:3f4: 1b1c       set r1 = 0x11c
	0:3f5: e0d0       *r0 = a0
	0:3f6: 18ed       set r0 = 0x0ed
	0:3f7: f850       p = x*y, y = *r0, x = *pt++i
	0:3f8: 4500       move a0 = x
	0:3f9: 984e       a0 = a0>>4
	0:3fa: 988e       a0 = a0>>8
	0:3fb: e0d8       *r2 = a0
	0:3fc: b0c8       au x = *r2
	0:3fd: 3c50       p = x*y, a0 = *r0
	0:3fe: 980e       a0 = a0>>1
	0:3ff: 9d0e       if true a1 = p
	0:400: 99f1       if le a0 = -a0
	0:401: 38c4       a1l = *r1
	0:402: b6ac       a1 = a1+p, x = *r3
	0:403: 4920       move yl = a0
	0:404: 3fb8       a1 = a1+y, a0 = *r2
	0:405: 9eee       a1 = a1<<16
	0:406: 5910       move y = a1
	0:407: 3040       p = x*y, *r0
	0:408: 9d0e       if true a1 = p
	0:409: 20d4       *r1 = a1
	0:40a: 5110 09e4  y = 0x09e4
	0:40c: 31a0       a0 = a0+y, *r0
	0:40d: 4880       pt = a0
	0:40e: f840       p = x*y, y = *r0, x = *pt++
	0:40f: 3040       p = x*y, *r0
	0:410: 990e       if true a0 = p
	0:411: 98ae       a0 = a0<<8
	0:412: 982e       a0 = a0<<1
	0:413: 982e       a0 = a0<<1
	0:414: 5110 0001  y = 0x0001
	0:416: 3160       a0-y, *r0
	0:417: 9991       if le a0 = y
	0:418: 5110 07d0  y = 0x07d0
	0:41a: 3160       a0-y, *r0
	0:41b: 9981       if pl a0 = y
	0:41c: e0d0       *r0 = a0
	0:41d: 8504       call 0x0504	; do_sample_1
	0:41e: 50b0 0000  i = 0x0000
	0:420: 30c0       nop, *r0
	0:421: 30c0       nop, *r0
	0:422: 30c0       nop, *r0
	0:423: 30c0       nop, *r0
	0:424: 30c0       nop, *r0
	0:425: 5130 0008  auc = 0x0008	; disable alignment, enable A0 saturation, disable A1 saturation
	0:427: 5000 00cc  move r0 = 0x00cc
	0:429: 7880       pt = *r0
	0:42a: 5000 00f1  move r0 = 0x00f1
	0:42c: 3cd0       a0 = *r0
	0:42d: f850       p = x*y, y = *r0, x = *pt++i
	0:42e: 49e0       pdx1 = a0
	0:42f: 992e       a0h = a0h+1
	0:430: 5020 00f4  move r2 = 0x00f4
	0:432: 30c0       nop, *r0
	0:433: 30c0       nop, *r0
	0:434: 30c0       nop, *r0
	0:435: 1ee8       set r3 = 0x0e8
	0:436: 5010 011a  move r1 = 0x011a
	0:438: e0d0       *r0 = a0
	0:439: f850       p = x*y, y = *r0, x = *pt++i
	0:43a: 4500       move a0 = x
	0:43b: 986e       a0 = a0<<4
	0:43c: 988e       a0 = a0>>8
	0:43d: 984e       a0 = a0>>4
	0:43e: e0d8       *r2 = a0	; *r2 = second-to-left nibble of X (not sign-extended)
	0:43f: 4900       move x = a0
	0:440: 5000 00eb  move r0 = 0x00eb
	0:442: b8d0       au y = *r0
	0:443: 3cd0       a0 = *r0
	0:444: 980e       a0 = a0>>1
	0:445: 3040       p = x*y, *r0
	0:446: 9d0e       if true a1 = p
	0:447: 99f1       if le a0 = -a0
	0:448: 38c4       a1l = *r1
	0:449: b6ac       a1 = a1+p, x = *r3
	0:44a: 4920       move yl = a0
	0:44b: 3fb8       a1 = a1+y, a0 = *r2
	0:44c: 9eee       a1 = a1<<16
	0:44d: 5910       move y = a1
	0:44e: 3040       p = x*y, *r0
	0:44f: 9d0e       if true a1 = p
	0:450: 20d4       *r1 = a1
	0:451: 5110 09e4  y = 0x09e4
	0:453: 31a0       a0 = a0+y, *r0
	0:454: 4880       pt = a0
	0:455: f840       p = x*y, y = *r0, x = *pt++
	0:456: 3040       p = x*y, *r0
	0:457: 990e       if true a0 = p
	0:458: 98ae       a0 = a0<<8
	0:459: 982e       a0 = a0<<1
	0:45a: 982e       a0 = a0<<1
	0:45b: 5110 0001  y = 0x0001
	0:45d: 3160       a0-y, *r0
	0:45e: 9991       if le a0 = y
	0:45f: 5110 07d0  y = 0x07d0
	0:461: 3160       a0-y, *r0
	0:462: 9981       if pl a0 = y
	0:463: e0d0       *r0 = a0
	0:464: 30c0       nop, *r0
	0:465: 30c0       nop, *r0
	0:466: 30c0       nop, *r0
	0:467: 30c0       nop, *r0
	0:468: 8504       call 0x0504	; do_sample_1
	0:469: 50b0 0000  i = 0x0000
	0:46b: 30c0       nop, *r0
	0:46c: 30c0       nop, *r0
	0:46d: 30c0       nop, *r0
	0:46e: 30c0       nop, *r0
	0:46f: 30c0       nop, *r0
	0:470: 5130 0008  auc = 0x0008	; disable alignment, enable A0 saturation, disable A1 saturation
	0:472: 5000 00d0  move r0 = 0x00d0
	0:474: 7880       pt = *r0
	0:475: 5000 00f2  move r0 = 0x00f2
	0:477: 3cd0       a0 = *r0
	0:478: f850       p = x*y, y = *r0, x = *pt++i
	0:479: 49e0       pdx1 = a0
	0:47a: 992e       a0h = a0h+1
	0:47b: 5020 00f5  move r2 = 0x00f5
	0:47d: 30c0       nop, *r0
	0:47e: 30c0       nop, *r0
	0:47f: 30c0       nop, *r0
	0:480: 1ee9       set r3 = 0x0e9
	0:481: 5010 011b  move r1 = 0x011b
	0:483: e0d0       *r0 = a0
	0:484: f850       p = x*y, y = *r0, x = *pt++i
	0:485: 4500       move a0 = x
	0:486: 986e       a0 = a0<<4
	0:487: 988e       a0 = a0>>8
	0:488: 984e       a0 = a0>>4
	0:489: e0d8       *r2 = a0
	0:48a: 4900       move x = a0
	0:48b: 5000 00ec  move r0 = 0x00ec
	0:48d: b8d0       au y = *r0
	0:48e: 3cd0       a0 = *r0
	0:48f: 980e       a0 = a0>>1
	0:490: 3040       p = x*y, *r0
	0:491: 9d0e       if true a1 = p
	0:492: 99f1       if le a0 = -a0
	0:493: 38c4       a1l = *r1
	0:494: b6ac       a1 = a1+p, x = *r3
	0:495: 4920       move yl = a0
	0:496: 3fb8       a1 = a1+y, a0 = *r2
	0:497: 9eee       a1 = a1<<16
	0:498: 5910       move y = a1
	0:499: 3040       p = x*y, *r0
	0:49a: 9d0e       if true a1 = p
	0:49b: 20d4       *r1 = a1
	0:49c: 5110 09e4  y = 0x09e4
	0:49e: 31a0       a0 = a0+y, *r0
	0:49f: 4880       pt = a0
	0:4a0: f840       p = x*y, y = *r0, x = *pt++
	0:4a1: 3040       p = x*y, *r0
	0:4a2: 990e       if true a0 = p
	0:4a3: 98ae       a0 = a0<<8
	0:4a4: 982e       a0 = a0<<1
	0:4a5: 982e       a0 = a0<<1
	0:4a6: 5110 0001  y = 0x0001
	0:4a8: 3160       a0-y, *r0
	0:4a9: 9991       if le a0 = y
	0:4aa: 5110 07d0  y = 0x07d0
	0:4ac: 3160       a0-y, *r0
	0:4ad: 9981       if pl a0 = y
	0:4ae: e0d0       *r0 = a0
	0:4af: 30c0       nop, *r0
	0:4b0: 30c0       nop, *r0
	0:4b1: 30c0       nop, *r0
	0:4b2: 30c0       nop, *r0
	0:4b3: 8504       call 0x0504	; do_sample_1
	0:4b4: 50b0 0000  i = 0x0000
	0:4b6: 30c0       nop, *r0
	0:4b7: 30c0       nop, *r0
	0:4b8: 30c0       nop, *r0
	0:4b9: 30c0       nop, *r0
	0:4ba: 30c0       nop, *r0
	0:4bb: 5130 0008  auc = 0x0008	; disable alignment, enable A0 saturation, disable A1 saturation
	0:4bd: 5000 00d4  move r0 = 0x00d4
	0:4bf: 7880       pt = *r0
	0:4c0: 5000 00f3  move r0 = 0x00f3
	0:4c2: 3cd0       a0 = *r0
	0:4c3: f850       p = x*y, y = *r0, x = *pt++i
	0:4c4: 49e0       pdx1 = a0
	0:4c5: 992e       a0h = a0h+1
	0:4c6: 5020 00f6  move r2 = 0x00f6
	0:4c8: 30c0       nop, *r0
	0:4c9: 30c0       nop, *r0
	0:4ca: 30c0       nop, *r0
	0:4cb: 1eea       set r3 = 0x0ea
	0:4cc: 5010 011c  move r1 = 0x011c
	0:4ce: e0d0       *r0 = a0
	0:4cf: f850       p = x*y, y = *r0, x = *pt++i
	0:4d0: 4500       move a0 = x
	0:4d1: 986e       a0 = a0<<4
	0:4d2: 988e       a0 = a0>>8
	0:4d3: 984e       a0 = a0>>4
	0:4d4: e0d8       *r2 = a0
	0:4d5: 4900       move x = a0
	0:4d6: 5000 00ed  move r0 = 0x00ed
	0:4d8: b8d0       au y = *r0
	0:4d9: 3cd0       a0 = *r0
	0:4da: 980e       a0 = a0>>1
	0:4db: 3040       p = x*y, *r0
	0:4dc: 9d0e       if true a1 = p
	0:4dd: 99f1       if le a0 = -a0
	0:4de: 38c4       a1l = *r1
	0:4df: b6ac       a1 = a1+p, x = *r3
	0:4e0: 4920       move yl = a0
	0:4e1: 3fb8       a1 = a1+y, a0 = *r2
	0:4e2: 9eee       a1 = a1<<16
	0:4e3: 5910       move y = a1
	0:4e4: 3040       p = x*y, *r0
	0:4e5: 9d0e       if true a1 = p
	0:4e6: 20d4       *r1 = a1
	0:4e7: 5110 09e4  y = 0x09e4
	0:4e9: 31a0       a0 = a0+y, *r0
	0:4ea: 4880       pt = a0
	0:4eb: f840       p = x*y, y = *r0, x = *pt++
	0:4ec: 3040       p = x*y, *r0
	0:4ed: 990e       if true a0 = p
	0:4ee: 98ae       a0 = a0<<8
	0:4ef: 982e       a0 = a0<<1
	0:4f0: 982e       a0 = a0<<1
	0:4f1: 5110 0001  y = 0x0001
	0:4f3: 3160       a0-y, *r0
	0:4f4: 9991       if le a0 = y
	0:4f5: 5110 07d0  y = 0x07d0
	0:4f7: 3160       a0-y, *r0
	0:4f8: 9981       if pl a0 = y
	0:4f9: e0d0       *r0 = a0
	0:4fa: 30c0       nop, *r0
	0:4fb: 30c0       nop, *r0
	0:4fc: 30c0       nop, *r0
	0:4fd: 30c0       nop, *r0
	0:4fe: 8504       call 0x0504	; do_sample_1
	0:4ff: 50b0 0000  i = 0x0000
	0:501: 1ae3       set r1 = 0x0e3
	0:502: 7894       pr = *r1	; return offset = (*0x00E3)
	0:503: c000       return

do_sample_1:
	0:504: 5130 0002  auc = 0x0002		; alignment = *4, enable A0 saturation, enable A1 saturation
	0:506: 5000 0078  move r0 = 0x0078	; ofs 078: channel 0 ROM bank
	0:508: 7880       pt = *r0		; preload channel 0 bank
	0:509: f880       a0 = p, y = *r0, x = *pt++	; A0 = P*4 (due to alignment), rest are dummy reads to apply the ROM bank
	
	0:50a: 1800       set r0 = 0x000	; ChnRAM+00: ROM bank for next channel
	0:50b: 1a01       set r1 = 0x001	; ChnRAM+01: address
	0:50c: 1c03       set r2 = 0x003	; ChnRAM+03: phase (sample address, 16-bit fraction)
	0:50d: 1f0a       set r3 = 0x10a	; 10A..119: channel sample data with volume applied
	0:50e: 1008       set j = 0x008		; 8 bytes per channel
	0:50f: 7710       do 16 { 0x0510...0x051d }
		0:510: 79d4       pdx0 = *r1		; PDX0 = address of sample data to read
		0:511: 7881       pt = *r0++		; set bank for next channel [ChnRAM+00]
		0:512: b8f1       a0 = a0-p, y = *r0++	; A0 = 0, Y = (current offset << 16) [ChnRAM+01]
		0:513: 3cc1       a0l = *r0++		; A0L = playback rate [ChnRAM+02]
		0:514: b8c1       au yl = *r0++		; YL = phase [ChnRAM+03] -> Y = 16.16 sample offset
		0:515: 986e       a0 = a0<<4		; make playback rate 4.12 fixed point
		0:516: b9b1       a0 = a0+y, y = *r0++	; A0 = new offset, Y = loop size [ChnRAM+04]
		0:517: bdf1       a1 = a0-y, y = *r0++	; A1 = loop offset, Y = end offset [ChnRAM+05]
		0:518: e16b       a0-y, *r2++j = a0l	; test (A0 < end offset), save phase
		0:519: 9bc1       if pl a0 = a1		; end offset reached (A0 >= Y) -> loop back
		0:51a: f841       p = x*y, y = *r0++, x = *pt++	; Y = channel volume, X = sample data [ChnRAM+06]
		0:51b: e057       p = x*y, *r1++j = a0	; P = sample*volume, save current offset [ChnRAM+01], advance R1 to next channel
		0:51c: 3481       a1 = p, *r0++		; A1 = P*4, advance R0 to [ChnRAM+00] of next channel
		0:51d: 209d       a0 = p, *r3++ = a1	; A0 = P*4 (makes A0=0 above work), save final sample to RAM at 10A..119
	
	0:51e: 190a       set r0 = 0x10a	; 10A..119: channel sample data
	0:51f: 1cba       set r2 = 0x0ba	; 0BA..0C9: channel reverb volume
	0:520: b8d1       au y = *r0++		; Y = ch 0 sample data
	0:521: b4e9       a1 = a0-p, x = *r2++	; A1 = 0, X = channel reverb
	0:522: 7110       do 16 { 0x0523...0x0524 }
		0:523: b049       p = x*y, x = *r2++	; P = channel reverb data, get next channel reverb
		0:524: beb1       a1 = a1+p, y = *r0++	; accumulate total reverb, read next channel sample
	
	0:525: 5060 0554  move rb = 0x0554	; RB [reverb begin] = 0554
	0:527: 1ed9       set r3 = 0x0d9
	0:528: 787c       re = *r3		; RE [reverb end] = RAM[0x00D9] (reverb delay)
	0:529: 1b1f       set r1 = 0x11f
	0:52a: 7804       r0 = *r1
	0:52b: 3cd0       a0 = *r0	; A0 = RAM[ RAM[0x11F] ]
	0:52c: 1f22       set r3 = 0x122
	0:52d: 1c93       set r2 = 0x093
	0:52e: b8dc       au y = *r3
	0:52f: e0de       *r3-- = a0
	0:530: e1bc       a0 = a0+y, *r3 = a0
	0:531: 980e       a0 = a0>>1
	0:532: 4910       move y = a0
	0:533: b0c8       au x = *r2
	0:534: a05c       p = x*y, *r3 = y
	0:535: 36a0       a1 = a1+p, *r0
	0:536: 20d1       *r0++ = a1
	0:537: 6004       *r1 = r0
	
	0:538: 5060 0373  move rb = 0x0373	; RB [reverb begin] = 0373
	0:53a: 5070 0553  move re = 0x0553	; RE [reverb end] = 0553
	0:53c: 1b20       set r1 = 0x120
	0:53d: 7804       r0 = *r1
	0:53e: e0d1       *r0++ = a0		; write to *R0, then increase+wrap around R0 (if R0 == RE, then R0 = RB, else R0 ++)
	0:53f: 6004       *r1 = r0
	
	0:540: 51c0 3820  pioc = 0x3820	; enable INT interrupts
	0:542: 1cf7       set r2 = 0x0f7	; channel panning, right speaker (PanTable_FrontR)
	0:543: 51c0 3800  pioc = 0x3800	; disable INT interrupts
	0:545: 4550       a0 = c0	; get interrupt counter
	0:546: 99ce       a0 = a0
	0:547: d003 055c  if ne goto 0x055c	; if c0 == 1, then jump
	0:549: 30c0       nop, *r0	; else execut NOPs to make up for the cycles taken by the interrupt
	0:54a: 30c0       nop, *r0
	0:54b: 30c0       nop, *r0
	0:54c: 30c0       nop, *r0
	0:54d: 30c0       nop, *r0
	0:54e: 30c0       nop, *r0
	0:54f: 30c0       nop, *r0
	0:550: 30c0       nop, *r0
	0:551: 30c0       nop, *r0
	0:552: 30c0       nop, *r0
	0:553: 30c0       nop, *r0
	0:554: 30c0       nop, *r0
	0:555: 30c0       nop, *r0
	0:556: 30c0       nop, *r0
	0:557: 30c0       nop, *r0
	0:558: 30c0       nop, *r0
	0:559: 30c0       nop, *r0
	0:55a: 30c0       nop, *r0
	0:55b: 055e       goto 0x055e
	0:55c: 5150 0000  c0 = 0x0000
	
	0:55e: 1b0a       set r1 = 0x10a	; 10A..11C: channel sample data
	0:55f: 1880       set r0 = 0x080	; 080..092: channel panning (see PanTable_FrontL)
	0:560: 1f1e       set r3 = 0x11e	; 11E: final mixed sample data
	0:561: 50b0 0062  i = 0x0062
	0:563: 5110 0000  y = 0x0000
	0:565: 9d8e       if true a1 = y	; A1 = 0
	0:566: 3040       p = x*y, *r0		; P = 0
	0:567: 990e       if true a0 = p	; A0 = 0
	0:568: 7213       do 19 { 0x0569...0x056c }
		0:569: 7881       pt = *r0++
		0:56a: f874       a0 = a0-p, p = x*y, y = *r1, x = *pt++i	; A0 -= ROM[PanRearL] + SampleData (calculates previous channel data)
		0:56b: fe75       a1 = a1-p, p = x*y, y = *r1++, x = *pt++i	; A1 -= ROM[PanL] * SampleData
		0:56c: 6089       *r2++ = pt	; store PanR address for channels
	0:56d: 3060       a0 = a0-p, p = x*y, *r0	; A0 -= ROM[PanRearL] + SampleData (calculates last channel data)
	0:56e: 1d21       set r2 = 0x121
	0:56f: befa       a1 = a1-p, y = *r2--
	0:570: 31a0       a0 = a0+y, *r0	; add RAM[121] (unknown)
	0:571: e0dc       *r3 = a0		; store final data
	
	; do some reverb
	0:572: 5020 02b5  move r2 = 0x02b5
	0:574: 15f9       set rb = 0x1f9
	0:575: 5070 0256  move re = 0x0256
	0:577: 1923       set r0 = 0x123
	0:578: 7810       r1 = *r0
	0:579: b8d5       au y = *r1++
	0:57a: b089       a0 = p, x = *r2++
	0:57b: 715d       do 93 { 0x057c...0x057d }
		0:57c: b069       a0 = a0-p, p = x*y, x = *r2++
		0:57d: b8d5       au y = *r1++
	0:57e: b069       a0 = a0-p, p = x*y, x = *r2++
	0:57f: 5910       move y = a1
	0:580: a874       a0 = a0-p, p = x*y, *r1zp : y
	0:581: 6010       *r0 = r1
	
	; do some filter
	0:582: 1ce4       set r2 = 0x0e4
	0:583: b0e9       a0 = a0-p, x = *r2++
	0:584: 152d       set rb = 0x12d
	0:585: 175f       set re = 0x15f
	0:586: 1925       set r0 = 0x125
	0:587: 7810       r1 = *r0
	0:588: e0d5       *r1++ = a0
	0:589: 6011       *r0++ = r1
	0:58a: 7810       r1 = *r0
	0:58b: b8d5       au y = *r1++
	0:58c: b048       p = x*y, x = *r2
	0:58d: b89c       a0 = p, y = *r3
	0:58e: 6011       *r0++ = r1
	0:58f: 1560       set rb = 0x160
	0:590: 1792       set re = 0x192
	0:591: 7810       r1 = *r0
	0:592: a0d5       au *r1++ = y
	0:593: 6011       *r0++ = r1
	0:594: 7810       r1 = *r0
	0:595: b8d5       au y = *r1++
	0:596: 6010       *r0 = r1
	0:597: 5080 09d2  pt = 0x09d2
	0:599: f844       p = x*y, y = *r1, x = *pt++
	0:59a: 3020       a0 = a0 + p, p = x*y, *r0
	0:59b: 996e       a0 = rnd(a0)
	0:59c: 49a0       sdx = a0	; output left channel sample data
	
	0:59d: 18f7       set r0 = 0x0f7	; channel panning, right speaker (PanTable_FrontR)
	0:59e: 1b0a       set r1 = 0x10a	; 10A..11C: channel sample data
	0:59f: 990e       if true a0 = p
	0:5a0: 9d0e       if true a1 = p
	0:5a1: 7193       do 19 { 0x05a2...0x05a4 }
		0:5a2: 7881       pt = *r0++
		0:5a3: f874       a0 = a0-p, p = x*y, y = *r1, x = *pt++i
		0:5a4: fe75       a1 = a1-p, p = x*y, y = *r1++, x = *pt++i
	0:5a5: 3060       a0 = a0-p, p = x*y, *r0
	0:5a6: 1d21       set r2 = 0x121
	0:5a7: befa       a1 = a1-p, y = *r2--
	0:5a8: e7bc       a1 = a1+y, *r3 = a0
	
	; do some reverb
	0:5a9: 5020 0314  move r2 = 0x0314
	0:5ab: 5060 0257  move rb = 0x0257
	0:5ad: 5070 02b4  move re = 0x02b4
	0:5af: 1924       set r0 = 0x124
	0:5b0: 7810       r1 = *r0
	0:5b1: b8d5       au y = *r1++
	0:5b2: b089       a0 = p, x = *r2++
	0:5b3: 715d       do 93 { 0x05b4...0x05b5 }
		0:5b4: b069       a0 = a0-p, p = x*y, x = *r2++
		0:5b5: b8d5       au y = *r1++
	0:5b6: b069       a0 = a0-p, p = x*y, x = *r2++
	0:5b7: 5910       move y = a1
	0:5b8: a874       a0 = a0-p, p = x*y, *r1zp : y
	0:5b9: 6010       *r0 = r1
	
	; do some filter
	0:5ba: 1ce6       set r2 = 0x0e6
	0:5bb: b0e9       a0 = a0-p, x = *r2++
	0:5bc: 1593       set rb = 0x193
	0:5bd: 17c5       set re = 0x1c5
	0:5be: 1929       set r0 = 0x129
	0:5bf: 7810       r1 = *r0
	0:5c0: e0d5       *r1++ = a0
	0:5c1: 6011       *r0++ = r1
	0:5c2: 7810       r1 = *r0
	0:5c3: b8d5       au y = *r1++
	0:5c4: b048       p = x*y, x = *r2
	0:5c5: b89c       a0 = p, y = *r3
	0:5c6: 6011       *r0++ = r1
	0:5c7: 15c6       set rb = 0x1c6
	0:5c8: 5070 01f8  move re = 0x01f8
	0:5ca: 7810       r1 = *r0
	0:5cb: a0d5       au *r1++ = y
	0:5cc: 6011       *r0++ = r1
	0:5cd: 7810       r1 = *r0
	0:5ce: b8d5       au y = *r1++
	0:5cf: 6010       *r0 = r1
	0:5d0: 5080 09d2  pt = 0x09d2
	0:5d2: f844       p = x*y, y = *r1, x = *pt++
	0:5d3: 3020       a0 = a0 + p, p = x*y, *r0
	0:5d4: 996e       a0 = rnd(a0)
	0:5d5: 51e0 0000  pdx1 = 0x0000
	0:5d7: 49a0       sdx = a0	; output right channel sample data
	
	0:5d8: 1ae2       set r1 = 0x0e2	; load filter refresh flag offset
	0:5d9: b8d4       au y = *r1
	0:5da: 3180       a0 = y, *r0
	0:5db: d002 0612  if eq goto 0x0612	; loc_612
filter_refresh_1:
	0:5dd: 5020 00de  move r2 = 0x00de
	0:5df: 5030 0126  move r3 = 0x0126
	0:5e1: 5000 0125  move r0 = 0x0125
	
	0:5e3: 3cd1       a0 = *r0++	; A0 = *0x0125
	0:5e4: b8d9       au y = *r2++	; Y = *0x00DE
	0:5e5: 31e0       a0 = a0-y	; A0 = *0x0125 - *0x00DE
	0:5e6: 5110 0033  y = 0x0033
	0:5e8: 35a0       a1 = a0+y	; A1 = *0x0125 - *0x00DE + 0x0033
	0:5e9: 5110 012d  y = 0x012d
	0:5eb: 3160       a0-y, *r0
	0:5ec: 9bc0       if mi a0 = a1	; if (A0 < 0x012D) A0 = A1
	0:5ed: e0d1       *r0++ = a0	; *0x0126 = A0
	
	0:5ee: 3cd1       a0 = *r0++	; A0 = *0x0127
	0:5ef: b8d9       au y = *r2++	; Y = *0x00DF
	0:5f0: 31e0       a0 = a0-y	; A0 = *0x0127 - *0x00DF
	0:5f1: 5110 0033  y = 0x0033
	0:5f3: 35a0       a1 = a0+y	; A1 = *0x0127 - *0x00DF + 0x0033
	0:5f4: 5110 0160  y = 0x0160
	0:5f6: 3160       a0-y, *r0
	0:5f7: 9bc0       if mi a0 = a1	; if (A0 < 0x0160) A0 = A1
	0:5f8: e0d1       *r0++ = a0	; *0x0128 = A0
	
	0:5f9: 3cd1       a0 = *r0++	; A0 = *0x0129
	0:5fa: b8d9       au y = *r2++
	0:5fb: 31e0       a0 = a0-y	; A0 = *0x0129 - *0x00E0
	0:5fc: 5110 0033  y = 0x0033
	0:5fe: 35a0       a1 = a0+y	; A1 = *0x0129 - *0x00E0 + 0x0033
	0:5ff: 5110 0193  y = 0x0193
	0:601: 3160       a0-y, *r0
	0:602: 9bc0       if mi a0 = a1	; if (A0 < 0x0193) A0 = A1
	0:603: e0d1       *r0++ = a0	; *0x012A = A0
	
	0:604: 3cd1       a0 = *r0++	; A0 = *0x012B
	0:605: b8d9       au y = *r2++
	0:606: 31e0       a0 = a0-y	; A0 = *0x012B - *0x00E1
	0:607: 5110 0033  y = 0x0033
	0:609: 35a0       a1 = a0+y	; A1 = *0x012B - *0x00E1 + 0x0033
	0:60a: 5110 01c6  y = 0x01c6
	0:60c: 3160       a0-y, *r0
	0:60d: 9bc0       if mi a0 = a1	; if (A0 < 0x01C6) A0 = A1
	0:60e: e0d1       *r0++ = a0	; *0x012C = A0
	
	0:60f: 5110 0000  y = 0x0000
	0:611: a0d4       au *r1 = y	; set filter refresh flag offset to "0" (no refresh required)
loc_612:
	0:612: 30c0       nop, *r0
	0:613: 30c0       nop, *r0
	0:614: 30c0       nop, *r0
	0:615: 30c0       nop, *r0
	0:616: 30c0       nop, *r0
	0:617: 30c0       nop, *r0
	0:618: 30c0       nop, *r0
	0:619: c000       return
	
	0:61a: 51c0 3800  pioc = 0x3800	; disable INT interrupts
	0:61c: 5110 0000  y = 0x0000
	0:61e: 1800       set r0 = 0x000
	0:61f: 70ff       do 127 { 0x0620 }
		0:620: a0d1       au *r0++ = y
	0:621: 707f       redo 127
	0:622: 707f       redo 127
	0:623: 707f       redo 127
	0:624: 707f       redo 127
	0:625: 707f       redo 127
	0:626: 707f       redo 127
	0:627: 707f       redo 127
	0:628: 707f       redo 127
	0:629: 707f       redo 127
	0:62a: 707f       redo 127
	0:62b: 707f       redo 127
	0:62c: 707f       redo 127
	0:62d: 707f       redo 127
	0:62e: 707f       redo 127
	0:62f: 707f       redo 127
	0:630: 7010       redo 16
	0:631: 5000 00e3  move r0 = 0x00e3
	0:633: 5010 06b2  move r1 = 0x06b2
	0:635: 6010       *r0 = r1	; set main offset = 0x06B2 update_loop_2
	0:636: 5180 02e8  sioc = 0x02e8	; setup Serial I/O
	0:638: 51c0 3800  pioc = 0x3800	; disable INT interrupts
	0:63a: 5110 0120  y = 0x0120
	0:63c: 5000 0080  move r0 = 0x0080
	0:63e: 7093       do 19 { 0x063f }
		0:63f: a0d1       au *r0++ = y
	0:640: 50b0 0000  i = 0x0000
	0:642: 5110 0000  y = 0x0000
	0:644: 3040       p = x*y, *r0
	0:645: 1008       set j = 0x008
	0:646: 19fb       set r0 = 0x1fb
	0:647: 5010 0123  move r1 = 0x0123
	0:649: 6004       *r1 = r0
	0:64a: 5000 0227  move r0 = 0x0227
	0:64c: 5010 0124  move r1 = 0x0124
	0:64e: 6004       *r1 = r0
	0:64f: 5000 0253  move r0 = 0x0253
	0:651: 1bf9       set r1 = 0x1f9
	0:652: 6004       *r1 = r0
	0:653: 5000 027e  move r0 = 0x027e
	0:655: 1bfa       set r1 = 0x1fa
	0:656: 6004       *r1 = r0
	0:657: 5000 035b  move r0 = 0x035b
	0:659: 5010 0120  move r1 = 0x0120
	0:65b: 6004       *r1 = r0
	0:65c: 5000 053c  move r0 = 0x053c
	0:65e: 5010 011f  move r1 = 0x011f
	0:660: 6004       *r1 = r0
	0:661: 5000 00d9  move r0 = 0x00d9
	0:663: 5110 0542  y = 0x0542
	0:665: a0d0       au *r0 = y
	0:666: 1b25       set r1 = 0x125
	0:667: 192d       set r0 = 0x12d
	0:668: 6005       *r1++ = r0
	0:669: 1b27       set r1 = 0x127
	0:66a: 1960       set r0 = 0x160
	0:66b: 6005       *r1++ = r0
	0:66c: 1b29       set r1 = 0x129
	0:66d: 1993       set r0 = 0x193
	0:66e: 6005       *r1++ = r0
	0:66f: 1b2b       set r1 = 0x12b
	0:670: 19c6       set r0 = 0x1c6
	0:671: 6005       *r1++ = r0
	0:672: 18de       set r0 = 0x0de
	0:673: 5110 0001  y = 0x0001
	0:675: a0d1       au *r0++ = y
	0:676: 5110 0000  y = 0x0000
	0:678: a0d1       au *r0++ = y
	0:679: 5110 0000  y = 0x0000
	0:67b: a0d1       au *r0++ = y
	0:67c: 5110 0000  y = 0x0000
	0:67e: a0d1       au *r0++ = y
	0:67f: 5010 00e2  move r1 = 0x00e2	; filter refresh flag offset for filter_refresh routine
	0:681: 899b       call 0x099b	; filter_refresh_2
	0:682: 5000 00e4  move r0 = 0x00e4
	0:684: 5110 3fff  y = 0x3fff
	0:686: 7084       do 4 { 0x0687 }
		0:687: a0d1       au *r0++ = y
	0:688: 5000 0000  move r0 = 0x0000
	0:68a: 1008       set j = 0x008
	0:68b: 5110 8000  y = 0x8000
	0:68d: 7090       do 16 { 0x068e }
		0:68e: a0d3       au *r0++j = y
	0:68f: 5190 00ff  srta = 0x00ff	; Serial Receive Address = 0x00, Serial Transmit Address = 0xFF
	0:691: 5180 02e8  sioc = 0x02e8	; setup Serial I/O
	0:693: 51c0 3800  pioc = 0x3800	; disable INT interrupts
	0:695: 1202       set k = 0x002
	0:696: 5130 0008  auc = 0x0008	; disable alignment, enable A0 saturation, disable A1 saturation
	0:698: 5000 00cc  move r0 = 0x00cc
	0:69a: 5110 8000  y = 0x8000
	0:69c: a0d0       au *r0 = y
	0:69d: 5000 00d0  move r0 = 0x00d0
	0:69f: a0d0       au *r0 = y
	0:6a0: 5000 00d4  move r0 = 0x00d4
	0:6a2: a0d0       au *r0 = y
	0:6a3: 5000 00da  move r0 = 0x00da
	0:6a5: 5010 0f73  move r1 = 0x0f73
	0:6a7: 6011       *r0++ = r1
	0:6a8: 5010 0fa4  move r1 = 0x0fa4
	0:6aa: 6011       *r0++ = r1
	0:6ab: 5010 0f73  move r1 = 0x0f73
	0:6ad: 6011       *r0++ = r1
	0:6ae: 5010 0fa4  move r1 = 0x0fa4
	0:6b0: 6011       *r0++ = r1
	0:6b1: 004f       goto 0x004f	; copy_filter_data_2

update_loop_2:
	0:6b2: 5130 0008  auc = 0x0008	; disable alignment, enable A0 saturation, disable A1 saturation
	0:6b4: 18f1       set r0 = 0x0f1
	0:6b5: 1acb       set r1 = 0x0cb
	0:6b6: 3c90       a1 = p, a0 = *r0
	0:6b7: bef4       a1 = a1-p, y = *r1
	0:6b8: 3160       a0-y, *r0
	0:6b9: d003 06bd  if ne goto 0x06bd
	0:6bb: 18e8       set r0 = 0x0e8
	0:6bc: 20d0       *r0 = a1
	0:6bd: 18d6       set r0 = 0x0d6
	0:6be: b890       a0 = p, y = *r0
	0:6bf: 998e       if true a0 = y
	0:6c0: d002 06d1  if eq goto 0x06d1
	0:6c2: 1b1a       set r1 = 0x11a
	0:6c3: 20d4       *r1 = a1
	0:6c4: 20d0       *r0 = a1
	0:6c5: 1aeb       set r1 = 0x0eb
	0:6c6: 5110 000a  y = 0x000a
	0:6c8: a0d4       au *r1 = y
	0:6c9: 1ecd       set r3 = 0x0cd
	0:6ca: 1ae8       set r1 = 0x0e8
	0:6cb: b8dc       au y = *r3
	0:6cc: a0d4       au *r1 = y
	0:6cd: 1eca       set r3 = 0x0ca
	0:6ce: 1af1       set r1 = 0x0f1
	0:6cf: b8dc       au y = *r3
	0:6d0: a0d4       au *r1 = y
	0:6d1: 18cc       set r0 = 0x0cc
	0:6d2: 7880       pt = *r0
	0:6d3: 18f1       set r0 = 0x0f1
	0:6d4: 3cd0       a0 = *r0
	0:6d5: d850       p = x*y, y = a1, x = *pt++i
	0:6d6: 49e0       pdx1 = a0
	0:6d7: 1cf4       set r2 = 0x0f4
	0:6d8: 1ee8       set r3 = 0x0e8
	0:6d9: 30c0       nop, *r0
	0:6da: 30c0       nop, *r0
	0:6db: 30c0       nop, *r0
	0:6dc: 1b1a       set r1 = 0x11a
	0:6dd: e0d0       *r0 = a0
	0:6de: 18eb       set r0 = 0x0eb
	0:6df: f850       p = x*y, y = *r0, x = *pt++i
	0:6e0: 4500       move a0 = x
	0:6e1: 984e       a0 = a0>>4
	0:6e2: 988e       a0 = a0>>8
	0:6e3: e0d8       *r2 = a0
	0:6e4: b0c8       au x = *r2
	0:6e5: 3c50       p = x*y, a0 = *r0
	0:6e6: 980e       a0 = a0>>1
	0:6e7: 9d0e       if true a1 = p
	0:6e8: 99f1       if le a0 = -a0
	0:6e9: 38c4       a1l = *r1
	0:6ea: b6ac       a1 = a1+p, x = *r3
	0:6eb: 4920       move yl = a0
	0:6ec: 3fb8       a1 = a1+y, a0 = *r2
	0:6ed: 9eee       a1 = a1<<16
	0:6ee: 5910       move y = a1
	0:6ef: 3040       p = x*y, *r0
	0:6f0: 9d0e       if true a1 = p
	0:6f1: 20d4       *r1 = a1
	0:6f2: 5110 09e4  y = 0x09e4
	0:6f4: 31a0       a0 = a0+y, *r0
	0:6f5: 4880       pt = a0
	0:6f6: f840       p = x*y, y = *r0, x = *pt++
	0:6f7: 3040       p = x*y, *r0
	0:6f8: 990e       if true a0 = p
	0:6f9: 98ae       a0 = a0<<8
	0:6fa: 982e       a0 = a0<<1
	0:6fb: 982e       a0 = a0<<1
	0:6fc: 5110 0001  y = 0x0001
	0:6fe: 3160       a0-y, *r0
	0:6ff: 9991       if le a0 = y
	0:700: 5110 07d0  y = 0x07d0
	0:702: 3160       a0-y, *r0
	0:703: 9981       if pl a0 = y
	0:704: e0d0       *r0 = a0
	0:705: 88a2       call 0x08a2	; do_sample_2
	0:706: 50b0 0000  i = 0x0000
	0:708: 30c0       nop, *r0
	0:709: 30c0       nop, *r0
	0:70a: 30c0       nop, *r0
	0:70b: 30c0       nop, *r0
	0:70c: 30c0       nop, *r0
	0:70d: 5130 0008  auc = 0x0008	; disable alignment, enable A0 saturation, disable A1 saturation
	0:70f: 18f2       set r0 = 0x0f2
	0:710: 1acf       set r1 = 0x0cf
	0:711: 3c90       a1 = p, a0 = *r0
	0:712: bef4       a1 = a1-p, y = *r1
	0:713: 3160       a0-y, *r0
	0:714: d003 0718  if ne goto 0x0718
	0:716: 18e9       set r0 = 0x0e9
	0:717: 20d0       *r0 = a1
	0:718: 18d7       set r0 = 0x0d7
	0:719: b890       a0 = p, y = *r0
	0:71a: 998e       if true a0 = y
	0:71b: d002 072c  if eq goto 0x072c
	0:71d: 1b1b       set r1 = 0x11b
	0:71e: 20d4       *r1 = a1
	0:71f: 20d0       *r0 = a1
	0:720: 1aec       set r1 = 0x0ec
	0:721: 5110 000a  y = 0x000a
	0:723: a0d4       au *r1 = y
	0:724: 1ed1       set r3 = 0x0d1
	0:725: 1ae9       set r1 = 0x0e9
	0:726: b8dc       au y = *r3
	0:727: a0d4       au *r1 = y
	0:728: 1ece       set r3 = 0x0ce
	0:729: 1af2       set r1 = 0x0f2
	0:72a: b8dc       au y = *r3
	0:72b: a0d4       au *r1 = y
	0:72c: 18d0       set r0 = 0x0d0
	0:72d: 7880       pt = *r0
	0:72e: 18f2       set r0 = 0x0f2
	0:72f: 3cd0       a0 = *r0
	0:730: d850       p = x*y, y = a1, x = *pt++i
	0:731: 49e0       pdx1 = a0
	0:732: 1cf5       set r2 = 0x0f5
	0:733: 1ee9       set r3 = 0x0e9
	0:734: 30c0       nop, *r0
	0:735: 30c0       nop, *r0
	0:736: 30c0       nop, *r0
	0:737: 1b1b       set r1 = 0x11b
	0:738: e0d0       *r0 = a0
	0:739: 18ec       set r0 = 0x0ec
	0:73a: f850       p = x*y, y = *r0, x = *pt++i
	0:73b: 4500       move a0 = x
	0:73c: 984e       a0 = a0>>4
	0:73d: 988e       a0 = a0>>8
	0:73e: e0d8       *r2 = a0
	0:73f: b0c8       au x = *r2
	0:740: 3c50       p = x*y, a0 = *r0
	0:741: 980e       a0 = a0>>1
	0:742: 9d0e       if true a1 = p
	0:743: 99f1       if le a0 = -a0
	0:744: 38c4       a1l = *r1
	0:745: b6ac       a1 = a1+p, x = *r3
	0:746: 4920       move yl = a0
	0:747: 3fb8       a1 = a1+y, a0 = *r2
	0:748: 9eee       a1 = a1<<16
	0:749: 5910       move y = a1
	0:74a: 3040       p = x*y, *r0
	0:74b: 9d0e       if true a1 = p
	0:74c: 20d4       *r1 = a1
	0:74d: 5110 09e4  y = 0x09e4
	0:74f: 31a0       a0 = a0+y, *r0
	0:750: 4880       pt = a0
	0:751: f840       p = x*y, y = *r0, x = *pt++
	0:752: 3040       p = x*y, *r0
	0:753: 990e       if true a0 = p
	0:754: 98ae       a0 = a0<<8
	0:755: 982e       a0 = a0<<1
	0:756: 982e       a0 = a0<<1
	0:757: 5110 0001  y = 0x0001
	0:759: 3160       a0-y, *r0
	0:75a: 9991       if le a0 = y
	0:75b: 5110 07d0  y = 0x07d0
	0:75d: 3160       a0-y, *r0
	0:75e: 9981       if pl a0 = y
	0:75f: e0d0       *r0 = a0
	0:760: 88a2       call 0x08a2	; do_sample_2
	0:761: 50b0 0000  i = 0x0000
	0:763: 30c0       nop, *r0
	0:764: 30c0       nop, *r0
	0:765: 30c0       nop, *r0
	0:766: 30c0       nop, *r0
	0:767: 30c0       nop, *r0
	0:768: 5130 0008  auc = 0x0008	; disable alignment, enable A0 saturation, disable A1 saturation
	0:76a: 18f3       set r0 = 0x0f3
	0:76b: 1ad3       set r1 = 0x0d3
	0:76c: 3c90       a1 = p, a0 = *r0
	0:76d: bef4       a1 = a1-p, y = *r1
	0:76e: 3160       a0-y, *r0
	0:76f: d003 0773  if ne goto 0x0773
	0:771: 18ea       set r0 = 0x0ea
	0:772: 20d0       *r0 = a1
	0:773: 18d8       set r0 = 0x0d8
	0:774: b890       a0 = p, y = *r0
	0:775: 998e       if true a0 = y
	0:776: d002 0787  if eq goto 0x0787
	0:778: 1b1c       set r1 = 0x11c
	0:779: 20d4       *r1 = a1
	0:77a: 20d0       *r0 = a1
	0:77b: 1aed       set r1 = 0x0ed
	0:77c: 5110 000a  y = 0x000a
	0:77e: a0d4       au *r1 = y
	0:77f: 1ed5       set r3 = 0x0d5
	0:780: 1aea       set r1 = 0x0ea
	0:781: b8dc       au y = *r3
	0:782: a0d4       au *r1 = y
	0:783: 1ed2       set r3 = 0x0d2
	0:784: 1af3       set r1 = 0x0f3
	0:785: b8dc       au y = *r3
	0:786: a0d4       au *r1 = y
	0:787: 18d4       set r0 = 0x0d4
	0:788: 7880       pt = *r0
	0:789: 18f3       set r0 = 0x0f3
	0:78a: 3cd0       a0 = *r0
	0:78b: d850       p = x*y, y = a1, x = *pt++i
	0:78c: 49e0       pdx1 = a0
	0:78d: 1cf6       set r2 = 0x0f6
	0:78e: 1eea       set r3 = 0x0ea
	0:78f: 30c0       nop, *r0
	0:790: 30c0       nop, *r0
	0:791: 30c0       nop, *r0
	0:792: 1b1c       set r1 = 0x11c
	0:793: e0d0       *r0 = a0
	0:794: 18ed       set r0 = 0x0ed
	0:795: f850       p = x*y, y = *r0, x = *pt++i
	0:796: 4500       move a0 = x
	0:797: 984e       a0 = a0>>4
	0:798: 988e       a0 = a0>>8
	0:799: e0d8       *r2 = a0
	0:79a: b0c8       au x = *r2
	0:79b: 3c50       p = x*y, a0 = *r0
	0:79c: 980e       a0 = a0>>1
	0:79d: 9d0e       if true a1 = p
	0:79e: 99f1       if le a0 = -a0
	0:79f: 38c4       a1l = *r1
	0:7a0: b6ac       a1 = a1+p, x = *r3
	0:7a1: 4920       move yl = a0
	0:7a2: 3fb8       a1 = a1+y, a0 = *r2
	0:7a3: 9eee       a1 = a1<<16
	0:7a4: 5910       move y = a1
	0:7a5: 3040       p = x*y, *r0
	0:7a6: 9d0e       if true a1 = p
	0:7a7: 20d4       *r1 = a1
	0:7a8: 5110 09e4  y = 0x09e4
	0:7aa: 31a0       a0 = a0+y, *r0
	0:7ab: 4880       pt = a0
	0:7ac: f840       p = x*y, y = *r0, x = *pt++
	0:7ad: 3040       p = x*y, *r0
	0:7ae: 990e       if true a0 = p
	0:7af: 98ae       a0 = a0<<8
	0:7b0: 982e       a0 = a0<<1
	0:7b1: 982e       a0 = a0<<1
	0:7b2: 5110 0001  y = 0x0001
	0:7b4: 3160       a0-y, *r0
	0:7b5: 9991       if le a0 = y
	0:7b6: 5110 07d0  y = 0x07d0
	0:7b8: 3160       a0-y, *r0
	0:7b9: 9981       if pl a0 = y
	0:7ba: e0d0       *r0 = a0
	0:7bb: 88a2       call 0x08a2	; do_sample_2
	0:7bc: 50b0 0000  i = 0x0000
	0:7be: 30c0       nop, *r0
	0:7bf: 30c0       nop, *r0
	0:7c0: 30c0       nop, *r0
	0:7c1: 30c0       nop, *r0
	0:7c2: 30c0       nop, *r0
	0:7c3: 5130 0008  auc = 0x0008	; disable alignment, enable A0 saturation, disable A1 saturation
	0:7c5: 5000 00cc  move r0 = 0x00cc
	0:7c7: 7880       pt = *r0
	0:7c8: 5000 00f1  move r0 = 0x00f1
	0:7ca: 3cd0       a0 = *r0
	0:7cb: f850       p = x*y, y = *r0, x = *pt++i
	0:7cc: 49e0       pdx1 = a0
	0:7cd: 992e       a0h = a0h+1
	0:7ce: 5020 00f4  move r2 = 0x00f4
	0:7d0: 30c0       nop, *r0
	0:7d1: 30c0       nop, *r0
	0:7d2: 30c0       nop, *r0
	0:7d3: 1ee8       set r3 = 0x0e8
	0:7d4: 5010 011a  move r1 = 0x011a
	0:7d6: e0d0       *r0 = a0
	0:7d7: f850       p = x*y, y = *r0, x = *pt++i
	0:7d8: 4500       move a0 = x
	0:7d9: 986e       a0 = a0<<4
	0:7da: 988e       a0 = a0>>8
	0:7db: 984e       a0 = a0>>4
	0:7dc: e0d8       *r2 = a0
	0:7dd: 4900       move x = a0
	0:7de: 5000 00eb  move r0 = 0x00eb
	0:7e0: b8d0       au y = *r0
	0:7e1: 3cd0       a0 = *r0
	0:7e2: 980e       a0 = a0>>1
	0:7e3: 3040       p = x*y, *r0
	0:7e4: 9d0e       if true a1 = p
	0:7e5: 99f1       if le a0 = -a0
	0:7e6: 38c4       a1l = *r1
	0:7e7: b6ac       a1 = a1+p, x = *r3
	0:7e8: 4920       move yl = a0
	0:7e9: 3fb8       a1 = a1+y, a0 = *r2
	0:7ea: 9eee       a1 = a1<<16
	0:7eb: 5910       move y = a1
	0:7ec: 3040       p = x*y, *r0
	0:7ed: 9d0e       if true a1 = p
	0:7ee: 20d4       *r1 = a1
	0:7ef: 5110 09e4  y = 0x09e4
	0:7f1: 31a0       a0 = a0+y, *r0
	0:7f2: 4880       pt = a0
	0:7f3: f840       p = x*y, y = *r0, x = *pt++
	0:7f4: 3040       p = x*y, *r0
	0:7f5: 990e       if true a0 = p
	0:7f6: 98ae       a0 = a0<<8
	0:7f7: 982e       a0 = a0<<1
	0:7f8: 982e       a0 = a0<<1
	0:7f9: 5110 0001  y = 0x0001
	0:7fb: 3160       a0-y, *r0
	0:7fc: 9991       if le a0 = y
	0:7fd: 5110 07d0  y = 0x07d0
	0:7ff: 3160       a0-y, *r0
	0:800: 9981       if pl a0 = y
	0:801: e0d0       *r0 = a0
	0:802: 30c0       nop, *r0
	0:803: 30c0       nop, *r0
	0:804: 30c0       nop, *r0
	0:805: 30c0       nop, *r0
	0:806: 88a2       call 0x08a2	; do_sample_2
	0:807: 50b0 0000  i = 0x0000
	0:809: 30c0       nop, *r0
	0:80a: 30c0       nop, *r0
	0:80b: 30c0       nop, *r0
	0:80c: 30c0       nop, *r0
	0:80d: 30c0       nop, *r0
	0:80e: 5130 0008  auc = 0x0008	; disable alignment, enable A0 saturation, disable A1 saturation
	0:810: 5000 00d0  move r0 = 0x00d0
	0:812: 7880       pt = *r0
	0:813: 5000 00f2  move r0 = 0x00f2
	0:815: 3cd0       a0 = *r0
	0:816: f850       p = x*y, y = *r0, x = *pt++i
	0:817: 49e0       pdx1 = a0
	0:818: 992e       a0h = a0h+1
	0:819: 5020 00f5  move r2 = 0x00f5
	0:81b: 30c0       nop, *r0
	0:81c: 30c0       nop, *r0
	0:81d: 30c0       nop, *r0
	0:81e: 1ee9       set r3 = 0x0e9
	0:81f: 5010 011b  move r1 = 0x011b
	0:821: e0d0       *r0 = a0
	0:822: f850       p = x*y, y = *r0, x = *pt++i
	0:823: 4500       move a0 = x
	0:824: 986e       a0 = a0<<4
	0:825: 988e       a0 = a0>>8
	0:826: 984e       a0 = a0>>4
	0:827: e0d8       *r2 = a0
	0:828: 4900       move x = a0
	0:829: 5000 00ec  move r0 = 0x00ec
	0:82b: b8d0       au y = *r0
	0:82c: 3cd0       a0 = *r0
	0:82d: 980e       a0 = a0>>1
	0:82e: 3040       p = x*y, *r0
	0:82f: 9d0e       if true a1 = p
	0:830: 99f1       if le a0 = -a0
	0:831: 38c4       a1l = *r1
	0:832: b6ac       a1 = a1+p, x = *r3
	0:833: 4920       move yl = a0
	0:834: 3fb8       a1 = a1+y, a0 = *r2
	0:835: 9eee       a1 = a1<<16
	0:836: 5910       move y = a1
	0:837: 3040       p = x*y, *r0
	0:838: 9d0e       if true a1 = p
	0:839: 20d4       *r1 = a1
	0:83a: 5110 09e4  y = 0x09e4
	0:83c: 31a0       a0 = a0+y, *r0
	0:83d: 4880       pt = a0
	0:83e: f840       p = x*y, y = *r0, x = *pt++
	0:83f: 3040       p = x*y, *r0
	0:840: 990e       if true a0 = p
	0:841: 98ae       a0 = a0<<8
	0:842: 982e       a0 = a0<<1
	0:843: 982e       a0 = a0<<1
	0:844: 5110 0001  y = 0x0001
	0:846: 3160       a0-y, *r0
	0:847: 9991       if le a0 = y
	0:848: 5110 07d0  y = 0x07d0
	0:84a: 3160       a0-y, *r0
	0:84b: 9981       if pl a0 = y
	0:84c: e0d0       *r0 = a0
	0:84d: 30c0       nop, *r0
	0:84e: 30c0       nop, *r0
	0:84f: 30c0       nop, *r0
	0:850: 30c0       nop, *r0
	0:851: 88a2       call 0x08a2	; do_sample_2
	0:852: 50b0 0000  i = 0x0000
	0:854: 30c0       nop, *r0
	0:855: 30c0       nop, *r0
	0:856: 30c0       nop, *r0
	0:857: 30c0       nop, *r0
	0:858: 30c0       nop, *r0
	0:859: 5130 0008  auc = 0x0008	; disable alignment, enable A0 saturation, disable A1 saturation
	0:85b: 5000 00d4  move r0 = 0x00d4
	0:85d: 7880       pt = *r0
	0:85e: 5000 00f3  move r0 = 0x00f3
	0:860: 3cd0       a0 = *r0
	0:861: f850       p = x*y, y = *r0, x = *pt++i
	0:862: 49e0       pdx1 = a0
	0:863: 992e       a0h = a0h+1
	0:864: 5020 00f6  move r2 = 0x00f6
	0:866: 30c0       nop, *r0
	0:867: 30c0       nop, *r0
	0:868: 30c0       nop, *r0
	0:869: 1eea       set r3 = 0x0ea
	0:86a: 5010 011c  move r1 = 0x011c
	0:86c: e0d0       *r0 = a0
	0:86d: f850       p = x*y, y = *r0, x = *pt++i
	0:86e: 4500       move a0 = x
	0:86f: 986e       a0 = a0<<4
	0:870: 988e       a0 = a0>>8
	0:871: 984e       a0 = a0>>4
	0:872: e0d8       *r2 = a0
	0:873: 4900       move x = a0
	0:874: 5000 00ed  move r0 = 0x00ed
	0:876: b8d0       au y = *r0
	0:877: 3cd0       a0 = *r0
	0:878: 980e       a0 = a0>>1
	0:879: 3040       p = x*y, *r0
	0:87a: 9d0e       if true a1 = p
	0:87b: 99f1       if le a0 = -a0
	0:87c: 38c4       a1l = *r1
	0:87d: b6ac       a1 = a1+p, x = *r3
	0:87e: 4920       move yl = a0
	0:87f: 3fb8       a1 = a1+y, a0 = *r2
	0:880: 9eee       a1 = a1<<16
	0:881: 5910       move y = a1
	0:882: 3040       p = x*y, *r0
	0:883: 9d0e       if true a1 = p
	0:884: 20d4       *r1 = a1
	0:885: 5110 09e4  y = 0x09e4
	0:887: 31a0       a0 = a0+y, *r0
	0:888: 4880       pt = a0
	0:889: f840       p = x*y, y = *r0, x = *pt++
	0:88a: 3040       p = x*y, *r0
	0:88b: 990e       if true a0 = p
	0:88c: 98ae       a0 = a0<<8
	0:88d: 982e       a0 = a0<<1
	0:88e: 982e       a0 = a0<<1
	0:88f: 5110 0001  y = 0x0001
	0:891: 3160       a0-y, *r0
	0:892: 9991       if le a0 = y
	0:893: 5110 07d0  y = 0x07d0
	0:895: 3160       a0-y, *r0
	0:896: 9981       if pl a0 = y
	0:897: e0d0       *r0 = a0
	0:898: 30c0       nop, *r0
	0:899: 30c0       nop, *r0
	0:89a: 30c0       nop, *r0
	0:89b: 30c0       nop, *r0
	0:89c: 88a2       call 0x08a2	; do_sample_2
	0:89d: 50b0 0000  i = 0x0000
	0:89f: 1ae3       set r1 = 0x0e3
	0:8a0: 7894       pr = *r1	; return offset = (*0x00E3)
	0:8a1: c000       return
	
do_sample_2:
	0:8a2: 5130 0002  auc = 0x0002
	0:8a4: 5000 0078  move r0 = 0x0078
	0:8a6: 7880       pt = *r0
	0:8a7: f880       a0 = p, y = *r0, x = *pt++
	
	0:8a8: 1800       set r0 = 0x000
	0:8a9: 1a01       set r1 = 0x001
	0:8aa: 1c03       set r2 = 0x003
	0:8ab: 1f0a       set r3 = 0x10a
	0:8ac: 1008       set j = 0x008
	0:8ad: 7710       do 16 { 0x08ae...0x08bb }
		0:8ae: 79d4       pdx0 = *r1
		0:8af: 7881       pt = *r0++
		0:8b0: b8f1       a0 = a0-p, y = *r0++
		0:8b1: 3cc1       a0l = *r0++
		0:8b2: b8c1       au yl = *r0++
		0:8b3: 986e       a0 = a0<<4
		0:8b4: b9b1       a0 = a0+y, y = *r0++
		0:8b5: bdf1       a1 = a0-y, y = *r0++
		0:8b6: e16b       a0-y, *r2++j = a0l
		0:8b7: 9bc1       if pl a0 = a1
		0:8b8: f841       p = x*y, y = *r0++, x = *pt++
		0:8b9: e057       p = x*y, *r1++j = a0
		0:8ba: 3481       a1 = p, *r0++
		0:8bb: 209d       a0 = p, *r3++ = a1
	
	0:8bc: 190a       set r0 = 0x10a
	0:8bd: 1cba       set r2 = 0x0ba
	0:8be: b8d1       au y = *r0++
	0:8bf: b4e9       a1 = a0-p, x = *r2++
	0:8c0: 7110       do 16 { 0x08c1...0x08c2 }
		0:8c1: b049       p = x*y, x = *r2++
		0:8c2: beb1       a1 = a1+p, y = *r0++
	
	0:8c3: 5060 053c  move rb = 0x053c
	0:8c5: 1ed9       set r3 = 0x0d9
	0:8c6: 787c       re = *r3
	0:8c7: 1b1f       set r1 = 0x11f
	0:8c8: 7804       r0 = *r1
	0:8c9: 3cd0       a0 = *r0
	0:8ca: 1f22       set r3 = 0x122
	0:8cb: 1c93       set r2 = 0x093
	0:8cc: b8dc       au y = *r3
	0:8cd: e0de       *r3-- = a0
	0:8ce: e1bc       a0 = a0+y, *r3 = a0
	0:8cf: 980e       a0 = a0>>1
	0:8d0: 4910       move y = a0
	0:8d1: b0c8       au x = *r2
	0:8d2: a05c       p = x*y, *r3 = y
	0:8d3: 36a0       a1 = a1+p, *r0
	0:8d4: 20d1       *r0++ = a1
	0:8d5: 6004       *r1 = r0
	
	0:8d6: 5060 035b  move rb = 0x035b
	0:8d8: 5070 053b  move re = 0x053b
	0:8da: 1b20       set r1 = 0x120
	0:8db: 7804       r0 = *r1
	0:8dc: e0d1       *r0++ = a0
	0:8dd: 6004       *r1 = r0
	
	0:8de: 51c0 3820  pioc = 0x3820	; enable INT interrupts
	0:8e0: 1cf7       set r2 = 0x0f7
	0:8e1: 51c0 3800  pioc = 0x3800	; disable INT interrupts
	0:8e3: 4550       a0 = c0	; get interrupt counter
	0:8e4: 99ce       a0 = a0
	0:8e5: d003 08fa  if ne goto 0x08fa	; if c0 == 1, then jump
	0:8e7: 30c0       nop, *r0	; else execut NOPs to make up for the cycles taken by the interrupt
	0:8e8: 30c0       nop, *r0
	0:8e9: 30c0       nop, *r0
	0:8ea: 30c0       nop, *r0
	0:8eb: 30c0       nop, *r0
	0:8ec: 30c0       nop, *r0
	0:8ed: 30c0       nop, *r0
	0:8ee: 30c0       nop, *r0
	0:8ef: 30c0       nop, *r0
	0:8f0: 30c0       nop, *r0
	0:8f1: 30c0       nop, *r0
	0:8f2: 30c0       nop, *r0
	0:8f3: 30c0       nop, *r0
	0:8f4: 30c0       nop, *r0
	0:8f5: 30c0       nop, *r0
	0:8f6: 30c0       nop, *r0
	0:8f7: 30c0       nop, *r0
	0:8f8: 30c0       nop, *r0
	0:8f9: 08fc       goto 0x08fc
	0:8fa: 5150 0000  c0 = 0x0000
	
	0:8fc: 1b0a       set r1 = 0x10a
	0:8fd: 1880       set r0 = 0x080
	0:8fe: 1f1e       set r3 = 0x11e
	0:8ff: 50b0 0062  i = 0x0062
	0:901: 5110 0000  y = 0x0000
	0:903: 9d8e       if true a1 = y
	0:904: 3040       p = x*y, *r0
	0:905: 990e       if true a0 = p
	0:906: 7213       do 19 { 0x0907...0x090a }
		0:907: 7881       pt = *r0++
		0:908: f874       a0 = a0-p, p = x*y, y = *r1, x = *pt++i
		0:909: fe75       a1 = a1-p, p = x*y, y = *r1++, x = *pt++i
		0:90a: 6089       *r2++ = pt
	0:90b: 3060       a0 = a0-p, p = x*y, *r0
	0:90c: 1d21       set r2 = 0x121
	0:90d: befa       a1 = a1-p, y = *r2--
	0:90e: 31a0       a0 = a0+y, *r0
	0:90f: e0dc       *r3 = a0
	
	; do some reverb
	0:910: 5020 02a9  move r2 = 0x02a9
	0:912: 15fb       set rb = 0x1fb
	0:913: 5070 0226  move re = 0x0226
	0:915: 1923       set r0 = 0x123
	0:916: 7810       r1 = *r0
	0:917: b8d5       au y = *r1++
	0:918: b089       a0 = p, x = *r2++
	0:919: 712b       do 43 { 0x091a...0x091b }
		0:91a: b069       a0 = a0-p, p = x*y, x = *r2++
		0:91b: b8d5       au y = *r1++
	0:91c: b069       a0 = a0-p, p = x*y, x = *r2++
	0:91d: 5910       move y = a1
	0:91e: a874       a0 = a0-p, p = x*y, *r1zp : y
	0:91f: 30e0       a0 = a0-p, *r0
	0:920: 6010       *r0 = r1
	
	0:921: 5060 0253  move rb = 0x0253
	0:923: 5070 027d  move re = 0x027d
	0:925: 19f9       set r0 = 0x1f9
	0:926: 7810       r1 = *r0
	0:927: b8d5       au y = *r1++
	0:928: b489       a1 = p, x = *r2++
	0:929: 712a       do 42 { 0x092a...0x092b }
		0:92a: b669       a1 = a1-p, p = x*y, x = *r2++
		0:92b: b8d5       au y = *r1++
	0:92c: b669       a1 = a1-p, p = x*y, x = *r2++
	0:92d: b8dc       au y = *r3
	0:92e: ae74       a1 = a1-p, p = x*y, *r1zp : y
	0:92f: 6010       *r0 = r1
	
	; do some filter
	0:930: 1ce4       set r2 = 0x0e4
	0:931: b6e9       a1 = a1-p, x = *r2++
	0:932: 152d       set rb = 0x12d
	0:933: 175f       set re = 0x15f
	0:934: 1925       set r0 = 0x125
	0:935: 7810       r1 = *r0
	0:936: e0d5       *r1++ = a0
	0:937: 6011       *r0++ = r1
	0:938: 7810       r1 = *r0
	0:939: b8d5       au y = *r1++
	0:93a: b048       p = x*y, x = *r2
	0:93b: b89c       a0 = p, y = *r3
	0:93c: 6011       *r0++ = r1
	0:93d: 1560       set rb = 0x160
	0:93e: 1792       set re = 0x192
	0:93f: 7810       r1 = *r0
	0:940: 20d5       *r1++ = a1
	0:941: 6011       *r0++ = r1
	0:942: 7810       r1 = *r0
	0:943: b8d5       au y = *r1++
	0:944: 6010       *r0 = r1
	0:945: 5080 09d2  pt = 0x09d2
	0:947: f844       p = x*y, y = *r1, x = *pt++
	0:948: 3020       a0 = a0 + p, p = x*y, *r0
	0:949: 996e       a0 = rnd(a0)
	0:94a: 49a0       sdx = a0	; output left channel sample data
	
	0:94b: 18f7       set r0 = 0x0f7
	0:94c: 1b0a       set r1 = 0x10a
	0:94d: 990e       if true a0 = p
	0:94e: 9d0e       if true a1 = p
	0:94f: 7193       do 19 { 0x0950...0x0952 }
		0:950: 7881       pt = *r0++
		0:951: f874       a0 = a0-p, p = x*y, y = *r1, x = *pt++i
		0:952: fe75       a1 = a1-p, p = x*y, y = *r1++, x = *pt++i
	0:953: 3060       a0 = a0-p, p = x*y, *r0
	0:954: 1d21       set r2 = 0x121
	0:955: befa       a1 = a1-p, y = *r2--
	0:956: e7bc       a1 = a1+y, *r3 = a0
	
	; do some reverb
	0:957: 5020 0302  move r2 = 0x0302
	0:959: 5060 0227  move rb = 0x0227
	0:95b: 5070 0252  move re = 0x0252
	0:95d: 1924       set r0 = 0x124
	0:95e: 7810       r1 = *r0
	0:95f: b8d5       au y = *r1++
	0:960: b089       a0 = p, x = *r2++
	0:961: 712b       do 43 { 0x0962...0x0963 }
		0:962: b069       a0 = a0-p, p = x*y, x = *r2++
		0:963: b8d5       au y = *r1++
	0:964: b069       a0 = a0-p, p = x*y, x = *r2++
	0:965: 5910       move y = a1
	0:966: a874       a0 = a0-p, p = x*y, *r1zp : y
	0:967: 30e0       a0 = a0-p, *r0
	0:968: 6010       *r0 = r1
	
	0:969: 5060 027e  move rb = 0x027e
	0:96b: 5070 02a8  move re = 0x02a8
	0:96d: 19fa       set r0 = 0x1fa
	0:96e: 7810       r1 = *r0
	0:96f: b8d5       au y = *r1++
	0:970: b489       a1 = p, x = *r2++
	0:971: 712a       do 42 { 0x0972...0x0973 }
		0:972: b669       a1 = a1-p, p = x*y, x = *r2++
		0:973: b8d5       au y = *r1++
	0:974: b669       a1 = a1-p, p = x*y, x = *r2++
	0:975: b8dc       au y = *r3
	0:976: ae74       a1 = a1-p, p = x*y, *r1zp : y
	0:977: 6010       *r0 = r1
	
	; do some filter
	0:978: 1ce6       set r2 = 0x0e6
	0:979: b6e9       a1 = a1-p, x = *r2++
	0:97a: 1593       set rb = 0x193
	0:97b: 17c5       set re = 0x1c5
	0:97c: 1929       set r0 = 0x129
	0:97d: 7810       r1 = *r0
	0:97e: e0d5       *r1++ = a0
	0:97f: 6011       *r0++ = r1
	0:980: 7810       r1 = *r0
	0:981: b8d5       au y = *r1++
	0:982: b048       p = x*y, x = *r2
	0:983: b89c       a0 = p, y = *r3
	0:984: 6011       *r0++ = r1
	0:985: 15c6       set rb = 0x1c6
	0:986: 5070 01f8  move re = 0x01f8
	0:988: 7810       r1 = *r0
	0:989: 20d5       *r1++ = a1
	0:98a: 6011       *r0++ = r1
	0:98b: 7810       r1 = *r0
	0:98c: b8d5       au y = *r1++
	0:98d: 6010       *r0 = r1
	0:98e: 5080 09d2  pt = 0x09d2
	0:990: f844       p = x*y, y = *r1, x = *pt++
	0:991: 3020       a0 = a0 + p, p = x*y, *r0
	0:992: 996e       a0 = rnd(a0)
	0:993: 51e0 0000  pdx1 = 0x0000
	0:995: 49a0       sdx = a0	; output right channel sample data
	
	0:996: 1ae2       set r1 = 0x0e2	; load filter refresh flag offset
	0:997: b8d4       au y = *r1
	0:998: 3180       a0 = y, *r0
	0:999: d002 09d0  if eq goto 0x09d0	; loc_9D0
filter_refresh_2:	; for comments see filter_refresh_1, which is identical, except for additional NOPs
	0:99b: 5020 00de  move r2 = 0x00de
	0:99d: 5030 0126  move r3 = 0x0126
	0:99f: 5000 0125  move r0 = 0x0125
	
	0:9a1: 3cd1       a0 = *r0++
	0:9a2: b8d9       au y = *r2++
	0:9a3: 31e0       a0 = a0-y, *r0
	0:9a4: 5110 0033  y = 0x0033
	0:9a6: 35a0       a1 = a0+y, *r0
	0:9a7: 5110 012d  y = 0x012d
	0:9a9: 3160       a0-y, *r0
	0:9aa: 9bc0       if mi a0 = a1
	0:9ab: e0d1       *r0++ = a0
	
	0:9ac: 3cd1       a0 = *r0++
	0:9ad: b8d9       au y = *r2++
	0:9ae: 31e0       a0 = a0-y, *r0
	0:9af: 5110 0033  y = 0x0033
	0:9b1: 35a0       a1 = a0+y, *r0
	0:9b2: 5110 0160  y = 0x0160
	0:9b4: 3160       a0-y, *r0
	0:9b5: 9bc0       if mi a0 = a1
	0:9b6: e0d1       *r0++ = a0
	
	0:9b7: 3cd1       a0 = *r0++
	0:9b8: b8d9       au y = *r2++
	0:9b9: 31e0       a0 = a0-y, *r0
	0:9ba: 5110 0033  y = 0x0033
	0:9bc: 35a0       a1 = a0+y, *r0
	0:9bd: 5110 0193  y = 0x0193
	0:9bf: 3160       a0-y, *r0
	0:9c0: 9bc0       if mi a0 = a1
	0:9c1: e0d1       *r0++ = a0
	
	0:9c2: 3cd1       a0 = *r0++
	0:9c3: b8d9       au y = *r2++
	0:9c4: 31e0       a0 = a0-y, *r0
	0:9c5: 5110 0033  y = 0x0033
	0:9c7: 35a0       a1 = a0+y, *r0
	0:9c8: 5110 01c6  y = 0x01c6
	0:9ca: 3160       a0-y, *r0
	0:9cb: 9bc0       if mi a0 = a1
	0:9cc: e0d1       *r0++ = a0
	
	0:9cd: 5110 0000  y = 0x0000
	0:9cf: a0d4       au *r1 = y
loc_9D0:
	0:9d0: 30c0       nop, *r0
	0:9d1: c000       return


0:9D2	dw	0x0000, 0x3305, 0xFDC3, 0x023D, 0xC6B7, 0x778A, 0xFB86, 0x047A
0:9DA	dw	0x04F0, 0x0000

0:9DC	dw	0x009A, 0x009A, 0x0080, 0x0066, 0x004D, 0x003A, 0x003A, 0x003A
0:9E4	dw	0x003A, 0x003A, 0x003A, 0x003A, 0x004D, 0x0066, 0x0080, 0x009A
0:9EC	dw	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000


0:9F4	dw	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
...
0:D44	dw	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
0:D4C	dw	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000


0:D53	dw	0x0000, 0x0000, 0x0000, 0x0006, 0x002C, 0xFFE8, 0xFFCB, 0xFFF6
0:D5B	dw	0x003B, 0xFFD8, 0xFFE5, 0x0001, 0x0027, 0xFFE5, 0x0038, 0x007F
0:D63	dw	0x00AE, 0x0024, 0xFFF3, 0x0031, 0x00D4, 0x008E, 0x008F, 0xFFB7
0:D6B	dw	0xFFEC, 0x0042, 0xFF94, 0xFF8B, 0xFE71, 0xFEF7, 0xFE78, 0xFDC7
0:D73	dw	0xFE27, 0xFFB9, 0x005F, 0xFEC1, 0xFF26, 0xFF1A, 0x014B, 0x027E
0:D7B	dw	0x01C1, 0x01DD, 0xFF4C, 0x0214, 0x0453, 0x02EE, 0x26AB, 0x0EF4
0:D83	dw	0xF68E, 0x042F, 0xFF50, 0x00BF, 0xFE51, 0x0040, 0x0075, 0xFF6A
0:D8B	dw	0xFEEE, 0xFF9F, 0xFF12, 0x00A5, 0x00A6, 0x00FA, 0xFFED, 0x0004
0:D93	dw	0x0025, 0x00CC, 0x00BA, 0xFFFA, 0x008C, 0xFFB3, 0xFFFF, 0x0001
0:D9B	dw	0x0012, 0xFFF6, 0xFF69, 0xFF6B, 0xFF99, 0xFFF7, 0x0037, 0x0017
0:DA3	dw	0xFF9A, 0xFF9F, 0xFFF5, 0x000D, 0xFFD0, 0xFFE5, 0x0005, 0x0012
0:DAB	dw	0xFFC3, 0xFFE2, 0x0040, 0x0048, 0x0000, 0x0000, 0x0000

0:DB2	dw	0x0000, 0x0000, 0x0000, 0x0055, 0x0018, 0xFFB4, 0xFF85, 0xFFAA
0:DBA	dw	0xFFE3, 0xFFF2, 0xFFEC, 0xFFF9, 0x0006, 0xFFE4, 0xFFA9, 0xFFA7
0:DC2	dw	0xFFFB, 0x0064, 0x009A, 0x00A0, 0x0096, 0x0076, 0x0029, 0xFFD0
0:DCA	dw	0xFFB2, 0xFFE9, 0x003B, 0x0053, 0xFFFE, 0xFF50, 0xFEB3, 0xFEA8
0:DD2	dw	0xFF35, 0xFFBE, 0xFFD9, 0x0002, 0x00E0, 0x01EF, 0x01EF, 0x0118
0:DDA	dw	0x01B0, 0x053C, 0x09B3, 0x1501, 0x0771, 0x0292, 0x0000, 0x0061
0:DE2	dw	0x015B, 0x011D, 0x0023, 0xFFA1, 0xFFB2, 0xFFAE, 0xFF69, 0xFF40
0:DEA	dw	0xFF55, 0xFF6B, 0xFF6D, 0xFF8F, 0xFFEA, 0x0047, 0x0076, 0x0081
0:DF2	dw	0x007F, 0x006E, 0x0047, 0x001F, 0x0014, 0x0024, 0x002E, 0x0017
0:DFA	dw	0xFFE5, 0xFFC1, 0xFFCB, 0xFFEB, 0xFFED, 0xFFC4, 0xFFA4, 0xFFBB
0:E02	dw	0xFFF4, 0x0019, 0x001D, 0x001E, 0x0028, 0x0029, 0x001D, 0x001E
0:E0A	dw	0x002E, 0x0027, 0xFFF1, 0xFFB6, 0x0000, 0x0000, 0x0000

0:E11	dw	0x0000, 0x0000, 0x0000, 0x0017, 0x002A, 0x002F, 0x001D, 0x000A
0:E19	dw	0x0002, 0xFFF2, 0xFFCA, 0xFFA4, 0xFFA3, 0xFFBA, 0xFFC0, 0xFFB3
0:E21	dw	0xFFC7, 0x0012, 0x005E, 0x0071, 0x0057, 0x0045, 0x0043, 0x0032
0:E29	dw	0x0019, 0x001D, 0x003A, 0x003E, 0x0018, 0xFFD9, 0xFF7D, 0xFF00
0:E31	dw	0xFEBB, 0xFF16, 0xFFD3, 0x003A, 0x004E, 0x00DF, 0x01E5, 0x01F0
0:E39	dw	0x007F, 0x0006, 0x0359, 0x08EB, 0x0A7B, 0x1340, 0x0530, 0x0084
0:E41	dw	0x004F, 0x013A, 0x00BD, 0xFFB0, 0xFFA6, 0x0023, 0xFFEB, 0xFF46
0:E49	dw	0xFF3D, 0xFF9D, 0xFF78, 0xFEFE, 0xFF43, 0x0052, 0x0101, 0x00B9
0:E51	dw	0x0035, 0x0029, 0x0054, 0x0044, 0x0026, 0x003F, 0x004D, 0x000E
0:E59	dw	0xFFC4, 0xFFB9, 0xFFB9, 0xFF88, 0xFF69, 0xFFAC, 0x000E, 0x001D
0:E61	dw	0xFFF8, 0x0007, 0x0042, 0x0045, 0x000C, 0xFFFD, 0x0036, 0x005C
0:E69	dw	0x0034, 0xFFFA, 0xFFF1, 0xFFFE, 0x0000, 0x0000, 0x0000

0:E70	dw	0x0000, 0x0000, 0x0000, 0x0002, 0xFFE4, 0xFFDB, 0xFFEF, 0x0000
0:E78	dw	0xFFF7, 0xFFEA, 0xFFFD, 0x0023, 0x0034, 0x0027, 0x0014, 0x0007
0:E80	dw	0xFFFA, 0x0002, 0x0037, 0x0079, 0x0081, 0x0043, 0x0008, 0x0001
0:E88	dw	0x0009, 0xFFFA, 0xFFF0, 0x0010, 0x0042, 0x0060, 0x0076, 0x0082
0:E90	dw	0x004B, 0xFFD1, 0xFFA4, 0x002B, 0x00DF, 0x00EF, 0x0097, 0x00DB
0:E98	dw	0x01B8, 0x01DB, 0x00E2, 0x00CE, 0x03AC, 0x0834, 0x0A67, 0x1374
0:EA0	dw	0x0361, 0x0031, 0xFFDF, 0x00BA, 0x00E7, 0x0067, 0x002A, 0x0072
0:EA8	dw	0x00BF, 0x00B8, 0x0074, 0x001D, 0xFFD1, 0xFFB8, 0xFFEB, 0x003C
0:EB0	dw	0x0060, 0x0044, 0x001F, 0x0020, 0x003F, 0x0057, 0x004C, 0x0027
0:EB8	dw	0x0007, 0x000E, 0x0037, 0x0055, 0x0043, 0x0012, 0xFFF4, 0xFFFD
0:EC0	dw	0x0015, 0x0022, 0x001D, 0x0006, 0xFFE5, 0xFFCF, 0xFFDB, 0xFFFE
0:EC8	dw	0x0010, 0x0000, 0xFFEB, 0xFFF0, 0x0000, 0x0000, 0x0000

0:ECF	dw	0x0000, 0x0000, 0x0000, 0x0030, 0x0007, 0xFFEA, 0xFFE3, 0xFFF6
0:ED7	dw	0x0018, 0x0036, 0x003B, 0x001D, 0xFFDC, 0xFF8B, 0xFF47, 0xFF2B
0:EDF	dw	0xFF47, 0xFF9D, 0x000D, 0x005A, 0x0053, 0x0018, 0xFFFB, 0x0017
0:EE7	dw	0x0035, 0x002F, 0x0026, 0x0038, 0x0043, 0x0039, 0x004B, 0x006B
0:EEF	dw	0x0010, 0xFF0E, 0xFE48, 0xFE9D, 0xFF88, 0xFFDF, 0xFFD1, 0x0098
0:EF7	dw	0x01F5, 0x01D8, 0xFFC7, 0xFEDC, 0x0220, 0x0791, 0x08E5, 0x1801
0:EFF	dw	0x04D8, 0x0099, 0x002F, 0x00C8, 0x0098, 0x0024, 0x0040, 0x0086
0:F07	dw	0x004A, 0xFFAE, 0xFF30, 0xFEF6, 0xFEF4, 0xFF44, 0xFFD6, 0x0041
0:F0F	dw	0x004A, 0x0038, 0x0059, 0x0085, 0x0072, 0x002C, 0xFFFD, 0xFFFF
0:F17	dw	0x0011, 0x001D, 0x001D, 0xFFFE, 0xFFB4, 0xFF64, 0xFF45, 0xFF69
0:F1F	dw	0xFFAB, 0xFFE1, 0xFFFB, 0x0007, 0x0014, 0x0020, 0x0018, 0xFFFB
0:F27	dw	0xFFEC, 0x0006, 0x0030, 0x003E, 0x0000, 0x0000, 0x0000


0:F2E	dw	dup (0x0000) times 69


0:F73	dw	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
0:F7B	dw	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
0:F83	dw	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
0:F8B	dw	0x0000, 0x0000, 0xFE8D, 0xFF3C, 0xFEF4, 0xFE00, 0xFED1, 0xFEC5
0:F93	dw	0xFF48, 0xFFB4, 0x0114, 0xFF00, 0x012A, 0x00C4, 0x03DE, 0x00EC
0:F9B	dw	0x045A, 0xFF82, 0x1119, 0x1995, 0x0317
0:FA0	dw	0x0000, 0x0000, 0x0000, 0x0000
0:FA4	dw	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 
0:FAC	dw	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 
0:FB4	dw	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 
0:FBC	dw	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 
0:FC4	dw	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 
0:FCC	dw	0x0000, 0x0000, 0x0000, 0xC000, 0x0000, 0x0000, 0x0000, 0x0000, 


0:FD4	dw	dup (0x0000) times 44
