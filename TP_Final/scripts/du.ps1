# du.ps1 - Consola / debugger para la Debug Unit por UART
#
# Modo interactivo (sin argumentos): abre un prompt "du>"
#   .\scripts\du.ps1
#   .\scripts\du.ps1 -Port COM5
#
# Modo un solo comando:
#   .\scripts\du.ps1 S
#   .\scripts\du.ps1 L 00500093 00a00113
#
# Comandos:
#   (Enter)      un paso (igual que s)
#   s            un paso (un ciclo) y muestra la vista
#   r            correr hasta HALT y muestra la vista
#   d / v        muestra la vista sin ejecutar
#   x            reset del procesador
#   L w0 w1 ...  cargar instrucciones en hex desde la direccion 0
#   file X.hex   cargar un programa desde archivo (una palabra hex por linea)
#   mem [N]      listar las primeras N palabras de la memoria de programa
#   raw 4C 01..  mandar bytes crudos en hex y mostrar lo que vuelva
#   help / q
#
# La vista muestra las 5 instrucciones anteriores y las 5 siguientes al PC,
# desensambladas, con la instruccion actual (la que esta en IF) en verde, y al
# costado los registros x0..x9 (en amarillo los que cambiaron en el ultimo paso).
param(
    [Parameter(Position=0, ValueFromRemainingArguments=$true)][string[]]$Args_,
    [string]$Port = 'COM14'
)

$CTX      = 5      # instrucciones antes y despues del PC en la vista
$IMEM_LEN = 256    # palabras de la memoria de programa (2^ADDR_W)
$NREGS    = 10     # registros en el dump (DUMP_REGS en top.v)
$DUMP_LEN = 1 + 4 * (2 + $NREGS)   # estado + PC + instr + registros
$script:prevRegs = $null

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

# Manda D/S/R y devuelve @{halted; pc; instr; regs}
function Get-State([char]$cmd) {
    Send ([byte[]]@([byte]$cmd))
    $r = Recv $DUMP_LEN
    $regs = New-Object 'uint32[]' $NREGS
    for ($i = 0; $i -lt $NREGS; $i++) { $regs[$i] = [BitConverter]::ToUInt32($r, 9 + 4 * $i) }
    @{ halted = $r[0]; pc = [BitConverter]::ToUInt32($r, 1); instr = [BitConverter]::ToUInt32($r, 5); regs = $regs }
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
            if ($n) { return "{0,-6}{1}, {2}, {3}   -> 0x{4:X3}" -f $n, $rs1, $rs2, $immB, ($addr + $immB) }
        }
        0x6F { return "{0,-6}{1}, {2}   -> 0x{3:X3}" -f 'jal', $rd, $immJ, ($addr + $immJ) }
        0x67 { return "{0,-6}{1}, {2}({3})" -f 'jalr', $rd, $immI, $rs1 }
        0x37 { return "{0,-6}{1}, 0x{2:X}" -f 'lui', $rd, $immU }
        0x17 { return "{0,-6}{1}, 0x{2:X}" -f 'auipc', $rd, $immU }
    }
    return '???'
}

# ------------------------------------------------------------------ Vista
function Show-View($st) {
    $pcIdx = [int]($st.pc / 4)
    $first = [Math]::Max(0, $pcIdx - $CTX)
    $last  = [Math]::Min($IMEM_LEN - 1, $pcIdx + $CTX)
    $mem   = Read-Imem ($last + 1)

    Write-Host ""
    $estado = if ($st.halted) { 'HALTED' } else { 'corriendo' }
    $col    = if ($st.halted) { 'Red' } else { 'Cyan' }
    Write-Host ("  PC = 0x{0:X8}   " -f $st.pc) -NoNewline
    Write-Host $estado -ForegroundColor $col
    $W = 50   # ancho de la columna de codigo
    Write-Host ("  {0}   {1}" -f ("-" * $W), "----- registros -----")
    $nlines = [Math]::Max($last - $first + 1, $NREGS)
    for ($k = 0; $k -lt $nlines; $k++) {
        # Columna de codigo
        $i = $first + $k
        if ($i -le $last) {
            $a = 4 * $i
            $line = ("0x{0:X3}  {1:X8}  {2}" -f $a, $mem[$i], (Disasm $mem[$i] $a)).PadRight($W - 3)
            if ($i -eq $pcIdx) {
                Write-Host -NoNewline "  "
                Write-Host -NoNewline ">> $line" -ForegroundColor Black -BackgroundColor Green
            } else {
                Write-Host -NoNewline "     $line" -ForegroundColor DarkGray
            }
        } else {
            Write-Host -NoNewline ("  " + (" " * $W))
        }
        # Columna de registros
        if ($k -lt $NREGS) {
            $v = $st.regs[$k]
            $txt = "   {0,-4}0x{1:X8} {2,11}" -f "x$k", $v, [int32]$v
            $changed = $script:prevRegs -and ($script:prevRegs[$k] -ne $v)
            if ($changed) { Write-Host $txt -ForegroundColor Yellow }
            elseif ($v -eq 0) { Write-Host $txt -ForegroundColor DarkGray }
            else { Write-Host $txt }
        } else {
            Write-Host ""
        }
    }
    Write-Host ("  {0}   {1}" -f ("-" * $W), ("-" * 21))
    $script:prevRegs = $st.regs
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
            Show-View (Get-State 'D')
            return
        }
        'X' {
            Send ([byte[]]@([byte][char]'X'))
            $r = Recv 1
            if ($r[0] -eq 0x4B) { Write-Host "OK, reset" -ForegroundColor Green }
            else { Write-Host ("Respuesta inesperada: {0:X2}" -f $r[0]) -ForegroundColor Red }
            Show-View (Get-State 'D')
            return
        }
        { 'S','R','D','V' -contains $_ } {
            $cmd = if ($c -eq 'V') { 'D' } else { $c }
            Show-View (Get-State $cmd)
            return
        }
        default { Write-Host "Comando desconocido: $c (escribi help)" -ForegroundColor Yellow }
    }
}

$help = @"
Comandos:
  (Enter)       un paso
  s             un paso
  r             correr hasta HALT
  d / v         ver estado sin ejecutar
  x             reset del procesador
  L w0 w1 ...   cargar instrucciones (hex)
  file X.hex    cargar programa desde archivo
  mem [N]       listar memoria de programa (default 16 palabras)
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
