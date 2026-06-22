

`timescale 1ns / 1ps

module riscv_core (
    input  logic        clk,           
    input  logic        rst,           
    input  logic [31:0] instr,         // Fetched from Instruction Memory at current PC
    input  logic [31:0] read_data_mem, 
    output logic [31:0] alu_result,    
    output logic [31:0] write_data_mem,
    output logic        mem_write,     
    output logic [31:0] pc             // Directly exposes current address to Instruction Memory
);

    logic [31:0] pc_next;         // Target entering the PC register
    logic [31:0] pc_plus_4;       // Output from the sequential step adder
    logic [31:0] pc_target;       // Output from the branch target adder
    logic        pc_src;     
    logic        jump;     // Steering MUX control bit from branch gate

    // Control Unit Output Traces
    logic        branch;
    logic        mem_read;
    logic        mem_to_reg;
    logic [1:0]  alu_op;
    logic        alu_src;
    logic        reg_write;
    logic [2:0]  imm_src;
    logic [3:0]  alu_control;

    logic [31:0] src_a;           
    logic [31:0] reg_out_b;       
    logic [31:0] src_b;           
    logic [31:0] imm_ext;         
    logic [31:0] write_back_data; 
    logic        alu_zero;        

    logic        mem_write_internal;

    assign write_data_mem = reg_out_b;
    assign mem_write      = mem_write_internal;

    pc_reg u_pc_reg (
        .clk     (clk),
        .rst     (rst),
        .pc_next (pc_next),
        .pc      (pc)
    );

    pc_adder u_pc_adder (
        .a      (pc),
        .result (pc_plus_4)
    );

    pc_target_adder u_pc_target_adder (
        .pc      (pc),
        .imm_ext (imm_ext),
        .result  (pc_target)
    );

    branch_logic u_branch_logic (
        .branch     (branch),
        .zero       (alu_zero),
        .src_a      (src_a),          // Raw Operand A from the register file
        .src_b      (reg_out_b),      // Raw Operand B from the register file (NOT the immediate mux!)
        .alu_result (alu_result),     // The subtraction result from the ALU
        .funct3     (instr[14:12]),   // The 3-bit branch condition identifier
        .pc_src     (pc_src)
    );



 main_control u_main_control (
        .op        (instr[6:0]),
        .branch    (branch),
        .jump      (jump),               // <-- NEW CONNECTION
        .memRead   (mem_read),
        .memtoReg  (mem_to_reg),
        .aluOp     (alu_op),
        .memWrite  (mem_write_internal),
        .aluSrc    (alu_src),
        .regWrite  (reg_write),
        .immSrc    (imm_src)
    );

    alu_decoder u_alu_decoder (
        .aluOp      (alu_op),
        .funct3     (instr[14:12]),
        .funct7_bit (instr[30]),
        .aluControl (alu_control)
    );

    imm_gen u_imm_gen (
        .instr   (instr),
        .immSrc  (imm_src),
        .immExt  (imm_ext)
    );

    reg_file u_reg_file (
        .clk        (clk),
        .rst        (rst),
        .reg_write  (reg_write),
        .rs1        (instr[19:15]),
        .rs2        (instr[24:20]),
        .rd         (instr[11:7]),
        .write_data (write_back_data),
        .read_data1 (src_a),
        .read_data2 (reg_out_b)
    );

    alu_logic u_alu_logic (
        .a      (src_a),
        .b      (src_b), 
        .op     (alu_control),
        .result (alu_result),
        .zero   (alu_zero)
    );

    assign src_b = (alu_src) ? imm_ext : reg_out_b;

    assign write_back_data = (jump)       ? pc_plus_4 : 
                            (mem_to_reg) ? read_data_mem : alu_result;

    assign pc_next = (pc_src | jump) ? pc_target : pc_plus_4;

endmodule