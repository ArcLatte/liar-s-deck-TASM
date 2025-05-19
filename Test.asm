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
        
       msg_dot  db '.', '$'
       msg_pull_trigger db 'Pulling the trigger$'
       
       note_table_win dw 1911, 1703, 1517, 1432, 1275, 1136, 1012, 0
dur_table_win  dw 200, 200, 200, 200, 200, 200, 300, 0
; Notes = C4 D4 E4 F4 G4 A4 B4

note_table_lose dw 1012, 1136, 1275, 1517, 0
dur_table_lose  dw 300, 300, 300, 400, 0

; Notes = B3 A3 G3 E3 (descending)

msg_line1 db 13,10, 'Welcome to the Liar''s Bar...', '$'
msg_line2 db 13,10, 'You and Giorno will bluff to survive.', '$'
msg_line3 db 13,10, 'Let the game begin.', '$'



.code 
main proc
    mov ax, @data
    mov ds, ax
    
    call init_roulette
    ;call clear_screen
    call show_roulette_status
    
    lea dx, msg_line1
call print_line_with_delay

lea dx, msg_line2
call print_line_with_delay

lea dx, msg_line3
call print_line_with_delay

    
    mov ah, 09h
    lea dx, msg_pull_trigger
    int 21h
    call animate_dots
    call play_win_sound
    mov ah, 4Ch
    int 21h
    
main endp

print_line_with_delay proc
    push ax
    push dx

    mov ah, 09h
    int 21h          ; assumes DX already points to string

    call delay_slow  ; or use a shorter version like `delay_short`

    pop dx
    pop ax
    ret
print_line_with_delay endp


random_number proc
    ; Simple pseudo-random number
    mov ah, 00h
    int 1Ah
    mov ax, dx
    ret
random_number endp

play_melody proc
    ; Input: DS:SI = note table, DS:DI = duration table
    push ax
    push bx
    push cx
    push dx

next_note:
    mov ax, [si]
    cmp ax, 0
    je end_melody

    ; Setup PIT
    mov al, 0B6h
    out 43h, al
    out 42h, ax       ; Low byte
    mov al, ah
    out 42h, al       ; High byte

    ; Enable speaker
    in al, 61h
    or al, 3
    out 61h, al

    ; Play for [di] delay
    mov cx, [di]
delay_loop:
    nop
    loop delay_loop

    ; Turn off speaker
    in al, 61h
    and al, 0FCh
    out 61h, al

    ; Advance to next note
    add si, 2
    add di, 2
    jmp next_note

end_melody:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

play_melody endp

play_win_sound proc
    mov si, offset note_table_win
    mov di, offset dur_table_win
    call play_melody
    ret
play_win_sound endp

play_lose_sound proc
    mov si, offset note_table_lose
    mov di, offset dur_table_lose
    call play_melody
    ret
play_lose_sound endp


play_pop_sound proc
    push ax
    push dx
    push cx

    ; High-pitched "tick"
    mov al, 0B6h
    out 43h, al
    mov ax, 795          ; ~1500 Hz
    out 42h, al
    mov al, ah
    out 42h, al

    in al, 61h
    or al, 3
    out 61h, al

    mov cx, 8000         ; Long enough to be heard (~0.2 sec)
pop_delay:
    nop
    loop pop_delay

    in al, 61h
    and al, 0FCh
    out 61h, al

    pop cx
    pop dx
    pop ax
    ret
play_pop_sound endp


sharp_bang_sound proc
    push ax
    push dx
    push cx

    ; === Strong Low BANG ===
    mov al, 0B6h
    out 43h, al
    mov ax, 10847         ; ~110Hz
    out 42h, al
    mov al, ah
    out 42h, al

    in al, 61h
    or al, 3
    out 61h, al

    mov cx, 40000         ; ?? Longer burst (~0.5 sec)
gbang_delay:
    nop
    loop gbang_delay

    ; === Turn off ===
    in al, 61h
    and al, 0FCh
    out 61h, al

    ; === Follow-up metallic ring (higher pitch) ===
    mov al, 0B6h
    out 43h, al
    mov ax, 1193          ; ~1000Hz
    out 42h, al
    mov al, ah
    out 42h, al
    in al, 61h
    or al, 3
    out 61h, al

    mov cx, 20000         ; ?? Audible echo
gring_delay:
    nop
    loop gring_delay

    in al, 61h
    and al, 0FCh
    out 61h, al

    pop cx
    pop dx
    pop ax
    ret
sharp_bang_sound endp


brutal_shot_sound proc
    push ax
    push dx
    push cx

    ; === Initial BANG (low pitch burst) ===
    mov al, 0B6h
    out 43h, al
    mov ax, 10847         ; ~110Hz
    out 42h, al
    mov al, ah
    out 42h, al

    in al, 61h
    or al, 3
    out 61h, al

    mov cx, 30000         ; Strong burst
bang_delay:
    nop
    loop bang_delay

    ; === Pause gap ===
    in al, 61h
    and al, 0FCh
    out 61h, al
    mov cx, 4000
gap_delay:
    nop
    loop gap_delay

    ; === Metallic ring (high-pitched echo) ===
    mov al, 0B6h
    out 43h, al
    mov ax, 1193          ; ~1000Hz
    out 42h, al
    mov al, ah
    out 42h, al
    in al, 61h
    or al, 3
    out 61h, al

    mov cx, 8000          ; Short ringing
ring_delay:
    nop
    loop ring_delay

    ; === Final silence ===
    in al, 61h
    and al, 0FCh
    out 61h, al

    pop cx
    pop dx
    pop ax
    ret
brutal_shot_sound endp


