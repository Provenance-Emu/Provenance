<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
<xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes"/>

<!-- addressing modes -->



<xsl:template match="addr_dp">
; Direct $xx
	LI.8     $0			; direct
	ADD     $0,DP 
</xsl:template>	


<xsl:template match="addr_x_indirect">
	LR.8    $0,X		; x indirect
	ADD     $0,DP 
</xsl:template>	




<xsl:template match="addr_y_indirect">
	LR.8    $0,Y		; y indirect
	ADD     $0,DP 
</xsl:template>	


<xsl:template match="addr_x_indirect_inc">
; Direct Indexed X $xx,X
	LR.8    $0,X		; x indirect
	ADD     X,1 		; inc
	ADD     $0,DP 
</xsl:template>	



<xsl:template match="addr_dp_ix">
; Direct Indexed X $xx,X
	LI.8     $0			; direct
	ADD     $0,X 		; indexed x
	AND     $0,0xFF
	ADD     $0,DP 
</xsl:template>	

<xsl:template match="addr_dp_iy">
; Direct Indexed Y $xx,Y
	LI.8     $0			; direct
	ADD     $0,Y 		; indexed y
	AND     $0,0xFF
	ADD     $0,DP 
</xsl:template>	


<xsl:template match="addr_abs">
; Absolute $xxxx
	LI.16    $0			; absolute
</xsl:template>	



<xsl:template match="addr_abs_ix">
; Absolute Indexed X $xxxx,X
	LI.16    $0			; absolute
	ADD      $0,X 		; indexed x
</xsl:template>	

<xsl:template match="addr_abs_iy">
; Absolute Indexed Y $xxxx,Y
	LI.16    $0			; absolute
	ADD      $0,Y 		; indexed y
</xsl:template>	



<xsl:template match="addr_dp_ix_indirect">
; Direct Indexed Indirect ($xx,X)
	LI.8     $0			; direct

	ADD     $0,X 		; indexed x
	AND     $0,0xFF
	ADD     $0,DP 

	LM.16    $0,$0		; indirect
</xsl:template>


<xsl:template match="addr_dp_indirect_iy">
; Direct Indirect Indexed ($xx),Y
	LI.8     $0			; direct
	ADD     $0,DP 

	LM.16    $0,$0		; indirect

	ADD     $0,Y 		; indexed y
</xsl:template>	


<xsl:template match="addr_abs_ix_indirect">
; Absolute Zero Indexed Indirect ($xxxx,X)
	LI.16    $0			; absolute zero bank

	ADD     $0,X 		; indexed x

	LM.16    $0,$0		; indirect zero 
	AND     $0,0xFFFF
</xsl:template>	


<xsl:template match="addr_imm">
; Immediate #$xx
	LI.8     $1
</xsl:template>	


<xsl:template match="addr_imm8">
; Immediate #$xx
	LI.8     $1
</xsl:template>	

<xsl:template match="addr_imm16">
; Immediate #$xxxx
	LI.16    $1
</xsl:template>	

<xsl:template match="read">
    LM.8    $1,$0	    
</xsl:template>


<xsl:template match="read16">
    LM.16    $1,$0	    
</xsl:template>


<xsl:template match="write">
    SM.8    $0,$1	    
</xsl:template>








<xsl:template match="LDA" >
; LDA
    SR.8    A,$1
	SF.8    Z,$1
	SF.8    N,$1
</xsl:template>

<xsl:template match="LDYA" >
; LDYA
    SR.16    YA,$1
	SF.16    Z,$1
	SF.16    N,$1
</xsl:template>

<xsl:template match="LDX" >
; LDX
    SR.8    X,$1
	SF.8    Z,$1
	SF.8    N,$1
</xsl:template>

<xsl:template match="LDY" >
; LDY
    SR.8    Y,$1
	SF.8    Z,$1
	SF.8    N,$1
</xsl:template>

<xsl:template match="STA" >
; STA
    LR.8    $1,A
    SM.8    $0,$1
</xsl:template>

<xsl:template match="STYA" >
; STYA
    LR.16    $1,YA
    SM.16    $0,$1
</xsl:template>


<xsl:template match="STX" >
; STX
    LR.8    $1,X
    SM.8    $0,$1
</xsl:template>

