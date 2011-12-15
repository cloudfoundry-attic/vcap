require "spec_helper"
require "warden/container/sequence"

describe Warden::Container::Sequence do

  # Run every example in its own fiber within the reactor loop
  around(:each) do |example|
    em do
      f = Fiber.new do
        example.run
        done
      end
      f.resume
    end
  end

  subject {
    Warden::Container::Sequence
  }

  let(:tempfile) {
    Tempfile.new("spec")
  }

  let(:lines) {
    IO.readlines(tempfile.path).map(&:chomp)
  }

  it "should execute steps in the order they are defined" do
    lambda {
      subject.execute! { |seq|
        seq.step { |s|
          s.execute {
            s.sh "echo 1 >> #{tempfile.path}"
          }
        }
        seq.step { |s|
          s.execute {
            s.sh "echo 2 >> #{tempfile.path}"
          }
        }
      }
    }.should_not raise_error

    lines.should == ["1", "2"]
  end

  it "should halt execution when a step fails to execute successfully" do
    lambda {
      subject.execute! { |seq|
        seq.step { |s|
          s.execute {
            s.sh "echo 1 >> #{tempfile.path}"
          }
        }
        seq.step { |s|
          s.execute {
            s.sh "exit 1"
          }
        }
        seq.step { |s|
          s.execute {
            s.sh "echo 3 >> #{tempfile.path}"
          }
        }
      }
    }.should raise_error(Warden::WardenError)

    lines.should == ["1"]
  end

  it "should rollback every step up to and including the failed one in reverse order" do
    lambda {
      subject.execute! { |seq|
        seq.step { |s|
          s.execute {
            s.sh "echo 1 >> #{tempfile.path}"
          }
          s.rollback {
            s.sh "echo r1 >> #{tempfile.path}"
          }
        }
        seq.step { |s|
          s.execute {
            s.sh "echo 2 >> #{tempfile.path}; exit 1"
          }
          s.rollback {
            s.sh "echo r2 >> #{tempfile.path}"
          }
        }
      }
    }.should raise_error(Warden::WardenError)

    lines.should == ["1", "2", "r2", "r1"]
  end
end
