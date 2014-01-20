            processor 6502
            org $2000
;
; written for the dasm 2.20.11 assembler
;
; to build:
; dasm a2mp3.asm -f3 -La2mp3.list -oa2mp3
; java -jar ac.jar -d A2MP3XFR.DSK A2MP3
; java -jar ac.jar -p A2MP3XFR.DSK A2MP3 BIN 0x2000 < a2mp3
; where ac.jar is from http://AppleCommander.sourceforge.net/
;
; Sends Vinculum commands ("V3A", "VP") from the A2 to the VMusic2
; MP3 player attached to the A2MP3 card. From, say, Applesoft BASIC
; poke a NULL-terminated Vinuculum command into memory starting at 
; location CMD. Command output is sent to the page starting at STORAGE
; unless SKIPREAD is set to non-zero. (Sometimes the command output 
; causes a problem).
;

; SLOT 3 = $C0B0
; SLOT 4 = $C0C0

ACIA        equ $C0B0
ACIA_DAT    equ ACIA                ; 6551 DATA REGISTER
ACIA_SR     equ ACIA+1              ; 6551 STATUS REGISTER
ACIA_CMD    equ ACIA+2              ; 6551 COMMAND REGISTER
ACIA_CTRL   equ ACIA+3              ; 6551 CONTROL REGISTER
STORAGE     equ $2100               ; DATA BUFFER
STOREPTR    equ $06                 ; ZERO-PAGE POINTER TO DATA BUFFER
SKIPREAD    equ $20DE               ; FLAG TO SKIP JMP READ256 IN SENDSTR
FIRSTCHAR   equ $20DF
CMD         equ $20E0               ; POKE COMMMAND STRING INTO ADDR 8416 
CMDPTR      equ $08
COUT        equ $FDF0
PRBYTE      equ $FDDA
BELL        equ $87

LOCRPL      equ $03E3               ; LOCATE RWTS PARMLIST (IOB) SUBRTN
RWTS        equ $03E9               ; RWTS MAIN ENTRY
IOBPTR      equ $FD
SECBUF      equ $2100

;-------------------------------------------------------------------------------
; INITIALIZE THE 6551 CHIP
;-------------------------------------------------------------------------------
INIT        LDA     #<SECBUF        ; SAVE ADDRESS OF STORAGE (LSB)
            STA     STOREPTR        ; IN ZERO PAGE LOCATION $06,$07
            LDA     #>SECBUF        ; (MSB)
            STA     STOREPTR+1
            LDA     #<CMD           ; SAVE ADDRESS OF COMMAND STRING (LSB)
            STA     CMDPTR          ; IN ZERO PAGE LOCATION $08, $09
            LDA     #>CMD           ; (MSB)
            STA     CMDPTR+1
            LDA     #$10            ; SET BAUD RATE ($10=115K,$1E=9600)
            STA     ACIA_CTRL       ; ($10 = 16 x EXTERNAL CLOCK) 1 STOP BIT
            LDA     #$0B            ; PARITY DISABLED, TX+RX IRQ DISABLED, DTR READY
            STA     ACIA_CMD        ; STORE IN 6551 COMMAND REGISTER
            RTS

;-------------------------------------------------------------------------------
; SEND STRING TO 6551
;-------------------------------------------------------------------------------
SENDST      LDA     #$01
            STA     FIRSTCHAR
            LDY     #$00
NEXTCH1     LDA     (CMDPTR),Y
            BEQ     EOS             ; ON ZERO, END OF STRING REACHED
            JSR     SENDCH
SKIPCH      INY
            JMP     NEXTCH1
EOS         LDA     SKIPREAD        ; BASIC PROGRAM MAY NEED TO SKIP READ256
            BNE     SENDDONE
            JMP     READ256         ; IMMEDIATELY TRY READING FROM 6551
SENDDONE    RTS

;-------------------------------------------------------------------------------
; SEND CHAR TO 6551
;-------------------------------------------------------------------------------
SENDCH      STA     ACIA_DAT        ; SEND BYTE TO 6551 DATA REGISTER
NOT_EMPTY   LDA     ACIA_SR         ; TEST "TRANSMITTER DATA REGISTER EMPTY" FLG
            AND     #$10            ; IN STATUS REG (BIT4) 0=NOT_EMPTY 1=EMPTY
            BEQ     NOT_EMPTY       ; WAIT FOR "EMPTY"
            RTS

;-------------------------------------------------------------------------------
; SEND 256 CHARS TO 6551
;-------------------------------------------------------------------------------
SEND256     LDY     #$00
NEXTCH2     LDA     (STOREPTR),Y
            JSR     SENDCH
            INY
            BNE     NEXTCH2         ; Y WILL HIT 0 AGAIN AFTER 256 LOOPS
            RTS

;-------------------------------------------------------------------------------
; READ 256 BYTES
;-------------------------------------------------------------------------------
READ256     LDX     #$00
            LDY     #$00
NEXTCHAR1   CPX     #$E9
            BEQ     BAIL1
            INX
            LDA     ACIA_SR
            AND     #$08
            BEQ     NEXTCHAR1
            LDX     #$00
            LDA     ACIA_DAT
            STA     (STOREPTR),Y
            LDA     FIRSTCHAR
            BNE     SKIPIT
            INY
            BNE     NEXTCHAR1       ; UNTIL 256 BYTES, Y <> $00
BAIL1       RTS

SKIPIT      LDA     #$00            ; VERY FIRST CHAR FROM OUTPUT IS TRASH
            STA     FIRSTCHAR       ; I WANT TO SKIP IT SO
            JMP     NEXTCHAR1

;-------------------------------------------------------------------------------
; GET THE ADDRESS OF THE INPUT/OUTPUT CONTROL BLOCK (IOB)
; AFTER CALLING 03E3 A = MSB of IOB, Y = LSB of IOB
;-------------------------------------------------------------------------------
GETIOB      JSR     LOCRPL          ; CALL TO GET ADDRESS OF IOB
            STY     IOBPTR          ; Y = LSB OF IOB
            STA     IOBPTR + 1      ; A = MSB OF IOB
            RTS

;-------------------------------------------------------------------------------
; GET THE ADDRESS OF THE INPUT/OUTPUT CONTROL BLOCK (IOB)
; AFTER CALLING 03E3 A = MSB of IOB, Y = LSB of IOB
;-------------------------------------------------------------------------------
CALLRWTS    JSR     LOCRPL          ; CALL TO GET ADDRESS OF IOB
            JSR     $03D9
            LDA     #$00            ; RWTS USES A MEM LOC SHARED WITH MONITOR
            STA     $0048           ; RESET IT TO 0 AFTER CALLING RWTS
            BCC     EXITRWTS       ; ON RETURN FROM RWTS CARRY SET IF ERROR
            LDA     #BELL           ; BEEP AND PRINT RC=$xx
            JSR     COUT
            LDA     #'R
            JSR     COUT
            LDA     #'C
            JSR     COUT
            LDA     #'=
            JSR     COUT
            LDY     #$0D
            LDA     (IOBPTR),Y
            JSR     PRBYTE
EXITRWTS    RTS

;-------------------------------------------------------------------------------
; END OF FILE
;-------------------------------------------------------------------------------
