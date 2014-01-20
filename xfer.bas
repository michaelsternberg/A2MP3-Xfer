100 REM USB2DSK.BAS
110 REM USE A2MP3 CARD IN SLOT 3 TO 
120 REM XFER DOS 3.3 FLOPPIES TO USB THUMBDRIVE

140 HOME : PRINT "INFO> LOADING A2MP3"
150 PRINT CHR$ (4); "BLOAD A2MP3"
160 GOSUB 2000 : REM "DEFINE_CALLS"
170 GOSUB 1400 : REM "RWTS_GETIOB"
180 GOSUB 1200 : REM "INIT_6551"
190 LET SL = 6 : LET DR = 1

200 REM "MAIN_LOOP"
210     GOSUB 300 : REM "SHOW_MENU"
220     IF CH$ =  "1" THEN GOSUB 500 : REM "XFER_FLOPPY"
230     IF CH$ =  "2" THEN GOSUB 900 : REM "XFER_USB"
240     IF CH$ =  "3" THEN GOSUB 2100 : REM "FORMAT_FLOPPY"
250     IF CH$ <> "4" THEN GOTO 200
260 END

300 REM "SHOW_MENU"
310 HOME
320 PRINT "======================================="
330 PRINT "              MAIN MENU                "
340 PRINT "======================================="
350 PRINT "[1] TRANSFER FLOPPY TO USB"
360 PRINT "[2] TRANSFER USB TO FLOPPY"
370 PRINT "[3] FORMAT FLOPPY"
380 PRINT "[4] QUIT"
390 PRINT "======================================="
400 INPUT "ENTER CHOICE:";CH$
410 RETURN

500 REM "XFER_FLOPPY"
510 HOME
520 PRINT "======================================="
530 PRINT "       TRANSFER FLOPPY TO USB"
540 PRINT "======================================="
550 INPUT "ENTER FILENAME (8.3):";FL$
560 PRINT "IS "; FL$; " CORRECT (Y/<N>)";: INPUT R$
570 IF R$ <> "Y" AND R$ <> "y" THEN RETURN
580 HOME
590 PRINT "======================================="
600 PRINT "         TRANSFERRING TO USB"
610 PRINT "======================================="
620 GOSUB 1900 : REM "DRAW_GRID"
650 GOSUB 1500 : REM "RWTS_INIT"
660 LET V$ = "OPW " + FL$   : GOSUB 1300 : REM "SEND_VIN_CMD"
670 LET TX = 3: LET TY = 6
680 FOR TR = 0 TO 9
690     LET V$ = "WRF 4096" : GOSUB 1300 : REM "SEND_VIN_CMD"
700     FOR SE = 0 TO 0
710         HTAB TX : VTAB TY : PRINT "*"
720         GOSUB 1600 : REM "RWTS_READ_SECTOR"
730         CALL S256                   : REM SEND256
740         HTAB TX : VTAB TY : PRINT CHR$(255)
750         LET TX = TX + 1
760         IF TX > 37 THEN TX = 3 : TY = TY + 1
770     NEXT SE
780 NEXT TR
790 LET V$ = "CLF" : GOSUB 1300 : REM "SEND_VIN_CMD"
800 RETURN

900 REM "XFER_USB"
910 HOME : PRINT "======================================="
920 PRINT "       TRANSFER USB TO FLOPPY"
930 PRINT "======================================="
940 INPUT "ENTER FILENAME (8.3):";FL$
950 PRINT "IS "; FL$; " CORRECT (Y/<N>)"; : INPUT R$
960 IF R$ <> "Y" AND R$ <> "y" THEN RETURN
970 HOME : PRINT "======================================="
980 PRINT "        TRANSFERRING TO FLOPPY"
990 PRINT "======================================="
1000 GOSUB 1900 : REM "DRAW_GRID"
1020 GOSUB 1500 : REM "RWTS_INIT"
1030 LET V$ = "OPR " + FL$  : GOSUB 1300 : REM "SEND_VIN_CMD"
1040 LET TX = 3 : LET TY = 6
1050 FOR TR = 0 TO 34
1060    LET V$ = "RDF 4096" : GOSUB 1300 : REM "SEND_VIN_CMD"
1070    FOR I = 0 TO 250 : NEXT I 
1080    FOR SE = 0 TO 15
1090        HTAB TX : VTAB TY : PRINT "*"
1100        CALL R256
1105        CALL SW256
1110        GOSUB 1700 : REM "RWTS_WRITE_SECTOR"
1120        HTAB TX : VTAB TY : PRINT CHR$(255)
1130        LET TX = TX + 1
1140        IF TX > 37 THEN TX = 3 : TY = TY + 1
1150     NEXT SE
1160 NEXT TR
1170 LET V$ = "CLF" : GOSUB 1300 : REM "SEND_VIN_CMD"
1180 RETURN
  
