// Shared time-base and compact 3-key processing for CPLD resource saving.
module input_timebase #(
    parameter integer CLK_FREQ_HZ      = 10000,
    parameter         KEY_ACTIVE_LEVEL = 1'b0,
    parameter integer SCAN_TICK_HZ     = 1000
)(
    input  wire clk,
    input  wire rst_n,
    input  wire key_mode_in,
    input  wire key_pulse_in,
    input  wire key_rst_in,
    output reg  tick_1hz,
    output reg  tick_scan,
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

localparam integer CNT_1HZ_MAX       = (CLK_FREQ_HZ / 1) - 1;
localparam integer CNT_SCAN_MAX_RAW  = (CLK_FREQ_HZ / SCAN_TICK_HZ) - 1;
localparam integer CNT_SCAN_MAX       = (CNT_SCAN_MAX_RAW   < 0) ? 0 : CNT_SCAN_MAX_RAW;
localparam integer W_CNT_1HZ    = calc_width(CNT_1HZ_MAX + 1);
localparam integer W_CNT_SCAN   = calc_width(CNT_SCAN_MAX + 1);

reg [W_CNT_1HZ-1:0] cnt_1hz;
reg [W_CNT_SCAN-1:0] cnt_scan;

reg sync0_mode;
reg sync1_mode;
reg sync0_pulse;
reg sync1_pulse;
reg sync0_rst;
reg sync1_rst;

reg prev_mode_pressed;
reg prev_pulse_pressed;
reg prev_rst_pressed;

wire key_mode_act;
wire key_pulse_act;
wire key_rst_act;

assign key_mode_act  = (sync1_mode  == KEY_ACTIVE_LEVEL);
assign key_pulse_act = (sync1_pulse == KEY_ACTIVE_LEVEL);
assign key_rst_act   = (sync1_rst   == KEY_ACTIVE_LEVEL);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cnt_1hz          <= {W_CNT_1HZ{1'b0}};
        cnt_scan         <= {W_CNT_SCAN{1'b0}};
        tick_1hz         <= 1'b0;
        tick_scan        <= 1'b0;
        tick_blink       <= 1'b0;

        sync0_mode       <= ~KEY_ACTIVE_LEVEL;
        sync1_mode       <= ~KEY_ACTIVE_LEVEL;
        sync0_pulse      <= ~KEY_ACTIVE_LEVEL;
        sync1_pulse      <= ~KEY_ACTIVE_LEVEL;
        sync0_rst        <= ~KEY_ACTIVE_LEVEL;
        sync1_rst        <= ~KEY_ACTIVE_LEVEL;
        prev_mode_pressed  <= 1'b0;
        prev_pulse_pressed <= 1'b0;
        prev_rst_pressed   <= 1'b0;

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
        tick_scan   <= 1'b0;
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

        if (cnt_scan >= CNT_SCAN_MAX[W_CNT_SCAN-1:0]) begin
            cnt_scan  <= {W_CNT_SCAN{1'b0}};
            tick_scan <= 1'b1;
        end else begin
            cnt_scan <= cnt_scan + {{(W_CNT_SCAN-1){1'b0}}, 1'b1};
        end

        // Lightweight key handling: synchronize then detect press edges.
        if (key_mode_act && !prev_mode_pressed) begin
            key_mode_pulse <= 1'b1;
        end
        if (key_pulse_act && !prev_pulse_pressed) begin
            key_pulse_pulse <= 1'b1;
        end
        if (key_rst_act && !prev_rst_pressed) begin
            key_rst_pulse <= 1'b1;
        end

        prev_mode_pressed  <= key_mode_act;
        prev_pulse_pressed <= key_pulse_act;
        prev_rst_pressed   <= key_rst_act;
    end
end

endmodule
