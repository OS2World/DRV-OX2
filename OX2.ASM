	TITLE	AUX Monochrome Device Driver for OS/2
	PAGE	60, 132
	COMMENT +
	File:		OX2.ASM
	File type:	Microsoft Macro Assembler (MASM) Version 5.1 or higher
	Author: 	JWC (parts by Mike Geary)
	Date:		June, 1989

	Purpose:
	This device directs AUX output to the monochrome display under OS/2.

	This driver is in the public domain.  If you find it useful,
	how about returning the favor and putting some of your own
	favorite utilities in the public domain, too?
	(***with source code!!!***)
	+

	.286c
	.sall

	DATA SEGMENT WORD PUBLIC 'DATA'
	SUBTTL Device Driver Header
	PAGE +

; ***********************************************************************
; *				DEVICE HEADER				*
; ***********************************************************************

PtrToNextHeader dd	0FFFFFFFFh	; Indicates loadable device driver
DeviceAttribute dw	1000100010000000b
					; Bit 15 - Character device
					; Bit 11 - Supports Open/Close
					; Bits 9-7 - OS/2 device driver
StrategyOffset	dw	CODE:Strategy	; Offset to the Strategy routine
IDCOffset	dw	-1		; unused--must be -1
DeviceName	db	'AUX     '	; Name of the device
ReservedBlock2	db	8 dup (0)	; Reserved words

; ***********************************************************************
; *			    DEVHLP SUPPORT				*
; ***********************************************************************

		.XLIST
;
; These constants define the DevHlp commands:
;
;DevHlp_SchedClockAddr EQU 0	; 0h  Get system clock routine
;DevHlp_DevDone	    EQU   1	; 1h  Device I/O Complete
;DevHlp_Yield	    EQU   2	; 2h  Yield the CPU
;DevHlp_TCYield	    EQU   3	; 3h  Yield the CPU to time-critical
;DevHlp_Block	    EQU   4	; 4h  Block thread on event
;DevHlp_Run	    EQU   5	; 5h  Unblock thread
;DevHlp_SemRequest   EQU   6	; 6h  Claim a semaphore
;DevHlp_SemClear     EQU   7	; 7h  Release a semaphore
;DevHlp_SemHandle    EQU   8	; 8h  Get a semaphore handle
;DevHlp_PushReqPacket EQU  9	; 9h  Add request to list
;DevHlp_PullReqPacket EQU 10	; Ah  Remove request from list
;DevHlp_PullParticular EQU 11	; Bh  Remove a specific request from list
;DevHlp_SortReqPacket EQU 12	; Ch  Insert request in sorted order to list
;DevHlp_AllocReqPacket EQU 13	; Dh  Get a request packet
;DevHlp_FreeReqPacket EQU 14	; Eh  Free request packet
;DevHlp_QueueInit    EQU  15	; Fh  Initialize character queue
;DevHlp_QueueFlush   EQU  16	;10h  Clear character queue
;DevHlp_QueueWrite   EQU  17	;11h  Put a char in the queue
;DevHlp_QueueRead    EQU  18	;12h  Get a char from the queue
;DevHlp_Lock	    EQU  19	;13h  Lock segment
;DevHlp_Unlock	    EQU  20	;14h  Unlock segment
DevHlp_PhysToVirt   EQU  21	;15h  Map physical address to virtual
DevHlp_VirtToPhys   EQU  22	;16h  Map virtual-to-physical address
;DevHlp_PhysToUVirt  EQU  23	;17h  Map physical-to-user virtual
;DevHlp_AllocPhys    EQU  24	;18h  Allocate physical memory
;DevHlp_FreePhys     EQU  25	;19h  Free physical memory
;DevHlp_SetROMVector EQU  26	;1Ah  Set software interrupt vector
;DevHlp_SetIRQ	    EQU  27	;1Bh  Set a hardware interrupt handler
;DevHlp_UnSetIRQ     EQU  28	;1Ch  Reset a hardware interrupt handler
;DevHlp_SetTimer     EQU  29	;1Dh  Set timer request handler
;DevHlp_ResetTimer   EQU  30	;1Eh  Remove a timer handler
;DevHlp_MonitorCreate EQU 31	;1Fh  Create a monitor
;DevHlp_Register     EQU  32	;20h  Install a monitor
;DevHlp_DeRegister   EQU  33	;21h  Remove a monitor
;DevHlp_MonWrite     EQU  34	;22h  Pass data records to monitor
;DevHlp_MonFlush     EQU  35	;23h  Remove all data from stream
;DevHlp_GetDOSVar    EQU  36	;24h  Return pointer to DOS variable
;DevHlp_SendEvent    EQU  37	;25h  Indicate an event
;DevHlp_ROMCritSection EQU 38	;26h  ROM BIOS critical section
;DevHlp_VerifyAccess EQU  39	;27h  Verify access to memory
DevHlp_AllocGDTSelector EQU 45	;2Dh  Allocate GDT selectors
DevHlp_PhysToGDTSelector EQU 46 ;2Eh  Map physical to virtual address
;DevHlp_RealToProt   EQU  47	;2Fh  Real Mode to Protect Mode
;DevHlp_ProtToReal   EQU  48	;30h  Protect Mode to Real Mode
;DevHlp_EOI	    EQU  49	;31h  Issue an End-Of-Interrupt
DevHlp_UnPhysToVirt EQU  50	;32h  Mark PhysToVirt complete
;DevHlp_TickCount    EQU  51	;33h  Modify timer
;DevHlp_GetLIDEntry  EQU  52	;34h  Get Logical ID
;DevHlp_FreeLIDEntry EQU  53	;35h  Release Logical ID
;DevHlp_ABIOSCall    EQU  54	;36h  Invoke ABIOS function
;DevHlp_ABIOSCommonEntry EQU 55	;37h  Invoke ABIOS Common Entry Point

