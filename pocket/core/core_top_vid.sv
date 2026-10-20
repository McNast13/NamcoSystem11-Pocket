// GPL-2.0-or-later. Video-only bring-up test core: no System 11 logic, just the diagnostic picture through the real video PLL / APF video
// path / DDIO outputs, with the real bridge command handler so the Pocket boots it like the full core. Port list matches apf_top.v.
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
    input wire [15:0] cont4_trig
);

    // ---- unused interfaces ----
    assign port_ir_tx = 0, port_ir_rx_disable = 1;
    assign cart_tran_bank1 = 8'bz, cart_tran_bank2 = 8'bz, cart_tran_bank3 = 8'bz;
    assign cart_tran_bank1_dir = 0, cart_tran_bank2_dir = 0, cart_tran_bank3_dir = 0;
    assign cart_tran_bank0 = 4'hf, cart_tran_bank0_dir = 1;
    assign cart_tran_pin30 = 1'bz, cart_tran_pin30_dir = 0, cart_pin30_pwroff_reset = 0;
    assign cart_tran_pin31 = 1'bz, cart_tran_pin31_dir = 0;
    assign port_tran_si = 1'bz, port_tran_si_dir = 0, port_tran_so = 1'bz, port_tran_so_dir = 0;
    assign port_tran_sck = 1'bz, port_tran_sck_dir = 0, port_tran_sd = 1'bz, port_tran_sd_dir = 0;
    assign sram_a = 0, sram_dq = 16'bz, sram_oe_n = 1, sram_we_n = 1, sram_ub_n = 1, sram_lb_n = 1;
    assign dbg_tx = 1, user1 = 0, aux_scl = 0, aux_sda = 1'bz, vpll_feed = 0;
    assign cram0_a = 0, cram0_dq = 16'bz, cram0_clk = 0, cram0_adv_n = 1, cram0_cre = 0, cram0_ce0_n = 1, cram0_ce1_n = 1,
           cram0_oe_n = 1, cram0_we_n = 1, cram0_ub_n = 1, cram0_lb_n = 1;
    assign cram1_a = 0, cram1_dq = 16'bz, cram1_clk = 0, cram1_adv_n = 1, cram1_cre = 0, cram1_ce0_n = 1, cram1_ce1_n = 1,
           cram1_oe_n = 1, cram1_we_n = 1, cram1_ub_n = 1, cram1_lb_n = 1;
    assign dram_a = 0, dram_ba = 0, dram_dq = 16'bz, dram_dqm = 2'b11, dram_clk = 0, dram_cke = 0, dram_ras_n = 1, dram_cas_n = 1, dram_we_n = 1;
    assign audio_mclk = 0, audio_dac = 0, audio_lrck = 0;

    // ---- bridge command handler ----
    wire        reset_n;
    wire [31:0] cmd_bridge_rd_data;
    assign bridge_endian_little = 1'b1;
    assign bridge_rd_data = (bridge_addr[31:24] == 8'hF8) ? cmd_bridge_rd_data : 32'h0;

    wire        dataslot_requestread, dataslot_requestwrite, dataslot_update, dataslot_allcomplete;
    wire [15:0] dataslot_requestread_id, dataslot_requestwrite_id, dataslot_update_id;
    wire [31:0] dataslot_requestwrite_size, dataslot_update_size;
    wire [31:0] rtc_epoch_seconds, rtc_date_bcd, rtc_time_bcd;
    wire        rtc_valid, savestate_start, savestate_load, osnotify_inmenu;
    wire        target_dataslot_ack, target_dataslot_done;
    wire [2:0]  target_dataslot_err;
    reg  [9:0]  datatable_addr = 0;
    reg         datatable_wren = 0;
    reg  [31:0] datatable_data = 0;
    wire [31:0] datatable_q;
    reg         prev_dataslot_update = 0;
    always @(posedge clk_74a) begin
        prev_dataslot_update <= dataslot_update;
        datatable_wren <= 0;
        if (dataslot_update && ~prev_dataslot_update) begin
            datatable_addr <= dataslot_update_id[9:0] * 10'h2 + 10'h1;
            datatable_data <= dataslot_update_size;
            datatable_wren <= 1;
        end
    end

    // ---- clocks (the full core's PLL; the core-clock half is unused here and pruned) ----
    wire clk1x, clk2x, clk3x, clk_vid, clk_vid90, pll_locked;
    s11_pll pll (.clk_74a(clk_74a), .rst(1'b0), .clk1x(clk1x), .clk2x(clk2x), .clk3x(clk3x),
                 .clkvid(clk_vid), .clkvid90(clk_vid90), .locked(pll_locked));
    reg [1:0] lock_s74 = 2'b00;
    always @(posedge clk_74a) lock_s74 <= {lock_s74[0], pll_locked};
    wire pll_locked_74 = lock_s74[1];

    core_bridge_cmd icb (
        .clk(clk_74a), .reset_n(reset_n),
        .bridge_endian_little(bridge_endian_little), .bridge_addr(bridge_addr), .bridge_rd(bridge_rd),
        .bridge_rd_data(cmd_bridge_rd_data), .bridge_wr(bridge_wr), .bridge_wr_data(bridge_wr_data),
        .status_boot_done(pll_locked_74), .status_setup_done(pll_locked_74), .status_running(reset_n),
        .dataslot_requestread(dataslot_requestread), .dataslot_requestread_id(dataslot_requestread_id),
        .dataslot_requestread_ack(1'b1), .dataslot_requestread_ok(1'b1),
        .dataslot_requestwrite(dataslot_requestwrite), .dataslot_requestwrite_id(dataslot_requestwrite_id),
        .dataslot_requestwrite_size(dataslot_requestwrite_size),
        .dataslot_requestwrite_ack(pll_locked_74), .dataslot_requestwrite_ok(1'b1),
        .dataslot_update(dataslot_update), .dataslot_update_id(dataslot_update_id), .dataslot_update_size(dataslot_update_size),
        .dataslot_allcomplete(dataslot_allcomplete),
        .rtc_epoch_seconds(rtc_epoch_seconds), .rtc_date_bcd(rtc_date_bcd), .rtc_time_bcd(rtc_time_bcd), .rtc_valid(rtc_valid),
        .savestate_supported(1'b0), .savestate_addr(32'h0), .savestate_size(32'h0), .savestate_maxloadsize(32'h0),
        .savestate_start(savestate_start), .savestate_start_ack(1'b0), .savestate_start_busy(1'b0),
        .savestate_start_ok(1'b0), .savestate_start_err(1'b0),
        .savestate_load(savestate_load), .savestate_load_ack(1'b0), .savestate_load_busy(1'b0),
        .savestate_load_ok(1'b0), .savestate_load_err(1'b0),
        .osnotify_inmenu(osnotify_inmenu),
        .target_dataslot_read(1'b0), .target_dataslot_write(1'b0), .target_dataslot_getfile(1'b0), .target_dataslot_openfile(1'b0),
        .target_dataslot_ack(target_dataslot_ack), .target_dataslot_done(target_dataslot_done), .target_dataslot_err(target_dataslot_err),
        .target_dataslot_id(16'h0), .target_dataslot_slotoffset(32'h0), .target_dataslot_bridgeaddr(32'h0), .target_dataslot_length(32'h0),
        .target_buffer_param_struct(32'h0), .target_buffer_resp_struct(32'h0),
        .datatable_addr(datatable_addr), .datatable_wren(datatable_wren), .datatable_data(datatable_data), .datatable_q(datatable_q)
    );

    // ---- core setting "Diagnostic screen" (interact.json, 0x5000000C) picks the path: 1 = through psx_apf_video (what the real core uses),
    //      0 (the power-up value here) = raw: plain APF signalling straight from the generator, no slot words / padding / lead line ----
    reg path_apf74 = 1'b0;
    always @(posedge clk_74a) if (bridge_wr && bridge_addr == 32'h5000000C) path_apf74 <= bridge_wr_data[0];
    wire path_set;
    synch_3 #(.WIDTH(1)) s_path (path_apf74, path_set, clk_vid);
`ifdef FORCE_APF
    wire path_apf = 1'b1;     // build variant: always the psx_apf_video path
`elsif FORCE_RAW
    wire path_apf = 1'b0;     // build variant: always the raw path
`else
    wire path_apf = path_set;
`endif

    // ---- the picture: same generator as the full core's diagnostic screen (bus = fixed pattern so the status boxes are recognisable; the first box = 1 when the psx_apf_video path is in use) ----
    wire dg_ce, dg_hs, dg_vs, dg_hbl, dg_vbl; wire [23:0] dg_rgb;
    s11_diag diag (.clk(clk_vid), .extra(192'h0123456789ABCDEF_FEDCBA9876543210_0123456789ABCDEF), .bus({path_apf, 31'h25A5A5A5, 32'hFFFF0000, 32'h12345678, 32'h0000FFFF}),
                   .ce(dg_ce), .hsync(dg_hs), .vsync(dg_vs), .hblank(dg_hbl), .vblank(dg_vbl), .rgb(dg_rgb));

    // path A: the real formatter with the full core's parameters
    wire apf_hs, apf_vs, apf_de, apf_skip; wire [23:0] apf_rgb;
    psx_apf_video #(.STEADY_INTERLACE(0), .SLOT_SELECT(1), .PAD_LINES(1), .CENTER_LINES(1), .VS_ON_HS(1),
                    .CROP_LINES(1), .BLANK_TOP(1), .LEAD_LINE(1), .MID_W(384)) apf_video (
        .clk(clk_vid), .ce(dg_ce), .hsync(dg_hs), .vsync(dg_vs), .hblank(dg_hbl), .vblank(dg_vbl), .interlace(1'b0),
        .blank(1'b0), .weave(1'b0), .field_swap(1'b0), .video_test(2'b00), .rgb_in(dg_rgb),
        .hs(apf_hs), .vs(apf_vs), .de(apf_de), .skip(apf_skip), .rgb(apf_rgb)
    );

    // path B: raw. One-clock VS on the vsync rise, HS 4 clocks after the hsync rise, DE over the active area, pixels held for 8 clocks
    // (skip drops the repeats), 320 pixels land in the left half of the 640 slot.
    reg raw_hs_d = 1'b0, raw_vs_d = 1'b0; reg [3:0] raw_hs_pipe = 4'd0;
    reg raw_hs = 1'b0, raw_vs = 1'b0, raw_de = 1'b0, raw_skip = 1'b0; reg [23:0] raw_rgb = 24'd0;
    always @(posedge clk_vid) begin
        raw_hs_d <= dg_hs; raw_vs_d <= dg_vs;
        raw_hs_pipe <= {raw_hs_pipe[2:0], dg_hs && !raw_hs_d};
        raw_hs <= raw_hs_pipe[3];
        raw_vs <= dg_vs && !raw_vs_d;
        raw_de <= !dg_hbl && !dg_vbl;
        raw_skip <= !dg_ce;
        raw_rgb <= (!dg_hbl && !dg_vbl) ? dg_rgb : 24'd0;
    end

    // outputs retimed to the falling edge of video_rgb_clock, as in the full core
    reg [23:0] o_rgb = 24'd0; reg o_de = 1'b0, o_skip = 1'b0, o_hs = 1'b0, o_vs = 1'b0;
    always @(negedge clk_vid) begin
        o_rgb  <= path_apf ? apf_rgb  : raw_rgb;  o_de   <= path_apf ? apf_de   : raw_de;   o_skip <= path_apf ? apf_skip : raw_skip;
        o_hs   <= path_apf ? apf_hs   : raw_hs;   o_vs   <= path_apf ? apf_vs   : raw_vs;
    end
    assign video_rgb_clock = clk_vid, video_rgb_clock_90 = clk_vid90;
    assign video_rgb = o_rgb, video_de = o_de, video_skip = o_skip, video_hs = o_hs, video_vs = o_vs;
endmodule
`default_nettype wire
