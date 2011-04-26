class Route < ActiveRecord::Base
  belongs_to :app
  scope :active, lambda { where("routes.active = ?", true) }
  validates_presence_of :url, :app_id
  before_validation :normalize_url
  before_validation :cancel_save_if_url_taken_by_other_user
  before_validation :cancel_save_if_url_reserved

  def self.external_urls_allowed?
    AppConfig[:app_uris][:allow_external]
  end

  def self.base_url_for_cloud
    @base_url ||= AppConfig[:external_uri].sub(/^\s*[^\.]+/,'')
  end

  def allowed?
    return true if Route.external_urls_allowed?
    return true if internal_url?
    app.owner.admin?
  end

  def internal_url?
    url =~ /#{Route.base_url_for_cloud}\s*$/o
  end

  private
  def normalize_url
    url = read_attribute(:url).to_s.downcase.strip
    write_attribute(:url, url)
  end

  def cancel_save_if_url_reserved
    return false unless app && app.owner
    # Admins will not fail any of the below tests
    return true if app.owner.admin?

    return false unless AppConfig[:app_uris]
    reserved_list = AppConfig[:app_uris][:reserved_list]
    reserved_length = AppConfig[:app_uris][:reserved_length] || 0

    # We check against reserved length and the reserved list here.
    prefix = read_attribute(:url).sub(Route.base_url_for_cloud, '')

    # If the reserved list is big, stop doing linear scan
    return false if prefix.length <= reserved_length
    return false if reserved_list.include? prefix
    true
  end

  def cancel_save_if_url_taken_by_other_user
    owner_id = app && app.owner_id
    return false unless owner_id
    app_ids = app.owner.apps.map {|a| a.id}
    if Route.where("url = ? and app_id not in (?)", url, app_ids).any?
      false
    else
      true
    end
  end
end
