# Riesgos y HALT: decisiones de diseño

Archivos: src/hazard_unit.v, src/forwarding_unit.v (y las entradas stall, flush y halt de src/pc_unit.v, src/if_id.v y src/id_ex.v)

Este documento junta en un solo lugar cómo el pipeline resuelve los riesgos y cómo termina un programa con HALT. El detalle de cada módulo está en el .md de su etapa (if.md, id.md, ex.md, wb.md).


## 1. Resumen

| Riesgo | Cuándo pasa | Cómo se resuelve | Ciclos perdidos |
|---|---|---|---|
| Estructural | Dos etapas usan el mismo recurso | No pasa (sección 2) | 0 |
| Datos | Una instrucción usa un registro que otra anterior todavía no escribió | Forwarding y bypass del banco | 0 |
| Datos, load use | La instrucción que sigue a un load usa el dato cargado | Stall de 1 ciclo y después forwarding | 1 |
| Control | Salto tomado (beq, bne, jal, jalr) | Flush de IF/ID e ID/EX | 2 |
| Control | Salto no tomado | Nada: IF ya buscó PC + 4 | 0 |


## 2. Riesgos estructurales

No hay. La memoria de programa y la de datos están separadas, así que IF y MEM pueden acceder en el mismo ciclo. El banco de registros tiene dos puertos de lectura (ID) y uno de escritura (WB), así que ID y WB tampoco chocan.


## 3. Riesgos de datos: forwarding

Opciones: frenar el pipeline en cada dependencia o adelantar el dato.

Elección: adelantar. Hay tres caminos, según cuántas instrucciones separan a la que escribe de la que lee:

1. Instrucción anterior (distancia 1): el dato está en EX/MEM y la forwarding unit lo adelanta a EX (selector 01).
2. Dos antes (distancia 2): el dato está en MEM/WB y se adelanta a EX (selector 10).
3. Tres antes (distancia 3): WB escribe el banco en el mismo ciclo en que ID lo lee. El bypass del banco devuelve el dato nuevo (ver id.md, sección 2).

Si las dos instrucciones anteriores escriben el mismo registro, gana EX/MEM porque es la más reciente. No se adelanta si rd es x0 o si la instrucción no escribe registro.

Por qué: sin forwarding harían falta hasta 2 ciclos de espera por dependencia. Con forwarding el único caso que espera es el load use.

Los dos operandos de EX pasan por el forwarding, así que también quedan cubiertos el dato de un store y la comparación de un salto.


## 4. Load use

Un load tiene el dato recién al final de MEM. Si la instrucción siguiente lo necesita en EX, no llega a tiempo ni con forwarding.

Detección (en la hazard unit): la instrucción en EX es un load (mem_read), su rd no es x0 y la instrucción en ID usa ese registro como rs1 o rs2 (según uses_rs1 y uses_rs2).

Qué se hace en ese ciclo:
- PC e IF/ID se mantienen (stall): la instrucción que espera sigue en ID.
- ID/EX recibe una burbuja (flush): el ciclo siguiente EX no hace nada.

Al ciclo siguiente el load ya está en WB y el dato se adelanta desde MEM/WB.

Un load seguido de un store que guarda el dato cargado (lw x6 y después sw x6) también frena un ciclo. Se podría evitar con un forwarding de WB a MEM, pero se eligió lo simple: una sola regla de stall.

uses_rs1 y uses_rs2 evitan stalls falsos en instrucciones donde los bits de rs1 o rs2 son parte del inmediato (lui, jal, el rs2 de las tipo I).


## 5. Riesgos de control: saltos

Los saltos se resuelven en EX y no hay predicción: IF siempre busca PC + 4 (ver ex.md, secciones 1 y 2).

Si EX toma el salto (redirect), las 2 instrucciones que entraron detrás son del camino equivocado:
- IF/ID recibe un NOP.
- ID/EX recibe una burbuja.
- El PC carga el destino del salto.

Costo: 2 ciclos por salto tomado. Un salto no tomado no pierde ciclos.


## 6. Prioridades

Puede pasar más de una cosa en el mismo ciclo. El orden es:

1. redirect le gana al stall: si hay un salto tomado, la instrucción frenada también es del camino equivocado y se descarta.
2. redirect le gana al HALT: un HALT que entró detrás de un salto tomado se descarta y no frena el fetch.
3. En IF/ID el stall le gana al flush del HALT, para no perder la instrucción frenada por un load use.

| Situación | PC | IF/ID | ID/EX |
|---|---|---|---|
| Normal | PC + 4 | avanza | avanza |
| Load use | se mantiene | se mantiene | burbuja |
| Salto tomado | destino | NOP | burbuja |
| HALT en ID o fetch frenado | se mantiene | NOP | avanza |
| en = 0 (Debug Unit) | se mantiene | se mantiene | se mantiene |


## 7. Burbujas

IF/ID usa como burbuja el NOP (addi x0, x0, 0 = 0x00000013) y no un 0, porque el 0 es HALT. ID/EX, EX/MEM y MEM/WB usan todo en 0: no escriben registros ni memoria, no saltan y no llevan halt.

En el dump una burbuja se reconoce porque su pc4 vale 0 (ver if.md, sección 7).


## 8. HALT

Codificación: 0x00000000 (opcode 0000000). También se acepta el opcode 1111111. La memoria vacía es 0, así que un programa sin HALT frena al llegar a una zona vacía (ver id.md, sección 9).

Drenado del pipeline (R10):
1. Cuando el HALT llega a ID, la hazard unit activa fetch_stop: el PC queda fijo e IF/ID recibe NOPs.
2. Un registro (fetch_stopped) mantiene el fetch frenado hasta el próximo reset, porque al ciclo siguiente el HALT ya pasó a EX.
3. Las instrucciones anteriores al HALT siguen avanzando y terminan normalmente.
4. Cuando el HALT llega a WB, al ciclo siguiente halted se pone en 1 y queda trabado (ver wb.md, sección 7).

En ese momento todas las instrucciones anteriores ya escribieron y detrás del HALT solo hay burbujas: el pipeline está vacío. halted es lo que mira la Debug Unit para terminar el modo continuo.

Por qué detectar en ID y no en IF: en ID ya está la unidad de control que decodifica el opcode, y se puede saber si un salto tomado en EX lo va a descartar.


## 9. Pruebas

programs/pipeline.s tiene un caso de cada riesgo: forwarding desde EX/MEM y MEM/WB, load use, salto tomado y no tomado, loop, jal y jalr, y un HALT descartado detrás del jalr. tb/tb_cpu.v lo corre y muestra en cada ciclo qué instrucción hay en cada etapa y si hubo stall, salto, forwarding o fetch frenado.

programs/instrucciones.s agrega saltos hacia atrás y dependencias entre las 32 instrucciones.


## Pendiente

1. Testbenches unitarios tb/tb_hazard_unit.v y tb/tb_forwarding_unit.v.