1200 REM "INIT_6551"
1210 PRINT "INFO> INITIALIZING 6551"
1220 CALL I6551
1230 FOR I = 1 TO 250: NEXT I           : REM WAIT FOR INIT
1250 RETURN

1300 REM "SEND_VIN_CMD"
1310 FOR I = 1 TO LEN(V$)
1320 LET CH = ASC (MID$ (V$, I, 1))
1330 POKE CMD + I - 1, CH
1340 NEXT I
1350 POKE CMD + I - 1, 13       : REM CR ($0D)
1360 POKE CMD + I, 0            : REM NULL ($00)
1370 CALL SSTR
1380 FOR I = 1 TO 25 : NEXT I   : REM SMALL WAIT FOR VMUSIC2
1390 RETURN

1400 REM "RWTS_GETIOB"
1410 PRINT "INFO> GETTING IO BLOCK"
1420 CALL GIOB                  : REM GETIOB
1430 LET IOB = PEEK(253) + 256 * PEEK(254)
1440 RETURN

1500 REM "RWTS_INIT"
1510 POKE IOB + 0, 1             : REM TABLE TYPE (ALWAYS $01)
1520 POKE IOB + 1, SL * 16       : REM SLOT NUMBER (TIMES 16)
1530 POKE IOB + 2, DR            : REM DRIVE NUMBER
1540 POKE IOB + 3, 0             : REM NO EXPECTED VOLUME
1550 POKE IOB + 8, 0             : REM (LSB OF $2100 - 256 BYTE BUF FOR RD/WR)
1560 POKE IOB + 9, 2 * 16 + 1    : REM (MSB OF $2100)
1570 RETURN

1600 REM "RWTS_READ_SECTOR"
1610 HTAB 10 : VTAB 5 : PRINT "TRACK: "; TR; " SECTOR: "; SE; " "
1620 POKE IOB + 4, TR            : REM SET TRACK
1630 POKE IOB + 5, SE            : REM SET SECTOR
1640 POKE IOB + 12, 1            : REM SET CMD TO READ
1650 CALL RWTS                   : REM CALLRWTS ($2070)
1660 RETURN

1700 REM "RWTS_WRITE_SECTOR"
1710 HTAB 10 : VTAB 5 : PRINT "TRACK: "; TR; " SECTOR: "; SE; " "
1720 POKE IOB + 4, TR            : REM SET TRACK
1730 POKE IOB + 5, SE            : REM SET SECTOR
1740 POKE IOB + 8, 0
1750 POKE IOB + 9, 2 * 16 + 1
1760 POKE IOB + 12, 2            : REM SET CMD TO READ
1770 CALL RWTS                   : REM CALLRWTS
1780 RETURN

1800 REM "RWTS_FORMAT"
1810 PRINT "INSERT TARGET DISK, HIT RETURN"
1820 INPUT R$
1830 POKE IOB + 1, SL * 16
1840 POKE IOB + 2, DR
1850 POKE IOB + 3, 0
1860 POKE IOB + 12, 4            : REM SET CMD TO FORMAT
1870 CALL RWTS
1880 PRINT "RETURN CODE: "; PEEK (IOB + 13)
1890 RETURN

1900 REM "DRAW_GRID"
1910 FOR Y = 0 TO 15
1920    HTAB 3 : VTAB Y + 6 
1930    PRINT "..................................."
1940 NEXT Y
1950 
1960 RETURN

2000 REM "DEFINE_CALLS"
2010 PRINT "INFO> ASSIGNING CALLS"
2020 LET I6551 = 8192 : REM INIT6551 ($2000)
2030 LET SSTR  = 8219 : REM SENDST   ($201B)
2040 LET S256  = 8244 : REM SEND256  ($2036)
2050 LET R256  = 8291 : REM READ256  ($2065)
2060 LET SW256 = 8316 : REM SWAP256  ($207E)
2070 LET GIOB  = 8335 : REM GETIOB   ($2077)
2080 LET RWTS  = 8343 : REM CALLRWTS ($207F)
2090 LET CMD   = 8416 : REM CMD BUFFER ($20E0)
2095 RETURN

2100 REM "FORMAT_FLOPPY"
2110 HOME
2120 PRINT "======================================="
2130 PRINT "            FORMAT FLOPPY"
2140 PRINT "======================================="
2150 PRINT "FORMAT (Y/<N>)"; : INPUT R$
2160 IF R$ = "Y" OR R$ = "y" THEN GOSUB 1800 : REM "RWTS_FORMAT"
2170 RETURN