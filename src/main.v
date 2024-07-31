/****************************************************************************************************************
 *  Course       : CE/EE 6306 APPLICATION SPECIFIC INTEGRATED CIRCUITS DESIGN                                   *
 *  University   : The University of Texas at Dallas                                                            *
 *  Instructor   : Prof. Dinesh Bhatia, Prof. Dian Zhou                                                         *
 *  TA           : Tianning Gao                                                                                 *
 *  Assignment   : HW4                                                                                          *
 *  Topic        : Implementation of MSDAP paper using verilog                                                  *
 *  Team Members : Caroline B Joseph  -> CBJ200002                                                              *
 *                 Karthik Teja Movva -> KXM210092                                                              *
 *                 Samuel Priyadarshan Selvakumar Kingslin -> SXS200367                                         *
 *                                                                                                              *
 *****************************************************************************************************************/



module controller(Sclk, Dclk, Start, Reset_n, InputL, InputR, Frame, InReady, OutReady, OutputL, OutputR);

    // 30.721MHz clk domain
    input wire Sclk;
    output reg InReady, OutputL, OutputR;

    // 768KHz clk domain 
    input wire Dclk, Frame, InputL, InputR;
    output reg OutReady;

    // Asynchronous signals
    input wire Start, Reset_n;

    //STATE Definitions
    parameter STATE_0 = 4'b0000; //Initialization
    parameter STATE_1 = 4'b0001; //Waiting to receive Rj
    parameter STATE_2 = 4'b0010; //Reading Rj
    parameter STATE_3 = 4'b0011; //Waiting to receive Co-efficients
    parameter STATE_4 = 4'b0100; //Reading Co-efficients
    parameter STATE_5 = 4'b0101; //Waiting to receive data
    parameter STATE_6 = 4'b0110; //Working
    parameter STATE_7 = 4'b0111; //Clearing
    parameter STATE_8 = 4'b1000; //Sleeping

    //INTERNAL REGISTERS
    reg [3:0] present_state, next_state;
    reg [9:0] zero_counter;
    reg ack, Rj_en, Rj_write_en, Co_eff_en;
    reg [13:0] index, output_index, index_delay;
    reg [5:0] data_index, output_data_index, standby_data_index;
    reg standby_index;
    reg output_ack, done, reading, ON, done_clearing, Rj_ack, Co_eff_ack, rst_ack;
    reg [39:0] input_extend_40bits_left, input_extend_40bits_right;
    reg input_received, output_processed, output_received, output_computed;
    reg clk_gate, Start_read;
    reg [15:0] value_for_Rj_memory;
    
    //COMPUTATION
    reg [4:0] co_efficient_fetch_count;
    reg [7:0] total_number_of_terms, term_count, co_efficient_memory_value_for_computation;
    reg done_fetching_co_efficients, computation_Started, Start_computation, computation_sign;
    reg [8:0] Co_efficient_memory_index;
    reg [3:0] Rj_memory_index, buffer_index;
    reg [19:0] input_number_n, output_memory_index;
    reg [39:0] u_term_buffer, temp_value, value_to_output_memory;
    reg [39:0] computation_buffer [15:0];
    reg [19:0] value_of_n_k;
    reg [15:0] twos_complement;
    
    wire [15:0] twos_complement_wire;
    wire [15:0] sign_extend_left_complement;
    
    
    assign twos_complement_wire = twos_complement;
    assign sign_extend_left_complement = (twos_complement_wire[15]) ? 10'h3ff : 10'd0;
    
    
    //INTERNAL WIRES
    wire Sclk_gated, Dclk_gated, Rj_en_wire, Rj_write_en_wire, Co_eff_en_wire;
    wire [15:0] value_for_Rj_memory_wire, value_from_Rj_memory, index_wire;

    //MEMORIES 
    reg [15:0] Rj_memory [15:0];
    reg [15:0] co_efficient_memory [511:0];
    reg [15:0] data_memory_left [500:0];
    reg [15:0] data_memory_right [500:0];
    reg [15:0] standby_buffer_left [1:0];
    reg [15:0] standby_buffer_right [1:0];
    reg [39:0] output_memory_left [500:0];
    reg [39:0] output_memory_right [500:0];

    //Assign Statements
    wire [9:0] sign_extend_left, sign_extend_right;
