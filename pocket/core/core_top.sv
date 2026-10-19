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
    assign sram_a = 0, sram_dq = 16'bz, sram_oe_n = 1, sram_we_n = 1, sram_ub_n = 1, sram_lb_n = 1;
    assign dbg_tx = 1, aux_scl = 0, aux_sda = 1'bz, vpll_feed = 0;
    assign user1 = sink;    // keeps the placeholder loader/command logic alive in the skeleton fit
    // ---- APF host/target command handler (Analogue core_bridge_cmd, mapped at bridge 0xF8xxxxxx) ----
    wire        reset_n;
    wire [31:0] cmd_bridge_rd_data;
    assign bridge_endian_little = 1'b1;     // data-slot words arrive little-endian: byte 0 of the file = bits [7:0]
    reg  [31:0] bridge_rd_mux;
    always @(*) begin
        casex (bridge_addr)
            32'hF8xxxxxx: bridge_rd_mux = cmd_bridge_rd_data;
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

    // data table (slot id * 2 + 1 holds the size of the file loaded into the slot)
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

    // ---- core clocks: 33.8688 / 67.7376 / 101.6064 MHz from the 74.25 MHz reference ----
    wire clk1x, clk2x, clk3x, pll_locked;
    s11_pll pll (.clk_74a(clk_74a), .rst(1'b0), .clk1x(clk1x), .clk2x(clk2x), .clk3x(clk3x), .locked(pll_locked));
    reg [1:0] lock_s74 = 2'b00;
    reg [17:0] sdram_wait = 18'd0;                    // ~3.5 ms after lock: the controller powers the chip up (200 us) and sets the mode register
    reg        mem_ready_74 = 1'b0;
    always @(posedge clk_74a) begin
        lock_s74 <= {lock_s74[0], pll_locked};
        if (!lock_s74[1]) begin sdram_wait <= 18'd0; mem_ready_74 <= 1'b0; end
        else if (!(&sdram_wait)) sdram_wait <= sdram_wait + 1'b1;
        else mem_ready_74 <= 1'b1;
    end
    wire pll_locked_74 = lock_s74[1];
    reg [1:0] unlock_s1x = 2'b11;                     // PLL not locked, synchronised to clk1x: holds the memory/loader in reset
    always @(posedge clk1x or negedge pll_locked) if (!pll_locked) unlock_s1x <= 2'b11; else unlock_s1x <= {unlock_s1x[0], 1'b0};
    wire init1x = unlock_s1x[1];

    // ---- data-slot loader (bridge writes -> System 11 ROM/BIOS/EEPROM/config destinations) ----
    wire        ld_mem_valid, ld_mem_ready, ld_c76_wr, ld_ee_wr, ld_cfg_gun, ld_busy, ld_overflow;
    wire [26:0] ld_mem_addr;
    wire [31:0] ld_mem_data, ld_ee_data;
    wire [13:0] ld_c76_addr;
    wire [7:0]  ld_c76_data, ld_cfg_platform, ld_cfg_keycus;
    wire [9:0]  ld_ee_addr;
    s11_loader loader (
        .clk_74a(clk_74a), .bridge_wr(bridge_wr), .bridge_addr(bridge_addr), .bridge_wr_data(bridge_wr_data),
        .clk(clk1x), .rst(init1x),
        .mem_valid(ld_mem_valid), .mem_addr(ld_mem_addr), .mem_data(ld_mem_data), .mem_ready(ld_mem_ready),
        .c76_wr(ld_c76_wr), .c76_addr(ld_c76_addr), .c76_data(ld_c76_data),
        .ee_wr(ld_ee_wr), .ee_addr(ld_ee_addr), .ee_data(ld_ee_data),
        .cfg_platform(ld_cfg_platform), .cfg_keycus(ld_cfg_keycus), .cfg_gun(ld_cfg_gun),
        .ld_busy(ld_busy), .ld_overflow(ld_overflow)
    );

    // ---- main memory: Pocket SDRAM through the MiSTer-contract controller; the core's RAM ports are not connected yet ----
    wire [31:0] ram_ch1_dout32;
    wire        ram_ch1_ready;
    s11_ram ram (
        .clk1x(clk1x), .clk3x(clk3x), .init(init1x),
        .ld_valid(ld_mem_valid), .ld_addr(ld_mem_addr), .ld_data(ld_mem_data), .ld_ready(ld_mem_ready), .ld_active(ld_busy),
        .refreshForce(1'b0), .ram_idle(),
        .ch1_addr(27'b0), .ch1_dout(), .ch1_dout32(ram_ch1_dout32), .ch1_req(1'b0), .ch1_dma(1'b0), .ch1_cntDMA(2'b0),
        .ch1_cache(1'b0), .ch1_ready(ram_ch1_ready), .cache_wr(), .cache_data(), .cache_addr(),
        .dma_wr(), .dma_reqprocessed(), .dma_data(),
        .ch2_addr(27'b0), .ch2_dout(), .ch2_din(32'b0), .ch2_req(1'b0), .ch2_be(4'b0), .ch2_ready(),
        .ext_ch3_addr(27'b0), .ext_ch3_din(32'b0), .ext_ch3_req(1'b0), .ext_ch3_rnw(1'b0), .ext_ch3_be(4'b0),
        .ch3_dout(), .ext_ch3_ready(),
        .dmafifo_adr(27'b0), .dmafifo_data(32'b0), .dmafifo_empty(1'b1), .dmafifo_read(),
        .dram_dq(dram_dq), .dram_a(dram_a), .dram_dqm(dram_dqm), .dram_ba(dram_ba),
        .dram_we_n(dram_we_n), .dram_ras_n(dram_ras_n), .dram_cas_n(dram_cas_n), .dram_cke(dram_cke), .dram_clk(dram_clk)
    );
    reg  sink = 1'b0;
    always @(posedge clk1x)
        sink <= ^{ram_ch1_dout32, ram_ch1_ready, ld_mem_valid, ld_mem_addr, ld_mem_data, ld_c76_wr, ld_c76_addr, ld_c76_data, ld_ee_wr, ld_ee_addr, ld_ee_data,
                  ld_cfg_platform, ld_cfg_keycus, ld_cfg_gun, ld_busy, ld_overflow, datatable_q, dataslot_allcomplete,
                  target_dataslot_ack, target_dataslot_done, target_dataslot_err, dataslot_requestread, dataslot_requestwrite,
                  rtc_valid, savestate_start, savestate_load, osnotify_inmenu, rtc_epoch_seconds, rtc_date_bcd, rtc_time_bcd};
    assign audio_mclk = 0, audio_dac = 0, audio_lrck = 0;
    assign video_rgb = 0, video_rgb_clock = clk_74a, video_rgb_clock_90 = clk_74a,
           video_de = 0, video_skip = 0, video_vs = 0, video_hs = 0;
endmodule
