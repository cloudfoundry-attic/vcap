$:.unshift(File.join(File.dirname(__FILE__),'../../common/lib'))
require 'logger'
require 'tmpdir'
require 'fileutils'
require 'vcap/subprocess'
require 'em-http'
require 'fiber'


module VCAP module PackageCache end end

class VCAP::PackageCache::GemDownloader
  def initialize(tmp_dir, logger = nil)
    @logger = logger || Logger.new(STDOUT)
    @tmp_dir = tmp_dir
    @used = false
  end

  def async_fetch_url(url, tmp_file)
    f = Fiber.current
    http = EventMachine::HttpRequest.new(url).get

    file = File.open(tmp_file, 'w')
    http.errback {
      @logger.warn("Failed to download gem from #{url}.")
      file.close
      FileUtils.rm_f(tmp_file)
      f.resume
    }
    http.stream { |chunk|
      file.write(chunk)
    }
    http.callback {
      file.close
      f.resume
    }
    Fiber.yield
  end


  def download(gem_name)
    @logger.info("Downloading gem #{gem_name}")
    Dir.chdir(@tmp_dir) {
      tmp_file = random_file_name(:suffix => '.incomplete')
      url = gem_to_url(gem_name)
      async_fetch_url(url, tmp_file)
      raise "Download failed" if not File.exists?(tmp_file)
      File.rename(tmp_file, gem_name)
    }
    @logger.debug("#{gem_name} download completed.")
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
    @logger.info("purging downloads directory #{@tmp_dir}")
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
