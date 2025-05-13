.model small
.stack 100h

.data
    ; Card deck (6K, 6Q, 6A, 2J)
    deck          db 0,0,0,0,0,0, 1,1,1,1,1,1, 2,2,2,2,2,2, 3,3  
    deck_size     equ 20

    ; Game state
    table_type    db ?          ; 0=Kings, 1=Queens, 2=Aces
    seed          db 0
    player_hand   db 5 dup(?)
    ai_hand       db 5 dup(?)
    selected_cards db 5 dup(0)
    input_buffer  db 10 dup(?)
    empty_slot    db 255
    roulette_counter db 0
    ai_claim_count db ?

    ; Strings
    kings_str     db 'Kings $'
    queens_str    db 'Queens$'
    aces_str      db 'Aces  $'
    card_symbols  db 'KQAJ'    ; 0=K, 1=Q, 2=A, 3=J
    card_template db '[ ] $'
    msg_empty     db '[X] $'

    ; Messages
    msg_welcome   db 'LIAR',39,'S BAR',13,10,'$'
    msg_table     db 13,10,'Table Type: $'
    msg_player    db 13,10,'Your hand: $'
    msg_ai        db 13,10,'AI hand:   $'
    msg_choose    db 13,10,'Select cards (1-5, comma separated): $'
    msg_play      db 13,10,'You played: $'
    msg_claim     db 13,10,'Claim: $'
    msg_ai_claim  db 13,10,'AI claims: $'
    msg_ai_plays  db 13,10,'AI plays: $'
    msg_truth_reveal db 13,10,'Revealed cards: $'
    msg_invalid   db 13,10,'Invalid input! Use format like "1,3,5"$'
    msg_prompt    db 13,10,13,10,'Press any key to continue...$'
    msg_ai_playing db 13,10,'AI is playing cards...$'
    msg_ai_lied    db ' AI was bluffing!$'
    msg_player_lied db ' You were bluffing!$'
    msg_challenge_prompt db 13,10,'Call liar? (Y/N): $'
    msg_liar       db 13,10,'AI calls "LIAR!"$'
    msg_auto_challenge db 13,10,'HAND EMPTY! Automatic challenge!',13,10,'$'
    msg_ai_forced_challenge db 'AI is forced to call LIAR!',13,10,'$'
    msg_player_forced_challenge db 'You must call LIAR!',13,10,'$'
    msg_roulette   db 13,10,'RUSSIAN ROULETTE! Trigger #$'
    msg_bang       db ' BANG! Game over.$'
    msg_click      db ' *CLICK*$'
    ai_hidden_card db '[?] $'
    
    ;Debug only
    msg_table_type db 'Table type: ', '$'
    msg_selected_cards db 13, 10, 'Selected card values: ', '$'


.code
main proc
    mov ax, @data
    mov ds, ax
    
game_round:
    call clear_screen
    call select_table_type
    call show_table_type
    call enhanced_shuffle
    call deal_cards
    
round_turns:
    call clear_screen
    call show_table_type
    call display_hands
    
    ; Player turn
    call player_multi_turn
    call check_hands_empty
    cmp ax, 1
    je game_round
    
    ; AI turn
    call ai_turn
    call check_hands_empty
    cmp ax, 1
    je game_round
    
    ; Continue round
    mov ah, 09h
    lea dx, msg_prompt
    int 21h
    mov ah, 01h
    int 21h
    
    jmp round_turns
    
    mov ah, 4Ch
    int 21h
main endp

; === GAME PROCEDURES === 
select_table_type proc
    push ax
    push dx
    
    ; Get system time (more random than timer ticks)
    mov ah, 2Ch
    int 21h        ; DH=seconds, DL=1/100 seconds
    
    ; Use milliseconds for better randomness
    mov al, dl
    xor ah, ah
    mov dl, 3
    div dl         ; AH=remainder (0-2)
    
    mov table_type, ah  ; 0=Kings, 1=Queens, 2=Aces
    
    pop dx
    pop ax
    ret
select_table_type endp

show_table_type proc
    push ax
    push dx
    
    mov ah, 09h
    lea dx, msg_table
    int 21h
    
    ; Load correct string based on table_type (0-2)
    mov al, table_type
    cmp al, 0
    je show_kings
    cmp al, 1
    je show_queens
    
    ; Default to Aces
    lea dx, aces_str
    jmp display_type
    
