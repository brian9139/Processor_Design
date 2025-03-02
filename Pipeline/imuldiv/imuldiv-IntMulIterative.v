//========================================================================
// Lab 1 - Iterative Mul Unit
//========================================================================

`ifndef RISCV_INT_MUL_ITERATIVE_V
`define RISCV_INT_MUL_ITERATIVE_V

module imuldiv_IntMulIterative
(
  input                clk,
  input                reset,

  input  [31:0] mulreq_msg_a,
  input  [31:0] mulreq_msg_b,
  input         mulreq_val,
  output        mulreq_rdy,
  output [63:0] mulresp_msg_result,
  output        mulresp_val,
  input         mulresp_rdy
);
wire [1:0] state_w;  // Declare the wire to connect two submodules


  imuldiv_IntMulIterativeDpath dpath
  (
    .clk                (clk),
    .reset              (reset),
    .mulreq_msg_a       (mulreq_msg_a),
    .mulreq_msg_b       (mulreq_msg_b),
    .mulresp_msg_result (mulresp_msg_result),
    .state              (state_w)
  );

  imuldiv_IntMulIterativeCtrl ctrl
  (
    .clk                (clk),
    .reset              (reset),
    .mulreq_val         (mulreq_val),
    .mulreq_rdy         (mulreq_rdy),
    .mulresp_val        (mulresp_val),
    .mulresp_rdy        (mulresp_rdy),
    .state              (state_w)
  );

endmodule

//------------------------------------------------------------------------
// Datapath
//------------------------------------------------------------------------

module imuldiv_IntMulIterativeDpath
(
  input         clk,
  input         reset,
  input  [31:0] mulreq_msg_a,       // Operand A
  input  [31:0] mulreq_msg_b,       // Operand B
  input  [1:0] state,
  output [63:0] mulresp_msg_result // Result of operation

);

  //----------------------------------------------------------------------
  // Sequential Logic
  //----------------------------------------------------------------------

  reg  [63:0] a_reg;       // Register for storing operand A
  reg  [31:0] b_reg;       // Register for storing operand B

  //----------------------------------------------------------------------
  // Combinational Logic
  //----------------------------------------------------------------------

  // Extract sign bits

  reg [1:0] sign_bit_a ;
  reg [1:0] sign_bit_b ;

  always@(*)
  begin
    if(state == 2'd0)
      begin
        sign_bit_a <= mulreq_msg_a[31];
        sign_bit_b <= mulreq_msg_b[31];
      end  
    else
      begin
        sign_bit_a <= sign_bit_a;
        sign_bit_b <= sign_bit_b;
      end  
  end  

// Unsign operands if necessary

  wire [31:0] unsigned_a = ( sign_bit_a ) ? (~mulreq_msg_a + 1'b1) : mulreq_msg_a;
  wire [31:0] unsigned_b = ( sign_bit_b ) ? (~mulreq_msg_b + 1'b1) : mulreq_msg_b;

  // Computation logic
  

  reg [63:0] unsigned_result ;//change to iterative multiplication logic

  always @(posedge clk or posedge reset) 
  begin
    if (reset) 
      begin
        a_reg <= 64'b0;
        b_reg <= 32'b0;
        unsigned_result <= 64'b0;
      end
    else 
      begin
        if (state == 2'd0)//IDLE state 
        begin
          a_reg <= {32'b0, unsigned_a}; // Initialize a_reg
          b_reg <= unsigned_b;          // Initialize b_reg
          unsigned_result <= 64'b0;       // Reset the result register
        end
        // Perform one step of the multiplication in each clock cycle
        else if (state == 2'd1) 
        begin
          if (b_reg[0] == 1'b1) 
          begin
            unsigned_result <= unsigned_result + a_reg; // Add if LSB of b is 1
          end
          a_reg <= a_reg << 1; // Shift a_reg left
          b_reg <= b_reg >> 1; // Shift b_reg right
        end
      end
    end


  // Determine whether or not result is signed. Usually the result is
  // signed if one and only one of the input operands is signed. In other
  // words, the result is signed if the xor of the sign bits of the input
  // operands is true. Remainder opeartions are a bit trickier, and here
  // we simply assume that the result is signed if the dividend for the
  // rem operation is signed.

  wire is_result_signed = sign_bit_a ^ sign_bit_b;

  assign mulresp_msg_result
    = ( is_result_signed && state == 2'd2) ? (~unsigned_result + 1'b1) : unsigned_result;

endmodule

//------------------------------------------------------------------------
// Control Logic
//------------------------------------------------------------------------

module imuldiv_IntMulIterativeCtrl
(
  input        clk,           // Clock signal
  input        reset,         // Reset signal
  input        mulreq_val,    // Request valid signal
  output       mulreq_rdy,    // Request ready signal
  output       mulresp_val,   // Response valid signal
  input        mulresp_rdy,    // Response ready signal
  output reg [1:0] state
);

  reg [6:0] counter;
  localparam IDLE = 2'd0 ;
  localparam RUN = 2'd1 ;
  localparam DONE = 2'd2 ;


  //----------------------------------------------------------------------
  // Sequential State Transition Logic
  //----------------------------------------------------------------------

  always @(posedge clk) 
  begin
    if (reset)
      begin
        state <= IDLE;
      end
    else 
      begin
      case ( state )
        // IDLE: Wait for a ready request (mulreq_rdy) and if the response 
        // interface is valid (mulresp_val), move to RUN state.
        IDLE: 
        begin
          counter <= 0;
          if ( mulreq_val && mulreq_rdy )
            state <= RUN;
          else
            state <= IDLE;
        end

        // RUN: During the RUN state, we stay here for 32 cycles (handled in
        // the datapath). Once the datapath signals it's done, we transition
        // to the DONE state.
        RUN: 
        begin
          if ( counter == 31) // counter is 32 means dpath done calculating
            begin
              state <= DONE;
            end  
          else
            begin
              counter <= counter + 1; // Increment the counter
              state <= RUN;
            end
        end

        // DONE: In the DONE state, signal that the result is valid (mulresp_val).
        // Once the response is consumed (mulresp_rdy), go back to IDLE.
        DONE: 
        begin
          if ( mulresp_rdy )
          begin
            state <= IDLE;
          end
          else
            state <= DONE;
        end
      endcase
    end
  end  


  //----------------------------------------------------------------------
  // Output Logic
  //----------------------------------------------------------------------

  // mulreq_rdy is asserted in the IDLE state when we are ready for a new request
  assign mulreq_rdy = ( state == IDLE );

  // mulresp_val is asserted in the DONE state when the result is ready
  assign mulresp_val = ( state == DONE );

endmodule
`endif

// reg [1:0] state, state_temp;

// always@(posedge clk) begin
//   if (rst)
//     state <= 0;
//   else
//     state <= state_temp;A131156065


// end

// always@* begin
//   case(state)
//     IDLE: state_temp = RUN;
//     RUN: begin
//       if (...) state_temp = DONE;
//       else state_temp = RUN;
//     end
//     DONE: begin
//       state_temp = IDLE;
//     end

//   endcase

// end
