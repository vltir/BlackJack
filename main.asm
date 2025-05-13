ORG 0000H
    LJMP MAIN

; --- UART Init ---
UART_INIT:
    MOV TMOD, #20H        ; Timer1, Modus 2 (8-Bit Auto-Reload)
    MOV TH1, #0FDH        ; 9600 Baud bei 11.0592 MHz
    MOV SCON, #50H        ; UART Mode 1, REN=1
    SETB TR1              ; Timer1 starten
    RET

; --- UART Send ---
SEND_CHAR:
    JNB TI, $
    CLR TI
    MOV SBUF, A
    RET

SEND_STRING:
    CLR A
SEND_LOOP:
    MOVC A, @A+DPTR
    JZ DONE_SEND
    ACALL SEND_CHAR
    INC DPTR
    CLR A
    SJMP SEND_LOOP
DONE_SEND:
    RET

; --- UART Receive ---
RECEIVE_CHAR:
    JNB RI, $
    CLR RI
    MOV A, SBUF
    RET

; --- Zufall (nicht echt, reicht für Demo) ---
RAND_CARD:
    INC R7
    MOV A, R7
    ANL A, #0FH
    ADD A, #1         ; Werte 1–16
    CJNE A, #12, OKRAND
    MOV A, #10        ; keine Bildkarten, 10 als Ersatz
OKRAND:
    RET

; --- Zahl als ASCII senden ---
SEND_NUM:
    ; A enthält Zahl (1–99)
    MOV B, #10
    DIV AB            ; A = Ziffer 10er, B = Einer
    ADD A, #30H
    ACALL SEND_CHAR
    MOV A, B
    ADD A, #30H
    ACALL SEND_CHAR
    RET

; --- Spieler Logik ---
PLAYER_TURN:
    MOV R0, #0        ; Summe
    ACALL RAND_CARD
    MOV R1, A
    ACALL RAND_CARD
    ADD A, R1
    MOV R0, A         ; Spieler-Summe

    MOV DPTR, #MSG_YOURCARDS
    ACALL SEND_STRING
    MOV A, R0
    ACALL SEND_NUM
    ACALL SEND_CRLF

PLAYER_DECIDE:
    MOV DPTR, #MSG_HITSTAND
    ACALL SEND_STRING
    ACALL RECEIVE_CHAR
    CJNE A, #'h', CHECK_STAND
    ; Hit
    ACALL RAND_CARD
    ADD A, R0
    MOV R0, A
    MOV DPTR, #MSG_NEWCARD
    ACALL SEND_STRING
    MOV A, R0
    ACALL SEND_NUM
    ACALL SEND_CRLF
    CJNE A, #21, UNDER21
    SJMP PLAYER_DONE
UNDER21:
    JC PLAYER_DECIDE   ; Wenn A < 21
    SJMP PLAYER_DONE   ; Wenn > 21 → Bust
CHECK_STAND:
    CJNE A, #'s', PLAYER_DECIDE
PLAYER_DONE:
    RET

; --- Dealer Logik ---
DEALER_TURN:
    MOV R2, #0
    ACALL RAND_CARD
    MOV R3, A
    ACALL RAND_CARD
    ADD A, R3
    MOV R2, A
DEALER_LOOP:
    MOV A, R2
    CJNE A, #17, TRY_HIT
    RET
TRY_HIT:
    JC HIT_AGAIN
    RET
HIT_AGAIN:
    ACALL RAND_CARD
    ADD A, R2
    MOV R2, A
    SJMP DEALER_LOOP

; --- Gewinner ---
SHOW_RESULT:
    MOV DPTR, #MSG_RESULT
    ACALL SEND_STRING

    ; Spieler (R0), Dealer (R2)
    MOV A, R0
    CJNE A, #22, CHK_DEALER
    ; Spieler > 21 → Bust
    MOV DPTR, #MSG_LOSE
    ACALL SEND_STRING
    SJMP DONE
CHK_DEALER:
    MOV A, R2
    CJNE A, #22, COMPARE
    ; Dealer Bust → Spieler gewinnt
    MOV DPTR, #MSG_WIN
    ACALL SEND_STRING
    SJMP DONE
COMPARE:
    MOV A, R0
    CLR C
    SUBB A, R2
    JC DEALER_WIN
    JZ DRAW
    ; Spieler > Dealer
    MOV DPTR, #MSG_WIN
    ACALL SEND_STRING
    SJMP DONE
DEALER_WIN:
    MOV DPTR, #MSG_LOSE
    ACALL SEND_STRING
    SJMP DONE
DRAW:
    MOV DPTR, #MSG_DRAW
    ACALL SEND_STRING

DONE:
    ACALL SEND_CRLF
    SJMP $

SEND_CRLF:
    MOV A, #13
    ACALL SEND_CHAR
    MOV A, #10
    ACALL SEND_CHAR
    RET

; --- Strings ---
MSG_WELCOME: DB 13,10,'=== BLACKJACK 8051 ===',13,10,0
MSG_YOURCARDS: DB 'Deine Summe: ',0
MSG_HITSTAND: DB 13,10,'(h)it oder (s)tand? ',0
MSG_NEWCARD: DB 'Neue Summe: ',0
MSG_RESULT: DB 13,10,'== Ergebnis ==',13,10,0
MSG_WIN: DB 'Du GEWINNST!',13,10,0
MSG_LOSE: DB 'Du VERLIERST!',13,10,0
MSG_DRAW: DB 'UNENTSCHIEDEN!',13,10,0

; --- Hauptprogramm ---
MAIN:
    ACALL UART_INIT
    MOV DPTR, #MSG_WELCOME
    ACALL SEND_STRING

    ; Spiel starten
    ACALL PLAYER_TURN
    ACALL DEALER_TURN
    ACALL SHOW_RESULT
    SJMP $

END