# Debug Unit: decisiones de diseño

Archivos: src/debug_unit.v, src/top.v, src/br_generator.v, src/rx_uart.v, src/tx_uart.v, tb/tb_debug_unit.v, tb/tb_top.v, scripts/du.ps1, scripts/smoke_test.ps1

La Debug Unit es el puente entre la PC y el procesador. Recibe comandos por UART, carga el programa en la memoria de programa, controla la ejecución (continuo o paso a paso) y devuelve el estado: PC, latches, los 32 registros y la memoria de datos usada.


## 1. UART

Elección: los módulos del TP2 (br_generator, rx_uart, tx_uart), a 38400 baudios, 8N1.

Por qué: ya estaban probados en la placa. El divisor del baud rate se recalculó para el clock de 80 MHz: BR_DIV = 80 MHz / (16 * 38400) = 130.

tx_uart solo mira i_tx_start en un ciclo con tick de baud rate, así que tx_start se genera combinacional junto con br_tick (estado ST_TX_BR).


## 2. Formato de los comandos

Opciones: comandos de texto con fin de línea, tramas con encabezado, largo y checksum, o un byte de comando seguido de sus argumentos.

Elección: un byte de comando en ASCII y después sus argumentos en binario. Los números de más de un byte van en little endian.

Por qué: es lo más simple de decodificar en una FSM y de mandar desde la PC. Usar letras (L, S, R) hace que los comandos se lean en un volcado de la UART. No se usa checksum: el enlace es un cable USB corto y, si una carga sale mal, se puede verificar con el comando P y repetir.


## 3. Comandos

| Comando | Argumentos | Qué hace | Respuesta |
|---|---|---|---|
| L (0x4C) | N (2 bytes) y N palabras de 4 bytes | Carga N instrucciones desde la dirección 0 y resetea el procesador | K |
| S (0x53) | - | Ejecuta un ciclo de clock | dump |
| R (0x52) | - | Ejecuta hasta HALT | dump |
| D (0x44) | - | No ejecuta nada | dump |
| X (0x58) | - | Resetea el procesador | K |
| P (0x50) | N (2 bytes) | Lee las primeras N palabras de la memoria de programa | 4N bytes (K si N = 0) |
| otro | - | - | ? |

K (0x4B) es el ACK y ? (0x3F) el NAK. P sirve para verificar que lo cargado llegó bien.


## 4. Carga del programa y reprogramación

Elección: el comando L escribe la memoria de programa por un puerto de debug (ver if.md, sección 3). La FSM arma cada palabra con 4 bytes y la escribe en un ciclo (ST_LOAD_WR). Durante la carga el procesador está frenado (cpu_en = 0). Al terminar pulsa cpu_rst y responde K.

Por qué: así se programa y reprograma por UART sin resintetizar (R4 y R5). El reset al final deja el PC en 0 y el pipeline vacío, listo para arrancar.

Qué se borra al reprogramar (preguntas P1 a P4):
- Memoria de datos: sí, cpu_rst la pone en 0 (ver mem.md, sección 8).
- Registros: sí, cpu_rst los pone en 0 (ver id.md, sección 3).
- Pipeline: sí, cpu_rst carga burbujas en los latches, el PC vuelve a 0 y el HALT anterior se olvida (fetch_stopped y halted vuelven a 0).
- Memoria de programa: no se borra. Se sobrescriben las N primeras palabras; las de más arriba quedan del programa anterior. No hace falta borrarla porque el programa nuevo termina con su HALT y nunca llega a esas direcciones. du.ps1 agrega un HALT al final si el archivo no lo tiene.

Por qué borrar datos y registros: cada programa arranca de un estado conocido y el resultado no depende de lo que corrió antes.


## 5. Paso a paso sin tocar el clock

Elección: el procesador tiene una habilitación cpu_en que va a todos sus registros. En el comando S la FSM pasa por el estado ST_STEP, que dura exactamente un ciclo, y cpu_en vale 1 solo en ese ciclo. Después manda el dump.

Por qué: la consigna prohíbe intervenir el clock (R12). Todo el sistema usa un solo clock y el procesador avanza o no según cpu_en (ver if.md, sección 6).


## 6. Modo continuo

Elección: en el comando R la FSM queda en ST_RUN con cpu_en = 1 hasta que cpu_halted vale 1, y ahí manda el dump.

cpu_en también se corta cuando cpu_halted vale 1, así que pasos o corridas después del HALT no cambian nada.

