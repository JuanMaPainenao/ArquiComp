# du.ps1 - Consola / debugger para la Debug Unit por UART
#
# Modo interactivo (sin argumentos): abre un prompt "du>"
#   .\scripts\du.ps1
#   .\scripts\du.ps1 -Port COM5          (sin -Port busca el puerto FTDI de la Basys 3)
#
# Modo un solo comando:
#   .\scripts\du.ps1 S
#   .\scripts\du.ps1 file programs\pipeline.hex
#
# Comandos:
#   (Enter)      un paso (igual que s)
#   s [N]        N pasos (un ciclo cada uno, default 1) y muestra la vista
#   r            correr hasta HALT y muestra la vista
#   d / v        muestra la vista sin ejecutar
#   x            reset del procesador
#   L w0 w1 ...  cargar instrucciones en hex desde la direccion 0
#   file X.hex   cargar un programa desde archivo (una palabra hex por linea)
#   mem [N]      listar las primeras N palabras de la memoria de programa
#   dmem         memoria de datos usada (palabras, bytes y valor con signo)
#   lat          contenido crudo de los latches intermedios
#   raw 4C 01..  mandar bytes crudos en hex y mostrar lo que vuelva
#   help / q
#
# La vista muestra:
#   - Pipeline: que instruccion hay en cada etapa (IF ID EX MEM WB), con los
#     datos de su latch, y los riesgos del ciclo (stall, flush, forwarding).
#   - Codigo alrededor del PC con la etapa en la que esta cada instruccion.
#   - Los 32 registros (en amarillo los que cambiaron en el ultimo comando).
#   - La memoria de datos usada (en amarillo las palabras que cambiaron).
#
# Formato del dump (ver src/top.v): 1 byte de estado (bit0 = halted) y despues
# palabras de 32 bits little-endian: PC, M, 20 latches, x0..x31, M palabras de
# memoria de datos.
param(
    [Parameter(Position=0, ValueFromRemainingArguments=$true)][string[]]$Args_,
    [string]$Port = ''
)

$CTX      = 4      # instrucciones antes y despues del PC en la vista
$IMEM_LEN = 256    # palabras de la memoria de programa (2^IMEM_ADDR_W)
$N_LAT    = 20     # latches en el dump (N_LAT en top.v)
$N_FIXED  = 2 + $N_LAT + 32                  # PC, M, latches, registros
$FIXED_LEN = 1 + 4 * $N_FIXED                # bytes antes de la memoria
$script:prev  = $null
$script:ciclo = 0

# Si no se pasa -Port se busca el puerto USB-serie FTDI (la Basys 3)
if ($Port -eq '') {
    $ftdi = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue |
            Where-Object { $_.Manufacturer -eq 'FTDI' -and $_.Name -match '\((COM\d+)\)' } |
            Select-Object -First 1
    if ($ftdi) { $Port = [regex]::Match($ftdi.Name, 'COM\d+').Value } else { $Port = 'COM14' }
}

$p = New-Object System.IO.Ports.SerialPort $Port,38400,'None',8,'One'
$p.ReadTimeout = 3000
try { $p.Open() } catch { Write-Host "No pude abrir $Port : $_" -ForegroundColor Red; exit 1 }
$p.DiscardInBuffer()

# ------------------------------------------------------------------ UART
function Hex([byte[]]$b) { ($b | ForEach-Object { '{0:X2}' -f $_ }) -join ' ' }

function Recv([int]$n) {
    $buf = New-Object byte[] $n; $got = 0
    while ($got -lt $n) { $got += $p.Read($buf, $got, $n - $got) }
    ,$buf
}

function Send([byte[]]$tx) { $p.Write($tx, 0, $tx.Length) }

# Manda D/S/R y devuelve el estado completo
function Get-State([char]$cmd) {
    Send ([byte[]]@([byte]$cmd))
    $r = Recv $FIXED_LEN
    $w = New-Object 'uint32[]' $N_FIXED
    for ($i = 0; $i -lt $N_FIXED; $i++) { $w[$i] = [BitConverter]::ToUInt32($r, 1 + 4 * $i) }
    $m  = [int]$w[1]
    $rm = Recv (4 * $m)
    $mem = New-Object 'uint32[]' $m
    for ($i = 0; $i -lt $m; $i++) { $mem[$i] = [BitConverter]::ToUInt32($rm, 4 * $i) }
    @{
        halted = ($r[0] -band 1)
        pc     = $w[0]
        lat    = $w[2..(1 + $N_LAT)]
        regs   = $w[(2 + $N_LAT)..($N_FIXED - 1)]
        dmem   = $mem
    }
}

