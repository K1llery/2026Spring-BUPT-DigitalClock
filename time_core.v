// Store the current clock time in BCD and handle both
// automatic running and manual edits.
module time_core(
    input  wire clk,
    input  wire rst_n,
    input  wire tick_1hz,
    input  wire hour_inc,
    input  wire hour_dec,
    input  wire min_inc,
    input  wire min_dec,
    input  wire sec_inc,
    input  wire sec_dec,
    input  wire hour_clr,
    input  wire min_clr,
    input  wire sec_clr,
    output reg  [3:0] hour_tens,
    output reg  [3:0] hour_ones,
    output reg  [3:0] min_tens,
    output reg  [3:0] min_ones,
    output reg  [3:0] sec_tens,
    output reg  [3:0] sec_ones
);

task inc_hour;
begin
    // 23 -> 00
    if ((hour_tens == 4'd2) && (hour_ones == 4'd3)) begin
        hour_tens <= 4'd0;
        hour_ones <= 4'd0;
    end else if (hour_ones == 4'd9) begin
        hour_tens <= hour_tens + 4'd1;
        hour_ones <= 4'd0;
    end else begin
        hour_ones <= hour_ones + 4'd1;
    end
end
endtask

task dec_hour;
begin
    // 00 -> 23
    if ((hour_tens == 4'd0) && (hour_ones == 4'd0)) begin
        hour_tens <= 4'd2;
        hour_ones <= 4'd3;
    end else if (hour_ones == 4'd0) begin
        hour_tens <= hour_tens - 4'd1;
        hour_ones <= 4'd9;
    end else begin
        hour_ones <= hour_ones - 4'd1;
    end
end
endtask

task inc_min;
begin
    // 59 -> 00
    if ((min_tens == 4'd5) && (min_ones == 4'd9)) begin
        min_tens <= 4'd0;
        min_ones <= 4'd0;
    end else if (min_ones == 4'd9) begin
        min_tens <= min_tens + 4'd1;
        min_ones <= 4'd0;
    end else begin
        min_ones <= min_ones + 4'd1;
    end
end
endtask

task dec_min;
begin
    // 00 -> 59
    if ((min_tens == 4'd0) && (min_ones == 4'd0)) begin
        min_tens <= 4'd5;
        min_ones <= 4'd9;
    end else if (min_ones == 4'd0) begin
        min_tens <= min_tens - 4'd1;
        min_ones <= 4'd9;
    end else begin
        min_ones <= min_ones - 4'd1;
    end
end
endtask

task inc_sec;
begin
    // 59 -> 00
    if ((sec_tens == 4'd5) && (sec_ones == 4'd9)) begin
        sec_tens <= 4'd0;
        sec_ones <= 4'd0;
    end else if (sec_ones == 4'd9) begin
        sec_tens <= sec_tens + 4'd1;
        sec_ones <= 4'd0;
    end else begin
        sec_ones <= sec_ones + 4'd1;
    end
end
endtask

task dec_sec;
begin
    // 00 -> 59
    if ((sec_tens == 4'd0) && (sec_ones == 4'd0)) begin
        sec_tens <= 4'd5;
        sec_ones <= 4'd9;
    end else if (sec_ones == 4'd0) begin
        sec_tens <= sec_tens - 4'd1;
        sec_ones <= 4'd9;
    end else begin
        sec_ones <= sec_ones - 4'd1;
    end
end
endtask

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        hour_tens <= 4'd0;
        hour_ones <= 4'd0;
        min_tens  <= 4'd0;
        min_ones  <= 4'd0;
        sec_tens  <= 4'd0;
        sec_ones  <= 4'd0;
    end else begin
        // Manual clear/edit commands have higher priority than normal running.
        if (hour_clr) begin
            hour_tens <= 4'd0;
            hour_ones <= 4'd0;
        end else if (min_clr) begin
            min_tens <= 4'd0;
            min_ones <= 4'd0;
        end else if (sec_clr) begin
            sec_tens <= 4'd0;
            sec_ones <= 4'd0;
        end else if (hour_inc) begin
            inc_hour;
        end else if (hour_dec) begin
            dec_hour;
        end else if (min_inc) begin
            inc_min;
        end else if (min_dec) begin
            dec_min;
        end else if (sec_inc) begin
            inc_sec;
        end else if (sec_dec) begin
            dec_sec;
        end else if (tick_1hz) begin
            // Normal time running is implemented as a BCD carry chain:
            // second -> minute -> hour.
            if ((sec_tens == 4'd5) && (sec_ones == 4'd9)) begin
                sec_tens <= 4'd0;
                sec_ones <= 4'd0;

                if ((min_tens == 4'd5) && (min_ones == 4'd9)) begin
                    min_tens <= 4'd0;
                    min_ones <= 4'd0;
                    inc_hour;
                end else if (min_ones == 4'd9) begin
                    min_tens <= min_tens + 4'd1;
                    min_ones <= 4'd0;
                end else begin
                    min_ones <= min_ones + 4'd1;
                end
            end else if (sec_ones == 4'd9) begin
                sec_tens <= sec_tens + 4'd1;
                sec_ones <= 4'd0;
            end else begin
                sec_ones <= sec_ones + 4'd1;
            end
        end
    end
end

endmodule
