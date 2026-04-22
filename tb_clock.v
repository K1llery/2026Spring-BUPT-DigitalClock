`timescale 1us/1us

module tb_clock;

reg clk;
reg rst_n;
reg sw_dir;
reg qd_in;
reg pulse_in;
reg clr_in;
wire [7:0] lg1_seg;
wire [3:0] lg2_bcd;
wire [3:0] lg3_bcd;
wire [3:0] lg4_bcd;
wire [3:0] lg5_bcd;
wire [3:0] lg6_bcd;

clock #(
    .CLK_FREQ_HZ(10000),
    .KEY_ACTIVE_LEVEL(1'b0)
) uut (
    .clk(clk),
    .rst_n(rst_n),
    .sw_dir(sw_dir),
    .qd_in(qd_in),
    .pulse_in(pulse_in),
    .clr_in(clr_in),
    .lg1_seg(lg1_seg),
    .lg2_bcd(lg2_bcd),
    .lg3_bcd(lg3_bcd),
    .lg4_bcd(lg4_bcd),
    .lg5_bcd(lg5_bcd),
    .lg6_bcd(lg6_bcd)
);

initial begin
    clk = 1'b0;
    forever #50 clk = ~clk; // 10 kHz
end

task press_mode;
begin
    qd_in = 1'b0;
    repeat (150) @(posedge clk); // 15 ms
    qd_in = 1'b1;
    repeat (150) @(posedge clk);
end
endtask

task press_pulse;
begin
    pulse_in = 1'b0;
    repeat (150) @(posedge clk);
    pulse_in = 1'b1;
    repeat (150) @(posedge clk);
end
endtask

initial begin
    rst_n = 1'b0;
    sw_dir = 1'b1; // add direction
    qd_in = 1'b1;
    pulse_in = 1'b1;
    clr_in = 1'b1;

    repeat (20) @(posedge clk);
    rst_n = 1'b1;

    // Reset state should be 00:00:00.
    repeat (20) @(posedge clk);
    if ({uut.u_time_core.hour_tens, uut.u_time_core.hour_ones,
         uut.u_time_core.min_tens,  uut.u_time_core.min_ones,
         uut.u_time_core.sec_tens,  uut.u_time_core.sec_ones} !== 24'h000000) begin
        $display("FAIL: reset time is not 00:00:00");
        $finish;
    end

    // In RUN mode, one second tick should increment seconds to 01.
    repeat (10050) @(posedge clk);
    if ((uut.u_time_core.sec_tens !== 4'd0) || (uut.u_time_core.sec_ones !== 4'd1)) begin
        $display("FAIL: run mode second increment mismatch: %0d%0d", uut.u_time_core.sec_tens, uut.u_time_core.sec_ones);
        $finish;
    end

    // Enter SET_HOUR and increment hour once.
    press_mode();
    press_pulse();
    if ((uut.u_time_core.hour_tens !== 4'd0) || (uut.u_time_core.hour_ones !== 4'd1)) begin
        $display("FAIL: hour edit mismatch: %0d%0d", uut.u_time_core.hour_tens, uut.u_time_core.hour_ones);
        $finish;
    end

    // With default ENABLE_ALARM=0, mode loop is RUN->SET_HOUR->SET_MIN->SET_SEC->RUN.
    press_mode(); // SET_MIN
    press_mode(); // SET_SEC
    press_mode(); // RUN
    if (uut.mode_state !== 3'd0) begin
        $display("FAIL: mode loop should return to RUN when alarm is disabled, mode=%0d", uut.mode_state);
        $finish;
    end

    $display("PASS: basic reset/run/edit behavior verified");
    $finish;
end

endmodule
