//=========================================================================
// Cache Base Design
//=========================================================================

`include "vc-RAMs.v"

`ifndef RISCV_CACHE_BASE_V
`define RISCV_CACHE_BASE_V

module riscv_CacheBase (
    input clk,
    input reset,

    // imem
    input                                  memreq_val,
    output                                 memreq_rdy,
    input  [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] memreq_msg,

    output                               memresp_val,
    input                                memresp_rdy,
    output [`VC_MEM_RESP_MSG_SZ(32)-1:0] memresp_msg,

    //cache
    output                                 cachereq_val,
    input                                  cachereq_rdy,
    output [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] cachereq_msg,

    input                                cacheresp_val,
    output                               cacheresp_rdy,
    input  [`VC_MEM_RESP_MSG_SZ(32)-1:0] cacheresp_msg,

    // flush
    input  flush,
    output reg flush_done
);

    // Parameters
    localparam CACHE_SIZE   = 2048; // 2KB
    localparam BLOCK_SIZE   = 64;   // 64 bytes per block
    localparam NUM_BLOCKS   = CACHE_SIZE / BLOCK_SIZE;
    localparam INDEX_BITS   = $clog2(NUM_BLOCKS);
    localparam OFFSET_BITS  = $clog2(BLOCK_SIZE);
    localparam TAG_BITS     = 32 - INDEX_BITS - OFFSET_BITS;

    // Cache Structures: Replacing reg arrays with RAM modules
    wire [TAG_BITS-1:0] tag_rdata;
    wire [BLOCK_SIZE*8-1:0] data_rdata;

    vc_RAM_1w1r_pf #(
        .DATA_SZ(TAG_BITS),
        .ENTRIES(NUM_BLOCKS),
        .ADDR_SZ(INDEX_BITS)
    ) tag_array (
        .clk(clk),
        .raddr(index),
        .rdata(tag_rdata),
        .wen_p(wen_tag),
        .waddr_p(waddr),
        .wdata_p(tag_wdata)
    );

    vc_RAM_1w1r_pf #(
        .DATA_SZ(BLOCK_SIZE*8),
        .ENTRIES(NUM_BLOCKS),
        .ADDR_SZ(INDEX_BITS)
    ) data_array (
        .clk(clk),
        .raddr(index),
        .rdata(data_rdata),
        .wen_p(wen_data),
        .waddr_p(waddr),
        .wdata_p(data_wdata)
    );
    reg [NUM_BLOCKS-1:0] valid_array;
    reg [NUM_BLOCKS-1:0] dirty_array;

    reg [`VC_MEM_RESP_MSG_SZ(32)-1:0] memresp_msg_reg;
    reg [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] cachereq_msg_reg;
    assign memresp_msg = memresp_msg_reg;
    assign cachereq_msg = cachereq_msg_reg;

    // State Machine States
    localparam IDLE = 2'b00;
    localparam MISS = 2'b01;
    localparam WRITEBACK = 2'b10;
    localparam FLUSH = 2'b11;
    reg [1:0] state;

    // Internal signals
    wire [TAG_BITS-1:0] tag;
    wire [INDEX_BITS-1:0] index;
    wire [OFFSET_BITS-1:0] offset;
    reg wen_tag, wen_data;                    // 寫入使能信號
    reg [INDEX_BITS-1:0] waddr;               // 寫入地址
    reg [TAG_BITS-1:0] tag_wdata;             // 寫入標籤數據
    reg [BLOCK_SIZE*8-1:0] data_wdata;        // 寫入數據


    wire hit;

    // Parse memory request
    assign {tag, index, offset} = memreq_msg[`VC_MEM_REQ_MSG_ADDR_FIELD(32,32)];

    // Determine hit or miss
    assign hit = (valid_array[index] && tag_rdata == tag);

    // Outputs
    assign memreq_rdy = (state == IDLE);
    assign memresp_val = (state == IDLE && hit && memreq_val);
    assign cachereq_val = (state == MISS || state == WRITEBACK);
    assign cacheresp_rdy = (state == MISS || state == WRITEBACK);
                    
    integer i;

    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            flush_done <= 0;
            valid_array <= 0;
            dirty_array <= 0;
            memresp_msg_reg <= 'b0;
            cachereq_msg_reg <= 'b0;
            wen_data <= 0; // 初始化寫入使能
            wen_tag <= 0;  // 初始化寫入使能
        end else begin
            wen_data <= 0; // 每個時鐘週期將寫入使能復位
            wen_tag <= 0;
            case (state)
                IDLE: begin
                    if (flush) begin
                        state <= FLUSH;
                        flush_done <= 0;
                    end else if (memreq_val) begin
                        if (hit) begin
                            // Cache hit: respond immediately
                            memresp_msg_reg <= data_rdata[offset*8 +: 32]; // 使用 RAM 模組的 rdata 輸出
                        end else begin
                            // Cache miss
                            state <= (dirty_array[index]) ? WRITEBACK : MISS;
                            cachereq_msg_reg <= memreq_msg;
                        end
                    end
                end

                MISS: begin
                    if (cacheresp_val) begin
                        // 啟用數據寫入
                        wen_data <= 1;
                        waddr <= index;
                        data_wdata <= cacheresp_msg; // 將響應的數據寫入數據陣列

                        // 啟用標籤寫入
                        wen_tag <= 1;
                        tag_wdata <= tag;           // 將當前標籤寫入標籤陣列

                        // 更新有效位和狀態
                        valid_array[index] <= 1;
                        dirty_array[index] <= 0;
                        state <= IDLE;
                    end
                end

                WRITEBACK: begin
                    if (cacheresp_val) begin
                        // Write back dirty block
                        dirty_array[index] <= 0;
                        state <= MISS;
                    end
                end

                FLUSH: begin
                    // Write back all dirty blocks
                    for (i = 0; i < NUM_BLOCKS; i = i + 1) begin
                        if (dirty_array[i]) begin
                            dirty_array[i] <= 0;
                        end
                    end
                    flush_done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule

`endif /* RISCV_CACHE_BASE_V */
