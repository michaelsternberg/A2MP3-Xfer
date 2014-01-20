;
; written for the dasm 2.20.11 assembler
;
; to build:
; dasm usb.asm -f3 -Llist -oout
; java -jar ac.jar -d mp3.dsk OUT
; java -jar ac.jar -p mp3.dsk OUT BIN 0x2000 < out
;
; Sends Vinculum commands ("V3A", "VP") from the A2 to the VMusic2
; MP3 player attached to the A2MP3 card. From, say, Applesoft BASIC
; poke a NULL-terminated Vinuculum command into memory starting at 
; location CMD.
;
; If a Vinculum command is expected to send a response (such as "DIR")
; then precede the command with a "<" ("<DIR"). This will tell the
; program to send the VMusic2 output to a buffer (STOREPTR)
;
            processor 6502
            org $2000

; SLOT 3 = $C0B0
; SLOT 4 = $C0C0

ACIA        equ $C0B0
ACIA_DAT    equ ACIA                ; 6551 DATA REGISTER
ACIA_SR     equ ACIA+1              ; 6551 STATUS REGISTER
ACIA_CMD    equ ACIA+2              ; 6551 COMMAND REGISTER
ACIA_CTRL   equ ACIA+3              ; 6551 CONTROL REGISTER
STORAGE     equ $2100               ; DATA BUFFER
STOREPTR    equ $06                 ; ZERO-PAGE POINTER TO DATA BUFFER
FIRSTCHAR   equ $20DF
CMD         equ $20E0               ; POKE COMMMAND STRING INTO ADDR 8416 
CMDPTR      equ $08
COUT        equ $FDF0
CROUT       equ $FD8E
WAIT        equ $FCA8               ; DELAYS (26+27A+5A^2)/2 uSECS A=A REG

LOCRPL      equ $03E3               ; LOCATE RWTS PARMLIST (IOB) SUBRTN
RWTS        equ $03E9               ; RWTS MAIN ENTRY
IOBPTR      equ $FD
SECBUF      equ $2100
SEEK        equ $00
READ        equ $01
WRITE       equ $02

;-------------------------------------------------------------------------------
; INITIALIZE THE 6551 CHIP
;-------------------------------------------------------------------------------
INIT        LDA     #$00            ; SAVE ADDRESS OF STORAGE
            STA     STOREPTR        ; IN ZERO PAGE LOCATION $06,$07
            LDA     #$21            
            STA     STOREPTR+1
            LDA     #$E0            ; SAVE ADDRESS OF COMMAND STRING
            STA     CMDPTR          ; IN ZERO PAGE LOCATION $08, $09
            LDA     #$20
            STA     CMDPTR+1
            LDA     #$10            ; SET BAUD RATE ($10=115K,$1E=9600)
            STA     ACIA_CTRL       ; ($10 = 16 x EXTERNAL CLOCK) 1 STOP BIT
            LDA     #$0B            ; PARITY DISABLED, TX+RX IRQ DISABLED, DTR READY
            STA     ACIA_CMD        ; STORE IN 6551 COMMAND REGISTER
            RTS

;-------------------------------------------------------------------------------
; SEND STRING TO 6551
;-------------------------------------------------------------------------------
SENDST      LDY     #$00
NEXTCH1     LDA     (CMDPTR),Y
            BEQ     EOS             ; ON ZERO, END OF STRING REACHED
            JSR     SENDCH
SKIPCH      INY
            JMP     NEXTCH1
EOS         RTS
;EOS         JMP     READCH          ; IMMEDIATELY TRY READING FROM 6551

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
; READ CHAR FROM 6551
;-------------------------------------------------------------------------------
READCH      LDX     #$00
            LDY     #$00
NEXTCHAR    CPX     #$E9            ; NO RESPONSE IN A WHILE. ASSUME DONE
            BEQ     BAIL
            INX
            LDA     ACIA_SR         ; TEST "RECEIVER DATA REGISTER FULL" FLG
            AND     #$08            ; IN STATUS REG (BIT3) 0=NEXTCHAR 1=FULL
            BEQ     NEXTCHAR        ; WAIT FOR "FULL"
            LDX     #$00
            LDA     ACIA_DAT        ; GET CHAR FROM 6551
            STA     (STOREPTR),Y    ; COPY CHAR TO STRING BUFFER
            INY
            BNE     NEXTCHAR        ; GET NEXT CHAR NOW IF Y < $FF
            INC     STOREPTR+1      ; EXCEEDED $FF BYTES, INCREMENT PAGE
            JMP     NEXTCHAR        ; GET NEXT CHAR
BAIL        LDA     #$00             
            STA     (STOREPTR),Y    ; APPEND TERMINATOR TO STRING BUFFER
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
            LDA     ACIA_DAT
            STA     (STOREPTR),Y
            INY
            BNE     NEXTCHAR1       ; UNTIL 256 BYTES, Y <> $00
BAIL1       RTS

;-------------------------------------------------------------------------------
; SWAP PAIRS OF BYTES IN PAGE (A9 00 B8 01...) BECOMES (00 A9 01 B8...)
;-------------------------------------------------------------------------------
SWAP256     LDY     #$00
NEXTCHAR2   LDA     (STOREPTR),Y
            TAX     
            INY
            LDA     (STOREPTR),Y
            DEY 
            STA     (STOREPTR),Y
            TXA
            INY
            STA     (STOREPTR),Y
            INY
            BNE     NEXTCHAR2       ; UNTIL 256 BYTES, Y <> $00
            RTS

;-------------------------------------------------------------------------------
; GET THE ADDRESS OF THE INPUT/OUTPUT CONTROL BLOCK (IOB)
; AFTER CALLING 03E3 A = MSB of IOB, Y = LSB of IOB
;-------------------------------------------------------------------------------
GETIOB      JSR LOCRPL              ; CALL TO GET ADDRESS OF IOB
            STY IOBPTR              ; Y = LSB OF IOB
            STA IOBPTR + 1          ; A = MSB OF IOB
            RTS

;-------------------------------------------------------------------------------
; GET THE ADDRESS OF THE INPUT/OUTPUT CONTROL BLOCK (IOB)
; AFTER CALLING 03E3 A = MSB of IOB, Y = LSB of IOB
;-------------------------------------------------------------------------------
CALLRWTS    LDY IOBPTR
            LDA IOBPTR + 1
            JSR $03D9
            LDA #$00                ; RWTS USES A MEM LOC SHARED WITH MONITOR
            STA $0048               ; RESET IT TO 0 AFTER CALLING RWTS
            RTS

;-------------------------------------------------------------------------------
; END OF FILE
;-------------------------------------------------------------------------------
