// Shared time-base and compact 3-key processing for CPLD resource saving.
module input_timebase #(
    parameter integer CLK_FREQ_HZ      = 10000,
    parameter         KEY_ACTIVE_LEVEL = 1'b0
)(
    input  wire clk,
    input  wire rst_n,
    input  wire key_mode_in,
    input  wire key_pulse_in,
    input  wire key_rst_in,
    output reg  tick_1hz,
    output reg  tick_blink,
    output reg  key_mode_pulse,
    output reg  key_pulse_pulse,
    output reg  key_rst_pulse
);

function integer calc_width;
    input integer value;
    integer v;
begin
    v = value - 1;
    calc_width = 0;
    while (v > 0) begin
        calc_width = calc_width + 1;
        v = v >> 1;
    end
    if (calc_width < 1)
        calc_width = 1;
end
endfunction

function integer pick_tap_bit;
    input integer target_cycles;
    input integer max_bit;
    integer interval_cycles;
    integer bit_idx;
begin
    bit_idx = 0;
    interval_cycles = 2;
    while ((interval_cycles < target_cycles) && (bit_idx < max_bit)) begin
        interval_cycles = interval_cycles << 1;
        bit_idx = bit_idx + 1;
    end
    pick_tap_bit = bit_idx;
end
endfunction

localparam integer CNT_1HZ_MAX            = (CLK_FREQ_HZ / 1) - 1;
localparam integer W_CNT_1HZ              = calc_width(CNT_1HZ_MAX + 1);
localparam integer MAX_TAP_BIT            = (W_CNT_1HZ > 1) ? (W_CNT_1HZ - 1) : 0;
localparam integer SAMPLE_TARGET_CYCLES_R = CLK_FREQ_HZ / 250;
localparam integer SAMPLE_TARGET_CYCLES   = (SAMPLE_TARGET_CYCLES_R < 2) ? 2 : SAMPLE_TARGET_CYCLES_R;
localparam integer HOLD_TARGET_CYCLES_R   = (CLK_FREQ_HZ * 65) / 1000;
localparam integer HOLD_TARGET_CYCLES     = (HOLD_TARGET_CYCLES_R < 2) ? 2 : HOLD_TARGET_CYCLES_R;
localparam integer SAMPLE_TAP_BIT         = pick_tap_bit(SAMPLE_TARGET_CYCLES, MAX_TAP_BIT);
localparam integer HOLD_TAP_BIT           = pick_tap_bit(HOLD_TARGET_CYCLES, MAX_TAP_BIT);
localparam integer HOLD_TICK_CYCLES       = (1 << (HOLD_TAP_BIT + 1));
localparam integer HOLD_START_TICKS_R     = ((CLK_FREQ_HZ / 2) + HOLD_TICK_CYCLES - 1) / HOLD_TICK_CYCLES;
localparam integer HOLD_START_TICKS       = (HOLD_START_TICKS_R < 1) ? 1 : HOLD_START_TICKS_R;
localparam integer HOLD_COUNT_W           = calc_width(HOLD_START_TICKS + 1);

reg [W_CNT_1HZ-1:0] cnt_1hz;

reg sync0_mode;
reg sync1_mode;
reg sync0_pulse;
reg sync1_pulse;
reg sync0_rst;
reg sync1_rst;

reg sample_tap_prev;
reg hold_tap_prev;
reg mode_sample_prev;
reg pulse_sample_prev;
reg rst_sample_prev;
reg mode_pressed;
reg pulse_pressed;
reg rst_pressed;
reg [HOLD_COUNT_W-1:0] pulse_hold_ticks;

wire key_mode_act;
wire key_pulse_act;
wire key_rst_act;
wire sample_tick;
wire hold_tick;

