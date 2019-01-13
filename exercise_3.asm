.MODEL TINY 
IO8259_0 EQU 0250H;偶地址
IO8259_1 EQU 0251H;奇地址
COM_8255 EQU 0273H ;8255控制口地址
PA_8255  EQU 0270H  ;A端口地址
PB_8255  EQU 0271H
PC_8255  EQU 0272H
COM_ADDR EQU 0263H;计数器控制字地址
T0_ADDR EQU 0260H;计数器端口0
T1_ADDR EQU 0261H;计数器端口1
        .STACK 100
        .DATA
BUFFER  DB 8 DUP(?) 
SEG_TAB DB 0C0H,0F9H,0A4H,0B0H, 99H, 92H, 82H,0F8H
DB 080H, 90H, 88H, 83H,0C6H,0A1H, 86H,0c7h,08ch,0ffh;0-f,最后两位控制小数点可全灭
deng db 01111111B,00111111B,00011111B,00001111B,00000111b,00000011B,00110011B;“0”表示二极管亮
Counter DB 0
my_num DB 0
        .CODE
START:  MOV AX,@DATA
        MOV DS,AX
        MOV ES,AX
        NOP
        CLD ;0->DF, 地址自动递增
        MOV DX,COM_8255
	MOV AL,80H;方式选择控制字
	OUT DX,AL ;PA、PB 输出，PC 输出
	MOV Counter,0;中断次数
	CALL Init8259;8259A初始化
    CALL WriIntver;设置中断向量
    call WriIntver_2; 设置定时器中断向量
    CALL Init8253;8253初始化
    call LED_quanmie 
	STI ;开中断
	
A:	mov dx,5; 每位数有5个位置状态
        mov bx,0; BUFFE缓冲区里的值输出到数码管上,led函数完成2016数字在数码管上的循环移动
led:	LEA DI,buffer;获取buffer缓冲区的首地址
        MOV AL,11H   ;数码管只能显示16进制0-F,10H无法显示
        MOV CX,08H    
        REP STOSB;   al循环8次传给ES:DI
        mov buffer[bx],8
        mov buffer[bx+1],1
   	mov buffer[bx+2],0
  	mov buffer[bx+3],2
   	call dir;调用显示函数
   	inc bx;2018的5个位置依次往右移动一位
   	dec dx
   	jnz led;
   	LEA DI,buffer
   	MOV AL,11H
  	MOV CX,08H
  	REP STOSB
   	mov buffer[7],0
   	mov buffer[0],2
   	mov buffer[6],1
   	mov buffer[5],8
        call dir
   	LEA DI,buffer
   	MOV AL,11H
  	MOV CX,08H
  	REP STOSB
  	mov buffer[1],2
        mov buffer[0],0
 	mov buffer[7],1
        mov buffer[6],8
        call dir
        LEA DI,buffer
      	MOV AL,11H
   	MOV CX,08H
   	REP STOSB
   	mov buffer[2],2
   	mov buffer[1],0
   	mov buffer[0],1
   	mov buffer[7],8
   	call dir	

	jmp a;循环
	
Init8259 PROC NEAR;8259初始化子程序
	Push  dx
	Push  ax
        MOV DX,IO8259_0
        MOV AL,13H;        icw1
        OUT DX,AL
        MOV DX,IO8259_1
        MOV AL,08H;        icw2，中断类型号
        OUT DX,AL
        MOV AL,09H;        icw4
        OUT DX,AL
        MOV AL,0fcH;       ocw1,IR1，ir0 屏蔽操作控制
        OUT DX,AL
        mov al,21h ;       ocw2,ir1
        out dx,al
        mov al,20h ;       ocw2,ir0
        out dx,al
	Pop ax
	Pop dx
	RET
Init8259 ENDP