<xsl:template match="STY" >
; STY
    LR.8    $1,Y
    SM.8    $0,$1
</xsl:template>



<xsl:template match="INC" >
; INC
    ADD	    $1,1
    SM.x    $0,$1
    SF.x    Z,$1
    SF.x    N,$1
</xsl:template>

<xsl:template match="DEC" >
; DEC
    SUB	    $1,1
    SM.x    $0,$1
    SF.x    Z,$1
    SF.x    N,$1
</xsl:template>







<xsl:template match="CMP" >
	<xsl:param name="size"/>
; CMP
	SUB     $2,$1
	SF.x    Z,$2
	SF.x    N,$2
    SHR     $2,<xsl:value-of select="$size"/>    ; set carry
    XOR		$2,1
	SF.x    C,$2
</xsl:template>







<xsl:template match="CMPA" >
	<xsl:param name="size"/>
; CMPA
	LR.x    $2,A
	SUB     $2,$1
	SF.x    Z,$2
	SF.x    N,$2
    SHR     $2,<xsl:value-of select="$size"/>    ; set carry
    XOR		$2,1
	SF.x    C,$2
</xsl:template>


<xsl:template match="CMPX" >
	<xsl:param name="size"/>
; CPX
	LR.x    $2,X
	SUB     $2,$1
	SF.x    Z,$2
	SF.x    N,$2
    SHR     $2,<xsl:value-of select="$size"/>    ; set carry
    XOR		$2,1
	SF.x    C,$2
</xsl:template>


<xsl:template match="CMPY" >
	<xsl:param name="size"/>
; CPY
	LR.x    $2,Y
	SUB     $2,$1
	SF.x    Z,$2
	SF.x    N,$2
    SHR     $2,<xsl:value-of select="$size"/>    ; set carry
    XOR		$2,1
	SF.x    C,$2
</xsl:template>



<xsl:template match="SET1" >
; SET1
	LM.8    $1,$0   ; $1 = data
    OR		$1,<xsl:value-of select="@bit"/>   
	SM.8    $0,$1   ; store data
</xsl:template>

<xsl:template match="CLR1" >
; CLR1
	LM.8    $1,$0   ; $1 = data
    OR		$1,<xsl:value-of select="@bit"/>   
    XOR		$1,<xsl:value-of select="@bit"/>   
	SM.8    $0,$1   ; store data
</xsl:template>








<xsl:template match="JMP">
	SR.16		PC,$0	; 16-bit jump
</xsl:template>


<xsl:template match="CALL">
	LR			$2,PC
<!--	SUB			$2,1-->
	PUSH.16		$2		; push 16-bit PC
	SR.16		PC,$0	; 16-bit jump
</xsl:template>


<xsl:template match="SBC" >
	<xsl:param name="size"/>
; SBC (A + ~B + C)
	NOT.x	$1			; invert operand
	LR.x    $2,A	; A
	SBC.x   $2,$1	; A + value + carry
	SR.x	A,$2
	SF.x    Z,$2
	SF.x    N,$2
    SHR     $2,<xsl:value-of select="$size"/>    ; set carry
	SF.x    C,$2
</xsl:template>


<xsl:template match="ADC" >
	<xsl:param name="size"/>
; ADC (A + B + C)
	LR.x    $2,A	; A
	ADC.x   $2,$1	; A + value + carry
	SR.x	A,$2
	SF.x    Z,$2
	SF.x    N,$2
    SHR     $2,<xsl:value-of select="$size"/>    ; set carry
	SF.x    C,$2
</xsl:template>



<xsl:template match="ADCM" >
	<xsl:param name="size"/>
; ADC (A + B + C)
	ADC.x   $2,$1	; A + value + carry
	SM.x	$0,$2
	SF.x    Z,$2
	SF.x    N,$2
    SHR     $2,<xsl:value-of select="$size"/>    ; set carry
	SF.x    C,$2
</xsl:template>


<xsl:template match="SBCM" >
	<xsl:param name="size"/>
; SBC (A + ~B + C)
	NOT.x	$1			; invert operand
	SBC.x   $2,$1	; A + value + carry
	SM.x	$0,$2
	SF.x    Z,$2
	SF.x    N,$2
    SHR     $2,<xsl:value-of select="$size"/>    ; set carry
	SF.x    C,$2