assign key_mode_act  = (sync1_mode  == KEY_ACTIVE_LEVEL);
assign key_pulse_act = (sync1_pulse == KEY_ACTIVE_LEVEL);
assign key_rst_act   = (sync1_rst   == KEY_ACTIVE_LEVEL);
assign sample_tick   = cnt_1hz[SAMPLE_TAP_BIT] & ~sample_tap_prev;
assign hold_tick     = cnt_1hz[HOLD_TAP_BIT]   & ~hold_tap_prev;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cnt_1hz          <= {W_CNT_1HZ{1'b0}};
        tick_1hz         <= 1'b0;
        tick_blink       <= 1'b0;

        sync0_mode       <= ~KEY_ACTIVE_LEVEL;
        sync1_mode       <= ~KEY_ACTIVE_LEVEL;
        sync0_pulse      <= ~KEY_ACTIVE_LEVEL;
        sync1_pulse      <= ~KEY_ACTIVE_LEVEL;
        sync0_rst        <= ~KEY_ACTIVE_LEVEL;
        sync1_rst        <= ~KEY_ACTIVE_LEVEL;
        sample_tap_prev  <= 1'b0;
        hold_tap_prev    <= 1'b0;
        mode_sample_prev <= 1'b0;
        pulse_sample_prev <= 1'b0;
        rst_sample_prev  <= 1'b0;
        mode_pressed     <= 1'b0;
        pulse_pressed    <= 1'b0;
        rst_pressed      <= 1'b0;
        pulse_hold_ticks <= {HOLD_COUNT_W{1'b0}};

        key_mode_pulse   <= 1'b0;
        key_pulse_pulse  <= 1'b0;
        key_rst_pulse    <= 1'b0;
    end else begin
        sync0_mode <= key_mode_in;
        sync1_mode <= sync0_mode;
        sync0_pulse <= key_pulse_in;
        sync1_pulse <= sync0_pulse;
        sync0_rst <= key_rst_in;
        sync1_rst <= sync0_rst;

        tick_1hz    <= 1'b0;
        tick_blink  <= 1'b0;

        key_mode_pulse   <= 1'b0;
        key_pulse_pulse  <= 1'b0;
        key_rst_pulse    <= 1'b0;

        if (cnt_1hz >= CNT_1HZ_MAX[W_CNT_1HZ-1:0]) begin
            cnt_1hz   <= {W_CNT_1HZ{1'b0}};
            tick_1hz  <= 1'b1;
            tick_blink <= 1'b1;
        end else begin
            cnt_1hz <= cnt_1hz + {{(W_CNT_1HZ-1){1'b0}}, 1'b1};
        end

        if (sample_tick) begin
            if (key_mode_act == mode_sample_prev) begin
                if (mode_pressed != key_mode_act) begin
                    mode_pressed <= key_mode_act;
                    if (key_mode_act) begin
                        key_mode_pulse <= 1'b1;
                    end
                end
            end

            if (key_pulse_act == pulse_sample_prev) begin
                if (pulse_pressed != key_pulse_act) begin
                    pulse_pressed <= key_pulse_act;
                    if (key_pulse_act) begin
                        pulse_hold_ticks <= {HOLD_COUNT_W{1'b0}};
                        key_pulse_pulse  <= 1'b1;
                    end else begin
                        pulse_hold_ticks <= {HOLD_COUNT_W{1'b0}};
                    end
                end
            end

            if (key_rst_act == rst_sample_prev) begin
                if (rst_pressed != key_rst_act) begin
                    rst_pressed <= key_rst_act;
                    if (key_rst_act) begin
                        key_rst_pulse <= 1'b1;
                    end
                end
            end

            mode_sample_prev  <= key_mode_act;
            pulse_sample_prev <= key_pulse_act;
            rst_sample_prev   <= key_rst_act;
        end

        if (!pulse_pressed) begin
            pulse_hold_ticks <= {HOLD_COUNT_W{1'b0}};
        end else if (hold_tick) begin
            if (pulse_hold_ticks >= (HOLD_START_TICKS - 1)) begin
                key_pulse_pulse <= 1'b1;
            end else begin
                pulse_hold_ticks <= pulse_hold_ticks + {{(HOLD_COUNT_W-1){1'b0}}, 1'b1};
            end
        end

        sample_tap_prev <= cnt_1hz[SAMPLE_TAP_BIT];
        hold_tap_prev   <= cnt_1hz[HOLD_TAP_BIT];
    end
end

endmodule
