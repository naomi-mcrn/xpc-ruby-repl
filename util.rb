module XPC
  module Util
    def self.double_sha256(raw_byte)
      OpenSSL::Digest::SHA256.digest(OpenSSL::Digest::SHA256.digest(raw_byte)).unpack("C*").reverse.pack("C*")
    end
    def self.hex2raw(hex)
      [hex].pack("H*")
    end

    def self.raw2hex(raw)
      raw.unpack("H*")[0]
    end
  end
end
