# pipeline.s - Programa para ver una instruccion recorrer IF-ID-EX-MEM-WB
# y cada riesgo del pipeline. Ejecutarlo con "s" (paso a paso) en du.ps1.
#
# Ensamblar: python3 scripts/asm.py programs/pipeline.s
#
# Resultado esperado al HALT:
#   x1=0x5C x2=7 x3=12 x4=7 x5=x6=0x12345678 x7=0x12345679 x8=0x12 x9=0x78
#   x10=0x1234 x11=0 (las 2 de despues del beq se descartan) x12=0 x13=6
#   x14=106 x15=1
#   mem: [0]=0x12345678 [4]=0x0007000C [8]=6 [12]=106

# --- 1. Forwarding: el dato se usa en la instruccion siguiente
        addi x1, x0, 5          ; x1 = 5
        addi x2, x0, 7          ; x2 = 7
        add  x3, x1, x2         ; x3 = 12  (x2 desde EX/MEM, x1 desde MEM/WB)
        sub  x4, x3, x1         ; x4 = 7   (x3 desde EX/MEM)
        lui  x5, 0x12345        ; x5 = 0x12345000
        addi x5, x5, 0x678      ; x5 = 0x12345678 (forwarding de lui)

# --- 2. Stores (ver la memoria de datos con "dmem")
        sw   x5, 0(x0)          ; mem[0..3] = 0x12345678 (dato con forwarding)
        sb   x3, 4(x0)          ; mem[4]    = 0x0C
        sh   x4, 6(x0)          ; mem[6..7] = 0x0007

# --- 3. Load-use: 1 ciclo de stall + burbuja en ID/EX
        lw   x6, 0(x0)          ; x6 = 0x12345678
        addi x7, x6, 1          ; x7 = 0x12345679 (STALL, despues fwd desde WB)
        lb   x8, 3(x0)          ; x8 = 0x12
        lbu  x9, 0(x0)          ; x9 = 0x78
        lh   x10, 2(x0)         ; x10 = 0x1234

# --- 4. Saltos: tomado (flush de IF/ID e ID/EX) y no tomado
        beq  x4, x2, salto      ; 7 == 7 -> tomado
        addi x11, x0, -1        ; se descarta (flush)
        addi x11, x0, -1        ; se descarta (flush)
salto:  bne  x1, x1, salto      ; no tomado: no pierde ciclos
        addi x12, x0, 3         ; contador del loop

# --- 5. Loop: x13 = 3 + 2 + 1
loop:   add  x13, x13, x12
        addi x12, x12, -1
        bne  x12, x0, loop      ; tomado 2 veces

# --- 6. jal / jalr (subrutina)
        jal  x1, func           ; x1 = 0x5C, salta a func
        sw   x13, 8(x0)         ; mem[8] = 6 (al volver)
        halt                    ; frena el fetch y vacia el pipeline

func:   addi x14, x13, 100      ; x14 = 106
        sw   x14, 12(x0)        ; mem[12] = 106
        slt  x15, x4, x3        ; x15 = 1 (7 < 12)
        jalr x0, 0(x1)          ; vuelve a 0x5C (detras viene un HALT: se descarta)
