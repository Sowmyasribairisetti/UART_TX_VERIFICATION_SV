// uart_txn.sv
module uart_tx (
    input logic       clk,
    input logic       rstn,       // Active low reset
    input logic [7:0] tx_data,    // 8-bit data to transmit
    input logic       tx_start,   // Start transmission pulse
    output logic      tx_busy,    // Indicates transmission in progress
    output logic      tx_line     // UART serial output line
);

    // State enumeration for the FSM
    typedef enum logic [3:0] {
        IDLE,    // Waiting for transmission to start
        START,   // Transmitting start bit (logic 0)
        DATA0,   // Transmitting data bit 0
        DATA1,   // Transmitting data bit 1
        DATA2,   // Transmitting data bit 2
        DATA3,   // Transmitting data bit 3
        DATA4,   // Transmitting data bit 4
        DATA5,   // Transmitting data bit 5
        DATA6,   // Transmitting data bit 6
        DATA7,   // Transmitting data bit 7
        STOP     // Transmitting stop bit (logic 1)
    } state_t;

    state_t state;         // Current state of the FSM
    logic [7:0] data_buf;  // Buffer to hold the data to be transmitted

    // Sequential logic for FSM and data path
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin // Asynchronous active-low reset
            state      <= IDLE;    // Reset to IDLE state
            tx_line    <= 1;       // Tx line high (idle state)
            tx_busy    <= 0;       // Not busy
            data_buf   <= 0;       // Clear data buffer
        end else begin
            case (state)
                IDLE: begin
                    if (tx_start) begin // If start signal is asserted
                        state      <= START;    // Move to START state
                        tx_busy    <= 1;        // Indicate busy
                        data_buf   <= tx_data;  // Load data into buffer
                    end
                end

                START: begin
                    tx_line    <= 0;        // Transmit start bit (logic 0)
                    state      <= DATA0;    // Move to DATA0 state
                end

                DATA0: begin
                    tx_line    <= data_buf[0]; // Transmit data bit 0
                    state      <= DATA1;       // Move to DATA1 state
                end

                DATA1: begin
                    tx_line    <= data_buf[1]; // Transmit data bit 1
                    state      <= DATA2;       // Move to DATA2 state
                end

                DATA2: begin
                    tx_line    <= data_buf[2]; // Transmit data bit 2
                    state      <= DATA3;       // Move to DATA3 state
                end

                DATA3: begin
                    tx_line    <= data_buf[3]; // Transmit data bit 3
                    state      <= DATA4;       // Move to DATA4 state
                end

                DATA4: begin
                    tx_line    <= data_buf[4]; // Transmit data bit 4
                    state      <= DATA5;       // Move to DATA5 state
                end

                DATA5: begin
                    tx_line    <= data_buf[5]; // Transmit data bit 5
                    state      <= DATA6;       // Move to DATA6 state
                end

                DATA6: begin
                    tx_line    <= data_buf[6]; // Transmit data bit 6
                    state      <= DATA7;       // Move to DATA7 state
                end

                DATA7: begin
                    tx_line    <= data_buf[7]; // Transmit data bit 7
                    state      <= STOP;        // Move to STOP state
                end

                STOP: begin
                    tx_line    <= 1;         // Transmit stop bit (logic 1)
                    state      <= IDLE;      // Return to IDLE state
                    tx_busy    <= 0;         // Not busy anymore
                end
            endcase
        end
    end

endmodule
class uart_txn;
    rand bit [7:0] tx_data;

    function void display(string tag);
        $display("[%0s] UART TX Data: %0h", tag, tx_data);
    endfunction
endclass

// uart_if.sv
interface uart_if(input logic clk);
    logic rstn;
    logic [7:0] tx_data;
    logic tx_start;
    logic tx_busy;
    logic tx_line;
endinterface

// uart_generator.sv
class uart_generator;
    mailbox #(uart_txn) gen2drv;

    function new(mailbox #(uart_txn) gen2drv);
        this.gen2drv = gen2drv;
    endfunction

    task run();
        uart_txn txn;
        repeat (5) begin
            txn = new();
            assert(txn.randomize());
            txn.display("GEN");
            gen2drv.put(txn);
            #100;
        end
    endtask
endclass

// uart_driver.sv
class uart_driver;
    virtual uart_if vif;
    mailbox #(uart_txn) gen2drv;

    function new(virtual uart_if vif, mailbox #(uart_txn) gen2drv);
        this.vif = vif;
        this.gen2drv = gen2drv;
    endfunction

    task run();
        uart_txn txn;
        forever begin
            gen2drv.get(txn);
            @(posedge vif.clk);
            vif.tx_data <= txn.tx_data;
            vif.tx_start <= 1;
            @(posedge vif.clk);
            while (vif.tx_busy == 0) @(posedge vif.clk);
            vif.tx_start <= 0;
            @(posedge vif.clk);
            while (vif.tx_busy) @(posedge vif.clk);
        end
    endtask
endclass

// uart_monitor.sv
class uart_monitor;
    virtual uart_if vif;
    mailbox #(uart_txn) mon2scb;

    function new(virtual uart_if vif, mailbox #(uart_txn) mon2scb);
        this.vif = vif;
        this.mon2scb = mon2scb;
    endfunction

    task run();
        uart_txn txn;
        forever begin
            @(posedge vif.clk);
            if (vif.tx_start) begin
                txn = new();
                txn.tx_data = vif.tx_data;
                mon2scb.put(txn);
                txn.display("MON");
            end
        end
    endtask
endclass

// uart_scoreboard.sv
class uart_scoreboard;
    mailbox #(uart_txn) mon2scb;

    function new(mailbox #(uart_txn) mon2scb);
        this.mon2scb = mon2scb;
    endfunction

    task run();
        uart_txn txn;
        forever begin
            mon2scb.get(txn);
            $display("[SCB] Checking data: %0h", txn.tx_data);
        end
    endtask
endclass

// uart_env.sv
class uart_env;
    uart_generator gen;
    uart_driver drv;
    uart_monitor mon;
    uart_scoreboard scb;
    virtual uart_if vif;
    mailbox #(uart_txn) gen2drv;
    mailbox #(uart_txn) mon2scb;

    function new(virtual uart_if vif);
        this.vif = vif;
        gen2drv = new();
        mon2scb = new();
        gen = new(gen2drv);
        drv = new(vif, gen2drv);
        mon = new(vif, mon2scb);
        scb = new(mon2scb);
    endfunction

    task run();
        fork
            gen.run();
            drv.run();
            mon.run();
            scb.run();
        join_none
    endtask
endclass