Init8253 PROC NEAR;8253初始化
    Push  dx
	Push  ax
	MOV DX,COM_ADDR
	MOV AL,35H
	OUT DX,AL ;计数器T0设置在模式2状态,BCD码计数
	MOV DX,T0_ADDR
	MOV AL,00H	
	OUT DX,AL
	MOV AL,10H
	OUT DX,AL ;CLK0/1000
	MOV DX,COM_ADDR
	MOV AL,77H
	OUT DX,AL ;计数器T12状态，输出方波,BCD码计数
	MOV DX,T1_ADDR
	MOV AL,00H
	OUT DX,AL
	MOV AL,10H
	OUT DX,AL ;CLK1/1000
    Pop ax
	Pop dx
	RET
Init8253 ENDP

LED_quanmie PROC NEAR ;LED全灭
	PUSH DX;该程序为定时器中断服务子程序
        PUSH AX
        push bx
        mov bl,counter
        mov dx,pc_8255;deng缓冲区保存二极管状态信息，为0时对应二极管发光，数据通过8255C口输出
	mov al,0ffh;二极管全灭
	out dx,al;数据输出，二极管发光
        pop bx
        POP AX
        POP DX   
        RET 
LED_quanmie ENDP


WriIntver PROC NEAR;该程序功能为设置中断向量
          PUSH ES;    es:di=cs:si
          push ax
          push ds
          MOV AX,0
          MOV ES,AX
       	  MOV DI,24H;中断向量地址
          LEA AX,INT_2
          STOSW;   AX-ES:DI
          MOV AX,CS
          STOSW 
          POP ES
          pop ax
          pop ds
          RET
WriIntver ENDP

WriIntver_2 PROC NEAR;该程序功能为设置定时器中断向量
          PUSH ES;    es:di=cs:si
	  push ax
	  push ds
          MOV AX,0
          MOV ES,AX
       	  MOV DI,20H;中断向量地址
          LEA AX,INT_3
          STOSW;   AX-ES:DI
          MOV AX,CS
          STOSW 
          POP ES
          pop ax
          pop ds
          RET
WriIntver_2 ENDP

LedDisplay PROC NEAR;该程序功能为中断显示
          push cx
          push si
          mov cx,8
          mov si,0
yazhan: ;因为程序运行过程中会改变buffer缓冲区的值，所以将值保存在堆栈里
 	and ax,0000h
 	mov al,buffer[si] 
 	push ax
 	inc si
	loop yazhan
	MOV AL,Counter
	mov cl,counter
	and cx,0000000000000111b;因为题目要求计数从1-7，当counter到8时，将其回复为0
	cmp cx,0
	jnz jixu
	mov counter,1  ;原来是add counter, 1 有错
	mov cx,1
jixu:   cmp cx,07h
 	jz teshu
	MOV buffer,cl
	MOV Buffer + 1,cl
	MOV Buffer + 2,cl 
	MOV Buffer + 3,cl
	MOV Buffer + 4,cl
	MOV Buffer + 5,cl
	MOV Buffer + 6,cl
	MOV Buffer + 7,cl
	call dir2
	jmp e
teshu: 	mov buffer,10h;当counter为7时，要求显示2016LOOP，是特殊情况
	MOV Buffer + 1,00h
	MOV Buffer + 2,00h; 高六位不需要显示
	MOV Buffer + 3,0fh
	MOV Buffer + 4,08h
	MOV Buffer + 5,01h
	MOV Buffer + 6,00h
	MOV Buffer + 7,02h
	call dir2
e:	mov cx,8
	mov si,7	
chuzhan:and ax,0000h;回复buffer字节缓冲区内容
  	pop ax
  	mov buffer[si],al
  	dec si
  	loop chuzhan
  	pop si
  	pop cx
  	RET
LedDisplay ENDP

INT_2: PUSH DX;该程序为外部中断服务子程序
       PUSH AX
       MOV AL,Counter
       ADD AL,1
       MOV Counter,AL
       test AL,0000000000000001b
	JNZ delay1s
	MOV DX,T1_ADDR
	MOV AL,00H
	OUT DX,AL
	MOV AL,20H
	OUT DX,AL ;偶数延迟2s	
	JMP NEXT_0
