# Clock y timing: decisiones de diseño

Archivos: src/clk_gen.v, src/top.v, constrs/basys3.xdc, scripts/build.tcl

Este documento responde la sección 8 de la consigna (preguntas P6 a P8): cuál es el camino crítico, si hay skew y a qué frecuencia corre el sistema. Los números salen de los reportes de Vivado 2025.2 con el diseño ruteado (build/timing.rpt y build/utilization.rpt, que genera scripts/build.tcl).


## 1. Cómo se mide

scripts/build.tcl sintetiza, implementa y genera:
- build/timing.rpt: resumen de timing (WNS, TNS, WHS) y el peor camino de setup y de hold.
- build/critical_paths.rpt: los 10 peores caminos.
- build/utilization.rpt: recursos usados.

Si el WNS da negativo, el script no programa la placa.

La carpeta build/ no se sube al repositorio (se regenera), por eso los números que importan se copian acá.

Definiciones:
- WNS (worst negative slack): margen del peor camino de setup. Si es negativo, el dato llega tarde y el diseño no funciona a esa frecuencia.
- WHS (worst hold slack): margen del peor camino de hold. Si es negativo, el dato cambia demasiado pronto.
- Skew: diferencia entre el momento en que el clock llega al flip flop de origen y al de destino.


## 2. Recursos usados

| Recurso | Usado | Disponible | % |
|---|---|---|---|
| LUT | 10519 | 20800 | 50.6 |
| Flip flops | 3881 | 41600 | 9.3 |
| Block RAM | 0 | 50 | 0 |
| MMCM | 1 | 5 | 20 |
| BUFG | 1 | 32 | 3.1 |

La mayoría de las LUTs son los multiplexores de lectura de la memoria de datos y del banco de registros, que están hechos con flip flops porque se borran con reset (ver mem.md, sección 3).


## 3. Primer intento: 100 MHz

Con el pipeline completo conectado directo al clock de la placa (100 MHz, 10 ns), el ruteo dio WNS = -0.498 ns: el camino crítico necesita unos 10.5 ns. El diseño no cumple timing a 100 MHz.


## 4. Camino crítico (P6)

Con el sistema a 80 MHz (sección 6), el peor camino es:

| | |
|---|---|
| Origen | u_cpu/u_ex_mem/reg_write_out_reg (latch EX/MEM) |
| Destino | u_du/tx_data_reg[7] (byte que manda la Debug Unit) |
| Retardo del dato | 11.943 ns: 2.594 ns de lógica (22 %) y 9.349 ns de ruteo (78 %) |
| Niveles de lógica | 11 LUTs |
| Slack | +0.465 ns |

Recorrido:
1. reg_write de EX/MEM entra a la forwarding unit, que decide si adelantar el dato.
2. El mux de forwarding elige el operando B de EX y después el mux de alu_src.
3. El operando pasa por la ALU (la señal B[3], que maneja los shifts, tiene fanout 119).
4. El resultado de la ALU (latch 16, "EX: resultado de la ALU", ver debug_unit.md) pasa por el mux de latches de cpu.v y el mux del dump de top.v.
5. Llega a tx_data de la Debug Unit.

Es decir, el camino crítico del procesador es forwarding, ALU y resultado, que es el camino típico de un pipeline de 5 etapas. En este caso termina en la Debug Unit porque el resultado de la ALU también se manda en el dump, y eso le suma 3 LUTs de multiplexores.

El 78 % del retardo es ruteo: la lógica está repartida en la FPGA y las señales con mucho fanout (como B[3]) tardan en llegar a todos lados.


## 5. Skew (P7)

Todo el diseño usa un solo clock, que sale del MMCM y se distribuye por un buffer global (BUFG) a los 4137 flip flops. No hay compuertas sobre el clock ni clocks generados con lógica (ver if.md, sección 6).

Igual hay skew, porque el clock tarda distinto en llegar a cada flip flop según dónde está ubicado:

| Camino | Skew | Slack |
|---|---|---|
| Peor setup (sección 4) | -0.041 ns | +0.465 ns |
| Peor hold (EX/MEM alu_result a MEM/WB alu_result) | 0.260 ns | +0.069 ns |

A esto se suma la incertidumbre del clock por el jitter del MMCM: 0.082 ns.

Consecuencias:
- En setup, un skew negativo le resta tiempo al dato. Acá son 41 ps sobre un período de 12.5 ns, así que no influye.
- En hold, un skew positivo hace que el flip flop de destino capture más tarde, y el dato nuevo puede pisar al anterior. Es el caso más ajustado del diseño (69 ps de margen), pero cumple: Vivado agrega retardo de ruteo donde hace falta.

Conclusión: el skew existe pero es chico, porque el clock va por la red global y no se interviene. Vivado lo incluye en el análisis y todos los caminos cumplen.


## 6. Frecuencia (P8)

Opciones: bajar la frecuencia con un contador (clock generado con lógica), o con el MMCM del Artix 7 (lo que arma el Clocking Wizard).

Elección: MMCM, instanciado como primitiva (MMCME2_BASE) en clk_gen.v, con un BUFG a la salida.

Por qué: un clock generado con lógica tiene mucho skew y la consigna no permite intervenir el clock (R12). El MMCM es el hardware dedicado de la FPGA para esto. Se instancia como primitiva y no con el IP del Clocking Wizard para no depender de archivos generados por Vivado; el hardware es el mismo.

Configuración: 100 MHz x 8 = 800 MHz de VCO (tiene que quedar entre 600 y 1200 MHz), dividido 10 = 80 MHz (12.5 ns). Todo el sistema (procesador, Debug Unit y UART) usa este clock. El clock de la placa solo entra al MMCM.

Mientras el MMCM no engancha (locked = 0), el top mantiene todo en reset.

Resultado a 80 MHz:

| | Valor |
|---|---|
| WNS / TNS | +0.465 ns / 0 |
| WHS / THS | +0.069 ns / 0 |
| Endpoints que fallan | 0 de 13768 |

Frecuencia máxima: el período mínimo con este ruteo es 12.5 - 0.465 = 12.035 ns, o sea unos 83 MHz. Con el ruteo de 100 MHz el camino necesitaba unos 10.5 ns (unos 95 MHz). La diferencia es que Vivado optimiza el ruteo según la frecuencia pedida: con más margen se esfuerza menos. La frecuencia óptima real queda entre esos dos valores.

Se eligió 80 MHz porque es un número redondo, cierra timing con margen y el divisor de la UART da casi exacto (BR_DIV = 130).

Al cambiar la frecuencia hay que cambiar también BR_DIV en top.v: BR_DIV = f / (16 * 38400).


## Pendiente

1. Buscar la frecuencia máxima. Con el VCO en 800 MHz, OUT_DIV en clk_gen.v se puede cambiar de a 0.125: 9.5 da 84.2 MHz, 9 da 88.9 MHz y 8.5 da 94.1 MHz. Correr build.tcl con cada uno (y su BR_DIV) y quedarse con el más alto que tenga WNS >= 0.
2. Guardar en este documento los 10 caminos de build/critical_paths.rpt de la frecuencia final.
