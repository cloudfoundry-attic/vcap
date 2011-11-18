require "spec_helper"

describe "server backed by LXC" do

  # Make the server pick up the specified class
  let(:container_klass) {
    Warden::Container::LXC
  }

  it_behaves_like "a warden server"
end
