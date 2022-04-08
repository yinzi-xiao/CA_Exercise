//Module: CPU
//Function: CPU is the top design of the RISC-V processor

//Inputs:
//	clk: main clock
//	arst_n: reset 
// enable: Starts the execution
//	addr_ext: Address for reading/writing content to Instruction Memory
//	wen_ext: Write enable for Instruction Memory
// ren_ext: Read enable for Instruction Memory
//	wdata_ext: Write word for Instruction Memory
//	addr_ext_2: Address for reading/writing content to Data Memory
//	wen_ext_2: Write enable for Data Memory
// ren_ext_2: Read enable for Data Memory
//	wdata_ext_2: Write word for Data Memory

// Outputs:
//	rdata_ext: Read data from Instruction Memory
//	rdata_ext_2: Read data from Data Memory



module cpu(
		input  wire			  clk,
		input  wire         arst_n,
		input  wire         enable,
		input  wire	[63:0]  addr_ext,
		input  wire         wen_ext,
		input  wire         ren_ext,
		input  wire [31:0]  wdata_ext,
		input  wire	[63:0]  addr_ext_2,
		input  wire         wen_ext_2,
		input  wire         ren_ext_2,
		input  wire [63:0]  wdata_ext_2,
		
		output wire	[31:0]  rdata_ext,
		output wire	[63:0]  rdata_ext_2

   );

wire [       4:0] regfile_waddr;
wire [      63:0] regfile_wdata,mem_data,alu_out,
                  regfile_rdata_1,regfile_rdata_2,
                  alu_operand_2;

//IF stage

//Program counter
wire [      63:0] branch_pc,updated_pc,current_pc,jump_pc;
wire              zero_flag,branch_mux,jump_mux;
wire              write_pc;
assign            enable_pc = enable && write_pc;

//pc excutes if enable_pc=1
pc #(
   .DATA_W(64)
) program_counter (
   .clk       (clk       ),
   .arst_n    (arst_n    ),
   .branch_pc (branch_pc ),
   .jump_pc   (jump_pc   ),
   .zero_flag (zero_flag),
   .branch    (branch_mux    ),
   .jump      (jump_mux      ),
   .current_pc(current_pc),
   .enable    (enable_pc),
   .updated_pc(updated_pc)
);


// The instruction memory.
wire [      31:0] instruction;

