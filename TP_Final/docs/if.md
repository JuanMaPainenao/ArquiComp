# Etapa IF: decisiones de diseño

Archivos: src/pc_unit.v, src/instr_mem.v, src/if_id.v

IF busca la instrucción que está en la dirección del PC y calcula PC + 4. En cada ciclo habilitado el PC pasa a la instrucción siguiente, o al destino de un salto si EX lo pide. La instrucción, el PC y PC + 4 se guardan en el latch IF/ID.


## 1. Memoria de programa

Opciones: memoria inferida con lectura asincrónica o Block RAM (IP Block Memory Generator).

Elección: inferida, con lectura asincrónica. Vivado la implementa como RAM distribuida.

Por qué: la instrucción sale en el mismo ciclo en que entra el PC, como en el pipeline del libro. La Block RAM tiene lectura sincrónica y obliga a direccionarla con el próximo PC, con cuidado especial en stalls y saltos.


## 2. Tamaño

Elección: 256 instrucciones (ADDR_W = 8, 1 KB).

Por qué: sobra para los programas del TP y en RAM distribuida ocupa poco. Se cambia con un parámetro.

El PC es una dirección en bytes y las instrucciones están alineadas a 4, así que el índice de palabra es pc[ADDR_W+1:2].


## 3. Carga del programa sin resintetizar

Opciones: inicializar la memoria con un archivo al sintetizar, o escribirla en tiempo de ejecución.

Elección: un segundo puerto de debug, con escritura sincrónica, que maneja la Debug Unit (comando L). También tiene lectura (comando P) para verificar lo cargado.

Por qué: la consigna pide programar y reprogramar el procesador por UART sin resintetizar (R4 y R5). El puerto de debug usa índice de palabra porque la Debug Unit carga de a una instrucción.


## 4. Contenido inicial y direcciones fuera de rango

Elección: la memoria arranca en 0, y si el PC se sale del rango se lee 0 en lugar de dar la vuelta.

Por qué: 0x00000000 se decodifica como HALT. Si el programa no tiene HALT o el PC llega a una zona vacía, el procesador se detiene solo en vez de ejecutar basura o volver al principio.


## 5. Prioridad del próximo PC

Orden en pc_unit: rst, después en = 0 (se mantiene), después salto tomado (redirect), después stall o halt (se mantiene) y por último PC + 4.

Por qué redirect le gana a halt y a stall: si EX toma un salto, las instrucciones que están detrás son del camino equivocado. Un HALT o un stall en ese camino no tienen que frenar el PC, porque se van a descartar.


## 6. Pausa sin tocar el clock

Opciones: compuerta sobre el clock o una señal de habilitación.

Elección: habilitación en, que maneja la Debug Unit. Paso a paso es en = 1 durante un solo ciclo.

Por qué: la consigna prohíbe intervenir el clock (R12). Compuertear el clock además genera skew. Todos los registros del pipeline usan el mismo en.


## 7. PC + 4

Elección: pc_unit calcula PC + 4 y viaja por todos los latches como pc4.

Por qué: jal y jalr escriben PC + 4 en rd en WB, así que hay que llevarlo hasta ahí. Sirve también para el dump: una burbuja deja pc4 = 0, así que la PC puede saber qué instrucción hay en cada latch (la de pc4 menos 4) o si está vacío.


## 8. Latch IF/ID

rst o flush cargan un NOP (addi x0, x0, 0 = 0x00000013), no un 0.

Por qué: el 0 es HALT. Si una burbuja fuera 0, cada salto tomado o cada reset detendría el procesador.

Con stall el latch se mantiene (load use), y el stall le gana al flush para no perder la instrucción frenada. Con en = 0 también se mantiene.


## 9. Saltos y HALT

No hay predicción: IF siempre busca PC + 4 y, si EX toma un salto, se hace flush de IF/ID e ID/EX (ver ex.md).

Cuando ID ve un HALT, la hazard unit activa fetch_stop: el PC queda fijo e IF/ID recibe NOPs hasta el próximo reset, mientras el HALT avanza hasta WB (ver id.md). Así el pipeline queda vacío al terminar (R10).


## 10. Pruebas

tb/tb_cpu.v corre programs/pipeline.hex en el pipeline completo, cargándolo por el puerto de debug de la memoria de programa. tb/tb_top.v prueba la carga (L), la lectura (P) y la reprogramación por UART.
