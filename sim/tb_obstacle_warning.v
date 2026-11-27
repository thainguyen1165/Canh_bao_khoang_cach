`timescale 1ns/1ps

module tb_obstacle_warning;
    parameter integer CLK_MHZ = 1;
    localparam integer HALF_NS = 500 / CLK_MHZ;

    reg clk = 0, rst = 1, echo = 0;
    wire trig, led_green, led_yellow, led_red, buzzer, valid, result_ready;
    wire [1:0] level;
    time last_trigger = 0;
    integer passed = 0;

    always #(HALF_NS) clk = ~clk;

    obstacle_warning #(.CLK_MHZ(CLK_MHZ)) dut (
        .clk(clk), .rst(rst), .echo(echo), .trig(trig),
        .led_green(led_green), .led_yellow(led_yellow), .led_red(led_red),
        .buzzer(buzzer), .level(level), .valid(valid), .result_ready(result_ready)
    );

    always @(posedge trig) begin
        if (last_trigger != 0 && $time - last_trigger < 65_000_000)
            $fatal(1, "TRIG period below 65 ms");
        last_trigger = $time;
    end

    task await_trigger;
        time start_ns;
        begin
            @(posedge trig);
            start_ns = $time;
            @(negedge trig);
            if ($time - start_ns != 10_000)
                $fatal(1, "Incorrect TRIG pulse width");
            repeat (200 * CLK_MHZ) @(negedge clk);
        end
    endtask

    task expect_result;
        input [1:0] expected;
        input [8*48-1:0] label;
        reg [3:0] expected_outputs;
        begin
            @(posedge result_ready);
            @(negedge clk);
            case (expected)
                0: expected_outputs = 4'b1000;
                1: expected_outputs = 4'b0100;
                2: expected_outputs = 4'b0011;
                3: expected_outputs = 4'b0110;
            endcase
            if (level !== expected || valid !== (expected != 3) ||
                {led_green, led_yellow, led_red, buzzer} !== expected_outputs)
                $fatal(1, "%0s: level=%b valid=%b outputs=%b", label, level,
                       valid, {led_green, led_yellow, led_red, buzzer});
            @(negedge clk);
            if (result_ready !== 1'b0)
                $fatal(1, "result_ready did not clear after one clock");
            passed = passed + 1;
            $display("PASS  %-32s level=%0d valid=%b", label, level, valid);
        end
    endtask

    task measure;
        input integer width_us;
        input [1:0] expected;
        input [8*48-1:0] label;
        begin
            await_trigger;
            echo = 1;
            #(width_us * 1000) echo = 0;
            expect_result(expected, label);
        end
    endtask

    initial begin
        $dumpfile("build/obstacle_warning.vcd");
        $dumpvars(0, trig, echo, level, valid, result_ready,
                  led_green, led_yellow, led_red, buzzer, rst);
        $display("Simulation clock: %0d MHz", CLK_MHZ);
        repeat (5) @(negedge clk);
        if ({level, valid, trig, result_ready, led_green, led_yellow, led_red, buzzer}
            !== {2'd3, 1'b0, 1'b0, 1'b0, 4'b0110})
            $fatal(1, "Incorrect reset outputs");
        echo = 1;
        rst = 0;
        expect_result(3, "Echo already high at startup");
        if (trig !== 1'b0 || last_trigger != 0)
            $fatal(1, "TRIG asserted with Echo high at startup");
        echo = 0;

        measure(80 * 58, 0, "80 cm");
        measure(50 * 58 + 1, 0, "50 cm + 1 us");
        measure(50 * 58, 1, "50 cm boundary");
        measure(20 * 58 + 1, 1, "20 cm + 1 us");
        measure(20 * 58, 2, "20 cm boundary");
        measure(2 * 58, 2, "2 cm lower limit");
        measure(2 * 58 - 1, 3, "Below 2 cm");
        measure(400 * 58, 0, "400 cm upper limit");
        measure(400 * 58 + 1, 3, "Above 400 cm");

        await_trigger;
        expect_result(3, "Missing echo");
        await_trigger;
        echo = 1;
        expect_result(3, "Stuck-high echo timeout");
        expect_result(3, "High echo inhibits next trigger");
        if (trig !== 1'b0)
            $fatal(1, "TRIG asserted during stuck-high echo");
        echo = 0;
        measure(35 * 58, 1, "Recovery after timeout");

        $display("PASS: %0d scenarios plus reset and TRIG timing checks", passed);
        $finish;
    end

    initial begin
        #1_100_000_000;
        $fatal(1, "Simulation watchdog expired");
    end
endmodule