sram_BW32 #(
   .ADDR_W(9 ),
   .DATA_W(32)
) instruction_memory(
   .clk      (clk           ),
   .addr     (current_pc    ),
   .wen      (1'b0          ),
   .ren      (1'b1          ),
   .wdata    (32'b0         ),
   .rdata    (instruction   ),   
   .addr_ext (addr_ext      ),
   .wen_ext  (wen_ext       ), 
   .ren_ext  (ren_ext       ),
   .wdata_ext(wdata_ext     ),
   .rdata_ext(rdata_ext     )
);

//IF_ID pipeline register for PC signal
wire [      63:0] updated_pc_IF_ID;
wire             write_IF_ID_reg;
assign           enable_IF_ID = enable && write_IF_ID_reg;

//IF_ID pipeline register excutes if enable_IF_ID=1
reg_arstn_en#(
   .DATA_W(64)
)pc_IF_ID(
   .clk    (clk            ),
   .arst_n (arst_n         ),
   .din    (updated_pc    ),
   .en     (enable_IF_ID),
   .dout   (updated_pc_IF_ID)
);

//IF_ID pipeline register for instruction signal
wire [      31:0] instruction_IF_ID;

ins_IF_ID#(
   .DATA_W(32)
)ins_IF_ID(
   .clk     (clk),
   .arst_n  (arst_n),
   .en      (enable_IF_ID),
   .IF_flush(IF_flush),
   .din     (instruction),
   .dout    (instruction_IF_ID)
);

//ID stage

//Hazard detection unit
wire             mem_read_ID_EX,control_mux,branch;
wire [      4:0] rd_ID_EX;

hazard_detection_unit hazard_detection_unit(
   .branch        (branch_mux),
   .mem_read_ID_EX(mem_read_ID_EX),
   .rd_ID_EX      (rd_ID_EX),
   .rs1_IF_ID     (instruction_IF_ID[19:15]),
   .rs2_IF_ID     (instruction_IF_ID[24:20]),
   .write_IF_ID_reg(write_IF_ID_reg),
   .write_pc      (write_pc),
   .control_mux   (control_mux)
);

//Control unit
wire [       1:0] alu_op;
wire              reg_dst,mem_read,mem_2_reg,
                  mem_write,alu_src,reg_write,jump;

control_unit control_unit(
   .opcode   (instruction_IF_ID[6:0]),
   .zero_flag(zero_flag),
   .alu_op   (alu_op          ),
   .reg_dst  (reg_dst         ),
   .branch   (branch          ),
   .mem_read (mem_read        ),
   .mem_2_reg(mem_2_reg       ),
   .mem_write(mem_write       ),
   .alu_src  (alu_src         ),
   .reg_write(reg_write       ),
   .jump     (jump            ),
   .IF_flush (IF_flush        )
);

//mux for control unit
wire [       1:0] alu_op_mux;
wire              reg_dst_mux,mem_read_mux,mem_2_reg_mux,
                  mem_write_mux,alu_src_mux,reg_write_mux;

mux_2 #(
   .DATA_W(10)
) control_unit_mux(
   .input_a ({alu_op,reg_dst,branch,mem_read,mem_2_reg,mem_write,alu_src,reg_write,jump}),
   .input_b ({2'b00,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
   .select_a(control_mux           ),
   .mux_out ({alu_op_mux,reg_dst_mux,branch_mux,mem_read_mux,mem_2_reg_mux,mem_write_mux,alu_src_mux,reg_write_mux,jump_mux})
);

//Register file
wire [4:0] rd_M_WB;
wire       reg_write_M_WB;

register_file #(
   .DATA_W(64)
) register_file(
   .clk      (clk               ),
   .arst_n   (arst_n            ),
   .reg_write(reg_write_M_WB         ),
   .raddr_1  (instruction_IF_ID[19:15]),
   .raddr_2  (instruction_IF_ID[24:20]),
   .waddr    (rd_M_WB                 ),
   .wdata    (regfile_wdata     ),
   .rdata_1  (regfile_rdata_1   ),
   .rdata_2  (regfile_rdata_2   )
);

//Immediate generator
wire signed [63:0] immediate_extended;

immediate_extend_unit immediate_extend_u(
   .instruction         (instruction_IF_ID),
   .immediate_extended  (immediate_extended)
);

//branch unit moves to IF stage
branch_unit#(
   .DATA_W(64)
)branch_unit(
   .updated_pc         (updated_pc_IF_ID       ),
   .immediate_extended (immediate_extended),
   .branch_pc          (branch_pc               ),
   .jump_pc            (jump_pc                 )
);

//mux for ETU operand1
wire [      63:0] alu_out_EX_M;
wire [      63:0] eq_data1;
wire [       1:0] forward_C,forward_D;

mux_3 #(
   .DATA_W(64)
) etu_operand1_mux (
   .input_a (regfile_rdata_1         ),
   .input_b (alu_out_EX_M            ),
   .input_c (regfile_wdata           ),
   .select_a(forward_C               ),
   .mux_out (eq_data1          )
);

//mux for ETU operand2
wire [      63:0] eq_data2;

mux_3 #(
   .DATA_W(64)
) etu_operand2_mux (
   .input_a (regfile_rdata_2         ),
   .input_b (alu_out_EX_M            ),
   .input_c (regfile_wdata           ),
   .select_a(forward_D               ),
   .mux_out (eq_data2      )
);

//equality test unit
equality_test_unit equality_test_unit(
   .opcode     (instruction_IF_ID[6:0]),
   .data1      (eq_data1),
   .data2      (eq_data2),
   .zero_flag  (zero_flag)
);

//forward unit for equality test unit
wire [       4:0] rd_EX_M;
wire              reg_write_EX_M;