show_kings:
    lea dx, kings_str
    jmp display_type
    
show_queens:
    lea dx, queens_str
    
display_type:
    mov ah, 09h
    int 21h
    
    pop dx
    pop ax
    ret
show_table_type endp


enhanced_shuffle proc
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    
    ; Seed RNG
    mov ah, 2Ch
    int 21h
    mov al, dh
    add al, dl
    mov seed, al
    
    mov cx, deck_size
shuffle_loop:
    ; Pseudo-random: seed = (seed * 13 + 17)
    mov al, seed
    mov bl, 13
    mul bl
    add ax, 17
    mov seed, al
    
    ; Calculate swap position
    xor dx, dx
    mov bx, deck_size
    div bx
    
    ; Perform swap
    mov si, cx
    dec si
    mov di, dx
    
    mov al, [deck + si]
    mov bl, [deck + di]
    mov [deck + si], bl
    mov [deck + di], al
    
    loop shuffle_loop
    
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
enhanced_shuffle endp

deal_cards proc
    push ax
    push cx
    push si
    push di
    
    ; Deal to player (first 5 cards)
    mov cx, 5
    mov si, 0
deal_player:
    mov al, [deck + si]
    mov [player_hand + si], al
    inc si
    loop deal_player
    
    ; Deal to AI (next 5 cards)
    mov cx, 5
    mov di, 0
deal_ai:
    mov al, [deck + si]
    mov [ai_hand + di], al
    inc si
    inc di
    loop deal_ai
    
    pop di
    pop si
    pop cx
    pop ax
    ret
deal_cards endp


; === UPDATED PLAYER TURN ===
player_multi_turn proc
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    call clear_screen
    call show_table_type
    call display_hands

    mov cx, 5
    mov si, 0
clear_selection:
    mov [selected_cards + si], 0
    inc si
    loop clear_selection
input_loop:
    ; Show input prompt
    mov ah, 09h
    lea dx, msg_choose
    int 21h

    ; Get user input
    mov ah, 0Ah
    lea dx, input_buffer
    mov byte ptr [input_buffer], 8
    int 21h

    ; Process input string
    mov si, 2       ; Start of actual input
    mov cx, 0       ; Card count
process_char:
    mov al, [input_buffer + si]
    cmp al, 0Dh     ; Check for Enter
    je end_of_input

    ; Validate digit (1-5)
    cmp al, '1'
    jb input_error
    cmp al, '5'
    ja input_error

    ; Convert to 0-based index
    sub al, '1'
    mov bl, al
    xor bh, bh

    ; Check if card slot is empty
    cmp [player_hand + bx], 255
    je input_error

    ; Check if already selected
    cmp [selected_cards + bx], 1
    je input_error

    ; Mark card as selected
    mov [selected_cards + bx], 1
    inc cx          ; Increment valid card count

    ; Move to next character
    inc si
    mov al, [input_buffer + si]
    cmp al, 0Dh     ; End of input
    je end_of_input
    cmp al, ','     ; Comma separator
    jne input_error
    inc si          ; Skip comma
    jmp process_char

input_error:
    mov ah, 09h
    lea dx, msg_invalid
    int 21h
    jmp input_loop

end_of_input:
    ; Must select at least one card
    cmp cx, 0
    je input_error

    ; Display played cards
    mov ah, 09h
    lea dx, msg_play
    int 21h

    mov bx, offset card_symbols
    mov si, 0
show_played_cards:
    cmp [selected_cards + si], 1
    jne skip_display
    mov al, [player_hand + si]
    xlat
    mov [card_template + 1], al
    push dx
    lea dx, card_template
    mov ah, 09h
    int 21h
    pop dx
skip_display:
    inc si
    cmp si, 5
    jb show_played_cards

    ; Automatic claim
    mov ah, 09h
    lea dx, msg_claim
    int 21h
    mov dl, cl          ; Number of cards played
    add dl, '0'
    mov ah, 02h
    int 21h
    mov dl, ' '
    int 21h
    mov bx, offset card_symbols
    mov al, table_type
    xlat
    mov ah, 02h
    int 21h

    ; Remove played cards from hand
    mov si, 0
remove_cards:
    cmp si, 5
    jae cards_removed
    cmp [selected_cards + si], 1
    jne skip_removal
    mov [player_hand + si], 255
