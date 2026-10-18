// GPL-2.0-or-later. Port list matches the Analogue Pocket APF (apf_top.v).
`default_nettype none
module core_top (

    //
    // physical connections
    //

    ///////////////////////////////////////////////////
    // clock inputs 74.25mhz. not phase aligned, so treat these domains as asynchronous

    input wire clk_74a,  // mainclk1
    input wire clk_74b,  // mainclk1

    ///////////////////////////////////////////////////
    // cartridge interface
    // switches between 3.3v and 5v mechanically
    // output enable for multibit translators controlled by pic32

    // GBA AD[15:8]
    inout  wire [7:0] cart_tran_bank2,
    output wire       cart_tran_bank2_dir,

    // GBA AD[7:0]
    inout  wire [7:0] cart_tran_bank3,
    output wire       cart_tran_bank3_dir,

    // GBA A[23:16]
    inout  wire [7:0] cart_tran_bank1,
    output wire       cart_tran_bank1_dir,

    // GBA [7] PHI#
    // GBA [6] WR#
    // GBA [5] RD#
    // GBA [4] CS1#/CS#
    //     [3:0] unwired
    inout  wire [7:4] cart_tran_bank0,
    output wire       cart_tran_bank0_dir,

    // GBA CS2#/RES#
    inout  wire cart_tran_pin30,
    output wire cart_tran_pin30_dir,
    // when GBC cart is inserted, this signal when low or weak will pull GBC /RES low with a special circuit
    // the goal is that when unconfigured, the FPGA weak pullups won't interfere.
    // thus, if GBC cart is inserted, FPGA must drive this high in order to let the level translators
    // and general IO drive this pin.
    output wire cart_pin30_pwroff_reset,

    // GBA IRQ/DRQ
    inout  wire cart_tran_pin31,
    output wire cart_tran_pin31_dir,

    // infrared
    input  wire port_ir_rx,
    output wire port_ir_tx,
    output wire port_ir_rx_disable,

    // GBA link port
    inout  wire port_tran_si,
    output wire port_tran_si_dir,
    inout  wire port_tran_so,
    output wire port_tran_so_dir,
    inout  wire port_tran_sck,
    output wire port_tran_sck_dir,
    inout  wire port_tran_sd,
    output wire port_tran_sd_dir,

    ///////////////////////////////////////////////////
    // cellular psram 0 and 1, two chips (64mbit x2 dual die per chip)

    output wire [21:16] cram0_a,
    inout  wire [ 15:0] cram0_dq,
    input  wire         cram0_wait,
    output wire         cram0_clk,
    output wire         cram0_adv_n,
    output wire         cram0_cre,
    output wire         cram0_ce0_n,
    output wire         cram0_ce1_n,
    output wire         cram0_oe_n,
    output wire         cram0_we_n,
    output wire         cram0_ub_n,
    output wire         cram0_lb_n,

    output wire [21:16] cram1_a,
    inout  wire [ 15:0] cram1_dq,
    input  wire         cram1_wait,
    output wire         cram1_clk,
    output wire         cram1_adv_n,
    output wire         cram1_cre,
    output wire         cram1_ce0_n,
    output wire         cram1_ce1_n,
    output wire         cram1_oe_n,
    output wire         cram1_we_n,
    output wire         cram1_ub_n,
    output wire         cram1_lb_n,

    ///////////////////////////////////////////////////
    // sdram, 512mbit 16bit

    output wire [12:0] dram_a,
    output wire [ 1:0] dram_ba,
    inout  wire [15:0] dram_dq,
    output wire [ 1:0] dram_dqm,
    output wire        dram_clk,
    output wire        dram_cke,
    output wire        dram_ras_n,
    output wire        dram_cas_n,
    output wire        dram_we_n,

    ///////////////////////////////////////////////////
    // sram, 1mbit 16bit

    output wire [16:0] sram_a,
    inout  wire [15:0] sram_dq,
    output wire        sram_oe_n,
    output wire        sram_we_n,
    output wire        sram_ub_n,
    output wire        sram_lb_n,

    ///////////////////////////////////////////////////
    // vblank driven by dock for sync in a certain mode

    input wire vblank,

    ///////////////////////////////////////////////////
    // i/o to 6515D breakout usb uart

    output wire dbg_tx,
    input  wire dbg_rx,

    ///////////////////////////////////////////////////
    // i/o pads near jtag connector user can solder to

    output wire user1,
    input  wire user2,

    ///////////////////////////////////////////////////
    // RFU internal i2c bus

    inout  wire aux_sda,
    output wire aux_scl,

    ///////////////////////////////////////////////////
    // RFU, do not use
    output wire vpll_feed,


    //
    // logical connections
    //

    ///////////////////////////////////////////////////
    // video, audio output to scaler
    output wire [23:0] video_rgb,
    output wire        video_rgb_clock,
    output wire        video_rgb_clock_90,
    output wire        video_de,
    output wire        video_skip,
    output wire        video_vs,
    output wire        video_hs,

    output wire audio_mclk,
    input  wire audio_adc,
    output wire audio_dac,
    output wire audio_lrck,

    ///////////////////////////////////////////////////
    // bridge bus connection
    // synchronous to clk_74a
    output wire        bridge_endian_little,
    input  wire [31:0] bridge_addr,
    input  wire        bridge_rd,
    output wire [31:0] bridge_rd_data,
    input  wire        bridge_wr,
    input  wire [31:0] bridge_wr_data,

    ///////////////////////////////////////////////////
    // controller data
    //
    // key bitmap:
    //   [0]    dpad_up
    //   [1]    dpad_down
    //   [2]    dpad_left
    //   [3]    dpad_right
    //   [4]    face_a
    //   [5]    face_b
    //   [6]    face_x
    //   [7]    face_y
    //   [8]    trig_l1
    //   [9]    trig_r1
    //   [10]   trig_l2
    //   [11]   trig_r2
    //   [12]   trig_l3
    //   [13]   trig_r3
    //   [14]   face_select
    //   [15]   face_start
    //   [28:16] <unused>
    //   [31:29] type
    // joy values - unsigned
    //   [ 7: 0] lstick_x
    //   [15: 8] lstick_y
    //   [23:16] rstick_x
    //   [31:24] rstick_y
    // trigger values - unsigned
    //   [ 7: 0] ltrig
    //   [15: 8] rtrig
    //
    input wire [31:0] cont1_key,
    input wire [31:0] cont2_key,
    input wire [31:0] cont3_key,
    input wire [31:0] cont4_key,
    input wire [31:0] cont1_joy,
    input wire [31:0] cont2_joy,
    input wire [31:0] cont3_joy,
    input wire [31:0] cont4_joy,
    input wire [15:0] cont1_trig,
    input wire [15:0] cont2_trig,
    input wire [15:0] cont3_trig,
    input wire [15:0] cont4_trig,

    input  wire altera_reserved_tck,
    input  wire altera_reserved_tdi,
    output wire altera_reserved_tdo,
    input  wire altera_reserved_tms

);
    // ---- Namco System 11 shell skeleton: bare APF cost. Every output is tied off. ----
    assign port_ir_tx = 0, port_ir_rx_disable = 1;
    assign cart_tran_bank1 = 8'bz, cart_tran_bank2 = 8'bz, cart_tran_bank3 = 8'bz;
    assign cart_tran_bank1_dir = 0, cart_tran_bank2_dir = 0, cart_tran_bank3_dir = 0;
    assign cart_tran_bank0 = 4'hf, cart_tran_bank0_dir = 1;
    assign cart_tran_pin30 = 1'bz, cart_tran_pin30_dir = 0, cart_pin30_pwroff_reset = 0;
    assign cart_tran_pin31 = 1'bz, cart_tran_pin31_dir = 0;
    assign port_tran_si = 1'bz, port_tran_si_dir = 0, port_tran_so = 1'bz, port_tran_so_dir = 0;
    assign port_tran_sck = 1'bz, port_tran_sck_dir = 0, port_tran_sd = 1'bz, port_tran_sd_dir = 0;
    assign cram0_a = 0, cram0_dq = 16'bz, cram0_clk = 0, cram0_adv_n = 1, cram0_cre = 0,
           cram0_ce0_n = 1, cram0_ce1_n = 1, cram0_oe_n = 1, cram0_we_n = 1, cram0_ub_n = 1, cram0_lb_n = 1;
    assign cram1_a = 0, cram1_dq = 16'bz, cram1_clk = 0, cram1_adv_n = 1, cram1_cre = 0,
           cram1_ce0_n = 1, cram1_ce1_n = 1, cram1_oe_n = 1, cram1_we_n = 1, cram1_ub_n = 1, cram1_lb_n = 1;
    assign dram_a = 0, dram_ba = 0, dram_dq = 16'bz, dram_dqm = 0, dram_clk = 0, dram_cke = 0,
           dram_ras_n = 1, dram_cas_n = 1, dram_we_n = 1;
    assign sram_a = 0, sram_dq = 16'bz, sram_oe_n = 1, sram_we_n = 1, sram_ub_n = 1, sram_lb_n = 1;
    assign dbg_tx = 1, user1 = 0, aux_scl = 0, aux_sda = 1'bz, vpll_feed = 0;
    assign bridge_endian_little = 0, bridge_rd_data = 0;
    assign audio_mclk = 0, audio_dac = 0, audio_lrck = 0;
    assign video_rgb = 0, video_rgb_clock = clk_74a, video_rgb_clock_90 = clk_74a,
           video_de = 0, video_skip = 0, video_vs = 0, video_hs = 0;
    assign altera_reserved_tdo = 0;
endmodule
