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
    input wire [15:0] cont4_trig
);
    // ===================================================================================================================
    // Namco System 11 core on the Analogue Pocket: SYSTEM11.sv (the MiSTer `emu`, adapted by emu/pocket_emu.apply) wrapped in the
    // Pocket framework pieces: bridge command handler, data-slot -> ioctl bridge, PLL, SDRAM (inside emu), PSRAM VRAM,
    // controller mapping, APF video formatter and I2S audio.
    // ===================================================================================================================

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

    // ---- APF host/target command handler (Analogue core_bridge_cmd, mapped at bridge 0xF8xxxxxx) ----
    wire        reset_n;
    wire [31:0] cmd_bridge_rd_data;
    assign bridge_endian_little = 1'b1;     // data-slot words arrive little-endian: byte 0 of the file = bits [7:0]
    reg  [31:0] bridge_rd_mux;
    always @(*) begin
        casex (bridge_addr)
            32'hF8xxxxxx: bridge_rd_mux = cmd_bridge_rd_data;
            32'h09xxxxxx: bridge_rd_mux = ee_shadow_q;          // EEPROM save-back (data slot 9)
            default:      bridge_rd_mux = 32'h0;
        endcase
    end
    assign bridge_rd_data = bridge_rd_mux;

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

    // ---- clocks ----
    wire clk1x, clk2x, clk3x, clk_vid, clk_vid90, pll_locked;
    s11_pll pll (.clk_74a(clk_74a), .rst(1'b0), .clk1x(clk1x), .clk2x(clk2x), .clk3x(clk3x),
                 .clkvid(clk_vid), .clkvid90(clk_vid90), .locked(pll_locked));
    reg [1:0] lock_s74 = 2'b00;
    reg [17:0] sdram_wait = 18'd0;                    // ~3.5 ms after lock: the controller powers the chip up and sets the mode register
    reg        mem_ready_74 = 1'b0;
    always @(posedge clk_74a) begin
        lock_s74 <= {lock_s74[0], pll_locked};
        if (!lock_s74[1]) begin sdram_wait <= 18'd0; mem_ready_74 <= 1'b0; end
        else if (!(&sdram_wait)) sdram_wait <= sdram_wait + 1'b1;
        else mem_ready_74 <= 1'b1;
    end
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
        .dataslot_requestwrite_ack(mem_ready_74), .dataslot_requestwrite_ok(1'b1),
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

    // ---- reset into the core clock domain: held while the PLL is unlocked or the host holds the core in reset ----
    reg [2:0] rst_s1x = 3'b111;
    wire rst_async = ~pll_locked | ~reset_n;
    always @(posedge clk1x or posedge rst_async) if (rst_async) rst_s1x <= 3'b111; else rst_s1x <= {rst_s1x[1:0], 1'b0};
    wire core_reset = rst_s1x[2];

    // ---- data slots -> ioctl download stream ----
    wire        ioctl_dl, ioctl_wr, ioctl_wait, ld_busy, ld_overflow;
    wire [7:0]  ioctl_index;
    wire [26:0] ioctl_addr;
    wire [15:0] ioctl_dout;
    s11_ioctl_bridge ioctl (
        .clk_74a(clk_74a), .bridge_wr(bridge_wr), .bridge_addr(bridge_addr), .bridge_wr_data(bridge_wr_data),
        .clk(clk1x), .rst(~pll_locked),
        .ioctl_download(ioctl_dl), .ioctl_wr(ioctl_wr), .ioctl_index(ioctl_index), .ioctl_addr(ioctl_addr),
        .ioctl_dout(ioctl_dout), .ioctl_wait(ioctl_wait), .ld_busy(ld_busy), .ld_overflow(ld_overflow)
    );

    // ---- controllers: Pocket pads -> the MiSTer joystick word the core expects ----
    //  joy: [0]right [1]left [2]down [3]up [4..9]Button1..6 [10]Start [11]Coin [12]Pause [13]Service
    //  Pocket key: [0]up [1]down [2]left [3]right [4]A [5]B [6]X [7]Y [8]L1 [9]R1 [10]L2 [11]R2 [14]select [15]start
    //  Tekken layout: Button1 LP = Y, Button2 RP = X, Button3 LK = B, Button4 RK = A, Button5 = L1, Button6 = R1,
    //  Coin = Select, Service = L2
    function [19:0] map_joy(input [31:0] k);
        map_joy = {6'b0, 1'b0, 1'b0, k[10], 1'b0, k[14], k[15], k[9], k[8], k[4], k[5], k[6], k[7], k[0], k[1], k[2], k[3]};
    endfunction
    wire [31:0] k1_s, k2_s, k3_s, k4_s, j1_s, j2_s, j3_s, j4_s;
    synch_3 #(.WIDTH(32)) s_k1 (cont1_key, k1_s, clk1x);
    synch_3 #(.WIDTH(32)) s_k2 (cont2_key, k2_s, clk1x);
    synch_3 #(.WIDTH(32)) s_k3 (cont3_key, k3_s, clk1x);
    synch_3 #(.WIDTH(32)) s_k4 (cont4_key, k4_s, clk1x);
    synch_3 #(.WIDTH(32)) s_j1 (cont1_joy, j1_s, clk1x);
    synch_3 #(.WIDTH(32)) s_j2 (cont2_joy, j2_s, clk1x);
    synch_3 #(.WIDTH(32)) s_j3 (cont3_joy, j3_s, clk1x);
    synch_3 #(.WIDTH(32)) s_j4 (cont4_joy, j4_s, clk1x);
    function [15:0] map_stick(input [15:0] s);     // unsigned 0..255 centred on 128 -> signed -128..127, {Y, X}
        map_stick = {s[15:8] ^ 8'h80, s[7:0] ^ 8'h80};
    endfunction

    // ---- EEPROM save-back: a shadow copy readable from the bridge ----
    // zn1_io's EEPROM RAM has one port that the MIPS also uses, so the contents are copied out (1024 words, ~4k clk1x) after
    // the game starts and again after every save request the core raises (1.5 s after the last EEPROM write).
    wire        ee_save_req;
    wire [31:0] ee_q;
    reg         ee_rd = 1'b0;
    reg  [9:0]  ee_a = 10'd0;
    reg  [1:0]  ee_wait = 2'd0;
    reg  [10:0] ee_cnt = 11'd0;                 // 0..1023 scanning, 1024 idle
    reg         ee_wr_sh = 1'b0;
    reg  [9:0]  ee_wa_sh = 10'd0;
    reg         save_d = 1'b0, run_d_hold = 1'b0;
    reg  [15:0] start_delay = 16'd0;
    (* ramstyle = "M10K" *) reg [31:0] ee_shadow [0:1023];
    reg  [31:0] ee_shadow_q = 32'd0;
    always @(posedge clk1x) begin
        save_d <= ee_save_req; run_d_hold <= &start_delay;
        ee_wr_sh <= 1'b0;
        if (core_reset) start_delay <= 16'd0;
        else if (!(&start_delay)) start_delay <= start_delay + 1'b1;
        if ((ee_save_req && !save_d) || (&start_delay && !run_d_hold)) begin ee_cnt <= 11'd0; ee_wait <= 2'd0; end
        else if (!ee_cnt[10]) begin
            ee_rd <= 1'b1; ee_a <= ee_cnt[9:0];
            ee_wait <= ee_wait + 1'b1;
            if (ee_wait == 2'd3) begin ee_wr_sh <= 1'b1; ee_wa_sh <= ee_cnt[9:0]; ee_cnt <= ee_cnt + 1'b1; ee_wait <= 2'd0; end
        end else ee_rd <= 1'b0;
    end
    always @(posedge clk1x) if (ee_wr_sh) ee_shadow[ee_wa_sh] <= ee_q;
    always @(posedge clk_74a) ee_shadow_q <= ee_shadow[bridge_addr[11:2]];

    // ---- Core settings (interact.json): DIP1 Test, DIP2 Freeze, held Service button ----
    reg [2:0] settings74 = 3'b000;
    always @(posedge clk_74a) if (bridge_wr) begin
        if (bridge_addr == 32'h50000000) settings74[0] <= bridge_wr_data[0];
        if (bridge_addr == 32'h50000004) settings74[1] <= bridge_wr_data[0];
        if (bridge_addr == 32'h50000008) settings74[2] <= bridge_wr_data[0];
    end
    wire [2:0] settings;
    synch_3 #(.WIDTH(3)) s_set (settings74, settings, clk1x);
    wire [19:0] joy_svc = {6'b0, settings[2], 13'b0};     // joy[13] = Service

    // ---- the core ----
    wire        vid_ce, vid_hs, vid_vs, vid_hbl, vid_vbl, vid_ilace;
    wire [7:0]  vid_r, vid_g, vid_b;
    wire [15:0] aud_l, aud_r;
    wire        vr_busy, vr_dout_ready;
    wire [63:0] vr_dout;
    wire        vr_rd, vr_we;
    wire [7:0]  vr_burst, vr_be;
    wire [28:0] vr_addr;
    wire [63:0] vr_din;
    wire        emu_clk_video_unused, emu_ce_pixel_unused;

    emu s11 (
        .CLK_50M(clk_74a), .RESET(core_reset),
        .HDMI_WIDTH(12'd0), .HDMI_HEIGHT(12'd0),
        .FB_VBL(1'b0), .FB_LL(1'b0),
        .CLK_AUDIO(1'b0), .SD_MISO(1'b0), .SD_CD(1'b0),
        .DDRAM_BUSY(vr_busy), .DDRAM_BURSTCNT(vr_burst), .DDRAM_ADDR(vr_addr), .DDRAM_DOUT(vr_dout),
        .DDRAM_DOUT_READY(vr_dout_ready), .DDRAM_RD(vr_rd), .DDRAM_DIN(vr_din), .DDRAM_BE(vr_be), .DDRAM_WE(vr_we),
        .SDRAM_CLK(dram_clk), .SDRAM_CKE(dram_cke), .SDRAM_A(dram_a), .SDRAM_BA(dram_ba), .SDRAM_DQ(dram_dq),
        .SDRAM_DQML(dram_dqm[0]), .SDRAM_DQMH(dram_dqm[1]), .SDRAM_nCS(), .SDRAM_nCAS(dram_cas_n),
        .SDRAM_nRAS(dram_ras_n), .SDRAM_nWE(dram_we_n),
        .UART_CTS(1'b0), .UART_RXD(1'b0), .UART_DSR(1'b0), .USER_IN(7'd0), .OSD_STATUS(1'b0),
        .AUDIO_L(aud_l), .AUDIO_R(aud_r),
        .PK_CLK1X(clk1x), .PK_CLK2X(clk2x), .PK_CLK3X(clk3x), .PK_CLKVID(clk_vid), .PK_LOCKED(pll_locked),
        .PK_IOCTL_DL(ioctl_dl), .PK_IOCTL_WR(ioctl_wr), .PK_IOCTL_INDEX(ioctl_index), .PK_IOCTL_ADDR(ioctl_addr),
        .PK_IOCTL_DOUT(ioctl_dout), .PK_IOCTL_WAIT(ioctl_wait),
        .PK_JOY0(map_joy(k1_s) | joy_svc), .PK_JOY1(map_joy(k2_s)), .PK_JOY2(map_joy(k3_s)), .PK_JOY3(map_joy(k4_s)),
        .PK_ANALOG_L0(map_stick(j1_s[15:0])),  .PK_ANALOG_L1(map_stick(j2_s[15:0])),
        .PK_ANALOG_L2(map_stick(j3_s[15:0])),  .PK_ANALOG_L3(map_stick(j4_s[15:0])),
        .PK_ANALOG_R0(map_stick(j1_s[31:16])), .PK_ANALOG_R1(map_stick(j2_s[31:16])),
        .PK_ANALOG_R2(map_stick(j3_s[31:16])), .PK_ANALOG_R3(map_stick(j4_s[31:16])),
        .PK_STATUS({30'd0, settings[1], settings[0], 96'd0}),
        .PK_VID_CE(vid_ce), .PK_VID_HS(vid_hs), .PK_VID_VS(vid_vs), .PK_VID_HBL(vid_hbl), .PK_VID_VBL(vid_vbl),
        .PK_VID_ILACE(vid_ilace), .PK_VID_R(vid_r), .PK_VID_G(vid_g), .PK_VID_B(vid_b),
        .PK_EE_RD(ee_rd), .PK_EE_ADDR(ee_a), .PK_EE_Q(ee_q), .PK_EE_SAVE_REQ(ee_save_req)
    );

    // ---- GPU VRAM on the two PSRAMs ----
    reg [2:0] unlock_s2x = 3'b111;
    always @(posedge clk2x or negedge pll_locked) if (!pll_locked) unlock_s2x <= 3'b111; else unlock_s2x <= {unlock_s2x[1:0], 1'b0};
    s11_vram vram (
        .clk2x(clk2x), .reset(unlock_s2x[2]), .park(~reset_n),
        .ddr_busy(vr_busy), .ddr_burstcnt(vr_burst), .ddr_addr(vr_addr[24:0]), .ddr_dout(vr_dout),
        .ddr_dout_ready(vr_dout_ready), .ddr_rd(vr_rd), .ddr_din(vr_din), .ddr_be(vr_be), .ddr_we(vr_we),
        .cram0_a(cram0_a), .cram0_dq(cram0_dq), .cram0_clk(cram0_clk), .cram0_adv_n(cram0_adv_n), .cram0_cre(cram0_cre),
        .cram0_ce0_n(cram0_ce0_n), .cram0_ce1_n(cram0_ce1_n), .cram0_oe_n(cram0_oe_n), .cram0_we_n(cram0_we_n),
        .cram0_ub_n(cram0_ub_n), .cram0_lb_n(cram0_lb_n),
        .cram1_a(cram1_a), .cram1_dq(cram1_dq), .cram1_clk(cram1_clk), .cram1_adv_n(cram1_adv_n), .cram1_cre(cram1_cre),
        .cram1_ce0_n(cram1_ce0_n), .cram1_ce1_n(cram1_ce1_n), .cram1_oe_n(cram1_oe_n), .cram1_we_n(cram1_we_n),
        .cram1_ub_n(cram1_ub_n), .cram1_lb_n(cram1_lb_n)
    );

    // ---- video: raw PSX video -> APF scaler protocol (as in the PS Pocket core) ----
    wire apf_hs, apf_vs, apf_de, apf_skip;
    wire [23:0] apf_rgb;
    psx_apf_video #(.STEADY_INTERLACE(0), .SLOT_SELECT(1), .PAD_LINES(1), .CENTER_LINES(1), .VS_ON_HS(1),
                    .CROP_LINES(1), .BLANK_TOP(1), .LEAD_LINE(1), .MID_W(384)) apf_video (
        .clk(clk_vid), .ce(vid_ce),
        .hsync(vid_hs), .vsync(vid_vs), .hblank(vid_hbl), .vblank(vid_vbl), .interlace(vid_ilace),
        .blank(core_reset), .weave(1'b0), .field_swap(1'b0), .video_test(2'b00),
        .rgb_in({vid_r, vid_g, vid_b}),
        .hs(apf_hs), .vs(apf_vs), .de(apf_de), .skip(apf_skip), .rgb(apf_rgb)
    );
    assign video_rgb_clock = clk_vid, video_rgb_clock_90 = clk_vid90;
    assign video_rgb = apf_rgb, video_de = apf_de, video_skip = apf_skip, video_hs = apf_hs, video_vs = apf_vs;

    // ---- audio ----
    s11_audio audio (
        .clk_74b(clk_74b), .clk(clk1x), .reset(core_reset),
        .in_l($signed(aud_l)), .in_r($signed(aud_r)),
        .audio_mclk(audio_mclk), .audio_lrck(audio_lrck), .audio_dac(audio_dac)
    );
endmodule
