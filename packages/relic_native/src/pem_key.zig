//! Decrypts a password-protected private key PEM into the plain PEM
//! tls.zig reads. Two forms, the ones OpenSSL writes: PKCS#8
//! `ENCRYPTED PRIVATE KEY` under PBES2 with PBKDF2 and AES-128-CBC or
//! AES-256-CBC, from `openssl pkcs8` and `openssl genpkey`, and a key
//! block behind `Proc-Type` and `DEK-Info` headers under the same ciphers,
//! from `openssl ec` and `openssl rsa` with a cipher flag.
const std = @import("std");
const der = std.crypto.Certificate.der;
const Element = der.Element;

pub const Error = error{
    /// The key is encrypted and the password is missing or wrong, or a
    /// password came with a key in the clear.
    Password,
    /// The key is encrypted in a form this file does not read.
    Unsupported,
    OutOfMemory,
};

/// The plain PEM for an encrypted `pem`, which the caller zeroes and
/// frees, or null when `pem` is not encrypted. A password for a key in
/// the clear is refused as a misconfiguration.
pub fn decrypt(gpa: std.mem.Allocator, pem: []const u8, password: ?[]const u8) Error!?[]u8 {
    const block = pemBlock(pem) orelse return null;
    if (std.mem.eql(u8, block.label, "ENCRYPTED PRIVATE KEY")) {
        return try pkcs8(gpa, block, password);
    }
    if (try dekInfo(block.headers)) |dek| {
        return try openssl(gpa, block, dek, password orelse return error.Password);
    }
    if (password != null) return error.Password;
    return null;
}

const Block = struct {
    label: []const u8,
    /// The `Name: value` lines before the body, or "".
    headers: []const u8,
    /// The base64 text.
    body: []const u8,
};

/// The first private key block in `pem`, past any certificate, parameters
/// or malformed block before it, as tls.zig finds its key.
fn pemBlock(pem: []const u8) ?Block {
    const begin = "-----BEGIN ";
    const end = "-----END ";
    const dashes = "-----";
    var from: usize = 0;
    while (std.mem.indexOfPos(u8, pem, from, begin)) |begin_at| {
        const label_start = begin_at + begin.len;
        from = label_start;
        const label_end = std.mem.indexOfPos(u8, pem, label_start, dashes) orelse return null;
        const label = pem[label_start..label_end];
        if (std.mem.indexOfScalar(u8, label, '\n') != null) continue;
        const content_start = label_end + dashes.len;
        const end_at = std.mem.indexOfPos(u8, pem, content_start, end) orelse return null;
        if (!std.mem.startsWith(u8, pem[end_at + end.len ..], label)) continue;
        from = end_at + end.len;
        if (!std.mem.endsWith(u8, label, "PRIVATE KEY")) continue;
        const inner = pem[content_start..end_at];
        // Headers, when there are any, end at the first blank line.
        const blank = std.mem.indexOf(u8, inner, "\n\n") orelse std.mem.indexOf(u8, inner, "\r\n\r\n");
        if (blank) |at| {
            const headers = inner[0..at];
            if (std.mem.indexOfScalar(u8, headers, ':') != null) {
                return .{ .label = label, .headers = headers, .body = inner[at..] };
            }
        }
        return .{ .label = label, .headers = "", .body = inner };
    }
    return null;
}

const base64 = std.base64.standard.decoderWithIgnore(" \t\r\n");

/// `body` decoded, owned by the caller.
fn decodeBase64(gpa: std.mem.Allocator, body: []const u8) Error![]u8 {
    const buf = try gpa.alloc(u8, base64.calcSizeUpperBound(body.len));
    errdefer gpa.free(buf);
    const n = base64.decode(buf, body) catch return error.Unsupported;
    return gpa.realloc(buf, n) catch return error.OutOfMemory;
}

const Cipher = enum {
    aes128,
    aes256,

    fn keyLength(cipher: Cipher) usize {
        return switch (cipher) {
            .aes128 => 16,
            .aes256 => 32,
        };
    }
};

