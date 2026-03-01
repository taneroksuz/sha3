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

  reg_type init_reg = '{iter: 0, state: IDLE, ready: 0};

  reg_type r, rin;
  reg_type v;

  logic [63:0] C[0:4];
  logic [63:0] D_[0:4];
  logic [63:0] B[0:4][0:4];

  function [63:0] ROT64;
    input logic [63:0] x;
    input logic [5:0] n;
    begin
      ROT64 = (n == 0) ? x : ((x << n) | (x >> (64 - n)));
    end
  endfunction

  function automatic void THETA;
    inout logic [63:0] S[0:4][0:4];
    inout logic [63:0] Cv[0:4];
    inout logic [63:0] Dv[0:4];
    begin

      Cv[0] = S[0][0] ^ S[0][1] ^ S[0][2] ^ S[0][3] ^ S[0][4];
      Cv[1] = S[1][0] ^ S[1][1] ^ S[1][2] ^ S[1][3] ^ S[1][4];
      Cv[2] = S[2][0] ^ S[2][1] ^ S[2][2] ^ S[2][3] ^ S[2][4];
      Cv[3] = S[3][0] ^ S[3][1] ^ S[3][2] ^ S[3][3] ^ S[3][4];
      Cv[4] = S[4][0] ^ S[4][1] ^ S[4][2] ^ S[4][3] ^ S[4][4];

      Dv[0] = Cv[4] ^ ROT64(Cv[1], 1);
      Dv[1] = Cv[0] ^ ROT64(Cv[2], 1);
      Dv[2] = Cv[1] ^ ROT64(Cv[3], 1);
      Dv[3] = Cv[2] ^ ROT64(Cv[4], 1);
      Dv[4] = Cv[3] ^ ROT64(Cv[0], 1);

      S[0][0] ^= Dv[0];
      S[0][1] ^= Dv[0];
      S[0][2] ^= Dv[0];
      S[0][3] ^= Dv[0];
      S[0][4] ^= Dv[0];
      S[1][0] ^= Dv[1];
      S[1][1] ^= Dv[1];
      S[1][2] ^= Dv[1];
      S[1][3] ^= Dv[1];
      S[1][4] ^= Dv[1];
      S[2][0] ^= Dv[2];
      S[2][1] ^= Dv[2];
      S[2][2] ^= Dv[2];
      S[2][3] ^= Dv[2];
      S[2][4] ^= Dv[2];
      S[3][0] ^= Dv[3];
      S[3][1] ^= Dv[3];
      S[3][2] ^= Dv[3];
      S[3][3] ^= Dv[3];
      S[3][4] ^= Dv[3];
      S[4][0] ^= Dv[4];
      S[4][1] ^= Dv[4];
      S[4][2] ^= Dv[4];
      S[4][3] ^= Dv[4];
      S[4][4] ^= Dv[4];
    end
  endfunction

  function automatic void RHO_PI;
    input logic [63:0] S[0:4][0:4];
    output logic [63:0] Bv[0:4][0:4];
    begin

      Bv[0][0] = ROT64(S[0][0], 0);
      Bv[0][2] = ROT64(S[1][0], 1);
      Bv[0][4] = ROT64(S[2][0], 62);
      Bv[0][1] = ROT64(S[3][0], 28);
      Bv[0][3] = ROT64(S[4][0], 27);

      Bv[1][3] = ROT64(S[0][1], 36);
      Bv[1][0] = ROT64(S[1][1], 44);
      Bv[1][2] = ROT64(S[2][1], 6);
      Bv[1][4] = ROT64(S[3][1], 55);
      Bv[1][1] = ROT64(S[4][1], 20);

      Bv[2][1] = ROT64(S[0][2], 3);
      Bv[2][3] = ROT64(S[1][2], 10);
      Bv[2][0] = ROT64(S[2][2], 43);
      Bv[2][2] = ROT64(S[3][2], 25);
      Bv[2][4] = ROT64(S[4][2], 39);

      Bv[3][4] = ROT64(S[0][3], 41);
      Bv[3][1] = ROT64(S[1][3], 45);
      Bv[3][3] = ROT64(S[2][3], 15);
      Bv[3][0] = ROT64(S[3][3], 21);
      Bv[3][2] = ROT64(S[4][3], 8);

      Bv[4][2] = ROT64(S[0][4], 18);
      Bv[4][4] = ROT64(S[1][4], 2);
      Bv[4][1] = ROT64(S[2][4], 61);
      Bv[4][3] = ROT64(S[3][4], 56);
      Bv[4][0] = ROT64(S[4][4], 14);
    end
  endfunction

  function automatic void CHI;
    input logic [63:0] Bv[0:4][0:4];
    output logic [63:0] S[0:4][0:4];
    begin

      S[0][0] = Bv[0][0] ^ (~Bv[1][0] & Bv[2][0]);
      S[1][0] = Bv[1][0] ^ (~Bv[2][0] & Bv[3][0]);
      S[2][0] = Bv[2][0] ^ (~Bv[3][0] & Bv[4][0]);
      S[3][0] = Bv[3][0] ^ (~Bv[4][0] & Bv[0][0]);
      S[4][0] = Bv[4][0] ^ (~Bv[0][0] & Bv[1][0]);

      S[0][1] = Bv[0][1] ^ (~Bv[1][1] & Bv[2][1]);
      S[1][1] = Bv[1][1] ^ (~Bv[2][1] & Bv[3][1]);
      S[2][1] = Bv[2][1] ^ (~Bv[3][1] & Bv[4][1]);
      S[3][1] = Bv[3][1] ^ (~Bv[4][1] & Bv[0][1]);
      S[4][1] = Bv[4][1] ^ (~Bv[0][1] & Bv[1][1]);

      S[0][2] = Bv[0][2] ^ (~Bv[1][2] & Bv[2][2]);
      S[1][2] = Bv[1][2] ^ (~Bv[2][2] & Bv[3][2]);
      S[2][2] = Bv[2][2] ^ (~Bv[3][2] & Bv[4][2]);
      S[3][2] = Bv[3][2] ^ (~Bv[4][2] & Bv[0][2]);
      S[4][2] = Bv[4][2] ^ (~Bv[0][2] & Bv[1][2]);

      S[0][3] = Bv[0][3] ^ (~Bv[1][3] & Bv[2][3]);
      S[1][3] = Bv[1][3] ^ (~Bv[2][3] & Bv[3][3]);
      S[2][3] = Bv[2][3] ^ (~Bv[3][3] & Bv[4][3]);
      S[3][3] = Bv[3][3] ^ (~Bv[4][3] & Bv[0][3]);
      S[4][3] = Bv[4][3] ^ (~Bv[0][3] & Bv[1][3]);

      S[0][4] = Bv[0][4] ^ (~Bv[1][4] & Bv[2][4]);
      S[1][4] = Bv[1][4] ^ (~Bv[2][4] & Bv[3][4]);
      S[2][4] = Bv[2][4] ^ (~Bv[3][4] & Bv[4][4]);
      S[3][4] = Bv[3][4] ^ (~Bv[4][4] & Bv[0][4]);
      S[4][4] = Bv[4][4] ^ (~Bv[0][4] & Bv[1][4]);
    end
  endfunction

  function automatic void IOTA;
    inout logic [63:0] S[0:4][0:4];
    input logic [63:0] rc;
    begin
      S[0][0] ^= rc;
    end
  endfunction

  function automatic void ABSORB;
    inout logic [63:0] S[0:4][0:4];
    input logic [1599:0] data;
    begin
      S[0][0] ^= data[0+:64];
      S[1][0] ^= data[64+:64];
      S[2][0] ^= data[128+:64];
      S[3][0] ^= data[192+:64];
      S[4][0] ^= data[256+:64];
      S[0][1] ^= data[320+:64];
      S[1][1] ^= data[384+:64];
      S[2][1] ^= data[448+:64];
      S[3][1] ^= data[512+:64];
      S[4][1] ^= data[576+:64];
      S[0][2] ^= data[640+:64];
      S[1][2] ^= data[704+:64];
      S[2][2] ^= data[768+:64];
      S[3][2] ^= data[832+:64];
      S[4][2] ^= data[896+:64];
      S[0][3] ^= data[960+:64];
      S[1][3] ^= data[1024+:64];
      S[2][3] ^= data[1088+:64];
      S[3][3] ^= data[1152+:64];
      S[4][3] ^= data[1216+:64];
      S[0][4] ^= data[1280+:64];
      S[1][4] ^= data[1344+:64];
      S[2][4] ^= data[1408+:64];
      S[3][4] ^= data[1472+:64];
      S[4][4] ^= data[1536+:64];
    end
  endfunction

  function automatic void SQUEEZE;
    input logic [63:0] S[0:4][0:4];
    output logic [63:0] Hv[0:7];
    begin
      Hv[0] = S[0][0];
      Hv[1] = S[1][0];
      Hv[2] = S[2][0];
      Hv[3] = S[3][0];
      Hv[4] = S[4][0];
      Hv[5] = S[0][1];
      Hv[6] = S[1][1];
      Hv[7] = S[2][1];
    end
  endfunction

  logic [1599:0] data_padded;
  logic [63:0] H_wide[0:7];

  always_comb begin

    v   = r;

    S_d = S_q;
    H_d = H_q;

    for (int x = 0; x < 5; x++) begin
      C[x]  = 64'h0;
      D_[x] = 64'h0;
      for (int y = 0; y < 5; y++) B[x][y] = 64'h0;
    end

    data_padded                = 1600'h0;
    data_padded[RATE_BITS-1:0] = Data;

    for (int i = 0; i < 8; i++) H_wide[i] = 64'h0;

    if (r.state == IDLE) begin

      if (Enable == 1) begin

        if (Index == 1) begin
          for (int x = 0; x < 5; x++) for (int y = 0; y < 5; y++) S_d[x][y] = 64'h0;
        end

        ABSORB(S_d, data_padded);

        v.iter  = 0;
        v.state = INIT;

      end

      v.ready = 0;

    end else if (r.state == INIT) begin

      THETA(S_d, C, D_);
      RHO_PI(S_d, B);
      CHI(B, S_d);
      IOTA(S_d, RC[r.iter]);

      if (r.iter == 23) begin

        SQUEEZE(S_d, H_wide);
        for (int i = 0; i < DIGEST_LANES; i++) H_d[i] = H_wide[i];

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
