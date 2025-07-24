// Code your testbench here
// or browse Examples
module tb_uart;

    logic clk = 0; // Declare and initialize clock signal
    // Clock generator: Toggles clk every 5 time units, creating a 10ns period
    always #5 clk = ~clk;

    // Instantiate the UART Interface
    uart_if uif(clk); // Pass clock to the interface

    // Instantiate the Design Under Test (DUT)
    uart_tx dut (
        .clk(clk),
        .rstn(uif.rstn),       // Connect DUT's rstn to interface's rstn
        .tx_data(uif.tx_data), // Connect DUT's tx_data to interface's tx_data
        .tx_start(uif.tx_start), // Connect DUT's tx_start to interface's tx_start
        .tx_busy(uif.tx_busy),   // Connect DUT's tx_busy to interface's tx_busy
        .tx_line(uif.tx_line)   // Connect DUT's tx_line to interface's tx_line
    );

    uart_env env; // Declare an instance of the environment class

    // Initial block for simulation control
    initial begin
        // Apply reset sequence
        uif.rstn = 0; // Assert active-low reset
        #20;          // Hold reset for 20 time units
        uif.rstn = 1; // De-assert reset

        // Instantiate the environment and run it
        env = new (uif); // Pass the interface handle to the environment constructor
        env.run();       // Start the environment's run task

        // Run simulation for a fixed duration and then finish
        #2000 $finish; // End simulation after 2000 time units
    end

endmodule // Environment Class: uart_env