//    wire [9:0] sign_extend_left_complement, sign_extend_right_complement;
//    assign sign_extend_left = (data_memory_left[output_index][15]) ? 10'h3ff : 10'd0;
//    assign sign_extend_left_complement = ( (~data_memory_left[value_of_n_k]) + 1'b1) ? 10'h3ff : 10'd0;
    assign sign_extend_left = (data_memory_left[value_of_n_k-1][15]) ? 10'h3ff : 10'd0;
    assign sign_extend_right = (data_memory_right[output_index][15]) ? 10'h3ff : 10'd0;
    assign Sclk_gated = Sclk & (!clk_gate);
    assign Dclk_gated = Dclk & (!clk_gate); 
    assign Rj_en_wire = Rj_en;
    assign Co_eff_en_wire = Co_eff_en;
    assign Rj_write_en_wire = Rj_write_en;
    assign value_for_Rj_memory_wire = value_for_Rj_memory;
    assign index_wire = index;
    
    
    //INSTANSITATION
    rj_memory_module RJ_MEM (.Sclk(Sclk), .Dclk(Dclk), .write_enable(Rj_write_en), .rj_mem_en(Rj_en), .rj_index(index_delay), .rj_value(value_for_Rj_memory), .rj_out(value_from_Rj_memory));
    

    initial begin
        // present_state <= 4'b0000;
        // next_state <= 4'b0000;
        ON <= 1'b0;
        index <= 14'd0;
        data_index <= 6'd0;
        clk_gate <= 1'b0;
    end

    

    /*************************************** 28.66MHz clk DOMIAN ***************************************/

    always@(posedge Sclk)begin
        present_state <= next_state;
    end

    always@(negedge Sclk_gated or posedge Reset_n or posedge Start)begin
        if(Start)begin
	   next_state <= STATE_0;
            	ON <= 1'b1;
   	    	done_clearing <= 1'b0;
        end
	
	else if(Reset_n)begin
		next_state <= STATE_0;
		ON <= 1'b1;
		done_clearing <= 1'b0;
	end

	else if(Start)begin   
            	next_state <= STATE_0;
            	ON <= 1'b1;
   	    	done_clearing <= 1'b0;
	end

	else begin
        case (present_state)
            
            STATE_0: begin  //Initialization

                if(Start)begin    
                    if (index < 11'd1500)begin
                        //Clear all the memory values
                        data_memory_left[index] <= 16'h0000;
                        co_efficient_memory[index] <= 16'h0000;
                        Rj_memory[index] <= 16'h0000;
                        index <= index + 1'b1;
                        InReady <= 1'b0;
                        computation_Started <= 1'b1;
                        Start_computation <= 1'b0;
                    end
                    else begin
                        next_state <= STATE_1; 
                        done_clearing <= 1'b1;    
                        InReady <= 1'b1;
                        zero_counter <= 10'd0;
                    end
                end
            end

            STATE_1: begin //Waiting to receive Rj
                InReady <= 1'b1;
                if (Frame)begin
                    next_state <= STATE_2;
                    index <= 10'd0;
                    //Start_read <= 1'b1;
                    Rj_ack <= 1'b0;
                    Rj_en <= 1'b1;
                    //Rj_write_en <= 1'b1;
//                    value_for_Rj_memory <= 16'd0;
                end

		else begin
			//Do Nothing
		end
            end

            STATE_3: begin //Waiting to receive Co-efficients
                InReady <= 1'b1;
                if (Frame)begin
                    next_state <= STATE_4;
                    index <= 10'd0;
                    //Start_read <= 1'b1;
                    Co_eff_ack <= 1'b0;
                    Co_eff_en <= 1'b1;
                end

		else begin
			//Do Nothing
		end
            end

            STATE_5: begin //Waiting to receive data
                InReady <= 1'b1;

                if(!Reset_n)begin
                    next_state <= STATE_7;
                    rst_ack <= 1'b0;
                end

                else if(Frame)begin 
                    next_state <= STATE_6;
                    done <= 1'b0;
                    output_index <= 10'd0;
                    output_data_index <= 6'd0;
                    //Start_read <= 1'b1;
                    computation_Started <= 1'b0;
                    temp_value <= 40'd0;
                    value_of_n_k <= 20'd0;
                    input_number_n <= 20'd1;
                    output_memory_index <= 20'd0;
                end

                // if(!Reset_n) next_state <= STATE_7;
                else begin
			//Do Nothing
		end
            end

            STATE_6: begin //Working

                if(!Reset_n)begin 
                    next_state <= STATE_7;
                    data_index <= 6'd0;
                    index <= 11'd0;
                end
                // if(zero_counter == 10'd800) next_state <= STATE_8;
                else begin

                    // if(!InReady && !done)begin
                    if(!done)begin

                        if(data_index == 6'd15)begin
                            data_memory_left[index][6'hF - data_index] <= InputL;
                            data_memory_right[index][6'hF - data_index] <= InputR;
                            input_received <= 1'b1;
                            output_data_index <= 6'd0;
                            output_received <= 1'b0;
                            co_efficient_fetch_count <= 4'd0;
                            
                            
                        end
                    
                        else if(Frame && output_processed)begin
                            input_received <= 1'b0;
                            output_received <= 1'b0;
                            output_processed <= 1'b0;
                            output_data_index <= 6'd0;
                            OutputL <= input_extend_40bits_left[6'd1];
                            output_data_index <= 6'd2;
                            // output_data_index <= output_data_index + 1'b1;
                            // output_index <= output_index + 1'b1;
                        end

                        else if(output_data_index == 6'd39 && output_index == 14'd3799)begin
                            done <= 1'b1;
                            
                        end
                        else if(output_data_index == 6'd40)begin
                            // output_ack <= 1'b1;
                            output_received <= 1'b1;
                            output_data_index <= 6'd0;
                            output_index <= output_index + 1'b1;
                            
                        end

                        else if(input_received)begin
                            input_extend_40bits_left <= {sign_extend_left, data_memory_left[output_index], 16'h0000};
                            // input_extend_40bits_right <= {sign_extend_right, data_memory_right[output_index], 16'h0000};
                            input_extend_40bits_right <= 39'd0;
                            OutputL <= input_extend_40bits_left[6'd0];
                            output_data_index <= 6'd1;
                            output_processed <= 1'b1; //Might be needed for HW4 to work
                            Start_computation <= 1'b1;
//                            input_received <= 1'b0;
//                            if(!computation_Started)begin
//                                computation_Started <= 1'b1;
                                Rj_memory_index <= 4'd0;
                                if (!Start_computation)begin 
                                    Co_efficient_memory_index <= 9'd0;
                                    u_term_buffer <= 40'd0;
                                    term_count <= 8'd0;
                                end

				else begin
					//Do Nothing
				end
    //                            output_computed <= 1'b0;
                                
//                            end
                        end
                        else if(!output_received)begin
                            OutputL <= input_extend_40bits_left[output_data_index];
                            OutputR <= input_extend_40bits_right[output_data_index];
                            output_data_index <= output_data_index + 1'b1;
                        end

			else begin
				//Do Nothing
			end

                        
                    end
                end
            end

            

            STATE_7: begin //Cleaning
                InReady <= 1'b0;
                // Clear memories and registers except for Rj and co-efficient
                data_memory_left[index] <= 16'd0;
                data_memory_right[index] <= 16'd0;
                index <= index + 1'b1;

                if(index == 13'd7000 && Reset_n)begin
                    next_state <= STATE_5;
                    index <= 14'd0;
                    data_index <= 6'd0;
                    InReady <= 1'b1;
                    rst_ack <= 1'b1;
                end

		else begin
			//Do Nothing
		end

            end            
            
            default: begin
            	//Do Nothing
	    end
            
        endcase 
	end
    end

    always@(*)begin
        OutReady <= Frame && !output_received;
    end

    always@(*)begin
        reading <= Frame | Start_read;
    end
    
    
    /********************************* ALU CONTROLLER *********************************/
        
        always@(posedge Sclk_gated)begin
            case(present_state)
                STATE_6:begin //Computation STATE
                    if(output_computed)begin
                        //SEND OUTPUT TO MEMORY
                    end
                    
                    else begin
                        if(Start_computation)begin
                            //PERFORM COMPUTATION

                             if(Co_efficient_memory_index == 9'd511 && Rj_memory_index == 4'hf)begin
                                 Start_computation <= 1'b0;
                                 input_number_n <= input_number_n + 1'b1;
                                 value_to_output_memory <= {u_term_buffer[39], u_term_buffer[39:1]};
                                 output_memory_left[input_number_n-1] <= {u_term_buffer[39], u_term_buffer[39:1]};
                                 //value_of_n_k <= 20'd0;
                             end

                            output_computed <= 1'b0;
                            if(co_efficient_fetch_count < 4'd15 || co_efficient_fetch_count == 4'd15)begin //This is the loop for U values
                                done_fetching_co_efficients <= 1'b0;
                                total_number_of_terms <= Rj_memory[Rj_memory_index];
                                term_count <= 4'd0;
                                
                                //Fetching the co-efficient values
                                if(term_count < total_number_of_terms)begin //This is the loop for R values
                                    co_efficient_memory_value_for_computation <= co_efficient_memory[Co_efficient_memory_index][7:0];
                                    //value_of_n_k <= input_number_n - co_efficient_memory[Co_efficient_memory_index][7:0];
	                           //       value_of_n_k <= input_number_n;
//                                    if((input_number_n - co_efficient_memory[Co_efficient_memory_index][7:0]) > 20'd1)begin
                                    //if(Start_computation)begin
                                        
                                        computation_sign <= co_efficient_memory[Co_efficient_memory_index-1][8];
                                        //Check for sign for Add/Sub
                                        if(!co_efficient_memory[Co_efficient_memory_index-1][8])begin
//                                            if( (input_number_n - co_efficient_memory[Co_efficient_memory_index][7:0]) > input_number_n-1)begin
                                           /* if( (value_of_n_k > input_number_n+1) || (value_of_n_k == 20'd0))begin
                                                u_term_buffer <= u_term_buffer;
                                            end*/
                                            
                                            /*else begin
                                                u_term_buffer <= u_term_buffer + {sign_extend_left, data_memory_left[value_of_n_k - 1'b1], 16'h0000};
//                                                u_term_buffer <= u_term_buffer + {{10{data_memory_left[value_of_n_k - 1'b1][15]}}, data_memory_left[value_of_n_k - 1'b1], 16'h0000};
                                                temp_value <= {data_memory_left[value_of_n_k-1]};
                                                
                                            end*/
                                            u_term_buffer <= u_term_buffer + 1'b1;
                                        end
                
                                        else begin
                                            /*if( (value_of_n_k > input_number_n+1) || (value_of_n_k == 20'd0))begin
                                                u_term_buffer <= u_term_buffer;
//                                                /emp_value <= temp_value + 2'd2;
                                            end
                                            
                                            else begin
//                                                twos_complement <= ~data_memory_left[value_of_n_k-1] + 1'b1;
//                                                u_term_buffer <= u_term_buffer + {sign_extend_left_complement, (~data_memory_left[value_of_n_k-1] + 1'b1), 16'h0000};
                                                
                                                u_term_buffer <= u_term_buffer - {sign_extend_left, data_memory_left[value_of_n_k - 1'b1],16'h0000};
//                                                u_term_buffer <= u_term_buffer + {{10{data_memory_left[value_of_n_k - 1'b1][15]}}, data_memory_left[value_of_n_k - 1'b1], 16'h0000};
//                                                temp_value <= {(~ data_memory_left[value_of_n_k-1]) + 1'b1, 16'h0000};
//                                                temp_value <= temp_value + 1'b1;
                                                temp_value <= {data_memory_left[value_of_n_k-1], 16'h0000};
                                            end*/
                                            u_term_buffer <= u_term_buffer + 1'b1;
                                        end
                                    //end
                                    term_count <= term_count + 1'b1;
                                    Co_efficient_memory_index <= Co_efficient_memory_index + 1'b1;
//                                    u_term_buffer <= u_term_buffer + temp_value;
                                end
                
                                else begin
    //                                output_computed <= 1'b1;
                                    /*if((value_of_n_k > input_number_n+1) || (value_of_n_k == 20'd0))begin
                                        if(co_efficient_memory[Co_efficient_memory_index][16])begin
                                            
                                        end
                                        
                                        else begin
                                        
                                        end
                                    end*/
                                    u_term_buffer <= {u_term_buffer[39], u_term_buffer[39:1]};
                                    term_count <= 15'd0;
                                    Rj_memory_index <= Rj_memory_index + 1'b1;
                                    computation_buffer[buffer_index] <= u_term_buffer;
                                    buffer_index <= buffer_index + 1'b1;
                                    co_efficient_fetch_count <= co_efficient_fetch_count + 1'b1;
                                    //value_of_n_k <= 20'd0;
                                    
                                end
                            end
                            
                            else begin
                                done_fetching_co_efficients <= 1'b1;
                            end
                        end

                        else begin
                //            value_of_n_k <= 20'd0;
//                             Start_computation <= 1'd0;
//                             input_number_n <= input_number_n + 1'b1;
                        end
                    end
                end
            endcase
        end

    /**************************************** 768KHz clk DOMIAN ****************************************/

    always@(posedge Dclk_gated or posedge Reset_n)begin //SYNTHESIS ERROR HERE
	
	if(Reset_n)begin
		//Do Nothing

	end
	
	else begin
        case(present_state)

            STATE_0:begin
                //OutReady <= 1'b0;
            end

            STATE_2: begin //Reading Rj

                if(reading)begin
                    index_delay <= index;
                    Rj_memory[index][6'hF - data_index] <= InputL;
                    value_for_Rj_memory[6'hF - data_index] <= InputL;
//                    value_for_Rj_memory <= {value_for_Rj_memory[14:0], InputL};
                    // data_index <= data_index + 1'b1;
                    if (index == 10'd15 && data_index == 6'd15)begin
                        //next_state <= STATE_3;
                        //Start_read <= 1'b0;
                        Rj_ack <= 1'b1;
                        //Completed receiving Rj values
                        //InReady <= 1'b1;
                        //index <= 10'd0;
                        //data_index <= 6'd0;
                        //Rj_write_en <= 1'b0;
                        
                    end
                    else if (data_index < 6'd15)begin 
                        //data_index <= data_index + 1'b1;
//                        value_for_Rj_memory <= 16'd0;
                    end
                    else if (data_index == 6'd15)begin
//                        value_for_Rj_memory[6'hF - data_index] <= InputL;
//                        value_for_Rj_memory <= 16'd0;
                        //index <= index + 1'b1;
                        //data_index <= 6'd0;
                    end
                end
            end

            STATE_4: begin //Reading Co-efficients

                if(reading)begin
                    co_efficient_memory[index][6'hF - data_index] <= InputL; 
                    // data_index <= data_index + 1'b1;
                    
                    if (index == 10'd511 && data_index == 6'd15)begin
                        //next_state <= STATE_5;
                        Co_eff_ack <= 1'b1;
                        //Start_read <= 1'b0;
                        //Completed receiving co-efficient values
                        //InReady <= 1'b1;
                        //index <= 10'd0;
                        //data_index <= 6'd0;
                    end
                    //else if (data_index < 6'd15) //data_index <= data_index + 1'b1;
                    
                    else if (data_index == 6'd15)begin
                        
                        //index <= index + 1'b1;
                        //data_index <= 6'd0;
                    end
                end
            end

            STATE_6: begin //Working
                if(!Reset_n)begin
                    //next_state <= STATE_7;
                    rst_ack <= 1'b0;
                end
                if(zero_counter == 10'd800)begin
                    standby_index <= 0;
                    standby_data_index <= 6'd0;
                    //next_state <= STATE_8;
                    //zero_counter <= 10'd0;
                    clk_gate <= 1'b1;
                end
                else begin
                    if (reading)begin
                        //data_memory_left[index][6'hF - data_index] <= InputL; 
                        //data_memory_right[index][6'hF - data_index] <= InputR;
                        
                        if (index == 14'd3799 && data_index == 6'd15)begin
                            //Completed receiving co-efficient values
                            //input_received <= 1'b1;
                            //index <= 10'd0;
                            //data_index <= 6'd0;
                            //output_index <= 10'd0;
                            //output_data_index <= 6'd0;
                        end
                        //else if (data_index < 6'd15) //data_index <= data_index + 1'b1;
                        
                        else if (data_index == 6'd15)begin
                            
                            // zero_counter <= !((|data_memory_left[index]) & (|data_memory_right[index])) ? zero_counter + 1'b1 : 10'd0;
                            //zero_counter <= (data_memory_left[index] == 16'd0 && data_memory_right[index] == 16'd0) ? zero_counter + 1'b1 : 10'd0;
                            //index <= index + 1'b1;
                            //data_index <= 6'd0;
                        end
                    end
                end
            end
        endcase
       end 
    end

    always@(negedge Dclk or negedge Reset_n)begin
        //Read Input Data
       	if(!Reset_n)begin
		//Do Nothing
	end

        else if (present_state == STATE_8)begin
            if(~Reset_n)begin
            //next_state <= STATE_7;
            //clk_gate <= 1'b0;
            rst_ack <= 1'b0;
            end

            else if(standby_data_index == 6'd15)begin
                if((|standby_buffer_left[standby_index] == 1) || (|standby_buffer_right[standby_index] == 1) )begin
                    standby_buffer_left[standby_index][standby_data_index] <= InputL;
                    standby_buffer_right[standby_index][standby_data_index] <= InputR;
                    standby_index <= standby_index + 1'b1;
                    //standby_data_index <= 6'd0;
                    //next_state <= STATE_6;
                    //clk_gate <= 1'b0;
                end

                else begin
                    standby_index <= standby_index + 1'b1;
                    //standby_data_index <= 6'd0;
                end
            end

            else if(Frame)begin
                standby_buffer_left[standby_index][standby_data_index] <= InputL;
                standby_buffer_right[standby_index][standby_data_index] <= InputR;
                //standby_data_index <= standby_data_index + 1'b1;
            end
            else if(standby_data_index != 6'd0)begin
                standby_buffer_left[standby_index][standby_data_index] <= InputL;
                standby_buffer_right[standby_index][standby_data_index] <= InputR;
                //standby_data_index <= standby_data_index + 1'b1;
            end

	    else begin
	    	//Do Nothing
	    end
        end

	else begin
		//Do Nothing
	end
    end

    always@(posedge Dclk)begin
        if(present_state == STATE_8)begin
            if(standby_data_index == 6'd15)begin
                if((|standby_buffer_left[standby_index] == 1) || (|standby_buffer_right[standby_index] == 1))begin
                    standby_buffer_left[standby_index][standby_data_index] <= InputL;
                    standby_buffer_right[standby_index][standby_data_index] <= InputR;
                    standby_data_index <= 6'd0;
                    standby_index <= standby_index + 1'b1;
                    //next_state <= STATE_6;
                    output_ack <= 1'b0;
                    //clk_gate <= 1'b0;
                    //output_index <= output_index + 1'b1;
                    //output_data_index <= 6'd0;
                    standby_buffer_left[0] <= 16'd0;
                    standby_buffer_left[1] <= 16'd0;
                    standby_buffer_right[0] <= 16'd0;
                    standby_buffer_right[1] <= 16'd0;
                   // data_memory_left[0] <= {InputL,standby_buffer_left[standby_index][14:0]};
                    data_memory_right[0] <= {InputR,standby_buffer_right[standby_index][14:0]};
                end
                else begin
                    standby_index <= standby_index + 1'b1;
                    standby_data_index <= 6'd0;
                end
            end
        end
    end
    
    


endmodule
