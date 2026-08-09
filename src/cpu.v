// ============================================================
// Custom 16-bit accumulator-based CPU
// ============================================================
`default_nettype none

module top(
    input wire clk,
    input wire reset,
    input wire [15:0] main_input,
    output wire [15:0] main_output,
    output wire [5:0] pc_value
);

    // ---- fetch-stage wires ----
    wire        pc_enable;
    wire        jump;
    wire [5:0]  jump_address;
    wire [15:0] instruction_from_rom;
    wire [15:0] instruction;

    // The IR loads a fresh word from ROM whenever the PC is allowed to
    // advance. Tying this to pc_enable (rather than a constant 1) makes
    // sure that when HALT drops pc_enable, the IR freezes on the HALT
    // instruction itself instead of picking up whatever instruction
    // happens to sit at the next ROM address.
    wire ir_load = pc_enable;

    // Zero flag latched at the same edge the accumulator captures an ALU
    // result, so a following JZ/JNZ can test the flag from the
    // instruction that produced it (the live ALU output is only valid
    // during the cycle the ALU op itself is being decoded).
    reg flag_zero;
    always @(posedge clk) begin
        if (reset)
            flag_zero <= 1'b0;
        else
            flag_zero <= alu_zero;
    end

    // ---- decode-stage wires ----
    wire [3:0]  opcode;
    wire [11:0] operand;
    wire [11:0] constant;
    wire [2:0]  ram_addres;
    wire [15:0] immediate;

    // ---- control signals ----
    wire        acc_load;
    wire        load_upper;
    wire        lower_acc;
    wire        ram_write;
    wire        out_load;
    wire        halt;
    wire [2:0]  alu_operation;
    wire [2:0]  acc_source;

    // ---- datapath wires ----
    wire [15:0] alu_in_1, alu_in_2, alu_out;
    wire        alu_zero, alu_carry, alu_negative;
    wire [15:0] acc_out, acc_in;
    wire [15:0] ram_out;

    program_counter pc_unit (
        .clk(clk),
        .pc_rst(reset),
        .enable(pc_enable),
        .jump(jump),
        .jump_adres(jump_address),
        .pc(pc_value)
    );

    program_rom rom_unit (
        .address(pc_value),
        .instruction(instruction_from_rom)
    );

    instruction_reg ir_unit(
        .clk(clk),
        .reset(reset),
        .load(ir_load),
        .instruction_in(instruction_from_rom),
        .insctruction_out(instruction)
    );

    instruction_decoder decoder_unit(
        .decoder_in(instruction),
        .opcode(opcode),
        .operand(operand)
    );

    operand_splitter splitter_unit(
        .operand(operand),
        .constant(constant),
        .ram_addres(ram_addres),
        .jump_adres(jump_address)
    );

    // 12-bit immediate/constant field zero-extended to the 16-bit ALU/accumulator width
    assign immediate = {4'b0000, constant};

    control_unit control_unit_inst(
        .zero(flag_zero),
        .opcode(opcode),
        .acc_load(acc_load),
        .pc_enable(pc_enable),
        .jump(jump),
        .load_upper(load_upper),
        .ram_write(ram_write),
        .out_load(out_load),
        .halt(halt),
        .alu_operation(alu_operation),
        .acc_source(acc_source),
        .lower_acc(lower_acc)
    );

    alu_input alu_input_unit(
        .acc_out(acc_out),
        .constant(constant),
        .alu_in_1(alu_in_1),
        .alu_in_2(alu_in_2)
    );

    alu alu_unit(
        .alu_in_1(alu_in_1),
        .alu_in_2(alu_in_2),
        .operation(alu_operation),
        .alu_out(alu_out),
        .zero(alu_zero),
        .carry(alu_carry),
        .negative(alu_negative)
    );

    ram ram_unit(
        .clk(clk),
        .write_enable(ram_write),
        .address(ram_addres),
        .data_in(acc_out),
        .ram_out(ram_out)
    );

    accumulator_mux acc_mux_unit(
        .immediate(immediate),
        .alu_result(alu_out),
        .ram_data(ram_out),
        .input_data(main_input),
        .acc_out(acc_out),
        .acc_source(acc_source),
        .acc_in(acc_in)
    );

    accumulator acc_unit(
        .clk(clk),
        .reset(reset),
        .load(acc_load),
        .acc_in(acc_in),
        .acc_out(acc_out)
    );

    output_reg out_unit(
        .clk(clk),
        .reset(reset),
        .load(out_load),
        .output_input(acc_out),
        .full_out(main_output)
    );

endmodule


module accumulator (
    input wire clk,
    input wire reset,
    input wire load,
    input wire [15:0] acc_in,
    output reg [15:0] acc_out
);

    always @(posedge clk) begin
        if (reset) begin
            acc_out <= 16'h0000;
        end
        else if (load) begin
            acc_out <= acc_in;
        end
    end

endmodule


module program_counter (
    input wire clk,
    input wire pc_rst,
    input wire enable,
    input wire jump,
    input wire [5:0] jump_adres,
    output reg [5:0] pc
);

    always @(posedge clk) begin
        if (pc_rst) begin
            pc <= 6'd0;
        end
        else if (!enable) begin
            pc <= pc;
        end
        else if (jump) begin
            pc <= jump_adres;
        end
        else begin
            pc <= pc + 6'd1;
        end
    end
endmodule


module alu (
    input wire [15:0] alu_in_1,
    input wire [15:0] alu_in_2,
    input wire [2:0] operation,
    output reg [15:0] alu_out,
    output reg zero,
    output reg carry,
    output reg negative
);

    always @(*) begin
        carry = 1'b0;

        case (operation)
            3'b111: {carry, alu_out} = alu_in_1 + alu_in_2;   // ADD
            3'b001: alu_out = alu_in_1 - alu_in_2;            // SUB
            3'b010: alu_out = alu_in_1 & alu_in_2;            // AND
            3'b011: alu_out = alu_in_1 | alu_in_2;            // OR
            3'b100: alu_out = alu_in_1 ^ alu_in_2;            // XOR
            default: alu_out = 16'h0000;
        endcase

        zero     = (alu_out == 16'h0000);
        negative = alu_out[15];
    end
endmodule


module instruction_reg(
    input wire clk,
    input wire reset,
    input wire load,
    input wire [15:0] instruction_in,
    output reg [15:0] insctruction_out
);

    always @(posedge clk) begin
        if (reset) begin
            insctruction_out <= 16'h0000;
        end
        else if (load) begin
            insctruction_out <= instruction_in;
        end
        else begin
            insctruction_out <= insctruction_out;
        end
    end

endmodule


module instruction_decoder (
    input wire [15:0] decoder_in,
    output wire [3:0] opcode,
    output wire [11:0] operand
);
   assign opcode = decoder_in [15:12];
   assign operand = decoder_in [11:0];
endmodule


module program_rom(
    input wire [5:0] address,
    output reg [15:0] instruction
);
    // ASIC-synthesizable ROM: fixed content as combinational logic.
    // (An `initial`-loaded reg array has no power-on state on real
    // silicon -- there is no such thing as a pre-loaded flip-flop value
    // without an explicit reset network, so that pattern only works in
    // simulation. A case statement compiles down to real gates that
    // always produce the same values, so this is the correct way to
    // put fixed instructions into an ASIC ROM.)
    //
    // Demo program (also exercised by tb_cpu.v):
    //   0: LDI 5        acc = 5
    //   1: ADD 3        acc = 8
    //   2: STORE ram[0] ram[0] = 8
    //   3: LDI 2        acc = 2
    //   4: LOAD ram[0]  acc = 8
    //   5: SUB 8        acc = 0, zero flag set
    //   6: JZ 9         taken -> jump to 9
    //   7: NOP           (branch delay slot -- always executes once)
    //   8: LDI 0x63      (never reached; proves the jump worked)
    //   9: LDUP 0x12    acc = {0x12, acc[7:0]}
    //  10: IN           acc = main_input
    //  11: OUT          main_output = acc
    //  12: HALT
    //  13: LDI 1         (trap; must never execute if halt holds)
    always @(*) begin
        case (address)
            6'd0:  instruction = 16'h1005;
            6'd1:  instruction = 16'h3003;
            6'd2:  instruction = 16'h9000;
            6'd3:  instruction = 16'h1002;
            6'd4:  instruction = 16'h8000;
            6'd5:  instruction = 16'h4008;
            6'd6:  instruction = 16'hB009;
            6'd7:  instruction = 16'h0000;
            6'd8:  instruction = 16'h1063;
            6'd9:  instruction = 16'h2012;
            6'd10: instruction = 16'hD000;
            6'd11: instruction = 16'hE000;
            6'd12: instruction = 16'hF000;
            default: instruction = 16'hF000; // unused space defaults to HALT
        endcase
    end
endmodule


module ram(
    input wire clk,
    input wire write_enable,
    input wire [2:0] address,
    input wire [15:0] data_in,
    output reg [15:0] ram_out
);
   reg [15:0] ram [0:7];

   always @(*) begin
       ram_out = ram[address];
   end

   always @(posedge clk) begin
     if (write_enable) begin
        ram[address] <= data_in;
     end
   end

endmodule


module accumulator_mux (
    input wire [15:0] immediate,
    input wire [15:0] alu_result,
    input wire [15:0] ram_data,
    input wire [15:0] input_data,
    input wire [15:0] acc_out,

    input wire [2:0] acc_source,
    output reg [15:0] acc_in
);
   always @(*)begin
     case(acc_source)

      3'b000: acc_in = immediate;
      3'b001: acc_in = alu_result;
      3'b010: acc_in = ram_data;
      3'b011: acc_in = input_data;
      3'b100: acc_in = {immediate[7:0] , acc_out[7:0]};
      default: acc_in = 16'h0000;
     endcase
   end

endmodule


module control_unit(
   input wire zero,
   input wire [3:0] opcode,
   output reg acc_load,
   output reg pc_enable,
   output reg jump,
   output reg load_upper,
   output reg ram_write,
   output reg out_load,
   output reg halt,
   output reg [2:0] alu_operation,
   output reg [2:0] acc_source,
   output reg lower_acc
);

  always @(*) begin
    // defaults every cycle - avoids inferred latches
    acc_load      = 1'b0;
    pc_enable     = 1'b1;
    jump          = 1'b0;
    ram_write     = 1'b0;
    out_load      = 1'b0;
    halt          = 1'b0;
    alu_operation = 3'b000;
    acc_source    = 3'b000;
    load_upper    = 1'b0;
    lower_acc     = 1'b0;

    case(opcode)

    4'h0: begin
        // NOP
    end

    4'h1: begin
        // LDI - load immediate into accumulator
        acc_load   = 1'b1;
        acc_source = 3'b000;
    end

    4'h2: begin
        // Load upper byte of accumulator from immediate, keep lower byte
        acc_load   = 1'b1;
        acc_source = 3'b100;
        load_upper = 1'b1;
    end

    4'h3: begin
        // ADD
        alu_operation = 3'b111;
        acc_load      = 1'b1;
        acc_source    = 3'b001;
    end

    4'h4: begin
        // SUB
        alu_operation = 3'b001;
        acc_load      = 1'b1;
        acc_source    = 3'b001;
    end

    4'h5: begin
        // AND
        alu_operation = 3'b010;
        acc_load      = 1'b1;
        acc_source    = 3'b001;
    end

    4'h6: begin
        // OR
        alu_operation = 3'b011;
        acc_load      = 1'b1;
        acc_source    = 3'b001;
    end

    4'h7: begin
        // XOR
        alu_operation = 3'b100;
        acc_load      = 1'b1;
        acc_source    = 3'b001;
    end

    4'h8: begin
        // LOAD from RAM
        acc_load   = 1'b1;
        acc_source = 3'b010;
    end

    4'h9: begin
        // STORE to RAM
        ram_write = 1'b1;
    end

    4'hA: begin
        // JMP
        jump = 1'b1;
    end

    4'hB: begin
        // JZ
        if (zero) begin
            jump = 1'b1;
        end
    end

    4'hC: begin
        // JNZ
        if (!zero) begin
            jump = 1'b1;
        end
    end

    4'hD: begin
        // IN
        acc_source = 3'b011;
        acc_load   = 1'b1;
    end

    4'hE: begin
        // OUT
        out_load = 1'b1;
    end

    4'hF: begin
        // HALT
        halt      = 1'b1;
        pc_enable = 1'b0;
    end

  endcase
  end
endmodule


module alu_input(
    input wire [15:0] acc_out,
    input wire [11:0] constant,
    output reg [15:0] alu_in_1,
    output reg [15:0] alu_in_2
);

    always @(*) begin
        alu_in_1 = acc_out;
        alu_in_2 = {4'b0000, constant};
    end
endmodule


module output_reg(
    input wire clk,
    input wire reset,
    input wire load,
    input wire [15:0] output_input,
    output reg [15:0] full_out
);
    always @(posedge clk) begin
        if (reset) begin
            full_out <= 16'h0000;
        end
        else if (load) begin
            full_out <= output_input;
        end
    end
endmodule


module operand_splitter(
    input wire [11:0] operand,
    output wire [11:0] constant,
    output wire [2:0] ram_addres,
    output wire [5:0] jump_adres
);
   assign constant = operand;
   assign ram_addres = operand[2:0];
   assign jump_adres = operand[5:0];

endmodule

`default_nettype wire
