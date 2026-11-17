# Trabajo Final 2026 — Pipeline de procesador RISC-V

> **Fuente:** `TRABAJO FINAL 2026.pdf` (cátedra Arquitectura de Computadoras, FCEFyN-UNC, 20 slides).
> Este documento transcribe la consigna y la ordena para usarla como contexto de desarrollo.
> Todo lo que **no** sale de las slides está marcado con **[nota]** (aclaraciones, referencia de la spec RV32I, interpretaciones).

---

## 1. Resumen

Hay que construir tres cosas:

1. **Procesador RISC-V segmentado (pipeline de 5 etapas)** en HDL, sintetizado en FPGA.
2. **Debug Unit** en la FPGA que se comunica con la PC por **UART**: carga el programa, controla la ejecución y devuelve el estado interno.
3. **Interfaz en la PC** (CLI, TUI y/o GUI) para cargar programas, controlar la ejecución y ver los datos.

Además: un **ensamblador** (asm → código máquina) y un **informe** que documente las decisiones de diseño y responda las preguntas de la sección 9.

---

## 2. Requisitos obligatorios

| ID | Requisito |
|----|-----------|
| R1 | Implementar el pipeline del procesador RISC-V con las etapas IF, ID, EX, MEM y WB. |
| R2 | Implementar las **32 instrucciones** de la sección 3. |
| R3 | Implementar una Debug Unit que envíe y reciba información del procesador por **UART**. |
| R4 | El procesador se **programa y reprograma** con comandos UART, **sin resintetizar** (la memoria de programa se escribe en runtime). |
| R5 | La reprogramación tiene que poder hacerse **de forma dinámica**. |
| R6 | El programa se escribe en **ensamblador** y tiene que existir un mecanismo que lo traduzca a código máquina para enviarlo al procesador. |
| R7 | El programa tiene que terminar con una instrucción **HALT** (o de stop). |
| R8 | **Modo continuo:** un comando UART arranca la ejecución hasta el final del programa; ahí se muestran todos los valores. |
| R9 | **Modo paso a paso:** cada comando UART ejecuta **un ciclo de clock**; se muestran los valores en cada paso. |
| R10 | En ambos modos el **pipeline tiene que quedar vacío** cuando termina la ejecución. |
| R11 | La Debug Unit envía a la PC: **los 32 registros**, **los latches intermedios** (registros de pipeline) y **la memoria de datos usada**. |
| R12 | **El clock no se puede intervenir** en ninguna parte del proyecto. |
| R13 | Interfaz para ver los datos e interactuar con la Debug Unit (CLI/GUI/TUI). La cátedra pide **creatividad** en cómo se muestran y se manipulan los datos. |
| R14 | **Documentar cada decisión de diseño y su porqué.** |
| R15 | En la integración: análisis de camino crítico, skew y frecuencia de operación con herramientas de Vivado (sección 8). |

---

## 3. Set de instrucciones (32 instrucciones, RV32I)

### 3.1 Lista pedida por la consigna

| Formato | Instrucciones | Cant. |
|---------|---------------|------:|
| R (registro-registro) | `add, sub, sll, srl, sra, and, or, xor, slt, sltu` | 10 |
| I (cargas) | `lb, lh, lw, lbu, lhu` | 5 |
| I (aritmético-lógicas con inmediato) | `addi, andi, ori, xori, slti, sltiu, slli, srli, srai` | 9 |
| I (salto indirecto) | `jalr` | 1 |
| S (almacenamiento) | `sb, sh, sw` | 3 |
| B (salto condicional) | `beq, bne` | 2 |
| U (inmediato superior) | `lui` | 1 |
| J (salto incondicional) | `jal` | 1 |
| **Total** | | **32** |

**Fuera de alcance** (no están en la lista): `auipc`, `blt`, `bge`, `bltu`, `bgeu`, `ecall`, `ebreak`, `fence`, CSRs, extensiones M/A/F/D/C.

### 3.2 Codificación — [nota] referencia de la spec RV32I

Las slides solo muestran ejemplos sueltos (`add`, `sub`, `addi`, `sb`, `jal`, `beq`, `lui`); esta tabla completa sale de la especificación RISC-V.

