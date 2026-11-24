# Ensamblador: decisiones de diseño

Archivos: scripts/asm.py, programs/*.s

El ensamblador traduce un programa en assembly (.s) a código máquina (.hex), que después se carga en la placa con "file X.hex" en du.ps1. Cubre el requisito R6 de la consigna.

Uso: python3 scripts/asm.py programs/pipeline.s (genera programs/pipeline.hex). Se le puede pasar un segundo argumento con el nombre de salida.


## 1. Propio o toolchain existente

Opciones: usar el ensamblador de GNU (riscv64-unknown-elf-as) y extraer las palabras del binario, o escribir uno propio.

Elección: propio.

Por qué: son solo 32 instrucciones y 6 formatos. Con el toolchain habría que instalarlo, sacar las palabras del ELF con objcopy y además resolver HALT, que no existe en RV32I. Uno propio sale en un archivo, entiende halt y da errores pensados para este procesador (por ejemplo, rechaza mul o blt, que el hardware no tiene).


## 2. Lenguaje

Opciones: PowerShell, igual que du.ps1, o Python.

Elección: Python.

Por qué: separar texto, usar diccionarios y hacer operaciones de bits es más simple y se lee mejor. Corre igual en Windows y en Linux.


## 3. Formato de salida

Elección: el mismo .hex que ya se usaba: una palabra en hex por línea y un comentario con la dirección y la instrucción original.

Por qué: du.ps1 ya lo lee con "file X.hex", así que no hubo que tocar la consola ni el protocolo UART. El comentario permite ver qué instrucción es cada palabra sin desensamblar.

Por qué no cargar el .s directo desde du.ps1: harían falta dos lenguajes en el mismo comando. Con el .hex de por medio cada herramienta hace una sola cosa, y el .hex sirve también para tb/tb_cpu.v.


## 4. Dos pasadas

Primera pasada: recorre las líneas con un contador pc que arranca en 0 y suma 4 por instrucción, y anota la dirección de cada etiqueta.

Segunda pasada: codifica cada instrucción.

Por qué: un salto puede ir a una etiqueta que todavía no apareció (jal x1, func con func más abajo). En la primera pasada no se puede saber su dirección.


## 5. Tabla de instrucciones

Elección: un diccionario con formato, opcode, funct3 y funct7 por instrucción, y un if por formato que arma la palabra con desplazamientos (<<) y máscaras (&).

Por qué: se lee como la tabla de la consigna (sección 3). Agregar una instrucción es agregar una línea.

Además de los formatos de la spec (R, I, S, B, U, J) hay tres casos internos que cambian solo cómo se leen los operandos:
- SH: slli, srli, srai. Es formato I, pero el inmediato es shamt (0 a 31) y funct7 va arriba (srai lleva 0100000).
- L: loads y jalr. Es formato I, pero el operando se escribe imm(rs1).
- S: stores. También se escriben imm(rs1), pero el inmediato va partido en imm[11:5] e imm[4:0].


## 6. Saltos

En beq, bne y jal el inmediato no es la dirección de la etiqueta sino la distancia: offset = dirección de la etiqueta − pc de la instrucción. Coincide con lo que calcula EX (PC + imm).

También se acepta un número en lugar de la etiqueta, y se toma como offset directo.

En B y J el bit 0 no se codifica (siempre es 0), así que el offset tiene que ser par. Los bits se reparten como pide la spec, por ejemplo B: imm[12] | imm[10:5] | rs2 | rs1 | funct3 | imm[4:1] | imm[11] | opcode.


## 7. HALT y pseudoinstrucciones

halt se codifica como 0x00000000, la codificación que eligió el procesador (ver id.md).

Pseudoinstrucciones: nop (addi x0, x0, 0), mv rd, rs (addi rd, rs, 0), j etiqueta (jal x0, etiqueta) y ret (jalr x0, 0(x1)). Antes de codificar se traducen a la instrucción real.

Por qué solo esas: cada una es una línea y hacen el assembly más legible. li quedó afuera porque con valores grandes se convierte en dos instrucciones (lui + addi, con un ajuste de signo), y eso complica la primera pasada. Para cargar un valor grande se escriben lui y addi a mano, como en pipeline.s.


## 8. Sintaxis

- Comentarios con # o ;.
- Etiquetas con "nombre:", solas en la línea o antes de una instrucción.
- Registros solo como x0..x31.
- Inmediatos en decimal o hex, con signo: 5, -1, 0x678.

Por qué sin nombres ABI (ra, sp, a0...): el procesador y du.ps1 muestran los registros como xN. Usar el mismo nombre en todos lados evita traducir de cabeza al depurar.


## 9. Errores

Elección: el ensamblador se detiene en el primer error y dice la línea, el motivo y el texto de la línea. Por ejemplo: linea 12: etiqueta 'lop' no definida -> beq x1, x2, lop.

Qué controla: instrucción desconocida, cantidad de operandos, registro inválido, inmediato I y S en [−2048, 2047], shamt en [0, 31], inmediato de lui en 20 bits, offsets de salto pares y dentro del rango (±4 KiB en B, ±1 MiB en J), y etiquetas no definidas o repetidas.

Si no hay ningún halt, genera el .hex igual pero avisa. Sin halt el procesador frena igual al llegar a memoria vacía (0 = HALT, ver if.md), pero seguramente sea un olvido.


## 10. Pruebas

- programs/pipeline.s es pipeline.hex pasado a assembly. Al ensamblarlo salen las mismas 29 palabras que el pipeline.hex armado a mano, que ya se probó en la placa.
- programs/ejemplo.s y programs/grande.s son ejemplo.hex y grande.hex pasados a assembly. Al ensamblarlos salen las mismas palabras (5 y 201).
- programs/instrucciones.s usa las 32 instrucciones y las pseudoinstrucciones, con inmediatos negativos y beq, bne y jal hacia atrás. Se corrió en el pipeline (cpu.v con iverilog) y los 32 registros y la memoria dan lo mismo que el resultado esperado del archivo.
- Casos de error: inmediato fuera de rango, etiqueta no definida e instrucción que no está en el set (mul).


## Pendiente

Nada pendiente en el ensamblador.