# Lee las primeras n palabras de la memoria de programa (comando 'P')
function Read-Imem([int]$n) {
    Send ([byte[]]@([byte][char]'P', [byte]($n -band 0xFF), [byte]($n -shr 8)))
    $r = Recv (4 * $n)
    $w = New-Object 'uint32[]' $n
    for ($i = 0; $i -lt $n; $i++) { $w[$i] = [BitConverter]::ToUInt32($r, 4 * $i) }
    ,$w
}

# ------------------------------------------------------------------ Desensamblador RV32I
function Bits([uint32]$w, [int]$hi, [int]$lo) { ([int64]$w -shr $lo) -band ((1L -shl ($hi - $lo + 1)) - 1) }
function Sext([int64]$v, [int]$bits) { if ($v -band (1L -shl ($bits - 1))) { $v - (1L -shl $bits) } else { $v } }

function Disasm([uint32]$w, [int64]$addr) {
    if ($w -eq 0) { return 'HALT' }
    $op  = Bits $w 6 0
    $rd  = 'x' + (Bits $w 11 7)
    $f3  = Bits $w 14 12
    $rs1 = 'x' + (Bits $w 19 15)
    $rs2 = 'x' + (Bits $w 24 20)
    $f7  = Bits $w 31 25
    $immI = Sext (Bits $w 31 20) 12
    $immS = Sext (((Bits $w 31 25) -shl 5) -bor (Bits $w 11 7)) 12
    $immB = Sext (((Bits $w 31 31) -shl 12) -bor ((Bits $w 7 7) -shl 11) -bor ((Bits $w 30 25) -shl 5) -bor ((Bits $w 11 8) -shl 1)) 13
    $immJ = Sext (((Bits $w 31 31) -shl 20) -bor ((Bits $w 19 12) -shl 12) -bor ((Bits $w 20 20) -shl 11) -bor ((Bits $w 30 21) -shl 1)) 21
    $immU = Bits $w 31 12

    switch ($op) {
        0x33 {
            $n = switch ($f3) {
                0 { if ($f7 -eq 0x20) { 'sub' } else { 'add' } }
                1 { 'sll' } 2 { 'slt' } 3 { 'sltu' } 4 { 'xor' }
                5 { if ($f7 -eq 0x20) { 'sra' } else { 'srl' } }
                6 { 'or' } 7 { 'and' }
            }
            return "{0,-6}{1}, {2}, {3}" -f $n, $rd, $rs1, $rs2
        }
        0x13 {
            if ($w -eq 0x13) { return 'nop' }
            $sh = Bits $w 24 20
            switch ($f3) {
                1 { return "{0,-6}{1}, {2}, {3}" -f 'slli', $rd, $rs1, $sh }
                5 { $n = if ($f7 -eq 0x20) { 'srai' } else { 'srli' }; return "{0,-6}{1}, {2}, {3}" -f $n, $rd, $rs1, $sh }
            }
            $n = @{0='addi';2='slti';3='sltiu';4='xori';6='ori';7='andi'}[[int]$f3]
            return "{0,-6}{1}, {2}, {3}" -f $n, $rd, $rs1, $immI
        }
        0x03 {
            $n = @{0='lb';1='lh';2='lw';4='lbu';5='lhu'}[[int]$f3]
            if ($n) { return "{0,-6}{1}, {2}({3})" -f $n, $rd, $immI, $rs1 }
        }
        0x23 {
            $n = @{0='sb';1='sh';2='sw'}[[int]$f3]
            if ($n) { return "{0,-6}{1}, {2}({3})" -f $n, $rs2, $immS, $rs1 }
        }
        0x63 {
            $n = @{0='beq';1='bne';4='blt';5='bge';6='bltu';7='bgeu'}[[int]$f3]
            if ($n) { return "{0,-6}{1}, {2}, {3} ->0x{4:X3}" -f $n, $rs1, $rs2, $immB, ($addr + $immB) }
        }
        0x6F { return "{0,-6}{1}, {2} ->0x{3:X3}" -f 'jal', $rd, $immJ, ($addr + $immJ) }
        0x67 { return "{0,-6}{1}, {2}({3})" -f 'jalr', $rd, $immI, $rs1 }
        0x37 { return "{0,-6}{1}, 0x{2:X}" -f 'lui', $rd, $immU }
        0x17 { return "{0,-6}{1}, 0x{2:X}" -f 'auipc', $rd, $immU }
    }
    return '???'
}

