require "spec_helper"

describe "server implementing LXC" do
  it_behaves_like "a warden server", Warden::Container::LXC
end
