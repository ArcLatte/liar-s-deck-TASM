.model small
.stack 100h

.data
    msg_player_roulette_count db 13, 10, 'Player (', '$'
    msg_ai_roulette_count     db 13, 10, 'AI     (', '$'
    msg_of_six_closing        db '/6)', 13, 10, '$'
        ; Russian Roulette 
    player_roulette_counter db 0
    ai_roulette_counter     db 0
    player_bullet_position  db ?
    ai_bullet_position      db ?
    roulette_chamber_size   equ 6
    msg_roulette   db 13,10,'RUSSIAN ROULETTE! Trigger #$'
    msg_bang       db ' BANG! Game over.$'
    msg_click      db ' *CLICK*$'
    ai_hidden_card db '[?] $'
    msg_player_wins db ' You win! AI lost the Russian Roulette.$'
        msg_prompt    db 13,10,13,10,'Press any key to continue...$'

.code 
main proc
    call init_roulette
    ;call clear_screen
    call show_roulette_status
        mov ah, 4Ch
    int 21h
main endp

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
    mov ah, 09h
    lea dx, msg_roulette
    int 21h
    mov dl, player_roulette_counter
    add dl, '0'
    mov ah, 02h
    int 21h
    
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
    mov ah, 09h
    lea dx, msg_roulette
    int 21h
    mov dl, ai_roulette_counter
    add dl, '0'
    mov ah, 02h
    int 21h
    
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

show_roulette_status proc
    push ax
    push bx
    push cx
    push dx
    
    ; Ensure DS is correct
    mov ax, @data
    mov ds, ax

    ; Print player line
    mov ah, 09h
    lea dx, msg_player_roulette_count
    int 21h

    ; Print player counter
    mov al, player_roulette_counter
    add al, '0'
    mov dl, al
    mov ah, 02h
    int 21h

    ; Print suffix
    mov ah, 09h
    lea dx, msg_of_six_closing
    int 21h

    ; Print AI line
    mov ah, 09h
    lea dx, msg_ai_roulette_count
    int 21h

    mov al, ai_roulette_counter
    add al, '0'
    mov dl, al
    mov ah, 02h
    int 21h

    mov ah, 09h
    lea dx, msg_of_six_closing
    int 21h

    ; Add a newline for better spacing
    mov ah, 02h
    mov dl, 13
    int 21h
    mov dl, 10
    int 21h

    pop dx
    pop cx
    pop bx
    pop ax
    ret
show_roulette_status endp

end main