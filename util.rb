module XPC
  module Util
    def self.double_sha256(raw_byte)
      OpenSSL::Digest::SHA256.digest(OpenSSL::Digest::SHA256.digest(raw_byte)).unpack("C*").reverse.pack("C*")
    end
    def self.ripemd160(raw_byte)
      OpenSSL::Digest::RIPEMD160.digest(raw_byte).unpack("C*").pack("C*")
    end
    def self.hex2raw(hex)
      [hex].pack("H*")
    end

    def self.raw2hex(raw)
      raw.unpack("H*")[0]
    end

    def self.bits2tgt(bits)
      bits = bits.to_i(16) if bits.is_a?(String)
      mp = ((bits >> 24) & 0xFF) - 3
      bt = bits & 0xFFFFFF
      bt * (2 ** (8 * mp))
    end

    def self.bits2df(bits)
      bits2tgt(0x1d00ffff) * 1.0 / bits2tgt(bits)
    end
  end
end
