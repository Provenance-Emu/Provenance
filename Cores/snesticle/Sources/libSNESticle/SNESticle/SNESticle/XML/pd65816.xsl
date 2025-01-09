<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
<xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes"/>

<!-- addressing modes -->

<xsl:template match="addr_dp">
; Direct $xx
	LI.8     $0			; direct
	ADD     $0,DP 
	AND     $0,0xFFFF
</xsl:template>	

<xsl:template match="addr_dp_indirect">
; Direct Indirect ($xx) 
	LI.8     $0			; direct
	ADD     $0,DP 
	AND     $0,0xFFFF

	LM.16    $0,$0		; indirect
	OR      $0,DB
</xsl:template>

<xsl:template match="addr_dp_indirectlong">
; Direct Indirect Long [$xx]
	LI.8     $0			; direct
	ADD     $0,DP 
	AND     $0,0xFFFF

	LM.24    $0,$0		; indirect long
</xsl:template>	

<xsl:template match="addr_dp_indirect_iy">
; Direct Indirect Indexed ($xx),Y
	LI.8     $0			; direct
	ADD     $0,DP 
	AND     $0,0xFFFF

	LM.16    $0,$0		; indirect
	OR      $0,DB

	ADD     $0,Y 		; indexed y
</xsl:template>	

<xsl:template match="addr_dp_indirectlong_iy">
; Direct Indirect Long Indexed [$xx],Y
	LI.8     $0			; direct
	ADD     $0,DP 
	AND     $0,0xFFFF

	LM.24    $0,$0		; indirect long

	ADD     $0,Y 		; indexed y
</xsl:template>
	
<xsl:template match="addr_dp_indirectlong">
; Direct Indirect Long [$xx]
	LI.8     $0			; direct
	ADD     $0,DP 
	AND     $0,0xFFFF

	LM.24    $0,$0		; indirect long
</xsl:template>

<xsl:template match="addr_dp_ix">
; Direct Indexed X $xx,X
	LI.8     $0			; direct
	ADD     $0,DP 
	AND     $0,0xFFFF

    CYCLE   1           ; consume cycle
	ADD     $0,X 		; indexed x
	AND     $0,DPMASK	; no wrapping beyond zero bank (or page)
</xsl:template>	

<xsl:template match="addr_dp_iy">
; Direct Indexed Y $xx,Y
	LI.8     $0			; direct
	ADD     $0,DP 
	AND     $0,0xFFFF

    CYCLE   1           ; consume cycle
	ADD     $0,Y 		; indexed y
	AND     $0,DPMASK	; no wrapping beyond zero bank (or page)
</xsl:template>	

<xsl:template match="addr_dp_ix_indirect">
; Direct Indexed Indirect ($xx,X)
	LI.8     $0			; direct
	ADD     $0,DP 
	AND     $0,0xFFFF

    CYCLE   1           ; consume cycle
	ADD     $0,X        ; indexed x
	AND     $0,DPMASK   ; no wrapping beyond zero bank (or page)

	LM.16    $0,$0		; indirect
	OR      $0,DB
</xsl:template>

<xsl:template match="addr_abs">
; Absolute $xxxx
	LI.16    $0			; absolute
	OR      $0,DB
</xsl:template>	

<xsl:template match="addr_abs_zero">
; Absolute $xxxx
	LI.16    $0			; absolute
</xsl:template>	

<xsl:template match="addr_abs_indirect">
; Absolute Zero Indirect ($xxxx)
	LI.16    $0			; absolute zero bank

	LM.16    $0,$0		; indirect zero
	AND     $0,0xFFFF
</xsl:template>

<xsl:template match="addr_abs_indirectlong">
; Absolute Zero Indirect ($xxxx)
	LI.16    $0			; absolute zero bank

	LM.24    $0,$0		; indirect 
</xsl:template>

<xsl:template match="addr_abs_ix_indirect">
; Absolute Zero Indexed Indirect ($xxxx,X)
	LI.16    $0			; absolute zero bank

	ADD     $0,X 		; indexed x

	LM.16    $0,$0		; indirect zero 
	AND     $0,0xFFFF
</xsl:template>	



<xsl:template match="addr_pb_abs_ix_indirect">
; Absolute Zero Indexed Indirect ($xxxx,X)
	LI.16    $0			; absolute zero bank
	ADD     $0,X 		; indexed x
	AND     $0,0xFFFF

	LR		$1,PC		; get PC
    SHR		$1,16
    SHL		$1,16
    OR		$0,$1

	LM.16    $0,$0		; indirect zero 
	AND     $0,0xFFFF
