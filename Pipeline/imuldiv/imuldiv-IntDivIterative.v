//========================================================================
// Lab 1 - Iterative Div Unit
//========================================================================

`ifndef RISCV_INT_DIV_ITERATIVE_V
`define RISCV_INT_DIV_ITERATIVE_V

`include "imuldiv-DivReqMsg.v"

module imuldiv_IntDivIterative
(

  input         clk,
  input         reset,
  input         divreq_msg_fn,
  input  [31:0] divreq_msg_a,
  input  [31:0] divreq_msg_b,
  input         divreq_val,
  output        divreq_rdy,

  output [63:0] divresp_msg_result,
  output        divresp_val,
  input         divresp_rdy
);
wire [1:0] state_w;  // Declare the wire to connect two submodules


  imuldiv_IntDivIterativeDpath dpath
  (
    .clk                (clk),
    .reset              (reset),
    .divreq_msg_fn      (divreq_msg_fn),
    .divreq_msg_a       (divreq_msg_a),
    .divreq_msg_b       (divreq_msg_b),
    .divresp_msg_result (divresp_msg_result),
    .state              (state_w)

  );

  imuldiv_IntDivIterativeCtrl ctrl
  (
    .clk                (clk),
    .reset              (reset),
    .divreq_val         (divreq_val),
    .divreq_rdy         (divreq_rdy),
    .divresp_val        (divresp_val),
    .divresp_rdy        (divresp_rdy),
    .state              (state_w)

  );

endmodule

//------------------------------------------------------------------------
// Datapath
//------------------------------------------------------------------------

module imuldiv_IntDivIterativeDpath
(
  input         clk,
  input         reset,

  input         divreq_msg_fn,      // Function of MulDiv Unit
  input  [31:0] divreq_msg_a,       // Operand A
  input  [31:0] divreq_msg_b,       // Operand B
  input  [1:0]  state,
  output [63:0] divresp_msg_result // Result of operation
);

  //----------------------------------------------------------------------
  // Sequential Logic
  //----------------------------------------------------------------------

  reg  [64:0] a_reg;       // Register for storing operand A
  reg  [64:0] b_reg;       // Register for storing operand B
  reg  [0:0] fn ;
  wire [0:0] sign_bit_a ;
  wire [0:0] sign_bit_b ;

  always@(posedge clk)
  begin
    if(state == 2'd0)
      fn <= divreq_msg_fn; 
    else
      fn <= fn;
  end  
  
  assign  sign_bit_a = divreq_msg_a[31];
  assign  sign_bit_b = divreq_msg_b[31];

  reg is_result_signed_div ;
  reg is_result_signed_rem ;

  always@(posedge clk)
  begin
    if(state == 2'd0)
      begin
        is_result_signed_div = sign_bit_a ^ sign_bit_b;
        is_result_signed_rem = sign_bit_a;
      end  
    else
      begin
        is_result_signed_div <= is_result_signed_div;
        is_result_signed_rem <= is_result_signed_rem;
      end  
  end  



  //----------------------------------------------------------------------
  // Combinational Logic
  //----------------------------------------------------------------------


  // Unsign operands if necessary

  wire [31:0] unsigned_a = ( sign_bit_a ) ? (~divreq_msg_a + 1'b1) : divreq_msg_a;
  wire [31:0] unsigned_b = ( sign_bit_b ) ? (~divreq_msg_b + 1'b1) : divreq_msg_b;

  wire [31:0] unsigned_quotient;
  wire [31:0] unsigned_remainder;
  wire [64:0] diff;
  wire [64:0] a_sh;

  always @(posedge clk or posedge reset) 
  begin
    if (reset) 
      begin
        a_reg <= 65'b0;
        b_reg <= 65'b0;
      end
    else 
      begin
        if (state == 2'd0)//IDLE state 
          begin
            if(divreq_msg_fn)
              begin
                a_reg <= {33'b0, unsigned_a}; // Initialize a_reg
                b_reg <= {1'b0, unsigned_b, 32'b0};// Initialize b_reg
              end
            else 
              begin
                a_reg <= {33'b0, divreq_msg_a}; // Initialize a_reg
                b_reg <= {1'b0, divreq_msg_b, 32'b0};// Initialize b_reg
              end    
          end
        // Perform one step of the multiplication in each clock cycle
        else if (state == 2'd1)//RUN state 
          begin
            if(a_sh < b_reg)
              a_reg <= a_sh;
            else
              a_reg <= {diff[64:1],1'b1} ;
          end
        // else if ( state == 2'd2)//DONE state 
        //   begin
        //     unsigned_quotient <= a_reg[31:0];
        //     unsigned_remainder <= a_reg[63:32];
        //   end  
      end
    end

  assign a_sh = a_reg << 1;
  assign diff = a_sh - b_reg;
  assign unsigned_quotient = a_reg[31:0];
  assign unsigned_remainder = a_reg[63:32];

  // Determine whether or not result is signed. Usually the result is
  // signed if one and only one of the input operands is signed. In other
  // words, the result is signed if the xor of the sign bits of the input
  // operands is true. Remainder opeartions are a bit trickier, and here
  // we simply assume that the result is signed if the dividend for the
  // rem operation is signed.


  // Sign the final results if necessary

  wire [31:0] signed_quotient
    = ( fn && is_result_signed_div ) ? ~unsigned_quotient + 1'b1
    :                            unsigned_quotient;

  wire [31:0] signed_remainder
    = ( fn && is_result_signed_rem )  ? ~unsigned_remainder + 1'b1
   :                              unsigned_remainder;

  // assign divresp_msg_result = { signed_remainder, signed_quotient };
  assign divresp_msg_result
  = (fn ) ? { signed_remainder, signed_quotient } 
  : { unsigned_remainder, unsigned_quotient };


endmodule

//------------------------------------------------------------------------
// Control Logic
//------------------------------------------------------------------------

module imuldiv_IntDivIterativeCtrl
(
  input        clk,           // Clock signal
  input        reset,         // Reset signal
  input        divreq_val,    // Request valid signal
  output       divreq_rdy,    // Request ready signal
  output       divresp_val,   // Response valid signal
  input        divresp_rdy,    // Response ready signal
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
          counter <= 31;
          if ( divreq_val && divreq_rdy )
            state <= RUN;
          else
            state <= IDLE;
        end

        // RUN: During the RUN state, we stay here for 32 cycles (handled in
        // the datapath). Once the datapath signals it's done, we transition
        // to the DONE state.
        RUN: 
        begin
          if ( counter == 0) // counter is 32 means dpath done calculating
            begin
              state <= DONE;
              counter <= counter;
            end  
          else
            begin
              counter <= counter - 1; // Increment the counter
              state <= RUN;
            end
        end

        // DONE: In the DONE state, signal that the result is valid (mulresp_val).
        // Once the response is consumed (mulresp_rdy), go back to IDLE.
        DONE: 
        begin
            counter <= counter;
          if ( divresp_rdy )
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

  // divreq_rdy is asserted in the IDLE state when we are ready for a new request
  assign divreq_rdy = ( state == IDLE );

  // divresp_val is asserted in the DONE state when the result is ready
  assign divresp_val = ( state == DONE );



endmodule

`endif
