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

localparam integer KEY_HOLD_CYCLES  = 300;
localparam integer KEY_GAP_CYCLES   = 300;
localparam integer ONE_SECOND_CYCLES = 10050;
localparam integer LONG_HOLD_CYCLES = 14000;

function integer bcd_pair_to_int;
input [3:0] tens;
input [3:0] ones;
begin
    bcd_pair_to_int = (tens * 10) + ones;
end
endfunction

task expect_time;
input [23:0] expected_bcd;
begin
    if ({uut.u_time_core.hour_tens, uut.u_time_core.hour_ones,
         uut.u_time_core.min_tens,  uut.u_time_core.min_ones,
         uut.u_time_core.sec_tens,  uut.u_time_core.sec_ones} !== expected_bcd) begin
        $display("FAIL: expected BCD time %h, got %h",
                 expected_bcd,
                 {uut.u_time_core.hour_tens, uut.u_time_core.hour_ones,
                  uut.u_time_core.min_tens,  uut.u_time_core.min_ones,
                  uut.u_time_core.sec_tens,  uut.u_time_core.sec_ones});
        $finish;
    end
end
endtask

task load_time;
input [23:0] time_bcd;
begin
    uut.u_time_core.hour_tens = time_bcd[23:20];
    uut.u_time_core.hour_ones = time_bcd[19:16];
    uut.u_time_core.min_tens  = time_bcd[15:12];
    uut.u_time_core.min_ones  = time_bcd[11:8];
    uut.u_time_core.sec_tens  = time_bcd[7:4];
    uut.u_time_core.sec_ones  = time_bcd[3:0];
end
endtask

task press_mode;
begin
    qd_in = 1'b0;
    repeat (KEY_HOLD_CYCLES) @(posedge clk);
    qd_in = 1'b1;
    repeat (KEY_GAP_CYCLES) @(posedge clk);
end
endtask

task press_pulse;
begin
    pulse_in = 1'b0;
    repeat (KEY_HOLD_CYCLES) @(posedge clk);
    pulse_in = 1'b1;
    repeat (KEY_GAP_CYCLES) @(posedge clk);
end
endtask

task hold_pulse;
input integer hold_cycles;
begin
    pulse_in = 1'b0;
    repeat (hold_cycles) @(posedge clk);
    pulse_in = 1'b1;
    repeat (KEY_GAP_CYCLES) @(posedge clk);
end
endtask

task press_clr;
begin
    clr_in = 1'b0;
    repeat (KEY_HOLD_CYCLES) @(posedge clk);
    clr_in = 1'b1;
    repeat (KEY_GAP_CYCLES) @(posedge clk);
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

    repeat (20) @(posedge clk);
    expect_time(24'h000000);

    // In RUN mode, one second tick should increment seconds to 01.
    repeat (ONE_SECOND_CYCLES) @(posedge clk);
    expect_time(24'h000001);

    // Verify 23:59:59 wraps cleanly back to 00:00:00.
    load_time(24'h235959);
    repeat (ONE_SECOND_CYCLES) @(posedge clk);
    expect_time(24'h000000);

    // Edit modes should freeze the normal running second tick.
    load_time(24'h123456);
    press_mode();
    repeat (ONE_SECOND_CYCLES) @(posedge clk);
    expect_time(24'h123456);

    // SET_HOUR: single increment then wrap-around decrement.
    press_pulse();
    expect_time(24'h133456);

    load_time(24'h003456);
    sw_dir = 1'b0;
    press_pulse();
    expect_time(24'h233456);

    // SET_MIN: clear then decrement wrap-around.
    press_mode();
    sw_dir = 1'b1;
    load_time(24'h231234);
    press_clr();
    expect_time(24'h230034);

    sw_dir = 1'b0;
    load_time(24'h230034);
    press_pulse();
    expect_time(24'h235934);

    // SET_SEC: clear then decrement wrap-around.
    press_mode();
    sw_dir = 1'b1;
    load_time(24'h235945);
    press_clr();
    expect_time(24'h235900);

    sw_dir = 1'b0;
    load_time(24'h235900);
    press_pulse();
    expect_time(24'h235959);

    // With default ENABLE_ALARM=0, mode loop is RUN->SET_HOUR->SET_MIN->SET_SEC->RUN.
    press_mode();
    if (uut.mode_state !== 3'd0) begin
        $display("FAIL: mode loop should return to RUN when alarm is disabled, mode=%0d",
                 uut.mode_state);
        $finish;
    end

    // Long-press should fast-adjust the selected field in SET_HOUR mode.
    load_time(24'h010000);
    sw_dir = 1'b1;
    press_mode();
    hold_pulse(LONG_HOLD_CYCLES);
    if (bcd_pair_to_int(uut.u_time_core.hour_tens, uut.u_time_core.hour_ones) <= 2) begin
        $display("FAIL: long press did not trigger repeated hour adjustment, hour=%0d%0d",
                 uut.u_time_core.hour_tens, uut.u_time_core.hour_ones);
        $finish;
    end

    $display("PASS: reset/run/edit/wrap/clear/hold behavior verified");
    $finish;
end

endmodule