# ------------------------------------------------------------------ Vista
$FWD = @('ID', 'MEM', 'WB', '?')

# Direccion de la instruccion que tiene un latch (pc4 = 0 -> burbuja)
function Stage-Addr([uint32]$pc4) { if ($pc4 -eq 0) { -1 } else { [int64]$pc4 - 4 } }

function Imem-Word($imem, [int64]$a) {
    $i = [int]($a / 4)
    if ($a -ge 0 -and $i -lt $imem.Length) { $imem[$i] } else { [uint32]0 }
}

function Fmt-Hex([uint32]$v) { '0x{0:X8}' -f $v }

function Show-Pipeline($st, $imem) {
    $L  = $st.lat
    $hz = $L[15]
    $c7 = $L[7]; $c10 = $L[10]; $c14 = $L[14]

    # IF
    $stages = @()
    $stages += ,@('IF',  [int64]$st.pc, $L[0], '')
    # ID
    $aID = Stage-Addr $L[2]
    $stages += ,@('ID',  $aID, $L[1], '')
    # EX
    $aEX = Stage-Addr $L[3]
    $info = ''
    if ($aEX -ge 0) {
        $rs1 = Bits $c7 26 22; $rs2 = Bits $c7 21 17
        $fa = $FWD[(Bits $hz 6 5)]; $fb = $FWD[(Bits $hz 8 7)]
        $info = "rs1 x{0}={1}[{2}] rs2 x{3}={4}[{5}] imm={6} alu={7}" -f $rs1, (Fmt-Hex $L[4]), $fa, $rs2, (Fmt-Hex $L[5]), $fb, (Sext $L[6] 32), (Fmt-Hex $L[16])
        if ($hz -band 8) { $info += " -> SALTA a 0x{0:X3}" -f $L[17] }
    }
    $stages += ,@('EX',  $aEX, (Imem-Word $imem $aEX), $info)
    # MEM
    $aMEM = Stage-Addr $L[8]
    $info = ''
    if ($aMEM -ge 0) {
        if (Bits $c10 21 21)     { $info = "M[0x{0:X3}] <- {1}" -f $L[9], (Fmt-Hex $L[19]) }
        elseif (Bits $c10 22 22) { $info = "lee M[0x{0:X3}]" -f $L[9] }
        else                     { $info = "alu={0}" -f (Fmt-Hex $L[9]) }
    }
    $stages += ,@('MEM', $aMEM, (Imem-Word $imem $aMEM), $info)
    # WB
    $aWB = Stage-Addr $L[11]
    $info = ''
    if ($aWB -ge 0) {
        $rd = Bits $c14 31 27
        if ((Bits $c14 23 23) -and $rd -ne 0) { $info = "x{0} <- {1}" -f $rd, (Fmt-Hex $L[18]) }
        elseif (Bits $c14 18 18)              { $info = 'HALT llego a WB' }
        else                                  { $info = '(no escribe)' }
    }
    $stages += ,@('WB',  $aWB, (Imem-Word $imem $aWB), $info)

    Write-Host "  ---- pipeline ------------------------------------------------------------------" -ForegroundColor DarkCyan
    foreach ($s in $stages) {
        Write-Host -NoNewline ("  {0,-4}" -f $s[0]) -ForegroundColor Cyan
        if ($s[1] -lt 0) {
            Write-Host "  --    (burbuja)" -ForegroundColor DarkGray
        } else {
            Write-Host -NoNewline ("0x{0:X3}  {1,-26}" -f $s[1], (Disasm $s[2] $s[1]))
            Write-Host ("  " + $s[3]) -ForegroundColor Gray
        }
    }
    $r = @()
    if ($hz -band 1)  { $r += 'STALL load-use (PC e IF/ID quietos, burbuja en ID/EX)' }
    if ($hz -band 8)  { $r += 'SALTO tomado (flush IF/ID e ID/EX)' }
    elseif ($hz -band 2) { $r += 'flush IF/ID' }
    if ($hz -band 16) { $r += 'HALT: fetch frenado' }
    if (Bits $hz 6 5) { $r += 'fwd A desde ' + $FWD[(Bits $hz 6 5)] }
    if (Bits $hz 8 7) { $r += 'fwd B desde ' + $FWD[(Bits $hz 8 7)] }
    if ($r.Count -eq 0) { $r = @('ninguno') }
    Write-Host ("  riesgos (proximo flanco): " + ($r -join ' | ')) -ForegroundColor Magenta
    $stages
}

