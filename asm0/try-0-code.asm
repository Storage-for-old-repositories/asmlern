.code

; If file not compiled try set encodeing "Windows 1251"

;---------------------------------------------------------------------
; Расчитываем смещение позиция для линейного буфера
_invstack_Calculate_Offset_Position proc
; r10 - position: PutSymbols_Position
;	PutSymbols_Position: < _u16:length | u16:width | u16:y | u16:x >
;; r11 - usize:offset
;;; inversion [r13]

	; r11 = width
	mov r11, r10
	shr r11, 32
	movzx r11, r11b

	; r11 = y * width
	mov r13, r10
	shl r13, 32
	shr r13, 48
	imul r11, r13

	; r11 = x + y * width
	movzx r13, r10b
	add r11, r13

	; r11 = (x + y * width) * 4
	shl r11, 2

	ret

_invstack_Calculate_Offset_Position endp
;---------------------------------------------------------------------

;#####################################################################
;#####################################################################
;#####################################################################
;#####################################################################

;---------------------------------------------------------------------
Put_Symbols_Horizontal proc
; void (CHAR_INFO * screenBuffer, PutSymbols_Position position, PutSymbols_Draw draw)
;
; rcx - screenBuffer
; rdx - position: PutSymbols_Position
;	PutSymbols_Position: < u16:length | u16:width | u16:y | u16:x >
; r8 - draw
;	PutSymbols_Draw: < _u16:height | u32:symbol >
;
; void

	push rdi
	push rax
	push rcx
	push r10
	push r11
	push r13

	; r11 = byteoffset in screenBuffer
	mov r10, rdx
	call _invstack_Calculate_Offset_Position

	; add offset to screenBuffer
	add rcx, r11

	; eax = writeble u32:symbol ;; for [stosd]
	mov eax, r8d

	; rdi = screenBuffer ;; for [stosd]
	mov rdi, rcx

	; rcx = length ;; for [rep]
	mov rcx, rdx
	shr rcx, 48

	; put symbols in screenBuffer
	rep stosd
	
	pop r13
	pop r11
	pop r10
	pop rcx
	pop rax
	pop rdi

	ret

Put_Symbols_Horizontal endp
;---------------------------------------------------------------------

;---------------------------------------------------------------------
Put_Symbols_Region proc
; void (CHAR_INFO * screenBuffer, CHAR_INFO symbol, PutSymbols_Position position)
;
; rcx - screenBuffer
; rdx - position: PutSymbols_Position
;	PutSymbols_Position: < u16:region_width | u16:width | u16:y | u16:x >
; r8 - draw
;	PutSymbols_Draw: < u16:height | u32:symbol >
;
; void

	push rdi
	push rax
	push rcx
	push r10
	push r11
	push r12
	push r13
	push r14

	; r11 = byteoffset in screenBuffer
	mov r10, rdx
	call _invstack_Calculate_Offset_Position

	; add offset to screenBuffer
	add rcx, r11

	; r12 = draw.with ; region.width
	mov r12, rdx
	shr r12, 48

	; r13 = (position.region_width - draw.width) * 4; byteoffset for goto next line
	mov r13, rdx
	shl r13, 16
	shr r13, 48
	sub r13, r12
	shl r13, 2

	; r14 = draw.height ; region.height
	mov r14, r8
	shl r14, 16
	shr r14, 48

	; eax = writeble u32:symbol ;; for [stosd]
	mov eax, r8d

	; rdi = screenBuffer ;; for [stosd]
	mov rdi, rcx

	_height_iterator:
		
		; rcx = length ;; for [rep]
		mov rcx, r12

		; put symbols in screenBuffer
		rep stosd

		; move pointer on screenBuffer to next line
		add rdi, r13

		dec r14
		jnz _height_iterator

	pop r14
	pop r13
	pop r12
	pop r11
	pop r10
	pop rcx
	pop rax
	pop rdi

	ret

Put_Symbols_Region endp
;---------------------------------------------------------------------

