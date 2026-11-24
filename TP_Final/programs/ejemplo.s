# ejemplo.s - Programa mínimo: dos addi, un add y un sub con dependencias.
# Es el que usa scripts/smoke_test.ps1 en la placa.
#
# Ensamblar: python3 scripts/asm.py programs/ejemplo.s
#
# Resultado esperado al HALT:
#   x1=5 x2=10 x3=15 x4=-5 (0xFFFFFFFB)

        addi x1, x0, 5          ; x1 = 5
        addi x2, x0, 10         ; x2 = 10
        add  x3, x1, x2         ; x3 = 15 (forwarding de x1 y x2)
        sub  x4, x1, x2         ; x4 = -5
        halt
