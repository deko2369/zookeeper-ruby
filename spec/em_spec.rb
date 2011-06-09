require File.expand_path('../spec_helper', __FILE__)
require 'zookeeper/em_client'

gem 'evented-spec', '~> 0.4.1'
require 'evented-spec'


describe 'ZookeeperEM' do
  describe 'Client' do
    include EventedSpec::SpecHelper
    default_timeout 3.0

    before do
      @zk = ZookeeperEM::Client.new('localhost:2181')
    end

    describe 'selectable_io' do
      it %[should return an IO object] do
        @zk.selectable_io.should be_instance_of(IO)
      end

      it %[should not be closed] do
        @zk.selectable_io.should_not be_closed
      end

      before do
        @data_cb = ZookeeperCallbacks::DataCallback.new do
          $stderr.puts "cb called: #{@data_cb.inspect}"
        end
      end

      it %[should be read-ready if there's an event waiting] do
        @zk.get(:path => "/", :callback => @data_cb)

        r, *_ = IO.select([@zk.selectable_io], [], [], 2)

        r.should be_kind_of(Array)
      end

      it %[should not be read-ready if there's no event] do
        # there's always an initial event after connect

        events = 0

        while true
          r, *_ = IO.select([@zk.selectable_io], [], [], 0.2)

          break unless r

          h = @zk.get_next_event(false)
          @zk.selectable_io.read(1)

          events += 1

          h.should be_kind_of(Hash)
          $stderr.puts h
        end

        events.should == 1
      end
    end

    describe 'em_connection' do
      it %[should be nil before the reactor is started] do
        @zk.em_connection.should be_nil
      end

      it %[should fire off the on_attached callbacks once the reactor is managing us] do
        @zk.on_attached do |*|
          @zk.em_connection.should_not be_nil
          @zk.em_connection.should be_instance_of(ZookeeperEM::ZKConnection)
          @zk.close { done }
        end

        em do
          EM.reactor_running?.should be_true
        end
      end
    end

    describe 'callbacks' do
      it %[should be called on the reactor thread] do

        @zk.on_attached do
          cb = lambda do |h|
            EM.reactor_thread?.should be_true
            @zk.close { done }
          end

          @zk.get(:path => '/', :callback => cb) 
        end

        em { }
      end
    end
  end
end

