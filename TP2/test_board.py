"""
Prueba top_uart_alu en la Basys3 real via el puerto serie USB.

Protocolo (igual al del testbench): se mandan 3 bytes (A, B, OP) y se
espera 1 byte de vuelta con el resultado.

Uso:
    pip install pyserial
    python test_board.py COM5
    python test_board.py COM5 --baud 38400
    python test_board.py COM5 --a 10 --b 3 --op 0x20   # ADD puntual
"""
import argparse
import random
import sys
import time

import serial

OP_ADD = 0b100000
OP_SUB = 0b100010
OP_AND = 0b100100
OP_OR  = 0b100101
OP_XOR = 0b100110
OP_SRA = 0b000011
OP_SRL = 0b000010
OP_NOR = 0b100111

OPS = {
    "ADD": OP_ADD, "SUB": OP_SUB, "AND": OP_AND, "OR": OP_OR,
    "XOR": OP_XOR, "SRA": OP_SRA, "SRL": OP_SRL, "NOR": OP_NOR,
}


def modelo(a, b, op):
    a &= 0xFF
    b &= 0xFF
    if op == OP_ADD:
        return (a + b) & 0xFF
    if op == OP_SUB:
        return (a - b) & 0xFF
    if op == OP_AND:
        return a & b
    if op == OP_OR:
        return a | b
    if op == OP_XOR:
        return a ^ b
    if op == OP_SRL:
        return (a >> b) & 0xFF
    if op == OP_SRA:
        signed = a - 256 if a & 0x80 else a
        return (signed >> b) & 0xFF
    if op == OP_NOR:
        return (~(a | b)) & 0xFF
    return 0


def run_one(ser, a, b, op, verbose=True):
    ser.reset_input_buffer()
    ser.write(bytes([a & 0xFF, b & 0xFF, op & 0x3F]))
    res = ser.read(1)
    esperado = modelo(a, b, op)
    if len(res) != 1:
        if verbose:
            print(f"A={a:3d} B={b:3d} OP={op:06b} -> SIN RESPUESTA (timeout)")
        return False
    recibido = res[0]
    ok = recibido == esperado
    if verbose:
        estado = "OK   " if ok else "ERROR"
        print(f"{estado} A={a:3d} B={b:3d} OP={op:06b} | RES={recibido:3d} esperado={esperado:3d}")
    return ok


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("port", help="Puerto COM del USB-UART de la Basys3 (ej: COM5)")
    parser.add_argument("--baud", type=int, default=38400,
                         help="Baudrate (default 38400; el divisor actual da ~38110, "
                              "probar 38400 primero y si falla usar el valor exacto)")
    parser.add_argument("--timeout", type=float, default=1.0)
    parser.add_argument("--a", type=lambda x: int(x, 0))
    parser.add_argument("--b", type=lambda x: int(x, 0))
    parser.add_argument("--op", type=lambda x: int(x, 0))
    parser.add_argument("--n", type=int, default=8, help="Cantidad de vectores aleatorios si no se pasa --a/--b/--op")
    args = parser.parse_args()

    ser = serial.Serial(args.port, args.baud, bytesize=8, parity="N", stopbits=1, timeout=args.timeout)
    time.sleep(0.2)  # dar tiempo a que el puerto se estabilice

    if args.a is not None and args.b is not None and args.op is not None:
        ok = run_one(ser, args.a, args.b, args.op)
        sys.exit(0 if ok else 1)

    errores = 0
    for _ in range(args.n):
        a = random.randint(0, 255)
        b = random.randint(0, 255)
        op = random.choice(list(OPS.values()))
        if not run_one(ser, a, b, op):
            errores += 1

    print()
    if errores == 0:
        print(f"TEST OK: {args.n} vectores sin errores.")
    else:
        print(f"TEST FALLIDO: {errores} errores sobre {args.n} vectores.")
    ser.close()


if __name__ == "__main__":
    main()
