# smoke_test.ps1 - Prueba el procesador + Debug Unit en la placa por UART
# Uso (PowerShell en Windows, desde TP_Final):
#   powershell -ExecutionPolicy Bypass -File scripts\smoke_test.ps1 [-Port COM14]
# Sin -Port busca el puerto FTDI de la Basys 3.
#
# Dump (ver src/top.v): estado, PC, M, 20 latches, x0..x31, M palabras de dmem.
param([string]$Port = '')
if ($Port -eq '') {
    $ftdi = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue |
            Where-Object { $_.Manufacturer -eq 'FTDI' -and $_.Name -match '\((COM\d+)\)' } | Select-Object -First 1
    if ($ftdi) { $Port = [regex]::Match($ftdi.Name, 'COM\d+').Value } else { $Port = 'COM14' }
}
$N_FIXED = 2 + 20 + 32
$REG0 = 22                       # indice de palabra de x0
$p = New-Object System.IO.Ports.SerialPort $Port,38400,'None',8,'One'
$p.ReadTimeout = 3000
$p.Open(); Start-Sleep -Milliseconds 200; $p.DiscardInBuffer()
$fail = 0
function Send([byte[]]$b){ $p.Write($b,0,$b.Length) }
function Recv([int]$n){ $buf = New-Object byte[] $n; $got=0; while($got -lt $n){ $got += $p.Read($buf,$got,$n-$got) }; ,$buf }
function Check($name,$got,$exp){ if([uint32]$got -eq [uint32]$exp){"OK    $name = 0x{0:X8}" -f [uint32]$got}else{$script:fail++; "FAIL  $name = 0x{0:X8} (esperado 0x{1:X8})" -f [uint32]$got,[uint32]$exp} }
# Devuelve @{ halted; w = palabras fijas; mem = memoria de datos }
function Dump($cmd){
    Send @([byte][char]$cmd); $r = Recv (1 + 4*$N_FIXED)
    $w = @(for($i=0;$i -lt $N_FIXED;$i++){ [BitConverter]::ToUInt32($r,1+4*$i) })
    $rm = Recv (4*[int]$w[1])
    $m = @(for($i=0;$i -lt $w[1];$i++){ [BitConverter]::ToUInt32($rm,4*$i) })
    @{ halted = $r[0]; w = $w; mem = $m }
}
function Load([uint32[]]$prog){ $b = @([byte][char]'L', [byte]($prog.Length -band 0xFF), [byte]($prog.Length -shr 8)); foreach($w in $prog){ $b += [BitConverter]::GetBytes($w) }; Send $b; $r = Recv 1; Check 'ack' ([uint32]$r[0]) 0x4B }
function Reg($d,$k){ $d.w[$REG0 + $k] }

$prog = [uint32[]]@(0x00500093,0x00a00113,0x002081b3,0x40208233,0x00000000)
try {
"--- 0. Reset ('X')";        Send @([byte][char]'X'); Check 'ack' ([uint32](Recv 1)[0]) 0x4B
"--- 1. Carga ejemplo ('L')"; Load $prog
"--- 2. Dump ('D')";         $d = Dump 'D'; Check 'halted' $d.halted 0; Check 'PC' $d.w[0] 0; Check 'IF instr' $d.w[2] $prog[0]
"--- 3. Paso ('S')";         $d = Dump 'S'; Check 'PC' $d.w[0] 4; Check 'IF instr' $d.w[2] $prog[1]; Check 'IF/ID instr' $d.w[3] $prog[0]
"--- 4. Continuo ('R')";     $d = Dump 'R'; Check 'halted' $d.halted 1
                             Check 'x1' (Reg $d 1) 5; Check 'x2' (Reg $d 2) 10; Check 'x3' (Reg $d 3) 15; Check 'x4' (Reg $d 4) 0xFFFFFFFBL
                             Check 'MEM/WB pc4 (vacio)' $d.w[2+11] 0
"--- 5. pipeline.hex";
    $words = [uint32[]]@(Get-Content "$PSScriptRoot\..\programs\pipeline.hex" | ForEach-Object { ($_ -replace '(#|//|;).*$','').Trim() } |
                         Where-Object { $_ -ne '' } | ForEach-Object { [Convert]::ToUInt32($_,16) })
    Load ($words + [uint32]0)
    $d = Dump 'R'; Check 'halted' $d.halted 1
    $exp = @{1=0x5C;2=7;3=12;4=7;5=0x12345678;6=0x12345678;7=0x12345679;8=0x12;9=0x78;10=0x1234;11=0;12=0;13=6;14=106;15=1}
    foreach($k in ($exp.Keys | Sort-Object)){ Check "x$k" (Reg $d $k) $exp[$k] }
    Check 'palabras dmem' $d.mem.Count 4
    Check 'mem[0]' $d.mem[0] 0x12345678; Check 'mem[4]' $d.mem[1] 0x0007000C; Check 'mem[8]' $d.mem[2] 6; Check 'mem[12]' $d.mem[3] 106
"--- 6. Reprogramacion";     Load ([uint32[]]@(0x00100093)); $d = Dump 'D'
                             Check 'PC' $d.w[0] 0; Check 'IF instr' $d.w[2] 0x00100093; Check 'x1 (reset)' (Reg $d 1) 0; Check 'mem[0] (reset)' $d.mem[0] 0
"--- 7. Comando invalido";   Send @([byte]0x7A); Check 'nak' ([uint32](Recv 1)[0]) 0x3F
} catch { $fail++; "ERROR: $_" }
$p.Close()
if($fail -eq 0){"PLACA OK ($Port)"}else{"FALLARON $fail"}
