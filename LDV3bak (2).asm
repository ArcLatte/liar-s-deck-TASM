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
    ai_played_cards db 5 dup(255)
    input_buffer  db 10 dup(?)
    empty_slot    db 255
    roulette_counter db 0
    ai_claim_count db ?
    
    ; Russian Roulette 
    player_roulette_counter db 0
    ai_roulette_counter     db 0
    player_bullet_position  db ?
    ai_bullet_position      db ?
    roulette_chamber_size   equ 6

    ; Strings
    kings_str     db ' Kings $'
    queens_str    db ' Queens$'
    aces_str      db ' Aces  $'
    card_symbols  db 'KQAJ'    ; 0=K, 1=Q, 2=A, 3=J
    card_template db '[ ] $'
    msg_empty     db '[X] $'

    ; Messages
    msg_welcome         db 'LIAR',39,'S BAR',13,10,'$'
    msg_table           db 13,10,'Table Type: $'
    msg_player          db 13,10,'Your hand  : $'
    msg_ai              db 13,10,'Giorno hand: $'
    msg_choose          db 13,10,'Select cards (1-5, comma separated): $'
    msg_invalid         db 13,10,'Invalid input! Use format like "1,3,5"$'
    msg_play            db 13,10,'You play: $'
    msg_claim           db 13,10,'You Claim: $'
    msg_ai_claim        db 'Giorno claims: $'
    msg_ai_plays        db 13,10,'Giorno plays: $'
    msg_truth_reveal    db 13,10,'Revealed cards: $'
    msg_revealing_cards db 13,10,'Revealing cards$'
    msg_prompt          db 13,10,13,10,'Press any key to continue...$'
    msg_ai_playing      db 13,10,13,10,'Giorno is playing cards...$'
   
    msg_player_lied         db 'Player attempted to deceive. Russian roulette begins...', 13, 10, '$'
    msg_ai_lied             db 13,10,'Giorno lied. Spinning the chamber...', 13, 10, '$'
    msg_player_wrong_accuse db 13,10,'Player falsely accused. Time to pay...', 13, 10, '$'
    msg_ai_wrong_accuse     db 'AI misjudged the player. Facing the risk...', 13, 10, '$'
    
    msg_challenge_prompt db 13,10,'Call liar? (Y/N): $'
    msg_player_liar db 13,10,'You: LIAR!$'
    msg_ai_liar       db 13,10,13,10,'Giorno: LIAR!$'
    msg_auto_challenge db 13,10,'HAND EMPTY! Automatic challenge!',13,10,'$'
    msg_ai_forced_challenge db 'Giorno is forced to call LIAR!',13,10,'$'
    msg_player_forced_challenge db 'You must call LIAR!',13,10,'$'
    msg_roulette   db 13,10,'RUSSIAN ROULETTE! Trigger #$'
    msg_pull_trigger db 13,10,'Pulling the trigger$'
    msg_bang       db 13,10,' BANG! Game over.$'
    msg_click      db 13,10,' *CLICK*$'
    ai_hidden_card db '[?] $'
    msg_player_wins db ' You win! AI lost the Russian Roulette.$'
    
    msg_player_roulette_count db 13, 10, 'Player (', '$'
    msg_ai_roulette_count     db 'Giorno (', '$'
    msg_of_six_closing        db '/6)', 13, 10, '$'
    
    reveal_buffer db 80 dup('$')        ; Display buffer

    
    ;Flag
    new_round_flag db 0
    challenge_flag db 0

    
    ;Debug only
    msg_debug_played_cards db "Saved AI Played Cards: $"
    msg_start db 'Game starting...', 13, 10, '$'
    msg_init_done db 'Roulette initialized!', 13, 10, '$'






.code
main proc
    mov ax, @data
    mov ds, ax
    
    
    call init_roulette
    
game_round:
    call clear_screen
    call select_table_type
    call show_table_type
    call enhanced_shuffle
    call deal_cards
    