glitchy_death_sound proc
    push ax
    push bx
    push cx
    push dx

    mov ax, 700          ; Start freq ~1700Hz
    mov cx, 32           ; ~32 broken steps

glitch_loop:
    ; === Set pitch ===
    mov al, 0B6h
    out 43h, al
    mov bx, ax
    out 42h, al
    mov al, ah
    out 42h, al

    ; === Flicker ON ===
    in al, 61h
    or al, 3
    out 61h, al

    ; === Quick jitter burst ===
    mov dx, 800 + 50     ; Random-looking delay
glitch_delay_on:
    nop
    dec dx
    jnz glitch_delay_on

    ; === Flicker OFF ===
    in al, 61h
    and al, 0FCh
    out 61h, al

    ; === Uneven pause ===
    mov dx, 200 + 20
glitch_pause:
    nop
    dec dx
    jnz glitch_pause

    ; === Random drop in pitch ===
    add ax, 13           ; Uneven step = makes it sound broken

    loop glitch_loop

    ; === Final deep hum ===
    mov al, 0B6h
    out 43h, al
    mov ax, 11000        ; Very low pitch
    out 42h, al
    mov al, ah
    out 42h, al

    in al, 61h
    or al, 3
    out 61h, al

    mov dx, 12000
final_death_rumble:
    nop
    dec dx
    jnz final_death_rumble

    ; === Final silence ===
    in al, 61h
    and al, 0FCh
    out 61h, al

    pop dx
    pop cx
    pop bx
    pop ax
    ret
glitchy_death_sound endp


creepy_death_sound proc
    push ax
    push bx
    push cx
    push dx

    mov ax, 800          ; Start high (1500Hz)
    mov cx, 25           ; Number of glitch steps

creepy_loop:
    ; Set frequency
    mov al, 0B6h
    out 43h, al
    mov bx, ax
    out 42h, al
    mov al, ah
    out 42h, al

    ; Turn on speaker
    in al, 61h
    or al, 3
    out 61h, al

    ; Short broken burst
    mov dx, 1000
creepy_delay:
    nop
    dec dx
    jnz creepy_delay

    ; Glitch flicker: turn off momentarily
    in al, 61h
    and al, 0FCh
    out 61h, al

    ; Pause to make it feel irregular
    mov dx, 500
pause_delay:
    nop
    dec dx
    jnz pause_delay

    ; Drop pitch unevenly
    add ax, 25            ; non-linear fall (glitchy)

    loop creepy_loop

    ; Final rumble (low pitch hum)
    mov al, 0B6h
    out 43h, al
    mov ax, 10847         ; ~110Hz
    out 42h, al
    mov al, ah
    out 42h, al

    in al, 61h
    or al, 3
    out 61h, al

    mov dx, 10000
low_rumble:
    nop
    dec dx
    jnz low_rumble

    in al, 61h
    and al, 0FCh
    out 61h, al

    pop dx
    pop cx
    pop bx
    pop ax
    ret
creepy_death_sound endp


error_buzz proc
    push ax
    push dx

    mov al, 0B6h
    out 43h, al
    mov ax, 1193         ; ~1000Hz
    out 42h, al
    mov al, ah
    out 42h, al

    in al, 61h
    or al, 3
    out 61h, al

    mov dx, 25000
buzz_delay:
    nop
    dec dx
    jnz buzz_delay

    in al, 61h
    and al, 0FCh
    out 61h, al

    pop dx
    pop ax
    ret
error_buzz endp



note_delay proc
    push cx
    mov cx, 8000       ; ~200?300ms per note
note_loop:
    nop
    loop note_loop
    pop cx
    ret
note_delay endp


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

animate_dots proc
    push ax
    push cx

    mov cx, 3
print_dot:
    mov ah, 0Eh         ; BIOS teletype ? prints immediately
    mov al, '.'
    int 10h
    call delay_slow
    loop print_dot

    pop cx
    pop ax
    ret
animate_dots endp


delay_slow proc
    push cx
    push dx

    mov cx, 16         ; Outer loop
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
delay_slow endp

play_bang_sound proc
    push ax
    push dx
    push cx

    ; Start high, go low
    mov cx, 3000          ; Number of steps
    mov ax, 800           ; Start at 1500Hz ? 1193180 / 800 ? 1491 Hz

bang_sweep_loop:
    ; Set PIT (Timer 2)
    mov al, 0B6h
    out 43h, al
    mov bx, ax            ; Save current frequency count
    out 42h, al           ; Low byte
    mov al, ah
    out 42h, al           ; High byte

    ; Enable speaker
    in al, 61h
    or al, 3
    out 61h, al

    ; Short tone
    mov dx, 300
bang_tone_delay:
    nop
    dec dx
    jnz bang_tone_delay

    ; Reduce frequency
    add ax, 2             ; Lower pitch gradually

    ; Stop tone briefly (for smoother sweep)
    in al, 61h
    and al, 0FCh
    out 61h, al

    loop bang_sweep_loop

    ; Final off
    in al, 61h
    and al, 0FCh
    out 61h, al

    pop cx
    pop dx
    pop ax
    ret
play_bang_sound endp



play_click_sound proc
    push ax
    push dx

    ; High pitch: 1000Hz ? 1193 count
    mov al, 0B6h
    out 43h, al
    mov ax, 1193
    out 42h, al
    mov al, ah
    out 42h, al

    ; Turn on speaker
    in al, 61h
    or al, 3
    out 61h, al

    ; Short delay
    mov cx, 3000
click_delay:
    nop
    loop click_delay

    ; Turn off speaker
    in al, 61h
    and al, 0FCh
    out 61h, al

    pop dx
    pop ax
    ret
play_click_sound endp




end main