$:.unshift(File.join(File.dirname(__FILE__),'../../common/lib'))
require 'logger'
require 'tmpdir'
require 'fileutils'
require 'vcap/subprocess'


module PackageCache
  class GemDownloader
    def initialize(tmp_dir, logger = nil)
      @logger = Logger.new(STDOUT)
      @tmp_dir = tmp_dir
      @used = false
    end

    def download(gem_name)
      Dir.chdir(@tmp_dir) {
        tmp_file = random_file_name(:suffix => '.incomplete')
        url = gem_to_url(gem_name)
        VCAP::Subprocess.new.run("wget --quiet -O #{tmp_file} --retry-connrefused --connect-timeout=5 --no-check-certificate #{url}")
        File.rename(tmp_file, gem_name)
      }
      true
    end

    def contains?(gem_name)
      File.exists? File.join @tmp_dir, gem_name
    end

    def get_gem_path(gem_name)
      raise "no gem #{gem_name} present" if not contains?(gem_name)
      gem_path(gem_name)
    end

    def remove_gem!(gem_name)
      FileUtils.rm_f gem_path(gem_name)
    end

    def purge!
      FileUtils.rm_f Dir.glob("#{@tmp_dir}/*")
    end

    private

    def gem_to_url(gem_name)
      "http://production.s3.rubygems.org/gems/#{gem_name}"
    end


    def gem_path(gem_name)
      File.join @tmp_dir, gem_name
    end

    def random_file_name(opts={})
        opts = {:chars => ('0'..'9').to_a + ('A'..'F').to_a + ('a'..'f').to_a,
                :length => 16, :prefix => '', :suffix => '',
                :verify => true, :attempts => 10}.merge(opts)
        opts[:attempts].times do
            filename = ''
            opts[:length].times do
                filename << opts[:chars][rand(opts[:chars].size)]
            end
            filename = opts[:prefix] + filename + opts[:suffix]
            return filename unless opts[:verify] && File.exists?(filename)
        end
        raise "random file creation failed!!!"
    end
  end
end
