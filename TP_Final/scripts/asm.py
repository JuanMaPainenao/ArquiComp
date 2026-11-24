# asm.py - Ensamblador RV32I (las 32 instrucciones del TP) a .hex
#
# Uso:
#   python3 scripts/asm.py programs/pipeline.s            -> programs/pipeline.hex
#   python3 scripts/asm.py programs/pipeline.s salida.hex
#
# El .hex sale en el formato que lee "file X.hex" en du.ps1:
# una palabra por linea y un comentario con la direccion y la instruccion.
#
# Sintaxis del .s:
#   - Comentarios con # o ;
#   - Etiquetas: "loop:" (solas en la linea o antes de una instruccion)
#   - Registros x0..x31
#   - Inmediatos en decimal o hex (5, -1, 0x678)
#   - Loads y stores: lw x6, 0(x0)
#   - Extras: halt (0x00000000), nop, mv rd, rs, j etiqueta, ret

import sys

# instruccion: (formato, opcode, funct3, funct7)
INSTR = {
    'add':  ('R', 0b0110011, 0b000, 0b0000000),
    'sub':  ('R', 0b0110011, 0b000, 0b0100000),
    'sll':  ('R', 0b0110011, 0b001, 0b0000000),
    'slt':  ('R', 0b0110011, 0b010, 0b0000000),
    'sltu': ('R', 0b0110011, 0b011, 0b0000000),
    'xor':  ('R', 0b0110011, 0b100, 0b0000000),
    'srl':  ('R', 0b0110011, 0b101, 0b0000000),
    'sra':  ('R', 0b0110011, 0b101, 0b0100000),
    'or':   ('R', 0b0110011, 0b110, 0b0000000),
    'and':  ('R', 0b0110011, 0b111, 0b0000000),

    'addi':  ('I', 0b0010011, 0b000, 0),
    'slti':  ('I', 0b0010011, 0b010, 0),
    'sltiu': ('I', 0b0010011, 0b011, 0),
    'xori':  ('I', 0b0010011, 0b100, 0),
    'ori':   ('I', 0b0010011, 0b110, 0),
    'andi':  ('I', 0b0010011, 0b111, 0),

    'slli': ('SH', 0b0010011, 0b001, 0b0000000),
    'srli': ('SH', 0b0010011, 0b101, 0b0000000),
    'srai': ('SH', 0b0010011, 0b101, 0b0100000),

    'lb':  ('L', 0b0000011, 0b000, 0),
    'lh':  ('L', 0b0000011, 0b001, 0),
    'lw':  ('L', 0b0000011, 0b010, 0),
    'lbu': ('L', 0b0000011, 0b100, 0),
    'lhu': ('L', 0b0000011, 0b101, 0),
    'jalr': ('L', 0b1100111, 0b000, 0),

    'sb': ('S', 0b0100011, 0b000, 0),
    'sh': ('S', 0b0100011, 0b001, 0),
    'sw': ('S', 0b0100011, 0b010, 0),

    'beq': ('B', 0b1100011, 0b000, 0),
    'bne': ('B', 0b1100011, 0b001, 0),

    'lui': ('U', 0b0110111, 0, 0),
    'jal': ('J', 0b1101111, 0, 0),
}


class AsmError(Exception):
    pass


def reg(texto):
    texto = texto.strip()
    if not texto.startswith('x'):
        raise AsmError(f"registro invalido '{texto}' (usar x0..x31)")
    try:
        n = int(texto[1:])
    except ValueError:
        raise AsmError(f"registro invalido '{texto}'")
    if n < 0 or n > 31:
        raise AsmError(f"registro fuera de rango '{texto}'")
    return n


def numero(texto):
    try:
        return int(texto.strip(), 0)   # base 0: acepta 5, -1, 0x678
    except ValueError:
        raise AsmError(f"numero invalido '{texto}'")


