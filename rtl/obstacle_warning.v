`timescale 1ns/1ps

module obstacle_warning #(
    parameter integer CLK_MHZ = 50,
    parameter integer DANGER_CM = 20,
    parameter integer WARNING_CM = 50
)(
    input  wire clk,
    input  wire rst,
    input  wire echo,
    output reg  trig,
    output wire led_green,
    output wire led_yellow,
    output wire led_red,
    output wire buzzer,
    output reg  [1:0] level,
    output reg  valid,
    output reg  result_ready
);
    localparam integer TRIG_TICKS = 10 * CLK_MHZ;
    localparam integer PERIOD_TICKS = 65000 * CLK_MHZ;
    localparam integer TIMEOUT_TICKS = 30000 * CLK_MHZ;
    localparam integer TICKS_PER_CM = 58 * CLK_MHZ;
    localparam integer MIN_TICKS = 2 * TICKS_PER_CM;
    localparam integer MAX_TICKS = 400 * TICKS_PER_CM;
    localparam integer TIMER_WIDTH = $clog2(PERIOD_TICKS);

    localparam [1:0] SAFE = 2'd0, WARNING = 2'd1,
                     DANGER = 2'd2, FAULT = 2'd3;
    localparam [1:0] IDLE = 2'd0, TRIGGER = 2'd1,
                     WAIT_RISE = 2'd2, MEASURE = 2'd3;

    (* ASYNC_REG = "TRUE" *) reg echo_meta, echo_sync;
    reg [1:0] state;
    reg [TIMER_WIDTH-1:0] cooldown, timer;

    assign led_green  = level == SAFE;
    assign led_yellow = level == WARNING || level == FAULT;
    assign led_red    = level == DANGER || level == FAULT;
    assign buzzer     = level == DANGER;

    always @(posedge clk) begin
        if (rst) begin
            echo_meta <= 1'b0;
            echo_sync <= 1'b0;
        end else begin
            echo_meta <= echo;
            echo_sync <= echo_meta;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            state        <= IDLE;
            // Let the synchronizer sample Echo before the first trigger.
            cooldown     <= 2;
            timer        <= 0;
            trig         <= 1'b0;
            level        <= FAULT;
            valid        <= 1'b0;
            result_ready <= 1'b0;
        end else begin
            result_ready <= 1'b0;
            if (cooldown != 0)
                cooldown <= cooldown - 1'b1;

            case (state)
                IDLE: if (cooldown == 0) begin
                    cooldown <= PERIOD_TICKS - 1;
                    timer <= 0;
                    if (echo_sync) begin
                        level <= FAULT;
                        valid <= 1'b0;
                        result_ready <= 1'b1;
                    end else begin
                        trig <= 1'b1;
                        state <= TRIGGER;
                    end
                end

                TRIGGER: if (timer == TRIG_TICKS - 1) begin
                    trig <= 1'b0;
                    timer <= 0;
                    state <= WAIT_RISE;
                end else begin
                    timer <= timer + 1'b1;
                end

                WAIT_RISE: if (echo_sync) begin
                    timer <= 1;
                    state <= MEASURE;
                end else if (timer == TIMEOUT_TICKS - 1) begin
                    level <= FAULT;
                    valid <= 1'b0;
                    result_ready <= 1'b1;
                    state <= IDLE;
                end else begin
                    timer <= timer + 1'b1;
                end

                MEASURE: if (!echo_sync || timer == TIMEOUT_TICKS) begin
                    state <= IDLE;
                    result_ready <= 1'b1;
                    valid <= !echo_sync && timer >= MIN_TICKS && timer <= MAX_TICKS;
                    if (echo_sync || timer < MIN_TICKS || timer > MAX_TICKS)
                        level <= FAULT;
                    else if (timer <= DANGER_CM * TICKS_PER_CM)
                        level <= DANGER;
                    else if (timer <= WARNING_CM * TICKS_PER_CM)
                        level <= WARNING;
                    else
                        level <= SAFE;
                end else begin
                    timer <= timer + 1'b1;
                end
            endcase
        end
    end
endmodule