round_turns:
    mov ax, @data
    mov ds, ax
    call clear_screen
    ; debuging......
    mov ah, 09h
    lea dx, msg_welcome
    int 21h
    call show_roulette_status
        
    
    ; debuging ends...
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
    
    cmp new_round_flag, 1
    je skip_prompt
    
    ; Continue round
    mov ah, 09h
    lea dx, msg_prompt
    int 21h
    mov ah, 01h
    int 21h
    
    jmp round_turns
    
skip_prompt:
    mov new_round_flag, 0
    jmp game_round
    
    mov ah, 4Ch
    int 21h
main endp

;====== Game Setup Procedures ======
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

;------ Print Table Type(King, Queen, Ace)------
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

;------ Deck Shuffling Procedure ------
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

;------ Card Dealing Procedure ------
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
;====== Game Setup Procedures END ======


; === UPDATED PLAYER TURN ===
player_multi_turn proc
    push ax
    push bx
    push cx
    push dx
    push si
    push di

input_loop:
    mov cx, 5
    mov si, 0
clear_selection:
    mov [selected_cards + si], 0
    inc si
    loop clear_selection

    ;prompt player choice
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
    lea dx, msg_claim      ; "Player claims: "
    int 21h

    mov dl, cl             ; cl = number of cards
    add dl, '0'
    mov ah, 02h
    int 21h


    ; Show type based on table_type
    mov al, table_type
    cmp al, 0
    je claim_kings
    cmp al, 1
    je claim_queens

    ; Default ? Aces
    lea dx, aces_str
    jmp show_claim_type

claim_kings:
    lea dx, kings_str
    jmp show_claim_type

claim_queens:
    lea dx, queens_str

show_claim_type:
    mov ah, 09h
    int 21h

    ; Check if player's hand is empty
    ; Check if player's hand will be empty AFTER removing selected cards
    mov cx, 5
    mov si, 0
    mov dx, 0              ; DX will count remaining cards
check_would_be_empty:
    mov al, [player_hand + si]
    cmp al, 255
    je next_check
    cmp [selected_cards + si], 1
    je next_check          ; Will be removed, skip counting

    inc dx                 ; Still a valid unplayed card

next_check:
    inc si
    loop check_would_be_empty

    cmp dx, 0
    jne hand_not_empty     ; If any unplayed card left, continue normal path

    ; Player hand will be empty - force AI challenge
    mov ah, 09h
    lea dx, msg_auto_challenge
    int 21h
    lea dx, msg_ai_forced_challenge
    int 21h
    call reveal_played_cards
    call verify_player_claim
    cmp new_round_flag, 1
    je jump_to_game_round
    call remove_selected_cards
    jmp turn_complete
    
hand_not_empty:
    call ai_challenge
    cmp al, 1
    jne no_challenge

    ; AI challenged
    call reveal_played_cards 
    call verify_player_claim
    cmp new_round_flag, 1
    je jump_to_game_round
    call remove_selected_cards
    jmp turn_complete

no_challenge:
    call remove_selected_cards
    jmp turn_complete
jump_to_game_round:
    mov new_round_flag, 0
    jmp game_round
turn_complete:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
player_multi_turn endp

;========Remove Cards=======
remove_selected_cards proc
    push si
    mov si, 0
remove_loop:
    cmp si, 5
    jae done
    cmp [selected_cards + si], 1
    jne skip
    mov [player_hand + si], 255
skip:
    inc si
    jmp remove_loop
done:
    pop si
    ret
remove_selected_cards endp

; === UPDATED AI TURN ===
ai_turn proc
    push ax
    push bx
    push cx
    push dx
    push si
    push di

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
    xor bx, bx
count_ai_cards:
    cmp [ai_hand + si], 255
    je skip_ai_count
    inc bx
skip_ai_count:
    inc si
    loop count_ai_cards

    ; Limit claim to actual hand size
    cmp ax, bx
    jbe keep_ax
    mov ax, bx