forward_unit forward_equality_test(
   .reg_write_EX_M(reg_write_EX_M),
   .reg_write_M_WB(reg_write_M_WB),
   .rs1_ID_EX (instruction_IF_ID[19:15]),
   .rs2_ID_EX (instruction_IF_ID[24:20]),
   .rd_EX_M   (rd_EX_M  ),
   .rd_M_WB   (rd_M_WB  ),
   .forward_A (forward_C),
   .forward_B (forward_D)
);

//Since branch is in IF stage, it is no need.
/*
//ID_EX pipeline register for PC signal
wire [      63:0] updated_pc_ID_EX;

reg_arstn_en#(
   .DATA_W(64)
)pc_ID_EX(
   .clk    (clk            ),
   .arst_n (arst_n         ),
   .din    (updated_pc_IF_ID),
   .en     (enable         ),
   .dout  (updated_pc_ID_EX)
);
*/

//ID_EX pipeline register for Control signal
wire [       1:0] alu_op_ID_EX;
wire              reg_dst_ID_EX,branch_ID_EX,mem_2_reg_ID_EX,
                  mem_write_ID_EX,alu_src_ID_EX, reg_write_ID_EX,jump_ID_EX;

reg_arstn_en#(
   .DATA_W(10)
)control_ID_EX(
   .clk    (clk            ),
   .arst_n (arst_n         ),
   .din    ({alu_op_mux,reg_dst_mux,branch_mux,mem_read_mux,mem_2_reg_mux,mem_write_mux,alu_src_mux,reg_write_mux,jump_mux}),
   .en     (enable         ),
   .dout  ({alu_op_ID_EX,reg_dst_ID_EX,branch_ID_EX,mem_read_ID_EX,mem_2_reg_ID_EX,mem_write_ID_EX,alu_src_ID_EX,reg_write_ID_EX,jump_ID_EX})
);

//ID_EX pipeline register for read data1&2
wire [      63:0] regfile_rdata_1_ID_EX,
                  regfile_rdata_2_ID_EX;

reg_arstn_en#(
   .DATA_W(64)
)register_data_1_ID_EX(
   .clk    (clk            ),
   .arst_n (arst_n         ),
   .din    (regfile_rdata_1),
   .en     (enable         ),
   .dout  (regfile_rdata_1_ID_EX)
);

reg_arstn_en#(
   .DATA_W(64)
)register_data_2_ID_EX(
   .clk    (clk            ),
   .arst_n (arst_n         ),
   .din    (regfile_rdata_2),
   .en     (enable         ),
   .dout  (regfile_rdata_2_ID_EX)
);

//ID_EX pipeline register for immediate field
wire signed [63:0] immediate_extended_ID_EX;

reg_arstn_en#(
   .DATA_W(64)
)imm_gen_ID_EX(
   .clk    (clk            ),
   .arst_n (arst_n         ),
   .din    (immediate_extended),
   .en     (enable         ),
   .dout  (immediate_extended_ID_EX)
);

//ID_EX pipeline register for ALU control signal
wire              func7_5_ID_EX,func7_0_ID_EX;
wire [       2:0] func3_ID_EX;

reg_arstn_en#(
   .DATA_W(5)
)alu_control_ID_EX(
   .clk    (clk            ),
   .arst_n (arst_n         ),
   .din    ({instruction_IF_ID[30],instruction_IF_ID[25],instruction_IF_ID[14:12]}),
   .en     (enable         ),
   .dout  ({func7_5_ID_EX,func7_0_ID_EX,func3_ID_EX})
);

//ID_EX pipeline register for regsiter destination
reg_arstn_en#(
   .DATA_W(5)
)register_dest_ID_EX(
   .clk    (clk            ),
   .arst_n (arst_n         ),
   .din    (instruction_IF_ID[11:7]),
   .en     (enable         ),
   .dout   (rd_ID_EX       )
);

//ID_EX pipeline register for regsiter read address 1&2
wire [      4:0] rs1_ID_EX,rs2_ID_EX;