Programa sin HALT (pregunta P5): si el PC llega a una zona vacía de la memoria de programa lee 0, que es HALT, y frena solo (ver if.md, sección 4). Pero si el programa queda en un loop infinito, R no termina nunca: la FSM no lee la UART mientras está en ST_RUN, así que la única salida es el botón de reset de la placa. En modo paso a paso no hay problema, porque cada S es un solo ciclo.


## 7. Dump

Formato: 1 byte de estado (bit 0 = halted) y después palabras de 32 bits en little endian:

| Palabra | Contenido |
|---|---|
| 0 | PC (etapa IF) |
| 1 | M: cantidad de palabras de memoria de datos que vienen al final |
| 2 a 21 | 20 palabras de latches y señales de riesgo (tabla de abajo) |
| 22 a 53 | x0 a x31 |
| 54 a 54 + M - 1 | memoria de datos usada, palabras 0 a M - 1 |

Elección: la Debug Unit no sabe qué es cada palabra. Pide la palabra dump_idx y el top elige el dato con un multiplexor (PC, latches, registros o memoria).

Por qué: para agregar algo al dump solo se cambia el multiplexor del top y el programa de la PC; la FSM de la Debug Unit no se toca. Un dump es de tamaño fijo salvo la memoria, así que la PC sabe cuánto leer: primero las 54 palabras fijas y después M palabras.

Latches: de cada latch se manda pc4, los datos y las señales de control empaquetadas en una palabra. pc4 identifica la instrucción (es la de la dirección pc4 - 4), y pc4 = 0 indica una burbuja. El multiplexor está al final de cpu.v (entrada dbg_latch_sel).

| Latch | Contenido | Latch | Contenido |
|---|---|---|---|
| 0 | IF: instrucción leída | 10 | EX/MEM control |
| 1 | IF/ID instrucción | 11 | MEM/WB pc4 |
| 2 | IF/ID pc4 | 12 | MEM/WB alu_result |
| 3 | ID/EX pc4 | 13 | MEM/WB load_data |
| 4 | ID/EX rs1_data | 14 | MEM/WB control |
| 5 | ID/EX rs2_data | 15 | Riesgos |
| 6 | ID/EX imm | 16 | EX: resultado de la ALU |
| 7 | ID/EX control | 17 | EX: destino del salto |
| 8 | EX/MEM pc4 | 18 | WB: dato a escribir en rd |
| 9 | EX/MEM alu_result | 19 | EX/MEM store_data |

El latch k es la palabra k + 2 del dump.

Bits de las palabras de control:
- ID/EX: [31:27] rd, [26:22] rs1, [21:17] rs2, [16:14] funct3, [13] funct7[5], [12] reg_write, [11] alu_src, [10:9] alu_op, [8] mem_read, [7] mem_write, [6:5] wb_sel, [4] branch, [3] jump, [2] jalr, [1] halt.
- EX/MEM y MEM/WB: [31:27] rd, [26:24] funct3, [23] reg_write, [22] mem_read, [21] mem_write, [20:19] wb_sel, [18] halt. En MEM/WB funct3, mem_read y mem_write van en 0 porque ese latch no los guarda.
- Riesgos (lo que va a pasar en el próximo flanco): [0] stall, [1] flush_if_id, [2] flush_id_ex, [3] redirect, [4] fetch_stop, [6:5] fwd_a, [8:7] fwd_b, [9] halted.


## 8. Memoria de datos usada

Elección: desde la dirección 0 hasta la palabra que contiene el byte escrito más alto (max_addr de mem.v, ver mem.md, sección 9). Siempre se manda al menos la palabra 0.

Por qué: es un registro y una comparación, y el dump queda como una lista de palabras sin direcciones. Los programas de prueba usan la memoria desde la dirección 0, así que lo que se manda es casi exactamente lo usado.


## 9. Pruebas

tb/tb_top.v prueba el sistema completo por UART: carga (L), dump (D), paso a paso (S), continuo (R), reprogramación (que borra los registros), comando inválido (?) y lectura de la memoria de programa (P). Usa la primitiva MMCM de clk_gen.v, así que se simula en Vivado con la librería unisims, no con iverilog.

tb/tb_debug_unit.v prueba solo la FSM, sin UART, y corre con iverilog: maneja rx_data y rx_done directo y simula el tx_uart. Chequea cada comando, que S habilite el procesador exactamente 1 ciclo, que R lo habilite hasta halted y que después del HALT un S no ejecute nada.

En la placa, scripts/smoke_test.ps1 hace la misma secuencia con el programa de programs/ejemplo.s y chequea los resultados.


## Pendiente

1. Una forma de cortar el modo continuo sin el botón (un comando de stop o un límite de ciclos), para el caso de un loop infinito.
2. Poder correr tb/tb_top.v con iverilog (un clk_gen de simulación sin MMCM).
