# Etapa ID: decisiones de diseño

Archivos: src/id.v (módulo id_stage), src/reg_file.v, src/imm_gen.v, src/control_unit.v, src/alu_control.v, src/id_ex.v, src/hazard_unit.v

ID separa los campos de la instrucción, lee rs1 y rs2 del banco de registros, arma el inmediato y genera las señales de control. Todo eso se guarda en el latch ID/EX. En ID también se detecta el riesgo load use y el HALT.


## 1. Organización de la etapa

Elección: id_stage instancia reg_file, imm_gen y control_unit, y separa los campos (rd, rs1, rs2, funct3, funct7, opcode) con assign.

Por qué: el resto del pipeline ve a ID como un solo bloque, y cada parte se puede probar por separado.


## 2. Escritura del banco de registros

Opciones: escribir en el flanco de bajada (como "escribir en la primera mitad del ciclo" del libro) o en el de subida con bypass.

Elección: flanco de subida más bypass interno. Si WB escribe el mismo registro que ID está leyendo, la lectura devuelve el dato nuevo.

Por qué: el resultado es el mismo, pero sin usar el flanco de bajada, que obligaría a que la escritura entre en medio período y bajaría la frecuencia máxima.


## 3. x0, habilitación y reset del banco

x0 nunca se escribe y siempre se lee 0, también en el bypass. La escritura se habilita con en, así que con el procesador pausado no cambia nada.

rst pone los 32 registros en 0, por eso el banco se implementa con flip flops y no con RAM distribuida. Responde la pregunta P2: al reprogramar, los registros se vacían y el programa nuevo arranca de un estado conocido.

Tiene un tercer puerto de lectura, asincrónico, para que la Debug Unit mande los 32 registros en el dump.


## 4. Generador de inmediatos

Elección: un case sobre el opcode que arma el inmediato de 32 bits con extensión de signo según el formato: I (loads, aritméticas con inmediato y jalr), S, B, U (lui) y J. El default es 0.

En B y J el bit 0 es siempre 0, porque los saltos son múltiplos de 2. En slli, srli y srai el inmediato incluye los bits de funct7, pero no importa porque la ALU usa solo B[4:0] para desplazar.


## 5. Unidad de control

Elección: decodifica solo el opcode. Todas las salidas se ponen en 0 al principio del always y cada caso pone en 1 lo que necesita.

Por qué: con los valores por defecto arriba no se infieren latches, y una instrucción desconocida queda como una burbuja que no escribe nada.

Señales: reg_write, alu_src, alu_op, mem_read, mem_write, wb_sel, branch, jump, jalr, halt, uses_rs1 y uses_rs2.


## 6. Operación de la ALU en dos niveles

Opciones: decidir la operación completa en ID (alu_ctrl de 4 bits) o el esquema del libro (alu_op de 2 bits en ID y una unidad alu_control en EX que mira funct3 y funct7).

Elección: el esquema del libro. control_unit genera alu_op, y alu_control, instanciada en EX entre el latch ID/EX y ex.v, arma el alu_ctrl de 4 bits.

alu_op 00: ADD (loads, stores, jalr y branches, donde el resultado es una dirección o no se usa).
alu_op 01: tipo R, alu_ctrl = {funct7[5], funct3}.
alu_op 10: tipo I, alu_ctrl = {0, funct3}, salvo srli y srai (funct3 101), donde sí se mira funct7[5].
alu_op 11: PASS_B (lui).

Por qué: la unidad de control queda chica porque solo mira el opcode. En tipo I no se mira funct7[5] salvo en los shifts a la derecha, porque en las demás es parte del inmediato y un addi con inmediato negativo se ejecutaría como resta. Para que funcione, funct7 viaja por el latch ID/EX.


## 7. Selector de WB

wb_sel: 00 resultado de la ALU, 01 dato de memoria (loads), 10 PC + 4 (jal y jalr). Lo usa wb.v (ver wb.md).


## 8. uses_rs1 y uses_rs2

La unidad de control indica si la instrucción usa realmente rs1 y rs2.

Por qué: los campos rs1 y rs2 siempre existen en la instrucción, pero en algunas son parte del inmediato (lui, jal, el rs2 de las tipo I). Sin estas señales, la hazard unit frenaría el pipeline por dependencias que no existen.


## 9. HALT

Elección: opcode 0000000, es decir la palabra 0x00000000. También se acepta el opcode 1111111.

Por qué: la memoria vacía es 0, así que un programa sin HALT o un PC que se va de rango también terminan (ver if.md). Ninguna instrucción de RV32I usa esos opcodes.


## 10. Latch ID/EX

Guarda rs1_data, rs2_data, imm, rd, rs1, rs2, funct3, funct7, pc, pc4 y todas las señales de control.

rst, o en con flush, cargan una burbuja: todo en 0, así que no escribe registros ni memoria, no salta y tampoco lleva halt. Con en = 0 se mantiene.

No tiene stall: en un load use el latch recibe una burbuja (flush) en lugar de mantenerse, porque la instrucción frenada sigue esperando en IF/ID.

rs1 y rs2 (números de registro) viajan para que la forwarding unit los compare en EX.


## 11. Hazard unit

Se ocupa de las tres situaciones que cambian el flujo normal del pipeline. El resumen de todos los riesgos y del HALT está en riesgos.md.

Load use: si la instrucción en EX es un load (mem_read) y la de ID usa su rd (según uses_rs1 y uses_rs2, y con rd distinto de x0), el dato recién estará al final de MEM. Se frena 1 ciclo: stall al PC y a IF/ID, y burbuja en ID/EX. Después el forwarding lo adelanta desde WB. Es el único caso que el forwarding solo no resuelve.

Salto tomado: flush de IF/ID e ID/EX. Le gana al stall, porque la instrucción frenada también es del camino equivocado.

HALT: cuando ID ve un HALT y no hay un salto tomado que lo descarte, un registro (fetch_stopped) se pone en 1 hasta el próximo reset. Mientras tanto el PC no avanza e IF/ID recibe NOPs. Hace falta el registro porque al ciclo siguiente el HALT ya pasó a EX, y sin él el PC volvería a avanzar.


## 12. Pruebas

tb/tb_imm_gen.v (24 casos), tb/tb_reg_file.v, tb/tb_control_unit.v (12 opcodes, incluidos HALT y dos no soportados), tb/tb_alu_control.v (23 casos) y tb/tb_hazard_unit.v (16 casos) prueban los módulos por separado. tb/tb_cpu.v prueba el pipeline completo, incluidos los riesgos.

