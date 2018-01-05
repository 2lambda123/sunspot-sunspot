require File.expand_path('spec_helper', File.dirname(__FILE__))

RAILS_5 = (ENV['RAILS'] == '5.0' || ENV['RAILS'] == '5.1')

# TODO rewrite tests for rails > 5
unless RAILS_5

  describe PostsController, :type => :controller do
    begin
      include ::RSpec::Rails::ControllerExampleGroup
    rescue NameError
      # Silent -- rspec-rails 1.x catches the :type => :controller
    end

    before(:each) do
      Sunspot::Rails.configuration = @configuration = Sunspot::Rails::Configuration.new
    end

    after(:each) do
      Sunspot::Rails.configuration = nil
    end

    unless respond_to?(:describes)
      controller_name :posts # RSpec 1
    end

    it 'should automatically commit after each action if specified' do
      @configuration.user_configuration = { 'auto_commit_after_request' => true }
      expect(Sunspot).to receive(:commit_if_dirty)
      post :create, :post => { :title => 'Test 1' }
    end

    it 'should not commit, if configuration is set to false' do
      @configuration.user_configuration = { 'auto_commit_after_request' => false }
      expect(Sunspot).not_to receive(:commit_if_dirty)
      post :create, :post => { :title => 'Test 1' }
    end

    it 'should commit if configuration is not specified' do
      @configuration.user_configuration = {}
      expect(Sunspot).to receive(:commit_if_dirty)
      post :create, :post => { :title => 'Test 1' }
    end

    ### auto_commit_if_delete_dirty

    it 'should automatically commit after each delete if specified' do
      @configuration.user_configuration = { 'auto_commit_after_request' => false,
                                            'auto_commit_after_delete_request' => true }
      expect(Sunspot).to receive(:commit_if_delete_dirty)
      post :create, :post => { :title => 'Test 1' }
    end

    it 'should not automatically commit on delete if configuration is set to false' do
      @configuration.user_configuration = { 'auto_commit_after_request' => false,
                                            'auto_commit_after_delete_request' => false }
      expect(Sunspot).not_to receive(:commit_if_delete_dirty)
      post :create, :post => { :title => 'Test 1' }
    end

    it 'should not automatically commit on delete if configuration is not specified' do
      @configuration.user_configuration = { 'auto_commit_after_request' => false }
      expect(Sunspot).not_to receive(:commit_if_delete_dirty)
      post :create, :post => { :title => 'Test 1' }
    end
  end

end