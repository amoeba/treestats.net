# frozen_string_literal: true

require "socket"
require "openssl"
require "net/http"

# One real TLS connection per fixture, bound only to an ephemeral loopback port.
# The client trusts this fixture's CA, but still verifies the server hostname.
class MockHTTPSServer
  class DeadlineExceeded < StandardError; end

  attr_reader :requests

  def self.identity
    @identity ||= begin
      root_key = OpenSSL::PKey::RSA.new(2048)
      root = OpenSSL::X509::Certificate.new
      root.version = 2
      root.serial = 1
      root.subject = root.issuer = OpenSSL::X509::Name.parse("/CN=TreeStats test CA")
      root.public_key = root_key.public_key
      root.not_before = Time.now - 3600
      root.not_after = Time.now + 86_400
      extensions = OpenSSL::X509::ExtensionFactory.new
      extensions.subject_certificate = extensions.issuer_certificate = root
      root.add_extension(extensions.create_extension("basicConstraints", "CA:TRUE", true))
      root.add_extension(extensions.create_extension("keyUsage", "keyCertSign,cRLSign", true))
      root.sign(root_key, OpenSSL::Digest::SHA256.new)

      key = OpenSSL::PKey::RSA.new(2048)
      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      cert.serial = 2
      cert.subject = OpenSSL::X509::Name.parse("/CN=localhost")
      cert.issuer = root.subject
      cert.public_key = key.public_key
      cert.not_before = root.not_before
      cert.not_after = root.not_after
      extensions.subject_certificate = cert
      extensions.issuer_certificate = root
      cert.add_extension(extensions.create_extension("basicConstraints", "CA:FALSE", true))
      cert.add_extension(extensions.create_extension("keyUsage", "digitalSignature,keyEncipherment", true))
      cert.add_extension(extensions.create_extension("extendedKeyUsage", "serverAuth"))
      cert.add_extension(extensions.create_extension("subjectAltName", "DNS:localhost"))
      cert.sign(root_key, OpenSSL::Digest::SHA256.new)
      [root, cert, key]
    end
  end

  def self.open(handler)
    fixture = new(&handler)
    yield fixture
  ensure
    fixture&.close
  end

  def initialize(&handler)
    root, cert, key = self.class.identity
    @store = OpenSSL::X509::Store.new
    @store.add_cert(root)
    context = OpenSSL::SSL::SSLContext.new
    context.cert = cert
    context.key = key
    @listener = TCPServer.new("127.0.0.1", 0)
    @port = @listener.addr[1]
    @requests = []
    @thread = Thread.new do
      begin
        @tcp = @listener.accept
        @socket = OpenSSL::SSL::SSLSocket.new(@tcp, context)
        @socket.sync_close = true
        begin
          @socket.accept
        rescue OpenSSL::SSL::SSLError
          # A client rejecting our CA/hostname can abort the handshake.
          next
        end
        request = @socket.gets
        next unless request
        @requests << request
        while (header = @socket.gets) && header != "\r\n"
        end
        handler.call(@socket)
      rescue => error
        @error = error unless @closing && (error.is_a?(IOError) || error.is_a?(SystemCallError))
      ensure
        @socket&.close
        @tcp&.close
      end
    end
  end

  def url(host: "localhost")
    "https://#{host}:#{@port}/population.json"
  end

  def http_factory(trusted: true)
    lambda do |host, port, proxy|
      http = Net::HTTP.new(host, port, proxy)
      http.ipaddr = "127.0.0.1"
      http.cert_store = @store if trusted
      http
    end
  end

  def finish
    raise DeadlineExceeded, "mock HTTPS server did not observe client disconnect" unless @thread.join(3)
    raise @error if @error
  end

  def close
    @closing = true
    @listener.close
    @tcp&.close
    unless @thread.join(3)
      @thread.kill.join
      raise DeadlineExceeded, "mock HTTPS server leaked a thread"
    end
    raise @error if @error
  end
end