</xsl:template>








<xsl:template match="AND" >
; AND
	LR.x    $2,A
	AND     $2,$1
	SR.x    A,$2
	SF.x    Z,$2
	SF.x    N,$2
</xsl:template>



<xsl:template match="ORA" >
; ORA
	LR.x    $2,A
	OR      $2,$1
	SR.x    A,$2
	SF.x    Z,$2
	SF.x    N,$2
</xsl:template>

<xsl:template match="EOR" >
; EOR
	LR.x    $2,A
	XOR     $2,$1
	SR.x    A,$2
	SF.x    Z,$2
	SF.x    N,$2
</xsl:template>


<xsl:template match="ANDM" >
; ANDM
	AND     $2,$1
	SM.x    $0,$2
	SF.x    Z,$2
	SF.x    N,$2
</xsl:template>


<xsl:template match="ORM" >
; ORM
	OR      $2,$1
	SM.x    $0,$2
	SF.x    Z,$2
	SF.x    N,$2
</xsl:template>

<xsl:template match="EORM" >
; EORM
	XOR     $2,$1
	SM.x    $0,$2
	SF.x    Z,$2
	SF.x    N,$2
</xsl:template>


<xsl:template match="ASL">
	<xsl:param name="size"/>
; ASL
    SHL         $1,1     ; $1 = ddddddd0
    SM.x        $0,$1
    SF.x        Z,$1
    SF.x        N,$1
    SHR         $1,<xsl:value-of select="$size"/>     ; set carry
    SF.x        C,$1
</xsl:template>

<xsl:template match="LSR">
; LSR 
    SF.x    C,$1     ;  C = 0000000d
    SHR     $1,1     ; $1 = 0ddddddd
    SM.x    $0,$1
    SF.x    Z,$1
    SF.x    N,$1
</xsl:template>


<xsl:template match="ROL">
	<xsl:param name="size"/>
; ROL A 
    LF      $2,C     ; $2 = 0000000c
    SHL     $1,1     ; $1 = ddddddd0
    OR      $1,$2    ; $1 = dddddddc
    SM.x    $0,$1
    SF.x    Z,$1
    SF.x    N,$1
    SHR     $1,<xsl:value-of select="$size"/>    ; set carry
    SF.x    C,$1
</xsl:template>


<xsl:template match="ROR">
	<xsl:param name="size"/>
; ROR A 
    LF      $2,C     ; $2 = 0000000c

    SHL     $2,<xsl:value-of select="$size"/>     ; $2 = c0000000
    SF.x    C,$1     ;  C = 0000000d
    OR      $1,$2    ; $1 =cdddddddd
    SHR     $1,1     ; $1 = cddddddd

    SM.x    $0,$1
    SF.x    Z,$1
    SF.x    N,$1
</xsl:template>











<!--                    -->


<xsl:template match="/">
   <xsl:apply-templates />
</xsl:template>

<xsl:template match="cpu">
    <cpu>
    <xsl:attribute name="name"> <xsl:value-of select="@name"/> </xsl:attribute>

        <xsl:apply-templates/>
    </cpu>
</xsl:template>


<xsl:template match="ops">
<ops>
    <xsl:apply-templates/>
</ops>
</xsl:template>

<xsl:template name="OpName">
	<xsl:param name="parm"></xsl:param>
			<xsl:attribute name="name">
				<xsl:for-each select="*"><xsl:value-of select="name()" />_</xsl:for-each><xsl:value-of select="$parm" />
			</xsl:attribute>
</xsl:template>


<xsl:template match="op">
	<op>
	<xsl:attribute name="code"> <xsl:value-of select="@code"/> </xsl:attribute>
	<xsl:attribute name="cycles"> <xsl:value-of select="@cycles"/> </xsl:attribute>
    <xsl:if test="@size">
		<xsl:attribute name="size"> <xsl:value-of select="@size"/> </xsl:attribute>
    </xsl:if>
	<xsl:call-template name="OpName">
		<xsl:with-param name="parm"></xsl:with-param>
	</xsl:call-template>

    			<xsl:apply-templates>
    				<xsl:with-param name="size"> <xsl:value-of select="@size"/> </xsl:with-param>
    			</xsl:apply-templates>
			
	</op>

</xsl:template>

</xsl:stylesheet>
