require 'spec_helper'
require 'dir_checksum'

describe DirChecksum do

  context :Base do
    subject { DirChecksum::Base.new(:asum, '/some/base') }
    before  { subject.stub :checksum => "4215234" }

    [":asum, '/some/base', '/some/output.txt'",         :asum,     '/some/base', '/some/output.txt',
     ":a2, :checksum_file => 'out.a2', :dir => '/foo'", :a2,       '/foo',       'out.a2',
     ":dir => 'bar', :checksum_name => :sum3",          :sum3,     'bar',        'bar/.sum3s',
     "",                                                :checksum, :pwd,         'pwd/.checksums',
    ].each_slice(4) do |args, cn, dir, cf|
      specify "new(#{args})" do
        Dir.stub :pwd => :pwd
        dc = eval "DirChecksum::Base.new(#{args})"
        dc.instance_variable_get(:@checksum_name).should == cn
        dc.instance_variable_get(:@dir).should == dir
        dc.instance_variable_get(:@checksum_file).should == cf
      end
    end

    specify :recursive_checksum do
      Dir.should_receive(:[]).with('/some/base/**/*').and_return %w(/some/base/.asums /some/base/file1 /some/base/sub/file2)
      File.should_receive(:file?).exactly(3).times.and_return true
      results = []
      subject.recursive_checksum { |*args| results.concat(args) }
      results.should == %w(file1 4215234 sub/file2 4215234)
    end

    specify :has_checksum_file? do
      File.should_receive(:exist?).with('/some/base/.asums').and_return true
      subject.has_checksum_file?.should be_true
    end

    specify :write_to_file! do
      File.should_receive(:open).with('/some/base/.asums', 'w').and_yield(io = StringIO.new)
      subject.should_receive(:recursive_checksum).and_yield %w(a_file 42)
      subject.write_to_file!
      io.string.should == "a_file\t42\n"
    end

    specify "write_to_file! with block" do
      File.should_receive(:open).and_yield(io = StringIO.new)
      subject.should_receive(:recursive_checksum).and_yield %w(q w e)
      subject.write_to_file! { |dc| [:a_header, dc.dir] }
      io.string.should == %Q{# [:a_header, "/some/base"]\nq\tw\te\n}
    end

    specify :read_from_file do
      File.should_receive(:read).with('/some/base/.asums').and_return "a_file\t12\nsub/b_file\t91"
      subject.read_from_file.should == { "a_file" => "12", "sub/b_file" => "91" }
    end

    specify :diffs do
      subject.should_receive(:read_from_file).and_return({ "a_file" => "12", "sub/b_file" => "91", "z_file" => "13" })
      subject.should_receive(:recursive_checksum).and_yield("a_file", "12").
                                                    and_yield("sub/b_file", "76").
                                                    and_yield("x_file", "33")
      subject.diffs.should == ["File has changed: sub/b_file", "New file: x_file", "Missing file: z_file"]
    end

    specify "warn_if_has_checksum_file_and_diff! with missing checksum file" do
      subject.should_receive(:has_checksum_file?).and_return false
      subject.should_not_receive(:diffs)
      subject.warn_if_has_checksum_file_and_diff!
    end

    specify "warn_if_has_checksum_file_and_diff! with block" do
      subject.should_receive(:has_checksum_file?).and_return true
      subject.should_receive(:diffs).and_return %w(foo bar)
      found_diffs = nil
      subject.warn_if_has_checksum_file_and_diff! { |diffs| found_diffs = diffs }
      found_diffs.should == %w(foo bar)
    end

    specify "warn_if_has_checksum_file_and_diff! with no block" do
      subject.should_receive(:has_checksum_file?).and_return true
      subject.should_receive(:diffs).and_return %w(foo bar)
      io = StringIO.new
      subject.stub(:puts) { |s| io.puts(s) }
      subject.warn_if_has_checksum_file_and_diff!
      io.string.should == <<-END
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!! DIRECTORY /some/base CONTAINS DIFFERENCES !!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!! bar
!! foo
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      END
    end
  end

  specify :checksum do
    expect { DirChecksum::Base.new.send :checksum, :a_file }.should raise_error(NotImplementedError)
  end

  context 'implementation classes' do
    before do
      Dir.stub  :[] => %w(a_file)
      File.stub :file? => true,
                :open => 'file_contents'
    end

    it "should support Digest::MD5" do
      md5 = DirChecksum::MD5.new('/some/base')
      Digest::MD5.should_receive(:hexdigest).with('file_contents')
      md5.recursive_checksum {}
    end

    it "should support Digest::SHA1" do
      sha1 = DirChecksum::SHA1.new('/some/base')
      Digest::SHA1.should_receive(:hexdigest).with('file_contents')
      sha1.recursive_checksum {}
    end

    it "should support Timestamp diffing" do
      ts = DirChecksum::Timestamp.new('/some/base')
      File.should_receive(:mtime).with('a_file').and_return(42)
      ts.recursive_checksum {}
    end
  end

  context 'class-level methods' do
    [DirChecksum, DirChecksum::MD5, DirChecksum::SHA1, DirChecksum::Timestamp].each do |clazz|
      %w(recursive_checksum warn_if_has_checksum_file_and_diff! write_to_file!).each do |m|
        specify "#{clazz}.#{m}" do
          dc = mock(:dc_object)
          dc.should_receive(m).with(no_args).and_yield
          new_clazz = clazz.name =~ /::/ ? clazz : DirChecksum::SHA1
          new_clazz.should_receive(:new).with(:a, :b, :c, :d).and_return(dc)
          yielded = false
          clazz.send(m, :a, :b, :c, :d) { yielded = true }
          yielded.should be_true
        end
      end
    end
  end

end
