`timescale 1ns/1ps
// clk_gen.v - MMCM que pasa los 100 MHz de la placa a 80 MHz (100 * 8 / 10).
// Mientras locked = 0 el top mantiene todo en reset. Ver docs/timing.md.
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
