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

	pop rdi
	pop rax
	pop rcx
	pop r11
	pop r12
	pop r13
	pop r14

	ret

Put_Symbols_Region endp
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
			add rbx, 07h
		_skip_add_offset_to_char:

		mov [rcx], rbx

		; shift next line charpointer
		add rcx, rax

		; counter
		dec r10
		jnz _draw_color_rectangle

	; устанавливает цвет чёрнобелый и символ 'F'
	mov rbx, 0f00046h

	_draw_indexs_line_char:
		mov [rcx], rbx
		add rcx, 4
		dec rbx
		cmp rbx, 0f00041h
		jge _draw_indexs_line_char

	sub rbx, 07h
	_draw_indexs_line_numbers:
		mov [rcx], rbx
		add rcx, 4
		dec rbx
		cmp rbx, 0f00030h
		jge _draw_indexs_line_numbers

	pop rax
	pop rbx
	pop rcx 
	pop r10
	pop r11

	ret 

Draw_Color_Rectangle endp
;---------------------------------------------------------------------


end