const Prf = enum {
    sha1,
    sha224,
    sha256,
    sha384,
    sha512,

    fn Hmac(comptime prf: Prf) type {
        const hmac = std.crypto.auth.hmac;
        return switch (prf) {
            .sha1 => hmac.HmacSha1,
            .sha224 => hmac.sha2.HmacSha224,
            .sha256 => hmac.sha2.HmacSha256,
            .sha384 => hmac.sha2.HmacSha384,
            .sha512 => hmac.sha2.HmacSha512,
        };
    }
};

const oid_pbes2 = [_]u8{ 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x05, 0x0d };
const oid_pbkdf2 = [_]u8{ 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x05, 0x0c };

/// 1.2.840.113549.2.N, hmacWithSHA1 through hmacWithSHA512.
fn prfFromOid(oid: []const u8) ?Prf {
    const arc = [_]u8{ 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x02 };
    if (oid.len != arc.len + 1 or !std.mem.eql(u8, oid[0..arc.len], &arc)) return null;
    return switch (oid[arc.len]) {
        7 => .sha1,
        8 => .sha224,
        9 => .sha256,
        10 => .sha384,
        11 => .sha512,
        else => null,
    };
}

/// 2.16.840.1.101.3.4.1.N, the NIST AES-CBC identifiers.
fn cipherFromOid(oid: []const u8) ?Cipher {
    const arc = [_]u8{ 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x01 };
    if (oid.len != arc.len + 1 or !std.mem.eql(u8, oid[0..arc.len], &arc)) return null;
    return switch (oid[arc.len]) {
        2 => .aes128,
        42 => .aes256,
        else => null,
    };
}

/// The element at `index`, with `tag` when one is given. std's parser
/// trusts its input, so the tag and size bytes, the long-form length
/// bytes and the content are checked to lie within `bytes` first.
fn element(bytes: []const u8, index: usize, tag: ?der.Tag) Error!Element {
    if (index + 2 > bytes.len) return error.Unsupported;
    const size = bytes[index + 1];
    var content_start = index + 2;
    var content_len: usize = size;
    if (size & 0x80 != 0) {
        const len_size = size & 0x7f;
        if (len_size > 4 or content_start + len_size > bytes.len) return error.Unsupported;
        content_len = 0;
        for (bytes[content_start..][0..len_size]) |b| content_len = (content_len << 8) | b;
        content_start += len_size;
    }
    if (content_start + content_len > bytes.len) return error.Unsupported;
    const e = Element.parse(bytes, @intCast(index)) catch return error.Unsupported;
    if (tag) |t| if (e.identifier.tag != t) return error.Unsupported;
    return e;
}

fn content(bytes: []u8, e: Element) []u8 {
    return bytes[e.slice.start..e.slice.end];
}

/// A DER INTEGER as u32.
fn integer(bytes: []const u8) Error!u32 {
    if (bytes.len == 0 or bytes.len > 5) return error.Unsupported;
    var value: u64 = 0;
    for (bytes) |b| value = (value << 8) | b;
    return std.math.cast(u32, value) orelse error.Unsupported;
}

const Pbes2 = struct {
    salt: []const u8,
    iterations: u32,
    prf: Prf,
    cipher: Cipher,
    iv: [16]u8,
    data: []u8,
};

