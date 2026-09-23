## Constraints para top_uart_alu en la Basys3 (Xilinx Artix-7 XC7A35T-1CPG236C)

## Clock del sistema: 100 MHz
set_property PACKAGE_PIN W5 [get_ports clk]
    set_property IOSTANDARD LVCMOS33 [get_ports clk]
    create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## Boton central (BTNC) como reset sincrono activo en alto
set_property PACKAGE_PIN U18 [get_ports i_reset]
    set_property IOSTANDARD LVCMOS33 [get_ports i_reset]

## Interfaz USB-UART (puente FTDI) integrada en la placa
## RsRx: dato que llega al puente USB-UART y sale hacia la FPGA -> i_rx
## RsTx: dato que sale de la FPGA hacia el puente USB-UART       -> o_tx
set_property PACKAGE_PIN B18 [get_ports i_rx]
    set_property IOSTANDARD LVCMOS33 [get_ports i_rx]
set_property PACKAGE_PIN A18 [get_ports o_tx]
    set_property IOSTANDARD LVCMOS33 [get_ports o_tx]