keep_ax:
    mov ai_claim_count, al

    ; Show hidden cards
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

    ; New line
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

    ; === Check if AI will be empty after playing
    mov cx, 5
    mov si, 0
    xor bl, bl
check_empty_ahead:
    cmp [ai_hand + si], 255
    je skip_check
    inc bl
skip_check:
    inc si
    loop check_empty_ahead

    sub bl, ai_claim_count
    cmp bl, 0
    jne skip_force_challenge

    ; === Force challenge if AI will be empty
    call save_ai_played_cards
    mov ah, 09h
    lea dx, msg_player_forced_challenge
    int 21h
    call reveal_ai_cards
    call resolve_ai_claim
    jmp ai_turn_complete

skip_force_challenge:
    ; === Ask player to challenge
    call save_ai_played_cards
    call prompt_challenge
    cmp challenge_flag, 0
    je no_challenge_path

    ; Player challenges
    call reveal_ai_cards
    call resolve_ai_claim
    jmp ai_turn_complete

no_challenge_path:
    ; Player does NOT challenge ? just remove cards
    ; Save played cards for consistency (optional)
    call save_ai_played_cards

    ; Remove claimed cards from ai_hand
    mov cl, ai_claim_count
    xor di, di
    mov si, 0
remove_ai_cards:
    cmp cl, 0
    je ai_turn_complete
    cmp [ai_hand + si], 255
    je skip_remove
    mov [ai_hand + si], 255
    dec cl
skip_remove:
    inc si
    cmp si, 5
    jb remove_ai_cards

ai_turn_complete:
    pop di
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
    push cx
    push dx
    push si

    mov ah, 09h
    lea dx, msg_revealing_cards
    int 21h
    call short_delay
    mov ah, 09h
    lea dx, msg_truth_reveal
    int 21h

    mov bx, offset card_symbols
    xor si, si

reveal_loop:
    cmp [selected_cards + si], 1
    jne skip_card

    mov al, [player_hand + si]
    xlat                          ; Convert card value (0?3) to symbol
    mov [card_template + 1], al   ; Place symbol inside [ ]
    
    lea dx, card_template
    mov ah, 09h
    int 21h

skip_card:
    inc si
    cmp si, 5
    jb reveal_loop

    pop si
    pop dx
    pop cx
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
    lea dx, msg_revealing_cards
    int 21h
    call short_delay
    mov ah, 09h
    lea dx, msg_truth_reveal
    int 21h

    mov bx, offset card_symbols
    xor si, si

reveal_ai_loop:
    cmp [ai_played_cards + si], 255
    je skip_ai_card

    mov al, [ai_played_cards + si]
    xlat                          ; Convert card value to 'K', 'Q', 'A', or 'J'
    mov [card_template + 1], al

    lea dx, card_template
    mov ah, 09h
    int 21h

skip_ai_card:
    inc si
    cmp si, 5
    jb reveal_ai_loop

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
reveal_ai_cards endp


delay_short proc
    push cx
    mov cx, 5000
delay_loop:
    nop
    loop delay_loop
    pop cx
    ret
delay_short endp


; === CARD VERIFICATION ===
verify_player_claim proc
    push ax
    push bx
    push cx
    push dx
    push si
    
    mov new_round_flag, 0 ;reset new round flag

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
    cmp al, 3
    je skip_verify
    cmp al, table_type
    jne player_lied
skip_verify:
    
    inc si
    loop verify_loop

    ; All cards matched
    mov ah, 09h
    lea dx, msg_ai_wrong_accuse
    int 21h
    call ai_roulette  ; AI was wrong
    mov new_round_flag, 1
    jmp verify_done

player_lied:
    mov ah, 09h
    lea dx, msg_player_lied
    int 21h
    call player_roulette  ; Player was lying
    mov new_round_flag, 1
    
verify_done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
verify_player_claim endp

