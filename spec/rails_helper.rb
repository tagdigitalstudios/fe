# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spork'

Spork.prefork do
  ENV["RAILS_ENV"] ||= 'test'
  require File.expand_path("../dummy/config/environment.rb", __FILE__)
  require 'rspec/rails'
  require 'rspec'
  require 'shoulda'
  require 'database_cleaner'
  require 'factory_girl_rails'
  require 'simplecov'
  SimpleCov.start 'rails' do
    add_filter "vendor"
  end
  Rails.backtrace_cleaner.remove_silencers!

  ENGINE_RAILS_ROOT = File.join( File.dirname(__FILE__), '../' )

  # Requires supporting ruby files with custom matchers and macros, etc,
  # in spec/support/ and its subdirectories.
  Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}
  Dir[File.join(ENGINE_RAILS_ROOT,"spec/support/**/*.rb")].each {|f| require f}

  RSpec.configure do |config|

    config.include FactoryGirl::Syntax::Methods
    #
    #config.before(:suite) do
    #  DatabaseCleaner.strategy = :transaction
    #  DatabaseCleaner.clean_with(:truncation)
    #end
    #config.before(:each) do
    #  DatabaseCleaner.start
    #end
    #config.after(:each) do
    #  DatabaseCleaner.clean
    #end

    config.mock_with :rspec
    # muted to allow database_cleaner to work
    #
    # If you're not using ActiveRecord, or you'd prefer not to run each of your
    # examples within a transaction, remove the following line or assign false
    # instead of true.
    # config.use_transactional_fixtures = true

    # set to true (embrace the future)
    #
    # If true, the base class of anonymous controllers will be inferred
    # automatically. This will be the default behavior in future versions of
    # rspec-rails.
    config.infer_base_class_for_anonymous_controllers = true

    # Run specs in random order to surface order dependencies. If you find an
    # order dependency and want to debug it, you can fix the order by providing
    # the seed, which is printed after each run.
    #     --seed 1234
    config.order = "random"
  end
end

Spork.each_run do
  # This code will be run each time you run your specs.
  FactoryGirl.reload
end