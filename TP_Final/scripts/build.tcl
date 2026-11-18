# build.tcl - Sintesis + implementacion + bitstream (non-project) y programacion
# Uso (desde TP_Final/):  vivado -mode batch -source scripts/build.tcl [-tclargs noprog]
set root [file normalize [file dirname [info script]]/..]
set out  $root/build
file mkdir $out

read_verilog [glob $root/src/*.v]
read_xdc     $root/constrs/basys3.xdc

synth_design -top top -part xc7a35tcpg236-1
opt_design
place_design
route_design

report_utilization    -file $out/utilization.rpt
report_timing_summary -file $out/timing.rpt
report_timing -max_paths 10 -file $out/critical_paths.rpt
write_bitstream -force $out/top.bit

# No programar un diseno que no cierra timing
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
puts "WNS = $wns ns"
if {$wns < 0} {
    puts "ERROR: el diseno no cumple timing (WNS < 0), no se programa la placa"
    exit 1
}

if {[lsearch $argv noprog] < 0} {
    open_hw_manager
    connect_hw_server
    open_hw_target
    set dev [lindex [get_hw_devices xc7a35t*] 0]
    current_hw_device $dev
    set_property PROGRAM.FILE $out/top.bit $dev
    program_hw_devices $dev
    close_hw_manager
    puts "PROGRAMADO OK"
}