resolve_ai_claim proc
    push ax
    push bx
    push cx
    push dx
    push si

    mov new_round_flag, 0

    ; === Setup ===
    mov cl, ai_claim_count  ; Only check how many cards AI claimed
    mov si, 0               ; Index into ai_played_cards
    xor bx, bx              ; Mismatch counter

check_played_cards:
    cmp cl, 0
    je check_results        ; Done checking claimed cards

    cmp [ai_played_cards + si], 255
    je skip_check_card      ; Skip empty slots

    ; Compare played card to table type
    mov al, [ai_played_cards + si]
    cmp al, 3
    je card_matches
    cmp al, table_type
    je card_matches

    ; Card doesn't match - increment mismatch counter
    inc bx
    jmp skip_check_card

card_matches:
    ; Card matches - do nothing special
    nop

skip_check_card:
    inc si
    dec cl
    jmp check_played_cards

check_results:
    ; If any mismatches found (bx > 0), AI lied
    cmp bx, 0
    jne ai_lied

ai_truthful:
    ; All claimed cards matched
    call short_delay
    mov ah, 09h
    lea dx, msg_player_wrong_accuse
    int 21h
    call player_roulette
    mov new_round_flag, 1
    jmp resolve_done

ai_lied:
    ; At least one claimed card didn't match
    call short_delay
    mov ah, 09h
    lea dx, msg_ai_lied
    int 21h
    call ai_roulette
    mov new_round_flag, 1

resolve_done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
resolve_ai_claim endp


save_ai_played_cards proc
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; Clear previous played cards
    mov si, 0
clear_loop:
    mov [ai_played_cards + si], 255
    inc si
    cmp si, 5
    jb clear_loop

    ; Copy claimed cards from ai_hand to ai_played_cards (without removal)
    mov cx, 5
    mov si, 0
    xor di, di
    mov bl, ai_claim_count
copy_loop:
    cmp di, bx         ; use bx instead of ax
    je after_copy_loop
    cmp [ai_hand + si], 255
    je skip_copy
    mov al, [ai_hand + si]
    mov [ai_played_cards + di], al
    inc di
skip_copy:
    inc si
    cmp si, 5
    jb copy_loop

after_copy_loop:
    ; === DEBUG: Print saved played cards ===
    mov ah, 09h
    lea dx, msg_debug_played_cards  ; db "Saved AI Played Cards: $" in .data
    int 21h

    mov si, 0
debug_loop:
    cmp si, 5
    je debug_done
    mov al, [ai_played_cards + si]
    cmp al, 255
    je skip_debug

    ; Convert to ASCII and print
    add al, '0'
    mov dl, al
    mov ah, 02h
    int 21h

    ; Add space
    mov dl, ' '
    int 21h

skip_debug:
    inc si
    jmp debug_loop

debug_done:
    ; Newline
    mov ah, 02h
    mov dl, 13
    int 21h
    mov dl, 10
    int 21h

done_copy:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
save_ai_played_cards endp



; ======= RUSSIAN ROULETTE Procedures =======

; ----- Initialize Russian Roulette -----
init_roulette proc
    push ax
    push bx
    push dx
    
    ; Player bullet
    call random_number       ; returns a new AX value (from system time)
    and ax, 5
    inc al
    mov player_bullet_position, al

    ; AI bullet
    call random_number       ; called again ? returns a different AX (next tick)
    and ax, 5
    inc al
    mov ai_bullet_position, al

    
    ; Reset counters
    mov player_roulette_counter, 0
    mov ai_roulette_counter, 0
    
    pop dx
    pop bx
    pop ax
    ret
init_roulette endp

; === Player Russian Roulette ===
player_roulette proc
    push ax
    push dx
    
    inc player_roulette_counter
    
    
    ; Show attempt number
    call short_delay
    mov ah, 09h
    lea dx, msg_roulette
    int 21h
    mov dl, player_roulette_counter
    add dl, '0'
    mov ah, 02h
    int 21h
    call short_delay
    mov ah, 09h
    lea dx, msg_pull_trigger
    int 21h
    call animate_dots
    
    ; Check if this is the bullet position
    mov al, player_roulette_counter
    cmp al, player_bullet_position
    je player_death
    
    ; Survived
    mov ah, 09h
    lea dx, msg_click
    int 21h
    jmp player_roulette_done
    
