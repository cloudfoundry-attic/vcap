require 'logger'
require 'fileutils'
require 'em-http'
require 'fiber'

module VCAP module PackageCache end end

class VCAP::PackageCache::Downloader
  def initialize(tmp_dir, logger = nil)
    @logger = logger || Logger.new(STDOUT)
    @tmp_dir = tmp_dir
  end

  def async_fetch_url(url, tmp_file)
    f = Fiber.current
    http = EventMachine::HttpRequest.new(url).get

    file = File.open(tmp_file, 'w')
    http.errback {
      @logger.warn("Failed to download #{url}.")
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

  def download(file_name, url)
    @logger.info("Downloading #{file_name}")
    Dir.chdir(@tmp_dir) {
      tmp_file = random_file_name(:suffix => '.incomplete')
      async_fetch_url(url, tmp_file)
      raise "Download failed" if not File.exists?(tmp_file)
      File.rename(tmp_file, file_name)
    }
    @logger.debug("#{file_name} download completed.")
    true
  end

  def contains?(file_name)
    File.exists? file_path(file_name)
  end

  def get_file_path(file_name)
    raise "no #{file_name} present" if not contains?(file_name)
    file_path(file_name)
  end

  def remove_file!(file_name)
    FileUtils.rm_f file_path(file_name)
  end

  def purge!
    @logger.info("purging downloads directory #{@tmp_dir}")
    FileUtils.rm_f Dir.glob("#{@tmp_dir}/*")
  end

  private

  def file_path(file_name)
    File.join @tmp_dir, file_name
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