;
; This macro simplifies calling a DevHlp service by doing a load of the
; function code into DL and calling pfnDevHlp.
;

@DevHlp MACRO name
	mov  dl, DevHlp_&name
	call pfnDevHlp
	ENDM

		.LIST

	SUBTTL Structures/Codes for Request Packets
	PAGE +
; ***********************************************************************
; *			 REQUEST PACKET STRUCTURE			*
; ***********************************************************************

PKTMAX		EQU	18		; Maximum size of packet

PacketStruc	STRUC
 PktLen 	db	?		; Length in bytes of packet
 PktUnit	db	?		; Subunit number of block device
 PktCmd 	db	?		; Command code
 PktStatus	dw	?		; Status word
 PktDOSLink	dd	?		; Reserved
 PktDevLink	dd	?		; Device multiple-request link
 PktData	db	PKTMAX dup (?)	; Data pertaining to specific packet
PacketStruc	ENDS

; ***********************************************************************
; *		   CODES FOR STATUS OF REQUEST PACKET			*
; ***********************************************************************

; Bit positions in Status field:
StatRecord	RECORD	StatError:1,StatDevError:1,StatRes:4,StatBusy:1,\
			StatDone:1,StatErrCode:8

; Error Codes:
StatWrProtVio	EQU	00h		; WRITE PROTECT VIOLATION
StatUnknownCmd	EQU	03h		; UNKNOWN COMMAND
StatGenFailure	EQU	0Ch		; GENERAL FAILURE
StatCharIOIntd	EQU	11h		; CHARACTER I/O INTERRUPTED
StatMonNotSupp	EQU	12h		; MONITORS NOT SUPPORTED

; ***********************************************************************
; *		   POINTER CONSTANTS FOR REQUEST PACKET 		*
; ***********************************************************************

Packet		EQU	ES:[BX]

; INIT arguments:

InitpEnd	EQU	DWORD PTR PktData+1	; Pointer to freemem after dev
IOpData		EQU	DWORD PTR PktData+1	; Transfer address
IOcount		EQU	WORD  PTR PktData+5	; Count of bytes/sectors
InitArgs	EQU	DWORD PTR PktData+5	; Pointer to CONFIG.SYS args

; ***********************************************************************
; *		    DATA USED BY THE STRATEGY ROUTINE			*
; ***********************************************************************

pfnDevHlp	dd	?	; Holds address of the DevHlp function entry
fbError		db	0	; Error flag used to signal to the Strategy
				;  routine a return with error from another
				;  subroutine.

SCRMINOFF	EQU	160*24
SCRMAXOFF	EQU	160*25

ptrMonoMem	LABEL	DWORD
offMonoMem	dw	SCRMINOFF
selMonoMem	dw	?

BS		EQU	08h
TAB		EQU	09h
LF		EQU	0Ah
CR		EQU	0Dh

; ***********************************************************************
; * A call table is set up to call a particular subroutine depending on *
; * the command code field within the request packet.			*
; * The table of offsets must be stored in the data segment.		*
; ***********************************************************************

