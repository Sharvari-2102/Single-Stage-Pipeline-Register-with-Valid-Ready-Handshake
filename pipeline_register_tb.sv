// Testbench for Single-Stage Pipeline Register
//
// Tests:
// 1. Basic data transfer
// 2. Backpressure handling (output not ready)
// 3. Continuous streaming
// 4. Reset behavior
// 5. No data loss/duplication

`timescale 1ns/1ps

module pipeline_register_tb;

    parameter DATA_WIDTH = 32;
    parameter CLK_PERIOD = 10;
    
    // DUT signals
    logic                   clk;
    logic                   rst_n;
    logic                   in_valid;
    logic                   in_ready;
    logic [DATA_WIDTH-1:0]  in_data;
    logic                   out_valid;
    logic                   out_ready;
    logic [DATA_WIDTH-1:0]  out_data;
    
    // Testbench variables
    int errors = 0;
    int tests_passed = 0;
    
    // DUT instantiation
    pipeline_register #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .in_data(in_data),
        .out_valid(out_valid),
        .out_ready(out_ready),
        .out_data(out_data)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Test stimulus
    initial begin
        $display("=== Pipeline Register Testbench ===");
        
        // Initialize
        rst_n = 0;
        in_valid = 0;
        in_data = 0;
        out_ready = 0;
        
        // Reset
        repeat(2) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        
        // Test 1: Basic transfer
        $display("\nTest 1: Basic data transfer");
        test_basic_transfer();
        
        // Test 2: Backpressure
        $display("\nTest 2: Backpressure handling");
        test_backpressure();
        
        // Test 3: Continuous streaming
        $display("\nTest 3: Continuous streaming");
        test_continuous_stream();
        
        // Test 4: Reset during operation
        $display("\nTest 4: Reset behavior");
        test_reset();
        
        // Test 5: Random valid/ready
        $display("\nTest 5: Random valid/ready patterns");
        test_random_handshake();
        
        // Summary
        $display("\n=== Test Summary ===");
        $display("Tests passed: %0d", tests_passed);
        $display("Errors: %0d", errors);
        
        if (errors == 0)
            $display("ALL TESTS PASSED!");
        else
            $display("SOME TESTS FAILED!");
            
        $finish;
    end
    
    // Test 1: Basic transfer
    task test_basic_transfer();
        logic [DATA_WIDTH-1:0] test_data;
        
        test_data = 32'hDEADBEEF;
        
        // Send data
        @(posedge clk);
        in_valid = 1;
        in_data = test_data;
        
        // Wait for ready
        @(posedge clk);
        if (!in_ready) begin
            $display("ERROR: in_ready not asserted when pipeline empty");
            errors++;
        end
        
        // Check transfer
        @(posedge clk);
        in_valid = 0;
        
        if (!out_valid) begin
            $display("ERROR: out_valid not asserted after transfer");
            errors++;
        end
        
        if (out_data !== test_data) begin
            $display("ERROR: Data mismatch. Expected: %h, Got: %h", test_data, out_data);
            errors++;
        end else begin
            $display("PASS: Data transferred correctly");
            tests_passed++;
        end
        
        // Consume data
        out_ready = 1;
        @(posedge clk);
        out_ready = 0;
        
        @(posedge clk);
    endtask
    
    // Test 2: Backpressure
    task test_backpressure();
        logic [DATA_WIDTH-1:0] test_data;
        
        test_data = 32'hCAFEBABE;
        
        // Send data
        @(posedge clk);
        in_valid = 1;
        in_data = test_data;
        out_ready = 0;  // Not ready to receive
        
        @(posedge clk);
        in_valid = 0;
        
        // Data should be held
        repeat(3) begin
            @(posedge clk);
            if (!out_valid) begin
                $display("ERROR: out_valid deasserted during backpressure");
                errors++;
            end
            if (out_data !== test_data) begin
                $display("ERROR: Data changed during backpressure");
                errors++;
            end
            if (in_ready) begin
                $display("ERROR: in_ready asserted while backpressured");
                errors++;
            end
        end
        
        // Release backpressure
        out_ready = 1;
        @(posedge clk);
        out_ready = 0;
        
        @(posedge clk);
        if (out_valid) begin
            $display("ERROR: out_valid still asserted after consumption");
            errors++;
        end else begin
            $display("PASS: Backpressure handled correctly");
            tests_passed++;
        end
        
        @(posedge clk);
    endtask
    
    // Test 3: Continuous streaming
    task test_continuous_stream();
        logic [DATA_WIDTH-1:0] expected_data;
        int count = 0;
        
        // Stream 10 values
        fork
            // Producer
            begin
                for (int i = 0; i < 10; i++) begin
                    @(posedge clk);
                    in_valid = 1;
                    in_data = i;
                    wait(in_ready);
                end
                @(posedge clk);
                in_valid = 0;
            end
            
            // Consumer
            begin
                out_ready = 1;
                for (int i = 0; i < 10; i++) begin
                    @(posedge clk);
                    wait(out_valid);
                    if (out_data !== i) begin
                        $display("ERROR: Stream data mismatch at %0d. Expected: %h, Got: %h", 
                                 i, i, out_data);
                        errors++;
                    end else begin
                        count++;
                    end
                end
                out_ready = 0;
            end
        join
        
        if (count == 10) begin
            $display("PASS: Continuous stream of 10 values successful");
            tests_passed++;
        end
        
        @(posedge clk);
    endtask
    
    // Test 4: Reset
    task test_reset();
        // Load data
        @(posedge clk);
        in_valid = 1;
        in_data = 32'h12345678;
        
        @(posedge clk);
        in_valid = 0;
        
        // Apply reset
        @(posedge clk);
        rst_n = 0;
        
        @(posedge clk);
        if (out_valid) begin
            $display("ERROR: out_valid not cleared by reset");
            errors++;
        end else begin
            $display("PASS: Reset clears state correctly");
            tests_passed++;
        end
        
        // Release reset
        rst_n = 1;
        @(posedge clk);
    endtask
    
    // Test 5: Random handshake
    task test_random_handshake();
        logic [DATA_WIDTH-1:0] sent_data[$];
        logic [DATA_WIDTH-1:0] received_data[$];
        logic [DATA_WIDTH-1:0] current_data;
        int num_transactions = 20;
        
        fork
            // Randomized producer
            begin
                for (int i = 0; i < num_transactions; i++) begin
                    @(posedge clk);
                    in_valid = $random % 2;
                    in_data = $random;
                    
                    if (in_valid && in_ready) begin
                        sent_data.push_back(in_data);
                    end
                end
                @(posedge clk);
                in_valid = 0;
            end
            
            // Randomized consumer
            begin
                for (int i = 0; i < num_transactions * 2; i++) begin
                    @(posedge clk);
                    out_ready = $random % 2;
                    
                    if (out_valid && out_ready) begin
                        received_data.push_back(out_data);
                    end
                    
                    if (received_data.size() >= num_transactions)
                        break;
                end
            end
        join
        
        // Wait for pipeline to drain
        out_ready = 1;
        repeat(5) @(posedge clk);
        if (out_valid && out_ready)
            received_data.push_back(out_data);
        out_ready = 0;
        
        // Verify no loss/duplication
        if (sent_data.size() != received_data.size()) begin
            $display("ERROR: Data loss or duplication. Sent: %0d, Received: %0d",
                     sent_data.size(), received_data.size());
            errors++;
        end else begin
            int mismatches = 0;
            for (int i = 0; i < sent_data.size(); i++) begin
                if (sent_data[i] !== received_data[i]) begin
                    mismatches++;
                end
            end
            if (mismatches == 0) begin
                $display("PASS: Random handshake test passed (%0d transactions)", 
                         sent_data.size());
                tests_passed++;
            end else begin
                $display("ERROR: %0d data mismatches in random test", mismatches);
                errors++;
            end
        end
        
        @(posedge clk);
    endtask
    
    // Timeout watchdog
    initial begin
        #100000;
        $display("ERROR: Testbench timeout!");
        $finish;
    end

endmodule
