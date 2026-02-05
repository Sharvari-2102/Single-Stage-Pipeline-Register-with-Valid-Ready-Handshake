// Single-Stage Pipeline Register with Valid/Ready Handshake
// 
// This module implements a standard pipeline register that sits between
// an input and output interface, handling backpressure correctly.
//
// Protocol:
// - Data transfer occurs when both valid and ready are high
// - in_ready indicates this stage can accept new data
// - out_valid indicates this stage has valid data to present
// - No data loss or duplication under backpressure

module pipeline_register #(
    parameter int DATA_WIDTH = 32
) (
    input  logic                    clk,
    input  logic                    rst_n,
    
    // Input interface
    input  logic                    in_valid,
    output logic                    in_ready,
    input  logic [DATA_WIDTH-1:0]   in_data,
    
    // Output interface
    output logic                    out_valid,
    input  logic                    out_ready,
    output logic [DATA_WIDTH-1:0]   out_data
);

    // Internal storage
    logic [DATA_WIDTH-1:0] data_reg;
    logic                  valid_reg;
    
    // Handshake logic
    logic input_transfer;   // Data is being accepted from input
    logic output_transfer;  // Data is being consumed by output
    
    assign input_transfer  = in_valid && in_ready;
    assign output_transfer = out_valid && out_ready;
    
    // Ready when register is empty OR when output is being consumed
    assign in_ready = !valid_reg || output_transfer;
    
    // Valid when register has data
    assign out_valid = valid_reg;
    assign out_data  = data_reg;
    
    // State update
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_reg <= 1'b0;
            data_reg  <= '0;
        end else begin
            // Case 1: Input and output transfer simultaneously - update data
            // Case 2: Input transfer only - load new data, set valid
            // Case 3: Output transfer only - clear valid
            // Case 4: No transfer - maintain state
            
            if (input_transfer) begin
                data_reg  <= in_data;
                valid_reg <= 1'b1;
            end else if (output_transfer) begin
                valid_reg <= 1'b0;
            end
            // else maintain state
        end
    end
    
    // Assertions for verification
    `ifdef FORMAL
        // No data loss: if valid and not ready, data must be preserved
        property p_no_data_loss;
            @(posedge clk) disable iff (!rst_n)
            (out_valid && !out_ready) |=> (out_valid && $stable(out_data));
        endproperty
        assert property (p_no_data_loss);
        
        // Valid stays high until ready
        property p_valid_until_ready;
            @(posedge clk) disable iff (!rst_n)
            (out_valid && !out_ready) |=> out_valid;
        endproperty
        assert property (p_valid_until_ready);
        
        // Reset clears valid
        property p_reset_clears_valid;
            @(posedge clk)
            !rst_n |=> !out_valid;
        endproperty
        assert property (p_reset_clears_valid);
    `endif

endmodule