function Show-Code($st, $imem, $stages) {
    $pcIdx = [int]($st.pc / 4)
    $first = [Math]::Max(0, $pcIdx - $CTX - 4)
    $last  = [Math]::Min($IMEM_LEN - 1, $pcIdx + $CTX)
    Write-Host "  ---- codigo --------------------------------------------------------------------" -ForegroundColor DarkCyan
    for ($i = $first; $i -le $last; $i++) {
        $a = 4 * $i
        $tags = @($stages | Where-Object { $_[1] -eq $a } | ForEach-Object { $_[0] })
        $tag = ($tags -join ',')
        $line = ("0x{0:X3}  {1:X8}  {2,-28} {3}" -f $a, $imem[$i], (Disasm $imem[$i] $a), $tag)
        if ($i -eq $pcIdx) {
            Write-Host -NoNewline "  "
            Write-Host ">> $line" -ForegroundColor Black -BackgroundColor Green
        } elseif ($tag) {
            Write-Host "     $line" -ForegroundColor White
        } else {
            Write-Host "     $line" -ForegroundColor DarkGray
        }
    }
}

function Show-Regs($st) {
    Write-Host "  ---- registros -----------------------------------------------------------------" -ForegroundColor DarkCyan
    for ($row = 0; $row -lt 8; $row++) {
        Write-Host -NoNewline "  "
        for ($col = 0; $col -lt 4; $col++) {
            $k = $row + 8 * $col
            $v = $st.regs[$k]
            $txt = "{0,-4}{1:X8} {2,11}   " -f "x$k", $v, [int32]$v
            $changed = $script:prev -and ($script:prev.regs[$k] -ne $v)
            if ($changed) { Write-Host -NoNewline $txt -ForegroundColor Yellow }
            elseif ($v -eq 0) { Write-Host -NoNewline $txt -ForegroundColor DarkGray }
            else { Write-Host -NoNewline $txt }
        }
        Write-Host ""
    }
}

function Show-Dmem($st, [switch]$Full) {
    $m = $st.dmem.Length
    Write-Host ("  ---- memoria de datos (usada: 0x000..0x{0:X3}, {1} palabras) ---------------------" -f (4 * $m - 1), $m) -ForegroundColor DarkCyan
    $max = if ($Full) { $m } else { [Math]::Min($m, 16) }
    for ($i = 0; $i -lt $max; $i++) {
        $v = $st.dmem[$i]
        $b = [BitConverter]::GetBytes($v)
        $txt = "  0x{0:X3}  {1:X8}   bytes {2}   {3,11}" -f (4 * $i), $v, (Hex $b), [int32]$v
        $changed = $script:prev -and (($i -ge $script:prev.dmem.Length) -or ($script:prev.dmem[$i] -ne $v))
        if ($changed) { Write-Host $txt -ForegroundColor Yellow }
        elseif ($v -eq 0) { Write-Host $txt -ForegroundColor DarkGray }
        else { Write-Host $txt }
    }
    if ($max -lt $m) { Write-Host "  ... ($($m - $max) palabras mas, usar 'dmem')" -ForegroundColor DarkGray }
}

function Show-View($st) {
    # Hay que leer hasta la mayor direccion que este en alguna etapa
    $n = [int]($st.pc / 4) + $CTX + 1
    foreach ($k in 2, 3, 8, 11) { $n = [Math]::Max($n, [int]($st.lat[$k] / 4)) }
    $imem  = Read-Imem ([Math]::Min($IMEM_LEN, $n))

    Write-Host ""
    $estado = if ($st.halted) { 'HALTED (pipeline vacio)' } else { 'corriendo' }
    $col    = if ($st.halted) { 'Red' } else { 'Cyan' }
    Write-Host ("  ciclo {0,-5} PC = 0x{1:X8}   " -f $script:ciclo, $st.pc) -NoNewline
    Write-Host $estado -ForegroundColor $col
    $stages = Show-Pipeline $st $imem
    Show-Code $st $imem $stages
    Show-Regs $st
    Show-Dmem $st
    $script:prev = $st
}