def chequear(valor, minimo, maximo, que):
    if valor < minimo or valor > maximo:
        raise AsmError(f"{que} = {valor} fuera de rango [{minimo}, {maximo}]")


def offset_base(texto):
    # "12(x1)" -> (12, 1)
    texto = texto.strip()
    if '(' not in texto or not texto.endswith(')'):
        raise AsmError(f"se esperaba imm(rs1) y llego '{texto}'")
    imm, rs1 = texto[:-1].split('(')
    if imm.strip() == '':
        imm = '0'
    return numero(imm), reg(rs1)


def destino(texto, etiquetas, pc):
    # Para saltos: una etiqueta o un numero (offset directo)
    texto = texto.strip()
    if texto in etiquetas:
        return etiquetas[texto] - pc
    if texto[0].isdigit() or texto[0] == '-':
        return numero(texto)
    raise AsmError(f"etiqueta '{texto}' no definida")


def pseudo(mnem, ops):
    # Traduce las pseudoinstrucciones a una instruccion real
    if mnem == 'nop':
        return 'addi', ['x0', 'x0', '0']
    if mnem == 'mv':
        return 'addi', [ops[0], ops[1], '0']
    if mnem == 'j':
        return 'jal', ['x0', ops[0]]
    if mnem == 'ret':
        return 'jalr', ['x0', '0(x1)']
    return mnem, ops