StrategyFuncTable dw	INIT		;  0	INIT
		dw	BadCommand	;  1	MEDIA CHECK - N/A
		dw	BadCommand	;  2	BUILD BPB - N/A
		dw	BadCommand	;  3	reserved
		dw	BadCommand	;  4	READ (input) - N/A
		dw	BadCommand	;  5	NONDES READ NO WAIT - N/A
		dw	BadCommand	;  6	INPUT STATUS - N/A
		dw	BadCommand	;  7	INPUT FLUSH - N/A
		dw	WRITE		;  8	WRITE (output)
		dw	WRITE		;  9	WRITE WITH VERIFY - N/A
		dw	STATUS		;  A	OUTPUT STATUS
		dw	FLUSH		;  B	OUTPUT FLUSH
		dw	BadCommand	;  C	Reserved
		dw	OPEN		;  D	DEVICE OPEN
		dw	CLOSE		;  E	DEVICE CLOSE
		dw	BadCommand	;  F	REMOVABLE MEDIA - N/A
		dw	BadCommand	; 10	GENERIC IOCtl - N/A
		dw	BadCommand	; 11	RESET MEDIA - N/A
		dw	BadCommand	; 12	GET LOGICAL DRIVE MAP - N/A
		dw	BadCommand	; 13	SET LOGICAL DRIVE MAP - N/A
		dw	BadCommand	; 14	DEINSTALL - N/A
MaxCommandCode	EQU	(($-StrategyFuncTable) / 2) - 1


END_OF_DATA	EQU  $

DATA ENDS

CODE	  SEGMENT  WORD PUBLIC 'CODE'
	  ASSUME   CS:CODE, DS:DATA, ES:NOTHING

; ***********************************************************************
; *			    STRATEGY ROUTINE				*
; *									*
; * Far procedure Strategy gets the request packet and based on its	*
; * command code branches to the appropriate subroutine. Upon return	*
; * from the subroutine, the request is signalled serviced with or	*
; * without error.							*
; ***********************************************************************

Strategy PROC FAR
	push	es		; save the pointers to the request packet
	push	bx
	mov	al, BYTE PTR Packet.PktCmd
				; Command code is moved into al
	cmp	al, MaxCommandCode
				; If index larger than those supported
	ja	UNSUPPORTED	; Jump to indicate that the command is
				;  unsupported
	cbw			; Byte in al is converted to word
	mov	di, ax		; It is then moved to di
	shl	di, 1		; Converted to an index
	mov	fbError, 0	; Zero out the fbError flag prior to the call
	call	WORD PTR StrategyFuncTable[di]
				; Jump to appropriate offset
	pop	bx		; Restore the pointers to the request packet
	pop	es
	cmp	fbError, 0	; Upon return, check if subroutine returned
				;  an error
	jz	ERROR_FREE	; If no error, jump to signal devdone
	or	Packet.PktStatus, MASK StatError + StatGenFailure
				; Set the error condition in the Req Packet
				; Set the error to General Failure

ERROR_FREE:
	or	Packet.PktStatus, MASK StatDone
	jmp	FIN

UNSUPPORTED:
	pop	bx		; Retrieve the pushed values of bx and es
	pop	es
	call	BadCommand

FIN:
	ret
Strategy ENDP

; ***********************************************************************
; *			      WRITE ROUTINE				*
; ***********************************************************************

WRITE PROC NEAR
	cld
	mov	cx, WORD PTR Packet.IOcount	; CX = # bytes to write

	mov	ax, WORD PTR Packet.IOpData+2	; hi word of physical address
	mov	dx, ax
	mov	bx, WORD PTR Packet.IOpData	; low word of physical address
	mov	bp, bx				; NOTE: "Packet." is trashed!
	les	di, ptrMonoMem			; point ES:DI to mono memory
	mov	dh, 0				; 0 == DS:SI is virt address
	push	ds
	@DevHlp	PhysToVirt	
	jnc	outLoop
	mov	fbError, 1		; If failed, signal error writing
	jmp	write_term		; Jump to write_term
outLoop:
	lodsb				; Load a byte to write
	cmp	al, CR
	ja	outChar
	je	outCR
	cmp	al, LF
	je	outLF
	cmp	al, TAB
	je	outTAB
	cmp	al, BS
	je	outBS
outChar:
	stosb				; write the char
	inc	di			; advance over the attribute
	cmp	di, SCRMAXOFF		; are we at end of line?
	jb	outDone			; no, done with this char
	mov	di, SCRMINOFF		; yes, carriage return and ...