function Show-Latches($st) {
    $names = @('IF  instr', 'IF/ID instr', 'IF/ID pc4', 'ID/EX pc4', 'ID/EX rs1_data', 'ID/EX rs2_data',
               'ID/EX imm', 'ID/EX ctrl', 'EX/MEM pc4', 'EX/MEM alu_result', 'EX/MEM ctrl',
               'MEM/WB pc4', 'MEM/WB alu_result', 'MEM/WB load_data', 'MEM/WB ctrl', 'riesgos',
               'EX alu (comb.)', 'EX destino salto', 'WB dato a rd', 'EX/MEM store_data')
    for ($i = 0; $i -lt $N_LAT; $i++) { Write-Host ("  {0,2}  {1,-18} {2}" -f $i, $names[$i], (Fmt-Hex $st.lat[$i])) }
    $c = $st.lat[7]
    Write-Host ("  ID/EX ctrl: rd=x{0} rs1=x{1} rs2=x{2} f3={3} f7b5={4} reg_write={5} alu_src={6} alu_op={7} mem_read={8} mem_write={9} wb_sel={10} branch={11} jump={12} jalr={13} halt={14}" -f `
        (Bits $c 31 27), (Bits $c 26 22), (Bits $c 21 17), (Bits $c 16 14), (Bits $c 13 13), (Bits $c 12 12), (Bits $c 11 11),
        (Bits $c 10 9), (Bits $c 8 8), (Bits $c 7 7), (Bits $c 6 5), (Bits $c 4 4), (Bits $c 3 3), (Bits $c 2 2), (Bits $c 1 1))
    foreach ($k in 10, 14) {
        $c = $st.lat[$k]
        Write-Host ("  {0} ctrl: rd=x{1} f3={2} reg_write={3} mem_read={4} mem_write={5} wb_sel={6} halt={7}" -f `
            $(if ($k -eq 10) { 'EX/MEM' } else { 'MEM/WB' }), (Bits $c 31 27), (Bits $c 26 24), (Bits $c 23 23),
            (Bits $c 22 22), (Bits $c 21 21), (Bits $c 20 19), (Bits $c 18 18))
    }
}

