# Etapa EX: decisiones de diseño

Archivos: src/ex.v, src/alu.v, src/ex_mem.v, tb/tb_ex.v

EX recibe lo que preparó ID (latch ID/EX) y calcula: el resultado de la operación, la dirección de memoria de loads y stores, y si hay que saltar y a dónde. Es lógica combinacional; el resultado se guarda en el latch EX/MEM en el flanco siguiente.


## 1. En qué etapa se resuelven los saltos

Opciones: resolverlos en ID o en EX.

Elección: EX.

Por qué: en ID el salto cuesta 1 ciclo en vez de 2, pero el comparador necesita los valores de rs1 y rs2 ya en ID. Eso obliga a agregar forwarding hacia ID y stalls extra cuando la instrucción anterior todavía no calculó el dato, y además alarga el camino crítico de ID. En EX los operandos ya llegan con el forwarding normal y todo queda en un solo lugar.

Costo: cada salto tomado descarta las 2 instrucciones que entraron detrás (flush de IF/ID e ID/EX). Un salto no tomado no pierde ciclos.


## 2. Predicción de saltos

Opciones: predictor dinámico, predecir siempre tomado, o no predecir (seguir buscando PC + 4).

Elección: no predecir. IF sigue con PC + 4 y si EX descubre que el salto se toma, se descarta lo buscado.

Por qué: es lo más simple y no necesita hardware extra. La consigna no pide rendimiento.


## 3. Qué señales declara EX

Opciones: que todas las señales que viajan hacia MEM y WB pasen por EX (entran y salen sin tocarse), o que EX declare solo las que usa.

Elección: solo las que usa. rd, pc4, reg_write, mem_read, mem_write, wb_sel y halt van directo del latch ID/EX al latch EX/MEM en el módulo que conecta todo. rs1 y rs2 (números de registro) van a la unidad de forwarding.

Por qué: EX queda con 19 puertos en vez de unos 30, el testbench es más simple y se evitan errores al cablear salidas que no hacen nada. El hardware que genera Vivado es el mismo con las dos opciones.


## 4. ALU

Opciones: escribir una ALU nueva o reutilizar la del TP1.

Elección: reutilizar la del TP1 (copiada a src/alu.v) y adaptarla.

Cambios respecto del TP1:
1. Ancho de 32 bits (parámetro NB_DATA).
2. Códigos de operación de 4 bits en lugar de los 6 bits de MIPS.
3. Operaciones nuevas: SLL, SLT, SLTU y PASS_B.
4. Se sacó NOR (RISC V no la tiene) y las salidas CARRY y OVF (RISC V no usa flags y nunca se asignaban).
5. Los shifts usan solo B[4:0], como pide la spec. Con B = 33 se desplaza 1.


## 5. Codificación de alu_ctrl

Opciones: el esquema del libro (ALUOp de 2 bits en ID y un "ALU control" en EX que mira funct3 y funct7), o decodificar la operación completa en ID.

Elección: la operación completa se decide en ID y llega a EX como alu_ctrl de 4 bits, con el código {instr[30], funct3}.

ADD 0000, SUB 1000, SLL 0001, SLT 0010, SLTU 0011, XOR 0100, SRL 0101, SRA 1101, OR 0110, AND 0111, PASS_B 1111.

Por qué: con ese código las instrucciones tipo R se decodifican solas, EX queda más simple y en el dump de la Debug Unit se lee directamente qué operación se ejecuta. Este código tiene que coincidir con el que genera la unidad de control de ID.

Cuidado: en las instrucciones tipo I el bit 30 es parte del inmediato. Solo se mira en srli y srai. Si se mira siempre, un addi con inmediato negativo se ejecuta como resta.


## 6. lui con PASS_B

Opciones: ejecutar lui como ADD de x0 + imm, o agregar una operación que deje pasar B.

Elección: PASS_B (el resultado es B y A se ignora).

Por qué: lui no tiene rs1. Los bits donde iría rs1 son parte del inmediato, así que A tendría el valor de un registro cualquiera y la suma daría basura. Con PASS_B no importa qué tenga A.


