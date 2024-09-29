/****************************************************************************
FILENAME     :  video_uut.sv
PROJECT      :  Hack the Hill 2024
****************************************************************************/

/*  INSTANTIATION TEMPLATE  -------------------------------------------------

video_uut video_uut (
    .clk_i          ( ),//               
    .cen_i          ( ),//
    .vid_sel_i      ( ),//
    .vdat_bars_i    ( ),//[19:0]
    .vdat_colour_i  ( ),//[19:0]
    .fvht_i         ( ),//[ 3:0]
    .fvht_o         ( ),//[ 3:0]
    .video_o        ( ) //[19:0]
);

-------------------------------------------------------------------------- */


module video_uut (
    input  wire         clk_i           ,// clock
    input  wire         cen_i           ,// clock enable
    input  wire         vid_sel_i       ,// select source video
	 input  wire [15:0]	vid_count 		 ,
    input  wire [19:0]  vdat_bars_i     ,// input video {luma, chroma}
    input  wire [19:0]  vdat_colour_i   ,// input video {luma, chroma}
    input  wire [3:0]   fvht_i          ,// input video timing signals
    output wire [3:0]   fvht_o          ,// 1 clk pulse after falling edge on input signal
    output wire [19:0]  video_o          // 1 clk pulse after any edge on input signal
); 



reg [19:0]  vid_d1;
reg [3:0]   fvht_d1, fvht_d2, fvht_d3;
reg [9:0]  	int_cbcr;
reg        	int_ffsignal = 'b0;


reg [15:0] 	x_count = 0;
reg [15:0] 	y_count = 0;
reg [15:0]  frame_count = 0;
reg [15:0] 	video_frame_count = 0;

reg h_trigger = 0;
reg v_trigger = 0;
reg row_index_trigger = 0;


localparam frame_rate = 8; // fps is calculated with 60/frame_rate 
localparam num_frames = 4;
localparam x_resolution = 96;
localparam y_resolution = 54;
localparam image_size = x_resolution*y_resolution;
reg [15:0] column_index = 0;
reg [15:0] row_index = 0;
reg [29:0]  selected_color;

localparam size = image_size*num_frames;
reg [15:0] array_index;
wire [29:0] val1;
wire [29:0] val2;

//rom frame pixel storage
rom #(
			.SIZE			  (size)
			) rom (
			.clk_i (clk_i),
			.cen_i (cen_i),
			.addr_i(array_index),
			.val1_o (val1),
			.val2_o (val2)
			);

always @(posedge clk_i) begin
    if(cen_i) begin
		//calculates the width of one square 
		if (x_count % 21 == 20) begin
		
			column_index <= column_index + 1;
			
			if (column_index == x_resolution-1) begin
				column_index <= 0;
			end
				
		end
		
		//calculates the height of one square 
		if (y_count % 21 == 20) begin
			
			if (row_index_trigger == 0) begin
				row_index <= row_index + 1;
				row_index_trigger <= 1;
			end
			
			if (row_index == y_resolution-1) begin
				row_index <= 0;
			end
			
		end else begin
			row_index_trigger <= 0;
		end
		
		//fetches square color from rom
		array_index <= (row_index*x_resolution + column_index) + video_frame_count*image_size;
		
		selected_color <= vid_sel_i ? val1 : val2;

		  
		//alternate between Cb, Cr
		if (int_ffsignal == 0) begin
			int_ffsignal <= 1;
         int_cbcr <= selected_color[19:10];
		end else begin
         int_ffsignal <= 0;
         int_cbcr <= selected_color[9:0];  
		end
		  
		x_count <= x_count + 1;
		
		//if reach start of row...
		if (fvht_i[1] == 1) begin
			//triggers ensure no repetition of changes
			if (h_trigger == 0) begin
				y_count <= y_count + 1;
				h_trigger <= 1;
			end
			x_count <= 0;
			column_index <= 0;
		end else  if (fvht_i[2] == 0) begin
			h_trigger <= 0;
		end
	
		//if reach end of frame
		if (fvht_i[2] == 1) begin
			//triggers for no repetition
			if (v_trigger == 0) begin
				v_trigger <= 1;
				frame_count <= frame_count + 1;
			end
			y_count <= 0;
			row_index <= 0;
		end else if (fvht_i[1] == 0) begin
			v_trigger <= 0;
		end
		
		//gives a new frame every 8 rendering frames
		if (frame_count >= frame_rate) begin
			frame_count <= 0;
			video_frame_count <= video_frame_count + 1;
			
			if (video_frame_count == num_frames-1) begin
				video_frame_count <= 0;
				
			end
		end
		
		
		//send output
		vid_d1 <= {selected_color[29:20], int_cbcr};
		fvht_d1 <= fvht_i;
		fvht_d2 <= fvht_d1;
		fvht_d3 <= fvht_d2;
	end
end

// OUTPUT
assign fvht_o  = fvht_d3;
assign video_o = vid_d1;

endmodule

