`default_nettype none


module tt_um_zoomwag_cpu16 (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire        ena,     // goes high when the design is powered and selected
    input  wire        clk,     // clock
    input  wire        rst_n    // reset_n - low to reset
);

    // Silence "unused" lint warnings without affecting anything.
    wire _unused = &{ena, 1'b0};

    // All bidirectional pins are inputs (control signals) for this design.
    assign uio_out = 8'h00;
    assign uio_oe  = 8'h00;

    // The CPU core uses active-high reset; TT gives us active-low.
    wire reset = !rst_n;

    // ---- 16-bit input register, loaded a byte at a time ----
    wire load_half   = uio_in[2];
    wire load_strobe = uio_in[3];

    reg [15:0] main_input_reg;
    always @(posedge clk) begin
        if (reset) begin
            main_input_reg <= 16'h0000;
        end else if (load_strobe) begin
            if (load_half)
                main_input_reg[15:8] <= ui_in;
            else
                main_input_reg[7:0] <= ui_in;
        end
    end

    // ---- CPU core (see cpu.v) ----
    wire [15:0] main_output;
    wire [5:0]  pc_value;

    top cpu_core (
        .clk(clk),
        .reset(reset),
        .main_input(main_input_reg),
        .main_output(main_output),
        .pc_value(pc_value)
    );

    // ---- Output byte mux ----
    reg [7:0] out_byte;
    always @(*) begin
        case (uio_in[1:0])
            2'b00:   out_byte = main_output[7:0];
            2'b01:   out_byte = main_output[15:8];
            2'b10:   out_byte = {2'b00, pc_value};
            default: out_byte = 8'h00;
        endcase
    end

    assign uo_out = out_byte;

endmodule

`default_nettype wire
