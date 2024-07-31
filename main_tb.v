`timescale 1ns/1fs

module tb_MSDAP;

    reg sclk, dclk, start, reset_n, inputL, inputR, frame;
    wire inReady, outReady, outputL, outputR;

    //Memories
    reg [15:0] Rj_memory_left [15:0];
    reg [15:0] Rj_memory_right [15:0];
    reg [15:0] co_efficient_memory_left [511:0];
    reg [15:0] co_efficient_memory_right [511:0];
    reg [15:0] data_memory_left [6999:0];
    reg [15:0] data_memory_right [6999:0];
    reg [39:0] output_memory_left [0:500];
    reg [39:0] output_memory_right [0:500];

    //File Handling
    reg [0:370] line;
    reg [255:0] buffer;
    integer input_file, line_index;
    integer rj_index, co_eff_index, data_index ;
    integer output_index_tb, output_data_index_tb;

    //Internal signals
    reg [6:0] count;
    integer i,j;

    //clock sclk 26.88MHz (37.20ns) | FASTER CLK //Make it 28.416MHz
    always #16.276 sclk = ~sclk;

    //clock dclk 768kHz (1.30208us) | SLOWER CLK
    // always #651 dclk = ~dclk;
    always #651.04 dclk = ~dclk;
    
    controller DUT (.sclk(sclk), .dclk(dclk), .start(start), .reset_n(reset_n), .inputL(inputL), .inputR(inputR), .frame(frame), .inReady(inReady), .outReady(outReady), .outputL(outputL), .outputR(outputR));

    initial begin

        /************************** FILE HANDLING **************************/
        
        //Open the file in Reading Mode
        input_file = $fopen("/home/011/s/sx/sxs200367/ASIC/HW6/test_files/TestFiles/data1.in", "r");

        if(input_file == 0)begin
            $fatal("Error in Opening the input file");
        end
        // $fgets(line, input_file);
        // $display("First Line of the file: %s", line);
        // count = 0;
        #200;
        rj_index = 0;
        co_eff_index = 0;
        data_index = 0;
        output_data_index_tb = 0;
        output_index_tb = 0;

        for(line_index=0 ; line_index<7538; line_index = line_index+1)begin
            $fgets(line, input_file);
            $display("The line content is :%0s", line);

            //Put Rj values into memory of TB
            if(line_index >= 3 && line_index <= 19)begin
                $fscanf(input_file, "%h %h", Rj_memory_left[rj_index], Rj_memory_right[rj_index]);
                rj_index = rj_index + 1;
            end

            

            //Put Co-efficient Values into memory of TB
            if(line_index >= 21 && line_index <= 532)begin
                $fscanf(input_file, "%h %h", co_efficient_memory_left[co_eff_index], co_efficient_memory_right[co_eff_index]);
                co_eff_index = co_eff_index + 1;
            end

            //Put Data values into the memory of TB
            if(line_index >= 535 && line_index <= 7537)begin
                $fscanf(input_file, "%h %h", data_memory_left[data_index], data_memory_right[data_index]);
                data_index = data_index + 1;
            end

            #10;
                
        end
        $fclose(input_file);

        /*************************** Testbench Signals ***************************/
        
        sclk <= 0 ;
        dclk <= 1 ;
        reset_n <= 1;
        rj_index = 0;
        co_eff_index = 0;
        data_index = 0;
        frame <= 0;
        start <= 0;

        #1000;
        //Boot into STATE_0
        start <= 1;
        //Move to STATE_1 after clearing the memories and registers
        #60000;

        //Move into STATE_2
        for(i=0; i<16; i=i+1)begin

            for(j=0 ; j<16 ; j=j+1)begin
                if(j==0)begin 
                    @(posedge dclk)begin frame <= 1; inputL <= Rj_memory_left[i][15-j]; end
                end
                else begin
                    @(posedge dclk)begin frame <= 0; inputL <= Rj_memory_left[i][15-j]; end    
                end
                #10;
                // #(1302*15);
               
            end
            #10;
        end
        //Received all Rj values

        //Move to STATE_3: Waiting for Co-efficients
        #(1302*2);
        //Move to STATE_4: writing values into Co-efficient memory
        
        for(i=0; i<512; i=i+1)begin
            for(j=0 ; j<16 ; j=j+1)begin
                if(j==0)begin 
                    @(posedge dclk)begin frame <= 1; inputL <= co_efficient_memory_left[i][15-j]; end
                end
                else begin
                    @(posedge dclk)begin frame <= 0; inputL <= co_efficient_memory_left[i][15-j]; end    
                end
                #10;
                // #(1302*15);
            end
            #10;
        end
        
        //Move to STATE_5: Waiting to receive Data
        #(1302*2);

        //Move to STATE_6: Receiving Data and sending out Data
        for(i=0; i<7000 ; i=i+1)begin
            if(i==4200 || i==6000) reset_n <= 1'b0;
            else reset_n <= 1'b1;
            for(j=0 ; j<16 ; j=j+1)begin
                if(j==0)begin 
                    @(posedge dclk)begin
                        frame <= 1; 
                        inputL <= data_memory_left[i][15-j]; 
                        inputR <= data_memory_right[i][15-j];
                    end
                end
                else begin
                    @(posedge dclk)begin
                        frame <= 0; 
                        inputL <= data_memory_left[i][15-j]; 
                        inputR <= data_memory_right[i][15-j];
                    end    
                end
                #10;
                // #(1302*15);
            end
            #10;
        end

        //Output data
        for(i=0; i<512 ; i=i+1)begin
            @(posedge dclk)begin frame <= 1;end
            #10
            @(posedge dclk)begin frame <= 0;end    
            #(1302*39);
        end



        $finish;
    end

    always@(negedge sclk)begin
        if(outReady)begin
            
            if(output_data_index_tb == 39)begin
                output_data_index_tb <= 0;
                output_memory_left[output_index_tb][output_data_index_tb] <= outputL;
                output_memory_right[output_index_tb][output_data_index_tb] <= outputR;
                output_index_tb <= output_index_tb + 1'b1;
            end
            else begin
                output_memory_left[output_index_tb][output_data_index_tb] <= outputL;
                output_memory_right[output_index_tb][output_data_index_tb] <= outputR;
                output_data_index_tb <= output_data_index_tb + 1'b1;
            end
            
        end
        
           
    end


endmodule