// Store alarm time and generate buzzer output for
// both the alarm event and the hourly chime.
module alarm_core #(
    parameter integer ALARM_RING_SECONDS = 30
)(
    input  wire clk,
    input  wire rst_n,
    input  wire tick_1hz,
    input  wire alarm_hour_inc,
    input  wire alarm_hour_dec,
    input  wire alarm_min_inc,
    input  wire alarm_min_dec,
    input  wire alarm_enable_toggle,
    input  wire alarm_stop,
    input  wire [3:0] cur_hour_tens,
    input  wire [3:0] cur_hour_ones,
    input  wire [3:0] cur_min_tens,
    input  wire [3:0] cur_min_ones,
    input  wire [3:0] cur_sec_tens,
    input  wire [3:0] cur_sec_ones,
    output reg  [3:0] alarm_hour_tens,
    output reg  [3:0] alarm_hour_ones,
    output reg  [3:0] alarm_min_tens,
    output reg  [3:0] alarm_min_ones,
    output reg        alarm_enable,
    output wire       buzzer_en
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

localparam integer ALARM_RING_TICKS = (ALARM_RING_SECONDS < 1) ? 1 : ALARM_RING_SECONDS;
localparam integer ALARM_RING_W     = calc_width(ALARM_RING_TICKS + 1);

reg        alarm_ring_active;
reg [ALARM_RING_W-1:0] alarm_ring_cnt;
wire       is_alarm_match_now;

task inc_alarm_hour;
begin
    if ((alarm_hour_tens == 4'd2) && (alarm_hour_ones == 4'd3)) begin
        alarm_hour_tens <= 4'd0;
        alarm_hour_ones <= 4'd0;
    end else if (alarm_hour_ones == 4'd9) begin
        alarm_hour_tens <= alarm_hour_tens + 4'd1;
        alarm_hour_ones <= 4'd0;
    end else begin
        alarm_hour_ones <= alarm_hour_ones + 4'd1;
    end
end
endtask

task dec_alarm_hour;
begin
    if ((alarm_hour_tens == 4'd0) && (alarm_hour_ones == 4'd0)) begin
        alarm_hour_tens <= 4'd2;
        alarm_hour_ones <= 4'd3;
    end else if (alarm_hour_ones == 4'd0) begin
        alarm_hour_tens <= alarm_hour_tens - 4'd1;
        alarm_hour_ones <= 4'd9;
    end else begin
        alarm_hour_ones <= alarm_hour_ones - 4'd1;
    end
end
endtask

task inc_alarm_min;
begin
    if ((alarm_min_tens == 4'd5) && (alarm_min_ones == 4'd9)) begin
        alarm_min_tens <= 4'd0;
        alarm_min_ones <= 4'd0;
    end else if (alarm_min_ones == 4'd9) begin
        alarm_min_tens <= alarm_min_tens + 4'd1;
        alarm_min_ones <= 4'd0;
    end else begin
        alarm_min_ones <= alarm_min_ones + 4'd1;
    end
end
endtask

task dec_alarm_min;
begin
    if ((alarm_min_tens == 4'd0) && (alarm_min_ones == 4'd0)) begin
        alarm_min_tens <= 4'd5;
        alarm_min_ones <= 4'd9;
    end else if (alarm_min_ones == 4'd0) begin
        alarm_min_tens <= alarm_min_tens - 4'd1;
        alarm_min_ones <= 4'd9;
    end else begin
        alarm_min_ones <= alarm_min_ones - 4'd1;
    end
end
endtask

assign is_alarm_match_now =
    (cur_sec_tens  == 4'd0) &&
    (cur_sec_ones  == 4'd0) &&
    (cur_hour_tens == alarm_hour_tens) &&
    (cur_hour_ones == alarm_hour_ones) &&
    (cur_min_tens  == alarm_min_tens)  &&
    (cur_min_ones  == alarm_min_ones);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        alarm_hour_tens   <= 4'd0;
        alarm_hour_ones   <= 4'd0;
        alarm_min_tens    <= 4'd0;
        alarm_min_ones    <= 4'd0;
        alarm_enable      <= 1'b0;
        alarm_ring_active <= 1'b0;
        alarm_ring_cnt    <= {ALARM_RING_W{1'b0}};
    end else begin
        if (alarm_enable_toggle) begin
            alarm_enable <= ~alarm_enable;
        end

        // Alarm time editing is independent from the main time core.
        if (alarm_hour_inc) begin
            inc_alarm_hour;
        end else if (alarm_hour_dec) begin
            dec_alarm_hour;
        end else if (alarm_min_inc) begin
            inc_alarm_min;
        end else if (alarm_min_dec) begin
            dec_alarm_min;
        end

        if (alarm_stop) begin
            alarm_ring_active <= 1'b0;
            alarm_ring_cnt    <= {ALARM_RING_W{1'b0}};
        end else if (tick_1hz) begin
            if (alarm_ring_active) begin
                if (alarm_ring_cnt <= {{(ALARM_RING_W-1){1'b0}}, 1'b1}) begin
                    alarm_ring_active <= 1'b0;
                    alarm_ring_cnt    <= {ALARM_RING_W{1'b0}};
                end else begin
                    alarm_ring_cnt <= alarm_ring_cnt - {{(ALARM_RING_W-1){1'b0}}, 1'b1};
                end
            end

            // Lightweight match logic: trigger alarm when current HH:MM:00 is visible.
            if (alarm_enable && is_alarm_match_now) begin
                alarm_ring_active <= 1'b1;
                alarm_ring_cnt    <= ALARM_RING_TICKS[ALARM_RING_W-1:0];
            end
        end
    end
end

assign buzzer_en = alarm_ring_active;

endmodule