skip_removal:
    inc si
    jmp remove_cards

cards_removed:
    ; Check if player's hand is empty
    mov cx, 5
    mov si, 0
check_empty:
    cmp [player_hand + si], 255
    jne hand_not_empty
    inc si
    loop check_empty
    
    ; Player hand empty - force AI challenge
    mov ah, 09h
    lea dx, msg_auto_challenge
    int 21h
    lea dx, msg_ai_forced_challenge
    int 21h
    call reveal_played_cards
    call verify_player_claim
    jmp turn_complete
    
hand_not_empty:
    ; Normal AI challenge
    call ai_challenge
    cmp al, 1
    jne turn_complete
    call reveal_played_cards 
    call verify_player_claim

turn_complete:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
player_multi_turn endp

; === UPDATED AI TURN ===
ai_turn proc
    push ax
    push bx
    push cx
    push dx
    push si

    mov ah, 09h
    lea dx, msg_ai_playing
    int 21h

    ; Decide how many to play (1-3)
    call random_number
    and ax, 3
    jnz not_zero
    inc ax
not_zero:

    ; Count how many cards AI actually has
    mov cx, 5
    mov si, 0
    mov bx, 0
count_ai_cards:
    cmp [ai_hand + si], 255
    je skip_ai_count
    inc bx
skip_ai_count:
    inc si
    loop count_ai_cards

    ; Limit AI's claim to number of cards it actually holds
    cmp ax, bx
    jbe keep_ax
    mov ax, bx
keep_ax:
    mov ai_claim_count, al

    ; Show face-down cards
    mov ah, 09h
    lea dx, msg_ai_plays
    int 21h

    mov cl, ai_claim_count
    mov ch, 0
show_hidden:
    push cx
    lea dx, ai_hidden_card
    mov ah, 09h
    int 21h
    pop cx
    loop show_hidden

    ; New line after cards
    mov ah, 02h
    mov dl, 13
    int 21h
    mov dl, 10
    int 21h

    ; Display claim
    mov ah, 09h
    lea dx, msg_ai_claim
    int 21h
    mov dl, ai_claim_count
    add dl, '0'
    mov ah, 02h
    int 21h
    mov dl, ' '
    int 21h
    mov bx, offset card_symbols
    mov al, table_type
    xlat
    mov ah, 02h
    int 21h

    ; === EARLY CHECK: will AI have 0 cards after this move?
    ; Simulate AI hand after playing cards
    mov cx, 5
    mov si, 0
    mov dl, ai_claim_count
    mov bl, 0
check_empty_ahead:
    cmp [ai_hand + si], 255
    jne count_card
    jmp skip_check
count_card:
    inc bl
skip_check:
    inc si
    loop check_empty_ahead

    ; Subtract number of cards being played
    sub bl, ai_claim_count
    cmp bl, 0
    jne skip_force_challenge

    ; If AI will have 0 cards left, force challenge now
    mov ah, 09h
    lea dx, msg_auto_challenge
    int 21h
    lea dx, msg_player_forced_challenge
    int 21h
    call reveal_ai_cards
    call resolve_ai_claim
    jmp after_challenge

skip_force_challenge:
    ; Ask player if they want to challenge
    call prompt_challenge
    cmp al, 0
    je after_challenge
    call reveal_ai_cards
    call resolve_ai_claim

after_challenge:
    ; Remove played cards from AI's hand
    mov cx, 5
    mov si, 0
    mov bl, ai_claim_count
remove_ai_cards:
    cmp bl, 0
    je remove_done
    cmp [ai_hand + si], 255
    jne found_card
    inc si
    jmp remove_ai_cards
found_card:
    mov [ai_hand + si], 255
    dec bl
    inc si
    jmp remove_ai_cards

remove_done:

ai_turn_complete:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
ai_turn endp



; === CARD REVEAL PROCEDURES ===
reveal_played_cards proc
    push ax
    push bx
    push dx
    push si
    
    mov ah, 09h
    lea dx, msg_truth_reveal  ; "Revealed cards: "
    int 21h
    
    mov bx, offset card_symbols
    mov si, 0