;---------------------------------------------------------------------
; void Draw_Color_9SliceRectangle(
;	CHAR_INFO * screenBuffer, 
;	PutSymbols_Position position, 
;	DrawRectangleParams params,
;	unsigned short symbols[7]
;)
Draw_Color_9SliceRectangle proc
; rcx - screenBuffer
; rdx - position: PutSymbols_Position
;	< u16:region_width | u16:width | u16:y | u16:x >
; r8 - rectParams: DrawRectangleParams
;	< u16:color, u16:height >
; r9 - symbols
;
;; void

	; r11 = byteoffset in screenBuffer
	mov r10, rdx
	call _invstack_Calculate_Offset_Position

	; put top-left char
	mov r10, r8
	and r10, 0ffff0000h  ; apply color mask
	mov rax, [r9]        ; read char
	and rax, 0ffffh      ; apply first char mask
	or rax, r10          ; color | char
	mov [rcx + r11], eax ; put char

	; save registers
	mov r12, rdx
	mov r13, r8

	; put top line
	;; 
	mov r10, r8
	and r10, 0ffff0000h   ; apply color mask
	mov r8, [r9 + 2 * 4]  ; read char
	and r8, 0ffffh        ; apply first char mask
	or r8, r10            ; u16:color | u16:char
	xor r10, r10
	add r10, 1
	shl r10, 32
	or r8, r10            ; u16:height | u16:color | u16:char
	add rdx, 1            ; position.x += 1
	xor r10, r10          
	add r10, 2
	shl r10, 48
	sub rdx, r10          ; position.region_width -= 2
	call Put_Symbols_Region

	; put bottom line
	mov r10, r13
	and r10, 0ffffh       ; height
	sub r10, 1
	shl r10, 16           
	add rdx, r10  
	call Put_Symbols_Region

	; put center block
	sub rdx, r10  
	add rdx, 10000h       ; position.y += 1
	mov r10, r13
	and r10, 0ffffh       ; height
	sub r10, 3
	shl r10, 32
	add r8, r10           ; rectParams.height += height - 2
	mov r10, [r9 + 12]    ; read char
	and r10, 0ffffh       ; apply first char mask
	shr r8, 16
	shl r8, 16
	or r8, r10
	call Put_Symbols_Region

	; put left line
	mov r10, [r9 + 10]    ; read char
	and r10, 0ffffh       ; apply first char mask
	shr r8, 16
	shl r8, 16
	or r8, r10            ; replace char
	shl rdx, 16
	shr rdx, 16
	xor r10, r10
	add r10, 1
	shl r10, 48
	or rdx, r10          ; position.region_width = 1
	sub rdx, 1           ; position.x -= 1
	call Put_Symbols_Region

	; put right line
	mov r10, r12
	shr r10, 48
	sub r10, 1
	add rdx, r10
	call Put_Symbols_Region

	; put top-right char
	shl r10, 2
	add r11, r10
	mov r10d, r13d
	and r10, 0ffff0000h  ; apply color mask
	mov rax, [r9 + 2]    ; read char
	and rax, 0ffffh      ; apply first char mask
	or rax, r10          ; color | char
	mov [rcx + r11], eax ; put char

	push r13
	push r12

	; r11 = byteoffset in screenBuffer
	mov r10, r12
	mov r11, r13
	and r11, 0ffffh      ; height
	sub r11, 1
	shl r11, 16
	add r10, r11
	call _invstack_Calculate_Offset_Position

	pop r12
	pop r13

	; put left-bottom char
	mov r10d, r13d
	and r10, 0ffff0000h  ; apply color mask
	mov rax, [r9 + 4]    ; read char
	and rax, 0ffffh      ; apply first char mask
	or rax, r10          ; color | char
	mov [rcx + r11], eax ; put char

	; put left-bottom char
	mov r10d, r13d
	and r10, 0ffff0000h  ; apply color mask
	mov rax, [r9 + 6]    ; read char
	and rax, 0ffffh      ; apply first char mask
	or rax, r10          ; color | char
	mov r10, r12
	shr r10, 48
	sub r10, 1
	shl r10, 2
	add r11, r10
	mov [rcx + r11], eax ; put char

	ret

Draw_Color_9SliceRectangle endp
;---------------------------------------------------------------------


;#####################################################################
;#####################################################################
;#####################################################################
;#####################################################################

;---------------------------------------------------------------------
; Рисуем цветовой прямоугольник
Draw_Color_Rectangle proc
	; void (CHAR_INFO * screenBuffer, DrawRectangleParams params)
	; DrawRectangleParams = { u16 };
	;; rcx - screenBuffer
	;; rdx - params

	push rax
	push rbx
	push rcx
	push r10
	push r11

	; rax = (width - 16) * 4
	movzx rax, dx
	sub rax, 16
	shl rax, 2
	
	; r10 = 16
	; r10 - счётчик высоты
	mov r10, 16

_draw_color_rectangle:
		; r11 = 16
		; r11 - счётчик ширины
		mov r11, 16

	_draw_color_line: 
			; rbx = { u4:c_background }
			mov rbx, r10
			sub rbx, 1 ; поправка счётчика

			; rbx = { u4:c_background, u4:c_symbol }
			shl rbx, 4
			add rbx, r11
			sub rbx, 1 ; поправка счётчика

			; rbx = { u4:c_background, u4:c_symbol, u16:symbol }
			shl rbx, 16
			add rbx, 88

			; put char and shift charpointer
			mov [rcx], rbx
			add rcx, 4

			; counter
			dec r11
			jnz _draw_color_line

		; устанавливает цвет чёрнобелый и символ '0'
		mov rbx, 0f0002Fh
		add rbx, r10

		cmp rbx, 0f0003Ah
		jl _skip_add_offset_to_char
			add rbx, 07h ; смещаемся от символа '9' к символу 'A'
		_skip_add_offset_to_char:

		mov [rcx], rbx

		; shift next line charpointer
		add rcx, rax

		; counter
		dec r10
		jnz _draw_color_rectangle

	; устанавливает цвет чёрнобелый и символ 'F'
	mov rbx, 0f00046h

	mov r10, 0f00041h ; устанавливаем предел рисования символ 'A'
	call _draw_indexs_line

	sub rbx, 07h ; смещаемся от символа 'A' к символу '9'
	mov r10, 0f00030h ; устанавливаем предел рисования символ '0'
	call _draw_indexs_line

	pop rax
	pop rbx
	pop rcx 
	pop r10
	pop r11

	ret 

Draw_Color_Rectangle endp

_draw_indexs_line proc
	
	_cycle:
		mov [rcx], rbx
		add rcx, 4
		dec rbx
		cmp rbx, r10
		jge _draw_indexs_line

	ret

_draw_indexs_line endp
;---------------------------------------------------------------------


end