| Instr. | Fmt | opcode | funct3 | funct7 / imm[11:5] | Semántica |
|--------|-----|--------|--------|--------------------|-----------|
| `add`  | R | 0110011 | 000 | 0000000 | rd = rs1 + rs2 |
| `sub`  | R | 0110011 | 000 | 0100000 | rd = rs1 − rs2 |
| `sll`  | R | 0110011 | 001 | 0000000 | rd = rs1 << rs2[4:0] |
| `slt`  | R | 0110011 | 010 | 0000000 | rd = (rs1 <ₛ rs2) |
| `sltu` | R | 0110011 | 011 | 0000000 | rd = (rs1 <ᵤ rs2) |
| `xor`  | R | 0110011 | 100 | 0000000 | rd = rs1 ^ rs2 |
| `srl`  | R | 0110011 | 101 | 0000000 | rd = rs1 >>ₗ rs2[4:0] |
| `sra`  | R | 0110011 | 101 | 0100000 | rd = rs1 >>ₐ rs2[4:0] |
| `or`   | R | 0110011 | 110 | 0000000 | rd = rs1 \| rs2 |
| `and`  | R | 0110011 | 111 | 0000000 | rd = rs1 & rs2 |
| `addi` | I | 0010011 | 000 | — | rd = rs1 + imm |
| `slti` | I | 0010011 | 010 | — | rd = (rs1 <ₛ imm) |
| `sltiu`| I | 0010011 | 011 | — | rd = (rs1 <ᵤ imm) |
| `xori` | I | 0010011 | 100 | — | rd = rs1 ^ imm |
| `ori`  | I | 0010011 | 110 | — | rd = rs1 \| imm |
| `andi` | I | 0010011 | 111 | — | rd = rs1 & imm |
| `slli` | I | 0010011 | 001 | 0000000 | rd = rs1 << shamt |
| `srli` | I | 0010011 | 101 | 0000000 | rd = rs1 >>ₗ shamt |
| `srai` | I | 0010011 | 101 | 0100000 | rd = rs1 >>ₐ shamt |
| `lb`   | I | 0000011 | 000 | — | rd = sext(M[rs1+imm][7:0]) |
| `lh`   | I | 0000011 | 001 | — | rd = sext(M[rs1+imm][15:0]) |
| `lw`   | I | 0000011 | 010 | — | rd = M[rs1+imm][31:0] |
| `lbu`  | I | 0000011 | 100 | — | rd = zext(M[rs1+imm][7:0]) |
| `lhu`  | I | 0000011 | 101 | — | rd = zext(M[rs1+imm][15:0]) |
| `jalr` | I | 1100111 | 000 | — | rd = PC+4; PC = (rs1+imm) & ~1 |
| `sb`   | S | 0100011 | 000 | — | M[rs1+imm][7:0] = rs2[7:0] |
| `sh`   | S | 0100011 | 001 | — | M[rs1+imm][15:0] = rs2[15:0] |
| `sw`   | S | 0100011 | 010 | — | M[rs1+imm][31:0] = rs2 |
| `beq`  | B | 1100011 | 000 | — | if (rs1 == rs2) PC = PC + imm |
| `bne`  | B | 1100011 | 001 | — | if (rs1 != rs2) PC = PC + imm |
| `lui`  | U | 0110111 | — | — | rd = imm[31:12] << 12 |
| `jal`  | J | 1101111 | — | — | rd = PC+4; PC = PC + imm |

`shamt` = inst[24:20]. `x0` vale siempre 0 (las escrituras a `x0` se descartan).

### 3.3 Campos e inmediatos — [nota] spec RV32I

Campos base (formato R): `funct7[31:25] | rs2[24:20] | rs1[19:15] | funct3[14:12] | rd[11:7] | opcode[6:0]`

| Fmt | Armado del inmediato (todos con extensión de signo desde inst[31]) |
|-----|------------------------------------------------------------------|
| I | imm[11:0] = inst[31:20] |
| S | imm[11:5] = inst[31:25], imm[4:0] = inst[11:7] |
| B | imm[12] = inst[31], imm[10:5] = inst[30:25], imm[4:1] = inst[11:8], imm[11] = inst[7], imm[0] = 0 |
| U | imm[31:12] = inst[31:12], imm[11:0] = 0 |
| J | imm[20] = inst[31], imm[10:1] = inst[30:21], imm[11] = inst[20], imm[19:12] = inst[19:12], imm[0] = 0 |

---

## 4. Pipeline

### 4.1 Etapas (según la consigna)

| Etapa | Función |
|-------|---------|
| **IF** (Instruction Fetch) | Busca la instrucción en la memoria de programa. |
| **ID** (Instruction Decode) | Decodifica la instrucción y lee registros. |
| **EX** (Execute) | Ejecuta la operación. |
| **MEM** (Memory Access) | Lee o escribe la memoria de datos. |
| **WB** (Write Back) | Escribe el resultado en el banco de registros. |