# ------------------------------------------------------------------ Comandos
function Run-Cmd([string[]]$tok) {
    $c = $tok[0].ToUpper()
    $rest = @($tok | Select-Object -Skip 1)

    switch ($c) {
        'RAW' {
            $tx = [byte[]]($rest | ForEach-Object { [Convert]::ToByte($_, 16) })
            Send $tx
            Write-Host ("TX: " + (Hex $tx))
            Start-Sleep -Milliseconds 300
            $n = $p.BytesToRead
            if ($n -gt 0) { Write-Host ("RX: " + (Hex (Recv $n))) } else { Write-Host "RX: (nada)" }
            return
        }
        'MEM' {
            $n = 16
            if ($rest.Count -ge 1) { $n = [int]$rest[0] }
            if ($n -lt 1 -or $n -gt $IMEM_LEN) { Write-Host "Uso: mem [N]   (1..$IMEM_LEN, default 16)"; return }
            $mem = Read-Imem $n
            for ($i = 0; $i -lt $n; $i++) {
                Write-Host ("  0x{0:X3}  {1:X8}  {2}" -f (4 * $i), $mem[$i], (Disasm $mem[$i] (4 * $i)))
            }
            return
        }
        'DMEM' {
            $st = Get-State 'D'
            Show-Dmem $st -Full
            $script:prev = $st
            return
        }
        'LAT' {
            Show-Latches (Get-State 'D')
            return
        }
        'FILE' {
            if ($rest.Count -ne 1) { Write-Host "Uso: file programa.hex"; return }
            if (-not (Test-Path $rest[0])) { Write-Host "No existe $($rest[0])" -ForegroundColor Red; return }
            $words = @(); $n = 0
            foreach ($line in Get-Content $rest[0]) {
                $n++
                $l = ($line -replace '(#|//|;).*$', '').Trim() -replace '^0x', ''
                if ($l -eq '') { continue }
                if ($l -notmatch '^[0-9a-fA-F]{1,8}$') { Write-Host "Linea ${n}: '$line' no es una palabra hex" -ForegroundColor Red; return }
                $words += $l
            }
            if ($words.Count -eq 0) { Write-Host "El archivo no tiene instrucciones"; return }
            if ([Convert]::ToUInt32($words[-1], 16) -ne 0) { $words += '00000000'; Write-Host "(agrego HALT al final)" }
            if ($words.Count -gt $IMEM_LEN) { Write-Host "El programa tiene $($words.Count) instrucciones y la memoria tiene $IMEM_LEN" -ForegroundColor Red; return }
            Write-Host "Cargando $($words.Count) instrucciones de $($rest[0])..."
            Run-Cmd (@('L') + $words)
            return
        }
        'L' {
            if ($rest.Count -eq 0) { Write-Host "Uso: L 00500093 00a00113 ..."; return }
            $tx = @([byte][char]'L', [byte]($rest.Count -band 0xFF), [byte]($rest.Count -shr 8))
            foreach ($w in $rest) { $tx += [BitConverter]::GetBytes([Convert]::ToUInt32($w, 16)) }
            Send ([byte[]]$tx)
            $r = Recv 1
            if ($r[0] -eq 0x4B) { Write-Host "OK, cargado ($($rest.Count) instrucciones)" -ForegroundColor Green }
            else { Write-Host ("Respuesta inesperada: {0:X2}" -f $r[0]) -ForegroundColor Red }
            $script:ciclo = 0; $script:prev = $null
            Show-View (Get-State 'D')
            return
        }
        'X' {
            Send ([byte[]]@([byte][char]'X'))
            $r = Recv 1
            if ($r[0] -eq 0x4B) { Write-Host "OK, reset" -ForegroundColor Green }
            else { Write-Host ("Respuesta inesperada: {0:X2}" -f $r[0]) -ForegroundColor Red }
            $script:ciclo = 0; $script:prev = $null
            Show-View (Get-State 'D')
            return
        }
        'S' {
            $n = 1
            if ($rest.Count -ge 1) { $n = [int]$rest[0] }
            $st = $null
            for ($k = 0; $k -lt $n; $k++) {
                # cpu_en se corta con halted: si ya estaba halted, el paso no ejecuta
                if (($script:ciclo -is [int]) -and -not ($script:prev -and $script:prev.halted)) { $script:ciclo++ }
                $st = Get-State 'S'
                if ($st.halted) { break }
            }
            Show-View $st
            return
        }
        'R' {
            try { $st = Get-State 'R' }
            catch {
                Write-Host "No llego a HALT en 3 s (programa sin HALT o loop infinito)." -ForegroundColor Red
                Write-Host "La Debug Unit sigue en modo continuo: apreta BTNC (reset) en la placa." -ForegroundColor Red
                return
            }
            $script:ciclo = '?'
            Show-View $st
            return
        }
        { 'D','V' -contains $_ } {
            Show-View (Get-State 'D')
            return
        }
        default { Write-Host "Comando desconocido: $c (escribi help)" -ForegroundColor Yellow }
    }
}

$help = @"
Comandos:
  (Enter)       un paso (un ciclo de clock)
  s [N]         N pasos
  r             correr hasta HALT
  d / v         ver estado sin ejecutar
  x             reset del procesador
  L w0 w1 ...   cargar instrucciones (hex)
  file X.hex    cargar programa desde archivo (ej: file programs\pipeline.hex)
  mem [N]       listar memoria de programa (default 16 palabras)
  dmem          memoria de datos usada completa
  lat           latches intermedios en crudo
  raw 44 ...    mandar bytes crudos (hex)
  q             salir
"@

try {
    if ($Args_.Count -gt 0) {
        Run-Cmd $Args_
    } else {
        Write-Host "Debug Unit en $Port @ 38400. Enter = un paso, help = comandos, q = salir."
        Show-View (Get-State 'D')
        while ($true) {
            Write-Host -NoNewline "du> "
            $line = [Console]::ReadLine()
            if ($null -eq $line) { break }
            $tok = @($line.Trim() -split '\s+' | Where-Object { $_ -ne '' })
            if ($tok.Count -eq 0) { $tok = @('S') }      # Enter solo = un paso
            if ('q','quit','exit' -contains $tok[0].ToLower()) { break }
            if ($tok[0].ToLower() -eq 'help') { Write-Host $help; continue }
            try { Run-Cmd $tok } catch { Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red; $p.DiscardInBuffer() }
        }
    }
}
finally { $p.Close() }
