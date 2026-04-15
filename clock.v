// Top-level integration:
// clock ticks, keys, mode control, time core, alarm core and display path.
module clock #(
    parameter integer CLK_FREQ_HZ      = 1000000,
    parameter         KEY_ACTIVE_LEVEL = 1'b0,
    parameter         SEG_ACTIVE_LOW   = 1'b0,
    parameter         ENABLE_ALARM     = 1'b0
)(
    input  wire clk,
    input  wire rst_n,
    input  wire sw_dir,
    input  wire qd_in,
    input  wire pulse_in,
    input  wire clr_in,
    output wire [7:0] lg1_seg,
    output wire [3:0] lg2_bcd,
    output wire [3:0] lg3_bcd,
    output wire [3:0] lg4_bcd,
    output wire [3:0] lg5_bcd,
    output wire [3:0] lg6_bcd
);

wire tick_1hz;
wire tick_blink;

wire key_mode_pulse;
wire key_pulse_pulse;
wire key_rst_pulse;

wire dir_is_add;
wire key_add_act;
wire key_sub_act;
wire key_rst_act;

wire [2:0] mode_state;
wire time_tick;
wire hour_inc;
wire hour_dec;
wire min_inc;
wire min_dec;
wire sec_inc;
wire sec_dec;
wire hour_clr;
wire min_clr;
wire sec_clr;
wire alarm_hour_inc;
wire alarm_hour_dec;
wire alarm_min_inc;
wire alarm_min_dec;
wire alarm_enable_toggle;

wire [3:0] time_hour_tens;
wire [3:0] time_hour_ones;
wire [3:0] time_min_tens;
wire [3:0] time_min_ones;
wire [3:0] time_sec_tens;
wire [3:0] time_sec_ones;

wire [3:0] alarm_hour_tens;
wire [3:0] alarm_hour_ones;
wire [3:0] alarm_min_tens;
wire [3:0] alarm_min_ones;
wire       alarm_enable;

wire [3:0] dig0_bcd;
wire [3:0] dig1_bcd;
wire [3:0] dig2_bcd;
wire [3:0] dig3_bcd;
wire [3:0] dig4_bcd;
wire [3:0] dig5_bcd;
wire [5:0] blank_mask;
wire [5:0] dp_mask;
wire [7:0] lg1_seg_raw;

// Shared counters and key logic reduce register usage on MAX7000S.
input_timebase #(
    .CLK_FREQ_HZ     (CLK_FREQ_HZ),
    .KEY_ACTIVE_LEVEL(KEY_ACTIVE_LEVEL)
) u_input_timebase (
    .clk             (clk),
    .rst_n           (rst_n),
    .key_mode_in     (qd_in),
    .key_pulse_in    (pulse_in),
    .key_rst_in      (clr_in),
    .tick_1hz        (tick_1hz),
    .tick_blink      (tick_blink),
    .key_mode_pulse  (key_mode_pulse),
    .key_pulse_pulse (key_pulse_pulse),
    .key_rst_pulse   (key_rst_pulse)
);

// Because only one pulse key is available for editing, sw_dir selects
// whether the pulse means increment or decrement.
assign dir_is_add = sw_dir;
assign key_add_act = dir_is_add ? key_pulse_pulse : 1'b0;
assign key_sub_act = dir_is_add ? 1'b0 : key_pulse_pulse;
assign key_rst_act = key_rst_pulse;

// Mode control decides whether time runs or a selected field is edited.
set_ctrl u_set_ctrl (
    .clk               (clk),
    .rst_n             (rst_n),
    .tick_1hz          (tick_1hz),
    .key_mode          (key_mode_pulse),
    .key_add           (key_add_act),
    .key_sub           (key_sub_act),
    .key_rst           (key_rst_act),
    .mode_state        (mode_state),
    .time_tick         (time_tick),
    .hour_inc          (hour_inc),
    .hour_dec          (hour_dec),
    .min_inc           (min_inc),
    .min_dec           (min_dec),
    .sec_inc           (sec_inc),
    .sec_dec           (sec_dec),
    .hour_clr          (hour_clr),
    .min_clr           (min_clr),
    .sec_clr           (sec_clr),
    .alarm_hour_inc    (alarm_hour_inc),
    .alarm_hour_dec    (alarm_hour_dec),
    .alarm_min_inc     (alarm_min_inc),
    .alarm_min_dec     (alarm_min_dec),
    .alarm_enable_toggle(alarm_enable_toggle)
);