## 7. Mux del operando B

Opciones: elegir entre rs2 e imm mirando si el imm vale 0, o con la señal de control alu_src.

Elección: alu_src, que calcula ID a partir del opcode.

Por qué: lo que importa es el tipo de instrucción, no el valor del imm. addi x1, x2, 0 tiene imm 0 y tiene que usar el imm; una instrucción tipo R no tiene imm y tiene que usar rs2.


## 8. Dato de los stores (store_data)

Opciones: tomar rs2_data directo o tomar B_ (rs2 después del forwarding).

Elección: B_, antes del mux de alu_src.

Por qué: en un store la ALU calcula la dirección (rs1 + imm), así que B es el imm y el dato a guardar tiene que salir por otro lado. Se toma después del forwarding para que, si la instrucción anterior modificó rs2, se guarde el valor nuevo y no el que leyó ID.


## 9. Decisión de salto

Opciones: usar la ALU (SUB y mirar si da cero) o un comparador aparte.

Elección: comparador aparte, iguales = (A == B_), y una señal taken.

Por qué: la ALU no tiene salida de cero y no hace falta agregársela. Con el comparador aparte la condición se lee directo: beq salta si son iguales, bne si son distintos, jal y jalr siempre. Se compara con B_ (rs2), no con B, porque B puede ser el imm.

taken arranca en 0 al principio del always y los if solo lo ponen en 1. Así no hace falta else y no se infiere latch.


## 10. Destino del salto

beq, bne y jal: pc + imm. jalr: (rs1 + imm) con el bit 0 en 0, como pide la spec.

Opciones para jalr: reutilizar alu_result (la ALU ya calcula rs1 + imm porque ID pone ADD y alu_src = 1) o hacer la suma aparte.

Elección: la suma aparte dentro del always del destino.

Por qué: queda explícito y no depende de que ID ponga bien alu_ctrl para jalr. El costo es un sumador más.

redirect y flush valen lo mismo (taken) pero son dos salidas porque van a lugares distintos: redirect a pc_unit y flush a los latches IF/ID e ID/EX.


## 11. Forwarding

Los puertos ya están (ex_mem_result, mem_wb_data, fwd_a, fwd_b) pero todavía no se usan: A = rs1_data y B_ = rs2_data.

Selector previsto: 00 dato leído en ID, 01 resultado que está en EX/MEM, 10 dato que está en MEM/WB.

Por qué se deja para después: hace falta tener MEM y WB para que existan esos datos.


## 12. Estilo

Las condiciones se escriben con always @(*) e if/else, no con el operador ternario, porque se leen mejor. Las señales asignadas en un always se declaran reg.

Todo always combinacional asigna un valor en todos los casos (valor por defecto arriba, else o default) para que no se infieran latches.


## 13. Latch EX/MEM

Guarda alu_result y store_data (de EX) y rd, funct3, pc4, reg_write, mem_read, mem_write, wb_sel y halt (directo de ID/EX).

rst pone todo en 0, que es una burbuja: no escribe registros ni memoria. Con en = 0 mantiene el valor (pausa de la Debug Unit).

No tiene flush ni stall. Los saltos solo descartan lo que está en IF/ID e ID/EX, y en un load use la burbuja se mete en ID/EX. EX/MEM siempre avanza.


## 14. Pruebas

tb/tb_ex.v, autoverificante, 31 casos: las 11 operaciones de la ALU con los casos de signo y de shifts, el mux de B (incluido addi con imm 0), un store, y saltos tomados y no tomados de cada tipo.

iverilog g2012 o tb_ex tb/tb_ex.v src/ex.v src/alu.v y después vvp tb_ex


## Pendiente

1. Forwarding (unidad de forwarding y muxes de la sección 1 de ex.v).
2. Conectar redirect, redirect_target y flush a pc_unit, if_id e id_ex.
3. Confirmar con ID la codificación de alu_ctrl.