player_death:
    mov ah, 09h
    lea dx, msg_bang
    int 21h
    ; Game over
    mov ah, 4Ch
    int 21h
    
player_roulette_done:
    ; Pause so player can read
    mov ah, 09h
    lea dx, msg_prompt
    int 21h
    mov ah, 01h
    int 21h
    
    pop dx
    pop ax
    ret
player_roulette endp

; === AI Russian Roulette ===
ai_roulette proc
    push ax
    push dx
    
    inc ai_roulette_counter
    
    ; Show attempt number
    call short_delay
    mov ah, 09h
    lea dx, msg_roulette
    int 21h
    mov dl, ai_roulette_counter
    add dl, '0'
    mov ah, 02h
    int 21h
    mov ah, 09h
    lea dx, msg_pull_trigger
    int 21h
    call animate_dots
    
    ; Check if this is the bullet position
    mov al, ai_roulette_counter
    cmp al, ai_bullet_position
    je ai_death
    
    ; Survived
    mov ah, 09h
    lea dx, msg_click
    int 21h
    jmp ai_roulette_done
    
ai_death:
    mov ah, 09h
    lea dx, msg_bang
    int 21h
    ; Game over - AI loses
    mov ah, 09h
    lea dx, msg_player_wins
    int 21h
    mov ah, 4Ch
    int 21h
    
ai_roulette_done:
    ; Pause so player can read
    mov ah, 09h
    lea dx, msg_prompt
    int 21h
    mov ah, 01h
    int 21h
    
    pop dx
    pop ax
    ret
ai_roulette endp


;Display the count of Russian Roulette
show_roulette_status proc
    push ax
    push dx

    ; Ensure DS is correct
    mov ax, @data
    mov ds, ax

    ; Print player roulette count
    mov ah, 09h
    lea dx, msg_player_roulette_count
    int 21h
    mov al, player_roulette_counter
    add al, '0'
    mov dl, al
    mov ah, 02h
    int 21h
    lea dx, msg_of_six_closing
    mov ah, 09h
    int 21h

    ; Print AI roulette count
    mov ah, 09h
    lea dx, msg_ai_roulette_count
    int 21h
    mov al, ai_roulette_counter
    add al, '0'
    mov dl, al
    mov ah, 02h
    int 21h
    lea dx, msg_of_six_closing
    mov ah, 09h
    int 21h

    pop dx
    pop ax
    ret
show_roulette_status endp

; ==========================================


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

animate_dots proc
    push ax
    push cx

    mov cx, 3
print_dot:
    mov ah, 0Eh         ; BIOS teletype ? prints immediately
    mov al, '.'
    int 10h
    call short_delay
    loop print_dot

    pop cx
    pop ax
    ret
animate_dots endp

short_delay proc
    push cx
    push dx

    mov cx, 12         ; Outer loop
outer:
    mov dx, 0FFFFh     ; Inner loop: max 16-bit value
inner:
    nop
    dec dx
    jnz inner
    loop outer

    pop dx
    pop cx
    ret
short_delay endp

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
    lea dx, msg_ai_liar
    int 21h
    mov al, 1       ; Return 1 = challenge
    jmp ai_challenge_end
    
ai_no_challenge:
    xor al, al      ; Return 0 = no challenge
    
ai_challenge_end:   ; Changed from challenge_done
    pop bx
    ret
ai_challenge endp

;Promt Player to challenge
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
    mov challenge_flag, 1      ; Return 1 = challenge
    mov ah, 09h
    lea dx, msg_player_liar
    int 21h
    jmp prompt_challenge_end
    
player_challenge_no:
    mov challenge_flag, 0     ; Return 0 = no challenge
    
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