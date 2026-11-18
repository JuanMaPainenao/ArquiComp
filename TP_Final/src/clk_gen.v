`timescale 1ns/1ps
// ============================================================================
// clk_gen.v - Clock del sistema con el MMCM del Artix-7 (lo mismo que genera
// el Clocking Wizard, instanciado como primitiva para no depender de un IP).
//
// 100 MHz (placa) -> VCO = 100 * MULT / DIVCLK -> clk_out = VCO / OUT_DIV
// Default: 100 * 8 / 1 = 800 MHz -> 800 / 10 = 80 MHz.
//
// Por que: con el pipeline completo a 100 MHz el ruteo da WNS = -0.498 ns
// (el camino critico necesita ~10.5 ns). A 80 MHz (12.5 ns) sobra margen.
// El VCO tiene que quedar entre 600 y 1200 MHz (xc7a35t -1).
//
// locked = 0 mientras el MMCM no engancho: el top mantiene todo en reset.
// ============================================================================
module clk_gen #(
    parameter real MULT    = 8.0,
    parameter real OUT_DIV = 10.0
)(
    input  wire clk_in,      // 100 MHz
    output wire clk_out,
    output wire locked
);

    wire clk_fb;
    wire clk_mmcm;

    MMCME2_BASE #(
        .CLKIN1_PERIOD    (10.0),
        .DIVCLK_DIVIDE    (1),
        .CLKFBOUT_MULT_F  (MULT),
        .CLKOUT0_DIVIDE_F (OUT_DIV)
    ) u_mmcm (
        .CLKIN1   (clk_in),
        .CLKFBIN  (clk_fb),
        .CLKFBOUT (clk_fb),
        .CLKOUT0  (clk_mmcm),
        .LOCKED   (locked),
        .RST      (1'b0),
        .PWRDWN   (1'b0),
        .CLKFBOUTB(),
        .CLKOUT0B (),
        .CLKOUT1  (), .CLKOUT1B (),
        .CLKOUT2  (), .CLKOUT2B (),
        .CLKOUT3  (), .CLKOUT3B (),
        .CLKOUT4  (), .CLKOUT5  (), .CLKOUT6 ()
    );

    BUFG u_bufg (
        .I (clk_mmcm),
        .O (clk_out)
    );

endmodule
