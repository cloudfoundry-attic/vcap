require 'pkg_util'

module PipUtil
  class << self
    def pip_to_url(pip_name)
      url_prefix = "http://pypi.python.org/packages/source"
      first_letter = pip_name[0]
      base_name = pip_name.split('-')[0]
      file_name = PkgUtil.drop_extension(pip_name) + '.tar.bz2'
      "#{url_prefix}/#{first_letter}/#{base_name}/#{file_name}"
    end
  end
end
