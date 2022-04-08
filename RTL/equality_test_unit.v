//Module: Equality test
//Function: when the instruction is a branch, test if two operands are equal

module equality_test_unit(
        input wire [6 :0] opcode,
        input wire [63:0] data1,
        input wire [63:0] data2,
        output reg        zero_flag
    );
    
    parameter integer BRANCH_EQ  = 7'b1100011;
    parameter integer JUMP       = 7'b1101111;

    always@(*)begin
        if(opcode==BRANCH_EQ)begin
            if(data1==data2)begin
                zero_flag = 1'b1;
            end else begin
                zero_flag = 1'b0;
            end
        end else if(opcode==JUMP)begin
            //when there is a jump, flush is needed
            zero_flag = 1'b1;
        end else begin
            zero_flag = 1'b0;    
        end
    end
endmodule

