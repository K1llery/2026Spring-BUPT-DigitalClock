// Generate one-cycle tick enables from the master clock.
module clk_div #(
    parameter integer CLK_FREQ_HZ    = 10000,
    parameter integer SCAN_TICK_HZ   = 1000,
    parameter integer BLINK_TICK_HZ  = 2,
    parameter integer REPEAT_TICK_HZ = 10
)(
    input  wire clk,
    input  wire rst_n,
    output reg  tick_1hz,
    output reg  tick_scan,
    output reg  tick_blink,
    output reg  tick_repeat
);

localparam integer CNT_1HZ_MAX    = (CLK_FREQ_HZ    / 1)              - 1;
localparam integer CNT_SCAN_MAX   = (CLK_FREQ_HZ    / SCAN_TICK_HZ)   - 1;
localparam integer CNT_BLINK_MAX  = (CLK_FREQ_HZ    / BLINK_TICK_HZ)  - 1;
localparam integer CNT_REPEAT_MAX = (CLK_FREQ_HZ    / REPEAT_TICK_HZ) - 1;

reg [31:0] cnt_1hz;
reg [31:0] cnt_scan;
reg [31:0] cnt_blink;
reg [31:0] cnt_repeat;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cnt_1hz     <= 32'd0;
        cnt_scan    <= 32'd0;
        cnt_blink   <= 32'd0;
        cnt_repeat  <= 32'd0;
        tick_1hz    <= 1'b0;
        tick_scan   <= 1'b0;
        tick_blink  <= 1'b0;
        tick_repeat <= 1'b0;
    end else begin
        tick_1hz    <= 1'b0;
        tick_scan   <= 1'b0;
        tick_blink  <= 1'b0;
        tick_repeat <= 1'b0;

        // 1 Hz enable for the time core.
        if (cnt_1hz >= CNT_1HZ_MAX) begin
            cnt_1hz  <= 32'd0;
            tick_1hz <= 1'b1;
        end else begin
            cnt_1hz <= cnt_1hz + 32'd1;
        end

        // Scan enable for multiplexed seven-segment display.
        if (cnt_scan >= CNT_SCAN_MAX) begin
            cnt_scan  <= 32'd0;
            tick_scan <= 1'b1;
        end else begin
            cnt_scan <= cnt_scan + 32'd1;
        end

        // Blink enable for the currently edited field.
        if (cnt_blink >= CNT_BLINK_MAX) begin
            cnt_blink  <= 32'd0;
            tick_blink <= 1'b1;
        end else begin
            cnt_blink <= cnt_blink + 32'd1;
        end

        // Repeat enable used after a key has been held long enough.
        if (cnt_repeat >= CNT_REPEAT_MAX) begin
            cnt_repeat  <= 32'd0;
            tick_repeat <= 1'b1;
        end else begin
            cnt_repeat <= cnt_repeat + 32'd1;
        end
    end
end

endmodule
