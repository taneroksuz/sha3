module sha3 #(
    parameter integer VARIANT = 256
) (
    input  logic                  rst,
    input  logic                  clk,
    input  logic [ RATE_BITS-1:0] Data,
    input  logic [INDEX_BITS-1:0] Index,
    input  logic [           0:0] Enable,
    output logic [   VARIANT-1:0] Hash,
    output logic [           0:0] Ready
);
  timeunit 1ns; timeprecision 1ps;

  localparam integer RATE_BITS = 1600 - 2 * VARIANT;
  localparam integer RATE_LANES = RATE_BITS / 64;
  localparam integer DIGEST_LANES = (VARIANT + 63) / 64;
  localparam integer INDEX_BITS = RATE_BITS / 8;

  logic [63:0] S_d[0:4][0:4];
  logic [63:0] S_q[0:4][0:4];
  logic [63:0] H_d[0:DIGEST_LANES-1];
  logic [63:0] H_q[0:DIGEST_LANES-1];

  localparam logic [63:0] RC[0:23] = '{
      64'H0000000000000001,
      64'H0000000000008082,
      64'H800000000000808A,
      64'H8000000080008000,
      64'H000000000000808B,
      64'H0000000080000001,
      64'H8000000080008081,
      64'H8000000000008009,
      64'H000000000000008A,
      64'H0000000000000088,
      64'H0000000080008009,
      64'H000000008000000A,
      64'H000000008000808B,
      64'H800000000000008B,
      64'H8000000000008089,
      64'H8000000000008003,
      64'H8000000000008002,
      64'H8000000000000080,
      64'H000000000000800A,
      64'H800000008000000A,
      64'H8000000080008081,
      64'H8000000000008080,
      64'H0000000080000001,
      64'H8000000080008008
  };

  localparam integer RHO[0:4][0:4] = '{
      '{0, 36, 3, 41, 18},
      '{1, 44, 10, 45, 2},
      '{62, 6, 43, 15, 61},
      '{28, 55, 25, 21, 56},
      '{27, 20, 39, 8, 14}
  };

  localparam IDLE = 2'h0;
  localparam INIT = 2'h1;
  localparam STOP = 2'h2;

  typedef struct packed {
    logic [4:0] iter;
    logic [1:0] state;
    logic [0:0] ready;
  } reg_type;

  reg_type init_reg = '{iter  : 0, state : IDLE, ready : 0};

  reg_type r, rin;
  reg_type v;

  logic [63:0] C   [0:4];
  logic [63:0] D_  [0:4];
  logic [63:0] B   [0:4][0:4];
  logic [63:0] S_pi[0:4][0:4];
  logic [63:0] S_ch[0:4][0:4];

  function [63:0] ROT64;
    input logic [63:0] x;
    input logic [5:0] n;
    begin
      ROT64 = (n == 0) ? x : ((x << n) | (x >> (64 - n)));
    end
  endfunction

  always_comb begin

    v   = r;

    S_d = S_q;
    H_d = H_q;

    for (int x = 0; x < 5; x++) C[x] = 64'h0;
    for (int x = 0; x < 5; x++) D_[x] = 64'h0;
    for (int x = 0; x < 5; x++)
    for (int y = 0; y < 5; y++) begin
      B   [x][y] = 64'h0;
      S_pi[x][y] = 64'h0;
      S_ch[x][y] = 64'h0;
    end

    if (r.state == IDLE) begin

      if (Enable == 1) begin

        if (Index == 1) begin
          for (int x = 0; x < 5; x++) for (int y = 0; y < 5; y++) S_d[x][y] = 64'h0;
        end

        for (int i = 0; i < RATE_LANES; i = i + 1) S_d[i%5][i/5] = S_d[i%5][i/5] ^ Data[i*64+:64];

        v.iter  = 0;
        v.state = INIT;

      end

      v.ready = 0;

    end else if (r.state == INIT) begin

      for (int x = 0; x < 5; x = x + 1)
      C[x] = S_q[x][0] ^ S_q[x][1] ^ S_q[x][2] ^ S_q[x][3] ^ S_q[x][4];

      for (int x = 0; x < 5; x = x + 1) D_[x] = C[(x+4)%5] ^ ROT64(C[(x+1)%5], 1);

      for (int x = 0; x < 5; x = x + 1)
      for (int y = 0; y < 5; y = y + 1) S_d[x][y] = S_q[x][y] ^ D_[x];

      for (int x = 0; x < 5; x = x + 1)
      for (int y = 0; y < 5; y = y + 1) B[y][(2*x+3*y)%5] = ROT64(S_d[x][y], 6'(RHO[x][y]));

      for (int x = 0; x < 5; x = x + 1) for (int y = 0; y < 5; y = y + 1) S_pi[x][y] = B[x][y];

      for (int x = 0; x < 5; x = x + 1)
      for (int y = 0; y < 5; y = y + 1)
      S_ch[x][y] = S_pi[x][y] ^ (~S_pi[(x+1)%5][y] & S_pi[(x+2)%5][y]);

      for (int x = 0; x < 5; x = x + 1) for (int y = 0; y < 5; y = y + 1) S_d[x][y] = S_ch[x][y];

      S_d[0][0] = S_d[0][0] ^ RC[r.iter];

      if (r.iter == 23) begin

        for (int i = 0; i < DIGEST_LANES; i = i + 1) H_d[i] = S_d[i%5][i/5];

        v.iter  = 0;
        v.state = STOP;

      end else begin

        v.iter = r.iter + 1;

      end

      v.ready = 0;

    end else if (r.state == STOP) begin

      v.state = IDLE;
      v.ready = 1;

    end

    for (int i = 0; i < DIGEST_LANES - 1; i = i + 1) Hash[i*64+:64] = H_q[i];
    Hash[VARIANT-1:(DIGEST_LANES-1)*64] = H_q[DIGEST_LANES-1][VARIANT-(DIGEST_LANES-1)*64-1:0];

    Ready = v.ready;

    rin = v;

  end

  always_ff @(posedge clk) begin
    if (rst == 0) begin
      r <= init_reg;
    end else begin
      r <= rin;
    end
  end

  always_ff @(posedge clk) begin
    S_q <= S_d;
    H_q <= H_d;
  end

endmodule