</xsl:template>	






<xsl:template match="addr_abslong">
; Absolute Long $xxxxxx
	LI.24    $0			; absolute long
</xsl:template>	

<xsl:template match="addr_abs_ix">
; Absolute Indexed X $xxxx,X
	LI.16    $0			; absolute
	OR       $0,DB

	ADD      $0,X 		; indexed x
</xsl:template>	

<xsl:template match="addr_abs_iy">
; Absolute Indexed Y $xxxx,Y
	LI.16    $0			; absolute
	OR       $0,DB

	ADD      $0,Y 		; indexed y
</xsl:template>	

<xsl:template match="addr_abslong_ix">
; Absolute Long Indexed X $xxxxxx,X
	LI.24    $0			; absolute long

	ADD      $0,X 		; indexed x
</xsl:template>	

<xsl:template match="addr_sr">
; Stack Relative $xx,s
	LI.8     $0			; stack 
	ADD      $0,S 
	AND      $0,0xFFFF
    CYCLE   1           ; consume cycle
</xsl:template>	

<xsl:template match="addr_sr_indirect_iy">
; Stack Relative Indirect Indexed ($xx,s),y
	LI.8     $0			; stack
	ADD      $0,S 
	AND      $0,0xFFFF
    CYCLE   1           ; consume cycle

	LM.16    $0,$0		; indirect
	OR       $0,DB

    CYCLE   1           ; consume cycle
	ADD      $0,Y 		; indexed
</xsl:template>


<xsl:template match="cycle">
	CYCLE 1
</xsl:template>	

<xsl:template match="addr_imma">
; Immediate #$xx
	LI.x       $1
</xsl:template>	

<xsl:template match="addr_immx">
; Immediate #$xx
	LI.x       $1
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
    LM.x    $1,$0	    
</xsl:template>


<xsl:template match="write">
    SM.x    $0,$1	    
</xsl:template>




<xsl:template match="AND" >
; AND
	LR.x    $2,A
	AND     $2,$1
	SR.x    A,$2
	SF.x    Z,$2
	SF.x    N,$2
</xsl:template>




<xsl:template match="TSB">
; TSB
	LR.x    $2,A
	AND     $2,$1
	SF.x    Z,$2
; SET
    LR.x		$2,A    
    OR			$1,$2
    SM.x        $0,$1
</xsl:template>


<xsl:template match="TRB">
; TRB
	LR.x    $2,A
	AND     $2,$1
	SF.x    Z,$2
; RESET
    LR.x		$2,A    
    OR			$1,$2
    XOR			$1,$2
    SM.x        $0,$1
</xsl:template>


<xsl:template match="BIT" >
	<xsl:param name="size"/>
; BIT
	LR.x    $2,A
	AND     $2,$1
	SF.x    Z,$2
	SF.x    N,$1
	SHR		$1,<xsl:value-of select="$size - 2"/>
	SF.x    V,$1
</xsl:template>

<xsl:template match="BITI" >
; BIT imm
	LR.x    $2,A
	AND     $2,$1
	SF.x    Z,$2
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



<xsl:template match="CMP" >
	<xsl:param name="size"/>
; CMP
	LR.x    $2,A
	SUB     $2,$1
	SF.x    Z,$2
	SF.x    N,$2
    SHR     $2,<xsl:value-of select="$size"/>    ; set carry
    XOR		$2,1
	SF.x    C,$2
</xsl:template>

<xsl:template match="CPX" >
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


<xsl:template match="CPY" >
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




<xsl:template match="LDA" >
; LDA
    SR.x    A,$1
	SF.x    Z,$1
	SF.x    N,$1
</xsl:template>

<xsl:template match="LDX" >
; LDX
    SR.x    X,$1
	SF.x    Z,$1
	SF.x    N,$1
</xsl:template>

<xsl:template match="LDY" >
; LDY
    SR.x    Y,$1
	SF.x    Z,$1
	SF.x    N,$1
</xsl:template>

<xsl:template match="STZ" >
; STZ
    LR.x    $1,0
    SM.x    $0,$1
</xsl:template>

<xsl:template match="STA" >
; STA
    LR.x    $1,A
    SM.x    $0,$1
</xsl:template>

<xsl:template match="STX" >
; STX
    LR.x    $1,X
    SM.x    $0,$1
</xsl:template>

