# instrucciones.s - Usa las 32 instrucciones del set y las pseudoinstrucciones
# (nop, mv, j, ret), con inmediatos negativos y saltos hacia atrás.
# Sirve para probar el ensamblador y que cada instrucción dé el valor de la spec.
#
# Ensamblar: python3 scripts/asm.py programs/instrucciones.s
#
# Resultado esperado al HALT: ver la lista al final del archivo.

# --- 1. Tipo R
        addi x1, x0, -8         ; x1 = -8 (0xFFFFFFF8)
        addi x2, x0, 3          ; x2 = 3
        add  x3, x1, x2         ; x3 = -5
        sub  x4, x2, x1         ; x4 = 11
        sll  x5, x2, x2         ; x5 = 3 << 3 = 24
        srl  x6, x1, x2         ; x6 = 0x1FFFFFFF (entra un 0 arriba)
        sra  x7, x1, x2         ; x7 = -1 (se repite el signo)
        and  x8, x1, x4         ; x8 = 8
        or   x9, x1, x2         ; x9 = -5
        xor  x10, x1, x4        ; x10 = -13 (0xFFFFFFF3)
        slt  x11, x1, x2        ; x11 = 1 (-8 < 3 con signo)
        sltu x12, x1, x2        ; x12 = 0 (0xFFFFFFF8 > 3 sin signo)

# --- 2. Tipo I aritméticas y shifts con inmediato
        andi x13, x1, 0xFF      ; x13 = 0xF8
        ori  x14, x2, -16       ; x14 = -13 (0xFFFFFFF3)
        xori x15, x1, -1        ; x15 = 7 (not de -8)
        slti x16, x1, -7        ; x16 = 1 (-8 < -7)
        sltiu x17, x2, -1       ; x17 = 1 (3 < 0xFFFFFFFF sin signo)
        slli x18, x2, 30        ; x18 = 0xC0000000
        srli x19, x18, 28       ; x19 = 0xC
        srai x20, x18, 28       ; x20 = -4 (0xFFFFFFFC)

# --- 3. lui, stores y loads
        lui  x21, 0x80008       ; x21 = 0x80008000
        addi x21, x21, -1       ; x21 = 0x80007FFF
        sw   x21, 0(x0)         ; mem[0..3] = 0x80007FFF
        sh   x1, 4(x0)          ; mem[4..5] = 0xFFF8
        sb   x2, 6(x0)          ; mem[6]    = 0x03
        lb   x22, 3(x0)         ; x22 = 0xFFFFFF80 (byte 0x80 con signo)
        lbu  x23, 3(x0)         ; x23 = 0x80
        lh   x24, 2(x0)         ; x24 = 0xFFFF8000 (half 0x8000 con signo)
        lhu  x25, 2(x0)         ; x25 = 0x8000
        lw   x26, 4(x0)         ; x26 = 0x0003FFF8

# --- 4. beq y bne, hacia adelante y hacia atrás
        mv   x27, x0            ; x27 = 0 (contador)
atras:  addi x27, x27, 1
        beq  x27, x2, sigue     ; adelante: tomado cuando x27 = 3
        bne  x0, x2, atras      ; atrás: siempre tomado
sigue:  nop

# --- 5. jal y jalr (ret), y jal hacia atrás
        j    abajo              ; jal x0 hacia adelante
arriba: jal  x1, func           ; x1 = dirección de la instrucción siguiente
        sw   x28, 8(x0)         ; mem[8] = 42 (después de volver de func)
        halt

abajo:  jal  x29, arriba        ; jal hacia atrás, x29 = dirección de la siguiente
        addi x30, x0, 1         ; no se ejecuta nunca

func:   addi x28, x0, 42        ; x28 = 42
        ret                     ; jalr x0, 0(x1)

# Resultado esperado:
#   x1=0x94 x2=3 x3=-5 x4=11 x5=24 x6=0x1FFFFFFF x7=-1 x8=8 x9=-5 x10=-13
#   x11=1 x12=0 x13=0xF8 x14=-13 x15=7 x16=1 x17=1 x18=0xC0000000 x19=0xC
#   x20=-4 x21=0x80007FFF x22=0xFFFFFF80 x23=0x80 x24=0xFFFF8000 x25=0x8000
#   x26=0x0003FFF8 x27=3 x28=42 x29=0xA0 x30=0
#   mem: [0]=0x80007FFF [4]=0x0003FFF8 [8]=42
