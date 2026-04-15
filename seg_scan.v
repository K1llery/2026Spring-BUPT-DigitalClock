// Multiplex six display digits using a scan index and one shared segment bus.
module seg_scan #(
    parameter SEG_ACTIVE_LOW = 1'b1,
    parameter DIG_ACTIVE_LOW = 1'b1
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tick_scan,
    input  wire [3:0] dig0_bcd,
    input  wire [3:0] dig1_bcd,
    input  wire [3:0] dig2_bcd,
    input  wire [3:0] dig3_bcd,
    input  wire [3:0] dig4_bcd,
    input  wire [3:0] dig5_bcd,
    input  wire [5:0] blank_mask,
    input  wire [5:0] dp_mask,
    output reg  [5:0] dig_sel,
    output wire [7:0] seg_out
);

reg [2:0] scan_idx;
reg [3:0] cur_bcd;
reg       cur_blank;
reg       cur_dp;
reg [5:0] dig_sel_raw;
wire [7:0] seg_code;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        scan_idx <= 3'd0;
    end else if (tick_scan) begin
        // Move to the next digit on every scan enable pulse.
        if (scan_idx == 3'd5) begin
            scan_idx <= 3'd0;
        end else begin
            scan_idx <= scan_idx + 3'd1;
        end
    end
end

always @(*) begin
    // Select the BCD value and display attributes of the active digit.
    case (scan_idx)
        3'd0: begin
            cur_bcd   = dig0_bcd;
            cur_blank = blank_mask[0];
            cur_dp    = dp_mask[0];
        end
        3'd1: begin
            cur_bcd   = dig1_bcd;
            cur_blank = blank_mask[1];
            cur_dp    = dp_mask[1];
        end
        3'd2: begin
            cur_bcd   = dig2_bcd;
            cur_blank = blank_mask[2];
            cur_dp    = dp_mask[2];
        end
        3'd3: begin
            cur_bcd   = dig3_bcd;
            cur_blank = blank_mask[3];
            cur_dp    = dp_mask[3];
        end
        3'd4: begin
            cur_bcd   = dig4_bcd;
            cur_blank = blank_mask[4];
            cur_dp    = dp_mask[4];
        end
        default: begin
            cur_bcd   = dig5_bcd;
            cur_blank = blank_mask[5];
            cur_dp    = dp_mask[5];
        end
    endcase
end

always @(*) begin
    // Only one digit is enabled at a time.
    case (scan_idx)
        3'd0: dig_sel_raw = 6'b000001;
        3'd1: dig_sel_raw = 6'b000010;
        3'd2: dig_sel_raw = 6'b000100;
        3'd3: dig_sel_raw = 6'b001000;
        3'd4: dig_sel_raw = 6'b010000;
        default: dig_sel_raw = 6'b100000;
    endcase
end

seg_decoder #(
    .SEG_ACTIVE_LOW(SEG_ACTIVE_LOW)
) u_seg_decoder (
    .bcd_in (cur_bcd),
    .blank  (cur_blank),
    .dp_on  (cur_dp),
    .seg_out(seg_code)
);

assign seg_out = seg_code;

always @(*) begin
    if (DIG_ACTIVE_LOW) begin
        dig_sel = ~dig_sel_raw;
    end else begin
        dig_sel = dig_sel_raw;
    end
end

endmodule
