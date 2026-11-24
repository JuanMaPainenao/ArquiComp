# TP Final: procesador RISC-V segmentado con Debug Unit

Procesador RV32I de 5 etapas (IF, ID, EX, MEM, WB) con las 32 instrucciones de la consigna, forwarding y detección de riesgos. Una Debug Unit por UART carga el programa, lo ejecuta en modo continuo o paso a paso y devuelve registros, latches y memoria de datos.

- Placa: Basys 3 (xc7a35tcpg236-1)
- Clock: 100 MHz de la placa → MMCM → 80 MHz para todo el sistema
- UART: 38400 baudios, 8N1, por el USB de la placa
- Herramientas: Vivado 2025.2, Python 3 (ensamblador) y PowerShell (consola, Windows)


## Carpetas

| Carpeta | Contenido |
|---|---|
| src/ | Verilog del diseño. El top es top.v |
| constrs/ | basys3.xdc: pines y clock |
| tb/ | Testbenches autoverificantes (imprimen TEST OK o los errores) |
| programs/ | Programas en assembly (.s) y su código máquina (.hex) |
| scripts/ | asm.py (ensamblador), du.ps1 (consola), smoke_test.ps1, build.tcl |
| docs/ | Decisiones de diseño (ver al final) |


## Nombres de señales

Una señal tiene el mismo nombre en todos los archivos, así se puede seguir con una búsqueda. Solo se le agrega:
- La etapa o el latch donde está: id_, idex_, exmem_, memwb_, wb_ (por ejemplo id_rd → idex_rd → exmem_rd → memwb_rd).
- La dirección en los latches y en los módulos del TP2: _in / _out, i_ / o_ (por ejemplo rx_data sale de rx_uart como o_rx_data).
- dbg_ en los puertos que usa la Debug Unit para leer el estado.

Ejemplos: el dato que escribe WB es write_data_out en wb.v, wb_write_data en cpu.v, id.v y ex.v (forwarding) y write_data en reg_file.v. El HALT que frena el PC es fetch_stop en hazard_unit.v, cpu.v y pc_unit.v.


## 1. Crear el proyecto en Vivado

1. File → Project → New → RTL Project.
2. Add Sources: Add Directories → TP_Final/src. Destildar "Copy sources into project", así se edita el código del repo.
3. Add Constraints: TP_Final/constrs/basys3.xdc (también sin copiar).
4. Default Part: xc7a35tcpg236-1 (o la placa Basys 3).
5. Add Sources → Add or create simulation sources → Add Directories → TP_Final/tb.
6. En Sources, verificar que el top de Design Sources sea top. Si no: clic derecho en top → Set as Top.


## 2. Generar el bitstream y programar la placa

1. Flow Navigator → Generate Bitstream (hace síntesis e implementación).
2. Revisar el timing: Open Implemented Design → Report Timing Summary. WNS tiene que ser mayor o igual a 0 (da +0.465 ns a 80 MHz).
3. Open Hardware Manager → Open Target → Auto Connect → Program Device.

Alternativa sin abrir la interfaz, desde una terminal en TP_Final:

```
vivado -mode batch -source scripts/build.tcl
```

Hace todo lo anterior, deja los reportes en build/ y no programa la placa si WNS < 0. Con `-tclargs noprog` solo genera el bitstream.


## 3. Simular en Vivado

1. En Sources → Simulation Sources, clic derecho en el testbench → Set as Top.
2. Flow Navigator → Run Simulation → Run Behavioral Simulation.
3. En la Tcl Console escribir `run all`. El resultado sale en la consola.

Para no escribir `run all` cada vez: Settings → Simulation → Simulation → xsim.simulate.runtime = all.

| Testbench | Qué prueba |
|---|---|
| tb_cpu | Pipeline completo con programs/pipeline.s: riesgos, saltos, memoria y HALT. Imprime qué hay en cada etapa en cada ciclo |
| tb_top | Sistema completo por UART: carga, dump, paso a paso, continuo y reprogramación. Tarda varios minutos |
| tb_debug_unit | FSM de la Debug Unit sin UART: todos los comandos |
| tb_hazard_unit | Load use, saltos, HALT y prioridades |
| tb_forwarding_unit | Caminos de forwarding y prioridad |
| tb_control_unit | Señales de control de cada opcode |
| tb_alu_control | Código de la ALU de cada instrucción |
| tb_ex | ALU, operando B, stores y saltos |
| tb_mem | Stores, loads con y sin signo, memoria usada y reset |
| tb_wb | Mux de WB y halted |
| tb_imm_gen | Inmediatos de cada formato |
| tb_reg_file | Banco de registros: x0, bypass, en y reset |


## 4. Escribir y ensamblar un programa

El programa se escribe en assembly y tiene que terminar con `halt`. Sintaxis en docs/asm.md.

```
python scripts/asm.py programs/pipeline.s
```

Genera programs/pipeline.hex. Programas de ejemplo:

| Programa | Qué hace |
|---|---|
| ejemplo.s | 4 instrucciones con dependencias |
| pipeline.s | Un caso de cada riesgo, para ver paso a paso |
| instrucciones.s | Las 32 instrucciones y las pseudoinstrucciones |
| grande.s | 200 instrucciones, para probar la carga |

Cada .s tiene al principio o al final el resultado esperado.


## 5. Usar la placa

Con la placa programada y conectada por USB, en una terminal de Windows en TP_Final:

```
scripts\du
```

Busca solo el puerto de la Basys 3 (o se le pasa `-Port COM5`) y abre el prompt `du>`.

| Comando | Qué hace |
|---|---|
| file programs\pipeline.hex | Carga el programa (agrega HALT si falta) |
| s [N] o Enter | Ejecuta N ciclos de clock (1 por defecto) |
| r | Ejecuta hasta HALT |
| d | Muestra el estado sin ejecutar |
| x | Reset del procesador (vuelve al principio del programa) |
| dmem | Memoria de datos usada |
| lat | Latches crudos |
| mem [N] | Lee las N primeras palabras de la memoria de programa |
| help, q | Ayuda, salir |

La vista muestra qué instrucción hay en cada etapa, los riesgos del ciclo, los 32 registros y la memoria de datos. Lo que cambió en el último comando sale en amarillo.

Si el programa queda en un loop infinito, r no vuelve: apretar el botón central (BTNC) para resetear.

Prueba rápida de la placa: `powershell -ExecutionPolicy Bypass -File scripts\smoke_test.ps1`.


## Documentación

| Documento | Tema |
|---|---|
| docs/consigna-tp-final.md | Consigna transcripta |
| docs/if.md, id.md, ex.md, mem.md, wb.md | Decisiones de cada etapa |
| docs/riesgos.md | Forwarding, stalls, saltos y HALT |
| docs/debug_unit.md | Protocolo UART, comandos, dump y reprogramación |
| docs/timing.md | Camino crítico, skew y frecuencia |
| docs/asm.md | Ensamblador |
