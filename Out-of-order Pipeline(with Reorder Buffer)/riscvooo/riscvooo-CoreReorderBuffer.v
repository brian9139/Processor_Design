//=========================================================================
// 5-Stage RISCV Scoreboard
//=========================================================================

`ifndef RISCV_CORE_REORDERBUFFER_V
`define RISCV_CORE_REORDERBUFFER_V

module riscv_CoreReorderBuffer
(
  input         clk,
  input         reset,

  input         rob_alloc_req_val,
  output        rob_alloc_req_rdy,
  input  [ 4:0] rob_alloc_req_preg,
  
  output [ 3:0] rob_alloc_resp_slot,

  input         rob_fill_val,
  input  [ 3:0] rob_fill_slot,

  output        rob_commit_wen,
  output [ 3:0] rob_commit_slot,
  output [ 4:0] rob_commit_rf_waddr
);

  // Parameters and ROB definitions
  parameter ROB_SIZE = 16;

  reg  valid   [0:ROB_SIZE-1];         // Valid bit for each entry
  reg  pending [0:ROB_SIZE-1];       // Pending bit for each entry
  reg [4:0] rob_preg[0:ROB_SIZE-1]; // Physical register for each entry

  reg [3:0] head; // Head pointer for commit
  reg [3:0] tail; // Tail pointer for allocation

  wire is_full  = (head == tail) && valid[head];
  wire is_empty = (head == tail) && !valid[head];

  // Allocation logic
  assign rob_alloc_req_rdy = !is_full;
  assign rob_alloc_resp_slot = tail;

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      head <= 4'd0;
      tail <= 4'd0;
      for(integer i = 0; i < 16; i = i + 1)begin
        valid[i] <= 0;
        pending[i] <= 0;
      end
    end
    else if (rob_alloc_req_val && rob_alloc_req_rdy) begin
      valid[tail] <= 1'b1;
      pending[tail] <= 1'b1;
      rob_preg[tail] <= rob_alloc_req_preg;
      tail <= tail + 4'd1;
    end
  end

  // Writeback logic
  always @(posedge clk) begin
    if (rob_fill_val) begin
      pending[rob_fill_slot] <= 1'b0;
    end
  end

  // Commit logic
  assign rob_commit_wen = valid[head] && !pending[head];
  assign rob_commit_slot = head;
  assign rob_commit_rf_waddr = rob_preg[head];

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      head <= 4'd0;
    end
    else if (rob_commit_wen) begin
      valid[head] <= 1'b0;
      head <= head + 4'd1;
    end
  end

endmodule

`endif
