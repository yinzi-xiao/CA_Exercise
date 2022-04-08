//module: Hazard detection unit
//Function: stall the pipeline when there is a load-use hazard

module hazard_detection_unit(
        input wire       branch, 
        input wire       mem_read_ID_EX,
        input wire [4:0] rd_ID_EX,
        input wire [4:0] rs1_IF_ID,
        input wire [4:0] rs2_IF_ID,
        output reg      write_IF_ID_reg,
        output reg      write_pc, 
        output reg      control_mux    
    );

    always@(*)begin
        //if there is a load-use hazard, set write_IF_ID_reg,write_pc,control_mux to 0 to stall the pipeline
        if(mem_read_ID_EX && ((rd_ID_EX==rs1_IF_ID) || (rd_ID_EX==rs2_IF_ID)))begin
            write_IF_ID_reg = 1'b0;
            write_pc = 1'b0;
            control_mux = 1'b0;
        end else if(branch && ((rd_ID_EX==rs1_IF_ID) || (rd_ID_EX==rs2_IF_ID)))begin
            //if there is a ALU-branch hazard, set write_IF_ID_reg,write_pc,control_mux to 0 to stall the pipeline
            write_IF_ID_reg = 1'b0;
            write_pc = 1'b0;
            control_mux = 1'b0;
        end else begin
            write_IF_ID_reg = 1'b1;
            write_pc = 1'b1;
            control_mux = 1'b1;
        end
    end

endmodule