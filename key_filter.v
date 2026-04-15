// Debounce one key input and generate press/hold/repeat events.
module key_filter #(
    parameter         KEY_ACTIVE_LEVEL = 1'b0,
    parameter integer CLK_FREQ_HZ      = 10000,
    parameter integer DEBOUNCE_MS      = 20,
    parameter integer HOLD_MS          = 500
)(
    input  wire clk,
    input  wire rst_n,
    input  wire key_in,
    input  wire tick_repeat,
    output reg  key_pulse,
    output reg  key_level,
    output reg  key_hold,
    output reg  key_repeat
);

localparam integer DEBOUNCE_TICKS_RAW = (CLK_FREQ_HZ * DEBOUNCE_MS) / 1000;
localparam integer HOLD_TICKS_RAW     = (CLK_FREQ_HZ * HOLD_MS)     / 1000;
localparam integer DEBOUNCE_TICKS     = (DEBOUNCE_TICKS_RAW < 1) ? 1 : DEBOUNCE_TICKS_RAW;
localparam integer HOLD_TICKS         = (HOLD_TICKS_RAW < 1)     ? 1 : HOLD_TICKS_RAW;

reg sync_0;
reg sync_1;
reg stable_raw;
reg [31:0] debounce_cnt;
reg [31:0] hold_cnt;

wire pressed_now;

assign pressed_now = (stable_raw == KEY_ACTIVE_LEVEL);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sync_0       <= ~KEY_ACTIVE_LEVEL;
        sync_1       <= ~KEY_ACTIVE_LEVEL;
        stable_raw   <= ~KEY_ACTIVE_LEVEL;
        debounce_cnt <= 32'd0;
        hold_cnt     <= 32'd0;
        key_pulse    <= 1'b0;
        key_level    <= 1'b0;
        key_hold     <= 1'b0;
        key_repeat   <= 1'b0;
    end else begin
        sync_0     <= key_in;
        sync_1     <= sync_0;
        key_pulse  <= 1'b0;
        key_repeat <= 1'b0;

        // Accept a state change only after the input stays stable
        // for the configured debounce interval.
        if (sync_1 != stable_raw) begin
            if (debounce_cnt >= (DEBOUNCE_TICKS - 1)) begin
                stable_raw   <= sync_1;
                debounce_cnt <= 32'd0;
                if (sync_1 == KEY_ACTIVE_LEVEL) begin
                    key_pulse <= 1'b1;
                    hold_cnt  <= 32'd0;
                end
            end else begin
                debounce_cnt <= debounce_cnt + 32'd1;
            end
        end else begin
            debounce_cnt <= 32'd0;
        end

        key_level <= pressed_now;

        // Once the key is held long enough, key_hold stays high and
        // repeat pulses are emitted using tick_repeat.
        if (pressed_now) begin
            if (hold_cnt >= (HOLD_TICKS - 1)) begin
                key_hold <= 1'b1;
                if (tick_repeat) begin
                    key_repeat <= 1'b1;
                end
            end else begin
                hold_cnt <= hold_cnt + 32'd1;
                key_hold <= 1'b0;
            end
        end else begin
            hold_cnt  <= 32'd0;
            key_hold  <= 1'b0;
        end
    end
end

endmodule