<xsl:template match="STY" >
; STY
    LR.x    $1,Y
    SM.x    $0,$1
</xsl:template>

<xsl:template match="INA" >
; INA
    LR.x    $1,A
    ADD	    $1,1
    SR.x    A,$1
    SF.x    Z,$1
    SF.x    N,$1
</xsl:template>

<xsl:template match="INX" >
; INX
    LR.x    $1,X
    ADD	    $1,1
    SR.x    X,$1
    SF.x    Z,$1
    SF.x    N,$1
</xsl:template>

<xsl:template match="INY" >
; INY
    LR.x    $1,Y
    ADD	    $1,1
    SR.x    Y,$1
    SF.x    Z,$1
    SF.x    N,$1
</xsl:template>

<xsl:template match="DEA" >
; DEA
    LR.x    $1,A
    SUB	    $1,1
    SR.x    A,$1
    SF.x    Z,$1
    SF.x    N,$1
</xsl:template>

<xsl:template match="DEX" >
; DEX
    LR.x    $1,X
    SUB	    $1,1
    SR.x    X,$1
    SF.x    Z,$1
    SF.x    N,$1
</xsl:template>

<xsl:template match="DEY" >
; DEY
    LR.x    $1,Y
    SUB	    $1,1
    SR.x    Y,$1
    SF.x    Z,$1
    SF.x    N,$1
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


<xsl:template match="ROLA">
	<xsl:param name="size"/>
; ROL A 
    LR.x    $1,A
    LF      $2,C     ; $2 = 0000000c
    SHL     $1,1     ; $1 = ddddddd0
    OR      $1,$2    ; $1 = dddddddc
    SR.x    A,$1    ; A  = dddddddc
    SF.x    Z,$1
    SF.x    N,$1
    SHR     $1,<xsl:value-of select="$size"/>    ; set carry
    SF.x    C,$1
</xsl:template>

<xsl:template match="RORA">
	<xsl:param name="size"/>
; ROR A 
    LR.x    $1,A
    LF      $2,C     ; $2 = 0000000c
    SHL     $2,<xsl:value-of select="$size"/>     ; $2 = c0000000
    SF.x    C,$1     ;  C = 0000000d
    OR      $1,$2    ; $1 =cdddddddd
    SHR     $1,1     ; $1 = cddddddd
    SR.x    A,$1     ; A  = cddddddd
    SF.x    Z,$1
    SF.x    N,$1
</xsl:template>

<xsl:template match="LSRA">
; LSR A 
    LR.x    $1,A     ; $1 = dddddddd
    SF.x    C,$1     ;  C = 0000000d
    SHR     $1,1     ; $1 = 0ddddddd
    SR.x    A,$1     ;  A = 0ddddddd
    SF.x    Z,$1
    SF.x    N,$1
</xsl:template>

<xsl:template match="ASLA">
	<xsl:param name="size"/>
; ASL A
    LR.x    $1,A     ; $1 = dddddddd
    SHL     $1,1     ; $1 = ddddddd0
    SR.x    A,$1
    SF.x    Z,$1
    SF.x    N,$1
    SHR     $1,<xsl:value-of select="$size"/>     ; set carry
    SF.x    C,$1
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




<xsl:template match="JSR">
	LR			$2,PC
	SUB			$2,1
	PUSH.16		$2		; push 16-bit PC
	SR.16		PC,$0	; 16-bit jump
</xsl:template>

<xsl:template match="JSL">
	LR			$2,PC
	SUB			$2,1
	PUSH.24		$2		; push 24-bit PC
	SR.24		PC,$0	; 24-bit jump
</xsl:template>

<xsl:template match="JMP">
	SR.16		PC,$0	; 16-bit jump
</xsl:template>

