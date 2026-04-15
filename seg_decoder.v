// Convert one BCD digit into the segment pattern for one display position.
module seg_decoder #(
    parameter SEG_ACTIVE_LOW = 1'b1
)(
    input  wire [3:0] bcd_in,
    input  wire       blank,
    input  wire       dp_on,
    output wire [7:0] seg_out
);

reg [7:0] seg_raw;

always @(*) begin
    if (blank) begin
        seg_raw = 8'b00000000;
    end else begin
        case (bcd_in)
            4'd0: seg_raw = 8'b11111100;
            4'd1: seg_raw = 8'b01100000;
            4'd2: seg_raw = 8'b11011010;
            4'd3: seg_raw = 8'b11110010;
            4'd4: seg_raw = 8'b01100110;
            4'd5: seg_raw = 8'b10110110;
            4'd6: seg_raw = 8'b10111110;
            4'd7: seg_raw = 8'b11100000;
            4'd8: seg_raw = 8'b11111110;
            4'd9: seg_raw = 8'b11110110;
            default: seg_raw = 8'b00000000;
        endcase
    end

    // Bit 0 is used as the decimal point output in this project.
    seg_raw[0] = dp_on;
end

assign seg_out = SEG_ACTIVE_LOW ? ~seg_raw : seg_raw;

endmodule
