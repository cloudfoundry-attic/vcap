module ServicesHelper

  def validate_content_type
    raise CloudError.new(CloudError::BAD_REQUEST) unless request.env['CONTENT_TYPE'] == Mime::JSON
  end
end