<xsl:template match="JMPL">
	SR.24		PC,$0	; 24-bit jump
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
	
	<xsl:choose>
		<!-- permutate instruction based on different accumulator sizes -->
		<xsl:when test="@size='a'">
			<op>
			<xsl:attribute name="code"> <xsl:value-of select="@code"/> </xsl:attribute>
			<xsl:attribute name="size">16</xsl:attribute>
			<xsl:attribute name="cycles"> 
				<xsl:choose>
					<!-- 1. Add 1 cycle if m=0 (16-bit memory/accumulator)  -->
					<xsl:when test="contains(@flags, '1')">
						<xsl:value-of select="@cycles+1"/> 
					</xsl:when>
					<!-- 5. Add 2 cycles if m=0 (16-bit memory/accumulator) -->
					<xsl:when test="contains(@flags, '5')">
						<xsl:value-of select="@cycles+2"/> 
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="@cycles"/> 
					</xsl:otherwise>
				</xsl:choose>
			</xsl:attribute>
			<xsl:attribute name="m">0</xsl:attribute>
			<xsl:if test="@e">
				<xsl:attribute name="e"> <xsl:value-of select="@e"/> </xsl:attribute>
			</xsl:if>
			<xsl:call-template name="OpName">
				<xsl:with-param name="parm">m0</xsl:with-param>
			</xsl:call-template>
    			<xsl:apply-templates>
    				<xsl:with-param name="size">16</xsl:with-param>
    			</xsl:apply-templates>
			</op>

			<op>
			<xsl:attribute name="code"> <xsl:value-of select="@code"/> </xsl:attribute>
			<xsl:attribute name="size">8</xsl:attribute>
			<xsl:attribute name="cycles"> <xsl:value-of select="@cycles"/> </xsl:attribute>
			<xsl:attribute name="m">1</xsl:attribute>
			<xsl:if test="@e">
				<xsl:attribute name="e"> <xsl:value-of select="@e"/> </xsl:attribute>
			</xsl:if>
			<xsl:call-template name="OpName">
				<xsl:with-param name="parm">m1</xsl:with-param>
			</xsl:call-template>
    			<xsl:apply-templates>
    				<xsl:with-param name="size">8</xsl:with-param>
    			</xsl:apply-templates>
			</op>
		</xsl:when>

		<!-- permutate instruction based on different index register sizes -->
		<xsl:when test="@size='x'">
			<op>
			<xsl:attribute name="code"> <xsl:value-of select="@code"/> </xsl:attribute>
			<xsl:attribute name="size">16</xsl:attribute>
			<xsl:attribute name="cycles"> 
				<xsl:choose>
					<!-- 10. Add 1 cycle if x=0 (16-bit index registers)   -->
					<xsl:when test="contains(@flags, 'A')">
						<xsl:value-of select="@cycles+1"/> 
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="@cycles"/> 
					</xsl:otherwise>
				</xsl:choose>
			</xsl:attribute>
			<xsl:attribute name="x">0</xsl:attribute>
			<xsl:if test="@e">
				<xsl:attribute name="e"> <xsl:value-of select="@e"/> </xsl:attribute>
			</xsl:if>
			<xsl:call-template name="OpName">
				<xsl:with-param name="parm">x0</xsl:with-param>
			</xsl:call-template>
    			<xsl:apply-templates>
    				<xsl:with-param name="size">16</xsl:with-param>
    			</xsl:apply-templates>
			</op>

			<op>
			<xsl:attribute name="code"> <xsl:value-of select="@code"/> </xsl:attribute>
			<xsl:attribute name="size">8</xsl:attribute>
			<xsl:attribute name="cycles"> <xsl:value-of select="@cycles"/> </xsl:attribute>
			<xsl:attribute name="x">1</xsl:attribute>
			<xsl:if test="@e">
				<xsl:attribute name="e"> <xsl:value-of select="@e"/> </xsl:attribute>
			</xsl:if>
			<xsl:call-template name="OpName">
				<xsl:with-param name="parm">x1</xsl:with-param>
			</xsl:call-template>
    			<xsl:apply-templates>
    				<xsl:with-param name="size">8</xsl:with-param>
    			</xsl:apply-templates>
			</op>
			
		</xsl:when>
		
		<xsl:otherwise>
			<op>
			<xsl:attribute name="code"> <xsl:value-of select="@code"/> </xsl:attribute>
			<xsl:attribute name="cycles"> <xsl:value-of select="@cycles"/> </xsl:attribute>
			<xsl:if test="@x">
				<xsl:attribute name="x"> <xsl:value-of select="@x"/> </xsl:attribute>
			</xsl:if>
			<xsl:if test="@m">
				<xsl:attribute name="m"> <xsl:value-of select="@m"/> </xsl:attribute>
			</xsl:if>
			<xsl:if test="@e">
				<xsl:attribute name="e"> <xsl:value-of select="@e"/> </xsl:attribute>
			</xsl:if>
			<xsl:call-template name="OpName">
				<xsl:with-param name="parm"></xsl:with-param>
			</xsl:call-template>
				<xsl:apply-templates/>
			</op>
		</xsl:otherwise>
	
	</xsl:choose>
	
</xsl:template>

</xsl:stylesheet>