outLF:
	push	es			; save pointers and count
	push	di
	push	ds
	push	si
	push	cx

	mov	ax, es
	mov	ds, ax

	xor	di, di			; Scroll screen
	mov	si, 160
	mov	cx, 24*80
	rep	movsw

	mov	ax, 0720h		; Blank bottom line
	mov	cx, 80
	rep	stosw

; Remap DS to the user's physical buffer.
;	mov	ax, dx			; saved hi  word of phys. addr
;	mov	bx, bp			; saved low word of phys. addr
;	mov	dh, 0			; use DS:SI
;	@DevHlp	PhysToVirt

	pop	cx
	pop	si
	pop	ds
	pop	di
	pop	es
	jmp	outDone
outBS:
	cmp	di, SCRMINOFF
	je	outDone
	sub	di, 2
	jmp	outDone
outTAB:
	or	di, 0Eh
	add	di, 2
	jmp	outDone
outCR:
	mov	di, SCRMINOFF
outDone:
	loop	outLoop
write_term:
	pop	ds			; restore driver's DS register
	@DevHlp	UnPhysToVirt		; mark completion of PhysToVirt
	mov	WORD PTR ptrMonoMem, di	; save position on screen
; ------------------------------------------------------------------------
; Set new cursor position.
; ------------------------------------------------------------------------
	mov	dx, 03B4h
	shr	di, 1
	mov	ax, di
	mov	al, 0Eh
	out	dx, ax
	mov	ax, di
	xchg	ah, al
	mov	al, 0Fh
	out	dx, ax
	ret
WRITE ENDP

OPEN PROC NEAR
	mov	dx, 03B4h		; Set standard monochrome cursor.
	mov	ax, 0B0Ah
	out	dx, ax
	mov	ax, 0C0Bh
	out	dx, ax
	ret
OPEN ENDP

CLOSE PROC NEAR
	ret
CLOSE ENDP

STATUS PROC NEAR
	ret
STATUS ENDP

FLUSH PROC NEAR
	ret
FLUSH ENDP

NO_OP PROC NEAR
	ret
NO_OP ENDP

BadCommand PROC NEAR
	or Packet.PktStatus, MASK StatError + StatUnknownCmd
	ret
BadCommand ENDP

	SUBTTL Initialization Code
	page +

END_OF_CODE  EQU $

; ***********************************************************************
; *			     INIT ROUTINE				*
; *									*
; * INIT procedure is placed at the end of the code so it can go away	*
; * once initialization has been done.					*
; ***********************************************************************

INIT PROC NEAR
; ========================================================================
; Save the pointer to the DevHlp routines passed in the request packet.
; ========================================================================
	mov	ax, WORD PTR Packet.InitpEnd ; Save pointer to DevHlp
	mov	WORD PTR pfnDevHlp, ax
	mov	ax, WORD PTR Packet.InitpEnd+2
	mov	WORD PTR pfnDevHlp+2, ax
; ========================================================================
; Obtain a GDT selector and map it to the monochrome monitor's memory
; at B 0000.  The WRITE routine uses this memory area.
; ========================================================================
	push	es			; save ptr to request packet
	push	bx

	mov	ax, ds			; point ES:DI to GDT sel array
	mov	es, ax
	mov	di, OFFSET ptrMonoMem+2
	mov	cx, 1			; number of selectors
	@DevHlp	AllocGDTSelector	; allocate the selector
	jc	init_error
	mov	ax, 000Bh
	mov	bx, 0000h
	mov	cx, 4000
	mov	si, WORD PTR ptrMonoMem+2
	@DevHlp	PhysToGDTSelector	; map the selector to memory
	jc	init_error
; ------------------------------------------------------------------------
; ptrMonoMem now refers to the monochrome adapter's memory.
; ------------------------------------------------------------------------
; ------------------------------------------------------------------------
; Set the ending offsets to unload initialization code and data.
; ------------------------------------------------------------------------
@@:	pop	bx
	pop	es
	lea	ax, END_OF_CODE		; Place end of code segment into
	mov	WORD PTR Packet.InitpEnd, ax ; request packet
	lea	ax, END_OF_DATA		; Place end of data segment into
	mov	WORD PTR Packet.InitpEnd+2, ax ; request packet
	jmp	init_done
init_error:
	pop	bx			; restore ptr to request packet
	pop	es
	mov	fbError, 1
	mov	WORD PTR Packet.InitpEnd, 0
	mov	WORD PTR Packet.InitpEnd+2, 0
init_done:
	ret
INIT ENDP

CODE	ENDS

	END
