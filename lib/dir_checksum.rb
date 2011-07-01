module DirChecksum

  VERSION = "0.4.2"

  class Base

    attr_reader :checksum_name, :dir, :checksum_file

    def initialize(*args)
      options = Hash === args.last ? args.pop : {}
      @checksum_name = args.shift || options[:checksum_name] || :checksum
      @dir           = args.shift || options[:dir]           || Dir.pwd
      @checksum_file = args.shift || options[:checksum_file] ||
                       "#{dir}/.#{checksum_name.to_s.downcase}s"
    end

    def recursive_checksum(&block)
      Dir["#{dir}/**/*"].sort.each do |file|
        if File.file?(file) and file != checksum_file
          yield file.sub(%r{^#{dir}/*}, ''), checksum(file)
        end
      end
      nil
    end

    def has_checksum_file?
      File.exist?(checksum_file)
    end

    def write_to_file!(&block)
      File.open(checksum_file, 'w') do |out|
        header = yield(self) if block_given?
        out.puts("# #{header}") if header
        recursive_checksum do |*args|
          out.puts(args * "\t")
        end
      end
    end

    def read_from_file
      checks = File.read(checksum_file).lines.map do |line|
        next if line =~ /^#/
        line.chomp.split(/\t/)
      end
      Hash[*checks.compact.flatten]
    end

    def warn_if_has_checksum_file_and_diff!(&block)
      if has_checksum_file?
        diffs = self.diffs
        if diffs.empty?
          # do nothing
        elsif block_given?
          yield(diffs)
          nil
        else
          msg = "DIRECTORY #{dir} CONTAINS DIFFERENCES"
          header = "!" * (msg.length + 6)
          puts header
          puts "!! #{msg} !!"
          puts header
          diffs.sort.each { |d| puts "!! #{d}" }
          puts header
        end
      end
    end

    def diffs
      diffs = []
      checks = read_from_file
      recursive_checksum do |file, check|
        prev_check = checks.delete(file)
        if prev_check.nil?
          diffs << "New file: #{file}"
        elsif prev_check != check
          diffs << "File has changed: #{file}"
        end
      end
      checks.each do |file, check|
        diffs << "Missing file: #{file}"
      end
      diffs
    end

    private

    def checksum(file)
      raise NotImplementedError.new("Abstract class.  Childclasses must implement :checksum")
    end

  end

  #########################################################

  class DigestBase < Base

    def initialize(*args)
      name = self.class.name.sub(/.*::/, '')
      super(name, *args)
      require "digest/#{name.downcase}"
      @digest = ::Digest.const_get(name)
    end

    private

    def checksum(file)
      @digest.hexdigest(File.open(file, 'rb') { |f| f.read })
    end

  end

  #########################################################

  class MD5 < DigestBase; end
  class SHA1 < DigestBase; end

  #########################################################

  class Timestamp < Base

    def initialize(*args)
      super(:timestamp, *args)
    end

    private

    def checksum(file)
      File.mtime(file).to_i.to_s
    end

  end

  # Create class-level methods for convenience
  %w(recursive_checksum warn_if_has_checksum_file_and_diff! write_to_file!).each do |m|
    Base.send(:define_singleton_method, m) do |*args, &block|
      new(*args).send(m, &block)
    end

    # Defaults to SHA1
    define_singleton_method(m) do |*args, &block|
      SHA1.new(*args).send(m, &block)
    end
  end

end
