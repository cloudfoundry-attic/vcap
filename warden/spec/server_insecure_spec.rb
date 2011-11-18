require "spec_helper"

describe "server implementing insecure containers" do
  it_behaves_like "a warden server", Warden::Container::Insecure
end