delay1s:
	MOV DX,T1_ADDR
	MOV AL,00H
	OUT DX,AL
	MOV AL,10H
	OUT DX,AL ;奇数延迟1s
NEXT_0:
	STI;提前开中断
	MOV DX,IO8259_1
       MOV AL,0fcH;       ocw1,打开IR0
       OUT DX,AL
       call leddisplay
       MOV DX,IO8259_1
       MOV AL,0fdH;       ocw1,关闭IR0
       OUT DX,AL
       call LED_quanmie
       MOV DX,IO8259_0
       MOV AL,21H
       OUT DX,AL
       POP AX
       POP DX                                                                                                                                                                                                                                                  
       IRET
       
INT_3: PUSH DX;该程序为定时器中断服务子程序
       PUSH AX
       push bx
       mov bl, my_num
       inc bl
       mov my_num, bl
       mov bx,0
       mov bl,Counter
       AND BL,07H;对7取模
       mov dx,pc_8255;deng缓冲区保存二极管状态信息，为0时对应二极管发光，数据通过8255C口输出
       mov al, my_num
       and al,01h ;  my_num只会在1/2间变化
       jz mie_0
       mov al,deng[bx-1] ;二极管对应发光，闪烁是通过使二极管不同亮灭实现
       jmp dshuchu_0
mie_0: 	mov al,0ffh;二极管全灭

dshuchu_0: out dx,al;数据输出，二极管发光
       
       MOV DX,IO8259_0
       MOV AL,20H
       OUT DX,AL
       ;MOV AL,21H
       ;OUT DX,AL
       pop bx
       POP AX
       POP DX                                                                                                                                                                                                                                                  
       IRET      
      
dir    PROC NEAR;主程序显示数据
	PUSH AX
	PUSH BX
	PUSH DX
	PUSH CX
	sti
	mov cx,30;CX的值控制“2018“的向右移动速度
keng:	LEA SI,buffer ;置显示缓冲器初值
	MOV AH,0FeH    ;控制显示管亮的位数，为0的位置显示管亮
	LEA BX,SEG_TAB
ld0:    MOV DX,PA_8255
	LODSB
	XLAT ;取显示数据
	OUT DX,AL ;段数据->8255 PA 口
	INC DX ;扫描模式->8255 PB 口
	MOV AL,AH
	OUT DX,AL
	CALL dl1;延迟1ms;
	MOV DX,PB_8255
	MOV AL,0FFH
	OUT DX,AL
	TEST AH,80H
	JZ LD1
	ROL AH,01H
	JMP ld0
LD1:	loop keng
	pop cx
	pop dx
	pop bx
	pop ax
	ret	    
dir 	ENDP

DL1     PROC NEAR ;延迟子程序
   	PUSH CX
    	MOV CX,500
    	LOOP $;自动循环
	POP CX
	RET
DL1 	ENDP

DIR2    PROC NEAR;中断中的显示程序
	push cx
	PUSH AX
	PUSH BX
	PUSH DX
	mov cx,300;    控制LED灯的闪烁时间
again:  LEA SI,buffer ;置显示缓冲器初值
	MOV AH,0FEH
    LEA BX,SEG_TAB
        
xunhuan:MOV DX,PA_8255
	LODSB
	XLAT ;取显示数据
	OUT DX,AL ;段数据->8255 PA 口
	INC DX ;扫描模式->8255 PB 口
	MOV AL,AH
	OUT DX,AL
	CALL DL1 ;延迟1ms
	MOV DX,PB_8255
	MOV AL,0FFH
	OUT DX,AL
	TEST AH,80H;当数码管扫描到边缘时，进入设置二极管的程序
	JZ tiaochu
	ROL AH,01H;左移，数据输出到下个数码管
	JMP xunhuan
tiaochu: loop again
	 
	 POP DX
  	 POP BX
	 POP AX
	 pop cx
	 RET
DIR2 ENDP

end start