show_played:
    cmp [selected_cards + si], 1  ; Check if card was played
    jne skip_show
    
    mov al, [player_hand + si]    ; Get card value (0-3)
    cmp al, 255                   ; Skip if empty slot
    je skip_show
    
    xlat                          ; AL = [BX + AL] (convert to symbol)
    mov [card_template + 1], al   ; Update display template
    
    push dx
    lea dx, card_template         ; "[X] "
    mov ah, 09h
    int 21h
    pop dx
    
skip_show:
    inc si
    cmp si, 5
    jb show_played
    
    pop si
    pop dx
    pop bx
    pop ax
    ret
reveal_played_cards endp

reveal_ai_cards proc
    push ax
    push bx
    push cx
    push dx
    push si
    
    mov ah, 09h
    lea dx, msg_truth_reveal
    int 21h
    
    mov bx, offset card_symbols
    mov si, 0
    mov cl, ai_claim_count  ; Only show claimed number of cards
    mov ch, 0
reveal_loop:
    ; Find next non-empty card
    cmp si, 5
    jae reveal_done
    cmp [ai_hand + si], 255
    je skip_reveal
    
    ; Show actual card
    mov al, [ai_hand + si]
    xlat                     ; Convert to symbol
    mov [card_template + 1], al
    
    push dx
    lea dx, card_template    ; "[X] "
    mov ah, 09h
    int 21h
    pop dx
    
    dec cl                   ; Count down shown cards
    jz reveal_done
    
skip_reveal:
    inc si
    jmp reveal_loop
    
reveal_done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
reveal_ai_cards endp

; === CARD VERIFICATION ===
verify_player_claim proc
    push ax
    push bx
    push cx
    push dx
    push si

    ; --- Print table_type ---
    mov ah, 09h
    lea dx, msg_table_type
    int 21h
    mov al, table_type
    add al, '0'
    mov dl, al
    mov ah, 02h
    int 21h

    ; --- Print selected card values ---
    mov ah, 09h
    lea dx, msg_selected_cards
    int 21h

    mov cx, 5
    mov si, 0
print_selected_loop:
    cmp [selected_cards + si], 1
    jne skip_print

    mov al, [player_hand + si]
    add al, '0'
    mov dl, al
    mov ah, 02h
    int 21h

    mov dl, ' '
    int 21h

skip_print:
    inc si
    loop print_selected_loop

    ; Newline after values
    mov ah, 02h
    mov dl, 13
    int 21h
    mov dl, 10
    int 21h

    ; --- Verify ALL played cards match table_type ---
    mov cx, 5
    mov si, 0
verify_loop:
    cmp [selected_cards + si], 1
    jne skip_verify
    mov al, [player_hand + si]
    cmp al, table_type
    jne player_lied
skip_verify:
    inc si
    loop verify_loop

    ; All cards matched
    mov ah, 09h
    lea dx, msg_ai_lied
    int 21h
    call trigger_roulette  ; AI was wrong
    jmp verify_done

player_lied:
    mov ah, 09h
    lea dx, msg_player_lied
    int 21h
    call trigger_roulette  ; Player was lying

verify_done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
verify_player_claim endp

resolve_ai_claim proc
    push bx
    push cx
    push si
    
    ; Count AI's actual matching cards
    mov cx, 5
    mov si, 0
    xor bl, bl
count_matches:
    cmp [ai_hand + si], 255
    je skip_count
    mov al, [ai_hand + si]
    cmp al, table_type
    jne skip_count
    inc bl
skip_count:
    inc si
    loop count_matches
    
    ; Compare to claimed count
    cmp bl, ai_claim_count
    jae ai_truthful
    
    ; AI lied
    mov ah, 09h
    lea dx, msg_ai_lied
    int 21h
    call trigger_roulette
    jmp resolve_done
    
ai_truthful:
    ; Player was wrong
    mov ah, 09h
    lea dx, msg_player_lied
    int 21h
    call trigger_roulette
    
resolve_done:
    pop si
    pop cx
    pop bx
    ret
resolve_ai_claim endp

; === RUSSIAN ROULETTE ===
trigger_roulette proc
    push ax
    push dx
    
    inc roulette_counter
    
    ; Show attempt number
    mov ah, 09h
    lea dx, msg_roulette
    int 21h
    mov dl, roulette_counter
    add dl, '0'
    mov ah, 02h
    int 21h
    
    ; 6th attempt always kills
    cmp roulette_counter, 6
    je death
    
    ; 1 in 6 chance
    call random_number
    and ax, 7
    cmp ax, 1
    jle death
    
    ; Survived
    mov ah, 09h
    lea dx, msg_click
    int 21h
    jmp roulette_done
    
