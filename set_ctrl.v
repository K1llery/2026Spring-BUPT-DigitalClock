// Route key commands according to the current edit mode.
module set_ctrl(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tick_1hz,
    input  wire       key_mode,
    input  wire       key_add,
    input  wire       key_sub,
    input  wire       key_rst,
    output reg  [2:0] mode_state,
    output wire       time_tick,
    output wire       hour_inc,
    output wire       hour_dec,
    output wire       min_inc,
    output wire       min_dec,
    output wire       sec_inc,
    output wire       sec_dec,
    output wire       hour_clr,
    output wire       min_clr,
    output wire       sec_clr,
    output wire       alarm_hour_inc,
    output wire       alarm_hour_dec,
    output wire       alarm_min_inc,
    output wire       alarm_min_dec,
    output wire       alarm_enable_toggle
);

localparam RUN            = 3'd0;
localparam SET_HOUR       = 3'd1;
localparam SET_MIN        = 3'd2;
localparam SET_SEC        = 3'd3;
localparam SET_ALARM_HOUR = 3'd4;
localparam SET_ALARM_MIN  = 3'd5;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mode_state <= RUN;
    end else if (key_mode) begin
        // Cycle through all modes with one key.
        if (mode_state == SET_ALARM_MIN) begin
            mode_state <= RUN;
        end else begin
            mode_state <= mode_state + 3'd1;
        end
    end
end

// Only RUN mode is allowed to advance time automatically.
assign time_tick           = (mode_state == RUN)            ? tick_1hz : 1'b0;
assign hour_inc            = (mode_state == SET_HOUR)       ? key_add  : 1'b0;
assign hour_dec            = (mode_state == SET_HOUR)       ? key_sub  : 1'b0;
assign min_inc             = (mode_state == SET_MIN)        ? key_add  : 1'b0;
assign min_dec             = (mode_state == SET_MIN)        ? key_sub  : 1'b0;
assign sec_inc             = (mode_state == SET_SEC)        ? key_add  : 1'b0;
assign sec_dec             = (mode_state == SET_SEC)        ? key_sub  : 1'b0;
assign hour_clr            = (mode_state == SET_HOUR)       ? key_rst  : 1'b0;
assign min_clr             = (mode_state == SET_MIN)        ? key_rst  : 1'b0;
assign sec_clr             = (mode_state == SET_SEC)        ? key_rst  : 1'b0;
assign alarm_hour_inc      = (mode_state == SET_ALARM_HOUR) ? key_add  : 1'b0;
assign alarm_hour_dec      = (mode_state == SET_ALARM_HOUR) ? key_sub  : 1'b0;
assign alarm_min_inc       = (mode_state == SET_ALARM_MIN)  ? key_add  : 1'b0;
assign alarm_min_dec       = (mode_state == SET_ALARM_MIN)  ? key_sub  : 1'b0;
assign alarm_enable_toggle = ((mode_state == RUN) || (mode_state == SET_ALARM_HOUR) || (mode_state == SET_ALARM_MIN)) ? key_rst : 1'b0;

endmodule
