# Etapa WB: decisiones de diseño

Archivos: src/mem_wb.v, src/wb.v

WB es la última etapa. Elige qué valor se escribe en el registro destino y se lo manda al banco de registros, que está en ID. También avisa cuándo terminó el programa.


## 1. Latch MEM/WB

Guarda load_data (de MEM) y alu_result, pc4, rd, reg_write, wb_sel y halt (directo de EX/MEM). store_data, funct3, mem_read y mem_write no pasan porque ya se usaron en MEM.

rst pone todo en 0, que es una burbuja. Con en = 0 mantiene el valor.

No tiene flush ni stall: igual que EX/MEM, siempre avanza. Los saltos y el load use solo afectan a IF/ID e ID/EX.


## 2. Módulo aparte

Opciones: un wb.v o poner el mux directamente en el módulo que une el pipeline.

Elección: wb.v aparte.

Por qué: mantiene el patrón de un archivo por etapa, se puede probar solo y deja más limpio cpu.v.


## 3. Mux del dato a escribir

Elección: case sobre wb_sel. 00 resultado de la ALU, 01 dato de memoria, 10 PC + 4.

Por qué: se lee como una tabla, igual que el case de funct3 en mem.v. Los tres valores llegan siempre, para cualquier instrucción, y wb_sel, que generó la unidad de control en ID, indica cuál es el bueno.


## 4. wb_sel inválido

Opciones: que el default dé el resultado de la ALU o que dé 0.

Elección: 0.

Por qué: ninguna instrucción genera 11. El default existe para que no se infiera latch, y 0 deja claro que es un caso inválido, igual que en mem.v.


## 5. Escritura en x0

Elección: WB no hace nada especial con x0.

Por qué: el banco de registros ya ignora las escrituras a x0. La forwarding unit igual chequea rd distinto de 0 por su cuenta.


## 6. Hacia dónde va el dato

El dato elegido va al banco de registros (con reg_write y rd), y también a EX como wb_write_data para el forwarding.

Gracias al bypass del banco de registros, una instrucción que está en ID lee el valor que WB escribe en ese mismo ciclo.


## 7. Fin del programa (halted)

Opciones: halted combinacional (vale 1 mientras el HALT está en WB) o un registro que se traba en 1.

Elección: registro que se traba en 1 hasta el próximo reset.

Por qué: con la versión combinacional, si después del HALT se manda otro paso, el HALT sale de WB, entra una burbuja y halted vuelve a 0, como si el programa siguiera. Trabado, siempre indica que terminó.

Consecuencia: halted aparece un ciclo después de que el HALT llega a WB. En ese momento todas las instrucciones anteriores ya escribieron sus registros y el fetch está frenado, así que el pipeline está vacío (R10). halted es el cpu_halted que usa la Debug Unit para dejar de correr en el modo continuo.


## 8. Pruebas

tb/tb_wb.v, autoverificante: los cuatro valores de wb_sel, que rd y reg_write pasen directo, y que halted no suba con en = 0, se trabe en 1 y baje con rst. tb/tb_cpu.v prueba la etapa dentro del pipeline completo.


## Pendiente

Nada pendiente en WB.
