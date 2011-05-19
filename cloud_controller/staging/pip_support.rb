module PipSupport

  REQUIREMENTS_FILE = 'requirements.txt'

  def uses_pip?
    File.exists?(File.join(source_directory, REQUIREMENTS_FILE))
  end

  def install_requirements
    "../env/bin/pip install -r #{REQUIREMENTS_FILE}"
  end

end