def codificar(mnem, ops, etiquetas, pc):
    if mnem == 'halt':
        return 0x00000000

    mnem, ops = pseudo(mnem, ops)

    if mnem not in INSTR:
        raise AsmError(f"instruccion desconocida '{mnem}'")
    fmt, opcode, f3, f7 = INSTR[mnem]

    cantidad = {'R': 3, 'I': 3, 'SH': 3, 'L': 2, 'S': 2, 'B': 3, 'U': 2, 'J': 2}
    if len(ops) != cantidad[fmt]:
        raise AsmError(f"'{mnem}' lleva {cantidad[fmt]} operandos y tiene {len(ops)}")

    if fmt == 'R':      # add rd, rs1, rs2
        rd, rs1, rs2 = reg(ops[0]), reg(ops[1]), reg(ops[2])
        return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | opcode

    if fmt == 'I':      # addi rd, rs1, imm
        rd, rs1, imm = reg(ops[0]), reg(ops[1]), numero(ops[2])
        chequear(imm, -2048, 2047, 'inmediato')
        return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | opcode

    if fmt == 'SH':     # slli rd, rs1, shamt
        rd, rs1, shamt = reg(ops[0]), reg(ops[1]), numero(ops[2])
        chequear(shamt, 0, 31, 'shamt')
        return (f7 << 25) | (shamt << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | opcode

    if fmt == 'L':      # lw rd, imm(rs1)   /   jalr rd, imm(rs1)
        rd = reg(ops[0])
        imm, rs1 = offset_base(ops[1])
        chequear(imm, -2048, 2047, 'offset')
        return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | opcode

    if fmt == 'S':      # sw rs2, imm(rs1)
        rs2 = reg(ops[0])
        imm, rs1 = offset_base(ops[1])
        chequear(imm, -2048, 2047, 'offset')
        imm = imm & 0xFFF
        alto = (imm >> 5) & 0x7F     # imm[11:5]
        bajo = imm & 0x1F            # imm[4:0]
        return (alto << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (bajo << 7) | opcode

    if fmt == 'B':      # beq rs1, rs2, etiqueta
        rs1, rs2 = reg(ops[0]), reg(ops[1])
        off = destino(ops[2], etiquetas, pc)
        chequear(off, -4096, 4094, 'offset del salto')
        if off % 2 != 0:
            raise AsmError("el offset del salto tiene que ser par")
        off = off & 0x1FFF
        b12   = (off >> 12) & 1
        b11   = (off >> 11) & 1
        b10_5 = (off >> 5) & 0x3F
        b4_1  = (off >> 1) & 0xF
        return ((b12 << 31) | (b10_5 << 25) | (rs2 << 20) | (rs1 << 15) |
                (f3 << 12) | (b4_1 << 8) | (b11 << 7) | opcode)

    if fmt == 'U':      # lui rd, imm20
        rd, imm = reg(ops[0]), numero(ops[1])
        chequear(imm, 0, 0xFFFFF, 'inmediato de lui')
        return (imm << 12) | (rd << 7) | opcode

    if fmt == 'J':      # jal rd, etiqueta
        rd = reg(ops[0])
        off = destino(ops[1], etiquetas, pc)
        chequear(off, -1048576, 1048574, 'offset del salto')
        if off % 2 != 0:
            raise AsmError("el offset del salto tiene que ser par")
        off = off & 0x1FFFFF
        b20    = (off >> 20) & 1
        b19_12 = (off >> 12) & 0xFF
        b11    = (off >> 11) & 1
        b10_1  = (off >> 1) & 0x3FF
        return (b20 << 31) | (b10_1 << 21) | (b11 << 20) | (b19_12 << 12) | (rd << 7) | opcode


def limpiar(linea):
    # Saca comentarios (# o ;) y espacios
    for c in '#;':
        if c in linea:
            linea = linea[:linea.index(c)]
    return linea.strip()


def separar(linea):
    # "beq x1, x2, loop" -> ('beq', ['x1', 'x2', 'loop'])
    partes = linea.split(None, 1)
    mnem = partes[0].lower()
    ops = []
    if len(partes) > 1:
        ops = [o.strip() for o in partes[1].split(',')]
    return mnem, ops


def ensamblar(lineas):
    # Pasada 1: direccion de cada etiqueta y lista de instrucciones
    etiquetas = {}
    instrucciones = []          # (numero de linea, pc, texto)
    pc = 0
    for num, linea in enumerate(lineas, start=1):
        texto = limpiar(linea)
        while ':' in texto:
            nombre, texto = texto.split(':', 1)
            nombre = nombre.strip()
            texto = texto.strip()
            if nombre in etiquetas:
                raise AsmError(f"linea {num}: etiqueta '{nombre}' repetida")
            etiquetas[nombre] = pc
        if texto != '':
            instrucciones.append((num, pc, texto))
            pc += 4

    # Pasada 2: codificar
    salida = []                 # (pc, palabra, texto)
    for num, pc, texto in instrucciones:
        mnem, ops = separar(texto)
        try:
            palabra = codificar(mnem, ops, etiquetas, pc)
        except AsmError as e:
            raise AsmError(f"linea {num}: {e}  ->  {texto}")
        salida.append((pc, palabra, texto))
    return salida


def main():
    if len(sys.argv) < 2:
        print("Uso: python3 asm.py programa.s [salida.hex]")
        sys.exit(1)

    entrada = sys.argv[1]
    if len(sys.argv) > 2:
        destino_hex = sys.argv[2]
    elif entrada.endswith('.s'):
        destino_hex = entrada[:-2] + '.hex'
    else:
        destino_hex = entrada + '.hex'

    with open(entrada) as f:
        lineas = f.readlines()

    try:
        salida = ensamblar(lineas)
    except AsmError as e:
        print(f"Error en {entrada}, {e}")
        sys.exit(1)

    tiene_halt = False
    for pc, palabra, texto in salida:
        if palabra == 0:
            tiene_halt = True
    if not tiene_halt:
        print("Aviso: el programa no tiene halt")

    with open(destino_hex, 'w') as f:
        f.write(f"# Generado por asm.py desde {entrada}\n")
        for pc, palabra, texto in salida:
            f.write(f"{palabra:08x}   # 0x{pc:03X}  {texto}\n")

    print(f"{len(salida)} instrucciones -> {destino_hex}")


if __name__ == '__main__':
    main()