reg_arstn_en#(
   .DATA_W(5)
)register_signal1_ID_EX(
   .clk    (clk            ),
   .arst_n (arst_n         ),
   .din    (instruction_IF_ID[19:15]),
   .en     (enable         ),
   .dout   (rs1_ID_EX      )
);

reg_arstn_en#(
   .DATA_W(5)
)register_signal2_ID_EX(
   .clk    (clk            ),
   .arst_n (arst_n         ),
   .din    (instruction_IF_ID[24:20]),
   .en     (enable         ),
   .dout   (rs2_ID_EX      )
);

//EX stage

//ALU control
wire [       3:0] alu_control;

alu_control alu_ctrl(
   .func7_5        (func7_5_ID_EX   ),
   .func7_0	       (func7_0_ID_EX   ),
   .func3          (func3_ID_EX     ),
   .alu_op         (alu_op_ID_EX    ),
   .alu_control    (alu_control     )
);

//Forward unit
wire [       1:0] forward_A,forward_B;

forward_unit forward_unit(
   .reg_write_EX_M(reg_write_EX_M),
   .reg_write_M_WB(reg_write_M_WB),
   .rs1_ID_EX (rs1_ID_EX),
   .rs2_ID_EX (rs2_ID_EX),
   .rd_EX_M   (rd_EX_M  ),
   .rd_M_WB   (rd_M_WB  ),
   .forward_A (forward_A),
   .forward_B (forward_B)
);

//mux for ALU operand1
wire [      63:0] alu_operand_1;

mux_3 #(
   .DATA_W(64)
) alu_operand1_mux (
   .input_a (regfile_rdata_1_ID_EX   ),
   .input_b (alu_out_EX_M            ),
   .input_c (regfile_wdata           ),
   .select_a(forward_A               ),
   .mux_out (alu_operand_1           )
);

//mux for ALU operand2 (temporary)
wire [      63:0] alu_operand_2_temp;

mux_3 #(
   .DATA_W(64)
) alu_operand2_mux (
   .input_a (regfile_rdata_2_ID_EX   ),
   .input_b (alu_out_EX_M            ),
   .input_c (regfile_wdata           ),
   .select_a(forward_B               ),
   .mux_out (alu_operand_2_temp      )
);

//mux for ALU operand2
mux_2 #(
   .DATA_W(64)
) alu_operand_mux (
   .input_a (immediate_extended_ID_EX),
   .input_b (alu_operand_2_temp      ),
   .select_a(alu_src_ID_EX           ),
   .mux_out (alu_operand_2           )
);

//ALU
//We don't use zero_flag in ALU in branch test anymore
wire             zero_flag_alu;

alu#(
   .DATA_W(64)
) alu(
   .alu_in_0 (alu_operand_1   ),
   .alu_in_1 (alu_operand_2   ),
   .alu_ctrl (alu_control     ),
   .alu_out  (alu_out         ),
   .zero_flag(zero_flag_alu       ),
   .overflow (                )
);

//EX_MEM pipeline register for Control signal
wire              reg_dst_EX_M,mem_read_EX_M,mem_2_reg_EX_M,
                  mem_write_EX_M;

reg_arstn_en#(
   .DATA_W(7)
)control_EX_M(
   .clk    (clk            ),
   .arst_n (arst_n         ),
   .din    ({reg_dst_ID_EX,branch_ID_EX,mem_read_ID_EX,mem_2_reg_ID_EX,mem_write_ID_EX,reg_write_ID_EX,jump_ID_EX}),
   .en     (enable         ),
   .dout  ({reg_dst_EX_M,branch_EX_M,mem_read_EX_M,mem_2_reg_EX_M,mem_write_EX_M,reg_write_EX_M,jump_EX_M})
);