death:
    mov ah, 09h
    lea dx, msg_bang
    int 21h
    ; Game over
    mov ah, 4Ch
    int 21h
    
roulette_done:
    ; Pause so player can read
    mov ah, 09h
    lea dx, msg_prompt
    int 21h
    mov ah, 01h
    int 21h
    
    pop dx
    pop ax
    ret
trigger_roulette endp

; === UTILITY FUNCTIONS ===
random_number proc
    ; Simple pseudo-random number
    mov ah, 00h
    int 1Ah
    mov ax, dx
    ret
random_number endp

clear_screen proc
    push ax
    push bx
    push cx
    push dx
    mov ax, 0600h
    mov bh, 07h
    xor cx, cx
    mov dx, 184Fh
    int 10h
    mov ah, 02h
    xor bh, bh
    xor dx, dx
    int 10h
    pop dx
    pop cx
    pop bx
    pop ax
    ret
clear_screen endp

; === DISPLAY FUNCTIONS ===
display_hands proc
    push ax
    push bx
    push cx
    push dx
    push si
    
    ; Show player hand
    mov ah, 09h
    lea dx, msg_player
    int 21h
    
    mov cx, 5
    mov si, 0
    mov bx, offset card_symbols
show_player:
    cmp [player_hand + si], 255
    je show_empty
    
    mov al, [player_hand + si]
    xlat
    mov [card_template + 1], al
    lea dx, card_template
    jmp display_card
    
show_empty:
    lea dx, msg_empty
    
display_card:
    mov ah, 09h
    int 21h
    inc si
    loop show_player
    
    ; Show AI hand (face down)
    mov ah, 09h
    lea dx, msg_ai
    int 21h
    
    mov cx, 5
    mov si, 0
show_ai:
    cmp [ai_hand + si], 255
    je show_ai_empty
    mov dx, offset card_template
    jmp display_ai_card
    
show_ai_empty:
    mov dx, offset msg_empty
    
display_ai_card:
    mov [card_template + 1], '?'
    mov ah, 09h
    int 21h
    inc si
    loop show_ai
    
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
display_hands endp

; === CHALLENGE PROMPTS ===
ai_challenge proc
    push bx
    call random_number
    and ax, 3
    cmp ax, 0       ; 25% chance to challenge
    jne ai_no_challenge
    
    mov ah, 09h
    lea dx, msg_liar
    int 21h
    mov al, 1       ; Return 1 = challenge
    jmp ai_challenge_end
    
ai_no_challenge:
    xor al, al      ; Return 0 = no challenge
    
ai_challenge_end:   ; Changed from challenge_done
    pop bx
    ret
ai_challenge endp

prompt_challenge proc
    push dx
    
challenge_input:
    mov ah, 09h
    lea dx, msg_challenge_prompt
    int 21h
    
    mov ah, 01h
    int 21h
    and al, 0DFh    ; Convert to uppercase
    
    cmp al, 'Y'
    je player_challenge_yes
    cmp al, 'N'
    je player_challenge_no
    
    ; Invalid input - ask again
    jmp challenge_input
    
player_challenge_yes:
    mov al, 1       ; Return 1 = challenge
    jmp prompt_challenge_end
    
player_challenge_no:
    xor al, al      ; Return 0 = no challenge
    
prompt_challenge_end:  ; Changed from challenge_done
    pop dx
    ret
prompt_challenge endp

; === HAND MANAGEMENT ===
check_hands_empty proc
    ; Returns AX=1 if either hand is empty
    push cx
    push si
    
    ; Check player hand
    mov cx, 5
    mov si, 0
check_player:
    cmp [player_hand + si], 255
    jne check_ai
    inc si
    loop check_player
    mov ax, 1
    jmp hands_done
    
check_ai:
    ; Check AI hand
    mov cx, 5
    mov si, 0
check_ai_hand:
    cmp [ai_hand + si], 255
    jne hands_not_empty
    inc si
    loop check_ai_hand
    mov ax, 1
    jmp hands_done
    
hands_not_empty:
    mov ax, 0
    
hands_done:
    pop si
    pop cx
    ret
check_hands_empty endp

end main