/// Reads an EncryptedPrivateKeyInfo under PBES2 with PBKDF2 and AES-CBC.
fn parsePbes2(bytes: []u8) Error!Pbes2 {
    // SEQUENCE { encryptionAlgorithm AlgorithmIdentifier, encryptedData OCTET STRING }
    const info = try element(bytes, 0, .sequence);
    const algorithm = try element(bytes, info.slice.start, .sequence);
    const algorithm_oid = try element(bytes, algorithm.slice.start, .object_identifier);
    if (!std.mem.eql(u8, content(bytes, algorithm_oid), &oid_pbes2)) return error.Unsupported;
    // PBES2-params ::= SEQUENCE { keyDerivationFunc, encryptionScheme }
    const params = try element(bytes, algorithm_oid.slice.end, .sequence);
    const kdf = try element(bytes, params.slice.start, .sequence);
    const kdf_oid = try element(bytes, kdf.slice.start, .object_identifier);
    if (!std.mem.eql(u8, content(bytes, kdf_oid), &oid_pbkdf2)) return error.Unsupported;
    // PBKDF2-params ::= SEQUENCE { salt OCTET STRING, iterationCount INTEGER,
    //   keyLength INTEGER OPTIONAL, prf AlgorithmIdentifier DEFAULT hmacWithSHA1 }
    const kdf_params = try element(bytes, kdf_oid.slice.end, .sequence);
    const salt = try element(bytes, kdf_params.slice.start, .octetstring);
    const iterations = try element(bytes, salt.slice.end, .integer);
    var prf: Prf = .sha1;
    var next: usize = iterations.slice.end;
    while (next < kdf_params.slice.end) {
        const e = try element(bytes, next, null);
        next = e.slice.end;
        switch (e.identifier.tag) {
            // keyLength, which the cipher fixes anyway.
            .integer => {},
            .sequence => {
                const prf_oid = try element(bytes, e.slice.start, .object_identifier);
                prf = prfFromOid(content(bytes, prf_oid)) orelse return error.Unsupported;
            },
            else => return error.Unsupported,
        }
    }
    const scheme = try element(bytes, kdf.slice.end, .sequence);
    const cipher_oid = try element(bytes, scheme.slice.start, .object_identifier);
    const cipher = cipherFromOid(content(bytes, cipher_oid)) orelse return error.Unsupported;
    const iv = try element(bytes, cipher_oid.slice.end, .octetstring);
    if (iv.slice.end - iv.slice.start != 16) return error.Unsupported;
    const data = try element(bytes, algorithm.slice.end, .octetstring);
    return .{
        .salt = content(bytes, salt),
        .iterations = try integer(content(bytes, iterations)),
        .prf = prf,
        .cipher = cipher,
        .iv = content(bytes, iv)[0..16].*,
        .data = content(bytes, data),
    };
}

/// The scheme is read before the password is required, so a form this
/// file does not read is reported as such with or without one.
fn pkcs8(gpa: std.mem.Allocator, block: Block, password: ?[]const u8) Error![]u8 {
    const buf = try decodeBase64(gpa, block.body);
    defer {
        std.crypto.secureZero(u8, buf);
        gpa.free(buf);
    }
    const scheme = try parsePbes2(buf);
    const given = password orelse return error.Password;
    var key: [32]u8 = undefined;
    defer std.crypto.secureZero(u8, &key);
    const dk = key[0..scheme.cipher.keyLength()];
    switch (scheme.prf) {
        inline else => |prf| std.crypto.pwhash.pbkdf2(dk, given, scheme.salt, scheme.iterations, prf.Hmac()) catch return error.Unsupported,
    }
    const plain = try cbcDecrypt(scheme.cipher, dk, scheme.iv, scheme.data);
    return toPem(gpa, "PRIVATE KEY", plain);
}

const DekInfo = struct {
    cipher: Cipher,
    iv: [16]u8,
};

/// The cipher and IV of OpenSSL's `Proc-Type: 4,ENCRYPTED` headers, or
/// null without them.
fn dekInfo(headers: []const u8) Error!?DekInfo {
    if (std.mem.indexOf(u8, headers, "Proc-Type: 4,ENCRYPTED") == null) return null;
    const name = "DEK-Info: ";
    const at = std.mem.indexOf(u8, headers, name) orelse return error.Unsupported;
    const line_start = at + name.len;
    const line_end = std.mem.indexOfAnyPos(u8, headers, line_start, "\r\n") orelse headers.len;
    const line = headers[line_start..line_end];
    const comma = std.mem.indexOfScalar(u8, line, ',') orelse return error.Unsupported;
    const cipher: Cipher = if (std.mem.eql(u8, line[0..comma], "AES-128-CBC"))
        .aes128
    else if (std.mem.eql(u8, line[0..comma], "AES-256-CBC"))
        .aes256
    else
        return error.Unsupported;
    const hex = line[comma + 1 ..];
    if (hex.len != 32) return error.Unsupported;
    var iv: [16]u8 = undefined;
    _ = std.fmt.hexToBytes(&iv, hex) catch return error.Unsupported;
    return .{ .cipher = cipher, .iv = iv };
}