Registros de pipeline: **IF/ID, ID/EX, EX/MEM, MEM/WB** (son los "latches intermedios" que hay que mandar por UART).

### 4.2 Riesgos (hazards) que plantea el marco teórico

- **Estructurales:** dos instrucciones usan el mismo recurso en el mismo ciclo.
- **De datos:** se usa un dato antes de que esté listo; hay que mantener el orden estricto de lecturas y escrituras.
- **De control:** se toma una decisión sobre una condición que todavía no se evaluó.

[nota] La consigna no nombra explícitamente unidad de forwarding ni de detección de riesgos, pero para que el pipeline ejecute bien las 32 instrucciones hace falta resolver: dependencias RAW (forwarding y/o stall), el caso load-use (stall obligatorio de al menos 1 ciclo aunque haya forwarding) y los saltos `beq/bne/jal/jalr` (flush de las instrucciones buscadas de más).

---

## 5. Debug Unit

Envía a la PC por UART:

1. El contenido de los **32 registros** (32 × 32 bits = 128 bytes de payload).
2. El contenido de los **latches intermedios** (registros de pipeline IF/ID, ID/EX, EX/MEM, MEM/WB).
3. El contenido de la **memoria de datos usada** (solo la porción usada, no la memoria entera).

También recibe los comandos de la PC: carga de programa, arranque en modo continuo y paso de un ciclo.

---

## 6. Carga de programa

**El programa debe:**
- Estar escrito en **ensamblador**.
- Contar con un mecanismo que traduzca las instrucciones a código máquina para enviarlas al procesador.
- Tener una instrucción **HALT** o de stop.

**El sistema debe:**
- Permitir programar el procesador desde el software escribiendo la **memoria de programa**.
- Permitir reprogramarlo **dinámicamente**.

> **Importante:** la carga tiene que hacerse por **UART** y **sin resintetizar** el procesador.

---

## 7. Modos de operación

| Modo | Comportamiento |
|------|----------------|
| **Continuo** | Un comando por UART arranca la ejecución hasta el final del programa. Ahí se muestran en pantalla todos los valores pedidos. |
| **Paso a paso** | Cada comando por UART ejecuta **un ciclo de clock**. Se muestran los valores pedidos en cada paso. |

En ambos casos el **pipeline tiene que quedar vacío** al terminar la ejecución.

---

## 8. Clock y timing

En la integración, analizar:
- ¿Cuál es el **camino crítico** del sistema?
- ¿Ese camino crítico genera **skew**? ¿Qué consecuencias tiene?

Si hay skew:
1. Encontrar la **frecuencia óptima** de funcionamiento.
2. Generar **métricas** con las herramientas de Vivado (reportes de timing).
3. **Aplicar** esa frecuencia al sistema.

Tip de la cátedra: investigar los IP cores de Vivado para las **memorias** (Block Memory Generator) y el **Clocking Wizard**.

---

## 9. Preguntas que el informe tiene que responder

| # | Pregunta | Sección |
|---|----------|---------|
| P1 | Al reprogramar, ¿hay que vaciar la **memoria de datos**? | Carga de programa |
| P2 | ¿Y los **registros**? | Carga de programa |
| P3 | ¿Hay que vaciar el **pipeline**? | Carga de programa |
| P4 | ¿Y la **memoria de programa**? | Carga de programa |
| P5 | ¿Qué pasa si en la memoria **no hay una instrucción de parada**? | Modos de operación |
| P6 | ¿Cuál es el **camino crítico** del sistema? | Clock |
| P7 | ¿Genera **skew**? ¿Con qué consecuencias? | Clock |
| P8 | (Si hay skew) ¿Cuál es la **frecuencia óptima**? Métricas de Vivado + aplicación. | Clock |

---

## 10. Decisiones abiertas (a definir y documentar — R14)

La consigna deja esto a criterio del grupo. Cada una tiene que quedar justificada en el informe:

- **Codificación de HALT:** qué patrón de 32 bits se usa y cómo lo detecta el pipeline.
- **Drenado del pipeline con HALT:** en qué etapa se detecta, cómo se frena el fetch y cuándo se considera "pipeline vacío" (R10).
- **Protocolo UART de comandos:** opcodes de comando, framing, orden y formato de la trama de debug, confirmaciones (ACK).
- **Memorias:** tamaño de la memoria de programa y de datos, IP core vs. memoria inferida, cómo se escribe la memoria de programa en runtime.
- **"Memoria de datos usada":** cómo se determina qué rango mandar.
- **Paso a paso sin tocar el clock (R12):** mecanismo de habilitación/stall del procesador.
- **Resolución de saltos:** en qué etapa se resuelven (ID vs. EX) y cuántos ciclos de penalidad cuestan.
- **Forwarding y detección de riesgos:** qué caminos de forwarding hay y cuándo se hace stall.
- **Accesos desalineados** en `lh/lhu/lw/sh/sw`: qué hace el hardware.
- **Ensamblador:** propio o basado en un toolchain existente; formato de salida.
- **Interfaz:** CLI, TUI o GUI, lenguaje, y cómo se muestra el estado (diffs entre pasos, resaltado, etc.).
- **Frecuencia final** de operación (sección 8).

---

## 11. Erratas y aclaraciones de las slides — [nota]

- **"Riegos"** → riesgos (hazards).
- **"Latches intermedios"** = registros de pipeline (IF/ID, ID/EX, EX/MEM, MEM/WB). No tiene que ver con los latches de Verilog inferidos por un `case` incompleto.
- **Slide Tipo J:** dice que "la dirección a la que se salta es la almacenada en el registro rd". Según la spec es al revés: `rd` **guarda la dirección de retorno (PC+4)** y el destino es `PC + imm` (`jal`) o `(rs1 + imm) & ~1` (`jalr`).
- **Slide Tipo I:** el ejemplo usa `ld` (load doubleword, de RV64). No está en la lista pedida; como la lista tiene `lw/sw` y no `ld/sd`, el objetivo es **RV32I** (registros de 32 bits).
- **Slide `beq`:** el diagrama de codificación pone `rs1` dos veces; el campo inst[24:20] es `rs2`.
- **"El clock no debe verse intervenido" (R12):** interpretación: nada de clock gating ni clocks generados con lógica. Los modos continuo y paso a paso se hacen con señales de **enable/stall** sobre un clock único. El Clocking Wizard (MMCM/PLL) sí es la forma correcta de cambiar la frecuencia.

---

## 12. Contexto del entorno — [nota]

- Placa: **Digilent Basys 3** (Artix-7 `xc7a35tcpg236-1`), clock de **100 MHz**, toolchain **Vivado**.
- El TP final continúa el **TP2**: se pueden reutilizar los módulos UART 8N1 ya validados (`br_generator`, `rx_uart`, `tx_uart`, `interface_rx_uart`) y el esquema de prueba con pyserial.

---

## 13. Checklist de entregables

- [ ] RTL del pipeline de 5 etapas con las 32 instrucciones.
- [ ] Manejo de riesgos de datos y de control.
- [ ] Memoria de programa escribible por UART (sin resintetizar).
- [ ] Instrucción HALT definida, con drenado del pipeline.
- [ ] Debug Unit: comandos de carga, modo continuo y paso a paso.
- [ ] Debug Unit: envío de los 32 registros, registros de pipeline y memoria de datos usada.
- [ ] Ensamblador asm → código máquina.
- [ ] Interfaz PC (CLI/TUI/GUI).
- [ ] Testbenches por módulo y de integración.
- [ ] Reportes de timing en Vivado: camino crítico, skew, frecuencia óptima aplicada.
- [ ] Informe: decisiones de diseño justificadas + respuestas P1–P8.

---

## 14. Tips de la cátedra

1. No copien, inspírense.
2. Investiguen las herramientas de Vivado (IP cores para memorias, Clock Wizard).
3. Antes de escribir la primera línea:
   - Diseñen, dibujen y esquematicen.
   - Imaginen los módulos: cómo probarlos, cómo interactúan entre sí y qué herramientas ya usadas pueden aprovechar.
   - ¿Cómo voy a interactuar con mi sistema?
   - ¿Cómo puedo interpretar el estado actual del sistema mientras lo uso?

> "Todo lo que se les pide ya existe y ya se implementó 1000 veces. Asegúrense de que lo que hagan ustedes sea único."

---

## 15. Bibliografía

- **Instrucciones:** RISC-V ISA doc — https://msyksphinz-self.github.io/riscv-isadoc/
- **Pipeline:** Patterson & Hennessy, *Computer Organization and Design: The Hardware/Software Interface*, RISC-V Edition (cap. 4, "The Processor").