// Main time registers.
time_core u_time_core (
    .clk      (clk),
    .rst_n    (rst_n),
    .tick_1hz (time_tick),
    .hour_inc (hour_inc),
    .hour_dec (hour_dec),
    .min_inc  (min_inc),
    .min_dec  (min_dec),
    .sec_inc  (sec_inc),
    .sec_dec  (sec_dec),
    .hour_clr (hour_clr),
    .min_clr  (min_clr),
    .sec_clr  (sec_clr),
    .hour_tens(time_hour_tens),
    .hour_ones(time_hour_ones),
    .min_tens (time_min_tens),
    .min_ones (time_min_ones),
    .sec_tens (time_sec_tens),
    .sec_ones (time_sec_ones)
);

generate
if (ENABLE_ALARM) begin : g_alarm_on
    // Alarm logic uses the same visible running tick as the time core.
    alarm_core #(
        .ALARM_RING_SECONDS(30)
    ) u_alarm_core (
        .clk               (clk),
        .rst_n             (rst_n),
        .tick_1hz          (time_tick),
        .alarm_hour_inc    (alarm_hour_inc),
        .alarm_hour_dec    (alarm_hour_dec),
        .alarm_min_inc     (alarm_min_inc),
        .alarm_min_dec     (alarm_min_dec),
        .alarm_enable_toggle(alarm_enable_toggle),
        .alarm_stop        (key_mode_pulse | key_pulse_pulse | key_rst_pulse),
        .cur_hour_tens     (time_hour_tens),
        .cur_hour_ones     (time_hour_ones),
        .cur_min_tens      (time_min_tens),
        .cur_min_ones      (time_min_ones),
        .cur_sec_tens      (time_sec_tens),
        .cur_sec_ones      (time_sec_ones),
        .alarm_hour_tens   (alarm_hour_tens),
        .alarm_hour_ones   (alarm_hour_ones),
        .alarm_min_tens    (alarm_min_tens),
        .alarm_min_ones    (alarm_min_ones),
        .alarm_enable      (alarm_enable),
        .buzzer_en         ()
    );
end else begin : g_alarm_off
    assign alarm_hour_tens = 4'd0;
    assign alarm_hour_ones = 4'd0;
    assign alarm_min_tens  = 4'd0;
    assign alarm_min_ones  = 4'd0;
    assign alarm_enable    = 1'b0;
end
endgenerate

// Build the six display digits and blinking mask.
display_mux u_display_mux (
    .clk            (clk),
    .rst_n          (rst_n),
    .tick_blink     (tick_blink),
    .mode_state     (mode_state),
    .time_hour_tens (time_hour_tens),
    .time_hour_ones (time_hour_ones),
    .time_min_tens  (time_min_tens),
    .time_min_ones  (time_min_ones),
    .time_sec_tens  (time_sec_tens),
    .time_sec_ones  (time_sec_ones),
    .alarm_hour_tens(alarm_hour_tens),
    .alarm_hour_ones(alarm_hour_ones),
    .alarm_min_tens (alarm_min_tens),
    .alarm_min_ones (alarm_min_ones),
    .alarm_enable   (alarm_enable),
    .dig0_bcd       (dig0_bcd),
    .dig1_bcd       (dig1_bcd),
    .dig2_bcd       (dig2_bcd),
    .dig3_bcd       (dig3_bcd),
    .dig4_bcd       (dig4_bcd),
    .dig5_bcd       (dig5_bcd),
    .blank_mask     (blank_mask),
    .dp_mask        (dp_mask)
);

// LG1 is a direct seven-segment digit on TEC-8.
seg_decoder #(
    .SEG_ACTIVE_LOW(SEG_ACTIVE_LOW)
) u_lg1_decoder (
    .bcd_in (dig5_bcd),
    .blank  (blank_mask[5]),
    .dp_on  (dp_mask[5]),
    .seg_out(lg1_seg_raw)
);

assign lg1_seg = lg1_seg_raw;

// LG2~LG6 are BCD-input display digits.
assign lg2_bcd = blank_mask[4] ? 4'hF : dig4_bcd;
assign lg3_bcd = blank_mask[3] ? 4'hF : dig3_bcd;
assign lg4_bcd = blank_mask[2] ? 4'hF : dig2_bcd;
assign lg5_bcd = blank_mask[1] ? 4'hF : dig1_bcd;
assign lg6_bcd = blank_mask[0] ? 4'hF : dig0_bcd;

endmodule