/// Derives the key as OpenSSL's EVP_BytesToKey does with MD5 and one
/// round: MD5 over the password and the first eight bytes of the IV, then
/// MD5 over that digest, the password and those bytes for the second half
/// of a 256-bit key.
fn openssl(gpa: std.mem.Allocator, block: Block, dek: DekInfo, password: []const u8) Error![]u8 {
    const buf = try decodeBase64(gpa, block.body);
    defer {
        std.crypto.secureZero(u8, buf);
        gpa.free(buf);
    }
    var key: [32]u8 = undefined;
    defer std.crypto.secureZero(u8, &key);
    const salt = dek.iv[0..8];
    var md5 = std.crypto.hash.Md5.init(.{});
    md5.update(password);
    md5.update(salt);
    md5.final(key[0..16]);
    md5 = std.crypto.hash.Md5.init(.{});
    md5.update(key[0..16]);
    md5.update(password);
    md5.update(salt);
    md5.final(key[16..32]);
    const plain = try cbcDecrypt(dek.cipher, key[0..dek.cipher.keyLength()], dek.iv, buf);
    return toPem(gpa, block.label, plain);
}

/// Decrypts `data` in place and returns it without its PKCS#7 padding. A
/// wrong password shows as bad padding, or as something other than one
/// DER SEQUENCE the one time in 256 the padding passes.
fn cbcDecrypt(cipher: Cipher, key: []const u8, iv: [16]u8, data: []u8) Error![]u8 {
    if (data.len == 0 or data.len % 16 != 0) return error.Unsupported;
    switch (cipher) {
        .aes128 => cbc(std.crypto.core.aes.Aes128, key[0..16].*, iv, data),
        .aes256 => cbc(std.crypto.core.aes.Aes256, key[0..32].*, iv, data),
    }
    const pad = data[data.len - 1];
    if (pad == 0 or pad > 16) return error.Password;
    for (data[data.len - pad ..]) |b| if (b != pad) return error.Password;
    const plain = data[0 .. data.len - pad];
    const sequence = element(plain, 0, .sequence) catch return error.Password;
    if (sequence.slice.end != plain.len) return error.Password;
    return plain;
}

fn cbc(comptime Aes: type, key: [Aes.key_bits / 8]u8, iv: [16]u8, data: []u8) void {
    const ctx = Aes.initDec(key);
    var previous = iv;
    var i: usize = 0;
    while (i < data.len) : (i += 16) {
        const block: *[16]u8 = data[i..][0..16];
        const encrypted = block.*;
        var plain: [16]u8 = undefined;
        ctx.decrypt(&plain, &encrypted);
        for (&plain, previous) |*b, p| b.* ^= p;
        block.* = plain;
        previous = encrypted;
    }
}

/// `bytes` as a PEM block with `label`, its base64 on one line.
fn toPem(gpa: std.mem.Allocator, label: []const u8, bytes: []const u8) Error![]u8 {
    const encoder = std.base64.standard.Encoder;
    const encoded = try gpa.alloc(u8, encoder.calcSize(bytes.len));
    defer {
        std.crypto.secureZero(u8, encoded);
        gpa.free(encoded);
    }
    _ = encoder.encode(encoded, bytes);
    return std.fmt.allocPrint(gpa, "-----BEGIN {s}-----\n{s}\n-----END {s}-----\n", .{ label, encoded, label });
}
