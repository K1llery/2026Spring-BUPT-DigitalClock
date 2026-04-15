// Select what should be shown on the 6-digit display and
// blank the field that should blink while editing.
module display_mux(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tick_blink,
    input  wire [2:0] mode_state,
    input  wire [3:0] time_hour_tens,
    input  wire [3:0] time_hour_ones,
    input  wire [3:0] time_min_tens,
    input  wire [3:0] time_min_ones,
    input  wire [3:0] time_sec_tens,
    input  wire [3:0] time_sec_ones,
    input  wire [3:0] alarm_hour_tens,
    input  wire [3:0] alarm_hour_ones,
    input  wire [3:0] alarm_min_tens,
    input  wire [3:0] alarm_min_ones,
    input  wire       alarm_enable,
    output reg  [3:0] dig0_bcd,
    output reg  [3:0] dig1_bcd,
    output reg  [3:0] dig2_bcd,
    output reg  [3:0] dig3_bcd,
    output reg  [3:0] dig4_bcd,
    output reg  [3:0] dig5_bcd,
    output reg  [5:0] blank_mask,
    output reg  [5:0] dp_mask
);

localparam RUN            = 3'd0;
localparam SET_HOUR       = 3'd1;
localparam SET_MIN        = 3'd2;
localparam SET_SEC        = 3'd3;
localparam SET_ALARM_HOUR = 3'd4;
localparam SET_ALARM_MIN  = 3'd5;

reg blink_flag;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        blink_flag <= 1'b1;
    end else if (tick_blink) begin
        blink_flag <= ~blink_flag;
    end
end

always @(*) begin
    // Default page shows current HH:MM:SS.
    dig0_bcd   = time_hour_tens;
    dig1_bcd   = time_hour_ones;
    dig2_bcd   = time_min_tens;
    dig3_bcd   = time_min_ones;
    dig4_bcd   = time_sec_tens;
    dig5_bcd   = time_sec_ones;
    blank_mask = 6'b000000;
    dp_mask    = 6'b000000;

    if (alarm_enable) begin
        // Use one decimal point as a simple "alarm enabled" indicator.
        dp_mask[5] = 1'b1;
    end

    case (mode_state)
        SET_HOUR: begin
            if (!blink_flag) begin
                blank_mask[0] = 1'b1;
                blank_mask[1] = 1'b1;
            end
        end

        SET_MIN: begin
            if (!blink_flag) begin
                blank_mask[2] = 1'b1;
                blank_mask[3] = 1'b1;
            end
        end

        SET_SEC: begin
            if (!blink_flag) begin
                blank_mask[4] = 1'b1;
                blank_mask[5] = 1'b1;
            end
        end

        SET_ALARM_HOUR: begin
            // In alarm-setting pages, show alarm HH:MM on the left.
            dig0_bcd = alarm_hour_tens;
            dig1_bcd = alarm_hour_ones;
            dig2_bcd = alarm_min_tens;
            dig3_bcd = alarm_min_ones;
            dig4_bcd = 4'd0;
            dig5_bcd = 4'd0;
            blank_mask[4] = 1'b1;
            blank_mask[5] = 1'b1;
            if (!blink_flag) begin
                blank_mask[0] = 1'b1;
                blank_mask[1] = 1'b1;
            end
        end

        SET_ALARM_MIN: begin
            dig0_bcd = alarm_hour_tens;
            dig1_bcd = alarm_hour_ones;
            dig2_bcd = alarm_min_tens;
            dig3_bcd = alarm_min_ones;
            dig4_bcd = 4'd0;
            dig5_bcd = 4'd0;
            blank_mask[4] = 1'b1;
            blank_mask[5] = 1'b1;
            if (!blink_flag) begin
                blank_mask[2] = 1'b1;
                blank_mask[3] = 1'b1;
            end
        end

        default: begin
        end
    endcase
end

endmodule
