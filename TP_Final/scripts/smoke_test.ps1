# smoke_test.ps1 - Prueba la Debug Unit + etapa IF en la placa por UART
# Uso (PowerShell en Windows, desde TP_Final):
#   powershell -ExecutionPolicy Bypass -File scripts\smoke_test.ps1 [-Port COM14]
param([string]$Port = 'COM14')
$p = New-Object System.IO.Ports.SerialPort $Port,38400,'None',8,'One'
$p.ReadTimeout = 2000
$p.Open(); Start-Sleep -Milliseconds 200; $p.DiscardInBuffer()
$fail = 0
function Send([byte[]]$b){ $p.Write($b,0,$b.Length) }
function Recv([int]$n){ $buf = New-Object byte[] $n; $got=0; while($got -lt $n){ $got += $p.Read($buf,$got,$n-$got) }; ,$buf }
function Word([byte[]]$b,[int]$o){ [BitConverter]::ToUInt32($b,$o) }
function Check($name,$got,$exp){ if($got -eq $exp){"OK    $name = 0x{0:X8}" -f $got}else{$script:fail++; "FAIL  $name = 0x{0:X8} (esperado 0x{1:X8})" -f $got,$exp} }
function Dump($cmd,$h,$pc,$ins){ Send @([byte][char]$cmd); $r = Recv 9; Check 'halted' ([uint32]$r[0]) $h; Check 'PC' (Word $r 1) $pc; Check 'instr' (Word $r 5) $ins }
function Load([uint32[]]$prog){ $b = @([byte][char]'L', [byte]($prog.Length -band 0xFF), [byte]($prog.Length -shr 8)); foreach($w in $prog){ $b += [BitConverter]::GetBytes($w) }; Send $b; $r = Recv 1; Check 'ack' ([uint32]$r[0]) 0x4B }

$prog = [uint32[]]@(0x00500093,0x00a00113,0x002081b3,0x40208233)
try {
"--- 0. Reset ('X')";        Send @([byte][char]'X'); Check 'ack' ([uint32](Recv 1)[0]) 0x4B
"--- 1. Carga 4 instr ('L')"; Load $prog
"--- 2. Dump ('D')";         Dump 'D' 0 0 $prog[0]
"--- 3. Paso ('S')";         Dump 'S' 0 4 $prog[1]
"--- 3b. Paso ('S')";        Dump 'S' 0 8 $prog[2]
"--- 4. Continuo ('R')";     Dump 'R' 1 16 0
"--- 5. Reprogramacion";     Load ([uint32[]]@(0x00100093)); Dump 'D' 0 0 0x00100093
"--- 6. Comando invalido";   Send @([byte]0x7A); Check 'nak' ([uint32](Recv 1)[0]) 0x3F
} catch { $fail++; "ERROR: $_" }
$p.Close()
if($fail -eq 0){"PLACA OK"}else{"FALLARON $fail"}
