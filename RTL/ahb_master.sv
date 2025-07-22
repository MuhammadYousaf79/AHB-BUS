module ahb_master #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32

) (

    // Global Signals
    input logic Hclk,
    input logic Hresetn,

    // Processor input signals
    input logic [DATA_WIDTH-1:0] Pwdata,
    input logic [DATA_WIDTH-1:0] Paddr,
    input logic [2:0] Psize,
    input logic [DATA_WIDTH/8-1:0] Pstrb,
    input logic Pload,
    input logic Pstore,
    input logic [2:0] Pburst,
    input logic [1:0] Ptrans,

    // Slave Response
    input logic Hready,
    input logic [1:0] Hresp,
    input logic [DATA_WIDTH-1:0] HRdata,

    // Arbiter Signals
    input logic Hgrant,

    // Address Signals
    output logic [ADDR_WIDTH-1:0] Haddr,

    // Control Signals
    output logic HWrite,
    output logic [2:0] Hburst,
    output logic [2:0] Hsize,
    output logic [1:0] Htrans,
    output logic [DATA_WIDTH/8-1:0] Hstrb,
    output logic Hreq,
    output logic [DATA_WIDTH-1:0] Prdata,

    // Write Bus Data
    output logic [DATA_WIDTH-1:0] HWdata

);

logic HWrite_next;
logic [DATA_WIDTH-1:0] HWdata_next;
logic [DATA_WIDTH-1:0] Prdata_next;

logic addr_put;
logic data_put;

typedef enum logic [1:0] {
    IDLE,
    REQUEST_ADDR_PHASE,
    DATA_PHASE
} state_t;

state_t C_state, N_state;

always_ff @(posedge Hclk or negedge Hresetn) begin

    if (!Hresetn) begin
        C_state <= IDLE;
        HWrite <= 1'b0;
        HWdata <= 'b0;
        Prdata <= 'b0;
    end else begin
        C_state <= N_state;
        HWrite <= HWrite_next;
        HWdata <= HWdata_next;
        Prdata <= Prdata_next;
    end
end

always_comb begin
    HWrite_next = 1'b0;
    HWdata_next = 'b0;
    Prdata_next = 'b0;

    Haddr = '0;
    Hsize = '0;
    Hburst = '0;
    Htrans = '0;
    Hstrb = '0;

    if (addr_put) begin
        Haddr = Paddr;
        Hsize = Psize;
        Hburst = Pburst;
        Htrans = Ptrans;
        Hstrb = Pstrb;
        HWrite_next = Pstore;
    end
    if (data_put) begin
        if (HWrite) HWdata_next = Pwdata;
        else Prdata_next = HRdata;
    end
end

always_comb begin
    // Default values
    N_state = C_state;
    addr_put = 1'b0;
    data_put = 1'b0;

    case (C_state)

        IDLE: begin
            Hreq = 1'b0; // Deassert request
            if (Pload || Pstore)  begin
                Hreq = 1'b1; // Assert request to the arbiter
                N_state = REQUEST_ADDR_PHASE;
            end
        end

        REQUEST_ADDR_PHASE: begin
            Hreq = 1'b1; // Keep assert request after entering REQUEST state
            if (Hgrant && Hready) begin
                N_state = DATA_PHASE;
                addr_put = 1'b1; // Prepare to send address
                Hreq = 1'b0; // Deassert request once granted
            end
        end
        DATA_PHASE: begin
            if (Hgrant && Hready) begin
                data_put = 1'b1;
                addr_put = 1'b1;
                N_state = IDLE;
            end
        end

    endcase

end

endmodule