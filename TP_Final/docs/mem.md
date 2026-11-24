# Etapa MEM: decisiones de diseño

Archivos: src/mem.v

MEM es la única etapa que usa la memoria de datos. Recibe del latch EX/MEM la dirección (alu_result), el dato a guardar (store_data), el tamaño (funct3) y las señales mem_read y mem_write. En un store escribe 1, 2 o 4 bytes; en un load lee 1, 2 o 4 bytes y los extiende a 32 bits. Si mem_read y mem_write están en 0 no toca la memoria y la instrucción pasa de largo hacia MEM/WB.


## 1. Tipo de memoria

Opciones: memoria inferida (un array en Verilog) o el IP Block Memory Generator de Vivado, que usa Block RAM.

Elección: memoria inferida, con lectura asincrónica y escritura en el flanco de subida habilitada con en.

Por qué: es igual a instr_mem.v, el dato leído está disponible en el mismo ciclo y el pipeline de 5 etapas funciona sin cambios. Se simula con iverilog sin nada extra. La Block RAM tiene lectura sincrónica (el dato sale un ciclo después), lo que obliga a darle la dirección antes del latch EX/MEM o a reacomodar el pipeline, y no se puede borrar entera en un ciclo.

Si más adelante se pasa a Block RAM, el cambio queda dentro de mem.v: los puertos (dirección, dato, funct3, load_data) son los mismos y el resto del pipeline no se toca.


## 2. Organización

Opciones: array de bytes o array de palabras de 32 bits con máscara de bytes (byte enables).

Elección: array de bytes, reg [7:0] mem [0:DEPTH-1].

Por qué: sb, sh y sw escriben directamente 1, 2 o 4 posiciones, y los loads se arman concatenando bytes. Con palabras habría que armar máscaras y desplazar el dato según los 2 bits bajos de la dirección, que es más difícil de leer.


## 3. Tamaño

Opciones: 256 bytes, 1 KB o 4 KB o más.

Elección: 256 bytes en la placa (DMEM_ADDR_W = 8 en top.v). El módulo tiene ADDR_W = 10 (1 KB) por defecto, que se usa en simulación.

Por qué: la primera elección fue 1 KB, pero no entró en la xc7a35t. Como rst borra la memoria entera, se implementa con flip flops y no con RAM distribuida, y cada lectura asincrónica (4 bytes para los loads y 4 para el puerto de debug) es un multiplexor de todas las posiciones. Con 1 KB esos multiplexores ocupan más LUTs de las que tiene la FPGA. Con 256 bytes el diseño completo usa alrededor del 50 % de las LUTs y alcanza para los programas de prueba del TP. Se cambia con un solo número.

Se usan solo los bits bajos de la dirección (addr[ADDR_W-1:0]), así que una dirección fuera de rango da la vuelta. Las direcciones de los 4 bytes (a0 a a3) se declaran de ADDR_W bits por la misma razón.


## 4. Orden de los bytes

Little endian, como RISC V: el byte menos significativo va en la dirección más baja.

Un sw de 0x12345680 en la dirección 24 deja 80 en 24, 56 en 25, 34 en 26 y 12 en 27. Al leer se concatena al revés, de la dirección más alta a la más baja: {mem[a3], mem[a2], mem[a1], mem[a0]}.


## 5. Accesos desalineados

Opciones: ignorarlos o detectarlos y marcar un error.

Elección: ignorarlos. Un lw en la dirección 25 lee los bytes 25 a 28.

Por qué: el TP no tiene excepciones, así que no habría a quién avisar. Se asume que los programas usan accesos alineados.


## 6. Extensión de signo

Opciones: hacerla dentro de mem.v o en WB.

Elección: dentro de mem.v. load_data sale con el valor final de 32 bits.

Por qué: el latch MEM/WB guarda un dato ya listo, el forwarding desde MEM/WB lo usa directo y WB queda como un mux simple. Hacerla en WB obligaría a llevar funct3 y los bits bajos de la dirección hasta WB.

Se hace en un solo always con case sobre funct3, que arma los bytes y extiende a la vez:

lb repite 24 veces el bit 7 del byte. lh repite 16 veces el bit 7 del byte alto (el bit 15 del half). lw pasa tal cual. lbu y lhu rellenan con ceros. El default da 0 para que no se infiera latch.

Ejemplo: el byte 0x80 da 0xFFFFFF80 (menos 128) con lb y 0x00000080 (128) con lbu.

mem_read no se usa en esta lógica: la lectura es combinacional y si la instrucción no es un load, WB no elige este dato.


## 7. Valores de funct3

Loads y stores usan los mismos códigos para el mismo tamaño: 000 byte, 001 half, 010 word. 100 y 101 son lbu y lhu. Lo que distingue un load de un store es el opcode, que en MEM ya llega resuelto como mem_read o mem_write.

Se declaran constantes separadas (F3_LB, F3_SB, etc.) aunque valgan lo mismo, para que cada sección se lea según lo que hace.


## 8. Reset

Opciones: borrar la memoria con rst o no borrarla.

Elección: borrarla. Un for pone todos los bytes en 0, igual que reg_file con los registros.

Por qué: cada programa arranca con la memoria en un estado conocido. Responde la pregunta P1 de la consigna: al reprogramar, la memoria de datos se vacía.

Costo: borrar todo en un ciclo obliga a implementar la memoria con flip flops en lugar de RAM distribuida. Es la razón por la que la memoria quedó en 256 bytes (ver sección 3).


## 9. Memoria usada

La consigna pide mandar por la Debug Unit solo la memoria de datos usada.

Opciones: guardar la dirección más alta escrita, mandar siempre una ventana fija, o un bit de usado por palabra.

Elección: la dirección más alta escrita, en la salida max_addr. Se actualiza en cada store con el último byte escrito (a0 en sb, a1 en sh, a3 en sw) si es mayor que el valor guardado, y se pone en 0 con rst.

Por qué: es un registro y una comparación. La ventana fija no es en rigor la memoria usada, y el bit por palabra obliga a un dump de largo variable con direcciones, que complica la Debug Unit y el programa de la PC. Si hace falta se puede cambiar más adelante.

Caso borde: con 256 bytes, un sw en 254 escribe 254, 255, 0 y 1. Como a3 da la vuelta y vale 1, max_addr no registra el 255. Solo pasa si se escribe justo al final de la memoria.


## 10. Puerto de debug

dbg_addr es un índice de palabra, no de byte. La palabra k está en los bytes 4k a 4k+3, y la dirección 4k se arma pegando dos ceros a la derecha: {dbg_addr, 2'b00}. Los otros tres bytes se arman con 01, 10 y 11. dbg_data se concatena igual que un lw.

Es lectura asincrónica, igual que los puertos de debug de reg_file e instr_mem.


## 11. Qué señales declara MEM

Igual que en EX, mem.v declara solo lo que usa. rd, pc4, reg_write, wb_sel y halt van directo del latch EX/MEM al latch MEM/WB en el módulo que conecta todo.


## 12. Pruebas

tb/tb_mem.v, autoverificante: sw, sh y sb (sb modifica un solo byte), los 5 loads con y sin signo, max_addr (sube con los stores y no baja con uno más bajo), el puerto de debug, que con en = 0 no se escriba, la vuelta de las direcciones al pasar el final de la memoria (con 1 KB) y que rst borre la memoria y max_addr.


## Pendiente

Nada pendiente en MEM. El latch MEM/WB está en wb.md, y la conexión de max_addr y del puerto de debug al dump en debug_unit.md.