//Since branch is in IF stage, it is no need.
/*
//EX_MEM pipeline register for PC signal
wire [      63:0] updated_pc_EX_M;

reg_arstn_en#(
   .DATA_W(64)
)pc_EX_M(
   .clk    (clk            ),
   .arst_n (arst_n         ),
   .din    (updated_pc_ID_EX),
   .en     (enable         ),
   .dout  (updated_pc_EX_M)
);


//EX_MEM pipeline register for immediate field
wire signed [63:0] immediate_extended_EX_M;

reg_arstn_en#(
   .DATA_W(64)
)imm_gen_EX_M(
   .clk    (clk            ),
   .arst_n (arst_n         ),
   .din    (immediate_extended_ID_EX),
   .en     (enable         ),
   .dout  (immediate_extended_EX_M)
);
*/

//EX_MEM pipeline register for ALU zero&result
reg_arstn_en#(
   .DATA_W(65)
)alu_result_EX_M(
   .clk    (clk            ),
   .arst_n (arst_n         ),
   .din    ({zero_flag_alu,alu_out}),
   .en     (enable         ),
   .dout  ({zero_flag_alu_EX_M,alu_out_EX_M})
);

//EX_MEM pipeline register for read data2
wire [      63:0] regfile_rdata_2_EX_M;

reg_arstn_en#(
   .DATA_W(64)
)register_data_2_EX_M(
   .clk    (clk            ),
   .arst_n (arst_n         ),
   .din    (regfile_rdata_2_ID_EX),
   .en     (enable         ),
   .dout  (regfile_rdata_2_EX_M)
);

//EX_MEM pipeline register for register destination
reg_arstn_en#(
   .DATA_W(5)
)register_dest_EX_M(
   .clk    (clk            ),
   .arst_n (arst_n         ),
   .din    (rd_ID_EX       ),
   .en     (enable         ),
   .dout  (rd_EX_M        )
);

//MEM stage

// The data memory.
sram_BW64 #(
   .ADDR_W(10),
   .DATA_W(64)
) data_memory(
   .clk      (clk            ),
   .addr     (alu_out_EX_M   ),
   .wen      (mem_write_EX_M      ),
   .ren      (mem_read_EX_M       ),
   .wdata    (regfile_rdata_2_EX_M),
   .rdata    (mem_data       ),   
   .addr_ext (addr_ext_2     ),
   .wen_ext  (wen_ext_2      ),
   .ren_ext  (ren_ext_2      ),
   .wdata_ext(wdata_ext_2    ),
   .rdata_ext(rdata_ext_2    )
);

//MEM_WB pipeline register for Control signal
wire              reg_dst_M_WB,mem_2_reg_M_WB;

reg_arstn_en#(
   .DATA_W(3)
)control_M_WB(
   .clk    (clk            ),
   .arst_n (arst_n         ),
   .din    ({reg_dst_EX_M,mem_2_reg_EX_M,reg_write_EX_M}),
   .en     (enable         ),
   .dout  ({reg_dst_M_WB,mem_2_reg_M_WB,reg_write_M_WB})
);

//MEM_WB pipeline register for read memory data
wire [      63:0] mem_data_M_WB;

reg_arstn_en#(
   .DATA_W(64)
)memory_data_M_WB(
   .clk    (clk            ),
   .arst_n (arst_n         ),
   .din    (mem_data),
   .en     (enable         ),
   .dout  (mem_data_M_WB)
);

//MEM_WB pipeline register for ALU result
wire [      63:0] alu_out_M_WB;

reg_arstn_en#(
   .DATA_W(64)
)alu_result_M_WB(
   .clk    (clk            ),
   .arst_n (arst_n         ),
   .din    (alu_out_EX_M),
   .en     (enable         ),
   .dout  (alu_out_M_WB)
);

//MEM_WB pipeline register for register destination
reg_arstn_en#(
   .DATA_W(5)
)register_dest_M_WB(
   .clk    (clk            ),
   .arst_n (arst_n         ),
   .din    (rd_EX_M       ),
   .en     (enable         ),
   .dout  (rd_M_WB        )
);

//WB stage

//mux for regfile write back data
mux_2 #(
   .DATA_W(64)
) regfile_data_mux (
   .input_a  (mem_data_M_WB     ),
   .input_b  (alu_out_M_WB      ),
   .select_a (mem_2_reg_M_WB    ),
   .mux_out  (regfile_wdata)
);

endmodule


