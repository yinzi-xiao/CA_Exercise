// module: Forward Unit
// Function: Generates the forward signal to mux-3 to choose which stage of data should be sent to ALU

module forward_unit(
        input wire       reg_write_EX_M,
        input wire       reg_write_M_WB,
        input wire [4:0] rs1_ID_EX,
        input wire [4:0] rs2_ID_EX,
        input wire [4:0] rd_EX_M,
        input wire [4:0] rd_M_WB,
        output reg [1:0] forward_A,
        output reg [1:0] forward_B
    );

    always@(*)begin
        //No hazard, initialize forward_A & forward_B
        forward_A = 2'b00;
        forward_B = 2'b00;
        //EX hazard
        if(reg_write_EX_M && (rd_EX_M!=0) && (rd_EX_M==rs1_ID_EX))begin
            forward_A = 2'b10;
        end

        if(reg_write_EX_M && (rd_EX_M!=0) && (rd_EX_M==rs2_ID_EX))begin
            forward_B = 2'b10;
        end
        //MEM hazard
        if(reg_write_M_WB && (rd_M_WB!=0) 
        && !(reg_write_EX_M && (rd_EX_M!=0) && (rd_EX_M==rs1_ID_EX)) 
        && (rd_M_WB==rs1_ID_EX))begin
            forward_A = 2'b01;
        end

        if(reg_write_M_WB && (rd_M_WB!=0) 
        && !(reg_write_EX_M && (rd_EX_M!=0) && (rd_EX_M==rs2_ID_EX)) 
        && (rd_M_WB==rs2_ID_EX))begin
            forward_B = 2'b01;
        end
    end
endmodule