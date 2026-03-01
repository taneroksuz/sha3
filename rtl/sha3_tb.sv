`timescale 1ns / 1ps

module sha3_tb;

  localparam CLK_PERIOD = 10;
  localparam WATCHDOG = 1_000_000;

  logic clk = 0;
  always #(CLK_PERIOD / 2) clk = ~clk;

  logic          rst;

  logic [1151:0] sha3_224_data;
  logic [ 143:0] sha3_224_index;
  logic          sha3_224_enable;
  logic [ 223:0] sha3_224_hash;
  logic          sha3_224_ready;

  logic [1087:0] sha3_256_data;
  logic [ 135:0] sha3_256_index;
  logic          sha3_256_enable;
  logic [ 255:0] sha3_256_hash;
  logic          sha3_256_ready;

  logic [ 831:0] sha3_384_data;
  logic [ 103:0] sha3_384_index;
  logic          sha3_384_enable;
  logic [ 383:0] sha3_384_hash;
  logic          sha3_384_ready;

  logic [ 575:0] sha3_512_data;
  logic [  71:0] sha3_512_index;
  logic          sha3_512_enable;
  logic [ 511:0] sha3_512_hash;
  logic          sha3_512_ready;

  sha3 #(
      .VARIANT(224)
  ) u_sha3_224 (
      .rst   (rst),
      .clk   (clk),
      .Data  (sha3_224_data),
      .Index (sha3_224_index),
      .Enable(sha3_224_enable),
      .Hash  (sha3_224_hash),
      .Ready (sha3_224_ready)
  );

  sha3 #(
      .VARIANT(256)
  ) u_sha3_256 (
      .rst   (rst),
      .clk   (clk),
      .Data  (sha3_256_data),
      .Index (sha3_256_index),
      .Enable(sha3_256_enable),
      .Hash  (sha3_256_hash),
      .Ready (sha3_256_ready)
  );

  sha3 #(
      .VARIANT(384)
  ) u_sha3_384 (
      .rst   (rst),
      .clk   (clk),
      .Data  (sha3_384_data),
      .Index (sha3_384_index),
      .Enable(sha3_384_enable),
      .Hash  (sha3_384_hash),
      .Ready (sha3_384_ready)
  );

  sha3 #(
      .VARIANT(512)
  ) u_sha3_512 (
      .rst   (rst),
      .clk   (clk),
      .Data  (sha3_512_data),
      .Index (sha3_512_index),
      .Enable(sha3_512_enable),
      .Hash  (sha3_512_hash),
      .Ready (sha3_512_ready)
  );

  integer errors;
  integer pt_bytes;
  integer sha3_224_padded, sha3_256_padded, sha3_384_padded, sha3_512_padded;
  integer sha3_224_blocks, sha3_256_blocks, sha3_384_blocks, sha3_512_blocks;

  reg [7:0] sha3_224_exp[];
  reg [7:0] sha3_256_exp[];
  reg [7:0] sha3_384_exp[];
  reg [7:0] sha3_512_exp[];

  reg [7:0] sha3_224_res[];
  reg [7:0] sha3_256_res[];
  reg [7:0] sha3_384_res[];
  reg [7:0] sha3_512_res[];

  reg [7:0] raw         [];
  reg [7:0] data224     [];
  reg [7:0] data256     [];
  reg [7:0] data384     [];
  reg [7:0] data512     [];

  function automatic reg [7:0] hex_char(input reg [7:0] c);
    if (c <= 8'h39 && c >= 8'h30) return c - 8'h30;
    if (c <= 8'h66 && c >= 8'h61) return c - 8'h57;
    if (c <= 8'h46 && c >= 8'h41) return c - 8'h37;
    return 8'hFF;
  endfunction

  task automatic get_bytes(input string path, ref reg [7:0] out[], input integer num);
    integer f;
    reg [7:0] c, hv, hi;
    integer nv;
    out = new[num];
    nv  = 0;
    hi  = 0;
    f   = $fopen(path, "r");
    while (!$feof(
        f
    ) && nv < num * 2) begin
      $fread(c, f);
      hv = hex_char(c);
      if (hv != 8'hFF) begin
        if (nv[0] == 0) hi = hv;
        else out[nv/2] = (hi << 4) | hv;
        nv++;
      end
    end
    $fclose(f);
  endtask

  task automatic pad_sha3_224(input integer msg_len, input integer padded_len);
    data224 = new[padded_len];
    for (int i = 0; i < msg_len; i = i + 1) data224[i] = raw[i];
    for (int i = msg_len; i < padded_len; i = i + 1) data224[i] = 8'h00;
    data224[msg_len]      = data224[msg_len] ^ 8'h06;
    data224[padded_len-1] = data224[padded_len-1] ^ 8'h80;
  endtask

  task automatic pad_sha3_256(input integer msg_len, input integer padded_len);
    data256 = new[padded_len];
    for (int i = 0; i < msg_len; i = i + 1) data256[i] = raw[i];
    for (int i = msg_len; i < padded_len; i = i + 1) data256[i] = 8'h00;
    data256[msg_len]      = data256[msg_len] ^ 8'h06;
    data256[padded_len-1] = data256[padded_len-1] ^ 8'h80;
  endtask

  task automatic pad_sha3_384(input integer msg_len, input integer padded_len);
    data384 = new[padded_len];
    for (int i = 0; i < msg_len; i = i + 1) data384[i] = raw[i];
    for (int i = msg_len; i < padded_len; i = i + 1) data384[i] = 8'h00;
    data384[msg_len]      = data384[msg_len] ^ 8'h06;
    data384[padded_len-1] = data384[padded_len-1] ^ 8'h80;
  endtask

  task automatic pad_sha3_512(input integer msg_len, input integer padded_len);
    data512 = new[padded_len];
    for (int i = 0; i < msg_len; i = i + 1) data512[i] = raw[i];
    for (int i = msg_len; i < padded_len; i = i + 1) data512[i] = 8'h00;
    data512[msg_len]      = data512[msg_len] ^ 8'h06;
    data512[padded_len-1] = data512[padded_len-1] ^ 8'h80;
  endtask

  task automatic compare28(input string label);
    reg match;
    match = 1;
    for (int i = 0; i < 28; i = i + 1)
      if (sha3_224_res[i] !== sha3_224_exp[i]) begin
        match = 0;
        break;
      end
    $write("%s HASH: ", label);
    for (int i = 0; i < 28; i = i + 1) $write("%02h", sha3_224_res[i]);
    $write("\n%s ORIG: ", label);
    for (int i = 0; i < 28; i = i + 1) $write("%02h", sha3_224_exp[i]);
    $write("\n");
    if (match) $display("%s TEST SUCCEEDED", label);
    else $display("%s TEST FAILED", label);
    if (!match) errors++;
  endtask

  task automatic compare32(input string label);
    reg match;
    match = 1;
    for (int i = 0; i < 32; i = i + 1)
      if (sha3_256_res[i] !== sha3_256_exp[i]) begin
        match = 0;
        break;
      end
    $write("%s HASH: ", label);
    for (int i = 0; i < 32; i = i + 1) $write("%02h", sha3_256_res[i]);
    $write("\n%s ORIG: ", label);
    for (int i = 0; i < 32; i = i + 1) $write("%02h", sha3_256_exp[i]);
    $write("\n");
    if (match) $display("%s TEST SUCCEEDED", label);
    else $display("%s TEST FAILED", label);
    if (!match) errors++;
  endtask

  task automatic compare48(input string label);
    reg match;
    match = 1;
    for (int i = 0; i < 48; i = i + 1)
      if (sha3_384_res[i] !== sha3_384_exp[i]) begin
        match = 0;
        break;
      end
    $write("%s HASH: ", label);
    for (int i = 0; i < 48; i = i + 1) $write("%02h", sha3_384_res[i]);
    $write("\n%s ORIG: ", label);
    for (int i = 0; i < 48; i = i + 1) $write("%02h", sha3_384_exp[i]);
    $write("\n");
    if (match) $display("%s TEST SUCCEEDED", label);
    else $display("%s TEST FAILED", label);
    if (!match) errors++;
  endtask

  task automatic compare64(input string label);
    reg match;
    match = 1;
    for (int i = 0; i < 64; i = i + 1)
      if (sha3_512_res[i] !== sha3_512_exp[i]) begin
        match = 0;
        break;
      end
    $write("%s HASH: ", label);
    for (int i = 0; i < 64; i = i + 1) $write("%02h", sha3_512_res[i]);
    $write("\n%s ORIG: ", label);
    for (int i = 0; i < 64; i = i + 1) $write("%02h", sha3_512_exp[i]);
    $write("\n");
    if (match) $display("%s TEST SUCCEEDED", label);
    else $display("%s TEST FAILED", label);
    if (!match) errors++;
  endtask

  task automatic feed_sha3_224(input integer blocks);
    integer blk, timeout;
    for (blk = 0; blk < blocks; blk = blk + 1) begin
      @(posedge clk);
      for (int i = 0; i < 18; i = i + 1)
      sha3_224_data[i*64+:64] = {
        data224[blk*144+i*8+7],
        data224[blk*144+i*8+6],
        data224[blk*144+i*8+5],
        data224[blk*144+i*8+4],
        data224[blk*144+i*8+3],
        data224[blk*144+i*8+2],
        data224[blk*144+i*8+1],
        data224[blk*144+i*8+0]
      };
      sha3_224_index  = 144'(blk) + 1;
      sha3_224_enable = 1;
      @(posedge clk);
      sha3_224_enable = 0;
      timeout = 0;
      while (!sha3_224_ready) begin
        @(posedge clk);
        if (++timeout >= WATCHDOG) begin
          $display("[SHA3-224] WATCHDOG timeout at block %0d", blk);
          $finish;
        end
      end
    end
  endtask

  task automatic feed_sha3_256(input integer blocks);
    integer blk, timeout;
    for (blk = 0; blk < blocks; blk = blk + 1) begin
      @(posedge clk);
      for (int i = 0; i < 17; i = i + 1)
      sha3_256_data[i*64+:64] = {
        data256[blk*136+i*8+7],
        data256[blk*136+i*8+6],
        data256[blk*136+i*8+5],
        data256[blk*136+i*8+4],
        data256[blk*136+i*8+3],
        data256[blk*136+i*8+2],
        data256[blk*136+i*8+1],
        data256[blk*136+i*8+0]
      };
      sha3_256_index  = 136'(blk) + 1;
      sha3_256_enable = 1;
      @(posedge clk);
      sha3_256_enable = 0;
      timeout = 0;
      while (!sha3_256_ready) begin
        @(posedge clk);
        if (++timeout >= WATCHDOG) begin
          $display("[SHA3-256] WATCHDOG timeout at block %0d", blk);
          $finish;
        end
      end
    end
  endtask

  task automatic feed_sha3_384(input integer blocks);
    integer blk, timeout;
    for (blk = 0; blk < blocks; blk = blk + 1) begin
      @(posedge clk);
      for (int i = 0; i < 13; i = i + 1)
      sha3_384_data[i*64+:64] = {
        data384[blk*104+i*8+7],
        data384[blk*104+i*8+6],
        data384[blk*104+i*8+5],
        data384[blk*104+i*8+4],
        data384[blk*104+i*8+3],
        data384[blk*104+i*8+2],
        data384[blk*104+i*8+1],
        data384[blk*104+i*8+0]
      };
      sha3_384_index  = 104'(blk) + 1;
      sha3_384_enable = 1;
      @(posedge clk);
      sha3_384_enable = 0;
      timeout = 0;
      while (!sha3_384_ready) begin
        @(posedge clk);
        if (++timeout >= WATCHDOG) begin
          $display("[SHA3-384] WATCHDOG timeout at block %0d", blk);
          $finish;
        end
      end
    end
  endtask

  task automatic feed_sha3_512(input integer blocks);
    integer blk, timeout;
    for (blk = 0; blk < blocks; blk = blk + 1) begin
      @(posedge clk);
      for (int i = 0; i < 9; i = i + 1)
      sha3_512_data[i*64+:64] = {
        data512[blk*72+i*8+7],
        data512[blk*72+i*8+6],
        data512[blk*72+i*8+5],
        data512[blk*72+i*8+4],
        data512[blk*72+i*8+3],
        data512[blk*72+i*8+2],
        data512[blk*72+i*8+1],
        data512[blk*72+i*8+0]
      };
      sha3_512_index  = 72'(blk) + 1;
      sha3_512_enable = 1;
      @(posedge clk);
      sha3_512_enable = 0;
      timeout = 0;
      while (!sha3_512_ready) begin
        @(posedge clk);
        if (++timeout >= WATCHDOG) begin
          $display("[SHA3-512] WATCHDOG timeout at block %0d", blk);
          $finish;
        end
      end
    end
  endtask

  initial begin
    if (!$value$plusargs("PLAINTEXT_BYTES=%d", pt_bytes)) begin
      $display("ERROR: +PLAINTEXT_BYTES=<n> required");
      $finish;
    end

    sha3_224_padded = ((pt_bytes + 1 + 143) / 144) * 144;
    sha3_256_padded = ((pt_bytes + 1 + 135) / 136) * 136;
    sha3_384_padded = ((pt_bytes + 1 + 103) / 104) * 104;
    sha3_512_padded = ((pt_bytes + 1 + 71) / 72) * 72;

    sha3_224_blocks = sha3_224_padded / 144;
    sha3_256_blocks = sha3_256_padded / 136;
    sha3_384_blocks = sha3_384_padded / 104;
    sha3_512_blocks = sha3_512_padded / 72;

    get_bytes("plaintext.hex", raw, pt_bytes);

    sha3_224_exp = new[28];
    sha3_256_exp = new[32];
    sha3_384_exp = new[48];
    sha3_512_exp = new[64];

    get_bytes("sha3_224.hex", sha3_224_exp, 28);
    get_bytes("sha3_256.hex", sha3_256_exp, 32);
    get_bytes("sha3_384.hex", sha3_384_exp, 48);
    get_bytes("sha3_512.hex", sha3_512_exp, 64);

    pad_sha3_224(pt_bytes, sha3_224_padded);
    pad_sha3_256(pt_bytes, sha3_256_padded);
    pad_sha3_384(pt_bytes, sha3_384_padded);
    pad_sha3_512(pt_bytes, sha3_512_padded);

    $display(
        "[TB] plaintext: %0d bytes -> SHA3-224 blocks: %0d, SHA3-256 blocks: %0d, SHA3-384 blocks: %0d, SHA3-512 blocks: %0d",
        pt_bytes, sha3_224_blocks, sha3_256_blocks, sha3_384_blocks, sha3_512_blocks);

    errors          = 0;
    sha3_224_enable = 0;
    sha3_256_enable = 0;
    sha3_384_enable = 0;
    sha3_512_enable = 0;
    rst             = 0;
    repeat (4) @(posedge clk);
    rst = 1;
    repeat (2) @(posedge clk);

    sha3_224_res = new[28];
    feed_sha3_224(sha3_224_blocks);
    for (int i = 0; i < 28; i = i + 1) sha3_224_res[i] = sha3_224_hash[i*8+:8];
    compare28("[SHA3-224]");

    sha3_256_res = new[32];
    feed_sha3_256(sha3_256_blocks);
    for (int i = 0; i < 32; i = i + 1) sha3_256_res[i] = sha3_256_hash[i*8+:8];
    compare32("[SHA3-256]");

    sha3_384_res = new[48];
    feed_sha3_384(sha3_384_blocks);
    for (int i = 0; i < 48; i = i + 1) sha3_384_res[i] = sha3_384_hash[i*8+:8];
    compare48("[SHA3-384]");

    sha3_512_res = new[64];
    feed_sha3_512(sha3_512_blocks);
    for (int i = 0; i < 64; i = i + 1) sha3_512_res[i] = sha3_512_hash[i*8+:8];
    compare64("[SHA3-512]");

    if (errors == 0) $display("All tests PASSED.");
    else $display("%0d test(s) FAILED.", errors);

    $finish;
  end

  initial begin
    $dumpfile("sha3_tb.vcd");
    $dumpvars(0, sha3_tb);
  end

endmodule
