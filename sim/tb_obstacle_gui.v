`timescale 1ns/1ps

module tb_obstacle_gui;
    reg clk = 0, rst = 1, echo = 0;
    wire trig, led_green, led_yellow, led_red, buzzer, valid, result_ready;
    wire [1:0] level;
    integer distance_cm;
    integer no_echo;

    always #500 clk = ~clk;

    obstacle_warning #(.CLK_MHZ(1)) dut (
        .clk(clk), .rst(rst), .echo(echo), .trig(trig),
        .led_green(led_green), .led_yellow(led_yellow), .led_red(led_red),
        .buzzer(buzzer), .level(level), .valid(valid), .result_ready(result_ready)
    );

    initial begin
        if (!$value$plusargs("distance_cm=%d", distance_cm) ||
            distance_cm < 2 || distance_cm > 400)
            $fatal(1, "distance_cm must be between 2 and 400");
        if (!$value$plusargs("no_echo=%d", no_echo))
            no_echo = 0;

        repeat (5) @(negedge clk);
        rst = 0;
        @(negedge trig);
        repeat (200) @(negedge clk);
        if (no_echo == 0) begin
            echo = 1;
            #(distance_cm * 58 * 1000) echo = 0;
        end
        @(posedge result_ready);
        @(negedge clk);
        $display("RESULT %0d %b %b %b %b %b",
                 level, valid, led_green, led_yellow, led_red, buzzer);
        $finish;
    end

    initial begin
        #40_000_000;
        $fatal(1, "No result from the warning circuit");
    end
endmodule
